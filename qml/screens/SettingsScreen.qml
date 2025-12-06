import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Rectangle {
    id: root
    color: "#0a0a0a"
    
    property var appController: null
    property var feedController: null
    property var relayList: []
    property string storedPassword: "" // Temporarily store password for NWC save
    property bool closeToTray: true  // Two-way binding with main window
    
    signal logout()
    signal connectNwc(string uri)
    signal connectNwcAndSave(string uri, string password)
    signal disconnectNwc()
    signal closeToTrayToggled(bool value)
    
    // Load relays from config
    function loadRelays() {
        if (appController) {
            try {
                var json = appController.get_relays()
                relayList = JSON.parse(json)
            } catch (e) {
                console.log("Failed to load relays:", e)
                relayList = []
            }
        }
    }
    
    // Load relays when component is ready or appController changes
    Component.onCompleted: loadRelays()
    onAppControllerChanged: loadRelays()
    
    ColumnLayout {
        anchors.fill: parent
        spacing: 0
        
        // Header
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 60
            color: "#111111"
            
            Text {
                anchors.centerIn: parent
                text: "Settings"
                color: "#ffffff"
                font.pixelSize: 20
                font.weight: Font.Bold
            }
        }
        
        // Settings content
        ScrollView {
            Layout.fillWidth: true
            Layout.fillHeight: true
            contentWidth: availableWidth
            
            ColumnLayout {
                width: parent.width
                spacing: 24
                
                Item { Layout.preferredHeight: 20 }
                
                // Account section
                SettingsSection {
                    title: "Account"
                    
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 12
                        
                        Button {
                            text: "Logout"
                            Layout.fillWidth: true
                            Layout.preferredHeight: 44
                            
                            ToolTip.visible: hovered
                            ToolTip.text: "Sign out of your account"
                            ToolTip.delay: 500
                            
                            background: Rectangle {
                                color: parent.pressed ? "#7f1d1d" : "#991b1b"
                                radius: 8
                            }
                            
                            contentItem: Text {
                                text: parent.text
                                color: "#ffffff"
                                font.pixelSize: 14
                                horizontalAlignment: Text.AlignHCenter
                                verticalAlignment: Text.AlignVCenter
                            }
                            
                            onClicked: root.logout()
                        }
                    }
                }
                
                // Wallet section
                SettingsSection {
                    title: "Wallet (NWC)"
                    
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 12
                        
                        // Connection status indicator
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 8
                            visible: root.appController !== null
                            
                            Rectangle {
                                width: 10
                                height: 10
                                radius: 5
                                color: root.appController && root.appController.nwc_connected ? "#22c55e" : "#ef4444"
                            }
                            
                            Text {
                                text: root.appController && root.appController.nwc_connected ? "Connected" : "Not connected"
                                color: root.appController && root.appController.nwc_connected ? "#22c55e" : "#888888"
                                font.pixelSize: 13
                            }
                            
                            Item { Layout.fillWidth: true }
                            
                            // Balance display when connected
                            Text {
                                visible: root.appController && root.appController.nwc_connected && root.appController.wallet_balance_sats > 0
                                text: "⚡ " + (root.appController ? root.appController.wallet_balance_sats.toLocaleString() : "0") + " sats"
                                color: "#facc15"
                                font.pixelSize: 13
                                font.weight: Font.Medium
                            }
                        }
                        
                        // Connect UI (hidden when connected)
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 12
                            visible: !root.appController || !root.appController.nwc_connected
                        
                            TextField {
                                id: nwcInput
                                Layout.fillWidth: true
                                placeholderText: "nostr+walletconnect://..."
                                color: "#ffffff"
                                font.pixelSize: 14
                                
                                background: Rectangle {
                                    color: "#1a1a1a"
                                    radius: 8
                                    border.color: nwcInput.activeFocus ? "#9333ea" : "#333333"
                                    border.width: 1
                                }
                                
                                leftPadding: 16
                                rightPadding: 16
                                topPadding: 12
                                bottomPadding: 12
                            }
                            
                            // Remember wallet checkbox
                            CheckBox {
                                id: saveNwcCheckbox
                                text: "Remember wallet"
                                checked: false
                                
                                indicator: Rectangle {
                                    implicitWidth: 20
                                    implicitHeight: 20
                                    x: saveNwcCheckbox.leftPadding
                                    y: (saveNwcCheckbox.height - height) / 2
                                    radius: 4
                                    color: saveNwcCheckbox.checked ? "#9333ea" : "#1a1a1a"
                                    border.color: saveNwcCheckbox.checked ? "#9333ea" : "#333333"
                                    
                                    Text {
                                        text: "✓"
                                        color: "#ffffff"
                                        font.pixelSize: 14
                                        anchors.centerIn: parent
                                        visible: saveNwcCheckbox.checked
                                    }
                                }
                                
                                contentItem: Text {
                                    text: saveNwcCheckbox.text
                                    color: "#888888"
                                    font.pixelSize: 14
                                    leftPadding: saveNwcCheckbox.indicator.width + 8
                                    verticalAlignment: Text.AlignVCenter
                                }
                            }
                            
                            // Password field for saving NWC (only if remember is checked)
                            TextField {
                                id: nwcPasswordInput
                                Layout.fillWidth: true
                                placeholderText: "Password (same as login password)"
                                echoMode: TextInput.Password
                                color: "#ffffff"
                                font.pixelSize: 14
                                visible: saveNwcCheckbox.checked
                                
                                background: Rectangle {
                                    color: "#1a1a1a"
                                    radius: 8
                                    border.color: nwcPasswordInput.activeFocus ? "#9333ea" : "#333333"
                                    border.width: 1
                                }
                                
                                leftPadding: 16
                                rightPadding: 16
                                topPadding: 12
                                bottomPadding: 12
                            }
                            
                            Button {
                                text: "Connect Wallet"
                                Layout.fillWidth: true
                                Layout.preferredHeight: 44
                                
                                ToolTip.visible: hovered
                                ToolTip.text: "Connect your Nostr Wallet Connect (NWC) for zapping"
                                ToolTip.delay: 500
                                
                                background: Rectangle {
                                    color: parent.pressed ? "#7c22ce" : "#9333ea"
                                    radius: 8
                                }
                                
                                contentItem: Text {
                                    text: parent.text
                                    color: "#ffffff"
                                    font.pixelSize: 14
                                    horizontalAlignment: Text.AlignHCenter
                                    verticalAlignment: Text.AlignVCenter
                                }
                                
                                onClicked: {
                                    if (saveNwcCheckbox.checked && nwcPasswordInput.text.trim() !== "") {
                                        root.connectNwcAndSave(nwcInput.text.trim(), nwcPasswordInput.text)
                                    } else {
                                        root.connectNwc(nwcInput.text.trim())
                                    }
                                    nwcInput.text = ""
                                    nwcPasswordInput.text = ""
                                }
                            }
                        }
                        
                        // Disconnect button (shown when connected)
                        Button {
                            text: "Disconnect Wallet"
                            Layout.fillWidth: true
                            Layout.preferredHeight: 44
                            visible: root.appController && root.appController.nwc_connected
                            
                            ToolTip.visible: hovered
                            ToolTip.text: "Disconnect your wallet"
                            ToolTip.delay: 500
                            
                            background: Rectangle {
                                color: parent.pressed ? "#b91c1c" : "#dc2626"
                                radius: 8
                            }
                            
                            contentItem: Text {
                                text: parent.text
                                color: "#ffffff"
                                font.pixelSize: 14
                                horizontalAlignment: Text.AlignHCenter
                                verticalAlignment: Text.AlignVCenter
                            }
                            
                            onClicked: root.disconnectNwc()
                        }
                    }
                }
                
                // Appearance section
                SettingsSection {
                    title: "Appearance"
                    
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 12
                        
                        SettingsToggle {
                            text: "Auto-load images"
                            checked: true
                        }
                        
                        SettingsToggle {
                            id: showGlobalFeedToggle
                            text: "Show global feed"
                            property bool initialized: false
                            checked: root.appController ? root.appController.show_global_feed : true
                            Component.onCompleted: initialized = true
                            onCheckedChanged: {
                                // Only save when user changes the toggle, not on initialization
                                if (initialized && root.appController) {
                                    root.appController.set_show_global_feed_setting(checked)
                                }
                            }
                        }
                    }
                }
                
                // System Tray section - Currently disabled (requires QApplication)
                // TODO: Enable this when migrating to QApplication for system tray support
                /*
                SettingsSection {
                    title: "System Tray"
                    
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 12
                        
                        SettingsToggle {
                            id: closeToTrayToggle
                            text: "Close to tray instead of quit"
                            checked: root.closeToTray
                            onCheckedChanged: {
                                root.closeToTrayToggled(checked)
                            }
                        }
                        
                        Text {
                            text: "When enabled, closing the window minimizes to tray. Click the tray icon to restore."
                            color: "#888888"
                            font.pixelSize: 12
                            wrapMode: Text.WordWrap
                            Layout.fillWidth: true
                        }
                    }
                }
                */
                
                // Media Upload section
                SettingsSection {
                    title: "Media Upload"
                    
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 12
                        
                        Text {
                            text: "Blossom Server"
                            color: "#888888"
                            font.pixelSize: 12
                        }
                        
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 8
                            
                            TextField {
                                id: blossomServerInput
                                Layout.fillWidth: true
                                placeholderText: "https://blossom.band"
                                text: root.feedController ? root.feedController.get_blossom_server() : "https://blossom.band"
                                color: "#ffffff"
                                font.pixelSize: 14
                                
                                background: Rectangle {
                                    color: "#0a0a0a"
                                    radius: 8
                                    border.color: blossomServerInput.activeFocus ? "#9333ea" : "#333333"
                                    border.width: 1
                                }
                                
                                leftPadding: 12
                                rightPadding: 12
                                topPadding: 10
                                bottomPadding: 10
                            }
                            
                            Button {
                                text: "Save"
                                implicitWidth: 70
                                implicitHeight: 40
                                
                                ToolTip.visible: hovered
                                ToolTip.text: "Save media server URL"
                                ToolTip.delay: 500
                                
                                background: Rectangle {
                                    color: parent.pressed ? "#7c22ce" : "#9333ea"
                                    radius: 8
                                }
                                
                                contentItem: Text {
                                    text: parent.text
                                    color: "#ffffff"
                                    font.pixelSize: 14
                                    horizontalAlignment: Text.AlignHCenter
                                    verticalAlignment: Text.AlignVCenter
                                }
                                
                                onClicked: {
                                    if (root.feedController) {
                                        root.feedController.set_blossom_server(blossomServerInput.text.trim())
                                    }
                                }
                            }
                        }
                        
                        Text {
                            text: "Default: https://blossom.band"
                            color: "#666666"
                            font.pixelSize: 11
                        }
                        
                        Button {
                            text: "Reset to Default"
                            Layout.fillWidth: true
                            Layout.preferredHeight: 36
                            
                            ToolTip.visible: hovered
                            ToolTip.text: "Reset to default Blossom server"
                            ToolTip.delay: 500
                            
                            background: Rectangle {
                                color: parent.pressed ? "#333333" : "#252525"
                                radius: 8
                                border.color: "#404040"
                                border.width: 1
                            }
                            
                            contentItem: Text {
                                text: parent.text
                                color: "#888888"
                                font.pixelSize: 12
                                horizontalAlignment: Text.AlignHCenter
                                verticalAlignment: Text.AlignVCenter
                            }
                            
                            onClicked: {
                                blossomServerInput.text = "https://blossom.band"
                                if (root.feedController) {
                                    root.feedController.set_blossom_server("https://blossom.band")
                                }
                            }
                        }
                    }
                }
                
                // Relays section
                SettingsSection {
                    title: "Relays"
                    
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 12
                        
                        // Relay list
                        Repeater {
                            id: relayRepeater
                            model: root.relayList
                            
                            delegate: Rectangle {
                                Layout.fillWidth: true
                                height: 44
                                color: "#1a1a1a"
                                radius: 8
                                
                                RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: 12
                                    anchors.rightMargin: 8
                                    spacing: 8
                                    
                                    // Status indicator
                                    Rectangle {
                                        width: 8
                                        height: 8
                                        radius: 4
                                        color: "#22c55e"  // Green for connected
                                    }
                                    
                                    Text {
                                        Layout.fillWidth: true
                                        text: modelData.replace("wss://", "")
                                        color: "#ffffff"
                                        font.pixelSize: 13
                                        elide: Text.ElideRight
                                    }
                                    
                                    Button {
                                        implicitWidth: 32
                                        implicitHeight: 32
                                        text: "✕"
                                        
                                        background: Rectangle {
                                            color: parent.pressed ? "#7f1d1d" : (parent.hovered ? "#991b1b" : "transparent")
                                            radius: 6
                                        }
                                        
                                        contentItem: Text {
                                            text: parent.text
                                            color: parent.hovered ? "#ffffff" : "#666666"
                                            font.pixelSize: 14
                                            horizontalAlignment: Text.AlignHCenter
                                            verticalAlignment: Text.AlignVCenter
                                        }
                                        
                                        onClicked: {
                                            if (root.appController) {
                                                root.appController.remove_relay(modelData)
                                                root.loadRelays()
                                            }
                                        }
                                    }
                                }
                            }
                        }
                        
                        // Empty state
                        Text {
                            visible: root.relayList.length === 0
                            text: "No relays configured"
                            color: "#666666"
                            font.pixelSize: 14
                            Layout.alignment: Qt.AlignHCenter
                            Layout.topMargin: 8
                            Layout.bottomMargin: 8
                        }
                        
                        // Add relay input
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 8
                            
                            TextField {
                                id: newRelayInput
                                Layout.fillWidth: true
                                placeholderText: "wss://relay.example.com"
                                color: "#ffffff"
                                font.pixelSize: 14
                                
                                background: Rectangle {
                                    color: "#0a0a0a"
                                    radius: 8
                                    border.color: newRelayInput.activeFocus ? "#9333ea" : "#333333"
                                    border.width: 1
                                }
                                
                                leftPadding: 12
                                rightPadding: 12
                                topPadding: 10
                                bottomPadding: 10
                                
                                onAccepted: addRelayBtn.clicked()
                            }
                            
                            Button {
                                id: addRelayBtn
                                text: "Add"
                                implicitWidth: 70
                                implicitHeight: 40
                                
                                ToolTip.visible: hovered
                                ToolTip.text: "Add relay to your list"
                                ToolTip.delay: 500
                                
                                background: Rectangle {
                                    color: parent.enabled ? (parent.pressed ? "#7c22ce" : "#9333ea") : "#333333"
                                    radius: 8
                                }
                                
                                contentItem: Text {
                                    text: parent.text
                                    color: "#ffffff"
                                    font.pixelSize: 14
                                    horizontalAlignment: Text.AlignHCenter
                                    verticalAlignment: Text.AlignVCenter
                                }
                                
                                enabled: newRelayInput.text.trim() !== ""
                                
                                onClicked: {
                                    if (root.appController) {
                                        var url = newRelayInput.text.trim()
                                        // Auto-add wss:// if missing
                                        if (!url.startsWith("wss://") && !url.startsWith("ws://")) {
                                            url = "wss://" + url
                                        }
                                        if (root.appController.add_relay(url)) {
                                            newRelayInput.text = ""
                                            root.loadRelays()
                                        }
                                    }
                                }
                            }
                        }
                        
                        // Reset to defaults button
                        Button {
                            text: "Reset to Defaults"
                            Layout.fillWidth: true
                            Layout.preferredHeight: 40
                            Layout.topMargin: 8
                            
                            ToolTip.visible: hovered
                            ToolTip.text: "Reset to default relay list"
                            ToolTip.delay: 500
                            
                            background: Rectangle {
                                color: parent.pressed ? "#333333" : "#252525"
                                radius: 8
                                border.color: "#404040"
                                border.width: 1
                            }
                            
                            contentItem: Text {
                                text: parent.text
                                color: "#888888"
                                font.pixelSize: 13
                                horizontalAlignment: Text.AlignHCenter
                                verticalAlignment: Text.AlignVCenter
                            }
                            
                            onClicked: {
                                if (root.appController) {
                                    root.appController.reset_relays_to_default()
                                    root.loadRelays()
                                }
                            }
                        }
                    }
                }
                
                // System section
                SettingsSection {
                    title: "System"
                    
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 12
                        
                        SettingsToggle {
                            text: "Close to system tray"
                            checked: true
                        }
                        
                        SettingsToggle {
                            text: "Start minimized"
                            checked: false
                        }
                    }
                }
                
                // About section
                SettingsSection {
                    title: "About"
                    
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 8
                        
                        Text {
                            text: "Pleb Client Qt"
                            color: "#ffffff"
                            font.pixelSize: 16
                            font.weight: Font.Medium
                        }
                        
                        Text {
                            text: "Version 0.1.0"
                            color: "#888888"
                            font.pixelSize: 14
                        }
                        
                        Text {
                            text: "A native Nostr client for Linux"
                            color: "#666666"
                            font.pixelSize: 14
                        }
                    }
                }
                
                Item { Layout.preferredHeight: 40 }
            }
        }
    }
    
    component SettingsSection: ColumnLayout {
        property string title: ""
        default property alias content: contentColumn.data
        
        Layout.fillWidth: true
        Layout.leftMargin: 20
        Layout.rightMargin: 20
        spacing: 12
        
        Text {
            text: title.toUpperCase()
            color: "#888888"
            font.pixelSize: 12
            font.weight: Font.Medium
            font.letterSpacing: 1
            Layout.fillWidth: true
        }
        
        Rectangle {
            Layout.fillWidth: true
            color: "#111111"
            radius: 12
            implicitHeight: contentColumn.implicitHeight + 32
            
            ColumnLayout {
                id: contentColumn
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: 16
                spacing: 16
            }
        }
    }
    
    component SettingsToggle: Item {
        property alias text: label.text
        property alias checked: toggle.checked
        
        Layout.fillWidth: true
        implicitHeight: 32
        
        Text {
            id: label
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            anchors.right: toggleContainer.left
            anchors.rightMargin: 16
            color: "#ffffff"
            font.pixelSize: 14
        }
        
        Item {
            id: toggleContainer
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            width: 48
            height: 28
            
            Rectangle {
                anchors.fill: parent
                radius: 14
                color: toggle.checked ? "#9333ea" : "#333333"
                
                Behavior on color {
                    ColorAnimation { duration: 150 }
                }
                
                Rectangle {
                    x: toggle.checked ? parent.width - width - 4 : 4
                    anchors.verticalCenter: parent.verticalCenter
                    width: 20
                    height: 20
                    radius: 10
                    color: "#ffffff"
                    
                    Behavior on x {
                        NumberAnimation { duration: 150; easing.type: Easing.InOutQuad }
                    }
                }
                
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: toggle.checked = !toggle.checked
                }
            }
            
            Switch {
                id: toggle
                visible: false
            }
        }
    }
}
