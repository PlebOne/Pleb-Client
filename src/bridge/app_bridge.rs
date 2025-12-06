//! App bridge - main application state exposed to QML

#[cxx_qt::bridge]
pub mod qobject {
    unsafe extern "C++" {
        include!("cxx-qt-lib/qstring.h");
        type QString = cxx_qt_lib::QString;
        
        include!("cxx-qt-lib/qurl.h");
        type QUrl = cxx_qt_lib::QUrl;
    }

    unsafe extern "RustQt" {
        #[qobject]
        #[qml_element]
        #[qproperty(QString, current_screen)]
        #[qproperty(bool, logged_in)]
        #[qproperty(QString, public_key)]
        #[qproperty(QString, npub)]
        #[qproperty(QString, display_name)]
        #[qproperty(QString, profile_picture)]
        #[qproperty(bool, is_loading)]
        #[qproperty(QString, error_message)]
        #[qproperty(bool, tray_available)]
        #[qproperty(bool, signer_available)]
        #[qproperty(i64, wallet_balance_sats)]
        #[qproperty(bool, show_global_feed)]
        #[qproperty(bool, has_saved_credentials)]
        #[qproperty(bool, nwc_connected)]
        type AppController = super::AppControllerRust;

        /// Create a new Nostr account (generate keys)
        #[qinvokable]
        fn create_account(self: Pin<&mut AppController>);
        
        /// Login with nsec
        #[qinvokable]
        fn login_with_nsec(self: Pin<&mut AppController>, nsec: &QString);
        
        /// Login via Pleb Signer (advanced option)
        #[qinvokable]
        fn login_with_signer(self: Pin<&mut AppController>);
        
        /// Check if Pleb Signer is available and ready
        #[qinvokable]
        fn check_signer(self: Pin<&mut AppController>);
        
        /// Logout
        #[qinvokable]
        fn logout(self: Pin<&mut AppController>);
        
        /// Check for saved credentials (returns true if credentials exist)
        #[qinvokable]
        fn check_saved_credentials(self: Pin<&mut AppController>);
        
        /// Login with password (for stored encrypted credentials)
        #[qinvokable]
        fn login_with_password(self: Pin<&mut AppController>, password: &QString);
        
        /// Save nsec with password protection (remember me)
        #[qinvokable]
        fn save_credentials_with_password(self: Pin<&mut AppController>, nsec: &QString, password: &QString);
        
        /// Clear saved credentials (called during logout)
        #[qinvokable]
        fn clear_saved_credentials(self: Pin<&mut AppController>);
        
        /// Navigate to a screen
        #[qinvokable]
        fn navigate_to(self: Pin<&mut AppController>, screen: &QString);
        
        /// Refresh the current view
        #[qinvokable]
        fn refresh(self: Pin<&mut AppController>);
        
        /// Connect NWC wallet
        #[qinvokable]
        fn connect_nwc(self: Pin<&mut AppController>, uri: &QString);
        
        /// Connect NWC wallet with password (for saving)
        #[qinvokable]
        fn connect_nwc_and_save(self: Pin<&mut AppController>, uri: &QString, password: &QString);
        
        /// Disconnect NWC wallet
        #[qinvokable]
        fn disconnect_nwc(self: Pin<&mut AppController>);
        
        /// Check if NWC is connected
        #[qinvokable]
        fn is_nwc_connected(self: Pin<&mut AppController>) -> bool;
        
        /// Set show global feed setting
        #[qinvokable]
        fn set_show_global_feed_setting(self: Pin<&mut AppController>, show: bool);
        
        /// Get configured relays as JSON array
        #[qinvokable]
        fn get_relays(self: Pin<&mut AppController>) -> QString;
        
        /// Add a relay
        #[qinvokable]
        fn add_relay(self: Pin<&mut AppController>, url: &QString) -> bool;
        
        /// Remove a relay
        #[qinvokable]
        fn remove_relay(self: Pin<&mut AppController>, url: &QString) -> bool;
        
        /// Reset relays to defaults
        #[qinvokable]
        fn reset_relays_to_default(self: Pin<&mut AppController>);
        
        /// Minimize to system tray
        #[qinvokable]
        fn minimize_to_tray(self: Pin<&mut AppController>);
    }

