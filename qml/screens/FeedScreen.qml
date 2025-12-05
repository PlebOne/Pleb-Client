import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../components"

Rectangle {
    id: root
    color: "#0a0a0a"
    
    property var feedController: null
    
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
                anchors.leftMargin: 20
                anchors.rightMargin: 20
                spacing: 16
                
                Text {
                    text: "Feed"
                    color: "#ffffff"
                    font.pixelSize: 20
                    font.weight: Font.Bold
                }
                
                Item { Layout.fillWidth: true }
                
                // Feed type tabs
                Row {
                    spacing: 8
                    
                    Repeater {
                        model: ["Following", "Global"]
                        
                        delegate: Button {
                            text: modelData
                            font.pixelSize: 14
                            
                            background: Rectangle {
                                color: feedController && feedController.current_feed === modelData.toLowerCase() 
                                    ? "#9333ea" : "#1a1a1a"
                                radius: 16
                            }
                            
                            contentItem: Text {
                                text: parent.text
                                color: "#ffffff"
                                font: parent.font
                                horizontalAlignment: Text.AlignHCenter
                                verticalAlignment: Text.AlignVCenter
                            }
                            
                            onClicked: {
                                if (feedController) {
                                    feedController.load_feed(modelData.toLowerCase())
                                }
                            }
                        }
                    }
                }
                
                // Refresh button
                Button {
                    text: "🔄"
                    font.pixelSize: 18
                    
                    background: Rectangle {
                        color: parent.pressed ? "#333333" : "#1a1a1a"
                        radius: 8
                    }
                    
                    onClicked: {
                        if (feedController) {
                            feedController.load_feed(feedController.current_feed)
                        }
                    }
                }
            }
        }
        
        // Feed list
        ListView {
            id: feedList
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            spacing: 12
            leftMargin: 20
            rightMargin: 20
            topMargin: 20
            bottomMargin: 20
            
            model: feedController ? feedController.note_count : 0
            
            delegate: NoteCard {
                width: feedList.width - 40
                height: implicitHeight
                
                Component.onCompleted: {
                    if (feedController) {
                        var noteJson = feedController.get_note(index)
                        var note = JSON.parse(noteJson)
                        noteId = note.id || ""
                        authorName = note.authorName || "Unknown"
                        authorPicture = note.authorPicture || ""
                        content = note.content || ""
                        createdAt = note.createdAt || 0
                        likes = note.likes || 0
                        reposts = note.reposts || 0
                        replies = note.replies || 0
                        zapAmount = note.zapAmount || 0
                    }
                }
                
                onLikeClicked: feedController.like_note(noteId)
                onRepostClicked: feedController.repost_note(noteId)
                onReplyClicked: console.log("Reply to", noteId)
                onZapClicked: console.log("Zap", noteId)
            }
            
            // Loading indicator
            BusyIndicator {
                anchors.centerIn: parent
                running: feedController && feedController.is_loading
                visible: running
            }
            
            // Empty state
            Text {
                anchors.centerIn: parent
                text: "No notes to show"
                color: "#666666"
                font.pixelSize: 16
                visible: !feedController || (!feedController.is_loading && feedController.note_count === 0)
            }
        }
        
        // Compose bar
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 70
            color: "#111111"
            
            RowLayout {
                anchors.fill: parent
                anchors.margins: 12
                spacing: 12
                
                TextField {
                    id: composeInput
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    placeholderText: "What's on your mind?"
                    color: "#ffffff"
                    font.pixelSize: 14
                    
                    background: Rectangle {
                        color: "#1a1a1a"
                        radius: 8
                        border.color: composeInput.activeFocus ? "#9333ea" : "#333333"
                        border.width: 1
                    }
                    
                    leftPadding: 16
                    rightPadding: 16
                }
                
                Button {
                    text: "Post"
                    Layout.preferredHeight: parent.height
                    Layout.preferredWidth: 80
                    font.pixelSize: 14
                    font.weight: Font.Medium
                    
                    background: Rectangle {
                        color: parent.enabled ? (parent.pressed ? "#7c22ce" : "#9333ea") : "#333333"
                        radius: 8
                    }
                    
                    contentItem: Text {
                        text: parent.text
                        color: "#ffffff"
                        font: parent.font
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                    
                    enabled: composeInput.text.trim() !== ""
                    
                    onClicked: {
                        if (feedController) {
                            feedController.post_note(composeInput.text.trim())
                            composeInput.text = ""
                        }
                    }
                }
            }
        }
    }
}
