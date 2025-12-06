import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

// Zap dialog with preset amounts
Popup {
    id: root
    
    property string noteId: ""
    property string authorName: ""
    property var feedController: null
    property bool nwcConnected: false
    
    signal zapSent(string noteId, int amount, string comment)
    
    modal: true
    dim: true
    anchors.centerIn: Overlay.overlay
    width: 340
    height: contentColumn.implicitHeight + 48
    padding: 24
    
    background: Rectangle {
        color: "#1a1a1a"
        radius: 16
        border.color: "#333333"
        border.width: 1
    }
    
    // Close on escape
    Shortcut {
        sequence: "Escape"
        onActivated: root.close()
    }
    
    ColumnLayout {
        id: contentColumn
        anchors.fill: parent
        spacing: 20
        
        // Header
        RowLayout {
            Layout.fillWidth: true
            
            Text {
                text: "⚡"
                font.pixelSize: 24
            }
            
            Text {
                text: "Send Zap"
                color: "#ffffff"
                font.pixelSize: 18
                font.weight: Font.Bold
            }
            
            Item { Layout.fillWidth: true }
            
            // Close button
            Rectangle {
                width: 28
                height: 28
                radius: 14
                color: closeArea.containsMouse ? "#333333" : "transparent"
                
                Text {
                    anchors.centerIn: parent
                    text: "✕"
                    color: "#888888"
                    font.pixelSize: 14
                }
                
                MouseArea {
                    id: closeArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.close()
                }
                
                ToolTip.visible: closeArea.containsMouse
                ToolTip.text: "Close (Esc)"
                ToolTip.delay: 500
            }
        }
        
        // Recipient
        Text {
            text: authorName ? "Zapping " + authorName : "Zapping note"
            color: "#888888"
            font.pixelSize: 13
        }
        
        // NWC not connected warning
        Rectangle {
            Layout.fillWidth: true
            height: 50
            radius: 8
            color: "#3d2020"
            border.color: "#ff4444"
            border.width: 1
            visible: !nwcConnected
            
            RowLayout {
                anchors.fill: parent
                anchors.margins: 12
                spacing: 8
                
                Text {
                    text: "⚠️"
                    font.pixelSize: 16
                }
                
                Text {
                    text: "Wallet not connected"
                    color: "#ff8888"
                    font.pixelSize: 13
                    Layout.fillWidth: true
                }
            }
        }
        
        // Preset amounts
        Text {
            text: "Choose amount (sats)"
            color: "#888888"
            font.pixelSize: 13
        }
        
        GridLayout {
            Layout.fillWidth: true
            columns: 2
            columnSpacing: 12
            rowSpacing: 12
            
            ZapAmountButton {
                amount: 21
                emoji: "🤙"
                selected: amountGroup.checkedButton === this
                ButtonGroup.group: amountGroup
            }
            
            ZapAmountButton {
                amount: 100
                emoji: "💯"
                selected: amountGroup.checkedButton === this
                ButtonGroup.group: amountGroup
            }
            
            ZapAmountButton {
                amount: 500
                emoji: "🔥"
                selected: amountGroup.checkedButton === this
                ButtonGroup.group: amountGroup
            }
            
            ZapAmountButton {
                amount: 1000
                emoji: "🚀"
                label: "1k"
                selected: amountGroup.checkedButton === this
                ButtonGroup.group: amountGroup
            }
            
            ZapAmountButton {
                amount: 5000
                emoji: "⚡"
                label: "5k"
                selected: amountGroup.checkedButton === this
                ButtonGroup.group: amountGroup
            }
            
            ZapAmountButton {
                amount: 10000
                emoji: "💎"
                label: "10k"
                selected: amountGroup.checkedButton === this
                ButtonGroup.group: amountGroup
            }
        }
        
        // Custom amount
        RowLayout {
            Layout.fillWidth: true
            spacing: 12
            
            Text {
                text: "Custom:"
                color: "#888888"
                font.pixelSize: 13
            }
            
            TextField {
                id: customAmountField
                Layout.fillWidth: true
                placeholderText: "Enter amount"
                placeholderTextColor: "#666666"
                color: "#ffffff"
                font.pixelSize: 14
                validator: IntValidator { bottom: 1; top: 1000000 }
                
                background: Rectangle {
                    color: "#2a2a2a"
                    radius: 8
                    border.color: customAmountField.activeFocus ? "#9333ea" : "#444444"
                    border.width: 1
                }
                
                onTextChanged: {
                    if (text.length > 0) {
                        amountGroup.checkedButton = null
                    }
                }
            }
            
            Text {
                text: "sats"
                color: "#888888"
                font.pixelSize: 13
            }
        }
        
        // Comment (optional)
        TextField {
            id: commentField
            Layout.fillWidth: true
            placeholderText: "Add a comment (optional)"
            placeholderTextColor: "#666666"
            color: "#ffffff"
            font.pixelSize: 14
            
            background: Rectangle {
                color: "#2a2a2a"
                radius: 8
                border.color: commentField.activeFocus ? "#9333ea" : "#444444"
                border.width: 1
            }
        }
        
        // Send button
        Button {
            Layout.fillWidth: true
            Layout.preferredHeight: 48
            enabled: nwcConnected && getSelectedAmount() > 0
            
            ToolTip.visible: hovered && enabled
            ToolTip.text: "Send zap payment"
            ToolTip.delay: 500
            
            background: Rectangle {
                radius: 8
                color: parent.enabled ? (parent.pressed ? "#7c22ce" : "#9333ea") : "#333333"
            }
            
            contentItem: RowLayout {
                spacing: 8
                
                Item { Layout.fillWidth: true }
                
                Text {
                    text: "⚡"
                    font.pixelSize: 16
                    visible: parent.parent.enabled
                }
                
                Text {
                    text: parent.parent.enabled 
                        ? "Zap " + getSelectedAmount() + " sats"
                        : (nwcConnected ? "Select amount" : "Connect wallet first")
                    color: "#ffffff"
                    font.pixelSize: 15
                    font.weight: Font.Medium
                }
                
                Item { Layout.fillWidth: true }
            }
            
            onClicked: {
                var amount = getSelectedAmount()
                if (amount > 0 && feedController) {
                    feedController.zap_note(noteId, amount, commentField.text)
                    root.zapSent(noteId, amount, commentField.text)
                    root.close()
                }
            }
        }
    }
    
    ButtonGroup {
        id: amountGroup
    }
    
    function getSelectedAmount() {
        if (customAmountField.text.length > 0) {
            return parseInt(customAmountField.text) || 0
        }
        if (amountGroup.checkedButton) {
            return amountGroup.checkedButton.amount
        }
        return 0
    }
    
    function reset() {
        customAmountField.text = ""
        commentField.text = ""
        amountGroup.checkedButton = null
    }
    
    onOpened: {
        reset()
    }
    
    // Zap amount preset button
    component ZapAmountButton: AbstractButton {
        id: zapBtn
        property int amount: 0
        property string emoji: ""
        property string label: ""
        property bool selected: false
        
        Layout.fillWidth: true
        Layout.preferredHeight: 56
        
        background: Rectangle {
            radius: 10
            color: zapBtn.selected ? "#9333ea" : (zapBtn.pressed ? "#333333" : "#2a2a2a")
            border.color: zapBtn.selected ? "#9333ea" : "#444444"
            border.width: 1
            
            Behavior on color {
                ColorAnimation { duration: 100 }
            }
        }
        
        contentItem: ColumnLayout {
            spacing: 2
            
            Text {
                Layout.alignment: Qt.AlignHCenter
                text: zapBtn.emoji
                font.pixelSize: 18
            }
            
            Text {
                Layout.alignment: Qt.AlignHCenter
                text: zapBtn.label || zapBtn.amount.toString()
                color: "#ffffff"
                font.pixelSize: 14
                font.weight: Font.Medium
            }
        }
        
        checkable: true
        
        onClicked: {
            customAmountField.text = ""
        }
    }
}
