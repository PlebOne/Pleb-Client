//! Relay manager - handles connections to Nostr relays using nostr-sdk

#![allow(dead_code)]  // Planned infrastructure for future integration

use std::sync::Arc;
use std::time::Duration;
use nostr_sdk::prelude::*;
use std::sync::RwLock;
use futures::future::join_all;

/// Default relays for initial connection
pub const DEFAULT_RELAYS: &[&str] = &[
    "wss://relay.pleb.one",
    "wss://relay.primal.net",
    "wss://relay.damus.io",
    "wss://nos.lol",
];

/// Discovery relays for NIP-65 relay list lookups (outbox model)
/// These relays are used to find users' relay preferences
pub const DISCOVERY_RELAYS: &[&str] = &[
    "wss://purplepag.es",
    "wss://relay.nos.social",
    "wss://relay.nostr.band",
];

/// Default timeout for relay operations
pub const DEFAULT_TIMEOUT: Duration = Duration::from_secs(10);

/// Manages relay connections
pub struct RelayManager {
    client: Client,
    connected: bool,
    user_pubkey: Option<PublicKey>,
    following: Vec<PublicKey>,
}

impl RelayManager {
    /// Create a new relay manager
    pub fn new() -> Self {
        let client = Client::default();
        
        Self {
            client,
            connected: false,
            user_pubkey: None,
            following: Vec::new(),
        }
    }
    
    /// Create relay manager with a signer (for posting)
    pub fn with_keys(keys: Keys) -> Self {
        let client = Client::new(keys);
        
        Self {
            client,
            connected: false,
            user_pubkey: None,
            following: Vec::new(),
        }
    }
    
    /// Get the nostr-sdk client
    pub fn client(&self) -> &Client {
        &self.client
    }
    
    /// Set the current user's pubkey
    pub fn set_user_pubkey(&mut self, pubkey: PublicKey) {
        self.user_pubkey = Some(pubkey);
    }
    
    /// Get following list
    pub fn following(&self) -> &[PublicKey] {
        &self.following
    }
    
    /// Set following list
    pub fn set_following(&mut self, following: Vec<PublicKey>) {
        self.following = following;
    }
    
    /// Connect to default relays
    pub async fn connect(&mut self) -> Result<(), String> {
        tracing::info!("Connecting to {} default relays...", DEFAULT_RELAYS.len());
        
        // Add default read/write relays
        for relay_url in DEFAULT_RELAYS {
            if let Err(e) = self.client.add_relay(*relay_url).await {
                tracing::warn!("Failed to add relay {}: {}", relay_url, e);
            }
        }
        
        // Add discovery relays for NIP-65 lookups (outbox model)
        // These help us find users' preferred relays
        tracing::info!("Adding {} discovery relays for NIP-65 lookups...", DISCOVERY_RELAYS.len());
        for relay_url in DISCOVERY_RELAYS {
            if let Err(e) = self.client.add_relay(*relay_url).await {
                tracing::warn!("Failed to add discovery relay {}: {}", relay_url, e);
            }
        }
        
        self.client.connect().await;
        self.connected = true;
        
        tracing::info!("Connected to relays");
        Ok(())
    }
    
    /// Connect to specific relays
    pub async fn connect_to(&mut self, relay_urls: &[String]) -> Result<(), String> {
        for url in relay_urls {
            if let Err(e) = self.client.add_relay(url.as_str()).await {
                tracing::warn!("Failed to add relay {}: {}", url, e);
            }
        }
        
        self.client.connect().await;
        self.connected = true;
        Ok(())
    }
    
    /// Disconnect from all relays
    pub async fn disconnect(&mut self) {
        self.client.disconnect().await;
        self.connected = false;
    }
    
