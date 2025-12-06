//! DM bridge - exposes direct messages to QML

#[cxx_qt::bridge]
pub mod qobject {
    unsafe extern "C++" {
        include!("cxx-qt-lib/qstring.h");
        type QString = cxx_qt_lib::QString;
    }

    unsafe extern "RustQt" {
        #[qobject]
        #[qml_element]
        #[qproperty(i32, conversation_count)]
        #[qproperty(i32, unread_count)]
        #[qproperty(bool, is_loading)]
        #[qproperty(QString, selected_conversation)]
        #[qproperty(QString, error_message)]
        type DmController = super::DmControllerRust;

        /// Initialize DM controller with user's pubkey
        #[qinvokable]
        fn initialize(self: Pin<&mut DmController>, user_pubkey: &QString);

        /// Load conversations
        #[qinvokable]
        fn load_conversations(self: Pin<&mut DmController>);
        
        /// Get conversation at index (returns JSON)
        #[qinvokable]
        fn get_conversation(self: &DmController, index: i32) -> QString;
        
        /// Select a conversation
        #[qinvokable]
        fn select_conversation(self: Pin<&mut DmController>, peer_pubkey: &QString);
        
        /// Get messages for selected conversation (returns JSON array)
        #[qinvokable]
        fn get_messages(self: &DmController) -> QString;
        
        /// Get message count for selected conversation
        #[qinvokable]
        fn get_message_count(self: &DmController) -> i32;
        
        /// Send a message
        #[qinvokable]
        fn send_message(self: Pin<&mut DmController>, content: &QString);
        
        /// Start new conversation
        #[qinvokable]
        fn start_conversation(self: Pin<&mut DmController>, pubkey: &QString);
        
        /// Toggle protocol (NIP-04 / NIP-17)
        #[qinvokable]
        fn toggle_protocol(self: Pin<&mut DmController>);
        
        /// Get current protocol name
        #[qinvokable]
        fn get_protocol(self: &DmController) -> QString;
        
        /// Refresh conversations
        #[qinvokable]
        fn refresh(self: Pin<&mut DmController>);
    }

    unsafe extern "RustQt" {
        #[qsignal]
        fn conversations_updated(self: Pin<&mut DmController>);
        
        #[qsignal]
        fn messages_updated(self: Pin<&mut DmController>);
        
        #[qsignal]
        fn message_sent(self: Pin<&mut DmController>, message_id: &QString);
        
        #[qsignal]
        fn new_message_received(self: Pin<&mut DmController>, from_pubkey: &QString, preview: &QString);
        
        #[qsignal]
        fn error_occurred(self: Pin<&mut DmController>, error: &QString);
    }
}

use std::pin::Pin;
use std::sync::Arc;
use std::collections::HashMap;
use cxx_qt_lib::QString;
use cxx_qt::CxxQtType;
use nostr_sdk::prelude::*;
use tokio::sync::Mutex;

use crate::signer::SignerClient;
use crate::nostr::dm::{DmManager, DmMessage, DmConversation, DmProtocol, fetch_nip04_dms, get_nip04_peer, format_pubkey_short};
use crate::nostr::relay::DEFAULT_TIMEOUT;
use crate::nostr::profile::ProfileCache;

// Cache duration for DMs (5 minutes)
const DM_CACHE_DURATION_SECS: u64 = 5 * 60;

// Global state
lazy_static::lazy_static! {
    static ref DM_RUNTIME: tokio::runtime::Runtime = tokio::runtime::Runtime::new().unwrap();
    static ref DM_MANAGER: Arc<std::sync::RwLock<DmManager>> = Arc::new(std::sync::RwLock::new(DmManager::new()));
    // Reference to signer client
    static ref DM_SIGNER: Arc<Mutex<Option<SignerClient>>> = Arc::new(Mutex::new(None));
    // Reference to relay client
    static ref DM_CLIENT: Arc<std::sync::RwLock<Option<Client>>> = Arc::new(std::sync::RwLock::new(None));
    // User's nsec for local encryption/signing
    static ref DM_NSEC: Arc<std::sync::RwLock<Option<String>>> = Arc::new(std::sync::RwLock::new(None));
    // Last fetch timestamp for caching
    static ref DM_LAST_FETCH: Arc<std::sync::RwLock<Option<std::time::Instant>>> = Arc::new(std::sync::RwLock::new(None));
}

