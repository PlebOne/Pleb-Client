import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtMultimedia

Rectangle {
    id: root
    color: "#000000"
    radius: 8
    clip: true
    
    property string source: ""
    property bool autoPlay: false
    
    // Video player
    MediaPlayer {
        id: mediaPlayer
        source: root.source
        videoOutput: videoOutput
        audioOutput: AudioOutput {
            id: audioOutput
            volume: volumeSlider.value
        }
        
        onErrorOccurred: (error, errorString) => {
            console.log("Video error:", errorString)
            errorText.text = "Unable to play video"
            errorContainer.visible = true
        }
        
        onMediaStatusChanged: {
            if (mediaStatus === MediaPlayer.LoadedMedia && root.autoPlay) {
                play()
            }
        }
    }
    
    VideoOutput {
        id: videoOutput
        anchors.fill: parent
        
        // Maintain aspect ratio
        fillMode: VideoOutput.PreserveAspectFit
    }
    
    // Error display
    Rectangle {
        id: errorContainer
        anchors.fill: parent
        color: "#2a2a2a"
        visible: false
        
        Column {
            anchors.centerIn: parent
            spacing: 8
            
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "🎬"
                font.pixelSize: 32
                color: "#666666"
            }
            
            Text {
                id: errorText
                anchors.horizontalCenter: parent.horizontalCenter
                text: ""
                color: "#888888"
                font.pixelSize: 14
            }
            
            Button {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "Open externally"
                onClicked: Qt.openUrlExternally(root.source)
                
                ToolTip.visible: hovered
                ToolTip.text: "Open video in default player"
                ToolTip.delay: 500
                
                background: Rectangle {
                    color: parent.hovered ? "#3a3a3a" : "#2a2a2a"
                    radius: 4
                    border.color: "#444444"
                    border.width: 1
                }
                
                contentItem: Text {
                    text: parent.text
                    color: "#ffffff"
                    font.pixelSize: 12
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }
            }
        }
    }
    
    // Loading indicator
    Rectangle {
        anchors.fill: parent
        color: "#2a2a2a"
        visible: mediaPlayer.mediaStatus === MediaPlayer.LoadingMedia || 
                 mediaPlayer.mediaStatus === MediaPlayer.BufferingMedia
        
        BusyIndicator {
            anchors.centerIn: parent
            running: parent.visible
            width: 32
            height: 32
        }
    }
    
    // Play button overlay (shown when paused)
    Rectangle {
        id: playOverlay
        anchors.centerIn: parent
        width: 64
        height: 64
        radius: 32
        color: "#80000000"
        visible: mediaPlayer.playbackState !== MediaPlayer.PlayingState && !errorContainer.visible
        
        Text {
            anchors.centerIn: parent
            text: "▶"
            color: "#ffffff"
            font.pixelSize: 28
        }
        
        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            hoverEnabled: true
            
            onClicked: {
                if (mediaPlayer.playbackState === MediaPlayer.PlayingState) {
                    mediaPlayer.pause()
                } else {
                    mediaPlayer.play()
                }
            }
        }
        
        ToolTip.visible: playOverlay.visible && playOverlayHover.hovered
        ToolTip.text: "Play video"
        ToolTip.delay: 500
        
        HoverHandler {
            id: playOverlayHover
        }
    }
    
    // Click to play/pause
    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: {
            if (mediaPlayer.playbackState === MediaPlayer.PlayingState) {
                mediaPlayer.pause()
            } else {
                mediaPlayer.play()
            }
        }
        
        // Don't capture when controls are being used
        propagateComposedEvents: true
    }
    
    // Controls overlay
    Rectangle {
        id: controls
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: 48
        color: "#80000000"
        visible: controlsHover.containsMouse || mediaPlayer.playbackState === MediaPlayer.PlayingState
        opacity: controlsHover.containsMouse ? 1.0 : 0.0
        
        Behavior on opacity {
            NumberAnimation { duration: 200 }
        }
        
        HoverHandler {
            id: controlsHover
        }
        
        RowLayout {
            anchors.fill: parent
            anchors.margins: 8
            spacing: 8
            
            // Play/Pause button
            Rectangle {
                width: 32
                height: 32
                radius: 4
                color: playPauseHover.hovered ? "#3a3a3a" : "transparent"
                
                HoverHandler {
                    id: playPauseHover
                }
                
                Text {
                    anchors.centerIn: parent
                    text: mediaPlayer.playbackState === MediaPlayer.PlayingState ? "⏸" : "▶"
                    color: "#ffffff"
                    font.pixelSize: 16
                }
                
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (mediaPlayer.playbackState === MediaPlayer.PlayingState) {
                            mediaPlayer.pause()
                        } else {
                            mediaPlayer.play()
                        }
                    }
                }
                
                ToolTip.visible: playPauseHover.hovered
                ToolTip.text: mediaPlayer.playbackState === MediaPlayer.PlayingState ? "Pause" : "Play"
                ToolTip.delay: 500
            }
            
            // Current time
            Text {
                text: formatTime(mediaPlayer.position)
                color: "#ffffff"
                font.pixelSize: 12
            }
            
            // Progress slider
            Slider {
                id: progressSlider
                Layout.fillWidth: true
                from: 0
                to: mediaPlayer.duration > 0 ? mediaPlayer.duration : 1
                value: mediaPlayer.position
                
                onMoved: {
                    mediaPlayer.position = value
                }
                
                background: Rectangle {
                    x: progressSlider.leftPadding
                    y: progressSlider.topPadding + progressSlider.availableHeight / 2 - height / 2
                    implicitWidth: 200
                    implicitHeight: 4
                    width: progressSlider.availableWidth
                    height: implicitHeight
                    radius: 2
                    color: "#444444"
                    
                    Rectangle {
                        width: progressSlider.visualPosition * parent.width
                        height: parent.height
                        color: "#9333ea"
                        radius: 2
                    }
                }
                
                handle: Rectangle {
                    x: progressSlider.leftPadding + progressSlider.visualPosition * (progressSlider.availableWidth - width)
                    y: progressSlider.topPadding + progressSlider.availableHeight / 2 - height / 2
                    implicitWidth: 12
                    implicitHeight: 12
                    radius: 6
                    color: progressSlider.pressed ? "#b366ff" : "#9333ea"
                    visible: progressSlider.hovered || progressSlider.pressed
                }
            }
            
            // Duration
            Text {
                text: formatTime(mediaPlayer.duration)
                color: "#ffffff"
                font.pixelSize: 12
            }
            
            // Volume button
            Rectangle {
                width: 32
                height: 32
                radius: 4
                color: volumeHover.hovered ? "#3a3a3a" : "transparent"
                
                HoverHandler {
                    id: volumeHover
                }
                
                Text {
                    anchors.centerIn: parent
                    text: audioOutput.volume === 0 ? "🔇" : audioOutput.volume < 0.5 ? "🔉" : "🔊"
                    font.pixelSize: 14
                }
                
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        volumePopup.visible = !volumePopup.visible
                    }
                }
                
                ToolTip.visible: volumeHover.hovered && !volumePopup.visible
                ToolTip.text: "Volume"
                ToolTip.delay: 500
                
                // Volume popup
                Rectangle {
                    id: volumePopup
                    anchors.bottom: parent.top
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.bottomMargin: 8
                    width: 36
                    height: 100
                    radius: 4
                    color: "#2a2a2a"
                    visible: false
                    
                    Slider {
                        id: volumeSlider
                        anchors.centerIn: parent
                        orientation: Qt.Vertical
                        height: parent.height - 16
                        from: 0
                        to: 1
                        value: 0.8
                        
                        background: Rectangle {
                            x: volumeSlider.leftPadding + volumeSlider.availableWidth / 2 - width / 2
                            y: volumeSlider.topPadding
                            implicitWidth: 4
                            implicitHeight: 80
                            width: implicitWidth
                            height: volumeSlider.availableHeight
                            radius: 2
                            color: "#444444"
                            
                            Rectangle {
                                anchors.bottom: parent.bottom
                                width: parent.width
                                height: volumeSlider.visualPosition * parent.height
                                color: "#9333ea"
                                radius: 2
                            }
                        }
                        
                        handle: Rectangle {
                            x: volumeSlider.leftPadding + volumeSlider.availableWidth / 2 - width / 2
                            y: volumeSlider.topPadding + volumeSlider.visualPosition * (volumeSlider.availableHeight - height)
                            implicitWidth: 12
                            implicitHeight: 12
                            radius: 6
                            color: volumeSlider.pressed ? "#b366ff" : "#9333ea"
                        }
                    }
                }
            }
            
            // Fullscreen / Open external
            Rectangle {
                width: 32
                height: 32
                radius: 4
                color: externalHover.hovered ? "#3a3a3a" : "transparent"
                
                HoverHandler {
                    id: externalHover
                }
                
                Text {
                    anchors.centerIn: parent
                    text: "↗"
                    color: "#ffffff"
                    font.pixelSize: 16
                }
                
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Qt.openUrlExternally(root.source)
                }
                
                ToolTip.visible: externalHover.hovered
                ToolTip.text: "Open in external player"
                ToolTip.delay: 500
            }
        }
    }
    
    // Show controls on hover
    HoverHandler {
        id: rootHover
    }
    
    states: State {
        when: rootHover.hovered
        PropertyChanges { target: controls; opacity: 1.0 }
    }
    
    function formatTime(ms) {
        if (ms <= 0) return "0:00"
        
        var totalSeconds = Math.floor(ms / 1000)
        var minutes = Math.floor(totalSeconds / 60)
        var seconds = totalSeconds % 60
        
        return minutes + ":" + (seconds < 10 ? "0" : "") + seconds
    }
    
    // Stop playback when component is destroyed or hidden
    Component.onDestruction: {
        mediaPlayer.stop()
    }
    
    onVisibleChanged: {
        if (!visible) {
            mediaPlayer.pause()
        }
    }
}
