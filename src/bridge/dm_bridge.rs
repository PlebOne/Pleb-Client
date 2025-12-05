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
        type DmController = super::DmControllerRust;

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
    }
}

use std::pin::Pin;
use cxx_qt_lib::QString;
use cxx_qt::CxxQtType;

#[derive(Clone, Debug, PartialEq)]
pub enum DmProtocol {
    Nip04,
    Nip17,
}

impl Default for DmProtocol {
    fn default() -> Self {
        DmProtocol::Nip17
    }
}

#[derive(Clone, Debug)]
pub struct Conversation {
    pub peer_pubkey: String,
    pub peer_name: Option<String>,
    pub peer_picture: Option<String>,
    pub last_message: Option<String>,
    pub last_message_at: i64,
    pub unread_count: u32,
    pub protocol: DmProtocol,
}

#[derive(Clone, Debug)]
pub struct DirectMessage {
    pub id: String,
    pub sender_pubkey: String,
    pub content: String,
    pub created_at: i64,
    pub is_outgoing: bool,
}

/// Rust implementation of DmController
#[derive(Default)]
pub struct DmControllerRust {
    conversation_count: i32,
    unread_count: i32,
    is_loading: bool,
    selected_conversation: QString,
    
    // Internal state
    conversations: Vec<Conversation>,
    messages: Vec<DirectMessage>,
    current_protocol: DmProtocol,
}

impl qobject::DmController {
    pub fn load_conversations(self: Pin<&mut Self>) {
        let mut rust = self.rust_mut();
        rust.is_loading = true;
        tracing::info!("Loading DM conversations...");
        
        // TODO: Actually load from cache/relays
        rust.conversations = vec![];
        rust.conversation_count = 0;
        rust.is_loading = false;
    }
    
    pub fn get_conversation(&self, index: i32) -> QString {
        if let Some(convo) = self.conversations.get(index as usize) {
            let json = serde_json::json!({
                "peerPubkey": convo.peer_pubkey,
                "peerName": convo.peer_name,
                "peerPicture": convo.peer_picture,
                "lastMessage": convo.last_message,
                "lastMessageAt": convo.last_message_at,
                "unreadCount": convo.unread_count,
                "protocol": match convo.protocol {
                    DmProtocol::Nip04 => "NIP-04",
                    DmProtocol::Nip17 => "NIP-17",
                },
            });
            QString::from(&json.to_string())
        } else {
            QString::from("{}")
        }
    }
    
    pub fn select_conversation(self: Pin<&mut Self>, peer_pubkey: &QString) {
        let pubkey_str = peer_pubkey.to_string();
        let mut rust = self.rust_mut();
        rust.selected_conversation = peer_pubkey.clone();
        
        // Update protocol based on conversation preference
        if let Some(convo) = rust.conversations.iter().find(|c| c.peer_pubkey == pubkey_str) {
            rust.current_protocol = convo.protocol.clone();
        }
        
        // TODO: Load messages for this conversation
        rust.messages = vec![];
    }
    
    pub fn get_messages(&self) -> QString {
        let messages_json: Vec<serde_json::Value> = self.messages.iter().map(|m| {
            serde_json::json!({
                "id": m.id,
                "senderPubkey": m.sender_pubkey,
                "content": m.content,
                "createdAt": m.created_at,
                "isOutgoing": m.is_outgoing,
            })
        }).collect();
        
        QString::from(&serde_json::to_string(&messages_json).unwrap_or_default())
    }
    
    pub fn send_message(self: Pin<&mut Self>, content: &QString) {
        let content_str = content.to_string();
        tracing::info!("Sending DM: {}", content_str);
        // TODO: Create and publish DM event
    }
    
    pub fn start_conversation(self: Pin<&mut Self>, pubkey: &QString) {
        let pubkey_str = pubkey.to_string();
        tracing::info!("Starting conversation with: {}", pubkey_str);
        
        let mut rust = self.rust_mut();
        rust.selected_conversation = pubkey.clone();
        rust.messages = vec![];
    }
    
    pub fn toggle_protocol(self: Pin<&mut Self>) {
        let mut rust = self.rust_mut();
        rust.current_protocol = match rust.current_protocol {
            DmProtocol::Nip04 => DmProtocol::Nip17,
            DmProtocol::Nip17 => DmProtocol::Nip04,
        };
    }
    
    pub fn get_protocol(&self) -> QString {
        match self.current_protocol {
            DmProtocol::Nip04 => QString::from("NIP-04"),
            DmProtocol::Nip17 => QString::from("NIP-17"),
        }
    }
}
