//! Feed bridge - exposes feed/notes to QML

#[cxx_qt::bridge]
pub mod qobject {
    unsafe extern "C++" {
        include!("cxx-qt-lib/qstring.h");
        type QString = cxx_qt_lib::QString;
        
        include!("cxx-qt-lib/qstringlist.h");
        type QStringList = cxx_qt_lib::QStringList;
    }

    unsafe extern "RustQt" {
        #[qobject]
        #[qml_element]
        #[qproperty(i32, note_count)]
        #[qproperty(bool, is_loading)]
        #[qproperty(QString, current_feed)]
        #[qproperty(QString, error_message)]
        #[qproperty(i32, thread_count)]
        #[qproperty(QString, thread_note_id)]
        #[qproperty(QString, loading_status)]
        type FeedController = super::FeedControllerRust;

        /// Initialize the feed controller (called after login)
        #[qinvokable]
        fn initialize(self: Pin<&mut FeedController>, user_pubkey: &QString);
        
        /// Load a feed type (following, replies, global)
        #[qinvokable]
        fn load_feed(self: Pin<&mut FeedController>, feed_type: &QString);
        
        /// Load more notes (pagination)
        #[qinvokable]
        fn load_more(self: Pin<&mut FeedController>);
        
        /// Check for new notes (prepend without clearing)
        #[qinvokable]
        fn check_for_new(self: Pin<&mut FeedController>);
        
        /// Refresh the current feed
        #[qinvokable]
        fn refresh(self: Pin<&mut FeedController>);
        
        /// Get note at index (returns JSON for simplicity)
        #[qinvokable]
        fn get_note(self: &FeedController, index: i32) -> QString;
        
        /// Load thread for a specific note
        #[qinvokable]
        fn load_thread(self: Pin<&mut FeedController>, note_id: &QString);
        
        /// Get thread note at index (returns JSON)
        #[qinvokable]
        fn get_thread_note(self: &FeedController, index: i32) -> QString;
        
        /// Clear thread view
        #[qinvokable]
        fn clear_thread(self: Pin<&mut FeedController>);
        
        /// Like a note
        #[qinvokable]
        fn like_note(self: Pin<&mut FeedController>, note_id: &QString);
        
        /// React to a note with a custom emoji (kind 7 reaction)
        #[qinvokable]
        fn react_to_note(self: Pin<&mut FeedController>, note_id: &QString, emoji: &QString);
        
        /// Fetch reactions and zap stats for a specific note (async - non-blocking)
        /// Returns cached stats immediately if available, otherwise returns loading state and fetches in background
        /// Use get_cached_note_stats() with a timer to poll for results
        #[qinvokable]
        fn fetch_note_stats(self: Pin<&mut FeedController>, note_id: &QString) -> QString;
        
        /// Get cached note stats (non-blocking, read-only)
        /// Returns cached stats or loading state if fetch is in progress
        #[qinvokable]
        fn get_cached_note_stats(self: &FeedController, note_id: &QString) -> QString;
        
        /// Repost a note
        #[qinvokable]
        fn repost_note(self: Pin<&mut FeedController>, note_id: &QString);
        
        /// Reply to a note
        #[qinvokable]
        fn reply_to_note(self: Pin<&mut FeedController>, note_id: &QString, content: &QString);
        
        /// Zap a note
        #[qinvokable]
        fn zap_note(self: Pin<&mut FeedController>, note_id: &QString, amount_sats: i64, comment: &QString);
        
        /// Post a new note
        #[qinvokable]
        fn post_note(self: Pin<&mut FeedController>, content: &QString);
        
        /// Post a new note with media attachments
        /// media_urls is a JSON array of media URLs to attach
        #[qinvokable]
        fn post_note_with_media(self: Pin<&mut FeedController>, content: &QString, media_urls: &QString);
        
        /// Upload media to Blossom server
        /// Returns JSON with url on success, or error message
        #[qinvokable]
        fn upload_media(self: Pin<&mut FeedController>, file_path: &QString) -> QString;
        
        /// Get the configured Blossom server URL
        #[qinvokable]
        fn get_blossom_server(self: &FeedController) -> QString;
        
        /// Set the Blossom server URL
        #[qinvokable]
        fn set_blossom_server(self: Pin<&mut FeedController>, url: &QString);

        /// Fetch an embedded nostr event by nevent/naddr/note bech32 string
        /// Returns JSON with the note data or empty if not found
        #[qinvokable]
        fn fetch_embedded_event(self: Pin<&mut FeedController>, nostr_uri: &QString) -> QString;
        
        /// Fetch an embedded nostr profile by nprofile/npub bech32 string
        /// Returns JSON with profile data or empty if not found
        #[qinvokable]
        fn fetch_embedded_profile(self: Pin<&mut FeedController>, nostr_uri: &QString) -> QString;
        
        /// Fetch link preview metadata for a URL
        /// Returns JSON with title, description, image, siteName
        #[qinvokable]
        fn fetch_link_preview(self: Pin<&mut FeedController>, url: &QString) -> QString;
    }

    unsafe extern "RustQt" {
        /// Emitted when feed is updated
        #[qsignal]
        fn feed_updated(self: Pin<&mut FeedController>);
        
        /// Emitted when more notes are loaded
        #[qsignal]
        fn more_loaded(self: Pin<&mut FeedController>, count: i32);
        
        /// Emitted when new notes are found at the top
        #[qsignal]
        fn new_notes_found(self: Pin<&mut FeedController>, count: i32);
        
        /// Emitted when thread is loaded
        #[qsignal]
        fn thread_loaded(self: Pin<&mut FeedController>);
        
        /// Emitted when a note is posted
        #[qsignal]
        fn note_posted(self: Pin<&mut FeedController>, note_id: &QString);
        
        /// Emitted when media upload completes
        #[qsignal]
        fn media_uploaded(self: Pin<&mut FeedController>, url: &QString);
        
        /// Emitted when media upload fails
        #[qsignal]
        fn media_upload_failed(self: Pin<&mut FeedController>, error: &QString);

        /// Emitted when an error occurs
        #[qsignal]
        fn error_occurred(self: Pin<&mut FeedController>, error: &QString);
        
        /// Emitted when loading state changes
        #[qsignal]
        fn loading_changed(self: Pin<&mut FeedController>, loading: bool);
        
        /// Emitted when a zap is successful (amount in sats)
        #[qsignal]
        fn zap_success(self: Pin<&mut FeedController>, note_id: &QString, amount_sats: i64);
        
        /// Emitted when a zap fails
        #[qsignal]
        fn zap_failed(self: Pin<&mut FeedController>, note_id: &QString, error: &QString);
        
        /// Emitted when note stats are fetched (async)
        /// stats_json contains: {reactions: {emoji: count}, zapAmount: sats, zapCount: number}
        #[qsignal]
        fn note_stats_ready(self: Pin<&mut FeedController>, note_id: &QString, stats_json: &QString);
    }
}

use std::pin::Pin;
use std::sync::Arc;
use cxx_qt_lib::QString;
use cxx_qt::CxxQtType;
use nostr_sdk::prelude::*;
use tokio::sync::Mutex;
use crate::nostr::{
    database::NostrDbManager,
    relay::{RelayManager, SharedRelayManager, create_shared_relay_manager},
    feed::DisplayNote,
    profile::ProfileCache,
    blossom,
    zap::{self, GLOBAL_NWC_MANAGER},
};
use crate::core::config::Config;
use crate::signer::SignerClient;

/// Feed types
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum FeedType {
    Following, // Just posts from following (no replies)
    Replies,   // Combined following + replies (home experience)
    Global,
}

impl FeedType {
    pub fn from_str(s: &str) -> Self {
        match s.to_lowercase().as_str() {
            "following" => FeedType::Following,
            "replies" => FeedType::Replies,
            "global" => FeedType::Global,
            _ => FeedType::Following,
        }
    }
}

// Global state for async operations
lazy_static::lazy_static! {
    static ref RELAY_MANAGER: SharedRelayManager = create_shared_relay_manager();
    static ref FEED_RUNTIME: tokio::runtime::Runtime = tokio::runtime::Runtime::new().unwrap();
    // Prefetched feed cache - keyed by feed type string
    static ref FEED_CACHE: std::sync::RwLock<std::collections::HashMap<String, Vec<DisplayNote>>> = 
        std::sync::RwLock::new(std::collections::HashMap::new());
    // Signer client for signing events
    static ref FEED_SIGNER: Arc<Mutex<Option<SignerClient>>> = Arc::new(Mutex::new(None));
    // User's nsec for local signing (fallback)
    static ref FEED_NSEC: Arc<std::sync::RwLock<Option<String>>> = Arc::new(std::sync::RwLock::new(None));
    
    // Caches for embedded content to avoid blocking UI during scroll
    // Embedded event cache - keyed by nostr URI (nevent/note/naddr)
    static ref EMBEDDED_EVENT_CACHE: std::sync::RwLock<std::collections::HashMap<String, String>> = 
        std::sync::RwLock::new(std::collections::HashMap::new());
    // Embedded profile cache - keyed by nostr URI (nprofile/npub)
    static ref EMBEDDED_PROFILE_CACHE: std::sync::RwLock<std::collections::HashMap<String, String>> = 
        std::sync::RwLock::new(std::collections::HashMap::new());
    // Link preview cache - keyed by URL
    static ref LINK_PREVIEW_CACHE: std::sync::RwLock<std::collections::HashMap<String, String>> = 
        std::sync::RwLock::new(std::collections::HashMap::new());
    // Track pending fetches to avoid duplicate requests
    static ref PENDING_EMBEDS: std::sync::RwLock<std::collections::HashSet<String>> = 
        std::sync::RwLock::new(std::collections::HashSet::new());
    // Note stats cache - keyed by note ID
    static ref NOTE_STATS_CACHE: std::sync::RwLock<std::collections::HashMap<String, String>> = 
        std::sync::RwLock::new(std::collections::HashMap::new());
    // Track pending stats fetches to avoid duplicate requests
    static ref PENDING_STATS: std::sync::RwLock<std::collections::HashSet<String>> = 
        std::sync::RwLock::new(std::collections::HashSet::new());
}

