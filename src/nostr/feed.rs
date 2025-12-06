//! Feed manager - orchestrates fetching and caching of different feed types

use std::sync::Arc;
use nostr_sdk::prelude::*;
use tokio::sync::RwLock;
use super::database::NostrDbManager;
use super::relay::RelayManager;
use super::profile::ProfileCache;

/// Feed types supported by the application
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum FeedType {
    /// Posts from everyone the user follows (no replies)
    Following,
    /// Replies to posts from followed users
    Replies,
    /// Global feed - everything
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
    
    pub fn as_str(&self) -> &'static str {
        match self {
            FeedType::Following => "following",
            FeedType::Replies => "replies",
            FeedType::Global => "global",
        }
    }
}

/// A processed note ready for display
#[derive(Debug, Clone)]
pub struct DisplayNote {
    pub id: String,
    pub pubkey: String,
    pub author_name: String,
    pub author_picture: Option<String>,
    pub author_nip05: Option<String>,
    pub content: String,
    pub created_at: i64,
    pub likes: u32,
    pub reposts: u32,
    pub replies: u32,
    pub zap_amount: u64,
    pub zap_count: u32,  // Number of zaps received
    pub reactions: std::collections::HashMap<String, u32>,  // emoji -> count
    pub images: Vec<String>,
    pub videos: Vec<String>,
    pub is_reply: bool,
    pub reply_to: Option<String>,
    pub is_repost: bool,
    pub repost_author_name: Option<String>,
    pub repost_author_picture: Option<String>,
}

impl DisplayNote {
    /// Create from a nostr-sdk Event
    pub fn from_event(event: &Event, profile: Option<&ProfileCache>) -> Self {
        let id = event.id.to_hex();
        let pubkey = event.pubkey.to_hex();
        let created_at = event.created_at.as_u64() as i64;
        
        // Check if this is a repost (kind 6)
        let is_repost = event.kind == Kind::Repost;
        
        // For reposts, try to extract the original note content
        let content = if is_repost {
            // Kind 6 reposts may contain the original note JSON in content
            // or just reference it via 'e' tag
            if !event.content.is_empty() {
                // Try to parse embedded event JSON
                if let Ok(embedded) = serde_json::from_str::<serde_json::Value>(&event.content) {
                    embedded.get("content")
                        .and_then(|c| c.as_str())
                        .unwrap_or(&event.content)
                        .to_string()
                } else {
                    event.content.to_string()
                }
            } else {
                // Empty content repost - we'd need to fetch the original note
                "🔁 Reposted".to_string()
            }
        } else {
            event.content.to_string()
        };
        
        // Extract media URLs from content
        let (images, videos) = extract_media_urls(&content);
        
        // Check if this is a reply
        let (is_reply, reply_to) = check_reply_status(event);
        
        // Get author info from profile cache
        let (author_name, author_picture, author_nip05) = profile
            .map(|p| (
                p.name.clone().unwrap_or_else(|| format_npub(&pubkey)),
                p.picture.clone(),
                p.nip05.clone(),
            ))
            .unwrap_or_else(|| (format_npub(&pubkey), None, None));
        
        // For reposts, the reposter info goes in repost_author fields
        let (repost_author_name, repost_author_picture) = if is_repost {
            (Some(author_name.clone()), author_picture.clone())
        } else {
            (None, None)
        };
        
        Self {
            id,
            pubkey,
            author_name,
            author_picture,
            author_nip05,
            content,
            created_at,
            likes: 0,
            reposts: 0,
            replies: 0,
            zap_amount: 0,
            zap_count: 0,
            reactions: std::collections::HashMap::new(),
            images,
            videos,
            is_reply,
            reply_to,
            is_repost,
            repost_author_name,
            repost_author_picture,
        }
    }
    
    /// Serialize to JSON for QML consumption
    pub fn to_json(&self) -> String {
        serde_json::json!({
            "id": self.id,
            "pubkey": self.pubkey,
            "authorName": self.author_name,
            "authorPicture": self.author_picture,
            "authorNip05": self.author_nip05,
            "content": self.content,
            "createdAt": self.created_at,
            "likes": self.likes,
            "reposts": self.reposts,
            "replies": self.replies,
            "zapAmount": self.zap_amount,
            "zapCount": self.zap_count,
            "reactions": self.reactions,
            "images": self.images,
            "videos": self.videos,
            "isReply": self.is_reply,
            "replyTo": self.reply_to,
            "isRepost": self.is_repost,
            "repostAuthorName": self.repost_author_name,
            "repostAuthorPicture": self.repost_author_picture,
        }).to_string()
    }
}

