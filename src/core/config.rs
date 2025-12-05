//! Configuration management

use serde::{Deserialize, Serialize};
use std::path::PathBuf;

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Config {
    pub relays: Vec<String>,
    pub public_key: Option<String>,
    pub nwc_uri: Option<String>,
    pub close_to_tray: bool,
    pub auto_load_images: bool,
    pub show_global_feed: bool,
}

impl Default for Config {
    fn default() -> Self {
        Self {
            relays: vec![
                "wss://relay.damus.io".to_string(),
                "wss://relay.primal.net".to_string(),
                "wss://nos.lol".to_string(),
            ],
            public_key: None,
            nwc_uri: None,
            close_to_tray: true,
            auto_load_images: true,
            show_global_feed: true,
        }
    }
}

impl Config {
    pub fn config_dir() -> PathBuf {
        directories::ProjectDirs::from("com", "plebclient", "PlebClient")
            .map(|dirs| dirs.config_dir().to_path_buf())
            .unwrap_or_else(|| PathBuf::from("."))
    }

    pub fn config_path() -> PathBuf {
        Self::config_dir().join("config.toml")
    }

    pub fn load() -> Self {
        let path = Self::config_path();
        if path.exists() {
            std::fs::read_to_string(&path)
                .ok()
                .and_then(|s| toml::from_str(&s).ok())
                .unwrap_or_default()
        } else {
            Self::default()
        }
    }

    pub fn save(&self) -> Result<(), std::io::Error> {
        let path = Self::config_path();
        if let Some(parent) = path.parent() {
            std::fs::create_dir_all(parent)?;
        }
        let content = toml::to_string_pretty(self).unwrap();
        std::fs::write(path, content)
    }
}
