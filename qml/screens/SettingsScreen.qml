import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Rectangle {
    id: root
    color: "#0a0a0a"
    
    signal logout()
    signal connectNwc(string uri)
    
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
                        
                        Button {
                            text: "Connect Wallet"
                            Layout.fillWidth: true
                            Layout.preferredHeight: 44
                            
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
                            
                            onClicked: root.connectNwc(nwcInput.text.trim())
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
                            text: "Show global feed"
                            checked: true
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
        default property alias content: contentColumn.children
        
        Layout.fillWidth: true
        Layout.leftMargin: 20
        Layout.rightMargin: 20
        spacing: 12
        
        Text {
            text: title
            color: "#888888"
            font.pixelSize: 12
            font.weight: Font.Medium
            Layout.fillWidth: true
        }
        
        Rectangle {
            Layout.fillWidth: true
            color: "#111111"
            radius: 12
            implicitHeight: contentColumn.height + 32
            
            ColumnLayout {
                id: contentColumn
                anchors.fill: parent
                anchors.margins: 16
            }
        }
    }
    
    component SettingsToggle: RowLayout {
        property alias text: label.text
        property alias checked: toggle.checked
        
        Layout.fillWidth: true
        
        Text {
            id: label
            color: "#ffffff"
            font.pixelSize: 14
            Layout.fillWidth: true
        }
        
        Switch {
            id: toggle
            
            indicator: Rectangle {
                width: 44
                height: 24
                radius: 12
                color: toggle.checked ? "#9333ea" : "#333333"
                
                Rectangle {
                    x: toggle.checked ? parent.width - width - 4 : 4
                    anchors.verticalCenter: parent.verticalCenter
                    width: 16
                    height: 16
                    radius: 8
                    color: "#ffffff"
                    
                    Behavior on x {
                        NumberAnimation { duration: 100 }
                    }
                }
            }
        }
    }
}
