import QtQuick
import QtQuick.Controls

Rectangle {
    id: root
    radius: width / 2
    color: "#9333ea"
    
    property string name: ""
    property string imageUrl: ""
    
    Image {
        id: avatarImage
        anchors.fill: parent
        source: imageUrl
        visible: imageUrl !== "" && status === Image.Ready
        fillMode: Image.PreserveAspectCrop
        asynchronous: true  // Load images asynchronously for smooth scrolling
        cache: true         // Cache images in memory
        sourceSize.width: root.width * 2   // Limit source size for performance
        sourceSize.height: root.height * 2
        layer.enabled: true
        // layer.effect: OpacityMask would need import
        
        onStatusChanged: {
            if (status === Image.Error) {
                console.log("ProfileAvatar: Failed to load image:", imageUrl)
            }
        }
    }
    
    // Loading indicator for avatar
    Rectangle {
        anchors.fill: parent
        radius: width / 2
        color: "#2a2a2a"
        visible: imageUrl !== "" && avatarImage.status === Image.Loading
    }
    
    Text {
        anchors.centerIn: parent
        text: name.length > 0 ? name.charAt(0).toUpperCase() : "?"
        color: "#ffffff"
        font.pixelSize: parent.width * 0.4
        font.weight: Font.Bold
        visible: avatarImage.status !== Image.Ready && avatarImage.status !== Image.Loading
    }
}
