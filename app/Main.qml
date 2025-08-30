import QtQuick 2.15
import QtQuick.Controls 2.15

ApplicationWindow {
    id: win
    width: 800
    height: 600
    visible: true
    title: "MacCleaner - Demo"
    color: "#f0f0f0"  // Subtle background

    // Global style properties for consistency
    QtObject {
        id: style
        property color primaryColor: "#0078d4"
        property color secondaryColor: "#ffffff"
        property color accentColor: "#d13438"
        property color textColor: "#333333"
        property color borderColor: "#cccccc"
        property int radius: 6
        property int fontSize: 14
    }

    // Use an Item container for flexible anchoring
    Item {
        anchors.fill: parent
        property int margin: 12

        // Top row with buttons and status
        Row {
            id: topRow
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: margin
            spacing: 10

            Button {
                id: scanButton
                text: "Start Scan"
                enabled: !scanner.scanning  // Disable during scan
                onClicked: {
                    junkModel.clear()
                    scanner.startScan()
                }
                background: Rectangle {
                    gradient: Gradient {
                        GradientStop { position: 0.0; color: scanButton.pressed ? style.primaryColor : style.secondaryColor }
                        GradientStop { position: 1.0; color: scanButton.pressed ? Qt.darker(style.primaryColor, 1.2) : Qt.lighter(style.secondaryColor, 1.1) }
                    }
                    border.color: style.borderColor
                    border.width: 1
                    radius: style.radius
                }
                contentItem: Text {
                    text: parent.text
                    color: scanButton.pressed ? "white" : style.textColor
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                    font.pixelSize: style.fontSize
                }
                ToolTip.visible: hovered
                ToolTip.text: "Scan for junk files based on rules"
            }

            Button {
                text: "Clear"
                onClicked: junkModel.clear()
                background: Rectangle {
                    gradient: Gradient {
                        GradientStop { position: 0.0; color: pressed ? style.accentColor : style.secondaryColor }
                        GradientStop { position: 1.0; color: pressed ? Qt.darker(style.accentColor, 1.2) : Qt.lighter(style.secondaryColor, 1.1) }
                    }
                    border.color: style.borderColor
                    border.width: 1
                    radius: style.radius
                }
                contentItem: Text {
                    text: parent.text
                    color: pressed ? "white" : style.textColor
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                    font.pixelSize: style.fontSize
                }
                ToolTip.visible: hovered
                ToolTip.text: "Clear the list of found items"
            }

            Label {
                text: "Found: " + (typeof(junkModel.count) === 'number' ? junkModel.count : '0')
                font.pixelSize: style.fontSize
                color: style.textColor
                verticalAlignment: Text.AlignVCenter
            }

            // Progress indicator during scan
            BusyIndicator {
                running: scanner.scanning
                visible: running
                width: 24
                height: 24
            }
        }

        // Header row for the list
        Row {
            id: headerRow
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: topRow.bottom
            anchors.margins: margin
            height: 30
            spacing: 10

            Label { text: "Path"; font.bold: true; width: parent.width * 0.6; color: style.textColor }
            Label { text: "Size"; font.bold: true; width: parent.width * 0.15; color: style.textColor }
            Label { text: "Rule"; font.bold: true; width: parent.width * 0.15; color: style.textColor }
            Label { text: "Action"; font.bold: true; width: parent.width * 0.1; color: style.textColor }
        }

        // List view for junk items
        ListView {
            id: list
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: headerRow.bottom
            anchors.bottom: parent.bottom
            anchors.margins: margin
            model: junkModel
            clip: true

            delegate: Rectangle {
                width: parent.width
                height: 50
                color: index % 2 === 0 ? "#ffffff" : "#f9f9f9"
                border.color: style.borderColor
                border.width: 1
                radius: style.radius / 2

                Row {
                    anchors.fill: parent
                    anchors.margins: 8
                    spacing: 10

                    // Path and explanation
                    Column {
                        width: parent.width * 0.6
                        Text {
                            text: path
                            elide: Text.ElideRight
                            font.pixelSize: 12
                            color: style.textColor
                        }
                        Text {
                            text: explain
                            font.pixelSize: 10
                            color: "#666666"
                            wrapMode: Text.Wrap
                        }
                    }

                    // Size
                    Text {
                        text: (bytes / 1024).toFixed(1) + " KB"
                        width: parent.width * 0.15
                        font.pixelSize: 12
                        color: style.textColor
                        horizontalAlignment: Text.AlignRight
                    }

                    // Rule ID
                    Text {
                        text: ruleId
                        width: parent.width * 0.15
                        font.pixelSize: 12
                        color: style.textColor
                    }

                    // Trash button
                    Button {
                        text: "🗑️"
                        width: parent.width * 0.1
                        height: 30
                        onClicked: {
                            console.log("Trash: " + path)
                            // TODO: Integrate with macbridge for actual trashing
                        }
                        background: Rectangle {
                            color: pressed ? "#ffcccc" : style.secondaryColor
                            border.color: style.borderColor
                            border.width: 1
                            radius: style.radius
                        }
                        contentItem: Text {
                            text: parent.text
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                            font.pixelSize: 14
                        }
                        ToolTip.visible: hovered
                        ToolTip.text: "Move to Trash"
                    }
                }
            }
        }
    }
}