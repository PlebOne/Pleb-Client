//! Profile bridge - exposes profile data and editing to QML

#[cxx_qt::bridge]
pub mod qobject {
    unsafe extern "C++" {
        include!("cxx-qt-lib/qstring.h");
        type QString = cxx_qt_lib::QString;
    }

    unsafe extern "RustQt" {
        #[qobject]
        #[qml_element]
        #[qproperty(QString, public_key)]
        #[qproperty(QString, name)]
        #[qproperty(QString, display_name)]
        #[qproperty(QString, about)]
        #[qproperty(QString, picture)]
        #[qproperty(QString, banner)]
        #[qproperty(QString, website)]
        #[qproperty(QString, nip05)]
        #[qproperty(QString, lud16)]
        #[qproperty(i32, following_count)]
        #[qproperty(i32, followers_count)]
        #[qproperty(i32, notes_count)]
        #[qproperty(bool, is_loading)]
        #[qproperty(bool, is_own_profile)]
        #[qproperty(bool, is_following)]
        #[qproperty(QString, error_message)]
        type ProfileController = super::ProfileControllerRust;

        /// Load profile for a given pubkey
        #[qinvokable]
        fn load_profile(self: Pin<&mut ProfileController>, pubkey: &QString);
        
        /// Reload current profile
        #[qinvokable]
        fn reload(self: Pin<&mut ProfileController>);
        
        /// Update profile (for own profile only)
        #[qinvokable]
        fn update_profile(
            self: Pin<&mut ProfileController>,
            name: &QString,
            display_name: &QString,
            about: &QString,
            picture: &QString,
            banner: &QString,
            website: &QString,
            lud16: &QString,
        );
        
        /// Follow user
        #[qinvokable]
        fn follow_user(self: Pin<&mut ProfileController>);
        
        /// Unfollow user
        #[qinvokable]
        fn unfollow_user(self: Pin<&mut ProfileController>);
        
        /// Get following list (returns JSON array of pubkeys)
        #[qinvokable]
        fn get_following_list(self: &ProfileController) -> QString;
        
        /// Get followers list (returns JSON array of pubkeys)
        #[qinvokable]
        fn get_followers_list(self: &ProfileController) -> QString;
        
        /// Get user's notes count
        #[qinvokable]
        fn fetch_notes_count(self: Pin<&mut ProfileController>);
        
        /// Get following item at index (returns JSON)
        #[qinvokable]
        fn get_following_at(self: &ProfileController, index: i32) -> QString;
        
        /// Get follower item at index (returns JSON)
        #[qinvokable]
        fn get_follower_at(self: &ProfileController, index: i32) -> QString;
        
        /// Set the logged-in user's pubkey (to determine is_own_profile)
        #[qinvokable]
        fn set_logged_in_user(self: Pin<&mut ProfileController>, pubkey: &QString);
    }

    unsafe extern "RustQt" {
        /// Emitted when profile is loaded
        #[qsignal]
        fn profile_loaded(self: Pin<&mut ProfileController>);
        
        /// Emitted when profile update succeeds
        #[qsignal]
        fn profile_updated(self: Pin<&mut ProfileController>);
        
        /// Emitted when follow status changes
        #[qsignal]
        fn follow_status_changed(self: Pin<&mut ProfileController>);
        
        /// Emitted when following list is loaded
        #[qsignal]
        fn following_loaded(self: Pin<&mut ProfileController>);
        
        /// Emitted when followers list is loaded
        #[qsignal]
        fn followers_loaded(self: Pin<&mut ProfileController>);
        
        /// Emitted when an error occurs
        #[qsignal]
        fn error_occurred(self: Pin<&mut ProfileController>, error: &QString);
    }
    
    // Enable threading support for background work with UI updates
    impl cxx_qt::Threading for ProfileController {}
}

use std::pin::Pin;
use cxx_qt_lib::QString;
use cxx_qt::{CxxQtType, Threading};
use nostr_sdk::prelude::*;
use crate::nostr::relay::RelayManager;
use crate::nostr::profile::ProfileCache;
use crate::bridge::feed_bridge::create_authenticated_relay_manager;

// Global tokio runtime for profile operations
lazy_static::lazy_static! {
    static ref PROFILE_RUNTIME: tokio::runtime::Runtime = tokio::runtime::Runtime::new().unwrap();
}

/// Simple profile info for following/followers display
#[derive(Debug, Clone)]
struct ProfileListItem {
    pubkey: String,
    name: Option<String>,
    display_name: Option<String>,
    picture: Option<String>,
    nip05: Option<String>,
}

