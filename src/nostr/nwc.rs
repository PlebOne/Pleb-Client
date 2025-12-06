//! NWC (Nostr Wallet Connect) support - NIP-47
//!
//! Provides wallet functionality for sending and receiving zaps via NWC

use nostr_sdk::prelude::*;
use std::sync::Arc;
use tokio::sync::RwLock;

/// NWC connection state
#[derive(Debug, Clone, PartialEq)]
pub enum NwcState {
    Disconnected,
    Connecting,
    Connected,
    Error(String),
}

/// NWC connection info
#[derive(Debug, Clone)]
pub struct NwcConnection {
    pub relay_url: String,
    pub wallet_pubkey: PublicKey,
    pub secret: SecretKey,
    pub lud16: Option<String>,
}

impl NwcConnection {
    /// Parse NWC URI (nostr+walletconnect://...)
    pub fn from_uri(uri: &str) -> Result<Self, String> {
        // NWC URI format: nostr+walletconnect://pubkey?relay=wss://...&secret=hex
        let uri = uri.trim();
        
        // Remove the scheme
        let without_scheme = uri
            .strip_prefix("nostr+walletconnect://")
            .or_else(|| uri.strip_prefix("nostr://"))
            .ok_or("Invalid NWC URI scheme")?;
        
        // Split into pubkey and query string
        let (pubkey_str, query) = if let Some(idx) = without_scheme.find('?') {
            (&without_scheme[..idx], &without_scheme[idx + 1..])
        } else {
            return Err("Missing query parameters in NWC URI".to_string());
        };
        
        // Parse pubkey
        let wallet_pubkey = PublicKey::from_hex(pubkey_str)
            .or_else(|_| PublicKey::from_bech32(pubkey_str))
            .map_err(|e| format!("Invalid pubkey in NWC URI: {}", e))?;
        
        // Parse query params
        let mut relay_url = None;
        let mut secret_str = None;
        let mut lud16 = None;
        
        for param in query.split('&') {
            if let Some((key, value)) = param.split_once('=') {
                match key {
                    "relay" => relay_url = Some(urlencoding::decode(value)
                        .map_err(|e| format!("Failed to decode relay URL: {}", e))?
                        .to_string()),
                    "secret" => secret_str = Some(value.to_string()),
                    "lud16" => lud16 = Some(value.to_string()),
                    _ => {}
                }
            }
        }
        
        let relay_url = relay_url.ok_or("Missing relay in NWC URI")?;
        let secret_str = secret_str.ok_or("Missing secret in NWC URI")?;
        let secret = SecretKey::from_hex(&secret_str)
            .map_err(|e| format!("Invalid secret in NWC URI: {}", e))?;
        
        Ok(Self {
            relay_url,
            wallet_pubkey,
            secret,
            lud16,
        })
    }
}

/// NWC Manager for wallet operations
pub struct NwcManager {
    connection: Option<NwcConnection>,
    keys: Option<Keys>,
    client: Option<Client>,
    state: NwcState,
    balance_sats: i64,
}

impl NwcManager {
    pub fn new() -> Self {
        Self {
            connection: None,
            keys: None,
            client: None,
            state: NwcState::Disconnected,
            balance_sats: 0,
        }
    }
    
    /// Connect to NWC wallet
    pub async fn connect(&mut self, uri: &str) -> Result<(), String> {
        self.state = NwcState::Connecting;
        
        // Parse URI
        let connection = NwcConnection::from_uri(uri)?;
        
        // Create keys from the NWC secret
        let keys = Keys::new(connection.secret.clone());
        
        // Create client with the NWC keys
        let client = Client::builder()
            .signer(keys.clone())
            .build();
        
        // Add relay
        client.add_relay(&connection.relay_url).await
            .map_err(|e| format!("Failed to add relay: {}", e))?;
        
        // Connect
        client.connect().await;
        
        self.keys = Some(keys);
        self.connection = Some(connection);
        self.client = Some(client);
        self.state = NwcState::Connected;
        
        // Try to get initial balance
        if let Err(e) = self.fetch_balance().await {
            tracing::warn!("Failed to fetch initial balance: {}", e);
        }
        
        Ok(())
    }
    
    /// Disconnect from NWC wallet
    pub async fn disconnect(&mut self) {
        if let Some(client) = &self.client {
            client.disconnect().await;
        }
        self.client = None;
        self.keys = None;
        self.connection = None;
        self.state = NwcState::Disconnected;
        self.balance_sats = 0;
    }
    
    /// Check if connected
    pub fn is_connected(&self) -> bool {
        matches!(self.state, NwcState::Connected)
    }
    
