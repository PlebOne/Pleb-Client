import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

// Reaction picker popup for selecting emoji reactions
Popup {
    id: root
    
    property string noteId: ""
    property var feedController: null
    property var reactions: ({})  // Current reactions on the note: {emoji: count}
    
    // Default emoji options
    property var defaultEmoji: ["❤️", "🤙", "🔥", "😂", "🚀"]
    
    // Custom emoji that user has added (persisted in settings)
    property var customEmoji: []
    
    // All available emoji (default + custom)
    property var allEmoji: defaultEmoji.concat(customEmoji)
    
    signal reactionSelected(string emoji)
    signal reactionRemoved(string emoji)
    
    width: 300
    height: contentColumn.implicitHeight + 32
    modal: true
    closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
    
    background: Rectangle {
        color: "#1a1a1a"
        radius: 12
        border.color: "#333333"
        border.width: 1
        
        // Shadow
        layer.enabled: true
        layer.effect: Item {
            Rectangle {
                anchors.fill: parent
                anchors.margins: -2
                color: "transparent"
                radius: 14
                border.color: "#000000"
                border.width: 2
                opacity: 0.3
            }
        }
    }
    
    ColumnLayout {
        id: contentColumn
        anchors.fill: parent
        anchors.margins: 16
        spacing: 12
        
        // Header
        Text {
            text: "React"
            color: "#ffffff"
            font.pixelSize: 16
            font.weight: Font.Bold
        }
        
        // Current reactions on the note
        Flow {
            Layout.fillWidth: true
            spacing: 8
            visible: Object.keys(root.reactions).length > 0
            
            Repeater {
                model: Object.keys(root.reactions)
                
                delegate: Rectangle {
                    width: reactionRow.implicitWidth + 16
                    height: 32
                    radius: 16
                    color: "#2a2a2a"
                    border.color: "#444444"
                    border.width: 1
                    
                    RowLayout {
                        id: reactionRow
                        anchors.centerIn: parent
                        spacing: 4
                        
                        Text {
                            text: modelData
                            font.pixelSize: 16
                        }
                        
                        Text {
                            text: root.reactions[modelData] || 0
                            color: "#888888"
                            font.pixelSize: 12
                            font.weight: Font.Medium
                        }
                    }
                    
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            root.reactionSelected(modelData)
                            root.close()
                        }
                    }
                }
            }
        }
        
        // Separator
        Rectangle {
            Layout.fillWidth: true
            height: 1
            color: "#333333"
            visible: Object.keys(root.reactions).length > 0
        }
        
        // Default emoji row
        Text {
            text: "Quick react"
            color: "#888888"
            font.pixelSize: 12
        }
        
        Flow {
            Layout.fillWidth: true
            spacing: 8
            
            Repeater {
                model: root.allEmoji
                
                delegate: Rectangle {
                    width: 44
                    height: 44
                    radius: 22
                    color: hovered ? "#333333" : "#2a2a2a"
                    
                    property bool hovered: false
                    
                    Text {
                        anchors.centerIn: parent
                        text: modelData
                        font.pixelSize: 24
                    }
                    
                    // Show count if this emoji has reactions
                    Rectangle {
                        anchors.right: parent.right
                        anchors.bottom: parent.bottom
                        width: 18
                        height: 18
                        radius: 9
                        color: "#9333ea"
                        visible: root.reactions[modelData] > 0
                        
                        Text {
                            anchors.centerIn: parent
                            text: root.reactions[modelData] || ""
                            color: "#ffffff"
                            font.pixelSize: 10
                            font.weight: Font.Bold
                        }
                    }
                    
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        hoverEnabled: true
                        
                        onEntered: parent.hovered = true
                        onExited: parent.hovered = false
                        
                        onClicked: {
                            root.reactionSelected(modelData)
                            root.close()
                        }
                    }
                }
            }
        }
        
        // Add custom emoji section
        Rectangle {
            Layout.fillWidth: true
            height: 1
            color: "#333333"
        }
        
        RowLayout {
            Layout.fillWidth: true
            spacing: 8
            
            TextField {
                id: customEmojiInput
                Layout.fillWidth: true
                placeholderText: "Add custom emoji..."
                placeholderTextColor: "#666666"
                color: "#ffffff"
                font.pixelSize: 14
                
                background: Rectangle {
                    color: "#2a2a2a"
                    radius: 8
                    border.color: customEmojiInput.activeFocus ? "#9333ea" : "#444444"
                    border.width: 1
                }
                
                // Only allow emoji-like content (short strings)
                maximumLength: 4
                
                onAccepted: {
                    if (text.trim().length > 0) {
                        root.reactionSelected(text.trim())
                        text = ""
                        root.close()
                    }
                }
            }
            
            Button {
                text: "➕"
                font.pixelSize: 16
                implicitWidth: 40
                implicitHeight: 36
                
                ToolTip.visible: hovered
                ToolTip.text: "Add this emoji reaction"
                ToolTip.delay: 500
                
                background: Rectangle {
                    color: parent.pressed ? "#7c22bd" : "#9333ea"
                    radius: 8
                }
                
                onClicked: {
                    if (customEmojiInput.text.trim().length > 0) {
                        root.reactionSelected(customEmojiInput.text.trim())
                        customEmojiInput.text = ""
                        root.close()
                    }
                }
            }
        }
        
        // Manage custom emoji button
        Button {
            Layout.fillWidth: true
            text: "Manage custom emoji"
            font.pixelSize: 12
            visible: root.customEmoji.length > 0
            
            ToolTip.visible: hovered
            ToolTip.text: "Edit your custom emoji list"
            ToolTip.delay: 500
            
            background: Rectangle {
                color: parent.pressed ? "#333333" : "transparent"
                radius: 6
            }
            
            contentItem: Text {
                text: parent.text
                color: "#888888"
                font.pixelSize: 12
                horizontalAlignment: Text.AlignHCenter
            }
            
            onClicked: {
                customEmojiManager.open()
            }
        }
    }
    
    // Custom emoji manager popup (nested)
    Popup {
        id: customEmojiManager
        parent: Overlay.overlay
        x: Math.round((parent.width - width) / 2)
        y: Math.round((parent.height - height) / 2)
        width: 280
        height: 300
        modal: true
        
        background: Rectangle {
            color: "#1a1a1a"
            radius: 12
            border.color: "#333333"
            border.width: 1
        }
        
        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 16
            spacing: 12
            
            Text {
                text: "Custom Emoji"
                color: "#ffffff"
                font.pixelSize: 16
                font.weight: Font.Bold
            }
            
            ListView {
                Layout.fillWidth: true
                Layout.fillHeight: true
                model: root.customEmoji
                clip: true
                spacing: 4
                
                delegate: Rectangle {
                    width: ListView.view.width
                    height: 40
                    color: "#2a2a2a"
                    radius: 8
                    
                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: 8
                        
                        Text {
                            text: modelData
                            font.pixelSize: 20
                        }
                        
                        Item { Layout.fillWidth: true }
                        
                        Button {
                            text: "✕"
                            font.pixelSize: 14
                            implicitWidth: 28
                            implicitHeight: 28
                            
                            ToolTip.visible: hovered
                            ToolTip.text: "Remove this emoji"
                            ToolTip.delay: 500
                            
                            background: Rectangle {
                                color: parent.pressed ? "#ef4444" : "#7f1d1d"
                                radius: 6
                            }
                            
                            onClicked: {
                                var newList = root.customEmoji.filter(function(e) { return e !== modelData })
                                root.customEmoji = newList
                            }
                        }
                    }
                }
                
                // Empty state
                Text {
                    anchors.centerIn: parent
                    text: "No custom emoji yet"
                    color: "#666666"
                    font.pixelSize: 14
                    visible: root.customEmoji.length === 0
                }
            }
            
            Button {
                Layout.fillWidth: true
                text: "Done"
                font.pixelSize: 14
                
                ToolTip.visible: hovered
                ToolTip.text: "Close emoji manager"
                ToolTip.delay: 500
                
                background: Rectangle {
                    color: parent.pressed ? "#7c22bd" : "#9333ea"
                    radius: 8
                }
                
                contentItem: Text {
                    text: parent.text
                    color: "#ffffff"
                    font.pixelSize: 14
                    font.weight: Font.Medium
                    horizontalAlignment: Text.AlignHCenter
                }
                
                onClicked: customEmojiManager.close()
            }
        }
    }
}