    /// Fetch the user's contact list (following)
    pub async fn fetch_contact_list(&mut self, pubkey: &PublicKey) -> Result<Vec<PublicKey>, String> {
        let filter = Filter::new()
            .kind(Kind::ContactList)
            .author(*pubkey)
            .limit(1);
        
        let events = self.client
            .fetch_events(filter, DEFAULT_TIMEOUT)
            .await
            .map_err(|e| format!("Failed to fetch contact list: {}", e))?;
        
        let following: Vec<PublicKey> = events
            .into_iter()
            .flat_map(|e| {
                e.tags
                    .iter()
                    .filter_map(|tag| {
                        if let Some(TagStandard::PublicKey { public_key, .. }) = tag.as_standardized() {
                            Some(public_key.clone())
                        } else {
                            None
                        }
                    })
                    .collect::<Vec<_>>()
            })
            .collect();
        
        self.following = following.clone();
        tracing::info!("Fetched {} contacts", self.following.len());
        
        Ok(following)
    }
    
    /// Fetch followers of a user (users who follow this pubkey)
    /// This searches for contact lists that include the target pubkey
    pub async fn fetch_followers(&self, pubkey: &PublicKey) -> Result<Vec<PublicKey>, String> {
        // Search for contact lists (kind 3) that tag this pubkey
        // This is an expensive query - relays may limit results
        let filter = Filter::new()
            .kind(Kind::ContactList)
            .pubkey(*pubkey)  // Filter for events that tag this pubkey
            .limit(500);  // Limit to prevent overload
        
        let events = self.client
            .fetch_events(filter, Duration::from_secs(15))  // Longer timeout for this query
            .await
            .map_err(|e| format!("Failed to fetch followers: {}", e))?;
        
        // Extract unique authors (the followers)
        let mut followers: Vec<PublicKey> = events
            .iter()
            .map(|e| e.pubkey)
            .collect();
        
        // Deduplicate
        followers.sort_by_key(|pk| pk.to_hex());
        followers.dedup();
        
        tracing::info!("Fetched {} followers for {}", followers.len(), pubkey.to_hex());
        
        Ok(followers)
    }
    
    /// Fetch all notes from followed users (posts, replies, reposts - everything)
    pub async fn fetch_following_feed(&self, limit: u64, until: Option<Timestamp>) -> Result<Events, String> {
        if self.following.is_empty() {
            tracing::warn!("No following list, returning empty feed");
            return Ok(Events::default());
        }
        
        // Fetch text notes (kind 1) from following - includes posts and replies
        let mut text_filter = Filter::new()
            .kind(Kind::TextNote)
            .authors(self.following.clone())
            .limit(limit as usize);
        
        if let Some(ts) = until {
            text_filter = text_filter.until(ts);
        }
        
        // Fetch reposts (kind 6) from following
        let mut repost_filter = Filter::new()
            .kind(Kind::Repost)
            .authors(self.following.clone())
            .limit((limit / 2) as usize);
        
        if let Some(ts) = until {
            repost_filter = repost_filter.until(ts);
        }
        
        // Fetch both in parallel
        let (text_result, repost_result) = tokio::join!(
            self.client.fetch_events(text_filter, DEFAULT_TIMEOUT),
            self.client.fetch_events(repost_filter, DEFAULT_TIMEOUT)
        );
        
        let mut combined = Events::default();
        
        // Add text notes
        if let Ok(events) = text_result {
            for event in events.into_iter() {
                combined.insert(event);
            }
        }
        
        // Add reposts
        if let Ok(events) = repost_result {
            for event in events.into_iter() {
                combined.insert(event);
            }
        }
        
        tracing::info!("Fetched {} total events for following feed", combined.len());
        Ok(combined)
    }
    
    /// Fetch home feed: posts from following + replies to those posts (combined view)
    pub async fn fetch_home_feed(&self, limit: u64, until: Option<Timestamp>) -> Result<Events, String> {
        if self.following.is_empty() {
            tracing::warn!("No following list, returning empty feed");
            return Ok(Events::default());
        }
        
        // Fetch posts from following
        let mut posts_filter = Filter::new()
            .kind(Kind::TextNote)
            .authors(self.following.clone())
            .limit(limit as usize);
        
        if let Some(ts) = until {
            posts_filter = posts_filter.until(ts);
        }
        
        let posts = self.client
            .fetch_events(posts_filter, DEFAULT_TIMEOUT)
            .await
            .map_err(|e| format!("Failed to fetch posts: {}", e))?;
        
        // Get recent post IDs for fetching replies
        let event_ids: Vec<EventId> = posts.iter().take(50).map(|e| e.id).collect();
        
        // Combine posts with replies if we have event IDs
        let mut combined = Events::default();
        for event in posts.iter() {
            combined.insert(event.clone());
        }
        
        if !event_ids.is_empty() {
            // Fetch replies to recent posts
            let mut reply_filter = Filter::new()
                .kind(Kind::TextNote)
                .events(event_ids)
                .limit((limit / 2) as usize);  // Get fewer replies
            
            if let Some(ts) = until {
                reply_filter = reply_filter.until(ts);
            }
            
            if let Ok(replies) = self.client.fetch_events(reply_filter, DEFAULT_TIMEOUT).await {
                for event in replies.iter() {
                    combined.insert(event.clone());
                }
            }
        }
        
        Ok(combined)
    }
    