/// Rust implementation of DmController
pub struct DmControllerRust {
    conversation_count: i32,
    unread_count: i32,
    is_loading: bool,
    selected_conversation: QString,
    error_message: QString,
    
    // Internal state
    user_pubkey: Option<String>,
    user_nsec: Option<String>,
    current_protocol: DmProtocol,
    initialized: bool,
}

impl Default for DmControllerRust {
    fn default() -> Self {
        Self {
            conversation_count: 0,
            unread_count: 0,
            is_loading: false,
            selected_conversation: QString::from(""),
            error_message: QString::from(""),
            user_pubkey: None,
            user_nsec: None,
            current_protocol: DmProtocol::Nip04,
            initialized: false,
        }
    }
}

impl qobject::DmController {
    /// Initialize DM controller with user's pubkey
    pub fn initialize(mut self: Pin<&mut Self>, user_pubkey: &QString) {
        let pubkey_str = user_pubkey.to_string();
        tracing::info!("Initializing DmController for: {}", pubkey_str);
        
        // Check if already initialized with same pubkey
        if self.initialized && self.user_pubkey.as_ref() == Some(&pubkey_str) {
            tracing::info!("DmController already initialized");
            return;
        }
        
        // Store user pubkey
        {
            let mut rust = self.as_mut().rust_mut();
            rust.user_pubkey = Some(pubkey_str.clone());
            rust.initialized = true;
        }
        
        // Initialize DM manager with pubkey
        if let Ok(pk) = PublicKey::parse(&pubkey_str) {
            let mut dm_mgr = DM_MANAGER.write().unwrap();
            dm_mgr.set_user_pubkey(pk);
        }
        
        // Create relay client connection with keys if available for NIP-42 auth
        DM_RUNTIME.block_on(async {
            let client = {
                let nsec_opt = DM_NSEC.read().unwrap();
                if let Some(nsec) = nsec_opt.as_ref() {
                    if let Ok(secret_key) = SecretKey::parse(nsec) {
                        let keys = Keys::new(secret_key);
                        tracing::info!("Creating DM client with signing keys for NIP-42 auth");
                        Client::new(keys)
                    } else {
                        tracing::warn!("Invalid nsec, creating DM client without keys");
                        Client::default()
                    }
                } else {
                    tracing::warn!("No nsec available for DM client, relay auth may fail");
                    Client::default()
                }
            };
            
            // Add default relays
            for relay in crate::nostr::relay::DEFAULT_RELAYS {
                let _ = client.add_relay(*relay).await;
            }
            
            client.connect().await;
            
            let mut c = DM_CLIENT.write().unwrap();
            *c = Some(client);
        });
        
        // Store nsec for encryption
        {
            let nsec_opt = DM_NSEC.read().unwrap();
            if let Some(nsec) = nsec_opt.as_ref() {
                let mut rust = self.as_mut().rust_mut();
                rust.user_nsec = Some(nsec.clone());
            }
        }
        
        tracing::info!("DmController initialized");
    }

    pub fn load_conversations(mut self: Pin<&mut Self>) {
        self.load_conversations_with_cache(false);
    }
    