/// Feed manager that coordinates fetching and caching
pub struct FeedManager {
    db: Option<Arc<NostrDbManager>>,
    relay_manager: Option<Arc<RwLock<RelayManager>>>,
    current_feed: FeedType,
    notes: Vec<DisplayNote>,
    profiles: std::collections::HashMap<String, ProfileCache>,
}

impl FeedManager {
    pub fn new() -> Self {
        Self {
            db: None,
            relay_manager: None,
            current_feed: FeedType::Following,
            notes: Vec::new(),
            profiles: std::collections::HashMap::new(),
        }
    }
    
    /// Set the database
    pub fn set_database(&mut self, db: Arc<NostrDbManager>) {
        self.db = Some(db);
    }
    
    /// Set the relay manager
    pub fn set_relay_manager(&mut self, manager: Arc<RwLock<RelayManager>>) {
        self.relay_manager = Some(manager);
    }
    
    /// Get current feed type
    pub fn current_feed(&self) -> FeedType {
        self.current_feed
    }
    
    /// Get notes
    pub fn notes(&self) -> &[DisplayNote] {
        &self.notes
    }
    
    /// Get a note by index
    pub fn get_note(&self, index: usize) -> Option<&DisplayNote> {
        self.notes.get(index)
    }
    
    /// Get note count
    pub fn note_count(&self) -> usize {
        self.notes.len()
    }
    
    /// Load a feed type
    pub async fn load_feed(&mut self, feed_type: FeedType, limit: u64) -> Result<(), String> {
        self.current_feed = feed_type;
        
        let Some(relay_manager) = &self.relay_manager else {
            return Err("Relay manager not initialized".to_string());
        };
        
        let manager = relay_manager.read().await;
        
        let events = match feed_type {
            FeedType::Following => manager.fetch_following_feed(limit, None).await?,
            FeedType::Replies => manager.fetch_replies_feed(limit, None).await?,
            FeedType::Global => manager.fetch_global_feed(limit, None).await?,
        };
        
        // Collect unique pubkeys for profile fetching
        let pubkeys: Vec<PublicKey> = events
            .iter()
            .map(|e| e.pubkey)
            .collect::<std::collections::HashSet<_>>()
            .into_iter()
            .collect();
        
        // Fetch profiles for authors
        let profiles = manager.fetch_profiles(&pubkeys).await.unwrap_or_default();
        
        // Parse profiles and update cache
        for profile_event in profiles.iter() {
            if let Ok(metadata) = Metadata::from_json(&profile_event.content) {
                let pubkey_hex = profile_event.pubkey.to_hex();
                self.profiles.insert(pubkey_hex, ProfileCache::from_metadata(&metadata));
            }
        }
        
        // Store events in database if available
        if let Some(db) = &self.db {
            for event in events.iter() {
                if let Err(e) = db.ingest_event(event) {
                    tracing::warn!("Failed to store event: {}", e);
                }
            }
            for profile_event in profiles.iter() {
                if let Err(e) = db.ingest_event(profile_event) {
                    tracing::warn!("Failed to store profile: {}", e);
                }
            }
        }
        
        // Convert to display notes
        self.notes = events
            .iter()
            .map(|e| {
                let pubkey_hex = e.pubkey.to_hex();
                let profile = self.profiles.get(&pubkey_hex);
                DisplayNote::from_event(e, profile)
            })
            .collect();
        
        // Sort by created_at descending
        self.notes.sort_by(|a, b| b.created_at.cmp(&a.created_at));
        
        tracing::info!("Loaded {} notes for {:?} feed", self.notes.len(), feed_type);
        
        Ok(())
    }
    