/// Prefetch a feed in the background and cache it
fn prefetch_feed(feed_type: FeedType) {
    let feed_name = match feed_type {
        FeedType::Following => "following",
        FeedType::Replies => "replies",
        FeedType::Global => "global",
    };
    
    std::thread::spawn(move || {
        tracing::info!("Background prefetching {} feed...", feed_name);
        
        let result = FEED_RUNTIME.block_on(async {
            let rm = RELAY_MANAGER.read().unwrap();
            let Some(manager) = rm.as_ref() else {
                return Err("Relay manager not initialized".to_string());
            };
            
            let limit = 50u64;
            let events = match feed_type {
                FeedType::Following => manager.fetch_following_feed(limit, None).await?,
                FeedType::Replies => manager.fetch_home_feed(limit, None).await?,
                FeedType::Global => manager.fetch_global_feed(limit, None).await?,
            };
            
            // Fetch profiles
            let pubkeys: Vec<PublicKey> = events
                .iter()
                .map(|e| e.pubkey)
                .collect::<std::collections::HashSet<_>>()
                .into_iter()
                .collect();
            
            let profiles = manager.fetch_profiles(&pubkeys).await.unwrap_or_default();
            
            let mut profile_map = std::collections::HashMap::new();
            for profile_event in profiles.iter() {
                if let Ok(metadata) = Metadata::from_json(&profile_event.content) {
                    let pubkey_hex = profile_event.pubkey.to_hex();
                    profile_map.insert(pubkey_hex, ProfileCache::from_metadata(&metadata));
                }
            }
            
            let mut notes: Vec<DisplayNote> = events
                .iter()
                .map(|e| {
                    let pubkey_hex = e.pubkey.to_hex();
                    let profile = profile_map.get(&pubkey_hex);
                    DisplayNote::from_event(e, profile)
                })
                .collect();
            
            notes.sort_by(|a, b| b.created_at.cmp(&a.created_at));
            Ok(notes)
        });
        
        match result {
            Ok(notes) => {
                let count = notes.len();
                if let Ok(mut cache) = FEED_CACHE.write() {
                    cache.insert(feed_name.to_string(), notes);
                    tracing::info!("Prefetched {} notes for {} feed", count, feed_name);
                }
            }
            Err(e) => {
                tracing::warn!("Failed to prefetch {} feed: {}", feed_name, e);
            }
        }
    });
}

/// Rust implementation of FeedController
#[derive(Default)]
pub struct FeedControllerRust {
    note_count: i32,
    is_loading: bool,
    current_feed: QString,
    error_message: QString,
    thread_count: i32,
    thread_note_id: QString,
    loading_status: QString,
    
    // Internal state
    notes: Vec<DisplayNote>,
    thread_notes: Vec<DisplayNote>,  // Thread view: parents + target + replies
    user_pubkey: Option<String>,
    initialized: bool,
}

impl qobject::FeedController {
    /// Initialize the feed controller with user's pubkey
    pub fn initialize(mut self: Pin<&mut Self>, user_pubkey: &QString) {
        // Check if already initialized - access the field directly
        if self.initialized {
            tracing::info!("FeedController already initialized, skipping");
            return;
        }
        
        let pubkey_str = user_pubkey.to_string();
        tracing::info!("Initializing FeedController for user: {}", pubkey_str);
        
        self.as_mut().set_is_loading(true);
        self.as_mut().set_loading_status(QString::from("Connecting to relays..."));
        
        // Store pubkey
        {
            let mut rust = self.as_mut().rust_mut();
            rust.user_pubkey = Some(pubkey_str.clone());
        }
        
        // Initialize database and relay manager
        let init_result = FEED_RUNTIME.block_on(async {
            // Initialize database singleton
            if let Err(e) = NostrDbManager::global() {
                tracing::error!("Failed to initialize database: {}", e);
                // Continue anyway - we can work without local caching
            } else {
                tracing::info!("NostrDB initialized successfully");
            }
            
            // Initialize relay manager - use keys if nsec is available for NIP-42 auth
            let mut manager = {
                let nsec_opt = FEED_NSEC.read().unwrap();
                if let Some(nsec) = nsec_opt.as_ref() {
                    if let Ok(secret_key) = SecretKey::parse(nsec) {
                        let keys = Keys::new(secret_key);
                        tracing::info!("Creating relay manager with signing keys for NIP-42 auth");
                        RelayManager::with_keys(keys)
                    } else {
                        tracing::warn!("Invalid nsec, creating relay manager without keys");
                        RelayManager::new()
                    }
                } else {
                    tracing::warn!("No nsec available, relay authentication may fail");
                    RelayManager::new()
                }
            };
            
            // Set user pubkey
            if let Ok(pk) = PublicKey::parse(&pubkey_str) {
                manager.set_user_pubkey(pk);
                
                // Connect to relays
                if let Err(e) = manager.connect().await {
                    return Err(format!("Failed to connect to relays: {}", e));
                }
                
                // Fetch contact list
                if let Err(e) = manager.fetch_contact_list(&pk).await {
                    tracing::warn!("Failed to fetch contact list: {}", e);
                    // Continue - user might not follow anyone yet
                }
            }
            
            // Store relay manager
            let mut rm = RELAY_MANAGER.write().unwrap();
            *rm = Some(manager);
            
            Ok(())
        });
        
        match init_result {
            Ok(()) => {
                {
                    let mut rust = self.as_mut().rust_mut();
                    rust.initialized = true;
                }
                self.as_mut().set_is_loading(false);
                tracing::info!("FeedController initialized successfully");
                
                // Prefetch other feeds in the background
                // Following feed will be loaded immediately after init
                prefetch_feed(FeedType::Replies);
                prefetch_feed(FeedType::Global);
            }
            Err(e) => {
                self.as_mut().set_error_message(QString::from(&e));
                self.as_mut().set_is_loading(false);
                self.as_mut().error_occurred(&QString::from(&e));
            }
        }
    }
    
    /// Load a feed type
    pub fn load_feed(mut self: Pin<&mut Self>, feed_type: &QString) {
        let feed_type_str = feed_type.to_string();
        tracing::info!("Loading feed: {}", feed_type_str);
        
        self.as_mut().set_current_feed(feed_type.clone());
        
        // Check if we have this feed cached already
        if let Ok(cache) = FEED_CACHE.read() {
            if let Some(cached_notes) = cache.get(&feed_type_str) {
                if !cached_notes.is_empty() {
                    tracing::info!("Using cached {} feed ({} notes)", feed_type_str, cached_notes.len());
                    let notes = cached_notes.clone();
                    let count = notes.len() as i32;
                    {
                        let mut rust = self.as_mut().rust_mut();
                        rust.notes = notes;
                        rust.note_count = count;
                    }
                    self.as_mut().set_note_count(count);
                    self.as_mut().set_is_loading(false);
                    self.as_mut().set_error_message(QString::from(""));
                    self.as_mut().set_loading_status(QString::from(""));
                    self.as_mut().loading_changed(false);
                    self.as_mut().feed_updated();
                    return;
                }
            }
        }
        
        // No cache - load from network
        self.as_mut().set_is_loading(true);
        self.as_mut().set_loading_status(QString::from("Fetching notes..."));
        self.as_mut().loading_changed(true);
        
        let feed = FeedType::from_str(&feed_type_str);
        
        let result = FEED_RUNTIME.block_on(async {
            let rm = RELAY_MANAGER.read().unwrap();
            let Some(manager) = rm.as_ref() else {
                return Err("Relay manager not initialized. Please log in first.".to_string());
            };
            
            // Fetch feed based on type
            let limit = 50u64;
            let events = match feed {
                FeedType::Following => manager.fetch_following_feed(limit, None).await?,
                FeedType::Replies => manager.fetch_home_feed(limit, None).await?,
                FeedType::Global => manager.fetch_global_feed(limit, None).await?,
            };
            
            // Collect unique pubkeys for profile fetching
            let pubkeys: Vec<PublicKey> = events
                .iter()
                .map(|e| e.pubkey)
                .collect::<std::collections::HashSet<_>>()
                .into_iter()
                .collect();
            
            // Fetch profiles
            let profiles = manager.fetch_profiles(&pubkeys).await.unwrap_or_default();
            
            // Parse profiles into cache
            let mut profile_map = std::collections::HashMap::new();
            for profile_event in profiles.iter() {
                if let Ok(metadata) = Metadata::from_json(&profile_event.content) {
                    let pubkey_hex = profile_event.pubkey.to_hex();
                    profile_map.insert(pubkey_hex, ProfileCache::from_metadata(&metadata));
                }
            }
            
            // Store in nostrdb cache using the global singleton
            // TEMPORARILY DISABLED - nostrdb causing segfaults
            // if let Ok(db) = NostrDbManager::global() {
            //     // Ingest events in batch
            //     let event_vec: Vec<Event> = events.iter().cloned().collect();
            //     match db.ingest_events(&event_vec) {
            //         Ok(count) => tracing::debug!("Cached {} new events", count),
            //         Err(e) => tracing::warn!("Failed to cache events: {}", e),
            //     }
            //     
            //     // Ingest profiles in batch
            //     let profile_vec: Vec<Event> = profiles.iter().cloned().collect();
            //     match db.ingest_profiles(&profile_vec) {
            //         Ok(count) => tracing::debug!("Cached {} profiles", count),
            //         Err(e) => tracing::warn!("Failed to cache profiles: {}", e),
            //     }
            // }
            
            // Convert to display notes
            let notes: Vec<DisplayNote> = events
                .iter()
                .map(|e| {
                    let pubkey_hex = e.pubkey.to_hex();
                    let profile = profile_map.get(&pubkey_hex);
                    DisplayNote::from_event(e, profile)
                })
                .collect();
            
            Ok(notes)
        });
        
        match result {
            Ok(mut notes) => {
                // Sort by timestamp descending
                notes.sort_by(|a, b| b.created_at.cmp(&a.created_at));
                
                // Cache the results
                if let Ok(mut cache) = FEED_CACHE.write() {
                    cache.insert(feed_type_str.clone(), notes.clone());
                }
                
                let count = notes.len() as i32;
                {
                    let mut rust = self.as_mut().rust_mut();
                    rust.notes = notes;
                    rust.note_count = count;
                }
                self.as_mut().set_note_count(count);
                self.as_mut().set_is_loading(false);
                self.as_mut().set_loading_status(QString::from(""));
                self.as_mut().set_error_message(QString::from(""));
                self.as_mut().loading_changed(false);
                self.as_mut().feed_updated();
                
                tracing::info!("Loaded {} notes for {} feed", count, feed_type_str);
            }
            Err(e) => {
                tracing::error!("Failed to load feed: {}", e);
                self.as_mut().set_error_message(QString::from(&e));
                self.as_mut().set_is_loading(false);
                self.as_mut().set_loading_status(QString::from(""));
                self.as_mut().loading_changed(false);
                self.as_mut().error_occurred(&QString::from(&e));
            }
        }
    }
    