    /// Load conversations, optionally forcing a network refresh
    fn load_conversations_with_cache(mut self: Pin<&mut Self>, force_refresh: bool) {
        // Check if we have cached data and it's still fresh
        let should_use_cache = if force_refresh {
            false
        } else {
            let last_fetch = DM_LAST_FETCH.read().unwrap();
            if let Some(instant) = *last_fetch {
                let elapsed = instant.elapsed().as_secs();
                if elapsed < DM_CACHE_DURATION_SECS {
                    // Check if we actually have cached conversations
                    let dm_mgr = DM_MANAGER.read().unwrap();
                    !dm_mgr.get_conversations().is_empty()
                } else {
                    false
                }
            } else {
                false
            }
        };
        
        if should_use_cache {
            tracing::info!("Using cached DM conversations");
            let dm_mgr = DM_MANAGER.read().unwrap();
            let count = dm_mgr.get_conversations().len() as i32;
            let unread = dm_mgr.total_unread() as i32;
            drop(dm_mgr);
            
            self.as_mut().set_conversation_count(count);
            self.as_mut().set_unread_count(unread);
            self.as_mut().set_is_loading(false);
            self.as_mut().conversations_updated();
            return;
        }
        
        tracing::info!("Loading DM conversations from network...");
        
        let user_pubkey = match &self.user_pubkey {
            Some(pk) => pk.clone(),
            None => {
                tracing::warn!("Cannot load conversations: not initialized");
                self.as_mut().set_error_message(QString::from("Not initialized"));
                return;
            }
        };
        
        self.as_mut().set_is_loading(true);
        self.as_mut().set_error_message(QString::from(""));
        
        let user_nsec = self.user_nsec.clone();
        
        let result = DM_RUNTIME.block_on(async {
            let pk = PublicKey::parse(&user_pubkey)
                .map_err(|e| format!("Invalid pubkey: {}", e))?;
            
            // Get relay client
            let client = {
                let c = DM_CLIENT.read().unwrap();
                c.clone().ok_or("Not connected to relays")?
            };
            
            // Fetch NIP-04 DMs
            let events = fetch_nip04_dms(&client, &pk, 100).await?;
            
            // Process events into conversations
            let mut conversations: HashMap<String, Vec<(Event, bool)>> = HashMap::new();
            
            for event in events.iter() {
                if let Some(peer_pk) = get_nip04_peer(event, &pk) {
                    let peer_hex = peer_pk.to_hex();
                    let is_outgoing = event.pubkey == pk;
                    conversations.entry(peer_hex).or_default().push((event.clone(), is_outgoing));
                }
            }
            
            // Get unique peer pubkeys for profile fetching
            let peer_pubkeys: Vec<PublicKey> = conversations.keys()
                .filter_map(|hex| PublicKey::parse(hex).ok())
                .collect();
            
            // Fetch profiles
            let profiles = if !peer_pubkeys.is_empty() {
                let profile_filter = Filter::new()
                    .kind(Kind::Metadata)
                    .authors(peer_pubkeys.clone());
                
                client.fetch_events(profile_filter, DEFAULT_TIMEOUT).await.ok()
            } else {
                None
            };
            
            // Parse profiles
            let mut profile_map: HashMap<String, ProfileCache> = HashMap::new();
            if let Some(profile_events) = profiles {
                for event in profile_events.iter() {
                    if let Ok(metadata) = Metadata::from_json(&event.content) {
                        profile_map.insert(event.pubkey.to_hex(), ProfileCache::from_metadata(&metadata));
                    }
                }
            }
            
            Ok::<_, String>((conversations, profile_map, pk, user_nsec))
        });
        
        match result {
            Ok((conversations, profiles, user_pk, nsec_opt)) => {
                let mut dm_mgr = DM_MANAGER.write().unwrap();
                
                // Check if we have a signer or nsec for decryption
                let has_signer = DM_RUNTIME.block_on(async {
                    let signer = DM_SIGNER.lock().await;
                    signer.is_some()
                });
                
                for (peer_hex, events) in conversations {
                    let convo = dm_mgr.get_or_create_conversation(peer_hex.clone(), DmProtocol::Nip04);
                    
                    // Update profile info
                    if let Some(profile) = profiles.get(&peer_hex) {
                        convo.peer_name = profile.display_name.clone().or(profile.name.clone());
                        convo.peer_picture = profile.picture.clone();
                    } else {
                        convo.peer_name = Some(format_pubkey_short(&peer_hex));
                    }
                    
                    // Process messages
                    for (event, is_outgoing) in events {
                        let event_id = event.id.to_hex();
                        
                        // Try to decrypt
                        let content = if has_signer {
                            DM_RUNTIME.block_on(async {
                                let signer = DM_SIGNER.lock().await;
                                if let Some(s) = signer.as_ref() {
                                    let sender_pk = if is_outgoing {
                                        peer_hex.clone()
                                    } else {
                                        event.pubkey.to_hex()
                                    };
                                    s.nip04_decrypt(&event.content, &sender_pk).await.ok()
                                } else {
                                    None
                                }
                            })
                        } else if let Some(ref nsec) = nsec_opt {
                            if let Ok(secret_key) = SecretKey::parse(nsec) {
                                let peer_pk = if is_outgoing {
                                    PublicKey::parse(&peer_hex).ok()
                                } else {
                                    Some(event.pubkey)
                                };
                                
                                if let Some(pk) = peer_pk {
                                    nip04::decrypt(&secret_key, &pk, &event.content).ok()
                                } else {
                                    None
                                }
                            } else {
                                None
                            }
                        } else {
                            None
                        };
                        
                        let display_content = content.unwrap_or_else(|| "[Encrypted message]".to_string());
                        
                        let msg = DmMessage {
                            id: event_id,
                            sender_pubkey: event.pubkey.to_hex(),
                            recipient_pubkey: if is_outgoing { peer_hex.clone() } else { user_pk.to_hex() },
                            content: display_content,
                            created_at: event.created_at.as_secs() as i64,
                            is_outgoing,
                            protocol: DmProtocol::Nip04,
                        };
                        
                        dm_mgr.add_message(msg);
                    }
                }
                
                let count = dm_mgr.get_conversations().len() as i32;
                let unread = dm_mgr.total_unread() as i32;
                
                drop(dm_mgr);
                
                // Update cache timestamp
                {
                    let mut last_fetch = DM_LAST_FETCH.write().unwrap();
                    *last_fetch = Some(std::time::Instant::now());
                }
                
                self.as_mut().set_conversation_count(count);
                self.as_mut().set_unread_count(unread);
                self.as_mut().set_is_loading(false);
                self.as_mut().conversations_updated();
                
                tracing::info!("Loaded {} conversations", count);
            }
            Err(e) => {
                tracing::error!("Failed to load conversations: {}", e);
                self.as_mut().set_error_message(QString::from(&e));
                self.as_mut().set_is_loading(false);
                self.as_mut().error_occurred(&QString::from(&e));
            }
        }
    }
    