    /// Fetch replies to posts from followed users
    pub async fn fetch_replies_feed(&self, limit: u64, until: Option<Timestamp>) -> Result<Events, String> {
        if self.following.is_empty() {
            return Ok(Events::default());
        }
        
        // First, get recent posts from following
        let posts_filter = Filter::new()
            .kind(Kind::TextNote)
            .authors(self.following.clone())
            .limit(100);
        
        let posts = self.client
            .fetch_events(posts_filter, DEFAULT_TIMEOUT)
            .await
            .map_err(|e| format!("Failed to fetch posts: {}", e))?;
        
        // Get the event IDs
        let event_ids: Vec<EventId> = posts.iter().map(|e| e.id).collect();
        
        if event_ids.is_empty() {
            return Ok(Events::default());
        }
        
        // Fetch replies to those posts
        let mut reply_filter = Filter::new()
            .kind(Kind::TextNote)
            .events(event_ids)
            .limit(limit as usize);
        
        if let Some(ts) = until {
            reply_filter = reply_filter.until(ts);
        }
        
        self.client
            .fetch_events(reply_filter, DEFAULT_TIMEOUT)
            .await
            .map_err(|e| format!("Failed to fetch replies: {}", e))
    }

    /// Fetch long-form notes (kind 30023) from followed users
    pub async fn fetch_long_form_following(&self, limit: u64, until: Option<Timestamp>) -> Result<Events, String> {
        if self.following.is_empty() {
            return Ok(Events::default());
        }
        
        let mut filter = Filter::new()
            .kind(Kind::LongFormTextNote)
            .authors(self.following.clone())
            .limit(limit as usize);
            
        if let Some(ts) = until {
            filter = filter.until(ts);
        }
        
        self.client.fetch_events(filter, DEFAULT_TIMEOUT).await.map_err(|e| e.to_string())
    }

    /// Fetch global long-form notes
    pub async fn fetch_long_form_global(&self, limit: u64, until: Option<Timestamp>) -> Result<Events, String> {
        let mut filter = Filter::new()
            .kind(Kind::LongFormTextNote)
            .limit(limit as usize);
            
        if let Some(ts) = until {
            filter = filter.until(ts);
        }
        
        self.client.fetch_events(filter, DEFAULT_TIMEOUT).await.map_err(|e| e.to_string())
    }
    
    /// Fetch global feed (all text notes)
    pub async fn fetch_global_feed(&self, limit: u64, until: Option<Timestamp>) -> Result<Events, String> {
        let mut filter = Filter::new()
            .kind(Kind::TextNote)
            .limit(limit as usize);
        
        if let Some(ts) = until {
            filter = filter.until(ts);
        }
        
        self.client
            .fetch_events(filter, DEFAULT_TIMEOUT)
            .await
            .map_err(|e| format!("Failed to fetch global feed: {}", e))
    }
    
    /// Fetch profile metadata for pubkeys
    pub async fn fetch_profiles(&self, pubkeys: &[PublicKey]) -> Result<Events, String> {
        if pubkeys.is_empty() {
            return Ok(Events::default());
        }
        
        let filter = Filter::new()
            .kind(Kind::Metadata)
            .authors(pubkeys.to_vec());
        
        self.client
            .fetch_events(filter, DEFAULT_TIMEOUT)
            .await
            .map_err(|e| format!("Failed to fetch profiles: {}", e))
    }
    