    // Signals are declared in the extern block
    unsafe extern "RustQt" {
        /// Emitted when login completes (success or failure)
        #[qsignal]
        fn login_complete(self: Pin<&mut AppController>, success: bool, error: &QString);
        
        /// Emitted when account is created (returns nsec and npub)
        #[qsignal]
        fn account_created(self: Pin<&mut AppController>, nsec: &QString, npub: &QString);
        
        /// Emitted when signer status changes
        #[qsignal]
        fn signer_status_changed(self: Pin<&mut AppController>, available: bool);
        
        /// Emitted when feed is loaded
        #[qsignal]
        fn feed_loaded(self: Pin<&mut AppController>);
        
        /// Emitted when wallet balance updates
        #[qsignal]
        fn wallet_updated(self: Pin<&mut AppController>, balance_sats: i64);
        
        /// Emitted when a notification arrives
        #[qsignal]
        fn notification_received(self: Pin<&mut AppController>, title: &QString, body: &QString);
        
        /// Emitted when credentials are saved successfully
        #[qsignal]
        fn credentials_saved(self: Pin<&mut AppController>);
    }
}

use std::pin::Pin;
use std::sync::Arc;
use cxx_qt_lib::QString;
use tokio::sync::Mutex;
use crate::signer::SignerClient;
use crate::core::credentials::CredentialManager;
use crate::nostr::GLOBAL_NWC_MANAGER;
use crate::bridge::feed_bridge::set_feed_nsec;
use crate::bridge::dm_bridge::set_dm_nsec;

// Global signer client instance
lazy_static::lazy_static! {
    static ref SIGNER_CLIENT: Arc<Mutex<Option<SignerClient>>> = Arc::new(Mutex::new(None));
    static ref TOKIO_RUNTIME: tokio::runtime::Runtime = tokio::runtime::Runtime::new().unwrap();
}

/// Rust implementation of AppController
pub struct AppControllerRust {
    current_screen: QString,
    logged_in: bool,
    public_key: QString,
    npub: QString,
    display_name: QString,
    profile_picture: QString,
    is_loading: bool,
    error_message: QString,
    tray_available: bool,
    signer_available: bool,
    wallet_balance_sats: i64,
    show_global_feed: bool,
    has_saved_credentials: bool,
    nwc_connected: bool,
}

impl Default for AppControllerRust {
    fn default() -> Self {
        // Load config to get saved settings
        let config = crate::core::config::Config::load();
        
        // Check if encrypted credentials exist
        let has_creds = CredentialManager::new()
            .map(|cm| cm.has_credentials())
            .unwrap_or(false);
        
        Self {
            current_screen: QString::from("login"),
            logged_in: false,
            public_key: QString::from(""),
            npub: QString::from(""),
            display_name: QString::from(""),
            profile_picture: QString::from(""),
            is_loading: false,
            error_message: QString::from(""),
            tray_available: false,
            signer_available: false,
            wallet_balance_sats: 0,
            show_global_feed: config.show_global_feed,
            has_saved_credentials: has_creds,
            nwc_connected: false,
        }
    }
}

impl qobject::AppController {
    /// Create a new Nostr account (generate keys)
    pub fn create_account(mut self: Pin<&mut Self>) {
        tracing::info!("Creating new Nostr account...");
        
        self.as_mut().set_is_loading(true);
        self.as_mut().set_error_message(QString::from(""));
        
        match generate_keys() {
            Ok((nsec, npub)) => {
                tracing::info!("Account created successfully: {}", npub);
                self.as_mut().set_is_loading(false);
                self.as_mut().account_created(&QString::from(&nsec), &QString::from(&npub));
            }
            Err(e) => {
                tracing::error!("Failed to create account: {}", e);
                self.as_mut().set_error_message(QString::from(&e));
                self.as_mut().set_is_loading(false);
            }
        }
    }
    