    pub fn get_conversation(&self, index: i32) -> QString {
        let dm_mgr = DM_MANAGER.read().unwrap();
        let convos = dm_mgr.get_conversations();
        
        if let Some(convo) = convos.get(index as usize) {
            QString::from(&convo.to_json())
        } else {
            QString::from("{}")
        }
    }
    
    pub fn select_conversation(mut self: Pin<&mut Self>, peer_pubkey: &QString) {
        let pubkey_str = peer_pubkey.to_string();
        tracing::info!("Selecting conversation with: {}", pubkey_str);
        
        self.as_mut().set_selected_conversation(peer_pubkey.clone());
        
        // Mark as read
        {
            let mut dm_mgr = DM_MANAGER.write().unwrap();
            dm_mgr.mark_read(&pubkey_str);
            
            // Update protocol based on conversation
            if let Some(convo) = dm_mgr.get_conversation(&pubkey_str) {
                let mut rust = self.as_mut().rust_mut();
                rust.current_protocol = convo.protocol;
            }
        }
        
        // Update unread count
        let unread = {
            let dm_mgr = DM_MANAGER.read().unwrap();
            dm_mgr.total_unread() as i32
        };
        self.as_mut().set_unread_count(unread);
        self.as_mut().messages_updated();
    }
    
    pub fn get_messages(&self) -> QString {
        let selected = self.selected_conversation.to_string();
        if selected.is_empty() {
            return QString::from("[]");
        }
        
        let dm_mgr = DM_MANAGER.read().unwrap();
        if let Some(convo) = dm_mgr.get_conversation(&selected) {
            let messages_json: Vec<serde_json::Value> = convo.messages.iter()
                .map(|m| m.to_json())
                .collect();
            QString::from(&serde_json::to_string(&messages_json).unwrap_or_else(|_| "[]".to_string()))
        } else {
            QString::from("[]")
        }
    }
    
