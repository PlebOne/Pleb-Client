import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Rectangle {
    id: root
    color: "#0a0a0a"
    
    // Properties from AppController
    property bool signerAvailable: false
    property bool isLoading: false
    property string errorMessage: ""
    property string generatedNsec: ""
    property string generatedNpub: ""
    property bool hasSavedCredentials: false
    
    // Current view: "main", "create", "import", "advanced", "unlock"
    property string currentView: hasSavedCredentials ? "unlock" : "main"
    
    // Keep track of entered nsec for saving with password
    property string pendingNsec: ""
    
    signal loginRequested(string nsec)
    signal signerLoginRequested()
    signal checkSignerRequested()
    signal createAccountRequested()
    signal passwordLoginRequested(string password)
    signal saveCredentialsRequested(string nsec, string password)
    
    // Scroll view for content
    ScrollView {
        anchors.fill: parent
        contentWidth: availableWidth
        clip: true
        
        ColumnLayout {
            width: parent.width
            spacing: 0
            
            // Centered content
            Item {
                Layout.fillWidth: true
                Layout.preferredHeight: Math.max(contentColumn.implicitHeight + 100, root.height)
                
                ColumnLayout {
                    id: contentColumn
                    anchors.centerIn: parent
                    width: Math.min(420, parent.width - 40)
                    spacing: 24
                    
                    // Logo
                    Image {
                        Layout.preferredWidth: 120
                        Layout.preferredHeight: 120
                        Layout.alignment: Qt.AlignHCenter
                        source: "qrc:/icons/icons/icon-256.png"
                        fillMode: Image.PreserveAspectFit
                        smooth: true
                        mipmap: true
                    }
                    
                    // Title
                    Text {
                        text: "Pleb Client"
                        color: "#ffffff"
                        font.pixelSize: 32
                        font.weight: Font.Bold
                        Layout.alignment: Qt.AlignHCenter
                    }
                    
                    Text {
                        text: "A native Nostr client for Linux"
                        color: "#888888"
                        font.pixelSize: 16
                        Layout.alignment: Qt.AlignHCenter
                    }
                    
                    // Error message
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: errorText.implicitHeight + 20
                        color: "#3d1515"
                        radius: 8
                        border.color: "#ef4444"
                        border.width: 1
                        visible: root.errorMessage !== ""
                        
                        Text {
                            id: errorText
                            anchors.centerIn: parent
                            width: parent.width - 20
                            text: root.errorMessage
                            color: "#ef4444"
                            font.pixelSize: 14
                            wrapMode: Text.WordWrap
                            horizontalAlignment: Text.AlignHCenter
                        }
                    }
                    
                    Item { Layout.preferredHeight: 10 }
                    
                    // ========== UNLOCK VIEW (when credentials are saved) ==========
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 16
                        visible: root.currentView === "unlock"
                        
                        Text {
                            text: "Welcome Back"
                            color: "#ffffff"
                            font.pixelSize: 22
                            font.weight: Font.Bold
                            Layout.alignment: Qt.AlignHCenter
                        }
                        
                        Text {
                            Layout.fillWidth: true
                            text: "Enter your password to unlock your account"
                            color: "#888888"
                            font.pixelSize: 14
                            wrapMode: Text.WordWrap
                            horizontalAlignment: Text.AlignHCenter
                        }
                        
                        Item { Layout.preferredHeight: 8 }
                        
                        // Password input
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 8
                            
                            Text {
                                text: "Password"
                                color: "#888888"
                                font.pixelSize: 14
                            }
                            
                            TextField {
                                id: unlockPasswordInput
                                Layout.fillWidth: true
                                placeholderText: "Enter your password"
                                placeholderTextColor: "#555555"
                                echoMode: TextInput.Password
                                color: "#ffffff"
                                font.pixelSize: 14
                                enabled: !root.isLoading
                                
                                background: Rectangle {
                                    color: "#1a1a1a"
                                    radius: 10
                                    border.color: unlockPasswordInput.activeFocus ? "#9333ea" : "#333333"
                                    border.width: 1
                                }
                                
                                leftPadding: 16
                                rightPadding: 16
                                topPadding: 16
                                bottomPadding: 16
                                
                                Keys.onReturnPressed: {
                                    if (unlockPasswordInput.text.trim() !== "") {
                                        root.passwordLoginRequested(unlockPasswordInput.text.trim())
                                    }
                                }
                            }
                        }
                        
                        // Unlock button
                        Button {
                            id: unlockButton
                            Layout.fillWidth: true
                            Layout.preferredHeight: 50
                            enabled: !root.isLoading && unlockPasswordInput.text.trim() !== ""
                            
                            ToolTip.visible: hovered
                            ToolTip.text: "Unlock your account with your password"
                            ToolTip.delay: 500
                            
                            background: Rectangle {
                                color: unlockButton.enabled ? (unlockButton.pressed ? "#7c22ce" : (unlockButton.hovered ? "#a855f7" : "#9333ea")) : "#1a1a1a"
                                radius: 10
                            }
                            
                            contentItem: Text {
                                text: root.isLoading ? "Unlocking..." : "🔓 Unlock"
                                color: unlockButton.enabled ? "#ffffff" : "#666666"
                                font.pixelSize: 16
                                font.weight: Font.Medium
                                horizontalAlignment: Text.AlignHCenter
                            }
                            
                            onClicked: {
                                if (unlockPasswordInput.text.trim() !== "") {
                                    root.passwordLoginRequested(unlockPasswordInput.text.trim())
                                }
                            }
                        }
                        
                        Item { Layout.preferredHeight: 20 }
                        
                        // Use different account link
                        Text {
                            text: "<a href='#'>Use a different account</a>"
                            color: "#666666"
                            font.pixelSize: 14
                            Layout.alignment: Qt.AlignHCenter
                            textFormat: Text.StyledText
                            
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.currentView = "main"
                            }
                        }
                    }
                    
                    // ========== MAIN VIEW ==========
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 16
                        visible: root.currentView === "main"
                        
                        // Create New Account button (primary)
                        Button {
                            id: createAccountBtn
                            Layout.fillWidth: true
                            Layout.preferredHeight: 56
                            enabled: !root.isLoading
                            
                            ToolTip.visible: hovered
                            ToolTip.text: "Create a new Nostr identity"
                            ToolTip.delay: 500
                            
                            background: Rectangle {
                                color: createAccountBtn.pressed ? "#7c22ce" : (createAccountBtn.hovered ? "#a855f7" : "#9333ea")
                                radius: 12
                            }
                            
                            contentItem: RowLayout {
                                spacing: 12
                                anchors.centerIn: parent
                                
                                Text {
                                    text: "✨"
                                    font.pixelSize: 20
                                }
                                
                                Text {
                                    text: "Create New Account"
                                    color: "#ffffff"
                                    font.pixelSize: 18
                                    font.weight: Font.Medium
                                }
                            }
                            
                            onClicked: root.currentView = "create"
                        }
                        
                        Text {
                            text: "New to Nostr? Create your identity in seconds"
                            color: "#888888"
                            font.pixelSize: 13
                            Layout.alignment: Qt.AlignHCenter
                        }
                        
                        Item { Layout.preferredHeight: 8 }
                        
                        // Import Existing Account button
                        Button {
                            id: importAccountBtn
                            Layout.fillWidth: true
                            Layout.preferredHeight: 50
                            enabled: !root.isLoading
                            
                            ToolTip.visible: hovered
                            ToolTip.text: "Import an existing Nostr account using your nsec"
                            ToolTip.delay: 500
                            
                            background: Rectangle {
                                color: importAccountBtn.pressed ? "#2a2a2a" : (importAccountBtn.hovered ? "#333333" : "#1a1a1a")
                                radius: 10
                                border.color: "#444444"
                                border.width: 1
                            }
                            
                            contentItem: RowLayout {
                                spacing: 10
                                anchors.centerIn: parent
                                
                                Text {
                                    text: "🔑"
                                    font.pixelSize: 18
                                }
                                
                                Text {
                                    text: "I have an existing account"
                                    color: "#ffffff"
                                    font.pixelSize: 16
                                }
                            }
                            
                            onClicked: root.currentView = "import"
                        }
                        
                        Item { Layout.preferredHeight: 20 }
                        
                        // Advanced options link
                        Text {
                            text: "<a href='#'>Advanced options</a>"
                            color: "#666666"
                            font.pixelSize: 14
                            Layout.alignment: Qt.AlignHCenter
                            textFormat: Text.StyledText
                            
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.currentView = "advanced"
                            }
                        }
                    }
                    
                    // ========== CREATE ACCOUNT VIEW ==========
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 16
                        visible: root.currentView === "create"
                        
                        // Back button
                        RowLayout {
                            Layout.fillWidth: true
                            
                            Button {
                                text: "← Back"
                                font.pixelSize: 14
                                
                                ToolTip.visible: hovered
                                ToolTip.text: "Go back to main screen"
                                ToolTip.delay: 500
                                
                                background: Rectangle {
                                    color: parent.pressed ? "#2a2a2a" : (parent.hovered ? "#1a1a1a" : "transparent")
                                    radius: 4
                                }
                                
                                contentItem: Text {
                                    text: parent.text
                                    color: "#888888"
                                    font: parent.font
                                }
                                
                                onClicked: {
                                    root.currentView = "main"
                                    root.generatedNsec = ""
                                    root.generatedNpub = ""
                                }
                            }
                            
                            Item { Layout.fillWidth: true }
                        }
                        
                        Text {
                            text: "Create Your Nostr Identity"
                            color: "#ffffff"
                            font.pixelSize: 22
                            font.weight: Font.Bold
                            Layout.alignment: Qt.AlignHCenter
                        }
                        
                        // Before generation
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 16
                            visible: root.generatedNsec === ""
                            
                            Rectangle {
                                Layout.fillWidth: true
                                Layout.preferredHeight: infoCol.implicitHeight + 30
                                color: "#1a1a1a"
                                radius: 10
                                
                                ColumnLayout {
                                    id: infoCol
                                    anchors.centerIn: parent
                                    width: parent.width - 30
                                    spacing: 12
                                    
                                    Text {
                                        text: "🔐 Your keys, your identity"
                                        color: "#ffffff"
                                        font.pixelSize: 15
                                        font.weight: Font.Medium
                                    }
                                    
                                    Text {
                                        Layout.fillWidth: true
                                        text: "Nostr uses cryptographic keys instead of usernames and passwords. Your private key (nsec) is your identity - keep it safe and never share it!"
                                        color: "#888888"
                                        font.pixelSize: 13
                                        wrapMode: Text.WordWrap
                                        lineHeight: 1.4
                                    }
                                    
                                    Text {
                                        Layout.fillWidth: true
                                        text: "This app will securely store your key and can act as a signer for other Nostr applications."
                                        color: "#666666"
                                        font.pixelSize: 12
                                        wrapMode: Text.WordWrap
                                        lineHeight: 1.4
                                    }
                                }
                            }
                            
                            Button {
                                id: generateBtn
                                Layout.fillWidth: true
                                Layout.preferredHeight: 50
                                enabled: !root.isLoading
                                
                                ToolTip.visible: hovered
                                ToolTip.text: "Generate a new cryptographic key pair"
                                ToolTip.delay: 500
                                
                                background: Rectangle {
                                    color: generateBtn.pressed ? "#7c22ce" : (generateBtn.hovered ? "#a855f7" : "#9333ea")
                                    radius: 10
                                }
                                
                                contentItem: Text {
                                    text: root.isLoading ? "Generating..." : "Generate My Keys"
                                    color: "#ffffff"
                                    font.pixelSize: 16
                                    font.weight: Font.Medium
                                    horizontalAlignment: Text.AlignHCenter
                                }
                                
                                onClicked: root.createAccountRequested()
                            }
                        }
                        
                        // After generation - show keys
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 16
                            visible: root.generatedNsec !== ""
                            
                            Rectangle {
                                Layout.fillWidth: true
                                Layout.preferredHeight: warningCol.implicitHeight + 24
                                color: "#3d2815"
                                radius: 10
                                border.color: "#f59e0b"
                                border.width: 1
                                
                                ColumnLayout {
                                    id: warningCol
                                    anchors.centerIn: parent
                                    width: parent.width - 24
                                    spacing: 8
                                    
                                    Text {
                                        text: "⚠️ IMPORTANT - Save your private key!"
                                        color: "#fbbf24"
                                        font.pixelSize: 14
                                        font.weight: Font.Bold
                                    }
                                    
                                    Text {
                                        Layout.fillWidth: true
                                        text: "Write down your nsec and store it somewhere safe. If you lose it, you lose access to your account forever. There is no recovery option."
                                        color: "#fcd34d"
                                        font.pixelSize: 12
                                        wrapMode: Text.WordWrap
                                        lineHeight: 1.4
                                    }
                                }
                            }
                            
                            // Public key display
                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 6
                                
                                Text {
                                    text: "Your Public Key (npub) - share this freely"
                                    color: "#888888"
                                    font.pixelSize: 13
                                }
                                
                                Rectangle {
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 44
                                    color: "#1a1a1a"
                                    radius: 8
                                    border.color: "#333333"
                                    border.width: 1
                                    
                                    RowLayout {
                                        anchors.fill: parent
                                        anchors.margins: 10
                                        spacing: 8
                                        
                                        Text {
                                            Layout.fillWidth: true
                                            text: root.generatedNpub
                                            color: "#22c55e"
                                            font.pixelSize: 12
                                            font.family: "monospace"
                                            elide: Text.ElideMiddle
                                        }
                                        
                                        Button {
                                            Layout.preferredWidth: 60
                                            Layout.preferredHeight: 28
                                            text: "Copy"
                                            font.pixelSize: 12
                                            
                                            ToolTip.visible: hovered
                                            ToolTip.text: "Copy public key to clipboard"
                                            ToolTip.delay: 500
                                            
                                            background: Rectangle {
                                                color: parent.pressed ? "#333333" : (parent.hovered ? "#2a2a2a" : "#222222")
                                                radius: 4
                                            }
                                            
                                            contentItem: Text {
                                                text: parent.text
                                                color: "#888888"
                                                font: parent.font
                                                horizontalAlignment: Text.AlignHCenter
                                            }
                                            
                                            onClicked: {
                                                // Copy to clipboard
                                                npubCopyHelper.text = root.generatedNpub
                                                npubCopyHelper.selectAll()
                                                npubCopyHelper.copy()
                                            }
                                        }
                                    }
                                }
                            }
                            
                            // Private key display
                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 6
                                
                                Text {
                                    text: "Your Private Key (nsec) - KEEP THIS SECRET!"
                                    color: "#ef4444"
                                    font.pixelSize: 13
                                    font.weight: Font.Medium
                                }
                                
                                Rectangle {
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 44
                                    color: "#1a1515"
                                    radius: 8
                                    border.color: "#ef4444"
                                    border.width: 1
                                    
                                    RowLayout {
                                        anchors.fill: parent
                                        anchors.margins: 10
                                        spacing: 8
                                        
                                        Text {
                                            id: nsecDisplay
                                            Layout.fillWidth: true
                                            text: nsecVisible ? root.generatedNsec : "••••••••••••••••••••••••••••••••"
                                            color: "#ef4444"
                                            font.pixelSize: 12
                                            font.family: "monospace"
                                            elide: Text.ElideMiddle
                                            
                                            property bool nsecVisible: false
                                        }
                                        
                                        Button {
                                            Layout.preferredWidth: 50
                                            Layout.preferredHeight: 28
                                            text: nsecDisplay.nsecVisible ? "Hide" : "Show"
                                            font.pixelSize: 11
                                            
                                            ToolTip.visible: hovered
                                            ToolTip.text: nsecDisplay.nsecVisible ? "Hide private key" : "Show private key"
                                            ToolTip.delay: 500
                                            
                                            background: Rectangle {
                                                color: parent.pressed ? "#333333" : (parent.hovered ? "#2a2a2a" : "#222222")
                                                radius: 4
                                            }
                                            
                                            contentItem: Text {
                                                text: parent.text
                                                color: "#888888"
                                                font: parent.font
                                                horizontalAlignment: Text.AlignHCenter
                                            }
                                            
                                            onClicked: nsecDisplay.nsecVisible = !nsecDisplay.nsecVisible
                                        }
                                        
                                        Button {
                                            Layout.preferredWidth: 50
                                            Layout.preferredHeight: 28
                                            text: "Copy"
                                            font.pixelSize: 11
                                            
                                            ToolTip.visible: hovered
                                            ToolTip.text: "Copy private key to clipboard (be careful!)"
                                            ToolTip.delay: 500
                                            
                                            background: Rectangle {
                                                color: parent.pressed ? "#333333" : (parent.hovered ? "#2a2a2a" : "#222222")
                                                radius: 4
                                            }
                                            
                                            contentItem: Text {
                                                text: parent.text
                                                color: "#888888"
                                                font: parent.font
                                                horizontalAlignment: Text.AlignHCenter
                                            }
                                            
                                            onClicked: {
                                                nsecCopyHelper.text = root.generatedNsec
                                                nsecCopyHelper.selectAll()
                                                nsecCopyHelper.copy()
                                            }
                                        }
                                    }
                                }
                            }
                            
                            // Confirmation checkbox
                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 10
                                
                                CheckBox {
                                    id: savedKeyCheckbox
                                    
                                    indicator: Rectangle {
                                        implicitWidth: 22
                                        implicitHeight: 22
                                        radius: 4
                                        color: savedKeyCheckbox.checked ? "#9333ea" : "#1a1a1a"
                                        border.color: savedKeyCheckbox.checked ? "#9333ea" : "#444444"
                                        border.width: 1
                                        
                                        Text {
                                            anchors.centerIn: parent
                                            text: "✓"
                                            color: "#ffffff"
                                            font.pixelSize: 14
                                            font.weight: Font.Bold
                                            visible: savedKeyCheckbox.checked
                                        }
                                    }
                                }
                                
                                Text {
                                    Layout.fillWidth: true
                                    text: "I have saved my private key in a safe place"
                                    color: "#cccccc"
                                    font.pixelSize: 14
                                    wrapMode: Text.WordWrap
                                    
                                    MouseArea {
                                        anchors.fill: parent
                                        onClicked: savedKeyCheckbox.checked = !savedKeyCheckbox.checked
                                        cursorShape: Qt.PointingHandCursor
                                    }
                                }
                            }
                            
                            // Continue button
                            Button {
                                id: continueBtn
                                Layout.fillWidth: true
                                Layout.preferredHeight: 50
                                enabled: savedKeyCheckbox.checked && !root.isLoading
                                
                                ToolTip.visible: hovered
                                ToolTip.text: "Continue with your new account"
                                ToolTip.delay: 500
                                
                                background: Rectangle {
                                    color: continueBtn.enabled ? (continueBtn.pressed ? "#166534" : (continueBtn.hovered ? "#22c55e" : "#16a34a")) : "#1a1a1a"
                                    radius: 10
                                }
                                
                                contentItem: Text {
                                    text: "Continue to Pleb Client"
                                    color: continueBtn.enabled ? "#ffffff" : "#666666"
                                    font.pixelSize: 16
                                    font.weight: Font.Medium
                                    horizontalAlignment: Text.AlignHCenter
                                }
                                
                                onClicked: root.loginRequested(root.generatedNsec)
                            }
                        }
                    }
                    
                    // ========== IMPORT ACCOUNT VIEW ==========
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 16
                        visible: root.currentView === "import"
                        
                        // Back button
                        RowLayout {
                            Layout.fillWidth: true
                            
                            Button {
                                text: "← Back"
                                font.pixelSize: 14
                                
                                ToolTip.visible: hovered
                                ToolTip.text: "Go back to main screen"
                                ToolTip.delay: 500
                                
                                background: Rectangle {
                                    color: parent.pressed ? "#2a2a2a" : (parent.hovered ? "#1a1a1a" : "transparent")
                                    radius: 4
                                }
                                
                                contentItem: Text {
                                    text: parent.text
                                    color: "#888888"
                                    font: parent.font
                                }
                                
                                onClicked: root.currentView = "main"
                            }
                            
                            Item { Layout.fillWidth: true }
                        }
                        
                        Text {
                            text: "Import Your Account"
                            color: "#ffffff"
                            font.pixelSize: 22
                            font.weight: Font.Bold
                            Layout.alignment: Qt.AlignHCenter
                        }
                        
                        Text {
                            Layout.fillWidth: true
                            text: "Enter your private key (nsec) to access your existing Nostr identity."
                            color: "#888888"
                            font.pixelSize: 14
                            wrapMode: Text.WordWrap
                            horizontalAlignment: Text.AlignHCenter
                            lineHeight: 1.4
                        }
                        
                        Item { Layout.preferredHeight: 8 }
                        
                        // nsec input
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 8
                            
                            Text {
                                text: "Private Key (nsec)"
                                color: "#888888"
                                font.pixelSize: 14
                            }
                            
                            TextField {
                                id: nsecInput
                                Layout.fillWidth: true
                                placeholderText: "nsec1..."
                                placeholderTextColor: "#555555"
                                echoMode: TextInput.Password
                                color: "#ffffff"
                                font.pixelSize: 14
                                enabled: !root.isLoading
                                
                                background: Rectangle {
                                    color: "#1a1a1a"
                                    radius: 10
                                    border.color: nsecInput.activeFocus ? "#9333ea" : "#333333"
                                    border.width: 1
                                }
                                
                                leftPadding: 16
                                rightPadding: 16
                                topPadding: 16
                                bottomPadding: 16
                                
                                Keys.onReturnPressed: {
                                    if (nsecInput.text.trim() !== "" && !rememberMeCheckbox.checked) {
                                        root.loginRequested(nsecInput.text.trim())
                                    }
                                }
                            }
                        }
                        
                        // Remember me checkbox
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 10
                            
                            CheckBox {
                                id: rememberMeCheckbox
                                
                                indicator: Rectangle {
                                    implicitWidth: 22
                                    implicitHeight: 22
                                    radius: 4
                                    color: "#1a1a1a"
                                    border.color: rememberMeCheckbox.checked ? "#9333ea" : "#444444"
                                    border.width: 1
                                    
                                    Text {
                                        anchors.centerIn: parent
                                        text: "✓"
                                        color: "#9333ea"
                                        font.pixelSize: 14
                                        font.weight: Font.Bold
                                        visible: rememberMeCheckbox.checked
                                    }
                                }
                            }
                            
                            Text {
                                text: "Remember me (save with password)"
                                color: "#cccccc"
                                font.pixelSize: 14
                                
                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: rememberMeCheckbox.checked = !rememberMeCheckbox.checked
                                }
                            }
                        }
                        
                        // Password fields (shown when remember me is checked)
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 8
                            visible: rememberMeCheckbox.checked
                            
                            Text {
                                text: "Create a Password"
                                color: "#888888"
                                font.pixelSize: 14
                            }
                            
                            TextField {
                                id: newPasswordInput
                                Layout.fillWidth: true
                                placeholderText: "Enter a password"
                                placeholderTextColor: "#555555"
                                echoMode: TextInput.Password
                                color: "#ffffff"
                                font.pixelSize: 14
                                enabled: !root.isLoading
                                
                                background: Rectangle {
                                    color: "#1a1a1a"
                                    radius: 10
                                    border.color: newPasswordInput.activeFocus ? "#9333ea" : "#333333"
                                    border.width: 1
                                }
                                
                                leftPadding: 16
                                rightPadding: 16
                                topPadding: 14
                                bottomPadding: 14
                            }
                            
                            TextField {
                                id: confirmPasswordInput
                                Layout.fillWidth: true
                                placeholderText: "Confirm password"
                                placeholderTextColor: "#555555"
                                echoMode: TextInput.Password
                                color: "#ffffff"
                                font.pixelSize: 14
                                enabled: !root.isLoading
                                
                                background: Rectangle {
                                    color: "#1a1a1a"
                                    radius: 10
                                    border.color: confirmPasswordInput.activeFocus ? "#9333ea" : (confirmPasswordInput.text !== "" && confirmPasswordInput.text !== newPasswordInput.text ? "#ef4444" : "#333333")
                                    border.width: 1
                                }
                                
                                leftPadding: 16
                                rightPadding: 16
                                topPadding: 14
                                bottomPadding: 14
                            }
                            
                            Text {
                                visible: confirmPasswordInput.text !== "" && confirmPasswordInput.text !== newPasswordInput.text
                                text: "Passwords don't match"
                                color: "#ef4444"
                                font.pixelSize: 12
                            }
                            
                            Text {
                                text: "This password encrypts your key locally. You'll need it to login next time."
                                color: "#666666"
                                font.pixelSize: 12
                                wrapMode: Text.WordWrap
                                Layout.fillWidth: true
                            }
                        }
                        
                        // Login button
                        Button {
                            id: loginButton
                            Layout.fillWidth: true
                            Layout.preferredHeight: 50
                            enabled: {
                                if (root.isLoading) return false
                                if (nsecInput.text.trim() === "") return false
                                if (rememberMeCheckbox.checked) {
                                    return newPasswordInput.text.trim() !== "" && 
                                           newPasswordInput.text === confirmPasswordInput.text
                                }
                                return true
                            }
                            
                            ToolTip.visible: hovered
                            ToolTip.text: "Log in with your private key"
                            ToolTip.delay: 500
                            
                            background: Rectangle {
                                color: loginButton.enabled ? (loginButton.pressed ? "#7c22ce" : (loginButton.hovered ? "#a855f7" : "#9333ea")) : "#1a1a1a"
                                radius: 10
                            }
                            
                            contentItem: Text {
                                text: root.isLoading ? "Logging in..." : "Login"
                                color: loginButton.enabled ? "#ffffff" : "#666666"
                                font.pixelSize: 16
                                font.weight: Font.Medium
                                horizontalAlignment: Text.AlignHCenter
                            }
                            
                            onClicked: {
                                if (nsecInput.text.trim() !== "") {
                                    if (rememberMeCheckbox.checked && newPasswordInput.text.trim() !== "") {
                                        // Save the nsec for later, login first, then save
                                        root.pendingNsec = nsecInput.text.trim()
                                        root.loginRequested(nsecInput.text.trim())
                                        // After successful login, save credentials
                                        root.saveCredentialsRequested(nsecInput.text.trim(), newPasswordInput.text.trim())
                                    } else {
                                        root.loginRequested(nsecInput.text.trim())
                                    }
                                }
                            }
                        }
                        
                        // Info text
                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: securityNote.implicitHeight + 20
                            color: "#1a1a1a"
                            radius: 8
                            
                            Text {
                                id: securityNote
                                anchors.centerIn: parent
                                width: parent.width - 20
                                text: "🔒 Your key is encrypted locally and never sent to any server."
                                color: "#666666"
                                font.pixelSize: 12
                                wrapMode: Text.WordWrap
                                horizontalAlignment: Text.AlignHCenter
                                lineHeight: 1.4
                            }
                        }
                    }
                    
                    // ========== ADVANCED OPTIONS VIEW ==========
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 16
                        visible: root.currentView === "advanced"
                        
                        // Back button
                        RowLayout {
                            Layout.fillWidth: true
                            
                            Button {
                                text: "← Back"
                                font.pixelSize: 14
                                
                                ToolTip.visible: hovered
                                ToolTip.text: "Go back to main screen"
                                ToolTip.delay: 500
                                
                                background: Rectangle {
                                    color: parent.pressed ? "#2a2a2a" : (parent.hovered ? "#1a1a1a" : "transparent")
                                    radius: 4
                                }
                                
                                contentItem: Text {
                                    text: parent.text
                                    color: "#888888"
                                    font: parent.font
                                }
                                
                                onClicked: root.currentView = "main"
                            }
                            
                            Item { Layout.fillWidth: true }
                        }
                        
                        Text {
                            text: "Advanced Options"
                            color: "#ffffff"
                            font.pixelSize: 22
                            font.weight: Font.Bold
                            Layout.alignment: Qt.AlignHCenter
                        }
                        
                        Text {
                            Layout.fillWidth: true
                            text: "For power users who want to use an external signer application for enhanced security."
                            color: "#888888"
                            font.pixelSize: 14
                            wrapMode: Text.WordWrap
                            horizontalAlignment: Text.AlignHCenter
                        }
                        
                        Item { Layout.preferredHeight: 8 }
                        
                        // Pleb Signer section
                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: signerCol.implicitHeight + 30
                            color: "#1a1a1a"
                            radius: 10
                            border.color: root.signerAvailable ? "#22c55e" : "#333333"
                            border.width: 1
                            
                            ColumnLayout {
                                id: signerCol
                                anchors.centerIn: parent
                                width: parent.width - 30
                                spacing: 12
                                
                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: 10
                                    
                                    Text {
                                        text: "🔐"
                                        font.pixelSize: 24
                                    }
                                    
                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        spacing: 2
                                        
                                        Text {
                                            text: "Pleb Signer"
                                            color: "#ffffff"
                                            font.pixelSize: 16
                                            font.weight: Font.Medium
                                        }
                                        
                                        Text {
                                            text: root.signerAvailable ? "Connected and ready" : "Not detected"
                                            color: root.signerAvailable ? "#22c55e" : "#888888"
                                            font.pixelSize: 13
                                        }
                                    }
                                    
                                    Rectangle {
                                        width: 10
                                        height: 10
                                        radius: 5
                                        color: root.signerAvailable ? "#22c55e" : "#666666"
                                    }
                                }
                                
                                Text {
                                    Layout.fillWidth: true
                                    text: "Use a dedicated signer application to manage your keys. Your private key never touches this app."
                                    color: "#666666"
                                    font.pixelSize: 12
                                    wrapMode: Text.WordWrap
                                    lineHeight: 1.3
                                }
                                
                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: 10
                                    
                                    Button {
                                        Layout.fillWidth: true
                                        Layout.preferredHeight: 40
                                        text: root.signerAvailable ? "Login with Pleb Signer" : "Check Connection"
                                        enabled: !root.isLoading
                                        
                                        background: Rectangle {
                                            color: root.signerAvailable ? 
                                                (parent.pressed ? "#166534" : (parent.hovered ? "#22c55e" : "#16a34a")) :
                                                (parent.pressed ? "#2a2a2a" : (parent.hovered ? "#333333" : "#222222"))
                                            radius: 8
                                        }
                                        
                                        contentItem: Text {
                                            text: parent.text
                                            color: root.signerAvailable ? "#ffffff" : "#888888"
                                            font.pixelSize: 14
                                            horizontalAlignment: Text.AlignHCenter
                                        }
                                        
                                        onClicked: {
                                            if (root.signerAvailable) {
                                                root.signerLoginRequested()
                                            } else {
                                                root.checkSignerRequested()
                                            }
                                        }
                                    }
                                }
                            }
                        }
                        
                        // Info about external signers
                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: aboutSignerText.implicitHeight + 20
                            color: "transparent"
                            radius: 8
                            border.color: "#333333"
                            border.width: 1
                            
                            Text {
                                id: aboutSignerText
                                anchors.centerIn: parent
                                width: parent.width - 20
                                text: "External signers keep your private key in a separate, dedicated application. This provides better security by isolating your key from internet-connected apps. Pleb Signer is available at github.com/PlebOne/Pleb_Signer"
                                color: "#666666"
                                font.pixelSize: 12
                                wrapMode: Text.WordWrap
                                horizontalAlignment: Text.AlignHCenter
                                lineHeight: 1.4
                            }
                        }
                    }
                    
                    // Footer
                    Item { Layout.preferredHeight: 30 }
                    
                    Text {
                        text: "Learn more about <a href='https://nostr.how' style='color: #9333ea;'>Nostr</a>"
                        color: "#666666"
                        font.pixelSize: 13
                        Layout.alignment: Qt.AlignHCenter
                        textFormat: Text.StyledText
                        visible: root.currentView === "main"
                        
                        onLinkActivated: function(link) {
                            Qt.openUrlExternally(link)
                        }
                        
                        MouseArea {
                            anchors.fill: parent
                            acceptedButtons: Qt.NoButton
                            cursorShape: parent.hoveredLink ? Qt.PointingHandCursor : Qt.ArrowCursor
                        }
                    }
                }
            }
        }
    }
    
    // Hidden text fields for clipboard operations
    TextEdit {
        id: npubCopyHelper
        visible: false
    }
    
    TextEdit {
        id: nsecCopyHelper
        visible: false
    }
}
