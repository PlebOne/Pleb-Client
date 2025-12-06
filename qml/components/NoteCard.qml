import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Rectangle {
    id: root
    color: "#1a1a1a"
    radius: 12
    implicitHeight: contentColumn.implicitHeight + 32
    
    // Performance optimizations
    layer.enabled: false  // Disable layer unless needed
    antialiasing: false   // Disable antialiasing for rectangles
    
    property string noteId: ""
    property string authorName: ""
    property string authorPicture: ""
    property string authorNip05: ""
    property string content: ""
    property int createdAt: 0
    property int likes: 0
    property int reposts: 0
    property int replies: 0
    property int zapAmount: 0
    property int zapCount: 0  // Number of zaps
    property var reactions: ({})  // Emoji -> count map
    property var images: []
    property var videos: []
    property bool isReply: false
    property string replyTo: ""
    property bool isRepost: false
    property string repostAuthorName: ""
    property string repostAuthorPicture: ""
    property var feedController: null  // For embedded content fetching
    
    // Track if stats have been loaded
    property bool statsLoaded: false
    // Track if stats fetch is in progress
    property bool statsLoading: false
    
    signal likeClicked()
    signal repostClicked()
    signal replyClicked()
    signal zapClicked()
    signal noteClicked(string noteId)
    
    // Async stats fetching - non-blocking
    onNoteIdChanged: {
        if (noteId && feedController && visible && !statsLoaded && !statsLoading) {
            fetchStatsTimer.restart()
        }
    }
    
    onVisibleChanged: {
        if (visible && noteId && feedController && !statsLoaded && !statsLoading) {
            fetchStatsTimer.restart()
        }
    }
    
    // Timer to debounce stats fetching (prevents fetching while rapidly scrolling)
    Timer {
        id: fetchStatsTimer
        interval: 300  // Wait 300ms after note becomes visible
        repeat: false
        onTriggered: {
            if (root.noteId && root.feedController && !root.statsLoaded) {
                root.statsLoading = true
                var result = root.feedController.fetch_note_stats(root.noteId)
                try {
                    var stats = JSON.parse(result)
                    if (stats.loading) {
                        // Data is being fetched, start polling
                        statsPollTimer.start()
                    } else {
                        // Data was cached, apply immediately
                        applyStats(stats)
                    }
                } catch (e) {
                    root.statsLoading = false
                }
            }
        }
    }
    
    // Poll timer for checking async stats results
    Timer {
        id: statsPollTimer
        interval: 200  // Check every 200ms
        repeat: true
        property int pollCount: 0
        onTriggered: {
            pollCount++
            if (pollCount > 25) {  // Give up after 5 seconds
                stop()
                pollCount = 0
                root.statsLoading = false
                return
            }
            
            if (root.noteId && root.feedController) {
                var result = root.feedController.get_cached_note_stats(root.noteId)
                try {
                    var stats = JSON.parse(result)
                    if (!stats.loading) {
                        // Data is ready
                        stop()
                        pollCount = 0
                        applyStats(stats)
                    }
                } catch (e) {
                    // Continue polling
                }
            }
        }
    }
    
    // Apply fetched stats to the note card
    function applyStats(stats) {
        if (stats.reactions && Object.keys(stats.reactions).length > 0) {
            root.reactions = stats.reactions
        }
        if (stats.zapAmount !== undefined) {
            root.zapAmount = stats.zapAmount
        }
        if (stats.zapCount !== undefined) {
            root.zapCount = stats.zapCount
        }
        root.statsLoaded = true
        root.statsLoading = false
    }
    
    // Main click area for opening thread
    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: root.noteClicked(root.noteId)
        // Pass through to children that need interaction
        propagateComposedEvents: true
    }
    
    ColumnLayout {
        id: contentColumn
        anchors.fill: parent
        anchors.margins: 16
        spacing: 12
        
        // Repost indicator
        RowLayout {
            Layout.fillWidth: true
            spacing: 6
            visible: isRepost
            
            Text {
                text: "🔁"
                font.pixelSize: 12
            }
            
            Text {
                text: repostAuthorName + " reposted"
                color: "#666666"
                font.pixelSize: 12
            }
        }
        
        // Reply indicator
        RowLayout {
            Layout.fillWidth: true
            spacing: 6
            visible: isReply && !isRepost
            
            Text {
                text: "↩️"
                font.pixelSize: 12
            }
            
            Text {
                text: "Replying to a note"
                color: "#666666"
                font.pixelSize: 12
            }
        }
        
        // Header: author info
        RowLayout {
            Layout.fillWidth: true
            spacing: 12
            
            // Avatar
            ProfileAvatar {
                Layout.preferredWidth: 48
                Layout.preferredHeight: 48
                name: authorName
                imageUrl: authorPicture
            }
            
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2
                
                RowLayout {
                    spacing: 6
                    
                    Text {
                        text: authorName
                        color: "#ffffff"
                        font.pixelSize: 15
                        font.weight: Font.Medium
                        elide: Text.ElideRight
                        Layout.maximumWidth: 200
                    }
                    
                    // NIP-05 verification badge
                    Text {
                        text: "✓"
                        color: "#9333ea"
                        font.pixelSize: 12
                        visible: authorNip05 !== ""
                    }
                }
                
                RowLayout {
                    spacing: 8
                    
                    Text {
                        text: authorNip05 !== "" ? authorNip05 : ""
                        color: "#666666"
                        font.pixelSize: 12
                        visible: authorNip05 !== ""
                        elide: Text.ElideRight
                        Layout.maximumWidth: 150
                    }
                    
                    Text {
                        text: formatTimestamp(createdAt)
                        color: "#888888"
                        font.pixelSize: 12
                    }
                }
            }
        }
        
        // Content
        Text {
            text: formatContent(content)
            color: "#ffffff"
            font.pixelSize: 15
            wrapMode: Text.WordWrap
            Layout.fillWidth: true
            lineHeight: 1.4
            textFormat: Text.StyledText
            onLinkActivated: (link) => Qt.openUrlExternally(link)
            
            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.NoButton
                cursorShape: parent.hoveredLink ? Qt.PointingHandCursor : Qt.ArrowCursor
            }
        }
        
        // Embedded nostr notes (nevent, naddr, note)
        Repeater {
            model: extractNostrUris(content)
            
            delegate: EmbeddedNote {
                Layout.fillWidth: true
                nostrUri: modelData
                feedController: root.feedController
                onClicked: (noteId) => root.noteClicked(noteId)
            }
        }
        
        // Embedded nostr profiles (nprofile, npub)
        Repeater {
            model: extractProfileUris(content)
            
            delegate: EmbeddedProfile {
                Layout.fillWidth: true
                nostrUri: modelData
                feedController: root.feedController
                // TODO: onClicked navigate to profile screen
            }
        }
        
        // Link previews (non-media URLs)
        Repeater {
            model: extractPreviewUrls(content)
            
            delegate: LinkPreview {
                Layout.fillWidth: true
                url: modelData
                feedController: root.feedController
            }
        }
        
        // Image gallery
        Flow {
            Layout.fillWidth: true
            spacing: 8
            visible: images && images.length > 0
            
            Repeater {
                model: images || []
                
                delegate: Rectangle {
                    width: images.length === 1 ? Math.min(contentColumn.width, 400) : Math.min((contentColumn.width - 8) / 2, 200)
                    height: width * 0.75
                    radius: 8
                    color: "#2a2a2a"
                    clip: true
                    
                    Image {
                        anchors.fill: parent
                        source: modelData
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                        
                        // Loading placeholder
                        Rectangle {
                            anchors.fill: parent
                            color: "#2a2a2a"
                            visible: parent.status === Image.Loading
                            
                            BusyIndicator {
                                anchors.centerIn: parent
                                running: parent.visible
                                width: 24
                                height: 24
                            }
                        }
                        
                        // Error placeholder
                        Rectangle {
                            anchors.fill: parent
                            color: "#2a2a2a"
                            visible: parent.status === Image.Error
                            
                            Text {
                                anchors.centerIn: parent
                                text: "🖼️"
                                font.pixelSize: 24
                                color: "#666666"
                            }
                        }
                    }
                    
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (typeof imageViewer !== 'undefined' && imageViewer) {
                                imageViewer.showImage(modelData, images, index)
                            } else {
                                Qt.openUrlExternally(modelData)
                            }
                        }
                    }
                }
            }
        }
        
        // Video player
        Repeater {
            model: videos || []
            
            delegate: VideoPlayer {
                Layout.fillWidth: true
                Layout.preferredHeight: 280
                source: modelData
                autoPlay: false
            }
        }
        
        // Reactions display (show emoji counts above action bar)
        Flow {
            Layout.fillWidth: true
            spacing: 6
            visible: Object.keys(root.reactions).length > 0
            
            Repeater {
                model: Object.keys(root.reactions)
                
                delegate: Rectangle {
                    width: reactionContent.implicitWidth + 12
                    height: 24
                    radius: 12
                    color: "#2a2a2a"
                    
                    RowLayout {
                        id: reactionContent
                        anchors.centerIn: parent
                        spacing: 4
                        
                        Text {
                            text: modelData
                            font.pixelSize: 12
                        }
                        
                        Text {
                            text: root.reactions[modelData] || 0
                            color: "#888888"
                            font.pixelSize: 11
                        }
                    }
                    
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            // React with the same emoji
                            reactionPicker.noteId = root.noteId
                            reactionPicker.reactions = root.reactions
                            reactionPicker.open()
                        }
                    }
                }
            }
        }
        
        // Action bar
        RowLayout {
            Layout.fillWidth: true
            spacing: 24
            
            // Reply
            ActionButton {
                icon: "💬"
                count: replies
                tooltipText: "Reply to this note"
                onClicked: root.replyClicked()
            }
            
            // Repost
            ActionButton {
                icon: "🔄"
                count: reposts
                tooltipText: "Repost this note"
                onClicked: root.repostClicked()
            }
            
            // Like/React (opens reaction picker)
            ActionButton {
                id: likeButton
                icon: "❤️"
                count: getTotalReactions()
                tooltipText: "React with emoji"
                onClicked: {
                    reactionPicker.noteId = root.noteId
                    reactionPicker.reactions = root.reactions
                    reactionPicker.open()
                }
                
                function getTotalReactions() {
                    var total = 0
                    var keys = Object.keys(root.reactions)
                    for (var i = 0; i < keys.length; i++) {
                        total += root.reactions[keys[i]] || 0
                    }
                    return total > 0 ? total : root.likes
                }
            }
            
            // Zap - show total sats and count
            ZapButton {
                zapAmount: root.zapAmount
                zapCount: root.zapCount
                onClicked: root.zapClicked()
            }
            
            Item { Layout.fillWidth: true }
        }
    }
    
    // Reaction picker popup
    ReactionPicker {
        id: reactionPicker
        parent: Overlay.overlay
        x: Math.round((parent.width - width) / 2)
        y: Math.round((parent.height - height) / 2)
        feedController: root.feedController
        
        onReactionSelected: function(emoji) {
            if (root.feedController && root.noteId) {
                root.feedController.react_to_note(root.noteId, emoji)
                // Optimistically update the local reactions
                var newReactions = Object.assign({}, root.reactions)
                newReactions[emoji] = (newReactions[emoji] || 0) + 1
                root.reactions = newReactions
            }
        }
    }
    
    function formatTimestamp(ts) {
        if (ts === 0) return ""
        
        var now = Date.now() / 1000
        var diff = now - ts
        
        if (diff < 60) return Math.floor(diff) + "s"
        if (diff < 3600) return Math.floor(diff / 60) + "m"
        if (diff < 86400) return Math.floor(diff / 3600) + "h"
        if (diff < 604800) return Math.floor(diff / 86400) + "d"
        
        var date = new Date(ts * 1000)
        return date.toLocaleDateString()
    }
    
    function formatContent(text) {
        if (!text) return ""
        
        // Escape HTML
        var escaped = text.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;")
        
        // Remove nostr: URIs for notes (they're shown as embeds below)
        escaped = escaped.replace(/nostr:(nevent|naddr|note)[a-z0-9]+/gi, "")
        
        // Remove nostr: URIs for profiles (they're shown as embeds below)
        escaped = escaped.replace(/nostr:(nprofile|npub)[a-z0-9]+/gi, "")
        
        // Convert URLs to links (but not image/video URLs which are displayed separately)
        var urlPattern = /https?:\/\/[^\s<>\[\]]+/g
        escaped = escaped.replace(urlPattern, function(url) {
            var lower = url.toLowerCase()
            // Don't link media URLs (they're shown as embeds)
            if (lower.match(/\.(jpg|jpeg|png|gif|webp|mp4|webm|mov)$/)) {
                return ""
            }
            // Return shortened link text for cleaner display
            var displayUrl = url.length > 50 ? url.substring(0, 47) + "..." : url
            return '<a href="' + url + '" style="color: #9333ea;">' + displayUrl + '</a>'
        })
        
        // Convert newlines
        escaped = escaped.replace(/\n/g, "<br>")
        
        // Clean up multiple line breaks from removed content
        escaped = escaped.replace(/(<br>){3,}/g, "<br><br>")
        
        return escaped.trim()
    }
    
    // Extract nostr:nevent, nostr:naddr, nostr:note URIs from content
    function extractNostrUris(text) {
        if (!text) return []
        
        var uris = []
        var pattern = /nostr:(nevent[a-z0-9]+|naddr[a-z0-9]+|note[a-z0-9]+)/gi
        var match
        
        while ((match = pattern.exec(text)) !== null) {
            uris.push(match[0])
        }
        
        // Deduplicate
        return [...new Set(uris)]
    }
    
    // Extract nostr:nprofile, nostr:npub URIs from content
    function extractProfileUris(text) {
        if (!text) return []
        
        var uris = []
        var pattern = /nostr:(nprofile[a-z0-9]+|npub[a-z0-9]+)/gi
        var match
        
        while ((match = pattern.exec(text)) !== null) {
            uris.push(match[0])
        }
        
        // Deduplicate
        return [...new Set(uris)]
    }
    
    // Extract URLs for link previews (non-media, non-nostr)
    function extractPreviewUrls(text) {
        if (!text) return []
        
        var urls = []
        var pattern = /https?:\/\/[^\s<>\[\]]+/g
        var match
        
        while ((match = pattern.exec(text)) !== null) {
            var url = match[0]
            var lower = url.toLowerCase()
            
            // Skip media URLs (shown in gallery)
            if (lower.match(/\.(jpg|jpeg|png|gif|webp|mp4|webm|mov)$/)) {
                continue
            }
            
            // Skip nostr.band and other nostr links (they're just note references)
            if (lower.includes("nostr.band") || lower.includes("primal.net") || 
                lower.includes("snort.social") || lower.includes("iris.to")) {
                continue
            }
            
            urls.push(url)
        }
        
        // Deduplicate and limit to first 2 previews
        return [...new Set(urls)].slice(0, 2)
    }
    
    // Format sats amount nicely (e.g., 1234 -> "1.2k", 1234567 -> "1.2M")
    function formatSats(amount) {
        if (amount >= 1000000) {
            return (amount / 1000000).toFixed(1) + "M"
        } else if (amount >= 1000) {
            return (amount / 1000).toFixed(1) + "k"
        }
        return amount.toString()
    }
    
    component ActionButton: MouseArea {
        property string icon: ""
        property int count: 0
        property string suffix: ""
        property bool highlight: false
        property string tooltipText: ""
        
        width: row.width
        height: row.height
        cursorShape: Qt.PointingHandCursor
        hoverEnabled: true
        
        ToolTip.visible: containsMouse && tooltipText !== ""
        ToolTip.text: tooltipText
        ToolTip.delay: 500
        
        RowLayout {
            id: row
            spacing: 6
            
            Text {
                text: icon
                font.pixelSize: 16
            }
            
            Text {
                text: count > 0 ? count.toString() + suffix : ""
                color: highlight ? "#facc15" : "#888888"
                font.pixelSize: 13
            }
        }
    }
    
    // Zap button with amount and count display
    component ZapButton: MouseArea {
        property int zapAmount: 0
        property int zapCount: 0
        
        width: zapRow.width
        height: zapRow.height
        cursorShape: Qt.PointingHandCursor
        
        RowLayout {
            id: zapRow
            spacing: 6
            
            Text {
                text: "⚡"
                font.pixelSize: 16
            }
            
            // Sats amount (primary display)
            Text {
                text: zapAmount > 0 ? formatSats(zapAmount) : ""
                color: "#facc15"  // Yellow/gold for sats
                font.pixelSize: 13
                font.weight: Font.Medium
                visible: zapAmount > 0
            }
            
            // Zap count (secondary, smaller)
            Text {
                text: zapCount > 1 ? "(" + zapCount + ")" : ""
                color: "#888888"
                font.pixelSize: 11
                visible: zapCount > 1
            }
        }
        
        // Tooltip showing exact amount or prompt to zap
        ToolTip.visible: containsMouse
        ToolTip.text: zapAmount > 0 ? zapAmount.toLocaleString() + " sats from " + zapCount + " zap" + (zapCount !== 1 ? "s" : "") : "Send a zap"
        ToolTip.delay: 500
        
        hoverEnabled: true
    }
}
