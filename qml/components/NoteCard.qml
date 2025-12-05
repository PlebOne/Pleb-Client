import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Rectangle {
    id: root
    color: "#1a1a1a"
    radius: 12
    
    property string noteId: ""
    property string authorName: ""
    property string authorPicture: ""
    property string content: ""
    property int createdAt: 0
    property int likes: 0
    property int reposts: 0
    property int replies: 0
    property int zapAmount: 0
    
    signal likeClicked()
    signal repostClicked()
    signal replyClicked()
    signal zapClicked()
    
    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 16
        spacing: 12
        
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
                
                Text {
                    text: authorName
                    color: "#ffffff"
                    font.pixelSize: 15
                    font.weight: Font.Medium
                }
                
                Text {
                    text: formatTimestamp(createdAt)
                    color: "#888888"
                    font.pixelSize: 12
                }
            }
        }
        
        // Content
        Text {
            text: content
            color: "#ffffff"
            font.pixelSize: 15
            wrapMode: Text.WordWrap
            Layout.fillWidth: true
            lineHeight: 1.4
        }
        
        // Action bar
        RowLayout {
            Layout.fillWidth: true
            spacing: 24
            
            // Reply
            ActionButton {
                icon: "💬"
                count: replies
                onClicked: root.replyClicked()
            }
            
            // Repost
            ActionButton {
                icon: "🔄"
                count: reposts
                onClicked: root.repostClicked()
            }
            
            // Like
            ActionButton {
                icon: "❤️"
                count: likes
                onClicked: root.likeClicked()
            }
            
            // Zap
            ActionButton {
                icon: "⚡"
                count: zapAmount > 0 ? Math.floor(zapAmount / 1000) : 0
                suffix: zapAmount > 0 ? "k" : ""
                highlight: true
                onClicked: root.zapClicked()
            }
            
            Item { Layout.fillWidth: true }
        }
    }
    
    function formatTimestamp(ts) {
        var now = Date.now() / 1000
        var diff = now - ts
        
        if (diff < 60) return Math.floor(diff) + "s"
        if (diff < 3600) return Math.floor(diff / 60) + "m"
        if (diff < 86400) return Math.floor(diff / 3600) + "h"
        if (diff < 604800) return Math.floor(diff / 86400) + "d"
        
        var date = new Date(ts * 1000)
        return date.toLocaleDateString()
    }
    
    component ActionButton: MouseArea {
        property string icon: ""
        property int count: 0
        property string suffix: ""
        property bool highlight: false
        
        width: row.width
        height: row.height
        cursorShape: Qt.PointingHandCursor
        
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
}