    /// Check if Pleb Signer is available and ready
    pub fn check_signer(mut self: Pin<&mut Self>) {
        tracing::info!("Checking signer availability...");
        
        let available = TOKIO_RUNTIME.block_on(async {
            // Try to create a signer client
            match SignerClient::new("pleb-client").await {
                Ok(client) => {
                    // Check if signer is ready (unlocked)
                    match client.is_ready().await {
                        Ok(ready) => {
                            if ready {
                                // Store the client for later use
                                let mut signer = SIGNER_CLIENT.lock().await;
                                *signer = Some(client);
                                true
                            } else {
                                tracing::info!("Signer found but not unlocked");
                                false
                            }
                        }
                        Err(e) => {
                            tracing::warn!("Failed to check signer status: {}", e);
                            false
                        }
                    }
                }
                Err(e) => {
                    tracing::info!("Pleb Signer not available: {}", e);
                    false
                }
            }
        });
        
        self.as_mut().set_signer_available(available);
        self.as_mut().signer_status_changed(available);
        tracing::info!("Signer available: {}", available);
    }
    
    /// Login via Pleb Signer (preferred method)
    pub fn login_with_signer(mut self: Pin<&mut Self>) {
        tracing::info!("Attempting login via Pleb Signer...");
        
        self.as_mut().set_is_loading(true);
        self.as_mut().set_error_message(QString::from(""));
        
        let result = TOKIO_RUNTIME.block_on(async {
            let signer = SIGNER_CLIENT.lock().await;
            if let Some(client) = signer.as_ref() {
                // Get the public key from signer
                match client.get_public_key().await {
                    Ok(pubkey_result) => {
                        Ok((pubkey_result.pubkey_hex, pubkey_result.npub))
                    }
                    Err(e) => Err(format!("Failed to get public key: {}", e))
                }
            } else {
                Err("Signer not connected".to_string())
            }
        });
        
        match result {
            Ok((pubkey, npub)) => {
                self.as_mut().set_public_key(QString::from(&pubkey));
                self.as_mut().set_npub(QString::from(&npub));
                self.as_mut().set_logged_in(true);
                self.as_mut().set_current_screen(QString::from("feed"));
                self.as_mut().set_display_name(QString::from("Anonymous")); // Will be fetched from profile
                self.as_mut().set_is_loading(false);
                self.as_mut().login_complete(true, &QString::from(""));
                tracing::info!("Login via signer successful: {}", npub);
            }
            Err(e) => {
                self.as_mut().set_error_message(QString::from(&e));
                self.as_mut().set_is_loading(false);
                self.as_mut().login_complete(false, &QString::from(&e));
                tracing::error!("Login via signer failed: {}", e);
            }
        }
    }
    
    /// Login with nsec (fallback for when signer is not available)
    pub fn login_with_nsec(mut self: Pin<&mut Self>, nsec: &QString) {
        let nsec_str = nsec.to_string();
        tracing::info!("Attempting login with nsec...");
        
        self.as_mut().set_is_loading(true);
        self.as_mut().set_error_message(QString::from(""));
        
        // Parse and validate nsec using nostr-sdk
        match parse_nsec(&nsec_str) {
            Ok((_secret_key, pubkey, npub)) => {
                // Set nsec for signing operations in feed and DM bridges
                set_feed_nsec(Some(nsec_str.clone()));
                set_dm_nsec(Some(nsec_str.clone()));
                tracing::info!("Nsec set for signing operations");
                
                self.as_mut().set_public_key(QString::from(&pubkey));
                self.as_mut().set_npub(QString::from(&npub));
                self.as_mut().set_logged_in(true);
                self.as_mut().set_current_screen(QString::from("feed"));
                self.as_mut().set_display_name(QString::from("Anonymous"));
                self.as_mut().set_is_loading(false);
                self.as_mut().login_complete(true, &QString::from(""));
                
                tracing::info!("Login with nsec successful: {}", npub);
            }
            Err(e) => {
                self.as_mut().set_error_message(QString::from(&e));
                self.as_mut().set_is_loading(false);
                self.as_mut().login_complete(false, &QString::from(&e));
                tracing::error!("Login with nsec failed: {}", e);
            }
        }
    }
    