    /// Load more notes (pagination) - fetch older notes
    pub fn load_more(mut self: Pin<&mut Self>) {
        // Prevent re-entry while loading
        if *self.is_loading() {
            tracing::debug!("load_more called while already loading, ignoring");
            return;
        }
        
        let (oldest_timestamp, current_feed_type) = {
            let rust = self.as_ref();
            if rust.notes.is_empty() {
                tracing::warn!("No notes to paginate from");
                return;
            }
            let oldest = rust.notes.last().map(|n| n.created_at).unwrap_or(0);
            (oldest, rust.current_feed.to_string())
        };
        
        if oldest_timestamp <= 0 {
            tracing::warn!("Invalid timestamp for pagination: {}", oldest_timestamp);
            return;
        }
        
        // Check if we already have 24 hours of data
        let newest_timestamp = {
            let rust = self.as_ref();
            rust.notes.first().map(|n| n.created_at).unwrap_or(0)
        };
        
        let hours_covered = if newest_timestamp > 0 && oldest_timestamp > 0 {
            (newest_timestamp - oldest_timestamp) / 3600 // seconds to hours
        } else {
            0
        };
        
        tracing::info!("Current feed coverage: {} hours ({} to {})", 
            hours_covered, oldest_timestamp, newest_timestamp);
        
        self.as_mut().set_is_loading(true);
        self.as_mut().loading_changed(true);
        
        let feed = FeedType::from_str(&current_feed_type);
        
        tracing::info!("Loading more for {} feed, before timestamp {}", current_feed_type, oldest_timestamp);
        
        // Spawn thread to avoid Qt/tokio conflicts (same pattern as check_for_new)
        let result = std::thread::spawn(move || {
            FEED_RUNTIME.block_on(async {
                let rm = RELAY_MANAGER.read().unwrap();
                let Some(manager) = rm.as_ref() else {
                    return Err("Relay manager not initialized".to_string());
                };
                
                // Use timestamp - 1 to avoid duplicates
                let until = Some(Timestamp::from((oldest_timestamp - 1) as u64));
                let limit = 50u64;
                
                let events = match feed {
                    FeedType::Following => manager.fetch_following_feed(limit, until).await?,
                    FeedType::Replies => manager.fetch_home_feed(limit, until).await?,
                    FeedType::Global => manager.fetch_global_feed(limit, until).await?,
                };
                
                tracing::info!("Fetched {} older events for {} feed", events.len(), 
                    match feed { FeedType::Following => "following", FeedType::Replies => "replies", FeedType::Global => "global" });
                
                // Fetch profiles for new authors
                let pubkeys: Vec<PublicKey> = events
                    .iter()
                    .map(|e| e.pubkey)
                    .collect::<std::collections::HashSet<_>>()
                    .into_iter()
                    .collect();
                
                let profiles = manager.fetch_profiles(&pubkeys).await.unwrap_or_default();
                
                let mut profile_map = std::collections::HashMap::new();
                for profile_event in profiles.iter() {
                    if let Ok(metadata) = Metadata::from_json(&profile_event.content) {
                        let pubkey_hex = profile_event.pubkey.to_hex();
                        profile_map.insert(pubkey_hex, ProfileCache::from_metadata(&metadata));
                    }
                }
                
                let notes: Vec<DisplayNote> = events
                    .iter()
                    .map(|e| {
                        let pubkey_hex = e.pubkey.to_hex();
                        let profile = profile_map.get(&pubkey_hex);
                        DisplayNote::from_event(e, profile)
                    })
                    .collect();
                
                Ok(notes)
            })
        }).join();
        
        match result {
            Ok(Ok(mut new_notes)) => {
                // Sort by timestamp descending (newest first)
                new_notes.sort_by(|a, b| b.created_at.cmp(&a.created_at));
                
                // Filter out any duplicates based on note ID
                let existing_ids: std::collections::HashSet<String> = {
                    let rust = self.as_ref();
                    rust.notes.iter().map(|n| n.id.clone()).collect()
                };
                
                new_notes.retain(|n| !existing_ids.contains(&n.id));
                
                let count = new_notes.len() as i32;
                
                if count == 0 {
                    tracing::info!("No new older notes found (all were duplicates)");
                    self.as_mut().set_is_loading(false);
                    self.as_mut().loading_changed(false);
                    return;
                }
                
                let total = {
                    let mut rust = self.as_mut().rust_mut();
                    // Append to end (these are older notes)
                    rust.notes.extend(new_notes);
                    rust.note_count = rust.notes.len() as i32;
                    rust.note_count
                };
                
                // Update cache
                if let Ok(mut cache) = FEED_CACHE.write() {
                    let rust = self.as_ref();
                    cache.insert(current_feed_type.clone(), rust.notes.clone());
                }
                
                self.as_mut().set_note_count(total);
                self.as_mut().set_is_loading(false);
                self.as_mut().loading_changed(false);
                self.as_mut().more_loaded(count);
                self.as_mut().feed_updated();
                
                // Calculate new coverage
                let new_oldest = {
                    let rust = self.as_ref();
                    rust.notes.last().map(|n| n.created_at).unwrap_or(0)
                };
                let hours = if newest_timestamp > 0 && new_oldest > 0 {
                    (newest_timestamp - new_oldest) / 3600
                } else { 0 };
                
                tracing::info!("Loaded {} more notes, total: {}, coverage: {} hours", count, total, hours);
            }
            Ok(Err(e)) => {
                tracing::error!("Failed to load more: {}", e);
                self.as_mut().set_is_loading(false);
                self.as_mut().loading_changed(false);
                self.as_mut().error_occurred(&QString::from(&e));
            }
            Err(_panic) => {
                tracing::error!("Panic occurred while loading more notes");
                self.as_mut().set_is_loading(false);
                self.as_mut().loading_changed(false);
                self.as_mut().error_occurred(&QString::from("Internal error loading notes"));
            }
        }
    }
    
    /* Original load_more - disabled due to segfaults
    pub fn load_more_disabled(mut self: Pin<&mut Self>) {
        // Prevent re-entry while loading
        if *self.is_loading() {
            tracing::warn!("load_more called while already loading, ignoring");
            return;
        }
        
        let oldest_timestamp = {
            let rust = self.as_ref();
            if rust.notes.is_empty() {
                tracing::warn!("No notes to paginate from");
                return;
            }
            rust.notes.last().map(|n| n.created_at).unwrap_or(0)
        };
        
        if oldest_timestamp <= 0 {
            tracing::warn!("Invalid timestamp for pagination: {}", oldest_timestamp);
            return;
        }
        
        self.as_mut().set_is_loading(true);
        
        let current = self.current_feed().to_string();
        let feed = FeedType::from_str(&current);
        
        tracing::info!("Loading more for {} feed, before {}", current, oldest_timestamp);
        
        // Use a separate thread to avoid Qt/tokio conflicts
        let result = std::thread::spawn(move || {
            FEED_RUNTIME.block_on(async {
                let rm = RELAY_MANAGER.read().unwrap();
                let Some(manager) = rm.as_ref() else {
                    return Err("Relay manager not initialized".to_string());
                };
                
                let until = Some(Timestamp::from((oldest_timestamp - 1) as u64));
                let limit = 30u64;
                
                let events = match feed {
                    FeedType::Following => manager.fetch_following_feed(limit, until).await?,
                    FeedType::Replies => manager.fetch_replies_feed(limit, until).await?,
                    FeedType::Global => manager.fetch_global_feed(limit, until).await?,
                };
                
                // Fetch profiles for new authors
                let pubkeys: Vec<PublicKey> = events
                    .iter()
                    .map(|e| e.pubkey)
                    .collect::<std::collections::HashSet<_>>()
                    .into_iter()
                    .collect();
            
            let profiles = manager.fetch_profiles(&pubkeys).await.unwrap_or_default();
            
            let mut profile_map = std::collections::HashMap::new();
            for profile_event in profiles.iter() {
                if let Ok(metadata) = Metadata::from_json(&profile_event.content) {
                    let pubkey_hex = profile_event.pubkey.to_hex();
                    profile_map.insert(pubkey_hex, ProfileCache::from_metadata(&metadata));
                }
            }
            
            let notes: Vec<DisplayNote> = events
                .iter()
                .map(|e| {
                    let pubkey_hex = e.pubkey.to_hex();
                    let profile = profile_map.get(&pubkey_hex);
                    DisplayNote::from_event(e, profile)
                })
                .collect();
            
            Ok(notes)
            })
        });
        
        match result.join() {
            Ok(Ok(mut new_notes)) => {
                new_notes.sort_by(|a, b| b.created_at.cmp(&a.created_at));
                let count = new_notes.len() as i32;
                
                let total = {
                    let mut rust = self.as_mut().rust_mut();
                    rust.notes.extend(new_notes);
                    rust.note_count = rust.notes.len() as i32;
                    rust.note_count
                };
                
                self.as_mut().set_note_count(total);
                self.as_mut().set_is_loading(false);
                self.as_mut().more_loaded(count);
                self.as_mut().feed_updated();
                
                tracing::info!("Loaded {} more notes, total: {}", count, total);
            }
            Ok(Err(e)) => {
                tracing::error!("Failed to load more: {}", e);
                self.as_mut().set_is_loading(false);
                self.as_mut().error_occurred(&QString::from(&e));
            }
            Err(_panic) => {
                tracing::error!("Panic occurred while loading more notes");
                self.as_mut().set_is_loading(false);
                self.as_mut().error_occurred(&QString::from("Internal error loading notes"));
            }
        }
    }
    */
    
