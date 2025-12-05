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
    
    color: "#0a0a0a"
    
    // App controller from Rust
    AppController {
        id: appController
        
        onCurrent_screenChanged: {
            console.log("Screen changed to:", current_screen)
        }
        onLogged_inChanged: {
            console.log("Logged in changed to:", logged_in)
        }
    }
    
    // Feed controller from Rust
    FeedController {
        id: feedController
    }
    
    // DM controller from Rust
    DmController {
        id: dmController
    }
    
    // Handle window close
    onClosing: function(close) {
        close.accepted = true
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
            
            currentIndex: {
                switch (appController.current_screen) {
                    case "login": return 0
                    case "feed": return 1
                    case "notifications": return 2
                    case "messages": return 3
                    case "profile": return 4
                    case "settings": return 5
                    default: return 0
                }
            }
            
            // Login screen
            LoginScreen {
                onLoginRequested: function(nsec) {
                    console.log("Login requested with nsec")
                    appController.login_with_nsec(nsec)
                }
            }
            
            // Feed screen
            FeedScreen {
                feedController: feedController
            }
            
            // Notifications screen
            NotificationsScreen {
            }
            
            // DM screen
            DmScreen {
                dmController: dmController
            }
            
            // Profile screen
            ProfileScreen {
                publicKey: appController.public_key
                displayName: appController.display_name
            }
            
            // Settings screen
            SettingsScreen {
                onLogout: appController.logout()
                onConnectNwc: function(uri) {
                    appController.connect_nwc(uri)
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
    
    Component.onCompleted: {
        console.log("App starting, logged_in:", appController.logged_in)
        if (!appController.logged_in) {
            appController.navigate_to("login")
        } else {
            appController.navigate_to("feed")
            feedController.load_feed("following")
        }
    }
}