    pub fn get_message_count(&self) -> i32 {
        let selected = self.selected_conversation.to_string();
        if selected.is_empty() {
            return 0;
        }
        
        let dm_mgr = DM_MANAGER.read().unwrap();
        if let Some(convo) = dm_mgr.get_conversation(&selected) {
            convo.messages.len() as i32
        } else {
            0
        }
    }
    
    pub fn send_message(mut self: Pin<&mut Self>, content: &QString) {
        let content_str = content.to_string();
        let selected = self.selected_conversation.to_string();
        
        if selected.is_empty() {
            tracing::warn!("No conversation selected");
            return;
        }
        
        tracing::info!("Sending DM to {}", selected);
        
        self.as_mut().set_is_loading(true);
        
        let protocol = self.current_protocol;
        let user_pubkey = self.user_pubkey.clone();
        let user_nsec = self.user_nsec.clone();
        
        let result = DM_RUNTIME.block_on(async {
            let recipient_pk = PublicKey::parse(&selected)
                .map_err(|e| format!("Invalid recipient pubkey: {}", e))?;
            
            let user_pk = user_pubkey.as_ref()
                .and_then(|pk| PublicKey::parse(pk).ok())
                .ok_or("User not initialized")?;
            
            // Get client
            let client = {
                let c = DM_CLIENT.read().unwrap();
                c.clone().ok_or("Not connected to relays")?
            };
            
            // Try signer first, then local keys
            let signer = DM_SIGNER.lock().await;
            
            if let Some(s) = signer.as_ref() {
                // Use signer
                let ciphertext = s.nip04_encrypt(&content_str, &selected).await
                    .map_err(|e| format!("Encryption failed: {}", e))?;
                
                let tags = vec![Tag::public_key(recipient_pk)];
                let unsigned = EventBuilder::new(Kind::EncryptedDirectMessage, &ciphertext)
                    .tags(tags)
                    .build(user_pk);
                
                let unsigned_json = serde_json::to_string(&unsigned)
                    .map_err(|e| format!("Serialization failed: {}", e))?;
                
                let signed_result = s.sign_event(&unsigned_json).await
                    .map_err(|e| format!("Signing failed: {}", e))?;
                
                let signed_event: Event = serde_json::from_str(&signed_result.event_json)
                    .map_err(|e| format!("Failed to parse signed event: {}", e))?;
                
                client.send_event(&signed_event).await
                    .map_err(|e| format!("Failed to send: {}", e))?;
                
                Ok::<String, String>(signed_event.id.to_hex())
            } else if let Some(ref nsec) = user_nsec {
                // Use local keys
                let secret_key = SecretKey::parse(nsec)
                    .map_err(|e| format!("Invalid nsec: {}", e))?;
                let keys = Keys::new(secret_key);
                
                let ciphertext = nip04::encrypt(keys.secret_key(), &recipient_pk, &content_str)
                    .map_err(|e| format!("Encryption failed: {}", e))?;
                
                // Build the NIP-04 DM event manually
                let tags = vec![Tag::public_key(recipient_pk)];
                let event = EventBuilder::new(Kind::EncryptedDirectMessage, &ciphertext)
                    .tags(tags)
                    .sign_with_keys(&keys)
                    .map_err(|e| format!("Failed to sign: {}", e))?;
                
                client.send_event(&event).await
                    .map_err(|e| format!("Failed to send: {}", e))?;
                
                Ok(event.id.to_hex())
            } else {
                Err("No signing capability available".to_string())
            }
        });
        
        match result {
            Ok(event_id) => {
                tracing::info!("DM sent: {}", event_id);
                
                let msg = DmMessage {
                    id: event_id.clone(),
                    sender_pubkey: user_pubkey.unwrap_or_default(),
                    recipient_pubkey: selected,
                    content: content_str,
                    created_at: chrono::Utc::now().timestamp(),
                    is_outgoing: true,
                    protocol,
                };
                
                {
                    let mut dm_mgr = DM_MANAGER.write().unwrap();
                    dm_mgr.add_message(msg);
                }
                
                self.as_mut().set_is_loading(false);
                self.as_mut().message_sent(&QString::from(&event_id));
                self.as_mut().messages_updated();
            }
            Err(e) => {
                tracing::error!("Failed to send DM: {}", e);
                self.as_mut().set_error_message(QString::from(&e));
                self.as_mut().set_is_loading(false);
                self.as_mut().error_occurred(&QString::from(&e));
            }
        }
    }
    