    /// Check for saved credentials (just checks if they exist)
    pub fn check_saved_credentials(mut self: Pin<&mut Self>) {
        tracing::info!("Checking for saved credentials...");
        
        match CredentialManager::new() {
            Ok(creds) => {
                let has_creds = creds.has_credentials();
                self.as_mut().set_has_saved_credentials(has_creds);
                tracing::info!("Saved credentials exist: {}", has_creds);
            }
            Err(e) => {
                tracing::warn!("Credential manager unavailable: {}", e);
                self.as_mut().set_has_saved_credentials(false);
            }
        }
    }
    
    /// Login with password (for stored encrypted credentials)
    pub fn login_with_password(mut self: Pin<&mut Self>, password: &QString) {
        let password_str = password.to_string();
        tracing::info!("Attempting login with password...");
        
        self.as_mut().set_is_loading(true);
        self.as_mut().set_error_message(QString::from(""));
        
        match CredentialManager::new() {
            Ok(creds) => {
                match creds.get_nsec(&password_str) {
                    Ok(Some(nsec)) => {
                        tracing::info!("Successfully decrypted credentials");
                        // Use the nsec to complete login
                        match parse_nsec(&nsec) {
                            Ok((_secret_key, pubkey, npub)) => {
                                set_feed_nsec(Some(nsec.clone()));
                                set_dm_nsec(Some(nsec));
                                
                                self.as_mut().set_public_key(QString::from(&pubkey));
                                self.as_mut().set_npub(QString::from(&npub));
                                self.as_mut().set_logged_in(true);
                                self.as_mut().set_current_screen(QString::from("feed"));
                                self.as_mut().set_display_name(QString::from("Anonymous"));
                                self.as_mut().set_is_loading(false);
                                self.as_mut().login_complete(true, &QString::from(""));
                                tracing::info!("Login with password successful: {}", npub);
                                
                                // Try to reconnect NWC if it was saved
                                let password_for_nwc = password_str.clone();
                                if let Ok(nwc_uri) = creds.get_nwc(&password_for_nwc) {
                                    if let Some(uri) = nwc_uri {
                                        tracing::info!("Found saved NWC, reconnecting...");
                                        // Connect NWC in background
                                        let result = std::thread::spawn(move || {
                                            TOKIO_RUNTIME.block_on(async {
                                                let mut nwc = GLOBAL_NWC_MANAGER.lock().await;
                                                nwc.connect(&uri).await?;
                                                let balance = nwc.balance_sats();
                                                Ok::<_, String>(balance)
                                            })
                                        }).join();
                                        
                                        match result {
                                            Ok(Ok(balance)) => {
                                                tracing::info!("NWC reconnected, balance: {} sats", balance);
                                                self.as_mut().set_wallet_balance_sats(balance);
                                                self.as_mut().set_nwc_connected(true);
                                                self.as_mut().wallet_updated(balance);
                                            }
                                            Ok(Err(e)) => {
                                                tracing::warn!("Failed to reconnect NWC: {}", e);
                                            }
                                            Err(_) => {
                                                tracing::warn!("NWC reconnection thread panicked");
                                            }
                                        }
                                    }
                                }
                            }
                            Err(e) => {
                                self.as_mut().set_error_message(QString::from(&e));
                                self.as_mut().set_is_loading(false);
                                self.as_mut().login_complete(false, &QString::from(&e));
                            }
                        }
                    }
                    Ok(None) => {
                        let err = "No saved credentials found";
                        self.as_mut().set_error_message(QString::from(err));
                        self.as_mut().set_is_loading(false);
                        self.as_mut().login_complete(false, &QString::from(err));
                    }
                    Err(e) => {
                        // Most likely wrong password
                        self.as_mut().set_error_message(QString::from(&e));
                        self.as_mut().set_is_loading(false);
                        self.as_mut().login_complete(false, &QString::from(&e));
                        tracing::warn!("Failed to decrypt credentials: {}", e);
                    }
                }
            }
            Err(e) => {
                self.as_mut().set_error_message(QString::from(&e));
                self.as_mut().set_is_loading(false);
                self.as_mut().login_complete(false, &QString::from(&e));
            }
        }
    }
    
