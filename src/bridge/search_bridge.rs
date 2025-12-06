//! Search bridge - QML bridge for search functionality
//! Supports searching for notes, users, and hashtags

use cxx_qt::CxxQtType;
use cxx_qt_lib::QString;
use std::pin::Pin;

use nostr_sdk::{Filter, Kind};

use crate::nostr::relay::{SharedRelayManager, create_shared_relay_manager};

#[cxx_qt::bridge]
mod ffi {
    unsafe extern "C++" {
        include!("cxx-qt-lib/qstring.h");
        type QString = cxx_qt_lib::QString;
    }

    unsafe extern "RustQt" {
        #[qobject]
        #[qml_element]
        #[qproperty(QString, query)]
        #[qproperty(bool, is_searching)]
        #[qproperty(i32, user_count)]
        #[qproperty(i32, note_count)]
        #[qproperty(QString, search_type)]
        type SearchController = super::SearchControllerRust;

        #[qinvokable]
        fn search_users(self: Pin<&mut SearchController>, query: &QString);

        #[qinvokable]
        fn search_notes(self: Pin<&mut SearchController>, query: &QString);

        #[qinvokable]
        fn search_hashtag(self: Pin<&mut SearchController>, hashtag: &QString);

        #[qinvokable]
        fn get_user(self: &SearchController, index: i32) -> QString;

        #[qinvokable]
        fn get_note(self: &SearchController, index: i32) -> QString;

        #[qinvokable]
        fn clear_results(self: Pin<&mut SearchController>);
    }

    unsafe extern "RustQt" {
        #[qsignal]
        fn search_completed(self: Pin<&mut SearchController>);

        #[qsignal]
        fn error_occurred(self: Pin<&mut SearchController>, error: QString);
    }

    impl cxx_qt::Threading for SearchController {}
}

use cxx_qt::Threading;

// Global state
lazy_static::lazy_static! {
    static ref SEARCH_RELAY_MANAGER: SharedRelayManager = create_shared_relay_manager();
    static ref SEARCH_RUNTIME: tokio::runtime::Runtime = tokio::runtime::Runtime::new().unwrap();
}

/// Search result types
#[derive(Clone, Debug, Default)]
pub struct UserResult {
    pub pubkey: String,
    pub name: String,
    pub display_name: String,
    pub picture: String,
    pub nip05: String,
    pub about: String,
}

#[derive(Clone, Debug, Default)]
pub struct NoteResult {
    pub id: String,
    pub pubkey: String,
    pub author_name: String,
    pub author_picture: String,
    pub content: String,
    pub created_at: i64,
}

/// Rust struct for SearchController
#[derive(Default)]
pub struct SearchControllerRust {
    query: QString,
    is_searching: bool,
    user_count: i32,
    note_count: i32,
    search_type: QString,
    
    user_results: Vec<UserResult>,
    note_results: Vec<NoteResult>,
}