    /// Fetch a single event by ID
    pub async fn fetch_event(&self, event_id: &EventId) -> Result<Option<Event>, String> {
        let filter = Filter::new()
            .id(*event_id)
            .limit(1);
        
        let events = self.client
            .fetch_events(filter, DEFAULT_TIMEOUT)
            .await
            .map_err(|e| format!("Failed to fetch event: {}", e))?;
        
        Ok(events.into_iter().next())
    }
    
    /// Fetch thread for a note (parents + replies)
    /// Returns (parent_chain, target_note, replies)
    pub async fn fetch_thread(&self, event_id: &EventId) -> Result<(Vec<Event>, Option<Event>, Vec<Event>), String> {
        // First fetch the target event
        let target = self.fetch_event(event_id).await?;
        
        let Some(target_event) = target else {
            return Err("Event not found".to_string());
        };
        
        // Find parent event IDs from tags
        let parent_ids: Vec<EventId> = target_event.tags.iter()
            .filter_map(|tag| {
                if let Some(TagStandard::Event { event_id, .. }) = tag.as_standardized() {
                    Some(event_id.clone())
                } else {
                    None
                }
            })
            .collect();
        
        // Fetch parent events IN PARALLEL
        let parent_futures: Vec<_> = parent_ids.iter()
            .map(|parent_id| self.fetch_event(parent_id))
            .collect();
        
        // Start fetching replies in parallel with parents
        let reply_filter = Filter::new()
            .kind(Kind::TextNote)
            .event(*event_id)
            .limit(50);
        
        let replies_future = self.client.fetch_events(reply_filter, DEFAULT_TIMEOUT);
        
        // Wait for both parent fetches and replies concurrently
        let (parent_results, replies_result) = futures::future::join(
            join_all(parent_futures),
            replies_future
        ).await;
        
        // Collect successful parent events
        let mut parents: Vec<Event> = parent_results.into_iter()
            .filter_map(|r| r.ok().flatten())
            .collect();
        
        // Collect grandparent IDs from all parents
        let grandparent_ids: Vec<EventId> = parents.iter()
            .flat_map(|parent| {
                parent.tags.iter()
                    .filter_map(|tag| {
                        if let Some(TagStandard::Event { event_id, .. }) = tag.as_standardized() {
                            Some(event_id.clone())
                        } else {
                            None
                        }
                    })
            })
            .collect();
        
        // Fetch grandparents IN PARALLEL (if any)
        if !grandparent_ids.is_empty() {
            let grandparent_futures: Vec<_> = grandparent_ids.iter()
                .map(|gp_id| self.fetch_event(gp_id))
                .collect();
            
            let grandparent_results = join_all(grandparent_futures).await;
            
            for result in grandparent_results {
                if let Ok(Some(gp)) = result {
                    parents.push(gp);
                }
            }
        }
        
        // Sort parents by timestamp (oldest first for display)
        parents.sort_by(|a, b| a.created_at.cmp(&b.created_at));
        
        // Handle replies result
        let replies = replies_result
            .map_err(|e| format!("Failed to fetch replies: {}", e))?;
        
        let mut reply_vec: Vec<Event> = replies.into_iter().collect();
        reply_vec.sort_by(|a, b| a.created_at.cmp(&b.created_at));
        
        Ok((parents, Some(target_event), reply_vec))
    }
    
