import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../components"

Rectangle {
    id: root
    color: "#0a0a0a"
    focus: true
    
    // Required properties
    property var notificationController: null
    
    // Signal to open a note/thread
    signal openNote(string noteId)
    
    // Keyboard navigation
    Keys.onPressed: function(event) {
        if (event.key === Qt.Key_J || event.key === Qt.Key_Down) {
            notificationList.flick(0, -800)
            event.accepted = true
        } else if (event.key === Qt.Key_K || event.key === Qt.Key_Up) {
            notificationList.flick(0, 800)
            event.accepted = true
        } else if (event.key === Qt.Key_R) {
            if (notificationController) notificationController.refresh()
            event.accepted = true
        }
    }
    
    // Focus when visible
    onVisibleChanged: if (visible) forceActiveFocus()
    
    // Load notifications when controller is set
    onNotificationControllerChanged: {
        if (notificationController) {
            console.log("[DEBUG] NotificationController set, connecting signals")
        }
    }
    
    // Connect to controller signals
    Connections {
        target: notificationController
        ignoreUnknownSignals: true
        
        function onNotifications_updated() {
            console.log("[DEBUG] Notifications updated, count:", notificationController ? notificationController.notification_count : 0)
            notificationList.model = notificationController ? notificationController.notification_count : 0
        }
        
        function onMore_loaded(count) {
            console.log("[DEBUG] Loaded more notifications:", count)
            notificationList.model = notificationController ? notificationController.notification_count : 0
        }
        
        function onError_occurred(error) {
            console.log("[DEBUG] Notification error:", error)
        }
    }
    
    // Helper to format timestamp
    function formatTime(timestamp) {
        var now = Date.now() / 1000
        var diff = now - timestamp
        
        if (diff < 60) return "just now"
        if (diff < 3600) return Math.floor(diff / 60) + "m ago"
        if (diff < 86400) return Math.floor(diff / 3600) + "h ago"
        if (diff < 604800) return Math.floor(diff / 86400) + "d ago"
        
        var date = new Date(timestamp * 1000)
        return date.toLocaleDateString()
    }
    
    // Get color based on notification type
    function getTypeColor(type) {
        switch (type) {
            case "reaction": return "#ff6b6b"
            case "zap": return "#f57c00"  // Darker orange for better lightning bolt visibility
            case "repost": return "#4caf50"
            case "reply": return "#2196f3"
            case "mention": return "#9c27b0"
            default: return "#9333ea"
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
                
                Text {
                    text: "Notifications"
                    color: "#ffffff"
                    font.pixelSize: 20
                    font.weight: Font.Bold
                }
                
                Item { Layout.fillWidth: true }
                
                // Refresh button
                Button {
                    text: "↻ Refresh"
                    font.pixelSize: 14
                    
                    ToolTip.visible: hovered
                    ToolTip.text: "Refresh notifications"
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
                        if (notificationController) notificationController.refresh()
                    }
                }
                
                // Mark all read button
                Button {
                    text: "✓ Mark all read"
                    font.pixelSize: 14
                    
                    ToolTip.visible: hovered
                    ToolTip.text: "Mark all notifications as read"
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
                        if (notificationController) notificationController.mark_all_read()
                    }
                }
            }
        }
        
        // Loading indicator
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 40
            color: "#1a1a1a"
            visible: notificationController && notificationController.is_loading
            
            RowLayout {
                anchors.centerIn: parent
                spacing: 8
                
                BusyIndicator {
                    Layout.preferredWidth: 24
                    Layout.preferredHeight: 24
                    running: parent.visible
                }
                
                Text {
                    text: "Loading notifications..."
                    color: "#888888"
                    font.pixelSize: 14
                }
            }
        }
        
        // Notifications list
        ListView {
            id: notificationList
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            spacing: 1
            leftMargin: 20
            rightMargin: 20
            topMargin: 10
            bottomMargin: 10
            
            // Performance
            cacheBuffer: 1500
            flickDeceleration: 3000
            maximumFlickVelocity: 8000
            boundsBehavior: Flickable.StopAtBounds
            pixelAligned: true
            reuseItems: true
            
            ScrollBar.vertical: ScrollBar {
                policy: ScrollBar.AsNeeded
                minimumSize: 0.1
            }
            
            model: notificationController ? notificationController.notification_count : 0
            
            // Load more when near bottom
            onContentYChanged: {
                if (contentY + height > contentHeight - 200) {
                    if (notificationController && !notificationController.is_loading && count > 0) {
                        notificationController.load_more()
                    }
                }
            }
            
            delegate: Rectangle {
                id: notificationItem
                width: notificationList.width - 40
                height: 80
                color: notificationData.isRead ? "#111111" : "#1a1a1a"
                radius: 8
                
                // Parse notification data
                property var notificationData: {
                    if (!notificationController) return {}
                    try {
                        return JSON.parse(notificationController.get_notification(index))
                    } catch (e) {
                        console.log("Failed to parse notification:", e)
                        return {}
                    }
                }
                
                // Hover effect
                Rectangle {
                    anchors.fill: parent
                    color: "#ffffff"
                    opacity: mouseArea.containsMouse ? 0.05 : 0
                    radius: parent.radius
                }
                
                MouseArea {
                    id: mouseArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    
                    onClicked: {
                        console.log("[DEBUG] Notification clicked:", JSON.stringify(notificationData))
                        
                        // Mark as read
                        if (notificationController && notificationData.id) {
                            notificationController.mark_as_read(notificationData.id)
                        }
                        
                        // Determine which event to open
                        var noteIdToOpen = null
                        
                        if (notificationData.type === "reaction" || notificationData.type === "zap" || notificationData.type === "repost") {
                            // For reactions/zaps/reposts, open the note that was reacted to
                            noteIdToOpen = notificationData.referencedEventId
                        } else if (notificationData.type === "reply" || notificationData.type === "mention") {
                            // For replies/mentions, open the notification event itself (the reply/mention)
                            noteIdToOpen = notificationData.id
                        }
                        
                        if (noteIdToOpen) {
                            console.log("[DEBUG] Opening note:", noteIdToOpen)
                            root.openNote(noteIdToOpen)
                        } else {
                            console.log("[DEBUG] No valid note ID to open, type:", notificationData.type, 
                                       "id:", notificationData.id, "referencedEventId:", notificationData.referencedEventId)
                        }
                    }
                }
                
                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 12
                    spacing: 12
                    
                    // Type icon
                    Rectangle {
                        Layout.preferredWidth: 44
                        Layout.preferredHeight: 44
                        radius: 22
                        color: getTypeColor(notificationData.type || "mention")
                        
                        Text {
                            anchors.centerIn: parent
                            text: notificationData.typeIcon || "@"
                            font.pixelSize: 20
                        }
                    }
                    
                    // Avatar
                    Rectangle {
                        Layout.preferredWidth: 40
                        Layout.preferredHeight: 40
                        radius: 20
                        color: "#333333"
                        clip: true
                        
                        Image {
                            anchors.fill: parent
                            source: notificationData.authorPicture || ""
                            fillMode: Image.PreserveAspectCrop
                            visible: status === Image.Ready
                            
                            // Smooth scaling
                            smooth: true
                            mipmap: true
                        }
                        
                        Text {
                            anchors.centerIn: parent
                            text: (notificationData.authorName || "?").charAt(0).toUpperCase()
                            color: "#ffffff"
                            font.pixelSize: 16
                            font.weight: Font.Bold
                            visible: !notificationData.authorPicture
                        }
                    }
                    
                    // Content
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 4
                        
                        // Author and action
                        Text {
                            Layout.fillWidth: true
                            text: notificationData.authorName || "Someone"
                            color: "#ffffff"
                            font.pixelSize: 14
                            font.weight: Font.Bold
                            elide: Text.ElideRight
                        }
                        
                        // Preview
                        Text {
                            Layout.fillWidth: true
                            text: notificationData.contentPreview || "interacted with your note"
                            color: "#aaaaaa"
                            font.pixelSize: 13
                            elide: Text.ElideRight
                            maximumLineCount: 2
                            wrapMode: Text.WordWrap
                        }
                    }
                    
                    // Time
                    Text {
                        text: formatTime(notificationData.createdAt || 0)
                        color: "#666666"
                        font.pixelSize: 12
                    }
                }
                
                // Unread indicator
                Rectangle {
                    anchors.left: parent.left
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    anchors.leftMargin: -2
                    width: 4
                    radius: 2
                    color: "#9333ea"
                    visible: !notificationData.isRead
                }
            }
            
            // Empty state
            Text {
                anchors.centerIn: parent
                text: "No notifications yet"
                color: "#666666"
                font.pixelSize: 16
                visible: parent.count === 0 && !(notificationController && notificationController.is_loading)
            }
        }
    }
}
