import QtQuick
import Quickshell
import Quickshell.Services.UPower

import "../../common"

Row {
    id: battery

    readonly property var device: UPower.displayDevice
    readonly property bool available: device && device.isPresent
    readonly property real percentage: available ? device.percentage : 0
    readonly property bool charging: available && device.state === UPowerDeviceState.Charging
    readonly property bool low: percentage > 0 && percentage <= 15 && !charging

    visible: available
    spacing: Theme.spacingTiny

    // Horizontal battery glyph: outlined pill body + small terminal nub on the
    // right, with an inner fill proportional to the current percentage.
    Item {
        id: glyph
        anchors.verticalCenter: parent.verticalCenter
        width: Theme.topBarIconSize + 8
        height: Theme.topBarIconSize * 0.65

        readonly property int borderWidth: 1

        Rectangle {
            id: body
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            width: parent.width - nub.width
            color: "transparent"
            border.color: Theme.foregroundColor
            border.width: glyph.borderWidth
            radius: 2
        }

        Rectangle {
            id: nub
            anchors.left: body.right
            anchors.verticalCenter: parent.verticalCenter
            width: 2
            height: parent.height * 0.5
            radius: 1
            color: Theme.foregroundColor
        }

        Rectangle {
            id: fill
            anchors.left: body.left
            anchors.top: body.top
            anchors.leftMargin: glyph.borderWidth + 1
            anchors.topMargin: glyph.borderWidth + 1
            height: body.height - 2 * (glyph.borderWidth + 1)
            width: Math.max(0, (body.width - 2 * (glyph.borderWidth + 1)) * battery.percentage / 100)
            radius: 1
            color: battery.low ? "#e06c75" : Theme.foregroundColor

            Behavior on width {
                NumberAnimation {
                    duration: 300
                    easing.type: Easing.OutCubic
                }
            }
        }

        // Charging bolt overlay, drawn on top of the fill.
        Text {
            anchors.centerIn: body
            visible: battery.charging
            text: "\u26A1"
            color: Theme.backgroundColor
            font.pixelSize: glyph.height
            font.bold: true
        }
    }

    Text {
        anchors.verticalCenter: parent.verticalCenter
        text: Math.round(battery.percentage) + "%"
        color: Theme.foregroundColor
        font.pixelSize: Theme.fontSizeNormal
        font.bold: battery.charging
    }
}