    /// Get current state
    pub fn state(&self) -> &NwcState {
        &self.state
    }
    
    /// Get current balance in sats
    pub fn balance_sats(&self) -> i64 {
        self.balance_sats
    }
    
    /// Fetch wallet balance
    pub async fn fetch_balance(&mut self) -> Result<i64, String> {
        let (client, connection, keys) = match (&self.client, &self.connection, &self.keys) {
            (Some(c), Some(conn), Some(k)) => (c, conn, k),
            _ => return Err("Not connected to NWC".to_string()),
        };
        
        // Build get_balance request content
        let request = serde_json::json!({
            "method": "get_balance"
        });
        
        // Encrypt request content for the wallet
        let encrypted_content = nip04::encrypt(
            keys.secret_key(),
            &connection.wallet_pubkey,
            &request.to_string()
        ).map_err(|e| format!("Failed to encrypt NWC request: {}", e))?;
        
        // Build the event
        let event = EventBuilder::new(Kind::WalletConnectRequest, encrypted_content)
            .tag(Tag::public_key(connection.wallet_pubkey.clone()))
            .sign_with_keys(keys)
            .map_err(|e| format!("Failed to sign NWC request: {}", e))?;
        
        let event_id = event.id.clone();
        
        // Send request
        client.send_event(&event).await
            .map_err(|e| format!("Failed to send NWC request: {}", e))?;
        
        // Wait for response
        let filter = Filter::new()
            .kind(Kind::WalletConnectResponse)
            .author(connection.wallet_pubkey.clone())
            .custom_tag(SingleLetterTag::lowercase(Alphabet::E), event_id.to_hex())
            .limit(1);
        
        let events = client.fetch_events(filter, std::time::Duration::from_secs(30)).await
            .map_err(|e| format!("Failed to fetch NWC response: {}", e))?;
        
        if let Some(response_event) = events.into_iter().next() {
            // Decrypt and parse response
            let decrypted = nip04::decrypt(
                keys.secret_key(),
                &response_event.pubkey,
                &response_event.content
            ).map_err(|e| format!("Failed to decrypt NWC response: {}", e))?;
            
            let response: serde_json::Value = serde_json::from_str(&decrypted)
                .map_err(|e| format!("Failed to parse NWC response: {}", e))?;
            
            if let Some(balance) = response.get("result").and_then(|r| r.get("balance")).and_then(|b| b.as_i64()) {
                // Balance is in millisats, convert to sats
                self.balance_sats = balance / 1000;
                return Ok(self.balance_sats);
            }
            
            if let Some(error) = response.get("error") {
                return Err(format!("NWC error: {:?}", error));
            }
        }
        
        Err("No response from NWC".to_string())
    }
    
    /// Pay an invoice
    pub async fn pay_invoice(&mut self, invoice: &str) -> Result<String, String> {
        let (client, connection, keys) = match (&self.client, &self.connection, &self.keys) {
            (Some(c), Some(conn), Some(k)) => (c, conn, k),
            _ => return Err("Not connected to NWC".to_string()),
        };
        
        // Build pay_invoice request
        let request = serde_json::json!({
            "method": "pay_invoice",
            "params": {
                "invoice": invoice
            }
        });
        
        // Encrypt request content
        let encrypted_content = nip04::encrypt(
            keys.secret_key(),
            &connection.wallet_pubkey,
            &request.to_string()
        ).map_err(|e| format!("Failed to encrypt NWC request: {}", e))?;
        
        // Build and sign the event
        let event = EventBuilder::new(Kind::WalletConnectRequest, encrypted_content)
            .tag(Tag::public_key(connection.wallet_pubkey.clone()))
            .sign_with_keys(keys)
            .map_err(|e| format!("Failed to sign NWC request: {}", e))?;
        
        let event_id = event.id.clone();
        
        // Send request
        client.send_event(&event).await
            .map_err(|e| format!("Failed to send NWC request: {}", e))?;
        
        tracing::info!("NWC pay_invoice request sent, waiting for response...");
        
        // Wait for response with retries (payment can take time to process)
        let filter = Filter::new()
            .kind(Kind::WalletConnectResponse)
            .author(connection.wallet_pubkey.clone())
            .custom_tag(SingleLetterTag::lowercase(Alphabet::E), event_id.to_hex())
            .limit(1);
        
        // Retry fetching the response multiple times with delays
        // This handles the case where the wallet needs time to process
        let max_attempts = 12; // 12 attempts * 5 seconds = 60 seconds total
        for attempt in 1..=max_attempts {
            // Small delay before each fetch to give wallet time to respond
            if attempt > 1 {
                tokio::time::sleep(std::time::Duration::from_secs(5)).await;
            }
            
            tracing::debug!("NWC response fetch attempt {}/{}", attempt, max_attempts);
            
            let events = client.fetch_events(filter.clone(), std::time::Duration::from_secs(10)).await
                .map_err(|e| format!("Failed to fetch NWC response: {}", e))?;
            
            if let Some(response_event) = events.into_iter().next() {
                // Decrypt and parse response
                let decrypted = nip04::decrypt(
                    keys.secret_key(),
                    &response_event.pubkey,
                    &response_event.content
                ).map_err(|e| format!("Failed to decrypt NWC response: {}", e))?;
                
                tracing::debug!("NWC response decrypted: {}", &decrypted[..100.min(decrypted.len())]);
                
                let response: serde_json::Value = serde_json::from_str(&decrypted)
                    .map_err(|e| format!("Failed to parse NWC response: {}", e))?;
                
                if let Some(result) = response.get("result") {
                    if let Some(preimage) = result.get("preimage").and_then(|p| p.as_str()) {
                        tracing::info!("NWC payment successful, preimage received");
                        // Refresh balance after payment
                        let _ = self.fetch_balance().await;
                        return Ok(preimage.to_string());
                    }
                }
                
                if let Some(error) = response.get("error") {
                    return Err(format!("Payment failed: {:?}", error));
                }
            }
        }
        
        // If we got here, the payment might have succeeded but we didn't get the response
        // This is better than saying "failed" when the payment actually went through
        Err("NWC response timeout - payment may have succeeded, please check your wallet".to_string())
    }
    
