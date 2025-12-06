import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../components"

Rectangle {
    id: root
    color: "#0a0a0a"
    
    property var dmController: null
    property var appController: null
    
    // Initialize when visible and controllers are ready
    onVisibleChanged: {
        if (visible && dmController && appController && appController.public_key.toString() !== "") {
            console.log("[DEBUG] DmScreen visible, initializing DM controller")
            dmController.initialize(appController.public_key)
            dmController.load_conversations()
        }
    }
    
    // Connect to DM controller signals
    Connections {
        target: dmController
        ignoreUnknownSignals: true
        
        function onConversations_updated() {
            console.log("[DEBUG] Conversations updated, count:", dmController ? dmController.conversation_count : 0)
            conversationList.model = dmController ? dmController.conversation_count : 0
        }
        
        function onMessages_updated() {
            console.log("[DEBUG] Messages updated")
            if (dmController) {
                var json = dmController.get_messages()
                messageList.model = JSON.parse(json)
            }
        }
        
        function onMessage_sent(messageId) {
            console.log("[DEBUG] Message sent:", messageId)
        }
        
        function onError_occurred(error) {
            console.log("[DEBUG] DM error:", error)
        }
    }
    
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
                        
                        // Refresh button
                        Button {
                            text: "↻"
                            font.pixelSize: 18
                            
                            ToolTip.visible: hovered
                            ToolTip.text: "Refresh messages"
                            ToolTip.delay: 500
                            
                            background: Rectangle {
                                color: parent.pressed ? "#333333" : "transparent"
                                radius: 8
                            }
                            
                            contentItem: Text {
                                text: parent.text
                                color: "#888888"
                                font: parent.font
                            }
                            
                            onClicked: {
                                if (dmController) dmController.refresh()
                            }
                        }
                        
                        Button {
                            text: "+"
                            font.pixelSize: 20
                            
                            ToolTip.visible: hovered
                            ToolTip.text: "Start new conversation"
                            ToolTip.delay: 500
                            
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
                
                // Loading indicator
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 40
                    color: "#1a1a1a"
                    visible: dmController && dmController.is_loading
                    
                    RowLayout {
                        anchors.centerIn: parent
                        spacing: 8
                        
                        BusyIndicator {
                            Layout.preferredWidth: 20
                            Layout.preferredHeight: 20
                            running: parent.visible
                        }
                        
                        Text {
                            text: "Loading..."
                            color: "#888888"
                            font.pixelSize: 13
                        }
                    }
                }
                
                // Conversation list
                ListView {
                    id: conversationList
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true
                    
                    model: dmController ? dmController.conversation_count : 0
                    
                    delegate: Rectangle {
                        id: convoDelegate
                        width: conversationList.width
                        height: 70
                        color: convoData && dmController && dmController.selected_conversation.toString() === convoData.peerPubkey 
                            ? "#1a1a1a" : "transparent"
                        
                        property var convoData: null
                        
                        Component.onCompleted: {
                            if (dmController) {
                                var json = dmController.get_conversation(index)
                                try {
                                    convoData = JSON.parse(json)
                                } catch (e) {
                                    console.log("Failed to parse conversation:", e)
                                }
                            }
                        }
                        
                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
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
                                name: convoDelegate.convoData ? convoDelegate.convoData.peerName || "?" : "?"
                                imageUrl: convoDelegate.convoData ? convoDelegate.convoData.peerPicture || "" : ""
                            }
                            
                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 4
                                
                                Text {
                                    text: convoDelegate.convoData ? convoDelegate.convoData.peerName || "Unknown" : "Unknown"
                                    color: "#ffffff"
                                    font.pixelSize: 14
                                    font.weight: Font.Medium
                                    elide: Text.ElideRight
                                    Layout.fillWidth: true
                                }
                                
                                Text {
                                    text: convoDelegate.convoData ? convoDelegate.convoData.lastMessage || "" : ""
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
                                visible: convoDelegate.convoData && convoDelegate.convoData.unreadCount > 0
                                
                                Text {
                                    anchors.centerIn: parent
                                    text: convoDelegate.convoData ? convoDelegate.convoData.unreadCount : ""
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
                        text: "No conversations yet\nStart a new conversation!"
                        color: "#666666"
                        font.pixelSize: 14
                        horizontalAlignment: Text.AlignHCenter
                        visible: conversationList.count === 0 && !(dmController && dmController.is_loading)
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
                            
                            ToolTip.visible: hovered
                            ToolTip.text: "Send message (Enter)"
                            ToolTip.delay: 500
                            
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