    /// Fetch notifications for the user (mentions, reactions, zaps, reposts)
    pub async fn fetch_notifications(&self, user_pubkey: &PublicKey, limit: u64, until: Option<Timestamp>) -> Result<Events, String> {
        // Mentions: text notes that tag this user
        let mut mention_filter = Filter::new()
            .kind(Kind::TextNote)
            .pubkey(*user_pubkey)
            .limit(limit as usize);
        
        if let Some(ts) = until {
            mention_filter = mention_filter.until(ts);
        }
        
        // Reactions: kind 7 events that tag user's notes
        let mut reaction_filter = Filter::new()
            .kind(Kind::Reaction)
            .pubkey(*user_pubkey)
            .limit(limit as usize);
        
        if let Some(ts) = until {
            reaction_filter = reaction_filter.until(ts);
        }
        
        // Zaps: kind 9735 (zap receipt) that tag this user
        let mut zap_filter = Filter::new()
            .kind(Kind::ZapReceipt)
            .pubkey(*user_pubkey)
            .limit(limit as usize);
        
        if let Some(ts) = until {
            zap_filter = zap_filter.until(ts);
        }
        
        // Reposts of user's notes: kind 6 that tags user's notes
        let mut repost_filter = Filter::new()
            .kind(Kind::Repost)
            .pubkey(*user_pubkey)
            .limit(limit as usize);
        
        if let Some(ts) = until {
            repost_filter = repost_filter.until(ts);
        }
        
        // Fetch all in parallel
        let (mentions, reactions, zaps, reposts) = tokio::join!(
            self.client.fetch_events(mention_filter, DEFAULT_TIMEOUT),
            self.client.fetch_events(reaction_filter, DEFAULT_TIMEOUT),
            self.client.fetch_events(zap_filter, DEFAULT_TIMEOUT),
            self.client.fetch_events(repost_filter, DEFAULT_TIMEOUT)
        );
        
        let mut combined = Events::default();
        
        // Filter out self-interactions and add to combined
        for events_result in [mentions, reactions, zaps, reposts] {
            if let Ok(events) = events_result {
                for event in events.into_iter() {
                    // Skip events from the user themselves
                    if event.pubkey != *user_pubkey {
                        combined.insert(event);
                    }
                }
            }
        }
        
        tracing::info!("Fetched {} notifications", combined.len());
        Ok(combined)
    }
    
