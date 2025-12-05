import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Rectangle {
    id: root
    color: "#0a0a0a"
    
    signal loginRequested(string nsec)
    
    ColumnLayout {
        anchors.centerIn: parent
        width: 400
        spacing: 24
        
        // Logo
        Image {
            source: "qrc:/icons/icon.png"
            Layout.preferredWidth: 128
            Layout.preferredHeight: 128
            Layout.alignment: Qt.AlignHCenter
        }
        
        // Title
        Text {
            text: "Welcome to Pleb Client"
            color: "#ffffff"
            font.pixelSize: 28
            font.weight: Font.Bold
            Layout.alignment: Qt.AlignHCenter
        }
        
        Text {
            text: "A native Nostr client for Linux"
            color: "#888888"
            font.pixelSize: 16
            Layout.alignment: Qt.AlignHCenter
        }
        
        // Spacer
        Item { Layout.preferredHeight: 20 }
        
        // nsec input
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 8
            
            Text {
                text: "Enter your nsec or private key"
                color: "#888888"
                font.pixelSize: 14
            }
            
            TextField {
                id: nsecInput
                Layout.fillWidth: true
                placeholderText: "nsec1..."
                echoMode: TextInput.Password
                color: "#ffffff"
                font.pixelSize: 14
                
                background: Rectangle {
                    color: "#1a1a1a"
                    radius: 8
                    border.color: nsecInput.activeFocus ? "#9333ea" : "#333333"
                    border.width: 1
                }
                
                leftPadding: 16
                rightPadding: 16
                topPadding: 14
                bottomPadding: 14
                
                Keys.onReturnPressed: loginButton.clicked()
            }
        }
        
        // Login button
        Button {
            id: loginButton
            Layout.fillWidth: true
            Layout.preferredHeight: 50
            
            text: "Login"
            font.pixelSize: 16
            font.weight: Font.Medium
            
            background: Rectangle {
                color: loginButton.pressed ? "#7c22ce" : (loginButton.hovered ? "#a855f7" : "#9333ea")
                radius: 8
            }
            
            contentItem: Text {
                text: loginButton.text
                color: "#ffffff"
                font: loginButton.font
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
            }
            
            onClicked: {
                if (nsecInput.text.trim() !== "") {
                    root.loginRequested(nsecInput.text.trim())
                }
            }
        }
        
        // Info text
        Text {
            text: "Your key is stored locally and never sent to any server."
            color: "#666666"
            font.pixelSize: 12
            Layout.alignment: Qt.AlignHCenter
            wrapMode: Text.WordWrap
            horizontalAlignment: Text.AlignHCenter
        }
        
        // Spacer
        Item { Layout.preferredHeight: 20 }
        
        // Create account link
        Text {
            text: "Don't have a Nostr account? <a href='https://nostr.how'>Learn more</a>"
            color: "#888888"
            font.pixelSize: 14
            Layout.alignment: Qt.AlignHCenter
            textFormat: Text.StyledText
            
            onLinkActivated: function(link) {
                Qt.openUrlExternally(link)
            }
            
            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.NoButton
                cursorShape: parent.hoveredLink ? Qt.PointingHandCursor : Qt.ArrowCursor
            }
        }
    }
}
