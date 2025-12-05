import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Rectangle {
    id: root
    color: "#0a0a0a"
    
    property string publicKey: ""
    property string displayName: ""
    
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
                text: "Profile"
                color: "#ffffff"
                font.pixelSize: 20
                font.weight: Font.Bold
            }
        }
        
        // Profile content
        ScrollView {
            Layout.fillWidth: true
            Layout.fillHeight: true
            
            ColumnLayout {
                width: parent.width
                spacing: 20
                
                // Banner placeholder with gradient-like effect using simple colors
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 200
                    gradient: Gradient {
                        GradientStop { position: 0.0; color: "#1a1a2e" }
                        GradientStop { position: 1.0; color: "#9333ea" }
                    }
                }
                
                // Profile info
                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.leftMargin: 20
                    Layout.rightMargin: 20
                    spacing: 16
                    
                    // Avatar
                    Rectangle {
                        Layout.preferredWidth: 100
                        Layout.preferredHeight: 100
                        radius: 50
                        color: "#9333ea"
                        
                        Text {
                            anchors.centerIn: parent
                            text: displayName.length > 0 ? displayName.charAt(0).toUpperCase() : "?"
                            color: "#ffffff"
                            font.pixelSize: 40
                            font.weight: Font.Bold
                        }
                    }
                    
                    // Name
                    Text {
                        text: displayName || "Anonymous"
                        color: "#ffffff"
                        font.pixelSize: 24
                        font.weight: Font.Bold
                    }
                    
                    // Public key
                    Text {
                        text: publicKey ? publicKey.substring(0, 20) + "..." : ""
                        color: "#888888"
                        font.pixelSize: 14
                        font.family: "monospace"
                    }
                    
                    // Edit button
                    Button {
                        text: "Edit Profile"
                        font.pixelSize: 14
                        
                        background: Rectangle {
                            color: parent.pressed ? "#333333" : "#1a1a1a"
                            radius: 8
                            border.color: "#333333"
                            border.width: 1
                        }
                        
                        contentItem: Text {
                            text: parent.text
                            color: "#ffffff"
                            font: parent.font
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                        }
                    }
                }
                
                // Stats
                RowLayout {
                    Layout.fillWidth: true
                    Layout.leftMargin: 20
                    Layout.rightMargin: 20
                    spacing: 40
                    
                    StatItem { label: "Notes"; value: "0" }
                    StatItem { label: "Following"; value: "0" }
                    StatItem { label: "Followers"; value: "0" }
                }
                
                // Spacer
                Item { Layout.fillHeight: true }
            }
        }
    }
    
    component StatItem: ColumnLayout {
        property string label: ""
        property string value: "0"
        
        spacing: 4
        
        Text {
            text: value
            color: "#ffffff"
            font.pixelSize: 20
            font.weight: Font.Bold
        }
        
        Text {
            text: label
            color: "#888888"
            font.pixelSize: 14
        }
    }
}