impl ProfileListItem {
    fn to_json(&self) -> String {
        serde_json::json!({
            "pubkey": self.pubkey,
            "name": self.name,
            "displayName": self.display_name,
            "picture": self.picture,
            "nip05": self.nip05,
        }).to_string()
    }
}

/// Rust implementation of ProfileController
pub struct ProfileControllerRust {
    public_key: QString,
    name: QString,
    display_name: QString,
    about: QString,
    picture: QString,
    banner: QString,
    website: QString,
    nip05: QString,
    lud16: QString,
    following_count: i32,
    followers_count: i32,
    notes_count: i32,
    is_loading: bool,
    is_own_profile: bool,
    is_following: bool,
    error_message: QString,
    
    // Internal state
    target_pubkey: Option<PublicKey>,
    logged_in_pubkey: Option<PublicKey>,
    following_list: Vec<ProfileListItem>,
    followers_list: Vec<ProfileListItem>,
    user_following: Vec<PublicKey>, // Who the logged-in user is following
}

impl Default for ProfileControllerRust {
    fn default() -> Self {
        Self {
            public_key: QString::from(""),
            name: QString::from(""),
            display_name: QString::from(""),
            about: QString::from(""),
            picture: QString::from(""),
            banner: QString::from(""),
            website: QString::from(""),
            nip05: QString::from(""),
            lud16: QString::from(""),
            following_count: 0,
            followers_count: 0,
            notes_count: 0,
            is_loading: false,
            is_own_profile: false,
            is_following: false,
            error_message: QString::from(""),
            target_pubkey: None,
            logged_in_pubkey: None,
            following_list: Vec::new(),
            followers_list: Vec::new(),
            user_following: Vec::new(),
        }
    }
}

impl qobject::ProfileController {
    /// Set the logged-in user's pubkey
    pub fn set_logged_in_user(mut self: Pin<&mut Self>, pubkey: &QString) {
        let pubkey_str = pubkey.to_string();
        let parsed = if pubkey_str.starts_with("npub") {
            PublicKey::from_bech32(&pubkey_str).ok()
        } else {
            PublicKey::from_hex(&pubkey_str).ok()
        };
        
        {
            let mut rust = self.as_mut().rust_mut();
            rust.logged_in_pubkey = parsed;
        }
        
        // Fetch who this user is following
        self.fetch_user_following();
    }
    
    /// Fetch who the logged-in user is following
    fn fetch_user_following(self: Pin<&mut Self>) {
        let logged_in = {
            self.as_ref().logged_in_pubkey.clone()
        };
        
        let Some(pubkey) = logged_in else {
            return;
        };
        
        let qt_thread = self.qt_thread();
        
        std::thread::spawn(move || {
            let result = PROFILE_RUNTIME.block_on(async {
                let mut manager = create_authenticated_relay_manager();
                manager.connect().await?;
                manager.fetch_contact_list(&pubkey).await
            });
            
            if let Ok(following) = result {
                let _ = qt_thread.queue(move |mut qobject| {
                    let mut rust = qobject.as_mut().rust_mut();
                    rust.user_following = following;
                });
            }
        });
    }
    