    /// Load more notes (pagination)
    pub async fn load_more(&mut self, limit: u64) -> Result<usize, String> {
        let oldest_timestamp = self.notes.last().map(|n| n.created_at).unwrap_or(0);
        
        if oldest_timestamp == 0 {
            return Ok(0);
        }
        
        let Some(relay_manager) = &self.relay_manager else {
            return Err("Relay manager not initialized".to_string());
        };
        
        let manager = relay_manager.read().await;
        let until = Some(Timestamp::from(oldest_timestamp as u64 - 1));
        
        let events = match self.current_feed {
            FeedType::Following => manager.fetch_following_feed(limit, until).await?,
            FeedType::Replies => manager.fetch_replies_feed(limit, until).await?,
            FeedType::Global => manager.fetch_global_feed(limit, until).await?,
        };
        
        // Fetch profiles for new authors
        let new_pubkeys: Vec<PublicKey> = events
            .iter()
            .filter_map(|e| {
                let hex = e.pubkey.to_hex();
                if !self.profiles.contains_key(&hex) {
                    Some(e.pubkey)
                } else {
                    None
                }
            })
            .collect();
        
        if !new_pubkeys.is_empty() {
            let profiles = manager.fetch_profiles(&new_pubkeys).await.unwrap_or_default();
            for profile_event in profiles.iter() {
                if let Ok(metadata) = Metadata::from_json(&profile_event.content) {
                    let pubkey_hex = profile_event.pubkey.to_hex();
                    self.profiles.insert(pubkey_hex, ProfileCache::from_metadata(&metadata));
                }
            }
        }
        
        let new_notes: Vec<DisplayNote> = events
            .iter()
            .map(|e| {
                let pubkey_hex = e.pubkey.to_hex();
                let profile = self.profiles.get(&pubkey_hex);
                DisplayNote::from_event(e, profile)
            })
            .collect();
        
        let count = new_notes.len();
        self.notes.extend(new_notes);
        self.notes.sort_by(|a, b| b.created_at.cmp(&a.created_at));
        
        Ok(count)
    }
    
    /// Refresh the current feed
    pub async fn refresh(&mut self, limit: u64) -> Result<(), String> {
        self.notes.clear();
        self.load_feed(self.current_feed, limit).await
    }
}

/// Extract image and video URLs from content
fn extract_media_urls(content: &str) -> (Vec<String>, Vec<String>) {
    let mut images = Vec::new();
    let mut videos = Vec::new();
    
    // Simple URL regex pattern
    let url_pattern = regex::Regex::new(r"https?://[^\s<>\[\]]+").unwrap();
    
    for cap in url_pattern.find_iter(content) {
        let url = cap.as_str().to_string();
        let lower = url.to_lowercase();
        
        if lower.ends_with(".jpg") || lower.ends_with(".jpeg") || 
           lower.ends_with(".png") || lower.ends_with(".gif") || 
           lower.ends_with(".webp") {
            images.push(url);
        } else if lower.ends_with(".mp4") || lower.ends_with(".webm") ||
                  lower.ends_with(".mov") {
            videos.push(url);
        }
    }
    
    (images, videos)
}

/// Check if event is a reply and get the reply-to ID
fn check_reply_status(event: &Event) -> (bool, Option<String>) {
    for tag in event.tags.iter() {
        if let Some(TagStandard::Event { event_id, marker, .. }) = tag.as_standardized() {
            // Has an event reference with reply marker
            if marker.is_some() {
                return (true, Some(event_id.to_hex()));
            }
        }
    }
    
    // Check for old-style replies (just 'e' tag without marker)
    for tag in event.tags.iter() {
        if tag.kind() == TagKind::SingleLetter(SingleLetterTag::lowercase(Alphabet::E)) {
            if let Some(id) = tag.content() {
                return (true, Some(id.to_string()));
            }
        }
    }
    
    (false, None)
}

/// Format pubkey as shortened npub
fn format_npub(hex_pubkey: &str) -> String {
    match PublicKey::parse(hex_pubkey) {
        Ok(pk) => {
            match pk.to_bech32() {
                Ok(npub) => {
                    if npub.len() > 16 {
                        format!("{}...{}", &npub[..8], &npub[npub.len()-4..])
                    } else {
                        npub
                    }
                }
                Err(_) => format!("{}...", &hex_pubkey[..8]),
            }
        }
        Err(_) => format!("{}...", &hex_pubkey.get(..8).unwrap_or("unknown")),
    }
}