impl ffi::SearchController {
    pub fn search_users(mut self: Pin<&mut Self>, query: &QString) {
        let query_str = query.to_string();
        if query_str.trim().is_empty() {
            return;
        }
        
        {
            let mut rust = self.as_mut().rust_mut();
            rust.query = query.clone();
            rust.is_searching = true;
            rust.search_type = QString::from("users");
            rust.user_results.clear();
            rust.user_count = 0;
        }
        self.as_mut().set_is_searching(true);
        self.as_mut().set_user_count(0);
        self.as_mut().set_search_type(QString::from("users"));
        
        let query_lower = query_str.to_lowercase();
        let qt_thread = self.qt_thread();
        
        std::thread::spawn(move || {
            let result = SEARCH_RUNTIME.block_on(async {
                let rm = SEARCH_RELAY_MANAGER.read().unwrap();
                let Some(manager) = rm.as_ref() else {
                    return Err("Relay manager not initialized".to_string());
                };
                
                let mut results = Vec::new();
                
                // Fetch recent metadata events
                let filter = Filter::new()
                    .kind(Kind::Metadata)
                    .limit(200);
                
                if let Ok(events) = manager.client().fetch_events(filter, std::time::Duration::from_secs(10)).await {
                    for event in events {
                        if let Ok(metadata) = serde_json::from_str::<serde_json::Value>(&event.content) {
                            let name = metadata.get("name").and_then(|n| n.as_str()).unwrap_or("");
                            let display_name = metadata.get("display_name").and_then(|n| n.as_str()).unwrap_or("");
                            let nip05 = metadata.get("nip05").and_then(|n| n.as_str()).unwrap_or("");
                            
                            let name_lower = name.to_lowercase();
                            let display_lower = display_name.to_lowercase();
                            let nip05_lower = nip05.to_lowercase();
                            
                            if name_lower.contains(&query_lower) 
                                || display_lower.contains(&query_lower)
                                || nip05_lower.contains(&query_lower) 
                            {
                                results.push(UserResult {
                                    pubkey: event.pubkey.to_hex(),
                                    name: name.to_string(),
                                    display_name: display_name.to_string(),
                                    picture: metadata.get("picture").and_then(|p| p.as_str()).unwrap_or("").to_string(),
                                    nip05: nip05.to_string(),
                                    about: metadata.get("about").and_then(|a| a.as_str()).unwrap_or("").to_string(),
                                });
                            }
                        }
                    }
                }
                
                Ok(results)
            });
            
            let _ = qt_thread.queue(move |mut qobject| {
                match result {
                    Ok(results) => {
                        let count = results.len() as i32;
                        {
                            let mut rust = qobject.as_mut().rust_mut();
                            rust.user_results = results;
                            rust.user_count = count;
                            rust.is_searching = false;
                        }
                        qobject.as_mut().set_user_count(count);
                        qobject.as_mut().set_is_searching(false);
                        qobject.as_mut().search_completed();
                    }
                    Err(e) => {
                        qobject.as_mut().rust_mut().is_searching = false;
                        qobject.as_mut().set_is_searching(false);
                        qobject.as_mut().error_occurred(QString::from(&e));
                    }
                }
            });
        });
    }
    
    pub fn search_notes(mut self: Pin<&mut Self>, query: &QString) {
        let query_str = query.to_string();
        if query_str.trim().is_empty() {
            return;
        }
        
        {
            let mut rust = self.as_mut().rust_mut();
            rust.query = query.clone();
            rust.is_searching = true;
            rust.search_type = QString::from("notes");
            rust.note_results.clear();
            rust.note_count = 0;
        }
        self.as_mut().set_is_searching(true);
        self.as_mut().set_note_count(0);
        self.as_mut().set_search_type(QString::from("notes"));
        
        let query_lower = query_str.to_lowercase();
        let qt_thread = self.qt_thread();
        
        std::thread::spawn(move || {
            let result = SEARCH_RUNTIME.block_on(async {
                let rm = SEARCH_RELAY_MANAGER.read().unwrap();
                let Some(manager) = rm.as_ref() else {
                    return Err("Relay manager not initialized".to_string());
                };
                
                let mut results = Vec::new();
                
                // Fetch recent notes
                let filter = Filter::new()
                    .kind(Kind::TextNote)
                    .limit(500);
                
                if let Ok(events) = manager.client().fetch_events(filter, std::time::Duration::from_secs(15)).await {
                    for event in events {
                        let content_lower = event.content.to_lowercase();
                        
                        if content_lower.contains(&query_lower) {
                            results.push(NoteResult {
                                id: event.id.to_hex(),
                                pubkey: event.pubkey.to_hex(),
                                author_name: String::new(),
                                author_picture: String::new(),
                                content: event.content.clone(),
                                created_at: event.created_at.as_secs() as i64,
                            });
                            
                            if results.len() >= 50 {
                                break;
                            }
                        }
                    }
                }
                
                Ok(results)
            });
            
            let _ = qt_thread.queue(move |mut qobject| {
                match result {
                    Ok(results) => {
                        let count = results.len() as i32;
                        {
                            let mut rust = qobject.as_mut().rust_mut();
                            rust.note_results = results;
                            rust.note_count = count;
                            rust.is_searching = false;
                        }
                        qobject.as_mut().set_note_count(count);
                        qobject.as_mut().set_is_searching(false);
                        qobject.as_mut().search_completed();
                    }
                    Err(e) => {
                        qobject.as_mut().rust_mut().is_searching = false;
                        qobject.as_mut().set_is_searching(false);
                        qobject.as_mut().error_occurred(QString::from(&e));
                    }
                }
            });
        });
    }
    