    /// Load profile for a given pubkey
    pub fn load_profile(mut self: Pin<&mut Self>, pubkey: &QString) {
        let pubkey_str = pubkey.to_string();
        tracing::info!("Loading profile for: {}", pubkey_str);
        
        // Parse pubkey
        let target_pk = if pubkey_str.starts_with("npub") {
            PublicKey::from_bech32(&pubkey_str).ok()
        } else {
            PublicKey::from_hex(&pubkey_str).ok()
        };
        
        let Some(target_pubkey) = target_pk else {
            self.as_mut().set_error_message(QString::from("Invalid public key"));
            self.as_mut().error_occurred(&QString::from("Invalid public key"));
            return;
        };
        
        // Check if this is own profile
        let is_own = {
            let rust = self.as_ref();
            rust.logged_in_pubkey.as_ref() == Some(&target_pubkey)
        };
        
        // Check if following this user
        let is_following = {
            let rust = self.as_ref();
            rust.user_following.contains(&target_pubkey)
        };
        
        {
            let mut rust = self.as_mut().rust_mut();
            rust.target_pubkey = Some(target_pubkey.clone());
            rust.is_own_profile = is_own;
            rust.is_following = is_following;
        }
        
        self.as_mut().set_public_key(QString::from(&target_pubkey.to_hex()));
        self.as_mut().set_is_own_profile(is_own);
        self.as_mut().set_is_following(is_following);
        self.as_mut().set_is_loading(true);
        
        // Get qt_thread for UI updates
        let qt_thread = self.qt_thread();
        let pk = target_pubkey.clone();
        
        // Spawn background thread - non-blocking
        std::thread::spawn(move || {
            let result = PROFILE_RUNTIME.block_on(async {
                let mut manager = create_authenticated_relay_manager();
                manager.connect().await?;
                
                // Fetch profile metadata
                let profile_events = manager.fetch_profiles(&[pk.clone()]).await?;
                let profile = profile_events.first()
                    .and_then(|e| ProfileCache::from_event(e).ok());
                
                // Fetch following list
                let following = manager.fetch_contact_list(&pk).await?;
                
                // Fetch followers (expensive - skip for now)
                let followers: Vec<PublicKey> = Vec::new();
                
                Ok::<_, String>((profile, following, followers, pk))
            });
            
            match result {
                Ok((profile, following, followers, target_pubkey)) => {
                    let following_count = following.len() as i32;
                    let followers_count = followers.len() as i32;
                    
                    // Convert to list items
                    let following_items: Vec<ProfileListItem> = following.iter()
                        .map(|pk| ProfileListItem {
                            pubkey: pk.to_hex(),
                            name: None,
                            display_name: None,
                            picture: None,
                            nip05: None,
                        })
                        .collect();
                    
                    let _ = qt_thread.queue(move |mut qobject| {
                        {
                            let mut rust = qobject.as_mut().rust_mut();
                            rust.following_list = following_items;
                            rust.followers_list = Vec::new();
                        }
                        
                        if let Some(p) = profile {
                            qobject.as_mut().set_name(QString::from(&p.name.unwrap_or_default()));
                            qobject.as_mut().set_display_name(QString::from(&p.display_name.unwrap_or_default()));
                            qobject.as_mut().set_about(QString::from(&p.about.unwrap_or_default()));
                            qobject.as_mut().set_picture(QString::from(&p.picture.unwrap_or_default()));
                            qobject.as_mut().set_banner(QString::from(&p.banner.unwrap_or_default()));
                            qobject.as_mut().set_website(QString::from(&p.website.unwrap_or_default()));
                            qobject.as_mut().set_nip05(QString::from(&p.nip05.unwrap_or_default()));
                            qobject.as_mut().set_lud16(QString::from(&p.lud16.unwrap_or_default()));
                        } else {
                            // No profile found - use defaults
                            let npub = target_pubkey.to_bech32()
                                .map(|s| format!("{}...", &s[..16]))
                                .unwrap_or_else(|_| "Unknown".to_string());
                            qobject.as_mut().set_display_name(QString::from(&npub));
                        }
                        
                        qobject.as_mut().set_following_count(following_count);
                        qobject.as_mut().set_followers_count(followers_count);
                        qobject.as_mut().set_is_loading(false);
                        qobject.as_mut().set_error_message(QString::from(""));
                        qobject.as_mut().profile_loaded();
                        
                        tracing::info!("Profile loaded: following={}, followers={}", following_count, followers_count);
                    });
                }
                Err(e) => {
                    let error_msg = e.clone();
                    let _ = qt_thread.queue(move |mut qobject| {
                        tracing::error!("Failed to load profile: {}", error_msg);
                        qobject.as_mut().set_is_loading(false);
                        qobject.as_mut().set_error_message(QString::from(&error_msg));
                        qobject.as_mut().error_occurred(&QString::from(&error_msg));
                    });
                }
            }
        });
    }
    
    /// Reload current profile
    pub fn reload(mut self: Pin<&mut Self>) {
        let pubkey = {
            self.as_ref().target_pubkey.clone()
        };
        
        if let Some(pk) = pubkey {
            let hex = pk.to_hex();
            self.load_profile(&QString::from(&hex));
        }
    }
    
