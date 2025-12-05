use cxx_qt_build::{CxxQtBuilder, QmlModule};

fn main() {
    CxxQtBuilder::new()
        .qt_module("Network")
        .qml_module(QmlModule {
            uri: "com.plebclient",
            rust_files: &[
                "src/bridge/app_bridge.rs",
                "src/bridge/feed_bridge.rs",
                "src/bridge/dm_bridge.rs",
            ],
            qml_files: &[
                "qml/Main.qml",
                "qml/components/Sidebar.qml",
                "qml/components/NoteCard.qml",
                "qml/components/ProfileAvatar.qml",
                "qml/screens/FeedScreen.qml",
                "qml/screens/LoginScreen.qml",
                "qml/screens/ProfileScreen.qml",
                "qml/screens/SettingsScreen.qml",
                "qml/screens/DmScreen.qml",
                "qml/screens/NotificationsScreen.qml",
            ],
            ..Default::default()
        })
        .build();
}
