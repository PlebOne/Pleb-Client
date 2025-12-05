//! PlebClient Qt - A Linux Nostr client using Qt/QML
//!
//! This uses cxx-qt to bridge Rust business logic with a Qt/QML UI.

mod bridge;
mod core;

use cxx_qt_lib::{QGuiApplication, QQmlApplicationEngine, QUrl};

fn main() {
    // Initialize logging
    tracing_subscriber::fmt()
        .with_env_filter(
            tracing_subscriber::EnvFilter::from_default_env()
                .add_directive("pleb_client_qt=info".parse().unwrap()),
        )
        .init();

    tracing::info!("Starting PlebClient Qt...");

    // Create Qt application
    let mut app = QGuiApplication::new();
    let mut engine = QQmlApplicationEngine::new();

    // Load main QML file
    if let Some(engine) = engine.as_mut() {
        engine.load(&QUrl::from("qrc:/qt/qml/com/plebclient/qml/Main.qml"));
    }

    // Run the application
    if let Some(app) = app.as_mut() {
        app.exec();
    }
}
