import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../components"

Rectangle {
    id: root
    color: "#0a0a0a"
    focus: true
    
    property var feedController: null
    property var appController: null
    
    // Signal to request thread view navigation
    signal openThread(string noteId)
    
    // Keyboard navigation
    Keys.onPressed: function(event) {
        if (event.key === Qt.Key_J || event.key === Qt.Key_Down) {
            // Scroll down
            feedList.flick(0, -800)
            event.accepted = true
        } else if (event.key === Qt.Key_K || event.key === Qt.Key_Up) {
            // Scroll up
            feedList.flick(0, 800)
            event.accepted = true
        } else if (event.key === Qt.Key_G && (event.modifiers & Qt.ShiftModifier)) {
            // Go to bottom (Shift+G)
            feedList.positionViewAtEnd()
            event.accepted = true
        } else if (event.key === Qt.Key_G) {
            // Go to top
            feedList.positionViewAtBeginning()
            event.accepted = true
        } else if (event.key === Qt.Key_R) {
            // Refresh
            if (feedController) feedController.refresh()
            event.accepted = true
        } else if (event.key === Qt.Key_N) {
            // Check for new
            if (feedController) feedController.check_for_new()
            event.accepted = true
        } else if (event.key === Qt.Key_Question) {
            // Toggle keyboard shortcuts help
            if (shortcutPopup.visible) {
                shortcutPopup.close()
            } else {
                shortcutPopup.open()
            }
            event.accepted = true
        } else if (event.key === Qt.Key_Space) {
            // Page down
            feedList.flick(0, -1500)
            event.accepted = true
        } else if (event.key === Qt.Key_Home) {
            feedList.positionViewAtBeginning()
            event.accepted = true
        } else if (event.key === Qt.Key_End) {
            feedList.positionViewAtEnd()
            event.accepted = true
        } else if (event.key === Qt.Key_PageDown) {
            feedList.flick(0, -1500)
            event.accepted = true
        } else if (event.key === Qt.Key_PageUp) {
            feedList.flick(0, 1500)
            event.accepted = true
        } else if (event.key === Qt.Key_1) {
            // Switch to Following feed
            if (feedController) feedController.load_feed("following")
            event.accepted = true
        } else if (event.key === Qt.Key_2) {
            // Switch to Replies feed
            if (feedController) feedController.load_feed("replies")
            event.accepted = true
        } else if (event.key === Qt.Key_3 && appController && appController.show_global_feed) {
            // Switch to Global feed (if enabled)
            if (feedController) feedController.load_feed("global")
            event.accepted = true
        }
    }
    
    // Ensure focus when visible
    onVisibleChanged: if (visible) forceActiveFocus()
    
    // Feed types - dynamically computed based on settings
    property var feedTypes: {
        var types = ["Following", "Replies"]  // Following = posts only, Replies = combined
        if (appController && appController.show_global_feed) {
            types.push("Global")
        }
        return types
    }
    
    // Helper function for empty message
    function getFeedEmptyMessage() {
        if (!feedController) return "No notes to show"
        var feed = feedController.current_feed.toString()
        switch(feed) {
            case "home":
            case "following": 
            case "replies": return "No posts from people you follow"
            case "global": return "No notes found"
            default: return "No notes to show"
        }
    }
    
    // Reload notes when feed updates
    Connections {
        target: feedController
        ignoreUnknownSignals: true
        function onFeed_updated() {
            feedList.model = feedController ? feedController.note_count : 0
        }
        function onMore_loaded(count) {
            feedList.model = feedController ? feedController.note_count : 0
        }
        function onNew_notes_found(count) {
            feedList.model = feedController ? feedController.note_count : 0
            if (count > 0) {
                // Scroll to top to show new notes
                feedList.positionViewAtBeginning()
            }
        }
        function onError_occurred(error) {
            console.log("Feed error:", error)
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
                    text: "Feed"
                    color: "#ffffff"
                    font.pixelSize: 20
                    font.weight: Font.Bold
                }
                
                // Feed type tabs (Following / Replies / Global - based on settings)
                Row {
                    spacing: 4
                    
                    Repeater {
                        model: root.feedTypes
                        
                        delegate: Rectangle {
                            width: tabText.implicitWidth + 24
                            height: 32
                            radius: 16
                            color: feedController && feedController.current_feed.toString() === modelData.toLowerCase() 
                                ? "#9333ea" : "transparent"
                            border.color: feedController && feedController.current_feed.toString() === modelData.toLowerCase()
                                ? "#9333ea" : "#333333"
                            border.width: 1
                            
                            Text {
                                id: tabText
                                anchors.centerIn: parent
                                text: modelData
                                color: feedController && feedController.current_feed.toString() === modelData.toLowerCase()
                                    ? "#ffffff" : "#aaaaaa"
                                font.pixelSize: 13
                                font.weight: Font.Medium
                            }
                            
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                hoverEnabled: true
                                
                                onClicked: {
                                    if (feedController) {
                                        feedController.load_feed(modelData.toLowerCase())
                                    }
                                }
                                
                                onEntered: {
                                    if (!(feedController && feedController.current_feed.toString() === modelData.toLowerCase())) {
                                        parent.color = "#1a1a1a"
                                    }
                                }
                                onExited: {
                                    if (!(feedController && feedController.current_feed.toString() === modelData.toLowerCase())) {
                                        parent.color = "transparent"
                                    }
                                }
                            }
                        }
                    }
                }
                
                Item { Layout.fillWidth: true }
                
                // Menu button (☰)
                Button {
                    id: menuButton
                    implicitWidth: 42
                    implicitHeight: 36
                    
                    ToolTip.visible: hovered && !feedMenu.visible
                    ToolTip.text: "Menu"
                    ToolTip.delay: 500
                    
                    background: Rectangle {
                        color: parent.pressed ? "#333333" : (feedMenu.visible ? "#333333" : (parent.hovered ? "#252525" : "#1a1a1a"))
                        radius: 8
                        border.color: "#333333"
                        border.width: 1
                    }
                    
                    contentItem: Text {
                        text: "☰"
                        font.pixelSize: 18
                        color: "#ffffff"
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                    
                    onClicked: {
                        feedMenu.open()
                    }
                    
                    Menu {
                        id: feedMenu
                        y: parent.height + 4
                        
                        background: Rectangle {
                            implicitWidth: 220
                            color: "#1a1a1a"
                            border.color: "#333333"
                            border.width: 1
                            radius: 8
                        }
                        
                        MenuItem {
                            text: "🔄  Refresh Feed"
                            onTriggered: {
                                if (feedController) {
                                    feedController.refresh()
                                }
                            }
                            
                            background: Rectangle {
                                color: parent.highlighted ? "#333333" : "transparent"
                                radius: 4
                            }
                            
                            contentItem: Text {
                                text: parent.text
                                font.pixelSize: 14
                                color: "#ffffff"
                                leftPadding: 8
                            }
                        }
                        
                        MenuItem {
                            text: "⬆️  Check for New"
                            onTriggered: {
                                if (feedController) {
                                    feedController.check_for_new()
                                }
                            }
                            
                            background: Rectangle {
                                color: parent.highlighted ? "#333333" : "transparent"
                                radius: 4
                            }
                            
                            contentItem: Text {
                                text: parent.text
                                font.pixelSize: 14
                                color: "#ffffff"
                                leftPadding: 8
                            }
                        }
                        
                        MenuItem {
                            text: "⌨️  Keyboard Shortcuts"
                            onTriggered: {
                                shortcutPopup.open()
                            }
                            
                            background: Rectangle {
                                color: parent.highlighted ? "#333333" : "transparent"
                                radius: 4
                            }
                            
                            contentItem: Text {
                                text: parent.text
                                font.pixelSize: 14
                                color: "#ffffff"
                                leftPadding: 8
                            }
                        }
                        
                        MenuSeparator {
                            contentItem: Rectangle {
                                implicitHeight: 1
                                color: "#333333"
                            }
                        }
                        
                        MenuItem {
                            text: "🐛  Bugs & Suggestions"
                            onTriggered: {
                                Qt.openUrlExternally("https://pleb.one/projects.html?id=e9ce79cf-6f96-498e-83fa-41f55a01f7aa")
                            }
                            
                            background: Rectangle {
                                color: parent.highlighted ? "#333333" : "transparent"
                                radius: 4
                            }
                            
                            contentItem: Text {
                                text: parent.text
                                font.pixelSize: 14
                                color: "#ffffff"
                                leftPadding: 8
                            }
                        }
                        
                        MenuItem {
                            text: "💜  Donate"
                            onTriggered: {
                                Qt.openUrlExternally("https://pleb.one/donations.html")
                            }
                            
                            background: Rectangle {
                                color: parent.highlighted ? "#333333" : "transparent"
                                radius: 4
                            }
                            
                            contentItem: Text {
                                text: parent.text
                                font.pixelSize: 14
                                color: "#ffffff"
                                leftPadding: 8
                            }
                        }
                        
                        MenuItem {
                            text: "ℹ️  About Pleb Client"
                            onTriggered: {
                                aboutPopup.open()
                            }
                            
                            background: Rectangle {
                                color: parent.highlighted ? "#333333" : "transparent"
                                radius: 4
                            }
                            
                            contentItem: Text {
                                text: parent.text
                                font.pixelSize: 14
                                color: "#ffffff"
                                leftPadding: 8
                            }
                        }
                    }
                }
            }
        }
        
        // About popup
        Popup {
            id: aboutPopup
            anchors.centerIn: parent
            width: 400
            height: 320
            modal: true
            focus: true
            closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
            
            background: Rectangle {
                color: "#1a1a1a"
                border.color: "#333333"
                border.width: 1
                radius: 12
            }
            
            contentItem: Column {
                spacing: 16
                padding: 24
                
                Text {
                    text: "Pleb Client"
                    font.pixelSize: 24
                    font.bold: true
                    color: "#ffffff"
                    anchors.horizontalCenter: parent.horizontalCenter
                }
                
                Text {
                    text: "A Nostr client for the plebs"
                    font.pixelSize: 14
                    color: "#888888"
                    anchors.horizontalCenter: parent.horizontalCenter
                }
                
                Item { height: 16; width: 1 }
                
                Column {
                    spacing: 12
                    anchors.horizontalCenter: parent.horizontalCenter
                    
                    Button {
                        text: "🌐  Visit pleb.one"
                        anchors.horizontalCenter: parent.horizontalCenter
                        
                        background: Rectangle {
                            color: parent.pressed ? "#333333" : "#262626"
                            radius: 8
                            border.color: "#444444"
                            border.width: 1
                        }
                        
                        contentItem: Text {
                            text: parent.text
                            font.pixelSize: 14
                            color: "#ffffff"
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                            leftPadding: 16
                            rightPadding: 16
                            topPadding: 8
                            bottomPadding: 8
                        }
                        
                        onClicked: {
                            Qt.openUrlExternally("https://pleb.one")
                        }
                    }
                    
                    Button {
                        text: "💜  Support Development"
                        anchors.horizontalCenter: parent.horizontalCenter
                        
                        background: Rectangle {
                            color: parent.pressed ? "#6b21a8" : "#7c3aed"
                            radius: 8
                        }
                        
                        contentItem: Text {
                            text: parent.text
                            font.pixelSize: 14
                            color: "#ffffff"
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                            leftPadding: 16
                            rightPadding: 16
                            topPadding: 8
                            bottomPadding: 8
                        }
                        
                        onClicked: {
                            Qt.openUrlExternally("https://pleb.one/donations.html")
                        }
                    }
                    
                    Button {
                        text: "🐛  Report Bugs"
                        anchors.horizontalCenter: parent.horizontalCenter
                        
                        background: Rectangle {
                            color: parent.pressed ? "#333333" : "#262626"
                            radius: 8
                            border.color: "#444444"
                            border.width: 1
                        }
                        
                        contentItem: Text {
                            text: parent.text
                            font.pixelSize: 14
                            color: "#ffffff"
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                            leftPadding: 16
                            rightPadding: 16
                            topPadding: 8
                            bottomPadding: 8
                        }
                        
                        onClicked: {
                            Qt.openUrlExternally("https://pleb.one/projects.html?id=e9ce79cf-6f96-498e-83fa-41f55a01f7aa")
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
            
            // Performance optimizations for smooth scrolling
            cacheBuffer: 800  // Reduced cache buffer - less items to create at once
            flickDeceleration: 2500  // Smoother deceleration
            maximumFlickVelocity: 6000  // Slightly reduced for smoother feel
            boundsBehavior: Flickable.StopAtBounds
            pixelAligned: true  // Sharper rendering
            reuseItems: true  // Reuse delegate instances
            
            // Disable highlight following to reduce overhead
            highlightFollowsCurrentItem: false
            
            // Smooth scrolling animation
            ScrollBar.vertical: ScrollBar {
                policy: ScrollBar.AsNeeded
                minimumSize: 0.1
            }
            
            model: feedController ? feedController.note_count : 0
            
            delegate: NoteCard {
                id: noteDelegate
                width: feedList.width - 40
                feedController: root.feedController  // Pass for embedded content
                
                // Track the index this delegate is displaying
                property int displayIndex: index
                
                // Function to load note data for the current index
                function loadNoteData() {
                    if (root.feedController && displayIndex >= 0) {
                        var noteJson = root.feedController.get_note(displayIndex)
                        if (noteJson) {
                            var note = JSON.parse(noteJson)
                            noteId = note.id || ""
                            authorName = note.authorName || "Unknown"
                            authorPicture = note.authorPicture || ""
                            authorNip05 = note.authorNip05 || ""
                            content = note.content || ""
                            createdAt = note.createdAt || 0
                            likes = note.likes || 0
                            reposts = note.reposts || 0
                            replies = note.replies || 0
                            zapAmount = note.zapAmount || 0
                            zapCount = note.zapCount || 0
                            reactions = note.reactions || {}
                            images = note.images || []
                            videos = note.videos || []
                            isReply = note.isReply || false
                            replyTo = note.replyTo || ""
                            isRepost = note.isRepost || false
                            repostAuthorName = note.repostAuthorName || ""
                            repostAuthorPicture = note.repostAuthorPicture || ""
                        }
                    }
                }
                
                // Load data when first created
                Component.onCompleted: loadNoteData()
                
                // Reload data when index changes (delegate reuse)
                onDisplayIndexChanged: loadNoteData()
                
                // Handle delegate reuse - reload data when pooled/reused
                ListView.onPooled: {
                    // Clear data when pooled to avoid stale display
                    noteId = ""
                    content = ""
                    authorName = ""
                    authorPicture = ""
                    images = []
                    videos = []
                    isRepost = false
                    repostAuthorName = ""
                    zapCount = 0
                    zapAmount = 0
                    reactions = {}
                    // statsLoaded = false  // Disabled - stats fetching causes scroll stutter
                }
                
                ListView.onReused: {
                    // Reload data when delegate is reused for a new index
                    loadNoteData()
                }
                
                onLikeClicked: feedController.like_note(noteId)
                onRepostClicked: feedController.repost_note(noteId)
                onReplyClicked: {
                    // Open compose dialog with reply context
                    composeDialog.replyToId = noteId
                    composeDialog.replyToAuthor = authorName || "Anonymous"
                    composeDialog.replyToContent = content.substring(0, 200) + (content.length > 200 ? "..." : "")
                    composeDialog.open()
                }
                onZapClicked: {
                    // Open zap dialog with note info
                    zapDialog.noteId = noteId
                    zapDialog.authorName = authorName
                    zapDialog.open()
                }
                onNoteClicked: function(id) {
                    console.log("Opening thread for note:", id)
                    root.openThread(id)
                }
            }
            
            // Infinite scroll - load more when near bottom
            property bool loadMorePending: false
            
            onContentYChanged: {
                // Trigger load when we're within 500px of the bottom
                var distanceFromBottom = contentHeight - (contentY + height)
                if (contentHeight > height && distanceFromBottom < 500 && 
                    !feedController.is_loading && !loadMorePending) {
                    loadMorePending = true
                    feedController.load_more()
                }
            }
            
            // Reset the pending flag when loading completes
            Connections {
                target: feedController
                function onMore_loaded(count) {
                    feedList.loadMorePending = false
                }
                function onError_occurred(error) {
                    feedList.loadMorePending = false
                }
            }
            
            // Loading indicator - prominent overlay for initial load
            Rectangle {
                id: loadingOverlay
                anchors.centerIn: parent
                width: 280
                height: 140
                radius: 16
                color: "#1a1a1a"
                border.color: "#333333"
                border.width: 1
                visible: feedController && feedController.is_loading && feedController.note_count === 0
                
                Column {
                    anchors.centerIn: parent
                    spacing: 16
                    
                    BusyIndicator {
                        anchors.horizontalCenter: parent.horizontalCenter
                        running: parent.parent.visible
                        width: 48
                        height: 48
                    }
                    
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: "Loading your feed..."
                        color: "#ffffff"
                        font.pixelSize: 16
                        font.weight: Font.Medium
                    }
                    
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: feedController && feedController.loading_status.toString() !== "" 
                            ? feedController.loading_status.toString() 
                            : "Please wait..."
                        color: "#888888"
                        font.pixelSize: 13
                    }
                }
            }
            
            // Small loading indicator for subsequent loads (refresh, load more)
            BusyIndicator {
                anchors.centerIn: parent
                running: feedController && feedController.is_loading && feedController.note_count > 0
                visible: running
                width: 32
                height: 32
            }
            
            // Empty state
            Column {
                anchors.centerIn: parent
                spacing: 12
                visible: !feedController || (!feedController.is_loading && feedController.note_count === 0)
                
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: root.getFeedEmptyMessage()
                    color: "#666666"
                    font.pixelSize: 16
                }
                
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: feedController && feedController.error_message.toString() !== "" 
                        ? feedController.error_message.toString() 
                        : ""
                    color: "#ff6b6b"
                    font.pixelSize: 13
                    visible: text !== ""
                    wrapMode: Text.WordWrap
                    width: Math.min(400, root.width - 80)
                    horizontalAlignment: Text.AlignHCenter
                }
            }
        }
        
    }
    
    // Floating New Post button
    Button {
        id: newPostButton
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.rightMargin: 24
        anchors.bottomMargin: 24
        width: 56
        height: 56
        
        ToolTip.visible: hovered
        ToolTip.text: "New Post"
        ToolTip.delay: 500
        
        background: Rectangle {
            color: parent.pressed ? "#7c22ce" : (parent.hovered ? "#a855f7" : "#9333ea")
            radius: 28
            
            // Shadow
            layer.enabled: true
            layer.effect: Item {
                Rectangle {
                    anchors.fill: parent
                    anchors.margins: -4
                    radius: 32
                    color: "#20000000"
                    z: -1
                }
            }
        }
        
        contentItem: Text {
            text: "✏️"
            font.pixelSize: 24
            color: "#ffffff"
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
        }
        
        onClicked: {
            composeDialog.replyToId = ""
            composeDialog.replyToAuthor = ""
            composeDialog.replyToContent = ""
            composeDialog.open()
        }
    }
    
    // Compose Dialog for new posts and replies
    ComposeDialog {
        id: composeDialog
        feedController: root.feedController
    }
    
    // Keyboard Shortcuts Popup
    Popup {
        id: shortcutPopup
        anchors.centerIn: parent
        width: 340
        height: contentColumn.implicitHeight + 48
        modal: true
        focus: true
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
        
        background: Rectangle {
            color: "#1a1a1a"
            radius: 12
            border.color: "#333333"
            border.width: 1
        }
        
        Column {
            id: contentColumn
            anchors.fill: parent
            anchors.margins: 20
            spacing: 16
            
            // Header
            RowLayout {
                width: parent.width
                
                Text {
                    text: "⌨️ Keyboard Shortcuts"
                    color: "#ffffff"
                    font.pixelSize: 16
                    font.weight: Font.Bold
                }
                
                Item { Layout.fillWidth: true }
                
                Text {
                    text: "✕"
                    color: "#666666"
                    font.pixelSize: 18
                    
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: shortcutPopup.close()
                    }
                }
            }
            
            Rectangle {
                width: parent.width
                height: 1
                color: "#333333"
            }
            
            // Navigation section
            Column {
                width: parent.width
                spacing: 8
                
                Text {
                    text: "Navigation"
                    color: "#9333ea"
                    font.pixelSize: 13
                    font.weight: Font.Medium
                }
                
                ShortcutRow { key: "J"; desc: "Scroll down" }
                ShortcutRow { key: "K"; desc: "Scroll up" }
                ShortcutRow { key: "G"; desc: "Go to top" }
                ShortcutRow { key: "Shift + G"; desc: "Go to bottom" }
            }
            
            Rectangle {
                width: parent.width
                height: 1
                color: "#252525"
            }
            
            // Actions section
            Column {
                width: parent.width
                spacing: 8
                
                Text {
                    text: "Actions"
                    color: "#9333ea"
                    font.pixelSize: 13
                    font.weight: Font.Medium
                }
                
                ShortcutRow { key: "R"; desc: "Refresh feed" }
                ShortcutRow { key: "N"; desc: "Check for new posts" }
                ShortcutRow { key: "?"; desc: "Toggle this help" }
            }
            
            Rectangle {
                width: parent.width
                height: 1
                color: "#252525"
            }
            
            // Tabs section
            Column {
                width: parent.width
                spacing: 8
                
                Text {
                    text: "Feed Tabs"
                    color: "#9333ea"
                    font.pixelSize: 13
                    font.weight: Font.Medium
                }
                
                ShortcutRow { key: "1"; desc: "Following feed" }
                ShortcutRow { key: "2"; desc: "Replies feed" }
                ShortcutRow { key: "3"; desc: "Global feed (if enabled)" }
            }
        }
    }
    
    // Zap Dialog
    ZapDialog {
        id: zapDialog
        feedController: root.feedController
        nwcConnected: appController ? appController.nwc_connected : false
        
        onZapSent: function(noteId, amount, comment) {
            console.log("Zap sent:", amount, "sats to", noteId)
        }
    }
    
    // Handle zap results
    Connections {
        target: feedController
        
        function onZap_success(noteId, amount) {
            console.log("Zap successful:", amount, "sats to", noteId)
            // Could show a toast notification here
        }
        
        function onZap_failed(noteId, error) {
            console.log("Zap failed:", error)
            // Show error dialog
            errorDialog.text = error
            errorDialog.open()
        }
    }
    
    // Error dialog for zap failures
    Popup {
        id: errorDialog
        property string text: ""
        
        modal: true
        dim: true
        anchors.centerIn: Overlay.overlay
        width: 320
        height: errorContent.implicitHeight + 48
        padding: 24
        
        background: Rectangle {
            color: "#1a1a1a"
            radius: 12
            border.color: "#ff4444"
            border.width: 1
        }
        
        ColumnLayout {
            id: errorContent
            anchors.fill: parent
            spacing: 16
            
            Text {
                text: "⚠️ Zap Failed"
                color: "#ff6666"
                font.pixelSize: 16
                font.weight: Font.Bold
            }
            
            Text {
                Layout.fillWidth: true
                text: errorDialog.text
                color: "#cccccc"
                font.pixelSize: 14
                wrapMode: Text.Wrap
            }
            
            Button {
                Layout.fillWidth: true
                text: "OK"
                
                background: Rectangle {
                    color: parent.pressed ? "#333333" : "#2a2a2a"
                    radius: 8
                }
                
                contentItem: Text {
                    text: parent.text
                    color: "#ffffff"
                    font.pixelSize: 14
                    horizontalAlignment: Text.AlignHCenter
                }
                
                onClicked: errorDialog.close()
            }
        }
    }
    
    // Reusable shortcut row component
    component ShortcutRow: RowLayout {
        property string key: ""
        property string desc: ""
        width: parent.width
        spacing: 12
        
        Rectangle {
            Layout.preferredWidth: keyText.implicitWidth + 16
            Layout.preferredHeight: 24
            color: "#252525"
            radius: 4
            border.color: "#404040"
            border.width: 1
            
            Text {
                id: keyText
                anchors.centerIn: parent
                text: key
                color: "#cccccc"
                font.pixelSize: 12
                font.family: "monospace"
                font.weight: Font.Medium
            }
        }
        
        Text {
            text: desc
            color: "#888888"
            font.pixelSize: 13
        }
        
        Item { Layout.fillWidth: true }
    }
}
