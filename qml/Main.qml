import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Window
import com.plebclient 1.0
import "components"
import "screens"

ApplicationWindow {
    id: window
    visible: true
    width: 1200
    height: 800
    minimumWidth: 800
    minimumHeight: 600
    title: "Pleb Client"
    
    // Application icon (shows in taskbar)
    // Note: Window icon requires the icon to be accessible via qrc
    
    color: "#0a0a0a"
    
    // System tray settings
    property bool closeToTray: false  // Disabled by default since system tray requires QApplication
    property bool showNotificationBadge: false
    property int unreadCount: 0
    
    // Note: System tray requires QApplication (not QGuiApplication)
    // For now, we skip the system tray implementation
    // The close-to-tray feature is disabled until we switch to QApplication
    
    // Global keyboard shortcuts
    Shortcut {
        sequence: "Ctrl+1"
        onActivated: if (appController.logged_in) appController.navigate_to("feed")
    }
    Shortcut {
        sequence: "Ctrl+2"
        onActivated: if (appController.logged_in) appController.navigate_to("search")
    }
    Shortcut {
        sequence: "Ctrl+3"
        onActivated: if (appController.logged_in) appController.navigate_to("notifications")
    }
    Shortcut {
        sequence: "Ctrl+4"
        onActivated: if (appController.logged_in) appController.navigate_to("messages")
    }
    Shortcut {
        sequence: "Ctrl+5"
        onActivated: if (appController.logged_in) appController.navigate_to("profile")
    }
    Shortcut {
        sequence: "Ctrl+,"
        onActivated: if (appController.logged_in) appController.navigate_to("settings")
    }
    Shortcut {
        sequence: "?"
        onActivated: shortcutsPopup.open()
    }
    Shortcut {
        sequence: "/"
        onActivated: if (appController.logged_in) appController.navigate_to("search")
    }
    
    // Check for saved credentials on startup
    Component.onCompleted: {
        console.log("[DEBUG] Window loaded, checking for saved credentials...")
        // Try auto-login first
        appController.check_saved_credentials()
        
        // If not logged in after auto-login attempt, navigate to login
        if (!appController.logged_in) {
            appController.navigate_to("login")
        } else {
            appController.navigate_to("feed")
            // Initialize feed controller if already logged in
            if (appController.public_key.toString() !== "") {
                feedController.initialize(appController.public_key)
                feedController.load_feed("following")
                // Initialize notification controller
                notificationController.initialize(appController.public_key)
            }
        }
    }
    
    // App controller from Rust
    AppController {
        id: appController
        
        onCurrent_screenChanged: {
            console.log("[DEBUG] Screen changed to:", current_screen)
            console.log("[DEBUG] StackLayout currentIndex should be:", getScreenIndex(current_screen))
        }
        onLogged_inChanged: {
            console.log("[DEBUG] Logged in changed to:", logged_in)
        }
        
        onLogin_complete: function(success, error) {
            if (success && public_key.toString() !== "") {
                // Initialize feed and load following feed (only called once)
                console.log("[DEBUG] Initializing feed controller for:", public_key)
                feedController.initialize(public_key)
                feedController.load_feed("following")
                
                // Initialize notification controller
                console.log("[DEBUG] Initializing notification controller for:", public_key)
                notificationController.initialize(public_key)
            }
        }
    }
    
    // Helper function to map screen name to index
    function getScreenIndex(screen) {
        switch (screen) {
            case "login": return 0
            case "feed": return 1
            case "thread": return 2
            case "notifications": return 3
            case "messages": return 4
            case "profile": return 5
            case "settings": return 6
            case "search": return 7
            default: return 0
        }
    }
    
    // Track the note to show in thread view
    property string threadNoteId: ""
    
    // Track the previous screen for back navigation
    property string previousScreen: "feed"
    
    // Feed controller from Rust
    FeedController {
        id: feedController
    }
    
    // DM controller from Rust
    DmController {
        id: dmController
    }
    
    // Notification controller from Rust
    NotificationController {
        id: notificationController
    }
    
    // Search controller from Rust
    SearchController {
        id: searchController
    }

    // Handle window close
    onClosing: function(close) {
        // Close to tray is disabled since it requires QApplication
        close.accepted = true
    }
    
    // Placeholder for future tray notification support
    function showTrayNotification(title, message) {
        // System tray not available without QApplication
        console.log("Notification:", title, "-", message)
    }
    
    // Update unread count when notifications change
    Connections {
        target: notificationController
        function onUnread_countChanged() {
            window.unreadCount = notificationController.unread_count
        }
    }
    
    // Main layout
    RowLayout {
        anchors.fill: parent
        spacing: 0
        
        // Sidebar
        Sidebar {
            id: sidebar
            Layout.fillHeight: true
            Layout.preferredWidth: 240
            visible: appController.logged_in
            
            currentScreen: appController.current_screen
            displayName: appController.display_name
            profilePicture: appController.profile_picture
            walletBalance: appController.wallet_balance_sats
            
            onNavigate: function(screen) {
                appController.navigate_to(screen)
            }
        }
        
        // Separator
        Rectangle {
            Layout.fillHeight: true
            Layout.preferredWidth: 1
            color: "#2a2a2a"
            visible: appController.logged_in
        }
        
        // Main content area
        StackLayout {
            id: contentStack
            Layout.fillWidth: true
            Layout.fillHeight: true
            
            currentIndex: getScreenIndex(appController.current_screen)
            
            onCurrentIndexChanged: {
                console.log("[DEBUG] StackLayout currentIndex changed to:", currentIndex)
            }
            
            // Login screen
            LoginScreen {
                id: loginScreen
                signerAvailable: appController.signer_available
                isLoading: appController.is_loading
                errorMessage: appController.error_message
                hasSavedCredentials: appController.has_saved_credentials
                
                onLoginRequested: function(nsec) {
                    console.log("Login requested with nsec")
                    appController.login_with_nsec(nsec)
                }
                
                onSignerLoginRequested: {
                    console.log("Login requested via Pleb Signer")
                    appController.login_with_signer()
                }
                
                onCheckSignerRequested: {
                    console.log("Checking signer availability")
                    appController.check_signer()
                }
                
                onCreateAccountRequested: {
                    console.log("Create account requested")
                    appController.create_account()
                }
                
                onPasswordLoginRequested: function(password) {
                    console.log("Password login requested")
                    appController.login_with_password(password)
                }
                
                onSaveCredentialsRequested: function(nsec, password) {
                    console.log("Saving credentials with password")
                    appController.save_credentials_with_password(nsec, password)
                }
                
                // Handle account created signal
                Connections {
                    target: appController
                    function onAccount_created(nsec, npub) {
                        console.log("Account created:", npub)
                        loginScreen.generatedNsec = nsec
                        loginScreen.generatedNpub = npub
                    }
                }
            }
            
            // Feed screen
            FeedScreen {
                feedController: feedController
                appController: appController
                
                onOpenThread: function(noteId) {
                    console.log("Opening thread for:", noteId)
                    window.previousScreen = "feed"
                    window.threadNoteId = noteId
                    appController.navigate_to("thread")
                }
            }
            
            // Thread screen
            ThreadScreen {
                feedController: feedController
                noteId: window.threadNoteId
                
                onBack: {
                    appController.navigate_to(window.previousScreen)
                }
            }
            
            // Notifications screen
            NotificationsScreen {
                notificationController: notificationController
                
                onOpenNote: function(noteId) {
                    console.log("[DEBUG] Opening thread from notification:", noteId)
                    window.previousScreen = "notifications"
                    window.threadNoteId = noteId
                    appController.navigate_to("thread")
                }
            }
            
            // DM screen
            DmScreen {
                dmController: dmController
                appController: appController
            }
            
            // Profile screen
            ProfileScreen {
                publicKey: appController.public_key
                displayName: appController.display_name
                appController: appController
            }
            
            // Settings screen
            SettingsScreen {
                appController: appController
                feedController: feedController
                closeToTray: window.closeToTray
                onLogout: appController.logout()
                onConnectNwc: function(uri) {
                    appController.connect_nwc(uri)
                }
                onConnectNwcAndSave: function(uri, password) {
                    appController.connect_nwc_and_save(uri, password)
                }
                onDisconnectNwc: {
                    appController.disconnect_nwc()
                }
                onCloseToTrayToggled: function(value) {
                    window.closeToTray = value
                }
            }
            
            // Search screen
            SearchScreen {
                searchController: searchController
                
                onOpenProfile: function(pubkey) {
                    console.log("[DEBUG] Opening profile from search:", pubkey)
                    // TODO: Navigate to profile with pubkey
                }
                
                onOpenThread: function(noteId) {
                    console.log("[DEBUG] Opening thread from search:", noteId)
                    window.previousScreen = "search"
                    window.threadNoteId = noteId
                    appController.navigate_to("thread")
                }
            }
        }
    }
    
    // Global image viewer
    ImageViewer {
        id: imageViewer
    }
    
    // Keyboard shortcuts help popup
    Popup {
        id: shortcutsPopup
        modal: true
        dim: true
        anchors.centerIn: parent
        width: 400
        height: 480
        padding: 0
        
        background: Rectangle {
            color: "#1a1a1a"
            radius: 16
            border.color: "#333333"
            border.width: 1
        }
        
        contentItem: ColumnLayout {
            spacing: 0
            
            // Header
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 56
                color: "transparent"
                
                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 16
                    
                    Text {
                        text: "Keyboard Shortcuts"
                        color: "#ffffff"
                        font.pixelSize: 18
                        font.weight: Font.Bold
                    }
                    
                    Item { Layout.fillWidth: true }
                    
                    Button {
                        text: "×"
                        implicitWidth: 32
                        implicitHeight: 32
                        
                        ToolTip.visible: hovered
                        ToolTip.text: "Close (Esc)"
                        ToolTip.delay: 500
                        
                        background: Rectangle {
                            color: parent.hovered ? "#333333" : "transparent"
                            radius: 8
                        }
                        
                        contentItem: Text {
                            text: parent.text
                            color: "#888888"
                            font.pixelSize: 20
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                        }
                        
                        onClicked: shortcutsPopup.close()
                    }
                }
            }
            
            Rectangle {
                Layout.fillWidth: true
                height: 1
                color: "#333333"
            }
            
            // Shortcuts list
            ScrollView {
                Layout.fillWidth: true
                Layout.fillHeight: true
                
                ColumnLayout {
                    width: parent.width
                    spacing: 0
                    
                    ShortcutItem { key: "Ctrl+1"; desc: "Go to Feed" }
                    ShortcutItem { key: "Ctrl+2"; desc: "Go to Search" }
                    ShortcutItem { key: "Ctrl+3"; desc: "Go to Notifications" }
                    ShortcutItem { key: "Ctrl+4"; desc: "Go to Messages" }
                    ShortcutItem { key: "Ctrl+5"; desc: "Go to Profile" }
                    ShortcutItem { key: "Ctrl+,"; desc: "Open Settings" }
                    ShortcutItem { key: "/"; desc: "Quick Search" }
                    ShortcutItem { key: "?"; desc: "Show Shortcuts" }
                    
                    Rectangle { Layout.fillWidth: true; height: 1; color: "#333333" }
                    
                    Text {
                        Layout.fillWidth: true
                        Layout.margins: 16
                        text: "IN FEEDS"
                        color: "#666666"
                        font.pixelSize: 11
                        font.weight: Font.Medium
                        font.letterSpacing: 1
                    }
                    
                    ShortcutItem { key: "J / ↓"; desc: "Scroll Down" }
                    ShortcutItem { key: "K / ↑"; desc: "Scroll Up" }
                    ShortcutItem { key: "G"; desc: "Go to Top" }
                    ShortcutItem { key: "Shift+G"; desc: "Go to Bottom" }
                    ShortcutItem { key: "R"; desc: "Refresh Feed" }
                    ShortcutItem { key: "N"; desc: "Check for New Posts" }
                    ShortcutItem { key: "Space"; desc: "Page Down" }
                    
                    Rectangle { Layout.fillWidth: true; height: 1; color: "#333333" }
                    
                    Text {
                        Layout.fillWidth: true
                        Layout.margins: 16
                        text: "IN THREAD VIEW"
                        color: "#666666"
                        font.pixelSize: 11
                        font.weight: Font.Medium
                        font.letterSpacing: 1
                    }
                    
                    ShortcutItem { key: "Esc"; desc: "Go Back" }
                    
                    Item { Layout.preferredHeight: 16 }
                }
            }
        }
    }
    
    // Shortcut item component
    component ShortcutItem: Item {
        property string key: ""
        property string desc: ""
        
        Layout.fillWidth: true
        implicitHeight: 36
        
        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 16
            anchors.rightMargin: 16
            
            Text {
                text: desc
                color: "#ffffff"
                font.pixelSize: 13
                Layout.fillWidth: true
            }
            
            Rectangle {
                Layout.preferredWidth: keyText.width + 16
                Layout.preferredHeight: 24
                color: "#252525"
                radius: 4
                
                Text {
                    id: keyText
                    anchors.centerIn: parent
                    text: key
                    color: "#888888"
                    font.pixelSize: 12
                    font.family: "monospace"
                }
            }
        }
    }
    
    // Loading overlay
    Rectangle {
        anchors.fill: parent
        color: "#80000000"
        visible: appController.is_loading
        
        BusyIndicator {
            anchors.centerIn: parent
            running: parent.visible
        }
    }
}
