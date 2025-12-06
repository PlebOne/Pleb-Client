import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import com.plebclient 1.0
import "../components"

Rectangle {
    id: root
    color: "#0a0a0a"
    
    // External properties
    property string publicKey: ""
    property string displayName: ""
    property var appController: null
    
    // Profile controller
    ProfileController {
        id: profileController
        
        onProfile_loaded: {
            console.log("[DEBUG] Profile loaded:", profileController.display_name)
        }
        
        onProfile_updated: {
            console.log("[DEBUG] Profile updated successfully")
        }
        
        onFollow_status_changed: {
            console.log("[DEBUG] Follow status changed to:", profileController.is_following)
        }
        
        onError_occurred: function(error) {
            console.error("[DEBUG] Profile error:", error)
        }
    }
    
    // Load profile when pubkey changes
    onPublicKeyChanged: {
        if (publicKey.length > 0) {
            // Set logged in user first for follow status checking
            if (appController && appController.public_key) {
                profileController.set_logged_in_user(appController.public_key)
            }
            profileController.load_profile(publicKey)
        }
    }
    
    // Edit profile dialog
    property bool showEditDialog: false
    
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
                anchors.leftMargin: 16
                anchors.rightMargin: 16
                
                Text {
                    text: "Profile"
                    color: "#ffffff"
                    font.pixelSize: 20
                    font.weight: Font.Bold
                }
                
                Item { Layout.fillWidth: true }
                
                // Refresh button
                Button {
                    text: "↻"
                    font.pixelSize: 18
                    implicitWidth: 40
                    implicitHeight: 40
                    enabled: !profileController.is_loading
                    
                    ToolTip.visible: hovered
                    ToolTip.text: "Refresh profile"
                    ToolTip.delay: 500
                    
                    background: Rectangle {
                        color: parent.pressed ? "#333333" : "transparent"
                        radius: 20
                    }
                    
                    contentItem: Text {
                        text: parent.text
                        color: "#ffffff"
                        font: parent.font
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                    
                    onClicked: profileController.reload()
                }
            }
        }
        
        // Loading indicator
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: profileController.is_loading ? 4 : 0
            color: "transparent"
            visible: profileController.is_loading
            
            Rectangle {
                id: loadingBar
                width: parent.width * 0.3
                height: parent.height
                color: "#9333ea"
                
                NumberAnimation on x {
                    from: -loadingBar.width
                    to: root.width
                    duration: 1000
                    loops: Animation.Infinite
                    running: profileController.is_loading
                }
            }
        }
        
        // Profile content
        ScrollView {
            Layout.fillWidth: true
            Layout.fillHeight: true
            
            Flickable {
                contentWidth: parent.width
                contentHeight: contentColumn.height
                
                ColumnLayout {
                    id: contentColumn
                    width: parent.width
                    spacing: 0
                    
                    // Banner
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 200
                        
                        Image {
                            anchors.fill: parent
                            source: profileController.banner || ""
                            fillMode: Image.PreserveAspectCrop
                            visible: profileController.banner.length > 0
                        }
                        
                        // Fallback gradient
                        Rectangle {
                            anchors.fill: parent
                            visible: profileController.banner.length === 0
                            gradient: Gradient {
                                GradientStop { position: 0.0; color: "#1a1a2e" }
                                GradientStop { position: 1.0; color: "#9333ea" }
                            }
                        }
                    }
                    
                    // Profile info section
                    ColumnLayout {
                        Layout.fillWidth: true
                        Layout.topMargin: -50  // Overlap avatar with banner
                        Layout.leftMargin: 20
                        Layout.rightMargin: 20
                        spacing: 12
                        
                        // Avatar row
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 16
                            
                            // Avatar
                            Rectangle {
                                Layout.preferredWidth: 100
                                Layout.preferredHeight: 100
                                radius: 50
                                color: "#333333"
                                border.color: "#0a0a0a"
                                border.width: 4
                                
                                Image {
                                    anchors.fill: parent
                                    anchors.margins: 4
                                    source: profileController.picture || ""
                                    fillMode: Image.PreserveAspectCrop
                                    visible: profileController.picture.length > 0
                                    
                                    layer.enabled: true
                                    layer.effect: Item {
                                        // Circular mask would go here
                                    }
                                }
                                
                                // Fallback initial
                                Text {
                                    anchors.centerIn: parent
                                    text: {
                                        var name = profileController.display_name || profileController.name || ""
                                        return name.length > 0 ? name.charAt(0).toUpperCase() : "?"
                                    }
                                    color: "#ffffff"
                                    font.pixelSize: 40
                                    font.weight: Font.Bold
                                    visible: profileController.picture.length === 0
                                }
                            }
                            
                            Item { Layout.fillWidth: true }
                            
                            // Action buttons
                            RowLayout {
                                Layout.alignment: Qt.AlignBottom
                                spacing: 8
                                
                                // Follow/Unfollow button (only for other profiles)
                                Button {
                                    text: profileController.is_following ? "Following" : "Follow"
                                    visible: !profileController.is_own_profile
                                    font.pixelSize: 14
                                    
                                    ToolTip.visible: hovered
                                    ToolTip.text: profileController.is_following ? "Unfollow this user" : "Follow this user"
                                    ToolTip.delay: 500
                                    
                                    background: Rectangle {
                                        color: profileController.is_following ? 
                                            (parent.pressed ? "#333333" : "#1a1a1a") :
                                            (parent.pressed ? "#7c3aed" : "#9333ea")
                                        radius: 20
                                        border.color: profileController.is_following ? "#333333" : "transparent"
                                        border.width: 1
                                    }
                                    
                                    contentItem: Text {
                                        text: parent.text
                                        color: "#ffffff"
                                        font: parent.font
                                        horizontalAlignment: Text.AlignHCenter
                                        verticalAlignment: Text.AlignVCenter
                                    }
                                    
                                    onClicked: {
                                        if (profileController.is_following) {
                                            profileController.unfollow_user()
                                        } else {
                                            profileController.follow_user()
                                        }
                                    }
                                }
                                
                                // Edit button (only for own profile)
                                Button {
                                    text: "Edit Profile"
                                    visible: profileController.is_own_profile
                                    font.pixelSize: 14
                                    
                                    ToolTip.visible: hovered
                                    ToolTip.text: "Edit your profile"
                                    ToolTip.delay: 500
                                    
                                    background: Rectangle {
                                        color: parent.pressed ? "#333333" : "#1a1a1a"
                                        radius: 20
                                        border.color: "#333333"
                                        border.width: 1
                                    }
                                    
                                    contentItem: Text {
                                        text: parent.text
                                        color: "#ffffff"
                                        font: parent.font
                                        horizontalAlignment: Text.AlignHCenter
                                        verticalAlignment: Text.AlignVCenter
                                    }
                                    
                                    onClicked: showEditDialog = true
                                }
                            }
                        }
                        
                        // Name
                        Text {
                            text: profileController.display_name || profileController.name || "Anonymous"
                            color: "#ffffff"
                            font.pixelSize: 24
                            font.weight: Font.Bold
                        }
                        
                        // Username (if different from display name)
                        Text {
                            text: profileController.name ? "@" + profileController.name : ""
                            color: "#888888"
                            font.pixelSize: 14
                            visible: profileController.name.length > 0 && 
                                     profileController.name !== profileController.display_name
                        }
                        
                        // NIP-05
                        Text {
                            text: profileController.nip05 || ""
                            color: "#9333ea"
                            font.pixelSize: 14
                            visible: profileController.nip05.length > 0
                        }
                        
                        // About
                        Text {
                            Layout.fillWidth: true
                            text: profileController.about || ""
                            color: "#cccccc"
                            font.pixelSize: 14
                            wrapMode: Text.Wrap
                            visible: profileController.about.length > 0
                        }
                        
                        // Website
                        Text {
                            text: profileController.website || ""
                            color: "#6366f1"
                            font.pixelSize: 14
                            visible: profileController.website.length > 0
                            
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: Qt.openUrlExternally(profileController.website)
                            }
                        }
                        
                        // Lightning address
                        RowLayout {
                            visible: profileController.lud16.length > 0
                            spacing: 4
                            
                            Text {
                                text: "⚡"
                                font.pixelSize: 14
                            }
                            
                            Text {
                                text: profileController.lud16 || ""
                                color: "#fbbf24"
                                font.pixelSize: 14
                            }
                        }
                        
                        // Public key (truncated)
                        Text {
                            text: publicKey ? publicKey.substring(0, 20) + "..." : ""
                            color: "#666666"
                            font.pixelSize: 12
                            font.family: "monospace"
                            
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    // Copy to clipboard
                                    // clipboard.setText(publicKey)
                                }
                            }
                        }
                    }
                    
                    // Stats
                    RowLayout {
                        Layout.fillWidth: true
                        Layout.topMargin: 20
                        Layout.leftMargin: 20
                        Layout.rightMargin: 20
                        spacing: 40
                        
                        StatItem { 
                            label: "Notes"
                            value: profileController.notes_count.toString()
                            onClicked: {
                                // TODO: Show user's notes
                            }
                        }
                        StatItem { 
                            label: "Following"
                            value: profileController.following_count.toString()
                            onClicked: {
                                // TODO: Show following list dialog
                            }
                        }
                        StatItem { 
                            label: "Followers"
                            value: profileController.followers_count.toString()
                            onClicked: {
                                // TODO: Show followers list dialog
                            }
                        }
                    }
                    
                    // Divider
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 1
                        Layout.topMargin: 20
                        color: "#2a2a2a"
                    }
                    
                    // User's recent notes would go here
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 200
                        color: "transparent"
                        
                        Text {
                            anchors.centerIn: parent
                            text: "User's notes coming soon..."
                            color: "#666666"
                            font.pixelSize: 14
                        }
                    }
                    
                    // Spacer
                    Item { Layout.preferredHeight: 20 }
                }
            }
        }
    }
    
    // Edit Profile Dialog
    Popup {
        id: editDialog
        visible: showEditDialog
        modal: true
        anchors.centerIn: parent
        width: Math.min(500, root.width - 40)
        height: Math.min(600, root.height - 40)
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
        
        background: Rectangle {
            color: "#1a1a1a"
            radius: 12
            border.color: "#333333"
            border.width: 1
        }
        
        onClosed: showEditDialog = false
        
        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 20
            spacing: 16
            
            Text {
                text: "Edit Profile"
                color: "#ffffff"
                font.pixelSize: 20
                font.weight: Font.Bold
            }
            
            ScrollView {
                Layout.fillWidth: true
                Layout.fillHeight: true
                
                ColumnLayout {
                    width: parent.width
                    spacing: 12
                    
                    EditField { 
                        id: editName
                        label: "Name"
                        value: profileController.name
                    }
                    EditField { 
                        id: editDisplayName
                        label: "Display Name"
                        value: profileController.display_name
                    }
                    EditField { 
                        id: editAbout
                        label: "About"
                        value: profileController.about
                        multiline: true
                    }
                    EditField { 
                        id: editPicture
                        label: "Profile Picture URL"
                        value: profileController.picture
                    }
                    EditField { 
                        id: editBanner
                        label: "Banner URL"
                        value: profileController.banner
                    }
                    EditField { 
                        id: editWebsite
                        label: "Website"
                        value: profileController.website
                    }
                    EditField { 
                        id: editLud16
                        label: "Lightning Address"
                        value: profileController.lud16
                    }
                }
            }
            
            RowLayout {
                Layout.fillWidth: true
                spacing: 12
                
                Item { Layout.fillWidth: true }
                
                Button {
                    text: "Cancel"
                    onClicked: showEditDialog = false
                    
                    ToolTip.visible: hovered
                    ToolTip.text: "Cancel editing"
                    ToolTip.delay: 500
                    
                    background: Rectangle {
                        color: parent.pressed ? "#333333" : "#1a1a1a"
                        radius: 8
                        border.color: "#333333"
                        border.width: 1
                    }
                    
                    contentItem: Text {
                        text: parent.text
                        color: "#ffffff"
                        font: parent.font
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                }
                
                Button {
                    text: "Save"
                    enabled: !profileController.is_loading
                    
                    ToolTip.visible: hovered
                    ToolTip.text: "Save profile changes"
                    ToolTip.delay: 500
                    
                    background: Rectangle {
                        color: parent.pressed ? "#7c3aed" : "#9333ea"
                        radius: 8
                    }
                    
                    contentItem: Text {
                        text: parent.text
                        color: "#ffffff"
                        font: parent.font
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                    
                    onClicked: {
                        profileController.update_profile(
                            editName.value,
                            editDisplayName.value,
                            editAbout.value,
                            editPicture.value,
                            editBanner.value,
                            editWebsite.value,
                            editLud16.value
                        )
                        showEditDialog = false
                    }
                }
            }
        }
    }
    
    // Stat item component
    component StatItem: ColumnLayout {
        property string label: ""
        property string value: "0"
        signal clicked()
        
        spacing: 4
        
        MouseArea {
            Layout.fillWidth: true
            Layout.fillHeight: true
            cursorShape: Qt.PointingHandCursor
            onClicked: parent.clicked()
            
            ColumnLayout {
                anchors.fill: parent
                spacing: 4
                
                Text {
                    text: value
                    color: "#ffffff"
                    font.pixelSize: 20
                    font.weight: Font.Bold
                }
                
                Text {
                    text: label
                    color: "#888888"
                    font.pixelSize: 14
                }
            }
        }
    }
    
    // Edit field component
    component EditField: ColumnLayout {
        property string label: ""
        property string value: ""
        property bool multiline: false
        
        Layout.fillWidth: true
        spacing: 4
        
        Text {
            text: label
            color: "#888888"
            font.pixelSize: 12
        }
        
        TextField {
            Layout.fillWidth: true
            text: value
            onTextChanged: value = text
            visible: !multiline
            
            background: Rectangle {
                color: "#111111"
                radius: 8
                border.color: parent.focus ? "#9333ea" : "#333333"
                border.width: 1
            }
            
            color: "#ffffff"
            font.pixelSize: 14
        }
        
        TextArea {
            Layout.fillWidth: true
            Layout.preferredHeight: 100
            text: value
            onTextChanged: value = text
            visible: multiline
            wrapMode: TextArea.Wrap
            
            background: Rectangle {
                color: "#111111"
                radius: 8
                border.color: parent.focus ? "#9333ea" : "#333333"
                border.width: 1
            }
            
            color: "#ffffff"
            font.pixelSize: 14
        }
    }
}
