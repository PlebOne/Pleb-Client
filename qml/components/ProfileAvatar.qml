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
        layer.enabled: true
        // layer.effect: OpacityMask would need import
    }
    
    Text {
        anchors.centerIn: parent
        text: name.charAt(0).toUpperCase()
        color: "#ffffff"
        font.pixelSize: parent.width * 0.4
        font.weight: Font.Bold
        visible: !avatarImage.visible
    }
}
