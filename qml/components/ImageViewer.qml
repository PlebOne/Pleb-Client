import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

// Full screen image viewer popup
Popup {
    id: root
    
    property string imageUrl: ""
    property int currentIndex: 0
    property var imageList: []
    
    modal: true
    dim: true
    
    width: parent.width
    height: parent.height
    x: 0
    y: 0
    
    padding: 0
    
    background: Rectangle {
        color: "#000000e0"
    }
    
    onOpened: contentItem.forceActiveFocus()
    
    contentItem: FocusScope {
        anchors.fill: parent
        focus: true
        
        // Close on escape
        Keys.onEscapePressed: root.close()
        
        // Navigation with arrow keys
        Keys.onLeftPressed: {
            if (root.currentIndex > 0) {
                root.currentIndex--
                root.imageUrl = root.imageList[root.currentIndex]
            }
        }
        
        Keys.onRightPressed: {
            if (root.currentIndex < root.imageList.length - 1) {
                root.currentIndex++
                root.imageUrl = root.imageList[root.currentIndex]
            }
        }
        
        // Click anywhere to close
        MouseArea {
            anchors.fill: parent
            onClicked: root.close()
        }
        
        // Image container
        Flickable {
            id: flickable
            anchors.fill: parent
            anchors.margins: 60
            
            contentWidth: Math.max(image.width * image.scale, width)
            contentHeight: Math.max(image.height * image.scale, height)
            clip: true
            
            boundsMovement: Flickable.StopAtBounds
            
            Image {
                id: image
                source: root.imageUrl
                anchors.centerIn: parent
                fillMode: Image.PreserveAspectFit
                
                property real scale: 1.0
                
                width: flickable.width
                height: flickable.height
                
                asynchronous: true
                cache: true
                
                // Zoom with wheel
                MouseArea {
                    anchors.fill: parent
                    propagateComposedEvents: true
                    
                    onWheel: (wheel) => {
                        var delta = wheel.angleDelta.y / 120
                        var newScale = image.scale + delta * 0.1
                        image.scale = Math.max(0.5, Math.min(4.0, newScale))
                        wheel.accepted = true
                    }
                    
                    onClicked: (mouse) => {
                        mouse.accepted = false
                    }
                }
                
                // Loading state
                BusyIndicator {
                    anchors.centerIn: parent
                    running: image.status === Image.Loading
                    visible: running
                }
                
                // Error state
                Column {
                    anchors.centerIn: parent
                    visible: image.status === Image.Error
                    spacing: 12
                    
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: "🖼️"
                        font.pixelSize: 48
                        color: "#666666"
                    }
                    
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: "Failed to load image"
                        color: "#888888"
                        font.pixelSize: 14
                    }
                    
                    Button {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: "Open externally"
                        onClicked: Qt.openUrlExternally(root.imageUrl)
                        
                        ToolTip.visible: hovered
                        ToolTip.text: "Open image in default browser"
                        ToolTip.delay: 500
                        
                        background: Rectangle {
                            color: parent.hovered ? "#3a3a3a" : "#2a2a2a"
                            radius: 8
                        }
                        
                        contentItem: Text {
                            text: parent.text
                            color: "#ffffff"
                            font.pixelSize: 13
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                        }
                    }
                }
            }
        }
        
        // Close button
        Button {
            anchors.top: parent.top
            anchors.right: parent.right
            anchors.margins: 20
            width: 44
            height: 44
            
            ToolTip.visible: hovered
            ToolTip.text: "Close viewer (Esc)"
            ToolTip.delay: 500
            
            background: Rectangle {
                color: parent.hovered ? "#ffffff30" : "#ffffff20"
                radius: 22
            }
            
            contentItem: Text {
                text: "✕"
                color: "#ffffff"
                font.pixelSize: 18
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
            }
            
            onClicked: root.close()
        }
        
        // Navigation arrows (for multiple images)
        Button {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            anchors.leftMargin: 20
            width: 44
            height: 44
            visible: root.imageList.length > 1 && root.currentIndex > 0
            
            ToolTip.visible: hovered
            ToolTip.text: "Previous image (←)"
            ToolTip.delay: 500
            
            background: Rectangle {
                color: parent.hovered ? "#ffffff30" : "#ffffff20"
                radius: 22
            }
            
            contentItem: Text {
                text: "‹"
                color: "#ffffff"
                font.pixelSize: 24
                font.weight: Font.Bold
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
            }
            
            onClicked: {
                root.currentIndex--
                root.imageUrl = root.imageList[root.currentIndex]
            }
        }
        
        Button {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            anchors.rightMargin: 20
            width: 44
            height: 44
            visible: root.imageList.length > 1 && root.currentIndex < root.imageList.length - 1
            
            ToolTip.visible: hovered
            ToolTip.text: "Next image (→)"
            ToolTip.delay: 500
            
            background: Rectangle {
                color: parent.hovered ? "#ffffff30" : "#ffffff20"
                radius: 22
            }
            
            contentItem: Text {
                text: "›"
                color: "#ffffff"
                font.pixelSize: 24
                font.weight: Font.Bold
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
            }
            
            onClicked: {
                root.currentIndex++
                root.imageUrl = root.imageList[root.currentIndex]
            }
        }
        
        // Image counter
        Rectangle {
            anchors.bottom: parent.bottom
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottomMargin: 20
            visible: root.imageList.length > 1
            
            width: counterText.width + 24
            height: 32
            radius: 16
            color: "#00000080"
            
            Text {
                id: counterText
                anchors.centerIn: parent
                text: (root.currentIndex + 1) + " / " + root.imageList.length
                color: "#ffffff"
                font.pixelSize: 13
            }
        }
        
        // Zoom controls
        Row {
            anchors.bottom: parent.bottom
            anchors.right: parent.right
            anchors.margins: 20
            spacing: 8
            
            Button {
                width: 36
                height: 36
                
                ToolTip.visible: hovered
                ToolTip.text: "Zoom out"
                ToolTip.delay: 500
                
                background: Rectangle {
                    color: parent.hovered ? "#ffffff30" : "#ffffff20"
                    radius: 8
                }
                
                contentItem: Text {
                    text: "−"
                    color: "#ffffff"
                    font.pixelSize: 18
                    font.weight: Font.Bold
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }
                
                onClicked: image.scale = Math.max(0.5, image.scale - 0.25)
            }
            
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: Math.round(image.scale * 100) + "%"
                color: "#ffffff"
                font.pixelSize: 12
                width: 40
                horizontalAlignment: Text.AlignHCenter
            }
            
            Button {
                width: 36
                height: 36
                
                ToolTip.visible: hovered
                ToolTip.text: "Zoom in"
                ToolTip.delay: 500
                
                background: Rectangle {
                    color: parent.hovered ? "#ffffff30" : "#ffffff20"
                    radius: 8
                }
                
                contentItem: Text {
                    text: "+"
                    color: "#ffffff"
                    font.pixelSize: 18
                    font.weight: Font.Bold
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }
                
                onClicked: image.scale = Math.min(4.0, image.scale + 0.25)
            }
        }
    }
    
    function showImage(url, allImages, index) {
        imageUrl = url
        imageList = allImages || [url]
        currentIndex = index || 0
        open()
    }
}
