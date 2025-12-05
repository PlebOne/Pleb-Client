//! Error types

use thiserror::Error;

#[derive(Error, Debug)]
pub enum PlebClientError {
    #[error("Not authenticated")]
    NotAuthenticated,
    
    #[error("Invalid key: {0}")]
    InvalidKey(String),
    
    #[error("Relay error: {0}")]
    Relay(String),
    
    #[error("Nostr error: {0}")]
    Nostr(String),
    
    #[error("NWC error: {0}")]
    Nwc(String),
    
    #[error("IO error: {0}")]
    Io(#[from] std::io::Error),
    
    #[error("Serialization error: {0}")]
    Serialization(#[from] serde_json::Error),
}

pub type Result<T> = std::result::Result<T, PlebClientError>;