    /// Check for new notes since the latest one we have
    /// This fetches new notes and prepends them without clearing the existing feed
    pub fn check_for_new(mut self: Pin<&mut Self>) {
        if *self.is_loading() {
            tracing::warn!("check_for_new called while already loading, ignoring");
            return;
        }
        
        let (newest_timestamp, should_do_normal_load) = {
            let rust = self.as_ref();
            if rust.notes.is_empty() {
                // If no notes, just do a normal load
                tracing::info!("No existing notes, doing normal load instead of check_for_new");
                (0, true)
            } else {
                // Get the newest timestamp - notes are sorted descending, so first is newest
                (rust.notes.first().map(|n| n.created_at).unwrap_or(0), false)
            }
        };
        
        if should_do_normal_load {
            let current_feed = self.current_feed().clone();
            self.load_feed(&current_feed);
            return;
        }
        
        let current = self.current_feed().to_string();
        let feed = FeedType::from_str(&current);
        
        tracing::info!("Checking for new {} notes since timestamp {}", current, newest_timestamp);
        
        // Don't set loading state for quick check - prevents UI flicker
        
        // Use a separate thread to avoid Qt/tokio conflicts
        let result = std::thread::spawn(move || {
            FEED_RUNTIME.block_on(async {
                let rm = RELAY_MANAGER.read().unwrap();
                let Some(manager) = rm.as_ref() else {
                    return Err("Relay manager not initialized".to_string());
                };
                
                // Fetch recent notes - we'll filter by timestamp on our end
                let limit = 50u64; // Fetch more to increase chance of finding new ones
                let events = match feed {
                    FeedType::Following => manager.fetch_following_feed(limit, None).await?,
                    FeedType::Replies => manager.fetch_home_feed(limit, None).await?,
                    FeedType::Global => manager.fetch_global_feed(limit, None).await?,
                };
                
                tracing::debug!("check_for_new: fetched {} events from relays", events.len());
                
                // Log some timestamps for debugging
                for (i, e) in events.iter().take(5).enumerate() {
                    tracing::debug!("  event {}: ts={}, newest_ts={}, newer={}", 
                        i, e.created_at.as_u64(), newest_timestamp,
                        e.created_at.as_u64() as i64 > newest_timestamp);
                }
                
                // Filter to only notes newer than our newest
                let new_events: Vec<_> = events
                    .iter()
                    .filter(|e| e.created_at.as_u64() as i64 > newest_timestamp)
                    .cloned()
                    .collect();
                
                tracing::debug!("check_for_new: {} events are newer than {}", new_events.len(), newest_timestamp);
                
                if new_events.is_empty() {
                    return Ok(vec![]);
                }
                
                // Fetch profiles for new authors
                let pubkeys: Vec<PublicKey> = new_events
                    .iter()
                    .map(|e| e.pubkey)
                    .collect::<std::collections::HashSet<_>>()
                    .into_iter()
                    .collect();
            
                let profiles = manager.fetch_profiles(&pubkeys).await.unwrap_or_default();
            
                let mut profile_map = std::collections::HashMap::new();
                for profile_event in profiles.iter() {
                    if let Ok(metadata) = Metadata::from_json(&profile_event.content) {
                        let pubkey_hex = profile_event.pubkey.to_hex();
                        profile_map.insert(pubkey_hex, ProfileCache::from_metadata(&metadata));
                    }
                }
            
                let notes: Vec<DisplayNote> = new_events
                    .iter()
                    .map(|e| {
                        let pubkey_hex = e.pubkey.to_hex();
                        let profile = profile_map.get(&pubkey_hex);
                        DisplayNote::from_event(e, profile)
                    })
                    .collect();
            
                Ok(notes)
            })
        });
        
        match result.join() {
            Ok(Ok(mut new_notes)) => {
                if new_notes.is_empty() {
                    tracing::info!("No new notes found for {} feed", current);
                    self.as_mut().new_notes_found(0);
                    return;
                }
                
                // Sort new notes by timestamp descending
                new_notes.sort_by(|a, b| b.created_at.cmp(&a.created_at));
                let new_count = new_notes.len() as i32;
                
                // Prepend new notes to existing ones
                let total = {
                    let mut rust = self.as_mut().rust_mut();
                    // Prepend new notes
                    new_notes.append(&mut rust.notes);
                    rust.notes = new_notes;
                    rust.note_count = rust.notes.len() as i32;
                    rust.note_count
                };
                
                // Update the cache too
                if let Ok(mut cache) = FEED_CACHE.write() {
                    let rust = self.as_ref();
                    cache.insert(current.clone(), rust.notes.clone());
                }
                
                self.as_mut().set_note_count(total);
                self.as_mut().new_notes_found(new_count);
                self.as_mut().feed_updated();
                
                tracing::info!("Found {} new notes for {} feed, total: {}", new_count, current, total);
            }
            Ok(Err(e)) => {
                tracing::error!("Failed to check for new notes: {}", e);
                self.as_mut().error_occurred(&QString::from(&e));
            }
            Err(_panic) => {
                tracing::error!("Panic occurred while checking for new notes");
                self.as_mut().error_occurred(&QString::from("Internal error checking for new notes"));
            }
        }
    }

    /// Refresh the current feed
    pub fn refresh(self: Pin<&mut Self>) {
        let current = self.current_feed().to_string();
        
        // Clear the cache for this feed so we fetch fresh data
        if let Ok(mut cache) = FEED_CACHE.write() {
            cache.remove(&current);
            tracing::info!("Cleared cache for {} feed, fetching fresh", current);
        }
        
        self.load_feed(&QString::from(&current));
    }
    
    /// Get note at index
    pub fn get_note(&self, index: i32) -> QString {
        if let Some(note) = self.notes.get(index as usize) {
            QString::from(&note.to_json())
        } else {
            QString::from("{}")
        }
    }
    
    /// Load thread for a specific note (parents + target + replies)
    pub fn load_thread(mut self: Pin<&mut Self>, note_id: &QString) {
        let note_id_str = note_id.to_string();
        tracing::info!("Loading thread for note: {}", note_id_str);
        
        self.as_mut().set_is_loading(true);
        self.as_mut().set_thread_note_id(note_id.clone());
        
        // Use a separate thread to avoid Qt/tokio conflicts
        let result = std::thread::spawn(move || {
            FEED_RUNTIME.block_on(async {
                let rm = RELAY_MANAGER.read().unwrap();
                let Some(manager) = rm.as_ref() else {
                    return Err("Relay manager not initialized".to_string());
                };
                
                let event_id = EventId::parse(&note_id_str)
                    .map_err(|e| format!("Invalid event ID: {}", e))?;
                
                let (parents, target, replies) = manager.fetch_thread(&event_id).await?;
                
                // Collect all events for profile fetching
                let mut all_events = parents.clone();
                if let Some(ref t) = target {
                    all_events.push(t.clone());
                }
                all_events.extend(replies.clone());
                
                // Fetch profiles
                let pubkeys: Vec<PublicKey> = all_events
                    .iter()
                    .map(|e| e.pubkey)
                    .collect::<std::collections::HashSet<_>>()
                    .into_iter()
                    .collect();
                
                let profiles = manager.fetch_profiles(&pubkeys).await.unwrap_or_default();
                
                let mut profile_map = std::collections::HashMap::new();
                for profile_event in profiles.iter() {
                    if let Ok(metadata) = Metadata::from_json(&profile_event.content) {
                        let pubkey_hex = profile_event.pubkey.to_hex();
                        profile_map.insert(pubkey_hex, ProfileCache::from_metadata(&metadata));
                    }
                }
                
                // Build thread notes list: parents first, then target, then replies
                let mut thread_notes: Vec<DisplayNote> = Vec::new();
                
                for event in &parents {
                    let pubkey_hex = event.pubkey.to_hex();
                    let profile = profile_map.get(&pubkey_hex);
                    thread_notes.push(DisplayNote::from_event(event, profile));
                }
                
                if let Some(ref t) = target {
                    let pubkey_hex = t.pubkey.to_hex();
                    let profile = profile_map.get(&pubkey_hex);
                    thread_notes.push(DisplayNote::from_event(t, profile));
                }
                
                for event in &replies {
                    let pubkey_hex = event.pubkey.to_hex();
                    let profile = profile_map.get(&pubkey_hex);
                    thread_notes.push(DisplayNote::from_event(event, profile));
                }
                
                Ok(thread_notes)
            })
        });
        
        match result.join() {
            Ok(Ok(thread_notes)) => {
                let count = thread_notes.len() as i32;
                {
                    let mut rust = self.as_mut().rust_mut();
                    rust.thread_notes = thread_notes;
                    rust.thread_count = count;
                }
                self.as_mut().set_thread_count(count);
                self.as_mut().set_is_loading(false);
                self.as_mut().thread_loaded();
                tracing::info!("Loaded thread with {} notes", count);
            }
            Ok(Err(e)) => {
                tracing::error!("Failed to load thread: {}", e);
                self.as_mut().set_is_loading(false);
                self.as_mut().error_occurred(&QString::from(&e));
            }
            Err(_panic) => {
                tracing::error!("Panic occurred while loading thread");
                self.as_mut().set_is_loading(false);
                self.as_mut().error_occurred(&QString::from("Internal error loading thread"));
            }
        }
    }
    
