//! App bridge - main application state exposed to QML

#[cxx_qt::bridge]
pub mod qobject {
    unsafe extern "C++" {
        include!("cxx-qt-lib/qstring.h");
        type QString = cxx_qt_lib::QString;
        
        include!("cxx-qt-lib/qurl.h");
        type QUrl = cxx_qt_lib::QUrl;
    }

    unsafe extern "RustQt" {
        #[qobject]
        #[qml_element]
        #[qproperty(QString, current_screen)]
        #[qproperty(bool, logged_in)]
        #[qproperty(QString, public_key)]
        #[qproperty(QString, display_name)]
        #[qproperty(QString, profile_picture)]
        #[qproperty(bool, is_loading)]
        #[qproperty(QString, error_message)]
        #[qproperty(bool, tray_available)]
        #[qproperty(i64, wallet_balance_sats)]
        type AppController = super::AppControllerRust;

        /// Login with nsec
        #[qinvokable]
        fn login_with_nsec(self: Pin<&mut AppController>, nsec: &QString);
        
        /// Logout
        #[qinvokable]
        fn logout(self: Pin<&mut AppController>);
        
        /// Navigate to a screen
        #[qinvokable]
        fn navigate_to(self: Pin<&mut AppController>, screen: &QString);
        
        /// Refresh the current view
        #[qinvokable]
        fn refresh(self: Pin<&mut AppController>);
        
        /// Connect NWC wallet
        #[qinvokable]
        fn connect_nwc(self: Pin<&mut AppController>, uri: &QString);
        
        /// Minimize to system tray
        #[qinvokable]
        fn minimize_to_tray(self: Pin<&mut AppController>);
    }

    // Signals are declared in the extern block
    unsafe extern "RustQt" {
        /// Emitted when login completes (success or failure)
        #[qsignal]
        fn login_complete(self: Pin<&mut AppController>, success: bool, error: &QString);
        
        /// Emitted when feed is loaded
        #[qsignal]
        fn feed_loaded(self: Pin<&mut AppController>);
        
        /// Emitted when wallet balance updates
        #[qsignal]
        fn wallet_updated(self: Pin<&mut AppController>, balance_sats: i64);
        
        /// Emitted when a notification arrives
        #[qsignal]
        fn notification_received(self: Pin<&mut AppController>, title: &QString, body: &QString);
    }
}

use std::pin::Pin;
use cxx_qt_lib::QString;

/// Rust implementation of AppController
#[derive(Default)]
pub struct AppControllerRust {
    current_screen: QString,
    logged_in: bool,
    public_key: QString,
    display_name: QString,
    profile_picture: QString,
    is_loading: bool,
    error_message: QString,
    tray_available: bool,
    wallet_balance_sats: i64,
}

impl qobject::AppController {
    /// Login with nsec
    pub fn login_with_nsec(mut self: Pin<&mut Self>, nsec: &QString) {
        let nsec_str = nsec.to_string();
        tracing::info!("Attempting login with nsec: {}...", &nsec_str[..20.min(nsec_str.len())]);
        
        self.as_mut().set_is_loading(true);
        
        // For now, just simulate successful login
        // TODO: Actually parse nsec and validate
        self.as_mut().set_logged_in(true);
        self.as_mut().set_current_screen(QString::from("feed"));
        self.as_mut().set_display_name(QString::from("Anonymous"));
        self.as_mut().set_is_loading(false);
        
        tracing::info!("Login complete, navigating to feed");
    }
    
    /// Logout
    pub fn logout(mut self: Pin<&mut Self>) {
        self.as_mut().set_logged_in(false);
        self.as_mut().set_public_key(QString::from(""));
        self.as_mut().set_current_screen(QString::from("login"));
    }
    
    /// Navigate to a screen
    pub fn navigate_to(mut self: Pin<&mut Self>, screen: &QString) {
        tracing::info!("Navigating to: {}", screen.to_string());
        self.as_mut().set_current_screen(screen.clone());
    }
    
    /// Refresh the current view
    pub fn refresh(mut self: Pin<&mut Self>) {
        self.as_mut().set_is_loading(true);
        // TODO: Trigger refresh based on current screen
    }
    
    /// Connect NWC wallet
    pub fn connect_nwc(self: Pin<&mut Self>, uri: &QString) {
        let uri_str = uri.to_string();
        tracing::info!("Connecting NWC: {}", uri_str);
        // TODO: Implement NWC connection
    }
    
    /// Minimize to system tray
    pub fn minimize_to_tray(self: Pin<&mut Self>) {
        tracing::info!("Minimize to tray requested");
    }
}
