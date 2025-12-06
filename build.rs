use cxx_qt_build::{CxxQtBuilder, QmlModule};

fn main() {
    CxxQtBuilder::new()
        .qt_module("Network")
        .qt_module("Multimedia")
        .qt_module("Widgets")  // Required for QApplication and system tray
        .qrc("resources/resources.qrc")
        .qml_module(QmlModule {
            uri: "com.plebclient",
            rust_files: &[
                "src/bridge/app_bridge.rs",
                "src/bridge/feed_bridge.rs",
                "src/bridge/dm_bridge.rs",
                "src/bridge/notification_bridge.rs",
                "src/bridge/profile_bridge.rs",
                "src/bridge/search_bridge.rs",
            ],
            qml_files: &[
                "qml/Main.qml",
                "qml/components/Sidebar.qml",
                "qml/components/NoteCard.qml",
                "qml/components/ProfileAvatar.qml",
                "qml/components/EmbeddedNote.qml",
                "qml/components/EmbeddedProfile.qml",
                "qml/components/LinkPreview.qml",
                "qml/components/VideoPlayer.qml",
                "qml/components/ImageViewer.qml",
                "qml/components/ZapDialog.qml",
                "qml/components/ReactionPicker.qml",
                "qml/components/ComposeDialog.qml",
                "qml/screens/FeedScreen.qml",
                "qml/screens/ThreadScreen.qml",
                "qml/screens/LoginScreen.qml",
                "qml/screens/ProfileScreen.qml",
                "qml/screens/SettingsScreen.qml",
                "qml/screens/DmScreen.qml",
                "qml/screens/NotificationsScreen.qml",
                "qml/screens/SearchScreen.qml",
            ],
            ..Default::default()
        })
        .build();
}