    pub fn start_conversation(mut self: Pin<&mut Self>, pubkey: &QString) {
        let pubkey_str = pubkey.to_string();
        tracing::info!("Starting conversation with: {}", pubkey_str);
        
        // Parse pubkey (could be npub or hex)
        let hex_pubkey = if pubkey_str.starts_with("npub") {
            match PublicKey::from_bech32(&pubkey_str) {
                Ok(pk) => pk.to_hex(),
                Err(e) => {
                    self.as_mut().set_error_message(QString::from(&format!("Invalid npub: {}", e)));
                    self.as_mut().error_occurred(&QString::from(&format!("Invalid npub: {}", e)));
                    return;
                }
            }
        } else {
            match PublicKey::parse(&pubkey_str) {
                Ok(pk) => pk.to_hex(),
                Err(e) => {
                    self.as_mut().set_error_message(QString::from(&format!("Invalid pubkey: {}", e)));
                    self.as_mut().error_occurred(&QString::from(&format!("Invalid pubkey: {}", e)));
                    return;
                }
            }
        };
        
        // Create or get conversation
        {
            let mut dm_mgr = DM_MANAGER.write().unwrap();
            let convo = dm_mgr.get_or_create_conversation(hex_pubkey.clone(), self.current_protocol);
            
            if convo.peer_name.is_none() {
                convo.peer_name = Some(format_pubkey_short(&hex_pubkey));
            }
        }
        
        let count = {
            let dm_mgr = DM_MANAGER.read().unwrap();
            dm_mgr.get_conversations().len() as i32
        };
        
        self.as_mut().set_conversation_count(count);
        self.as_mut().set_selected_conversation(QString::from(&hex_pubkey));
        self.as_mut().conversations_updated();
        self.as_mut().messages_updated();
    }
    
    pub fn toggle_protocol(mut self: Pin<&mut Self>) {
        let mut rust = self.rust_mut();
        rust.current_protocol = match rust.current_protocol {
            DmProtocol::Nip04 => DmProtocol::Nip17,
            DmProtocol::Nip17 => DmProtocol::Nip04,
        };
        tracing::info!("Toggled protocol to: {:?}", rust.current_protocol);
    }
    
    pub fn get_protocol(&self) -> QString {
        match self.current_protocol {
            DmProtocol::Nip04 => QString::from("NIP-04"),
            DmProtocol::Nip17 => QString::from("NIP-17"),
        }
    }
    
    pub fn refresh(mut self: Pin<&mut Self>) {
        tracing::info!("Refreshing DMs (forcing network fetch)...");
        self.load_conversations_with_cache(true);
    }
}

/// Set the signer client for DM encryption/decryption
pub fn set_dm_signer(signer: Option<SignerClient>) {
    DM_RUNTIME.block_on(async {
        let mut dm_signer = DM_SIGNER.lock().await;
        *dm_signer = signer;
    });
}

/// Set the user's nsec for local encryption
pub fn set_dm_nsec(nsec: Option<String>) {
    let mut dm_nsec = DM_NSEC.write().unwrap();
    *dm_nsec = nsec;
    tracing::info!("DM nsec set for encryption/signing operations");
}