    pub fn search_hashtag(mut self: Pin<&mut Self>, hashtag: &QString) {
        let hashtag_str = hashtag.to_string();
        let hashtag_clean = hashtag_str.trim_start_matches('#').to_lowercase();
        
        if hashtag_clean.is_empty() {
            return;
        }
        
        {
            let mut rust = self.as_mut().rust_mut();
            rust.query = QString::from(&format!("#{}", hashtag_clean));
            rust.is_searching = true;
            rust.search_type = QString::from("hashtags");
            rust.note_results.clear();
            rust.note_count = 0;
        }
        self.as_mut().set_is_searching(true);
        self.as_mut().set_note_count(0);
        self.as_mut().set_search_type(QString::from("hashtags"));
        
        let qt_thread = self.qt_thread();
        
        std::thread::spawn(move || {
            let result = SEARCH_RUNTIME.block_on(async {
                let rm = SEARCH_RELAY_MANAGER.read().unwrap();
                let Some(manager) = rm.as_ref() else {
                    return Err("Relay manager not initialized".to_string());
                };
                
                let mut results = Vec::new();
                
                // Search by hashtag tag
                let filter = Filter::new()
                    .kind(Kind::TextNote)
                    .hashtag(hashtag_clean.clone())
                    .limit(100);
                
                if let Ok(events) = manager.client().fetch_events(filter, std::time::Duration::from_secs(15)).await {
                    for event in events {
                        results.push(NoteResult {
                            id: event.id.to_hex(),
                            pubkey: event.pubkey.to_hex(),
                            author_name: String::new(),
                            author_picture: String::new(),
                            content: event.content.clone(),
                            created_at: event.created_at.as_secs() as i64,
                        });
                    }
                }
                
                Ok(results)
            });
            
            let _ = qt_thread.queue(move |mut qobject| {
                match result {
                    Ok(results) => {
                        let count = results.len() as i32;
                        {
                            let mut rust = qobject.as_mut().rust_mut();
                            rust.note_results = results;
                            rust.note_count = count;
                            rust.is_searching = false;
                        }
                        qobject.as_mut().set_note_count(count);
                        qobject.as_mut().set_is_searching(false);
                        qobject.as_mut().search_completed();
                    }
                    Err(e) => {
                        qobject.as_mut().rust_mut().is_searching = false;
                        qobject.as_mut().set_is_searching(false);
                        qobject.as_mut().error_occurred(QString::from(&e));
                    }
                }
            });
        });
    }
    
    pub fn get_user(&self, index: i32) -> QString {
        if index < 0 || index as usize >= self.user_results.len() {
            return QString::from("{}");
        }
        
        let user = &self.user_results[index as usize];
        let json = serde_json::json!({
            "pubkey": user.pubkey,
            "name": user.name,
            "displayName": user.display_name,
            "picture": user.picture,
            "nip05": user.nip05,
            "about": user.about,
        });
        
        QString::from(&json.to_string())
    }
    
    pub fn get_note(&self, index: i32) -> QString {
        if index < 0 || index as usize >= self.note_results.len() {
            return QString::from("{}");
        }
        
        let note = &self.note_results[index as usize];
        let json = serde_json::json!({
            "id": note.id,
            "pubkey": note.pubkey,
            "authorName": note.author_name,
            "authorPicture": note.author_picture,
            "content": note.content,
            "createdAt": note.created_at,
        });
        
        QString::from(&json.to_string())
    }
    
    pub fn clear_results(mut self: Pin<&mut Self>) {
        {
            let mut rust = self.as_mut().rust_mut();
            rust.user_results.clear();
            rust.note_results.clear();
            rust.user_count = 0;
            rust.note_count = 0;
            rust.query = QString::default();
        }
        self.as_mut().set_user_count(0);
        self.as_mut().set_note_count(0);
        self.as_mut().set_query(QString::default());
    }
}
