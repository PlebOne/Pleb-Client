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
        type FeedController = super::FeedControllerRust;

        /// Load a feed type
        #[qinvokable]
        fn load_feed(self: Pin<&mut FeedController>, feed_type: &QString);
        
        /// Get note at index (returns JSON for simplicity)
        #[qinvokable]
        fn get_note(self: &FeedController, index: i32) -> QString;
        
        /// Like a note
        #[qinvokable]
        fn like_note(self: Pin<&mut FeedController>, note_id: &QString);
        
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
    }

    unsafe extern "RustQt" {
        #[qsignal]
        fn feed_updated(self: Pin<&mut FeedController>);
        
        #[qsignal]
        fn note_posted(self: Pin<&mut FeedController>, note_id: &QString);
        
        #[qsignal]
        fn error_occurred(self: Pin<&mut FeedController>, error: &QString);
    }
}

use std::pin::Pin;
use cxx_qt_lib::QString;
use cxx_qt::CxxQtType;

/// Note data structure (internal)
#[derive(Clone, Debug)]
pub struct NoteData {
    pub id: String,
    pub pubkey: String,
    pub author_name: String,
    pub author_picture: Option<String>,
    pub content: String,
    pub created_at: i64,
    pub likes: u32,
    pub reposts: u32,
    pub replies: u32,
    pub zap_amount: u64,
}

impl NoteData {
    /// Serialize to JSON for QML consumption
    pub fn to_json(&self) -> String {
        serde_json::json!({
            "id": self.id,
            "pubkey": self.pubkey,
            "authorName": self.author_name,
            "authorPicture": self.author_picture,
            "content": self.content,
            "createdAt": self.created_at,
            "likes": self.likes,
            "reposts": self.reposts,
            "replies": self.replies,
            "zapAmount": self.zap_amount,
        }).to_string()
    }
}

/// Rust implementation of FeedController
#[derive(Default)]
pub struct FeedControllerRust {
    note_count: i32,
    is_loading: bool,
    current_feed: QString,
    
    // Internal state
    notes: Vec<NoteData>,
}

impl qobject::FeedController {
    pub fn load_feed(self: Pin<&mut Self>, feed_type: &QString) {
        let mut rust = self.rust_mut();
        rust.current_feed = feed_type.clone();
        rust.is_loading = true;
        
        tracing::info!("Loading feed: {}", feed_type.to_string());
        
        // TODO: Actually fetch from relays
        // For now, add some placeholder data
        rust.notes = vec![
            NoteData {
                id: "note1abc".to_string(),
                pubkey: "npub1xyz".to_string(),
                author_name: "Satoshi".to_string(),
                author_picture: None,
                content: "Hello Nostr! ⚡".to_string(),
                created_at: chrono::Utc::now().timestamp(),
                likes: 21,
                reposts: 5,
                replies: 3,
                zap_amount: 21000,
            },
        ];
        rust.note_count = rust.notes.len() as i32;
        rust.is_loading = false;
    }
    
    pub fn get_note(&self, index: i32) -> QString {
        if let Some(note) = self.notes.get(index as usize) {
            QString::from(&note.to_json())
        } else {
            QString::from("{}")
        }
    }
    
    pub fn like_note(self: Pin<&mut Self>, note_id: &QString) {
        tracing::info!("Like note: {}", note_id.to_string());
        // TODO: Implement
    }
    
    pub fn repost_note(self: Pin<&mut Self>, note_id: &QString) {
        tracing::info!("Repost note: {}", note_id.to_string());
        // TODO: Implement
    }
    
    pub fn reply_to_note(self: Pin<&mut Self>, note_id: &QString, content: &QString) {
        tracing::info!("Reply to {}: {}", note_id.to_string(), content.to_string());
        // TODO: Implement
    }
    
    pub fn zap_note(self: Pin<&mut Self>, note_id: &QString, amount_sats: i64, comment: &QString) {
        tracing::info!("Zap {} with {} sats", note_id.to_string(), amount_sats);
        // TODO: Implement via NWC
    }
    
    pub fn post_note(self: Pin<&mut Self>, content: &QString) {
        tracing::info!("Post note: {}", content.to_string());
        // TODO: Implement
    }
}