    /// Fetch reactions, zaps, replies, and reposts for specific note IDs
    /// Returns a map of note_id -> (reactions_map, zap_total, zap_count, reply_count, repost_count)
    /// where reactions_map is emoji -> count
    pub async fn fetch_note_stats(&self, note_ids: &[EventId]) -> Result<std::collections::HashMap<String, (std::collections::HashMap<String, u32>, u64, u32, u32, u32)>, String> {
        if note_ids.is_empty() {
            return Ok(std::collections::HashMap::new());
        }
        
        // Fetch reactions (kind 7) for these notes
        let reaction_filter = Filter::new()
            .kind(Kind::Reaction)
            .events(note_ids.to_vec())
            .limit(500);
        
        // Fetch zap receipts (kind 9735) for these notes
        let zap_filter = Filter::new()
            .kind(Kind::ZapReceipt)
            .events(note_ids.to_vec())
            .limit(200);
        
        // Fetch replies (kind 1 that tag these notes)
        let reply_filter = Filter::new()
            .kind(Kind::TextNote)
            .events(note_ids.to_vec())
            .limit(500);
        
        // Fetch reposts (kind 6) for these notes
        let repost_filter = Filter::new()
            .kind(Kind::Repost)
            .events(note_ids.to_vec())
            .limit(200);
        
        let (reactions_result, zaps_result, replies_result, reposts_result) = tokio::join!(
            self.client.fetch_events(reaction_filter, DEFAULT_TIMEOUT),
            self.client.fetch_events(zap_filter, DEFAULT_TIMEOUT),
            self.client.fetch_events(reply_filter, DEFAULT_TIMEOUT),
            self.client.fetch_events(repost_filter, DEFAULT_TIMEOUT)
        );
        
        // stats: (reactions_map, zap_total, zap_count, reply_count, repost_count)
        let mut stats: std::collections::HashMap<String, (std::collections::HashMap<String, u32>, u64, u32, u32, u32)> = std::collections::HashMap::new();
        
        // Initialize stats for all requested note IDs
        for note_id in note_ids {
            stats.insert(note_id.to_hex(), (std::collections::HashMap::new(), 0, 0, 0, 0));
        }
        
        // Process reactions
        if let Ok(reactions) = reactions_result {
            for event in reactions.iter() {
                // Find which note this reaction is for
                for tag in event.tags.iter() {
                    if let Some(TagStandard::Event { event_id, .. }) = tag.as_standardized() {
                        let note_id_hex = event_id.to_hex();
                        if let Some((reactions_map, _, _, _, _)) = stats.get_mut(&note_id_hex) {
                            // The emoji is in the content - if empty or "+", use "❤️"
                            let emoji = if event.content.is_empty() || event.content == "+" {
                                "❤️".to_string()
                            } else if event.content == "-" {
                                "👎".to_string()
                            } else {
                                // Take first grapheme cluster (emoji) or first few chars
                                let content = event.content.trim();
                                // Get first emoji or character (handle multi-byte)
                                content.chars().take(2).collect::<String>()
                            };
                            *reactions_map.entry(emoji).or_insert(0) += 1;
                        }
                        break; // Only count once per event
                    }
                }
            }
        }
        
        // Process zaps
        if let Ok(zaps) = zaps_result {
            tracing::debug!("Processing {} zap events", zaps.len());
            for event in zaps.iter() {
                // Find which note this zap is for and extract amount
                let mut target_note: Option<String> = None;
                let mut amount_msats: u64 = 0;
                
                for tag in event.tags.iter() {
                    match tag.as_standardized() {
                        Some(TagStandard::Event { event_id, .. }) => {
                            target_note = Some(event_id.to_hex());
                        }
                        Some(TagStandard::Bolt11(invoice)) => {
                            // Try to extract amount from bolt11 invoice
                            // The amount is in the invoice string after "lnbc" or "lntb"
                            if let Some(amount) = extract_bolt11_amount(&invoice.to_string()) {
                                amount_msats = amount;
                                tracing::debug!("Extracted {} msats from bolt11", amount);
                            }
                        }
                        _ => {}
                    }
                    
                    // Also check for "amount" tag (some implementations use this)
                    if tag.kind() == TagKind::Amount {
                        if let Some(amount_str) = tag.content() {
                            if let Ok(amt) = amount_str.parse::<u64>() {
                                amount_msats = amt;
                                tracing::debug!("Found amount tag: {} msats", amt);
                            }
                        }
                    }
                }
                
                if let Some(note_id_hex) = target_note {
                    if let Some((_, zap_total, zap_count, _, _)) = stats.get_mut(&note_id_hex) {
                        let sats = amount_msats / 1000;
                        tracing::debug!("Adding {} sats to note {}", sats, &note_id_hex[..8]);
                        *zap_total += sats;
                        *zap_count += 1;
                    }
                }
            }
        }
        
        // Process replies
        if let Ok(replies) = replies_result {
            tracing::debug!("Processing {} reply events", replies.len());
            for event in replies.iter() {
                // Find which note this is a reply to
                for tag in event.tags.iter() {
                    if let Some(TagStandard::Event { event_id, marker, .. }) = tag.as_standardized() {
                        // Only count direct replies (with reply marker or root if no reply marker)
                        let is_direct_reply = match marker {
                            Some(m) => *m == Marker::Reply,
                            None => true, // Legacy format - first e tag is the reply target
                        };
                        if is_direct_reply {
                            let note_id_hex = event_id.to_hex();
                            if let Some((_, _, _, reply_count, _)) = stats.get_mut(&note_id_hex) {
                                *reply_count += 1;
                                tracing::debug!("Added reply to note {}", &note_id_hex[..8]);
                            }
                            break; // Only count once per event
                        }
                    }
                }
            }
        }
        
        // Process reposts
        if let Ok(reposts) = reposts_result {
            for event in reposts.iter() {
                // Find which note was reposted
                for tag in event.tags.iter() {
                    if let Some(TagStandard::Event { event_id, .. }) = tag.as_standardized() {
                        let note_id_hex = event_id.to_hex();
                        if let Some((_, _, _, _, repost_count)) = stats.get_mut(&note_id_hex) {
                            *repost_count += 1;
                        }
                        break; // Only count once per event
                    }
                }
            }
        }
        
        Ok(stats)
    }
    
    /// Subscribe to new events (real-time updates)
    pub async fn subscribe_feed(&self, following: &[PublicKey]) -> Result<(), String> {
        // Build filter for text notes from following
        let filter = Filter::new()
            .kind(Kind::TextNote)
            .authors(following.to_vec());
        
        self.client
            .subscribe(filter, None)
            .await
            .map_err(|e| format!("Failed to subscribe: {}", e))?;
        
        Ok(())
    }
}

