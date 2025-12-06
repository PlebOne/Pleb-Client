//! Zap (Lightning payments) support - NIP-57
//!
//! Provides functionality for zapping notes and profiles via LNURL

use nostr_sdk::prelude::*;
use serde::{Deserialize, Serialize};
use std::sync::Arc;
use tokio::sync::Mutex;

use super::nwc::NwcManager;

/// LNURL-pay callback response
#[derive(Debug, Clone, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct LnurlPayResponse {
    pub callback: String,
    pub min_sendable: u64,  // millisats
    pub max_sendable: u64,  // millisats
    pub metadata: String,
    #[serde(default)]
    pub allows_nostr: bool,
    #[serde(default)]
    pub nostr_pubkey: Option<String>,
}

/// Invoice response from LNURL callback
#[derive(Debug, Clone, Deserialize)]
pub struct LnurlInvoiceResponse {
    pub pr: String,  // payment request (bolt11 invoice)
    #[serde(default)]
    pub routes: Vec<serde_json::Value>,
}

/// Error response from LNURL
#[derive(Debug, Clone, Deserialize)]
pub struct LnurlErrorResponse {
    pub status: String,
    pub reason: String,
}

/// Shared NWC manager type
pub type SharedNwcManager = Arc<Mutex<NwcManager>>;

/// Create a shared NWC manager
pub fn create_shared_nwc_manager() -> SharedNwcManager {
    Arc::new(Mutex::new(NwcManager::new()))
}

/// Global NWC manager instance
lazy_static::lazy_static! {
    pub static ref GLOBAL_NWC_MANAGER: SharedNwcManager = create_shared_nwc_manager();
}

/// Resolve a Lightning address to LNURL-pay endpoint info
pub async fn resolve_lnurl(lud16: &str) -> Result<LnurlPayResponse, String> {
    // Convert lightning address to LNURL
    // format: user@domain -> https://domain/.well-known/lnurlp/user
    let parts: Vec<&str> = lud16.split('@').collect();
    if parts.len() != 2 {
        return Err(format!("Invalid lightning address format: {}", lud16));
    }
    
    let (user, domain) = (parts[0], parts[1]);
    let url = format!("https://{}/.well-known/lnurlp/{}", domain, user);
    
    tracing::info!("Resolving LNURL: {}", url);
    
    let client = reqwest::Client::builder()
        .timeout(std::time::Duration::from_secs(10))
        .build()
        .map_err(|e| format!("Failed to create HTTP client: {}", e))?;
    
    let response = client.get(&url)
        .header("Accept", "application/json")
        .send()
        .await
        .map_err(|e| format!("Failed to fetch LNURL: {}", e))?;
    
    if !response.status().is_success() {
        return Err(format!("LNURL request failed with status: {}", response.status()));
    }
    
    let text = response.text().await
        .map_err(|e| format!("Failed to read LNURL response: {}", e))?;
    
    // Check if it's an error response
    if let Ok(error) = serde_json::from_str::<LnurlErrorResponse>(&text) {
        if error.status == "ERROR" {
            return Err(format!("LNURL error: {}", error.reason));
        }
    }
    
    let lnurl_response: LnurlPayResponse = serde_json::from_str(&text)
        .map_err(|e| format!("Failed to parse LNURL response: {} - {}", e, text))?;
    
    Ok(lnurl_response)
}

/// Create a zap request event (NIP-57)
pub fn create_zap_request(
    keys: &Keys,
    recipient_pubkey: &PublicKey,
    event_id: Option<&EventId>,
    amount_msats: u64,
    relays: &[String],
    content: &str,
) -> Result<Event, String> {
    // Build tags
    let mut tags = vec![
        Tag::public_key(recipient_pubkey.clone()),
        Tag::custom(
            TagKind::custom("relays"),
            relays.iter().map(|s| s.to_string()).collect::<Vec<String>>()
        ),
        Tag::custom(TagKind::custom("amount"), vec![amount_msats.to_string()]),
    ];
    
    // Add event tag if zapping a specific note
    if let Some(eid) = event_id {
        tags.push(Tag::event(eid.clone()));
    }
    
    // Build zap request event (kind 9734)
    let event = EventBuilder::new(Kind::ZapRequest, content)
        .tags(tags)
        .sign_with_keys(keys)
        .map_err(|e| format!("Failed to sign zap request: {}", e))?;
    
    Ok(event)
}