    /// Save nsec with password protection
    pub fn save_credentials_with_password(mut self: Pin<&mut Self>, nsec: &QString, password: &QString) {
        let nsec_str = nsec.to_string();
        let password_str = password.to_string();
        tracing::info!("Saving credentials with password protection...");
        
        match CredentialManager::new() {
            Ok(creds) => {
                match creds.save_nsec(&nsec_str, &password_str) {
                    Ok(()) => {
                        self.as_mut().set_has_saved_credentials(true);
                        self.as_mut().credentials_saved();
                        tracing::info!("Credentials saved with password protection");
                    }
                    Err(e) => {
                        tracing::error!("Failed to save credentials: {}", e);
                        self.as_mut().set_error_message(QString::from(&e));
                    }
                }
            }
            Err(e) => {
                tracing::error!("Credential manager unavailable: {}", e);
            }
        }
    }
    
    /// Clear saved credentials
    pub fn clear_saved_credentials(mut self: Pin<&mut Self>) {
        tracing::info!("Clearing saved credentials...");
        
        match CredentialManager::new() {
            Ok(creds) => {
                if let Err(e) = creds.clear() {
                    tracing::warn!("Failed to clear credentials: {}", e);
                } else {
                    self.as_mut().set_has_saved_credentials(false);
                    tracing::info!("Credentials cleared");
                }
            }
            Err(e) => {
                tracing::warn!("Credential manager unavailable: {}", e);
            }
        }
    }
    
    /// Logout
    pub fn logout(mut self: Pin<&mut Self>) {
        tracing::info!("Logging out...");
        
        // Clear saved credentials
        self.as_mut().clear_saved_credentials();
        
        // Clear signer client
        TOKIO_RUNTIME.block_on(async {
            let mut signer = SIGNER_CLIENT.lock().await;
            *signer = None;
        });
        
        self.as_mut().set_logged_in(false);
        self.as_mut().set_public_key(QString::from(""));
        self.as_mut().set_npub(QString::from(""));
        self.as_mut().set_display_name(QString::from(""));
        self.as_mut().set_profile_picture(QString::from(""));
        self.as_mut().set_signer_available(false);
        self.as_mut().set_has_saved_credentials(false);
        self.as_mut().set_current_screen(QString::from("login"));
    }
    
    /// Navigate to a screen
    pub fn navigate_to(mut self: Pin<&mut Self>, screen: &QString) {
        tracing::info!("Navigating to: {}", screen.to_string());
        self.as_mut().set_current_screen(screen.clone());
    }
    
    /// Refresh the current view
    pub fn refresh(mut self: Pin<&mut Self>) {
        self.as_mut().set_is_loading(true);
        // TODO: Trigger refresh based on current screen
    }
    
    /// Connect NWC wallet
    pub fn connect_nwc(mut self: Pin<&mut Self>, uri: &QString) {
        let uri_str = uri.to_string();
        tracing::info!("Connecting NWC: {}", uri_str);
        
        self.as_mut().set_is_loading(true);
        
        // Connect in background
        let result = std::thread::spawn(move || {
            TOKIO_RUNTIME.block_on(async {
                let mut nwc = GLOBAL_NWC_MANAGER.lock().await;
                nwc.connect(&uri_str).await?;
                let balance = nwc.balance_sats();
                Ok::<_, String>(balance)
            })
        }).join();
        
        match result {
            Ok(Ok(balance)) => {
                tracing::info!("NWC connected, balance: {} sats", balance);
                self.as_mut().set_wallet_balance_sats(balance);
                self.as_mut().set_nwc_connected(true);
                self.as_mut().set_is_loading(false);
                self.as_mut().wallet_updated(balance);
            }
            Ok(Err(e)) => {
                tracing::error!("NWC connection failed: {}", e);
                self.as_mut().set_nwc_connected(false);
                self.as_mut().set_is_loading(false);
                self.as_mut().set_error_message(QString::from(&format!("NWC error: {}", e)));
            }
            Err(_) => {
                tracing::error!("NWC connection thread panicked");
                self.as_mut().set_nwc_connected(false);
                self.as_mut().set_is_loading(false);
                self.as_mut().set_error_message(QString::from("NWC connection failed"));
            }
        }
    }
    