    /// Get thread note at index
    pub fn get_thread_note(&self, index: i32) -> QString {
        if let Some(note) = self.thread_notes.get(index as usize) {
            QString::from(&note.to_json())
        } else {
            QString::from("{}")
        }
    }
    
    /// Clear thread view
    pub fn clear_thread(mut self: Pin<&mut Self>) {
        {
            let mut rust = self.as_mut().rust_mut();
            rust.thread_notes.clear();
            rust.thread_count = 0;
        }
        self.as_mut().set_thread_count(0);
        self.as_mut().set_thread_note_id(QString::from(""));
    }
    
    /// Like a note (kind 7)
    pub fn like_note(mut self: Pin<&mut Self>, note_id: &QString) {
        let note_id_str = note_id.to_string();
        tracing::info!("Like note: {}", note_id_str);
        
        let user_pubkey = self.user_pubkey.clone();
        
        let result = FEED_RUNTIME.block_on(async {
            let event_id = EventId::from_hex(&note_id_str)
                .map_err(|e| format!("Invalid event ID: {}", e))?;
            
            let user_pk = user_pubkey.as_ref()
                .and_then(|pk| PublicKey::parse(pk).ok())
                .ok_or("User not initialized")?;
            
            // Get relay manager
            let rm = RELAY_MANAGER.read().unwrap();
            let manager = rm.as_ref().ok_or("Not connected to relays")?;
            let client = manager.client();
            
            // Build reaction event (kind 7)
            let tags = vec![
                Tag::event(event_id),
                Tag::public_key(user_pk), // Tag the author (we'd need to fetch the event to get author)
            ];
            
            // Try signer first
            let signer = FEED_SIGNER.lock().await;
            if let Some(s) = signer.as_ref() {
                let unsigned = EventBuilder::new(Kind::Reaction, "+")
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
            } else if let Some(nsec) = FEED_NSEC.read().unwrap().as_ref() {
                // Use local keys
                let secret_key = SecretKey::parse(nsec)
                    .map_err(|e| format!("Invalid nsec: {}", e))?;
                let keys = Keys::new(secret_key);
                
                let event = EventBuilder::new(Kind::Reaction, "+")
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
                tracing::info!("Liked note, reaction event: {}", event_id);
            }
            Err(e) => {
                tracing::error!("Failed to like note: {}", e);
                self.as_mut().error_occurred(&QString::from(&e));
            }
        }
    }
    
    /// React to a note with a custom emoji (kind 7)
    pub fn react_to_note(mut self: Pin<&mut Self>, note_id: &QString, emoji: &QString) {
        let note_id_str = note_id.to_string();
        let emoji_str = emoji.to_string();
        let reaction_content = if emoji_str.is_empty() { "+".to_string() } else { emoji_str.clone() };
        tracing::info!("Reacting to note {} with: {}", note_id_str, reaction_content);
        
        let user_pubkey = self.user_pubkey.clone();
        
        let result = FEED_RUNTIME.block_on(async {
            let event_id = EventId::from_hex(&note_id_str)
                .map_err(|e| format!("Invalid event ID: {}", e))?;
            
            let user_pk = user_pubkey.as_ref()
                .and_then(|pk| PublicKey::parse(pk).ok())
                .ok_or("User not initialized")?;
            
            // Get relay manager
            let rm = RELAY_MANAGER.read().unwrap();
            let manager = rm.as_ref().ok_or("Not connected to relays")?;
            let client = manager.client();
            
            // Fetch the original event to get the author's pubkey
            let original_event = manager.fetch_event(&event_id).await?
                .ok_or("Original event not found")?;
            
            // Build reaction event (kind 7)
            let tags = vec![
                Tag::event(event_id),
                Tag::public_key(original_event.pubkey),
            ];
            
            // Try signer first
            let signer = FEED_SIGNER.lock().await;
            if let Some(s) = signer.as_ref() {
                let unsigned = EventBuilder::new(Kind::Reaction, &reaction_content)
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
            } else if let Some(nsec) = FEED_NSEC.read().unwrap().as_ref() {
                // Use local keys
                let secret_key = SecretKey::parse(nsec)
                    .map_err(|e| format!("Invalid nsec: {}", e))?;
                let keys = Keys::new(secret_key);
                
                let event = EventBuilder::new(Kind::Reaction, &reaction_content)
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
                tracing::info!("Reacted to note with {}, event: {}", reaction_content, event_id);
            }
            Err(e) => {
                tracing::error!("Failed to react to note: {}", e);
                self.as_mut().error_occurred(&QString::from(&e));
            }
        }
    }
    
    /// Fetch reactions and zap stats for a specific note (async - non-blocking)
    /// Returns cached data immediately if available, otherwise returns empty and fetches in background
    /// Call get_cached_note_stats() to retrieve results after fetching
    pub fn fetch_note_stats(self: Pin<&mut Self>, note_id: &QString) -> QString {
        let note_id_str = note_id.to_string();
        
        // Check cache first
        {
            let cache = NOTE_STATS_CACHE.read().unwrap();
            if let Some(cached) = cache.get(&note_id_str) {
                return QString::from(cached);
            }
        }
        
        // Check if already pending
        {
            let pending = PENDING_STATS.read().unwrap();
            if pending.contains(&note_id_str) {
                // Already fetching, return empty (loading state)
                return QString::from(r#"{"reactions":{},"zapAmount":0,"zapCount":0,"loading":true}"#);
            }
        }
        
        // Mark as pending
        {
            let mut pending = PENDING_STATS.write().unwrap();
            pending.insert(note_id_str.clone());
        }
        
        // Spawn background fetch - don't block UI
        let note_id_clone = note_id_str.clone();
        std::thread::spawn(move || {
            let result: Result<String, String> = FEED_RUNTIME.block_on(async {
                let event_id = EventId::from_hex(&note_id_clone)
                    .map_err(|e| format!("Invalid event ID: {}", e))?;
                
                // Get relay manager
                let rm = RELAY_MANAGER.read().unwrap();
                let manager = rm.as_ref().ok_or_else(|| "Not connected to relays".to_string())?;
                
                // Fetch stats for this note
                let stats = manager.fetch_note_stats(&[event_id]).await?;
                
                // Get the stats for this specific note
                if let Some((reactions, zap_amount, zap_count)) = stats.get(&note_id_clone) {
                    Ok(serde_json::json!({
                        "reactions": reactions,
                        "zapAmount": zap_amount,
                        "zapCount": zap_count
                    }).to_string())
                } else {
                    Ok(serde_json::json!({
                        "reactions": {},
                        "zapAmount": 0,
                        "zapCount": 0
                    }).to_string())
                }
            });
            
            // Cache the result
            match result {
                Ok(json) => {
                    if let Ok(mut cache) = NOTE_STATS_CACHE.write() {
                        cache.insert(note_id_clone.clone(), json);
                    }
                }
                Err(e) => {
                    tracing::warn!("Failed to fetch note stats for {}: {}", note_id_clone, e);
                    // Cache empty result to prevent repeated failed fetches
                    if let Ok(mut cache) = NOTE_STATS_CACHE.write() {
                        cache.insert(note_id_clone.clone(), r#"{"reactions":{},"zapAmount":0,"zapCount":0}"#.to_string());
                    }
                }
            }
            
            // Remove from pending
            if let Ok(mut pending) = PENDING_STATS.write() {
                pending.remove(&note_id_clone);
            }
        });
        
        // Return loading state while fetching
        QString::from(r#"{"reactions":{},"zapAmount":0,"zapCount":0,"loading":true}"#)
    }
    
    /// Get cached note stats (non-blocking)
    /// Returns cached stats or empty if not yet fetched
    pub fn get_cached_note_stats(&self, note_id: &QString) -> QString {
        let note_id_str = note_id.to_string();
        
        // Check cache
        let cache = NOTE_STATS_CACHE.read().unwrap();
        if let Some(cached) = cache.get(&note_id_str) {
            return QString::from(cached);
        }
        
        // Check if pending
        let pending = PENDING_STATS.read().unwrap();
        if pending.contains(&note_id_str) {
            return QString::from(r#"{"reactions":{},"zapAmount":0,"zapCount":0,"loading":true}"#);
        }
        
        // Not in cache and not pending
        QString::from(r#"{"reactions":{},"zapAmount":0,"zapCount":0}"#)
    }
    
    /// Repost a note (kind 6)
    pub fn repost_note(mut self: Pin<&mut Self>, note_id: &QString) {
        let note_id_str = note_id.to_string();
        tracing::info!("Repost note: {}", note_id_str);
        
        let user_pubkey = self.user_pubkey.clone();
        
        let result = FEED_RUNTIME.block_on(async {
            let event_id = EventId::from_hex(&note_id_str)
                .map_err(|e| format!("Invalid event ID: {}", e))?;
            
            let user_pk = user_pubkey.as_ref()
                .and_then(|pk| PublicKey::parse(pk).ok())
                .ok_or("User not initialized")?;
            
            // Get relay manager
            let rm = RELAY_MANAGER.read().unwrap();
            let manager = rm.as_ref().ok_or("Not connected to relays")?;
            let client = manager.client();
            
            // Fetch the original event to include in repost
            let original_event = manager.fetch_event(&event_id).await?
                .ok_or("Original event not found")?;
            
            // Build repost event (kind 6)
            let tags = vec![
                Tag::event(event_id),
                Tag::public_key(original_event.pubkey),
            ];
            
            // Include original event JSON as content
            let original_json = serde_json::to_string(&original_event)
                .unwrap_or_default();
            
            let signer = FEED_SIGNER.lock().await;
            if let Some(s) = signer.as_ref() {
                let unsigned = EventBuilder::new(Kind::Repost, &original_json)
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
            } else if let Some(nsec) = FEED_NSEC.read().unwrap().as_ref() {
                let secret_key = SecretKey::parse(nsec)
                    .map_err(|e| format!("Invalid nsec: {}", e))?;
                let keys = Keys::new(secret_key);
                
                let event = EventBuilder::new(Kind::Repost, &original_json)
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
                tracing::info!("Reposted note, event: {}", event_id);
            }
            Err(e) => {
                tracing::error!("Failed to repost note: {}", e);
                self.as_mut().error_occurred(&QString::from(&e));
            }
        }
    }
    
    /// Reply to a note
    pub fn reply_to_note(mut self: Pin<&mut Self>, note_id: &QString, content: &QString) {
        let note_id_str = note_id.to_string();
        let content_str = content.to_string();
        tracing::info!("Reply to {}: {}", note_id_str, &content_str[..content_str.len().min(50)]);
        
        let user_pubkey = self.user_pubkey.clone();
        
        let result = FEED_RUNTIME.block_on(async {
            let event_id = EventId::from_hex(&note_id_str)
                .map_err(|e| format!("Invalid event ID: {}", e))?;
            
            let user_pk = user_pubkey.as_ref()
                .and_then(|pk| PublicKey::parse(pk).ok())
                .ok_or("User not initialized")?;
            
            // Get relay manager
            let rm = RELAY_MANAGER.read().unwrap();
            let manager = rm.as_ref().ok_or("Not connected to relays")?;
            let client = manager.client();
            
            // Fetch original event to get author and any root event
            let original_event = manager.fetch_event(&event_id).await?
                .ok_or("Original event not found")?;
            
            // Build tags for reply (NIP-10 compliant)
            let mut tags = vec![
                Tag::event(event_id), // Reply to this event
                Tag::public_key(original_event.pubkey), // Tag the author
            ];
            
            // Check if original was already a reply - if so, include root
            for tag in original_event.tags.iter() {
                if let Some(TagStandard::Event { event_id: root_id, marker, .. }) = tag.as_standardized() {
                    if marker.as_ref().map(|m| *m == Marker::Root).unwrap_or(false) {
                        // Add root tag - use owned strings for Tag::parse
                        let root_tag = Tag::parse(vec![
                            "e".to_string(),
                            root_id.to_hex(),
                            String::new(),
                            "root".to_string()
                        ]).unwrap();
                        tags.insert(0, root_tag);
                        break;
                    }
                }
            }
            
            let signer = FEED_SIGNER.lock().await;
            if let Some(s) = signer.as_ref() {
                let unsigned = EventBuilder::text_note(&content_str)
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
            } else if let Some(nsec) = FEED_NSEC.read().unwrap().as_ref() {
                let secret_key = SecretKey::parse(nsec)
                    .map_err(|e| format!("Invalid nsec: {}", e))?;
                let keys = Keys::new(secret_key);
                
                let event = EventBuilder::text_note(&content_str)
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
                tracing::info!("Posted reply, event: {}", event_id);
                self.as_mut().note_posted(&QString::from(&event_id));
            }
            Err(e) => {
                tracing::error!("Failed to post reply: {}", e);
                self.as_mut().error_occurred(&QString::from(&e));
            }
        }
    }
    
    /// Zap a note
    pub fn zap_note(mut self: Pin<&mut Self>, note_id: &QString, amount_sats: i64, comment: &QString) {
        let note_id_str = note_id.to_string();
        let comment_str = comment.to_string();
        tracing::info!("Zapping note {} with {} sats", note_id_str, amount_sats);
        
        // Get user's signing keys
        let nsec_opt = FEED_NSEC.read().unwrap().clone();
        
        let result = FEED_RUNTIME.block_on(async {
            // Check if NWC is connected
            let mut nwc = GLOBAL_NWC_MANAGER.lock().await;
            if !nwc.is_connected() {
                return Err("NWC wallet not connected. Please connect your wallet in Settings.".to_string());
            }
            
            // Get signing keys
            let keys = match nsec_opt.as_ref() {
                Some(nsec) => {
                    let secret_key = SecretKey::parse(nsec)
                        .map_err(|e| format!("Invalid nsec: {}", e))?;
                    Keys::new(secret_key)
                }
                None => {
                    return Err("No signing keys available".to_string());
                }
            };
            
            // Get relay manager for fetching note author
            let rm = RELAY_MANAGER.read().unwrap();
            let manager = rm.as_ref().ok_or("Not connected to relays")?;
            let client = manager.client();
            
            // Parse note ID
            let event_id = EventId::parse(&note_id_str)
                .or_else(|_| EventId::from_bech32(&note_id_str))
                .map_err(|e| format!("Invalid note ID: {}", e))?;
            
            // Fetch the note to get author's pubkey and find their lud16
            let note_filter = Filter::new()
                .id(event_id.clone())
                .limit(1);
            
            let note_events = client.fetch_events(note_filter, std::time::Duration::from_secs(10)).await
                .map_err(|e| format!("Failed to fetch note: {}", e))?;
            
            let note_event = note_events.into_iter().next()
                .ok_or("Note not found")?;
            
            let author_pubkey = note_event.pubkey.clone();
            
            // Fetch author's profile to get their lightning address
            let profile_filter = Filter::new()
                .kind(Kind::Metadata)
                .author(author_pubkey.clone())
                .limit(1);
            
            let profile_events = client.fetch_events(profile_filter, std::time::Duration::from_secs(10)).await
                .map_err(|e| format!("Failed to fetch author profile: {}", e))?;
            
            let profile_event = profile_events.into_iter().next()
                .ok_or("Author profile not found")?;
            
            // Parse metadata to get lud16
            let metadata: Metadata = serde_json::from_str(&profile_event.content)
                .map_err(|e| format!("Failed to parse profile metadata: {}", e))?;
            
            let lud16 = metadata.lud16
                .ok_or("Author doesn't have a lightning address (lud16)")?;
            
            if lud16.is_empty() {
                return Err("Author's lightning address is empty".to_string());
            }
            
            // Get relay URLs for zap request (use default relays)
            let relays: Vec<String> = crate::nostr::relay::DEFAULT_RELAYS.iter()
                .take(3) // Include up to 3 relays
                .map(|s| s.to_string())
                .collect();
            
            // Perform the zap
            zap::zap(
                &mut *nwc,
                &keys,
                &author_pubkey,
                &lud16,
                Some(&event_id),
                amount_sats as u64,
                &comment_str,
                &relays,
            ).await
        });
        
        match result {
            Ok(preimage) => {
                tracing::info!("Zap successful! Preimage: {}", &preimage[..16.min(preimage.len())]);
                self.as_mut().zap_success(&QString::from(&note_id_str), amount_sats);
            }
            Err(e) => {
                tracing::error!("Zap failed: {}", e);
                self.as_mut().zap_failed(&QString::from(&note_id_str), &QString::from(&e));
            }
        }
    }
    
    /// Post a new note
    pub fn post_note(mut self: Pin<&mut Self>, content: &QString) {
        let content_str = content.to_string();
        tracing::info!("Post note: {}", &content_str[..content_str.len().min(50)]);
        
        let user_pubkey = self.user_pubkey.clone();
        
        let result = FEED_RUNTIME.block_on(async {
            let user_pk = user_pubkey.as_ref()
                .and_then(|pk| PublicKey::parse(pk).ok())
                .ok_or("User not initialized")?;
            
            // Get relay manager
            let rm = RELAY_MANAGER.read().unwrap();
            let manager = rm.as_ref().ok_or("Not connected to relays")?;
            let client = manager.client();
            
            let signer = FEED_SIGNER.lock().await;
            if let Some(s) = signer.as_ref() {
                let unsigned = EventBuilder::text_note(&content_str)
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
            } else if let Some(nsec) = FEED_NSEC.read().unwrap().as_ref() {
                let secret_key = SecretKey::parse(nsec)
                    .map_err(|e| format!("Invalid nsec: {}", e))?;
                let keys = Keys::new(secret_key);
                
                let event = EventBuilder::text_note(&content_str)
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
                tracing::info!("Posted note, event: {}", event_id);
                self.as_mut().note_posted(&QString::from(&event_id));
            }
            Err(e) => {
                tracing::error!("Failed to post note: {}", e);
                self.as_mut().error_occurred(&QString::from(&e));
            }
        }
    }
    
    /// Post a new note with media attachments
    pub fn post_note_with_media(mut self: Pin<&mut Self>, content: &QString, media_urls: &QString) {
        let content_str = content.to_string();
        let media_urls_str = media_urls.to_string();
        
        // Parse media URLs from JSON array
        let media_urls: Vec<String> = serde_json::from_str(&media_urls_str).unwrap_or_default();
        
        // Append media URLs to content
        let full_content = if media_urls.is_empty() {
            content_str.clone()
        } else {
            format!("{}\n\n{}", content_str, media_urls.join("\n"))
        };
        
        tracing::info!("Post note with {} media: {}", media_urls.len(), &full_content[..full_content.len().min(100)]);
        
        let user_pubkey = self.user_pubkey.clone();
        
        let result = FEED_RUNTIME.block_on(async {
            let user_pk = user_pubkey.as_ref()
                .and_then(|pk| PublicKey::parse(pk).ok())
                .ok_or("User not initialized")?;
            
            // Get relay manager
            let rm = RELAY_MANAGER.read().unwrap();
            let manager = rm.as_ref().ok_or("Not connected to relays")?;
            let client = manager.client();
            
            // Build event with imeta tags for each media URL
            let mut builder = EventBuilder::text_note(&full_content);
            
            // Add imeta tags for media URLs (NIP-92 style)
            for url in &media_urls {
                // Detect media type from URL
                let lower = url.to_lowercase();
                let media_type = if lower.ends_with(".mp4") || lower.ends_with(".webm") || lower.ends_with(".mov") {
                    "video"
                } else {
                    "image"
                };
                
                // Add imeta tag with url and m (mime type hint)
                builder = builder.tag(Tag::custom(
                    TagKind::Custom("imeta".into()),
                    vec![
                        format!("url {}", url),
                        format!("m {}/{}", media_type, lower.rsplit('.').next().unwrap_or("jpeg")),
                    ],
                ));
            }
            
            let signer = FEED_SIGNER.lock().await;
            if let Some(s) = signer.as_ref() {
                let unsigned = builder.build(user_pk);
                
                let unsigned_json = serde_json::to_string(&unsigned)
                    .map_err(|e| format!("Serialization failed: {}", e))?;
                
                let signed_result = s.sign_event(&unsigned_json).await
                    .map_err(|e| format!("Signing failed: {}", e))?;
                
                let signed_event: Event = serde_json::from_str(&signed_result.event_json)
                    .map_err(|e| format!("Failed to parse signed event: {}", e))?;
                
                client.send_event(&signed_event).await
                    .map_err(|e| format!("Failed to send: {}", e))?;
                
                Ok::<String, String>(signed_event.id.to_hex())
            } else if let Some(nsec) = FEED_NSEC.read().unwrap().as_ref() {
                let secret_key = SecretKey::parse(nsec)
                    .map_err(|e| format!("Invalid nsec: {}", e))?;
                let keys = Keys::new(secret_key);
                
                let event = builder
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
                tracing::info!("Posted note with media, event: {}", event_id);
                self.as_mut().note_posted(&QString::from(&event_id));
            }
            Err(e) => {
                tracing::error!("Failed to post note: {}", e);
                self.as_mut().error_occurred(&QString::from(&e));
            }
        }
    }
    
    /// Upload media to Blossom server
    pub fn upload_media(mut self: Pin<&mut Self>, file_path: &QString) -> QString {
        let path = file_path.to_string();
        
        // Remove file:// prefix if present (from QML file dialog)
        let clean_path = path.strip_prefix("file://").unwrap_or(&path);
        
        tracing::info!("Uploading media: {}", clean_path);
        
        let result = FEED_RUNTIME.block_on(async {
            // Get keys for signing
            let nsec = FEED_NSEC.read().unwrap().clone()
                .ok_or("No signing keys available")?;
            
            let secret_key = SecretKey::parse(&nsec)
                .map_err(|e| format!("Invalid nsec: {}", e))?;
            let keys = Keys::new(secret_key);
            
            // Get blossom server from config
            let config = Config::load();
            let server_url = &config.blossom_server;
            
            // Upload to Blossom
            let response = blossom::upload_media(server_url, clean_path, &keys).await?;
            
            Ok::<String, String>(serde_json::json!({
                "url": response.url,
                "sha256": response.sha256,
                "size": response.size,
                "type": response.mime_type,
            }).to_string())
        });
        
        match result {
            Ok(json) => {
                // Parse to get URL for signal
                if let Ok(data) = serde_json::from_str::<serde_json::Value>(&json) {
                    if let Some(url) = data.get("url").and_then(|u| u.as_str()) {
                        self.as_mut().media_uploaded(&QString::from(url));
                    }
                }
                QString::from(&json)
            }
            Err(e) => {
                tracing::error!("Media upload failed: {}", e);
                self.as_mut().media_upload_failed(&QString::from(&e));
                QString::from(&format!(r#"{{"error": "{}"}}"#, e))
            }
        }
    }
    
    /// Get the configured Blossom server URL
    pub fn get_blossom_server(&self) -> QString {
        let config = Config::load();
        QString::from(&config.blossom_server)
    }
    
    /// Set the Blossom server URL
    pub fn set_blossom_server(self: Pin<&mut Self>, url: &QString) {
        let url_str = url.to_string().trim().to_string();
        
        // Validate URL
        if url_str.is_empty() {
            tracing::warn!("Empty blossom server URL, using default");
            return;
        }
        
        let mut config = Config::load();
        config.blossom_server = url_str.clone();
        
        if let Err(e) = config.save() {
            tracing::error!("Failed to save config: {}", e);
        } else {
            tracing::info!("Blossom server set to: {}", url_str);
        }
    }
    
    /// Fetch an embedded nostr event by nevent/naddr/note bech32 string
    /// Uses caching to avoid blocking the UI thread during scroll
    pub fn fetch_embedded_event(self: Pin<&mut Self>, nostr_uri: &QString) -> QString {
        let uri = nostr_uri.to_string();
        let cache_key = uri.clone();
        
        // Check cache first - return immediately if cached
        if let Ok(cache) = EMBEDDED_EVENT_CACHE.read() {
            if let Some(cached) = cache.get(&cache_key) {
                return QString::from(cached);
            }
        }
        
        // Check if already pending
        {
            let pending = PENDING_EMBEDS.read().unwrap();
            if pending.contains(&cache_key) {
                // Already fetching, return loading state
                return QString::from("{}");
            }
        }
        
        // Mark as pending
        {
            let mut pending = PENDING_EMBEDS.write().unwrap();
            pending.insert(cache_key.clone());
        }
        
        // Strip nostr: prefix if present
        let bech32_str = uri.strip_prefix("nostr:").unwrap_or(&uri).to_string();
        
        // Spawn background fetch - don't block UI
        let cache_key_clone = cache_key.clone();
        std::thread::spawn(move || {
            let result = FEED_RUNTIME.block_on(async {
                // Try to parse as different nostr types
                let event_id = if bech32_str.starts_with("nevent") {
                    match Nip19Event::from_bech32(&bech32_str) {
                        Ok(nip19) => Some(nip19.event_id),
                        Err(_) => None,
                    }
                } else if bech32_str.starts_with("note") {
                    match EventId::from_bech32(&bech32_str) {
                        Ok(id) => Some(id),
                        Err(_) => None,
                    }
                } else if bech32_str.starts_with("naddr") {
                    match Nip19Coordinate::from_bech32(&bech32_str) {
                        Ok(coord) => {
                            let rm = RELAY_MANAGER.read().unwrap();
                            let Some(manager) = rm.as_ref() else {
                                return Err("Relay manager not initialized".to_string());
                            };
                            
                            let filter = Filter::new()
                                .kind(coord.coordinate.kind)
                                .author(coord.coordinate.public_key)
                                .identifier(&coord.coordinate.identifier)
                                .limit(1);
                            
                            let events = manager.client().fetch_events(filter, std::time::Duration::from_secs(3))
                                .await
                                .map_err(|e| format!("Failed to fetch naddr: {}", e))?;
                            
                            if let Some(event) = events.into_iter().next() {
                                let profiles = manager.fetch_profiles(&[event.pubkey]).await.unwrap_or_default();
                                let profile = profiles.iter().next().and_then(|p| {
                                    Metadata::from_json(&p.content).ok().map(|m| ProfileCache::from_metadata(&m))
                                });
                                let note = DisplayNote::from_event(&event, profile.as_ref());
                                return Ok(note.to_json());
                            }
                            return Err("naddr event not found".to_string());
                        }
                        Err(_) => None,
                    }
                } else {
                    None
                };
                
                if let Some(event_id) = event_id {
                    let rm = RELAY_MANAGER.read().unwrap();
                    let Some(manager) = rm.as_ref() else {
                        return Err("Relay manager not initialized".to_string());
                    };
                    
                    let filter = Filter::new().id(event_id).limit(1);
                    let events = manager.client().fetch_events(filter, std::time::Duration::from_secs(3))
                        .await
                        .map_err(|e| format!("Failed to fetch event: {}", e))?;
                    
                    if let Some(event) = events.into_iter().next() {
                        let profiles = manager.fetch_profiles(&[event.pubkey]).await.unwrap_or_default();
                        let profile = profiles.iter().next().and_then(|p| {
                            Metadata::from_json(&p.content).ok().map(|m| ProfileCache::from_metadata(&m))
                        });
                        let note = DisplayNote::from_event(&event, profile.as_ref());
                        return Ok(note.to_json());
                    }
                }
                Err("Event not found".to_string())
            });
            
            // Cache the result
            if let Ok(json) = result {
                if let Ok(mut cache) = EMBEDDED_EVENT_CACHE.write() {
                    cache.insert(cache_key_clone.clone(), json);
                }
            }
            
            // Remove from pending
            if let Ok(mut pending) = PENDING_EMBEDS.write() {
                pending.remove(&cache_key_clone);
            }
        });
        
        // Return empty while fetching - QML shows loading state
        QString::from("{}")
    }
    
    /// Fetch an embedded nostr profile by nprofile/npub bech32 string
    /// Uses caching to avoid blocking the UI thread during scroll
    pub fn fetch_embedded_profile(self: Pin<&mut Self>, nostr_uri: &QString) -> QString {
        let uri = nostr_uri.to_string();
        let cache_key = uri.clone();
        
        // Check cache first - return immediately if cached
        if let Ok(cache) = EMBEDDED_PROFILE_CACHE.read() {
            if let Some(cached) = cache.get(&cache_key) {
                return QString::from(cached);
            }
        }
        
        // Check if already pending
        {
            let pending = PENDING_EMBEDS.read().unwrap();
            if pending.contains(&cache_key) {
                return QString::from("{}");
            }
        }
        
        // Mark as pending
        {
            let mut pending = PENDING_EMBEDS.write().unwrap();
            pending.insert(cache_key.clone());
        }
        
        // Strip nostr: prefix if present
        let bech32_str = uri.strip_prefix("nostr:").unwrap_or(&uri).to_string();
        
        // Spawn background fetch
        let cache_key_clone = cache_key.clone();
        std::thread::spawn(move || {
            let result = FEED_RUNTIME.block_on(async {
                let pubkey = if bech32_str.starts_with("nprofile") {
                    match Nip19Profile::from_bech32(&bech32_str) {
                        Ok(nip19) => Some(nip19.public_key),
                        Err(_) => None,
                    }
                } else if bech32_str.starts_with("npub") {
                    match PublicKey::from_bech32(&bech32_str) {
                        Ok(pk) => Some(pk),
                        Err(_) => None,
                    }
                } else {
                    None
                };
                
                if let Some(pk) = pubkey {
                    let rm = RELAY_MANAGER.read().unwrap();
                    let Some(manager) = rm.as_ref() else {
                        return Err("Relay manager not initialized".to_string());
                    };
                    
                    let profiles = manager.fetch_profiles(&[pk]).await.unwrap_or_default();
                    
                    if let Some(profile_event) = profiles.into_iter().next() {
                        if let Ok(metadata) = Metadata::from_json(&profile_event.content) {
                            let profile = ProfileCache::from_metadata(&metadata);
                            let npub = pk.to_bech32().unwrap_or_default();
                            let json = serde_json::json!({
                                "pubkey": pk.to_hex(),
                                "npub": npub,
                                "name": profile.name,
                                "displayName": profile.display_name,
                                "picture": profile.picture,
                                "banner": profile.banner,
                                "about": profile.about,
                                "website": profile.website,
                                "nip05": profile.nip05,
                                "lud16": profile.lud16,
                            });
                            return Ok(json.to_string());
                        }
                    }
                    
                    // Return minimal profile with just pubkey
                    let npub = pk.to_bech32().unwrap_or_default();
                    let json = serde_json::json!({
                        "pubkey": pk.to_hex(),
                        "npub": npub,
                    });
                    return Ok(json.to_string());
                }
                Err("Profile not found".to_string())
            });
            
            // Cache the result
            if let Ok(json) = result {
                if let Ok(mut cache) = EMBEDDED_PROFILE_CACHE.write() {
                    cache.insert(cache_key_clone.clone(), json);
                }
            }
            
            // Remove from pending
            if let Ok(mut pending) = PENDING_EMBEDS.write() {
                pending.remove(&cache_key_clone);
            }
        });
        
        QString::from("{}")
    }
    
    /// Fetch link preview metadata for a URL
    /// Uses caching to avoid blocking the UI thread during scroll
    pub fn fetch_link_preview(self: Pin<&mut Self>, url: &QString) -> QString {
        let url_str = url.to_string();
        
        // Skip media URLs - they're displayed directly
        let lower = url_str.to_lowercase();
        if lower.ends_with(".jpg") || lower.ends_with(".jpeg") || 
           lower.ends_with(".png") || lower.ends_with(".gif") || 
           lower.ends_with(".webp") || lower.ends_with(".mp4") ||
           lower.ends_with(".webm") || lower.ends_with(".mov") {
            return QString::from("{}");
        }
        
        let cache_key = url_str.clone();
        
        // Check cache first
        if let Ok(cache) = LINK_PREVIEW_CACHE.read() {
            if let Some(cached) = cache.get(&cache_key) {
                return QString::from(cached);
            }
        }
        
        // Check if already pending
        {
            let pending = PENDING_EMBEDS.read().unwrap();
            if pending.contains(&cache_key) {
                return QString::from("{}");
            }
        }
        
        // Mark as pending
        {
            let mut pending = PENDING_EMBEDS.write().unwrap();
            pending.insert(cache_key.clone());
        }
        
        // Spawn background fetch
        let cache_key_clone = cache_key.clone();
        let url_clone = url_str.clone();
        std::thread::spawn(move || {
            let result = FEED_RUNTIME.block_on(async {
                fetch_og_metadata(&url_clone).await
            });
            
            // Cache the result (even errors to avoid refetching)
            if let Ok(mut cache) = LINK_PREVIEW_CACHE.write() {
                let cached_val = match result {
                    Ok(metadata) => metadata,
                    Err(_) => "{}".to_string(),
                };
                cache.insert(cache_key_clone.clone(), cached_val);
            }
            
            // Remove from pending
            if let Ok(mut pending) = PENDING_EMBEDS.write() {
                pending.remove(&cache_key_clone);
            }
        });
        
        QString::from("{}")
    }
}

/// Fetch OpenGraph metadata from a URL
async fn fetch_og_metadata(url: &str) -> Result<String, String> {
    use std::time::Duration;
    
    let client = reqwest::Client::builder()
        .timeout(Duration::from_secs(5))
        .user_agent("Mozilla/5.0 (compatible; PlebClient/1.0)")
        .build()
        .map_err(|e| format!("Failed to create HTTP client: {}", e))?;
    
    let response = client.get(url)
        .send()
        .await
        .map_err(|e| format!("Failed to fetch URL: {}", e))?;
    
    if !response.status().is_success() {
        return Err(format!("HTTP error: {}", response.status()));
    }
    
    let html = response.text().await
        .map_err(|e| format!("Failed to read response: {}", e))?;
    
    // Parse OpenGraph meta tags
    let mut title = None;
    let mut description = None;
    let mut image = None;
    let mut site_name = None;
    
    // Simple regex-based OG parsing (faster than full HTML parsing)
    let og_regex = regex::Regex::new(r#"<meta[^>]*(?:property|name)=["']og:([^"']+)["'][^>]*content=["']([^"']*?)["'][^>]*/?>|<meta[^>]*content=["']([^"']*?)["'][^>]*(?:property|name)=["']og:([^"']+)["'][^>]*/?>"#).unwrap();
    
    for cap in og_regex.captures_iter(&html) {
        let (prop, content) = if let (Some(p), Some(c)) = (cap.get(1), cap.get(2)) {
            (p.as_str(), c.as_str())
        } else if let (Some(c), Some(p)) = (cap.get(3), cap.get(4)) {
            (p.as_str(), c.as_str())
        } else {
            continue;
        };
        
        match prop {
            "title" => title = Some(content.to_string()),
            "description" => description = Some(content.to_string()),
            "image" => image = Some(content.to_string()),
            "site_name" => site_name = Some(content.to_string()),
            _ => {}
        }
    }
    
    // Fallback to regular title tag if no og:title
    if title.is_none() {
        let title_regex = regex::Regex::new(r#"<title[^>]*>([^<]+)</title>"#).unwrap();
        if let Some(cap) = title_regex.captures(&html) {
            title = Some(cap[1].to_string());
        }
    }
    
    // Fallback to meta description if no og:description
    if description.is_none() {
        let desc_regex = regex::Regex::new(r#"<meta[^>]*name=["']description["'][^>]*content=["']([^"']*?)["'][^>]*/?>"#).unwrap();
        if let Some(cap) = desc_regex.captures(&html) {
            description = Some(cap[1].to_string());
        }
    }
    
    // Get site name from URL if not in OG
    if site_name.is_none() {
        if let Ok(parsed) = url::Url::parse(url) {
            site_name = parsed.host_str().map(|h| h.to_string());
        }
    }
    
    // Only return if we have at least a title
    if title.is_none() && description.is_none() && image.is_none() {
        return Err("No metadata found".to_string());
    }
    
    // Decode HTML entities
    let decode_html = |s: &str| {
        s.replace("&amp;", "&")
         .replace("&lt;", "<")
         .replace("&gt;", ">")
         .replace("&quot;", "\"")
         .replace("&#39;", "'")
         .replace("&nbsp;", " ")
    };
    
    let json = serde_json::json!({
        "url": url,
        "title": title.map(|t| decode_html(&t)),
        "description": description.map(|d| decode_html(&d)),
        "image": image,
        "siteName": site_name,
    });
    
    Ok(json.to_string())
}

/// Set the signer client for feed operations
pub fn set_feed_signer(signer: Option<SignerClient>) {
    FEED_RUNTIME.block_on(async {
        let mut feed_signer = FEED_SIGNER.lock().await;
        *feed_signer = signer;
    });
}

/// Set the user's nsec for local signing
pub fn set_feed_nsec(nsec: Option<String>) {
    let mut feed_nsec = FEED_NSEC.write().unwrap();
    *feed_nsec = nsec;
}

/// Get the nsec for creating relay managers in other bridges
pub fn get_feed_nsec() -> Option<String> {
    FEED_NSEC.read().unwrap().clone()
}

/// Create a RelayManager with signing keys if available
pub fn create_authenticated_relay_manager() -> RelayManager {
    let nsec_opt = FEED_NSEC.read().unwrap();
    if let Some(nsec) = nsec_opt.as_ref() {
        if let Ok(secret_key) = SecretKey::parse(nsec) {
            let keys = Keys::new(secret_key);
            return RelayManager::with_keys(keys);
        }
    }
    RelayManager::new()
}