/// Check if an event is a direct reply to another note
/// We want to filter out actual replies but keep:
/// - Quote posts (notes that embed/mention other notes)
/// - Root posts with no reply context
fn is_reply(event: &Event) -> bool {
    // Check for explicit reply markers (NIP-10 compliant)
    for tag in event.tags.iter() {
        if let Some(TagStandard::Event { marker, .. }) = tag.as_standardized() {
            // If it has a "reply" marker, it's definitely a reply
            if let Some(m) = marker {
                if *m == Marker::Reply || *m == Marker::Root {
                    // But check if there's actual content beyond just the reply
                    // Short content with just a reply tag = pure reply
                    // Longer content = might be a quote post
                    if event.content.len() < 50 {
                        return true;
                    }
                }
            }
        }
    }
    
    // For old-style (no marker), check if it looks like a reply context
    // Old replies typically have e tag as first tag and short content
    let e_tags: Vec<_> = event.tags.iter()
        .filter(|tag| tag.kind() == TagKind::SingleLetter(SingleLetterTag::lowercase(Alphabet::E)))
        .collect();
    
    // If there are e tags but also substantial content, treat as quote post
    if !e_tags.is_empty() {
        // Multiple e tags or short content = likely reply thread
        // Single e tag with longer content = likely quote post
        if e_tags.len() > 1 || event.content.len() < 100 {
            // Check if content starts with mentioning someone (reply pattern)
            if event.content.starts_with("@") || event.content.starts_with("nostr:npub") {
                return true;
            }
            // If first tag is an 'e' tag (reply pattern from older clients)
            if let Some(first_tag) = event.tags.first() {
                if first_tag.kind() == TagKind::SingleLetter(SingleLetterTag::lowercase(Alphabet::E)) 
                   && event.content.len() < 100 {
                    return true;
                }
            }
        }
    }
    
    false
}

/// Thread-safe relay manager handle
pub type SharedRelayManager = Arc<RwLock<Option<RelayManager>>>;

/// Create a shared relay manager instance
pub fn create_shared_relay_manager() -> SharedRelayManager {
    Arc::new(RwLock::new(None))
}

// Global relay manager - shared across all bridges
lazy_static::lazy_static! {
    /// Global relay manager instance shared by all bridges
    pub static ref GLOBAL_RELAY_MANAGER: SharedRelayManager = create_shared_relay_manager();
}

/// Extract amount in millisatoshis from a BOLT11 invoice string
fn extract_bolt11_amount(invoice: &str) -> Option<u64> {
    // BOLT11 format: ln[tb|bc][amount][multiplier][rest]
    // Amount is optional and followed by multiplier: m (milli), u (micro), n (nano), p (pico)
    let invoice_lower = invoice.to_lowercase();
    
    // Find the prefix end (lnbc or lntb)
    let start = if invoice_lower.starts_with("lnbc") {
        4
    } else if invoice_lower.starts_with("lntb") {
        4
    } else if invoice_lower.starts_with("lnbcrt") {
        6
    } else {
        return None;
    };
    
    // Extract the amount portion (digits followed by optional multiplier)
    let rest = &invoice_lower[start..];
    let mut amount_str = String::new();
    let mut multiplier: Option<char> = None;
    
    for c in rest.chars() {
        if c.is_ascii_digit() {
            amount_str.push(c);
        } else if matches!(c, 'm' | 'u' | 'n' | 'p') && !amount_str.is_empty() {
            multiplier = Some(c);
            break;
        } else {
            break;
        }
    }
    
    if amount_str.is_empty() {
        return None;
    }
    
    let base_amount: u64 = amount_str.parse().ok()?;
    
    // Convert to millisatoshis based on multiplier
    // In BOLT11: amount is in BTC, so:
    // m = milli-BTC = 100,000 sats = 100,000,000 msats
    // u = micro-BTC = 100 sats = 100,000 msats  
    // n = nano-BTC = 0.1 sats = 100 msats
    // p = pico-BTC = 0.0001 sats = 0.1 msats
    let msats = match multiplier {
        Some('m') => base_amount * 100_000_000,
        Some('u') => base_amount * 100_000,
        Some('n') => base_amount * 100,
        Some('p') => base_amount / 10,
        None => base_amount * 100_000_000_000, // No multiplier means BTC
        _ => return None, // Unknown multiplier
    };
    
    Some(msats)
}