    /// Update profile (for own profile only)
    pub fn update_profile(
        mut self: Pin<&mut Self>,
        name: &QString,
        display_name: &QString,
        about: &QString,
        picture: &QString,
        banner: &QString,
        website: &QString,
        lud16: &QString,
    ) {
        let is_own = {
            self.as_ref().is_own_profile
        };
        
        if !is_own {
            self.as_mut().set_error_message(QString::from("Cannot edit other users' profiles"));
            self.as_mut().error_occurred(&QString::from("Cannot edit other users' profiles"));
            return;
        }
        
        self.as_mut().set_is_loading(true);
        
        // Build metadata
        let metadata = Metadata::new()
            .name(&name.to_string())
            .display_name(&display_name.to_string())
            .about(&about.to_string())
            .picture(url::Url::parse(&picture.to_string()).ok().unwrap_or_else(|| url::Url::parse("https://example.com").unwrap()))
            .banner(url::Url::parse(&banner.to_string()).ok().unwrap_or_else(|| url::Url::parse("https://example.com").unwrap()))
            .website(url::Url::parse(&website.to_string()).ok().unwrap_or_else(|| url::Url::parse("https://example.com").unwrap()))
            .lud16(&lud16.to_string());
        
        // TODO: Sign and publish the metadata event
        // This requires access to the user's keys or signer
        // For now, we just update the local state
        
        self.as_mut().set_name(name.clone());
        self.as_mut().set_display_name(display_name.clone());
        self.as_mut().set_about(about.clone());
        self.as_mut().set_picture(picture.clone());
        self.as_mut().set_banner(banner.clone());
        self.as_mut().set_website(website.clone());
        self.as_mut().set_lud16(lud16.clone());
        self.as_mut().set_is_loading(false);
        self.as_mut().profile_updated();
        
        tracing::info!("Profile updated locally (publishing not yet implemented)");
    }
    
    /// Follow user
    pub fn follow_user(mut self: Pin<&mut Self>) {
        let target = {
            self.as_ref().target_pubkey.clone()
        };
        
        let Some(_target_pk) = target else {
            return;
        };
        
        // TODO: Update contact list and publish
        // For now, just update local state
        self.as_mut().set_is_following(true);
        {
            let mut rust = self.as_mut().rust_mut();
            if let Some(pk) = rust.target_pubkey.clone() {
                if !rust.user_following.contains(&pk) {
                    rust.user_following.push(pk);
                }
            }
        }
        self.as_mut().follow_status_changed();
        tracing::info!("Follow status changed to: following");
    }
    
    /// Unfollow user
    pub fn unfollow_user(mut self: Pin<&mut Self>) {
        let target = {
            self.as_ref().target_pubkey.clone()
        };
        
        let Some(_target_pk) = target else {
            return;
        };
        
        // TODO: Update contact list and publish
        // For now, just update local state
        self.as_mut().set_is_following(false);
        {
            let mut rust = self.as_mut().rust_mut();
            if let Some(pk) = rust.target_pubkey.clone() {
                rust.user_following.retain(|p| *p != pk);
            }
        }
        self.as_mut().follow_status_changed();
        tracing::info!("Follow status changed to: not following");
    }
    
    /// Get following list as JSON
    pub fn get_following_list(&self) -> QString {
        let json = serde_json::to_string(&self.following_list.iter().map(|i| i.to_json()).collect::<Vec<_>>())
            .unwrap_or_else(|_| "[]".to_string());
        QString::from(&json)
    }
    
    /// Get followers list as JSON
    pub fn get_followers_list(&self) -> QString {
        let json = serde_json::to_string(&self.followers_list.iter().map(|i| i.to_json()).collect::<Vec<_>>())
            .unwrap_or_else(|_| "[]".to_string());
        QString::from(&json)
    }
    
    /// Fetch notes count for current profile
    pub fn fetch_notes_count(self: Pin<&mut Self>) {
        let target = {
            self.as_ref().target_pubkey.clone()
        };
        
        let Some(pk) = target else {
            return;
        };
        
        let qt_thread = self.qt_thread();
        
        std::thread::spawn(move || {
            let result = PROFILE_RUNTIME.block_on(async {
                let mut manager = create_authenticated_relay_manager();
                manager.connect().await?;
                
                // Fetch recent notes by this author
                let filter = Filter::new()
                    .author(pk)
                    .kind(Kind::TextNote)
                    .limit(500); // Just get a rough count
                
                let events = manager.client().fetch_events(filter, std::time::Duration::from_secs(5)).await
                    .map_err(|e| e.to_string())?;
                
                Ok::<_, String>(events.len())
            });
            
            if let Ok(count) = result {
                let _ = qt_thread.queue(move |mut qobject| {
                    qobject.as_mut().set_notes_count(count as i32);
                });
            }
        });
    }
    
    /// Get following item at index
    pub fn get_following_at(&self, index: i32) -> QString {
        if let Some(item) = self.following_list.get(index as usize) {
            QString::from(&item.to_json())
        } else {
            QString::from("{}")
        }
    }
    
    /// Get follower item at index
    pub fn get_follower_at(&self, index: i32) -> QString {
        if let Some(item) = self.followers_list.get(index as usize) {
            QString::from(&item.to_json())
        } else {
            QString::from("{}")
        }
    }
}
