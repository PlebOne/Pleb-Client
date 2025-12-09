import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../components"

Rectangle {
    id: root
    color: "#0a0a0a"
    // Don't grab focus by default - let the active screen handle it
    focus: false
    
    property var feedController: null
    property var appController: null
    
    // Signal to request thread view navigation
    signal openThread(string noteId)
    // Signal to request profile view navigation
    signal openProfile(string pubkey)
    
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
        } else if (event.key === Qt.Key_2 && appController && appController.show_global_feed) {
            // Switch to Global feed (if enabled)
            if (feedController) feedController.load_feed("global")
            event.accepted = true
        }
    }
    
    // Ensure focus when visible AND is the current screen
    onVisibleChanged: {
        if (visible && appController && appController.current_screen === "feed") {
            forceActiveFocus()
        }
    }
    
    // Feed types - dynamically computed based on settings
    property var feedTypes: {
        var types = ["Following"]
        if (appController && appController.show_global_feed) {
            types.push("Global")
        }
        return types
    }
    
    // Filter states - all checked by default
    property bool showPictures: true
    property bool showReplies: true
    property bool showReposts: true
    
    // Filtered notes list
    property var filteredIndices: []
    
    // Real-time stats cache - noteId -> stats object
    property var liveStatsCache: ({})
    
    // Signal to notify NoteCards of stats updates
    signal statsUpdated(string noteId, var stats)
    
    // Timer to periodically refresh stats for visible notes
    Timer {
        id: statsRefreshTimer
        interval: 30000  // Refresh every 30 seconds
        repeat: true
        running: root.visible && feedController !== null
        onTriggered: {
            root.refreshVisibleStats()
        }
    }
    
    // Function to collect visible note IDs and request refresh
    function refreshVisibleStats() {
        if (!feedController || !feedList.count) return
        
        // Get the indices of visible items
        var firstVisible = Math.max(0, Math.floor(feedList.contentY / 150))  // Approx height
        var visibleCount = Math.ceil(feedList.height / 150) + 2  // +2 for buffer
        var lastVisible = Math.min(firstVisible + visibleCount, feedList.count - 1)
        
        // Collect note IDs for visible items
        var noteIds = []
        for (var i = firstVisible; i <= lastVisible && i < root.filteredIndices.length; i++) {
            var actualIndex = root.filteredIndices[i]
            if (actualIndex !== undefined && actualIndex >= 0) {
                var noteJson = feedController.get_note(actualIndex)
                if (noteJson) {
                    try {
                        var note = JSON.parse(noteJson)
                        if (note.id) {
                            noteIds.push(note.id)
                        }
                    } catch (e) {}
                }
            }
        }
        
        if (noteIds.length > 0) {
            feedController.refresh_visible_stats(JSON.stringify(noteIds))
        }
    }
    
    // Timer to fetch stats shortly after feed loads (debounced)
    Timer {
        id: initialStatsTimer
        interval: 500  // Wait 500ms after feed loads
        repeat: false
        onTriggered: root.refreshVisibleStats()
    }
    
    // Timer for periodic stats refresh (real-time updates)
    Timer {
        id: periodicStatsTimer
        interval: 30000  // Refresh stats every 30 seconds
        repeat: true
        running: root.visible && feedController !== null
        onTriggered: root.refreshVisibleStats()
    }
    
    // Update filtered indices when filters or notes change
    function updateFilteredNotes() {
        var indices = []
        var count = feedController ? feedController.note_count : 0
        
        for (var i = 0; i < count; i++) {
            var noteJson = feedController.get_note(i)
            if (noteJson) {
                var note = JSON.parse(noteJson)
                var hasImages = note.images && note.images.length > 0
                var isReply = note.isReply || false
                var isRepost = note.isRepost || false
                
                // Apply filters
                var passesFilter = true
                
                // If showPictures is unchecked, hide notes with images
                if (!showPictures && hasImages) {
                    passesFilter = false
                }
                
                // If showReplies is unchecked, hide replies
                if (!showReplies && isReply) {
                    passesFilter = false
                }
                
                // If showReposts is unchecked, hide reposts
                if (!showReposts && isRepost) {
                    passesFilter = false
                }
                
                if (passesFilter) {
                    indices.push(i)
                }
            }
        }
        
        filteredIndices = indices
    }
    
    // Re-filter when filter states change
    onShowPicturesChanged: updateFilteredNotes()
    onShowRepliesChanged: updateFilteredNotes()
    onShowRepostsChanged: updateFilteredNotes()
    
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
            root.updateFilteredNotes()
            // Fetch stats for visible notes after feed loads
            initialStatsTimer.restart()
        }
        function onMore_loaded(count) {
            root.updateFilteredNotes()
            // Fetch stats for newly loaded notes
            initialStatsTimer.restart()
        }
        function onNew_notes_found(count) {
            root.updateFilteredNotes()
            if (count > 0) {
                // Scroll to top to show new notes
                feedList.positionViewAtBeginning()
                // Fetch stats for new notes
                initialStatsTimer.restart()
            }
        }
        function onError_occurred(error) {
            console.log("Feed error:", error)
        }
        // Handle real-time stats updates
        function onNote_stats_ready(noteId, statsJson) {
            try {
                var stats = JSON.parse(statsJson)
                // Update the live stats cache
                var newCache = root.liveStatsCache
                newCache[noteId] = stats
                root.liveStatsCache = newCache
                // Emit signal to notify NoteCards
                root.statsUpdated(noteId, stats)
            } catch (e) {
                console.log("Failed to parse stats JSON:", e)
            }
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
                
                // Separator
                Rectangle {
                    width: 1
                    height: 24
                    color: "#333333"
                    Layout.leftMargin: 8
                    Layout.rightMargin: 8
                }
                
                // Filter checkboxes
                Row {
                    spacing: 16
                    
                    // Pictures filter
                    Row {
                        spacing: 6
                        height: 32
                        
                        Rectangle {
                            id: picturesCheck
                            width: 18
                            height: 18
                            radius: 4
                            color: root.showPictures ? "#9333ea" : "transparent"
                            border.color: root.showPictures ? "#9333ea" : "#555555"
                            border.width: 1
                            anchors.verticalCenter: parent.verticalCenter
                            
                            Text {
                                anchors.centerIn: parent
                                text: "✓"
                                color: "#ffffff"
                                font.pixelSize: 11
                                font.bold: true
                                visible: root.showPictures
                            }
                            
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.showPictures = !root.showPictures
                            }
                        }
                        
                        Text {
                            text: "Pictures"
                            font.pixelSize: 13
                            color: root.showPictures ? "#ffffff" : "#888888"
                            anchors.verticalCenter: parent.verticalCenter
                            
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.showPictures = !root.showPictures
                            }
                        }
                    }
                    
                    // Replies filter
                    Row {
                        spacing: 6
                        height: 32
                        
                        Rectangle {
                            id: repliesCheck
                            width: 18
                            height: 18
                            radius: 4
                            color: root.showReplies ? "#9333ea" : "transparent"
                            border.color: root.showReplies ? "#9333ea" : "#555555"
                            border.width: 1
                            anchors.verticalCenter: parent.verticalCenter
                            
                            Text {
                                anchors.centerIn: parent
                                text: "✓"
                                color: "#ffffff"
                                font.pixelSize: 11
                                font.bold: true
                                visible: root.showReplies
                            }
                            
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.showReplies = !root.showReplies
                            }
                        }
                        
                        Text {
                            text: "Replies"
                            font.pixelSize: 13
                            color: root.showReplies ? "#ffffff" : "#888888"
                            anchors.verticalCenter: parent.verticalCenter
                            
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.showReplies = !root.showReplies
                            }
                        }
                    }
                    
                    // Reposts filter
                    Row {
                        spacing: 6
                        height: 32
                        
                        Rectangle {
                            id: repostsCheck
                            width: 18
                            height: 18
                            radius: 4
                            color: root.showReposts ? "#9333ea" : "transparent"
                            border.color: root.showReposts ? "#9333ea" : "#555555"
                            border.width: 1
                            anchors.verticalCenter: parent.verticalCenter
                            
                            Text {
                                anchors.centerIn: parent
                                text: "✓"
                                color: "#ffffff"
                                font.pixelSize: 11
                                font.bold: true
                                visible: root.showReposts
                            }
                            
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.showReposts = !root.showReposts
                            }
                        }
                        
                        Text {
                            text: "Reposts"
                            font.pixelSize: 13
                            color: root.showReposts ? "#ffffff" : "#888888"
                            anchors.verticalCenter: parent.verticalCenter
                            
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.showReposts = !root.showReposts
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
            
            model: root.filteredIndices.length
            
            delegate: NoteCard {
                id: noteDelegate
                width: feedList.width - 40
                feedController: root.feedController  // Pass for embedded content
                
                // Track the index this delegate is displaying (mapped through filter)
                property int displayIndex: index
                property int actualNoteIndex: root.filteredIndices[index] !== undefined ? root.filteredIndices[index] : -1
                
                // Function to load note data for the current index
                function loadNoteData() {
                    if (root.feedController && actualNoteIndex >= 0) {
                        var noteJson = root.feedController.get_note(actualNoteIndex)
                        if (noteJson) {
                            var note = JSON.parse(noteJson)
                            noteId = note.id || ""
                            authorPubkey = note.pubkey || ""
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
                onActualNoteIndexChanged: loadNoteData()
                
                // Handle delegate reuse - reload data when pooled/reused
                ListView.onPooled: {
                    // Clear data when pooled to avoid stale display
                    noteId = ""
                    authorPubkey = ""
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
                
                // Listen for real-time stats updates from parent
                Connections {
                    target: root
                    function onStatsUpdated(updatedNoteId, stats) {
                        if (noteDelegate.noteId === updatedNoteId) {
                            // Update stats in real-time
                            if (stats.reactions !== undefined) {
                                noteDelegate.reactions = stats.reactions
                            }
                            if (stats.zapAmount !== undefined) {
                                noteDelegate.zapAmount = stats.zapAmount
                            }
                            if (stats.zapCount !== undefined) {
                                noteDelegate.zapCount = stats.zapCount
                            }
                            if (stats.replyCount !== undefined) {
                                noteDelegate.replies = stats.replyCount
                            }
                            if (stats.repostCount !== undefined) {
                                noteDelegate.reposts = stats.repostCount
                            }
                            // Calculate total likes from reactions (❤️ + 👍 + +)
                            var likeCount = 0
                            if (stats.reactions) {
                                for (var emoji in stats.reactions) {
                                    if (emoji === "❤️" || emoji === "👍" || emoji === "+") {
                                        likeCount += stats.reactions[emoji]
                                    }
                                }
                            }
                            if (likeCount > 0) {
                                noteDelegate.likes = likeCount
                            }
                        }
                    }
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
                onAuthorClicked: function(pubkey) {
                    console.log("Opening profile for:", pubkey)
                    root.openProfile(pubkey)
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
            
            // Filtered empty state - when filters hide all content
            Column {
                anchors.centerIn: parent
                spacing: 12
                visible: feedController && !feedController.is_loading && feedController.note_count > 0 && root.filteredIndices.length === 0
                
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "🔍"
                    font.pixelSize: 48
                }
                
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "No posts match your filters"
                    color: "#666666"
                    font.pixelSize: 16
                }
                
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "Try enabling more filter options above"
                    color: "#555555"
                    font.pixelSize: 13
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
