import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Rectangle {
    id: root
    color: "#111111"
    
    property string currentScreen: "feed"
    property string displayName: ""
    property string profilePicture: ""
    property int walletBalance: 0
    
    signal navigate(string screen)
    
    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 12
        spacing: 8
        
        // Logo/title
        RowLayout {
            Layout.fillWidth: true
            spacing: 12
            
            Image {
                source: "qrc:/icons/icon.png"
                Layout.preferredWidth: 40
                Layout.preferredHeight: 40
            }
            
            Text {
                text: "Pleb Client"
                color: "#ffffff"
                font.pixelSize: 18
                font.weight: Font.Bold
            }
        }
        
        // Spacer
        Item { Layout.preferredHeight: 20 }
        
        // Navigation items
        Repeater {
            model: [
                { icon: "🏠", label: "Feed", screen: "feed" },
                { icon: "🔔", label: "Notifications", screen: "notifications" },
                { icon: "✉️", label: "Messages", screen: "messages" },
                { icon: "👤", label: "Profile", screen: "profile" },
                { icon: "⚙️", label: "Settings", screen: "settings" }
            ]
            
            delegate: Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 44
                radius: 8
                color: currentScreen === modelData.screen ? "#9333ea" : "transparent"
                
                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    
                    onClicked: root.navigate(modelData.screen)
                    
                    onEntered: {
                        if (currentScreen !== modelData.screen) {
                            parent.color = "#1a1a1a"
                        }
                    }
                    onExited: {
                        if (currentScreen !== modelData.screen) {
                            parent.color = "transparent"
                        }
                    }
                }
                
                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 12
                    anchors.rightMargin: 12
                    spacing: 12
                    
                    Text {
                        text: modelData.icon
                        font.pixelSize: 18
                    }
                    
                    Text {
                        text: modelData.label
                        color: "#ffffff"
                        font.pixelSize: 14
                        Layout.fillWidth: true
                    }
                }
            }
        }
        
        // Spacer
        Item { Layout.fillHeight: true }
        
        // Wallet balance
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 50
            radius: 8
            color: "#1a1a1a"
            visible: walletBalance > 0
            
            RowLayout {
                anchors.fill: parent
                anchors.margins: 12
                spacing: 8
                
                Text {
                    text: "⚡"
                    font.pixelSize: 20
                }
                
                Text {
                    text: walletBalance.toLocaleString() + " sats"
                    color: "#facc15"
                    font.pixelSize: 14
                    font.weight: Font.Medium
                }
            }
        }
        
        // User profile
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 60
            radius: 8
            color: "#1a1a1a"
            
            RowLayout {
                anchors.fill: parent
                anchors.margins: 8
                spacing: 10
                
                // Avatar
                Rectangle {
                    Layout.preferredWidth: 44
                    Layout.preferredHeight: 44
                    radius: 22
                    color: "#9333ea"
                    
                    Image {
                        anchors.fill: parent
                        source: profilePicture
                        visible: profilePicture !== ""
                        fillMode: Image.PreserveAspectCrop
                        layer.enabled: true
                    }
                    
                    Text {
                        anchors.centerIn: parent
                        text: displayName.charAt(0).toUpperCase()
                        color: "#ffffff"
                        font.pixelSize: 18
                        font.weight: Font.Bold
                        visible: profilePicture === ""
                    }
                }
                
                Text {
                    text: displayName || "Anonymous"
                    color: "#ffffff"
                    font.pixelSize: 14
                    Layout.fillWidth: true
                    elide: Text.ElideRight
                }
            }
        }
    }
}
