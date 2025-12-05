import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Rectangle {
    id: root
    color: "#0a0a0a"
    
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
                text: "Notifications"
                color: "#ffffff"
                font.pixelSize: 20
                font.weight: Font.Bold
            }
        }
        
        // Notifications list
        ListView {
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            spacing: 1
            
            model: 0 // TODO: bind to notification count
            
            delegate: Rectangle {
                width: parent.width
                height: 70
                color: "#111111"
                
                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 16
                    spacing: 12
                    
                    // Icon
                    Rectangle {
                        Layout.preferredWidth: 40
                        Layout.preferredHeight: 40
                        radius: 20
                        color: "#9333ea"
                        
                        Text {
                            anchors.centerIn: parent
                            text: "⚡"
                            font.pixelSize: 18
                        }
                    }
                    
                    // Content
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 4
                        
                        Text {
                            text: "Someone zapped your note"
                            color: "#ffffff"
                            font.pixelSize: 14
                        }
                        
                        Text {
                            text: "2 hours ago"
                            color: "#888888"
                            font.pixelSize: 12
                        }
                    }
                }
            }
            
            // Empty state
            Text {
                anchors.centerIn: parent
                text: "No notifications yet"
                color: "#666666"
                font.pixelSize: 16
                visible: parent.count === 0
            }
        }
    }
}