    /// Connect NWC wallet and save to encrypted storage
    pub fn connect_nwc_and_save(mut self: Pin<&mut Self>, uri: &QString, password: &QString) {
        let uri_str = uri.to_string();
        let password_str = password.to_string();
        tracing::info!("Connecting and saving NWC...");
        
        self.as_mut().set_is_loading(true);
        
        // Connect in background
        let result = std::thread::spawn(move || {
            TOKIO_RUNTIME.block_on(async {
                let mut nwc = GLOBAL_NWC_MANAGER.lock().await;
                nwc.connect(&uri_str).await?;
                let balance = nwc.balance_sats();
                Ok::<_, String>((balance, uri_str))
            })
        }).join();
        
        match result {
            Ok(Ok((balance, uri))) => {
                tracing::info!("NWC connected, balance: {} sats", balance);
                
                // Save NWC URI to encrypted storage
                if let Ok(creds) = CredentialManager::new() {
                    if let Err(e) = creds.save_nwc(&uri, &password_str) {
                        tracing::warn!("Failed to save NWC: {}", e);
                        // Still connected, just not persisted
                    } else {
                        tracing::info!("NWC URI saved to encrypted storage");
                    }
                }
                
                self.as_mut().set_wallet_balance_sats(balance);
                self.as_mut().set_nwc_connected(true);
                self.as_mut().set_is_loading(false);
                self.as_mut().wallet_updated(balance);
            }
            Ok(Err(e)) => {
                tracing::error!("NWC connection failed: {}", e);
                self.as_mut().set_nwc_connected(false);
                self.as_mut().set_is_loading(false);
                self.as_mut().set_error_message(QString::from(&format!("NWC error: {}", e)));
            }
            Err(_) => {
                tracing::error!("NWC connection thread panicked");
                self.as_mut().set_nwc_connected(false);
                self.as_mut().set_is_loading(false);
                self.as_mut().set_error_message(QString::from("NWC connection failed"));
            }
        }
    }
    
    /// Disconnect NWC wallet
    pub fn disconnect_nwc(mut self: Pin<&mut Self>) {
        tracing::info!("Disconnecting NWC wallet...");
        
        // Disconnect in background
        let result = std::thread::spawn(move || {
            TOKIO_RUNTIME.block_on(async {
                let mut nwc = GLOBAL_NWC_MANAGER.lock().await;
                nwc.disconnect().await;
            })
        }).join();
        
        if result.is_ok() {
            // Clear saved NWC URI
            if let Ok(creds) = CredentialManager::new() {
                let _ = creds.clear_nwc();
            }
            
            self.as_mut().set_wallet_balance_sats(0);
            self.as_mut().set_nwc_connected(false);
            self.as_mut().wallet_updated(0);
            tracing::info!("NWC wallet disconnected");
        }
    }
    
    /// Check if NWC is connected
    pub fn is_nwc_connected(self: Pin<&mut Self>) -> bool {
        let result = std::thread::spawn(move || {
            TOKIO_RUNTIME.block_on(async {
                let nwc = GLOBAL_NWC_MANAGER.lock().await;
                nwc.is_connected()
            })
        }).join();
        
        result.unwrap_or(false)
    }
    
    /// Set show global feed setting and persist
    pub fn set_show_global_feed_setting(mut self: Pin<&mut Self>, show: bool) {
        tracing::info!("Setting show_global_feed to: {}", show);
        self.as_mut().set_show_global_feed(show);
        
        // Persist to config
        let mut config = crate::core::config::Config::load();
        config.show_global_feed = show;
        if let Err(e) = config.save() {
            tracing::warn!("Failed to save config: {}", e);
        }
    }
    
