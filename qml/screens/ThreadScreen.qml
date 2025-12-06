import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../components"

Rectangle {
    id: root
    color: "#0a0a0a"
    focus: true
    
    property var feedController: null
    property string noteId: ""
    
    signal back()
    
    // Keyboard navigation
    Keys.onPressed: function(event) {
        if (event.key === Qt.Key_J || event.key === Qt.Key_Down) {
            threadList.flick(0, -800)
            event.accepted = true
        } else if (event.key === Qt.Key_K || event.key === Qt.Key_Up) {
            threadList.flick(0, 800)
            event.accepted = true
        } else if (event.key === Qt.Key_G && (event.modifiers & Qt.ShiftModifier)) {
            threadList.positionViewAtEnd()
            event.accepted = true
        } else if (event.key === Qt.Key_G) {
            threadList.positionViewAtBeginning()
            event.accepted = true
        } else if (event.key === Qt.Key_Space) {
            threadList.flick(0, -1500)
            event.accepted = true
        } else if (event.key === Qt.Key_PageDown) {
            threadList.flick(0, -1500)
            event.accepted = true
        } else if (event.key === Qt.Key_PageUp) {
            threadList.flick(0, 1500)
            event.accepted = true
        } else if (event.key === Qt.Key_Escape || event.key === Qt.Key_Backspace) {
            feedController.clear_thread()
            root.back()
            event.accepted = true
        }
    }
    
    // Ensure focus when visible
    onVisibleChanged: if (visible) forceActiveFocus()
    
    // Load thread when noteId changes
    onNoteIdChanged: {
        if (noteId && feedController) {
            // Reset model first to clear old delegates
            threadList.model = 0
            feedController.load_thread(noteId)
        }
    }
    
    // Reload when thread is loaded
    Connections {
        target: feedController
        ignoreUnknownSignals: true
        function onThread_loaded() {
            console.log("[ThreadScreen] Thread loaded, count:", feedController ? feedController.thread_count : 0)
            threadList.model = feedController ? feedController.thread_count : 0
        }
        function onError_occurred(error) {
            console.log("Thread error:", error)
        }
    }
    
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
                spacing: 12
                
                // Back button
                Button {
                    text: "← Back"
                    font.pixelSize: 14
                    
                    ToolTip.visible: hovered
                    ToolTip.text: "Go back to feed"
                    ToolTip.delay: 500
                    
                    background: Rectangle {
                        color: parent.pressed ? "#333333" : "#1a1a1a"
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
                        feedController.clear_thread()
                        root.back()
                    }
                }
                
                Text {
                    text: "Thread"
                    color: "#ffffff"
                    font.pixelSize: 20
                    font.weight: Font.Bold
                }
                
                Item { Layout.fillWidth: true }
                
                // Reply button in header
                Button {
                    text: "Reply"
                    font.pixelSize: 14
                    
                    ToolTip.visible: hovered
                    ToolTip.text: "Reply to this thread"
                    ToolTip.delay: 500
                    
                    background: Rectangle {
                        color: parent.pressed ? "#7c22c9" : "#9333ea"
                        radius: 8
                    }
                    
                    contentItem: Text {
                        text: parent.text
                        color: "#ffffff"
                        font.pixelSize: 14
                        font.weight: Font.Medium
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                    
                    onClicked: {
                        composeDialog.replyToId = root.noteId
                        composeDialog.replyToAuthor = ""
                        composeDialog.replyToContent = ""
                        composeDialog.open()
                    }
                }
            }
        }
        
        // Thread list
        ListView {
            id: threadList
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            spacing: 2
            leftMargin: 20
            rightMargin: 20
            topMargin: 20
            bottomMargin: 20
            
            // Performance optimizations
            cacheBuffer: 1500
            flickDeceleration: 3000
            maximumFlickVelocity: 8000
            boundsBehavior: Flickable.StopAtBounds
            pixelAligned: true
            reuseItems: false  // Disabled to ensure proper property binding evaluation
            
            ScrollBar.vertical: ScrollBar {
                policy: ScrollBar.AsNeeded
                minimumSize: 0.1
            }
            
            model: feedController ? feedController.thread_count : 0
            
            delegate: Item {
                id: delegateItem
                width: threadList.width - 40
                height: noteCard.implicitHeight + threadConnector.height
                
                // Store the note data loaded in Component.onCompleted
                property var noteData: ({})
                property bool isTarget: false
                
                Component.onCompleted: {
                    if (feedController) {
                        try {
                            var noteJson = feedController.get_thread_note(index)
                            console.log("[ThreadScreen] Loading note at index", index, ":", noteJson.substring(0, 100))
                            noteData = JSON.parse(noteJson)
                            isTarget = noteData.id === root.noteId
                        } catch (e) {
                            console.log("[ThreadScreen] Error parsing note:", e)
                            noteData = {}
                        }
                    }
                }
                
                // Thread connector line (connects notes visually)
                Rectangle {
                    id: threadConnector
                    visible: index > 0
                    width: 2
                    height: 8
                    color: "#333333"
                    anchors.horizontalCenter: parent.left
                    anchors.horizontalCenterOffset: 40
                    anchors.top: parent.top
                }
                
                NoteCard {
                    id: noteCard
                    width: parent.width
                    anchors.top: threadConnector.bottom
                    
                    // Highlight target note
                    color: delegateItem.isTarget ? "#252525" : "#1a1a1a"
                    border.color: delegateItem.isTarget ? "#9333ea" : "transparent"
                    border.width: delegateItem.isTarget ? 2 : 0
                    
                    noteId: delegateItem.noteData.id || ""
                    authorName: delegateItem.noteData.authorName || "Unknown"
                    authorPicture: delegateItem.noteData.authorPicture || ""
                    authorNip05: delegateItem.noteData.authorNip05 || ""
                    content: delegateItem.noteData.content || ""
                    createdAt: delegateItem.noteData.createdAt || 0
                    likes: delegateItem.noteData.likes || 0
                    reposts: delegateItem.noteData.reposts || 0
                    replies: delegateItem.noteData.replies || 0
                    zapAmount: delegateItem.noteData.zapAmount || 0
                    images: delegateItem.noteData.images || []
                    videos: delegateItem.noteData.videos || []
                    isReply: delegateItem.noteData.isReply || false
                    replyTo: delegateItem.noteData.replyTo || ""
                    isRepost: delegateItem.noteData.isRepost || false
                    repostAuthorName: delegateItem.noteData.repostAuthorName || ""
                    repostAuthorPicture: delegateItem.noteData.repostAuthorPicture || ""
                    
                    onLikeClicked: feedController.like_note(noteId)
                    onRepostClicked: feedController.repost_note(noteId)
                    onReplyClicked: {
                        composeDialog.replyToId = noteId
                        composeDialog.replyToAuthor = authorName || "Anonymous"
                        composeDialog.replyToContent = content.substring(0, 200) + (content.length > 200 ? "..." : "")
                        composeDialog.open()
                    }
                    onZapClicked: {
                        zapDialog.noteId = noteId
                        zapDialog.authorName = authorName
                        zapDialog.open()
                    }
                    // Clicking a note in thread view navigates to that note's thread
                    onNoteClicked: function(id) {
                        if (id !== root.noteId) {
                            root.noteId = id
                        }
                    }
                }
            }
            
            // Loading indicator
            BusyIndicator {
                anchors.centerIn: parent
                running: feedController && feedController.is_loading
                visible: running
            }
            
            // Empty state
            Column {
                anchors.centerIn: parent
                spacing: 12
                visible: !feedController || (!feedController.is_loading && feedController.thread_count === 0)
                
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "Thread not found"
                    color: "#666666"
                    font.pixelSize: 16
                }
            }
        }
    }
    
    // Compose Dialog for replies
    ComposeDialog {
        id: composeDialog
        feedController: root.feedController
        
        onPosted: {
            // Reload thread to show new reply
            feedController.load_thread(root.noteId)
        }
    }
    
    // Zap Dialog
    ZapDialog {
        id: zapDialog
        feedController: root.feedController
        nwcConnected: true  // TODO: Get from appController when available
    }
}
