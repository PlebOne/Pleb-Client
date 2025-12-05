import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../components"

Rectangle {
    id: root
    color: "#0a0a0a"
    
    property var dmController: null
    
    RowLayout {
        anchors.fill: parent
        spacing: 0
        
        // Conversation list
        Rectangle {
            Layout.fillHeight: true
            Layout.preferredWidth: 320
            color: "#111111"
            
            ColumnLayout {
                anchors.fill: parent
                spacing: 0
                
                // Header
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 60
                    color: "#111111"
                    
                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 16
                        anchors.rightMargin: 16
                        
                        Text {
                            text: "Messages"
                            color: "#ffffff"
                            font.pixelSize: 20
                            font.weight: Font.Bold
                        }
                        
                        Item { Layout.fillWidth: true }
                        
                        Button {
                            text: "+"
                            font.pixelSize: 20
                            
                            background: Rectangle {
                                color: parent.pressed ? "#333333" : "transparent"
                                radius: 8
                            }
                            
                            contentItem: Text {
                                text: parent.text
                                color: "#9333ea"
                                font: parent.font
                            }
                            
                            onClicked: newConvoDialog.open()
                        }
                    }
                }
                
                // Conversation list
                ListView {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true
                    
                    model: dmController ? dmController.conversation_count : 0
                    
                    delegate: Rectangle {
                        width: parent.width
                        height: 70
                        color: dmController && dmController.selected_conversation === model.peerPubkey 
                            ? "#1a1a1a" : "transparent"
                        
                        property var convoData: null
                        
                        Component.onCompleted: {
                            if (dmController) {
                                var json = dmController.get_conversation(index)
                                convoData = JSON.parse(json)
                            }
                        }
                        
                        MouseArea {
                            anchors.fill: parent
                            onClicked: {
                                if (dmController && convoData) {
                                    dmController.select_conversation(convoData.peerPubkey)
                                }
                            }
                        }
                        
                        RowLayout {
                            anchors.fill: parent
                            anchors.margins: 12
                            spacing: 12
                            
                            ProfileAvatar {
                                Layout.preferredWidth: 46
                                Layout.preferredHeight: 46
                                name: convoData ? convoData.peerName || "?" : "?"
                                imageUrl: convoData ? convoData.peerPicture || "" : ""
                            }
                            
                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 4
                                
                                Text {
                                    text: convoData ? convoData.peerName || "Unknown" : "Unknown"
                                    color: "#ffffff"
                                    font.pixelSize: 14
                                    font.weight: Font.Medium
                                    elide: Text.ElideRight
                                    Layout.fillWidth: true
                                }
                                
                                Text {
                                    text: convoData ? convoData.lastMessage || "" : ""
                                    color: "#888888"
                                    font.pixelSize: 12
                                    elide: Text.ElideRight
                                    Layout.fillWidth: true
                                }
                            }
                            
                            // Unread badge
                            Rectangle {
                                Layout.preferredWidth: 20
                                Layout.preferredHeight: 20
                                radius: 10
                                color: "#9333ea"
                                visible: convoData && convoData.unreadCount > 0
                                
                                Text {
                                    anchors.centerIn: parent
                                    text: convoData ? convoData.unreadCount : ""
                                    color: "#ffffff"
                                    font.pixelSize: 10
                                    font.weight: Font.Bold
                                }
                            }
                        }
                    }
                    
                    // Empty state
                    Text {
                        anchors.centerIn: parent
                        text: "No conversations"
                        color: "#666666"
                        font.pixelSize: 14
                        visible: parent.count === 0
                    }
                }
            }
        }
        
        // Separator
        Rectangle {
            Layout.fillHeight: true
            Layout.preferredWidth: 1
            color: "#2a2a2a"
        }
        
        // Chat area
        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            color: "#0a0a0a"
            
            ColumnLayout {
                anchors.fill: parent
                spacing: 0
                visible: dmController && dmController.selected_conversation !== ""
                
                // Chat header
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 60
                    color: "#111111"
                    
                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 16
                        anchors.rightMargin: 16
                        spacing: 12
                        
                        Text {
                            text: "Chat"
                            color: "#ffffff"
                            font.pixelSize: 16
                            font.weight: Font.Medium
                        }
                        
                        Item { Layout.fillWidth: true }
                        
                        // Protocol indicator
                        Rectangle {
                            Layout.preferredHeight: 24
                            Layout.preferredWidth: protocolText.width + 16
                            radius: 12
                            color: "#1a1a1a"
                            
                            Text {
                                id: protocolText
                                anchors.centerIn: parent
                                text: dmController ? dmController.get_protocol() : "NIP-17"
                                color: "#888888"
                                font.pixelSize: 11
                            }
                            
                            MouseArea {
                                anchors.fill: parent
                                onClicked: dmController.toggle_protocol()
                            }
                        }
                    }
                }
                
                // Messages
                ListView {
                    id: messageList
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true
                    spacing: 8
                    leftMargin: 16
                    rightMargin: 16
                    topMargin: 16
                    bottomMargin: 16
                    verticalLayoutDirection: ListView.BottomToTop
                    
                    model: {
                        if (!dmController) return []
                        var json = dmController.get_messages()
                        return JSON.parse(json)
                    }
                    
                    delegate: Rectangle {
                        width: Math.min(messageList.width - 100, messageText.implicitWidth + 32)
                        height: messageText.height + 24
                        radius: 16
                        color: modelData.isOutgoing ? "#9333ea" : "#1a1a1a"
                        anchors.right: modelData.isOutgoing ? parent.right : undefined
                        anchors.left: modelData.isOutgoing ? undefined : parent.left
                        
                        Text {
                            id: messageText
                            anchors.centerIn: parent
                            width: parent.width - 32
                            text: modelData.content
                            color: "#ffffff"
                            font.pixelSize: 14
                            wrapMode: Text.WordWrap
                        }
                    }
                }
                
                // Compose
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 70
                    color: "#111111"
                    
                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: 12
                        spacing: 12
                        
                        TextField {
                            id: dmInput
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            placeholderText: "Type a message..."
                            color: "#ffffff"
                            font.pixelSize: 14
                            
                            background: Rectangle {
                                color: "#1a1a1a"
                                radius: 8
                                border.color: dmInput.activeFocus ? "#9333ea" : "#333333"
                                border.width: 1
                            }
                            
                            leftPadding: 16
                            rightPadding: 16
                            
                            Keys.onReturnPressed: sendButton.clicked()
                        }
                        
                        Button {
                            id: sendButton
                            text: "Send"
                            Layout.preferredHeight: parent.height
                            Layout.preferredWidth: 70
                            
                            background: Rectangle {
                                color: parent.enabled ? "#9333ea" : "#333333"
                                radius: 8
                            }
                            
                            contentItem: Text {
                                text: parent.text
                                color: "#ffffff"
                                font.pixelSize: 14
                                horizontalAlignment: Text.AlignHCenter
                                verticalAlignment: Text.AlignVCenter
                            }
                            
                            enabled: dmInput.text.trim() !== ""
                            
                            onClicked: {
                                if (dmController) {
                                    dmController.send_message(dmInput.text.trim())
                                    dmInput.text = ""
                                }
                            }
                        }
                    }
                }
            }
            
            // No conversation selected
            Text {
                anchors.centerIn: parent
                text: "Select a conversation"
                color: "#666666"
                font.pixelSize: 16
                visible: !dmController || dmController.selected_conversation === ""
            }
        }
    }
    
    // New conversation dialog
    Dialog {
        id: newConvoDialog
        title: "New Conversation"
        modal: true
        anchors.centerIn: parent
        width: 400
        
        background: Rectangle {
            color: "#1a1a1a"
            radius: 12
        }
        
        ColumnLayout {
            anchors.fill: parent
            spacing: 16
            
            Text {
                text: "Enter npub or public key"
                color: "#888888"
                font.pixelSize: 14
            }
            
            TextField {
                id: newPubkeyInput
                Layout.fillWidth: true
                placeholderText: "npub1..."
                color: "#ffffff"
                font.pixelSize: 14
                
                background: Rectangle {
                    color: "#0a0a0a"
                    radius: 8
                    border.color: newPubkeyInput.activeFocus ? "#9333ea" : "#333333"
                    border.width: 1
                }
                
                leftPadding: 16
                rightPadding: 16
                topPadding: 12
                bottomPadding: 12
            }
        }
        
        standardButtons: Dialog.Cancel | Dialog.Ok
        
        onAccepted: {
            if (dmController && newPubkeyInput.text.trim() !== "") {
                dmController.start_conversation(newPubkeyInput.text.trim())
                newPubkeyInput.text = ""
            }
        }
    }
}
