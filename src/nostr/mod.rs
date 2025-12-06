//! Nostr module - handles relay connections, event storage, and feed management

pub mod database;
pub mod relay;
pub mod feed;
pub mod profile;
pub mod dm;
pub mod nwc;
pub mod blossom;
pub mod zap;

pub use database::NostrDatabase;
pub use relay::RelayManager;
pub use feed::{FeedType, FeedManager};
pub use profile::ProfileCache;
pub use dm::{DmManager, DmMessage, DmConversation, DmProtocol};
pub use nwc::{NwcManager, NwcConnection, NwcState, SharedNwcManager, create_nwc_manager};
pub use blossom::{upload_media, BlossomUploadResponse};
pub use zap::{zap, ZapResult, GLOBAL_NWC_MANAGER};