    /// Minimize to system tray
    pub fn minimize_to_tray(self: Pin<&mut Self>) {
        tracing::info!("Minimize to tray requested");
    }
    
    /// Get configured relays as JSON array
    pub fn get_relays(self: Pin<&mut Self>) -> QString {
        let config = crate::core::config::Config::load();
        let json = serde_json::to_string(&config.relays).unwrap_or_else(|_| "[]".to_string());
        QString::from(&json)
    }
    
    /// Add a relay URL
    pub fn add_relay(self: Pin<&mut Self>, url: &QString) -> bool {
        let url_str = url.to_string().trim().to_string();
        
        // Validate URL format
        if !url_str.starts_with("wss://") && !url_str.starts_with("ws://") {
            tracing::warn!("Invalid relay URL (must start with wss:// or ws://): {}", url_str);
            return false;
        }
        
        let mut config = crate::core::config::Config::load();
        
        // Check if already exists
        if config.relays.iter().any(|r| r == &url_str) {
            tracing::info!("Relay already exists: {}", url_str);
            return false;
        }
        
        config.relays.push(url_str.clone());
        
        if let Err(e) = config.save() {
            tracing::error!("Failed to save config: {}", e);
            return false;
        }
        
        tracing::info!("Added relay: {}", url_str);
        true
    }
    
    /// Remove a relay URL
    pub fn remove_relay(self: Pin<&mut Self>, url: &QString) -> bool {
        let url_str = url.to_string();
        let mut config = crate::core::config::Config::load();
        
        let initial_len = config.relays.len();
        config.relays.retain(|r| r != &url_str);
        
        if config.relays.len() == initial_len {
            tracing::warn!("Relay not found: {}", url_str);
            return false;
        }
        
        if let Err(e) = config.save() {
            tracing::error!("Failed to save config: {}", e);
            return false;
        }
        
        tracing::info!("Removed relay: {}", url_str);
        true
    }
    
    /// Reset relays to default
    pub fn reset_relays_to_default(self: Pin<&mut Self>) {
        let mut config = crate::core::config::Config::load();
        config.relays = vec![
            "wss://relay.pleb.one".to_string(),
            "wss://relay.primal.net".to_string(),
            "wss://relay.damus.io".to_string(),
            "wss://nos.lol".to_string(),
        ];
        
        if let Err(e) = config.save() {
            tracing::error!("Failed to save config: {}", e);
        } else {
            tracing::info!("Reset relays to default");
        }
    }
}

/// Parse an nsec string and extract keys
fn parse_nsec(nsec: &str) -> Result<(String, String, String), String> {
    use nostr_sdk::prelude::*;
    
    // Try to parse as bech32 nsec
    let secret_key = SecretKey::parse(nsec)
        .map_err(|e| format!("Invalid nsec: {}", e))?;
    
    // Get the hex representation before moving the key
    let secret_hex = secret_key.to_secret_hex();
    
    let keys = Keys::new(secret_key);
    let pubkey = keys.public_key().to_hex();
    let npub = keys.public_key().to_bech32()
        .map_err(|e| format!("Failed to encode npub: {}", e))?;
    
    Ok((secret_hex, pubkey, npub))
}

/// Format a hex public key as npub
fn format_npub(hex_pubkey: &str) -> String {
    use nostr_sdk::prelude::*;
    
    match PublicKey::parse(hex_pubkey) {
        Ok(pk) => pk.to_bech32().unwrap_or_else(|_| hex_pubkey.to_string()),
        Err(_) => hex_pubkey.to_string()
    }
}

/// Generate a new keypair for a new Nostr account
fn generate_keys() -> Result<(String, String), String> {
    use nostr_sdk::prelude::*;
    
    // Generate new random keys
    let keys = Keys::generate();
    
    // Get nsec (private key in bech32)
    let nsec = keys.secret_key()
        .to_bech32()
        .map_err(|e| format!("Failed to encode nsec: {}", e))?;
    
    // Get npub (public key in bech32)
    let npub = keys.public_key()
        .to_bech32()
        .map_err(|e| format!("Failed to encode npub: {}", e))?;
    
    Ok((nsec, npub))
}