/// Get an invoice from LNURL callback with zap request
pub async fn get_zap_invoice(
    lnurl_response: &LnurlPayResponse,
    amount_msats: u64,
    zap_request: Option<&Event>,
) -> Result<String, String> {
    // Validate amount
    if amount_msats < lnurl_response.min_sendable {
        return Err(format!(
            "Amount {} msats is below minimum {} msats",
            amount_msats, lnurl_response.min_sendable
        ));
    }
    if amount_msats > lnurl_response.max_sendable {
        return Err(format!(
            "Amount {} msats exceeds maximum {} msats",
            amount_msats, lnurl_response.max_sendable
        ));
    }
    
    // Build callback URL
    let mut url = format!("{}?amount={}", lnurl_response.callback, amount_msats);
    
    // Add nostr zap request if provided and supported
    if let Some(zap_req) = zap_request {
        if lnurl_response.allows_nostr {
            let zap_json = serde_json::to_string(&zap_req)
                .map_err(|e| format!("Failed to serialize zap request: {}", e))?;
            let encoded = urlencoding::encode(&zap_json);
            url = format!("{}&nostr={}", url, encoded);
        }
    }
    
    tracing::info!("Fetching invoice from: {}", url);
    
    let client = reqwest::Client::builder()
        .timeout(std::time::Duration::from_secs(30))
        .build()
        .map_err(|e| format!("Failed to create HTTP client: {}", e))?;
    
    let response = client.get(&url)
        .header("Accept", "application/json")
        .send()
        .await
        .map_err(|e| format!("Failed to fetch invoice: {}", e))?;
    
    if !response.status().is_success() {
        return Err(format!("Invoice request failed with status: {}", response.status()));
    }
    
    let text = response.text().await
        .map_err(|e| format!("Failed to read invoice response: {}", e))?;
    
    // Check if it's an error response
    if let Ok(error) = serde_json::from_str::<LnurlErrorResponse>(&text) {
        if error.status == "ERROR" {
            return Err(format!("LNURL error: {}", error.reason));
        }
    }
    
    let invoice_response: LnurlInvoiceResponse = serde_json::from_str(&text)
        .map_err(|e| format!("Failed to parse invoice response: {} - {}", e, text))?;
    
    Ok(invoice_response.pr)
}

/// Full zap flow: resolve lnurl -> create zap request -> get invoice -> pay
pub async fn zap(
    nwc_manager: &mut NwcManager,
    signing_keys: &Keys,
    recipient_pubkey: &PublicKey,
    lud16: &str,
    event_id: Option<&EventId>,
    amount_sats: u64,
    comment: &str,
    relays: &[String],
) -> Result<String, String> {
    let amount_msats = amount_sats * 1000;
    
    tracing::info!("Starting zap: {} sats to {} for {:?}", 
        amount_sats, lud16, event_id.map(|e| e.to_hex()));
    
    // Step 1: Resolve LNURL
    let lnurl_response = resolve_lnurl(lud16).await?;
    tracing::info!("LNURL resolved: allows_nostr={}", lnurl_response.allows_nostr);
    
    // Step 2: Create zap request if LNURL supports it
    let zap_request = if lnurl_response.allows_nostr {
        Some(create_zap_request(
            signing_keys,
            recipient_pubkey,
            event_id,
            amount_msats,
            relays,
            comment,
        )?)
    } else {
        None
    };
    
    // Step 3: Get invoice
    let invoice = get_zap_invoice(&lnurl_response, amount_msats, zap_request.as_ref()).await?;
    tracing::info!("Got invoice: {}...", &invoice[..50.min(invoice.len())]);
    
    // Step 4: Pay via NWC
    let preimage = nwc_manager.pay_invoice(&invoice).await?;
    tracing::info!("Zap successful! Preimage: {}...", &preimage[..16.min(preimage.len())]);
    
    Ok(preimage)
}

/// Zap result for QML
#[derive(Debug, Clone, Serialize)]
pub struct ZapResult {
    pub success: bool,
    pub preimage: Option<String>,
    pub error: Option<String>,
    pub amount_sats: u64,
}

impl ZapResult {
    pub fn success(preimage: String, amount_sats: u64) -> Self {
        Self {
            success: true,
            preimage: Some(preimage),
            error: None,
            amount_sats,
        }
    }
    
    pub fn error(error: String) -> Self {
        Self {
            success: false,
            preimage: None,
            error: Some(error),
            amount_sats: 0,
        }
    }
    
    pub fn to_json(&self) -> String {
        serde_json::to_string(self).unwrap_or_default()
    }
}