    /// Create an invoice
    pub async fn make_invoice(&mut self, amount_sats: u64, description: &str) -> Result<String, String> {
        let (client, connection, keys) = match (&self.client, &self.connection, &self.keys) {
            (Some(c), Some(conn), Some(k)) => (c, conn, k),
            _ => return Err("Not connected to NWC".to_string()),
        };
        
        // Build make_invoice request (amount in millisats)
        let request = serde_json::json!({
            "method": "make_invoice",
            "params": {
                "amount": amount_sats * 1000,
                "description": description
            }
        });
        
        // Encrypt request content
        let encrypted_content = nip04::encrypt(
            keys.secret_key(),
            &connection.wallet_pubkey,
            &request.to_string()
        ).map_err(|e| format!("Failed to encrypt NWC request: {}", e))?;
        
        // Build and sign the event
        let event = EventBuilder::new(Kind::WalletConnectRequest, encrypted_content)
            .tag(Tag::public_key(connection.wallet_pubkey.clone()))
            .sign_with_keys(keys)
            .map_err(|e| format!("Failed to sign NWC request: {}", e))?;
        
        let event_id = event.id.clone();
        
        // Send request
        client.send_event(&event).await
            .map_err(|e| format!("Failed to send NWC request: {}", e))?;
        
        // Wait for response
        let filter = Filter::new()
            .kind(Kind::WalletConnectResponse)
            .author(connection.wallet_pubkey.clone())
            .custom_tag(SingleLetterTag::lowercase(Alphabet::E), event_id.to_hex())
            .limit(1);
        
        let events = client.fetch_events(filter, std::time::Duration::from_secs(30)).await
            .map_err(|e| format!("Failed to fetch NWC response: {}", e))?;
        
        if let Some(response_event) = events.into_iter().next() {
            // Decrypt and parse response
            let decrypted = nip04::decrypt(
                keys.secret_key(),
                &response_event.pubkey,
                &response_event.content
            ).map_err(|e| format!("Failed to decrypt NWC response: {}", e))?;
            
            let response: serde_json::Value = serde_json::from_str(&decrypted)
                .map_err(|e| format!("Failed to parse NWC response: {}", e))?;
            
            if let Some(result) = response.get("result") {
                if let Some(invoice) = result.get("invoice").and_then(|i| i.as_str()) {
                    return Ok(invoice.to_string());
                }
            }
            
            if let Some(error) = response.get("error") {
                return Err(format!("Failed to create invoice: {:?}", error));
            }
        }
        
        Err("No response from NWC".to_string())
    }
}

impl Default for NwcManager {
    fn default() -> Self {
        Self::new()
    }
}

/// Shared NWC manager
pub type SharedNwcManager = Arc<RwLock<NwcManager>>;

/// Create a shared NWC manager
pub fn create_nwc_manager() -> SharedNwcManager {
    Arc::new(RwLock::new(NwcManager::new()))
}
