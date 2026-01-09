import QtQuick
import Quickshell.Io

import "../../common"

Item {
    id: appIcon
    width: Theme.dockIconSize
    height: Theme.dockIconSize

    // Properties
    property string appId: ""
    property string title: ""
    property bool isFocused: false
    property bool isRunning: false
    property bool isPinned: false

    signal clicked

    // Background with running/focused indicator
    Rectangle {
        anchors.fill: parent
        color: {
            if (appIcon.isFocused)
                return Theme.accentColor;
            if (mouseArea.containsMouse)
                return Theme.foregroundColor;
            return "transparent";
        }
        opacity: appIcon.isFocused ? 0.4 : (mouseArea.containsMouse ? 0.2 : 0.1)
        radius: 8

        // Running indicator dot
        Rectangle {
            visible: appIcon.isRunning
            width: 4
            height: 4
            radius: 2
            color: Theme.foregroundColor
            anchors {
                bottom: parent.bottom
                bottomMargin: 2
                horizontalCenter: parent.horizontalCenter
            }
        }

        // Border for focused window
        border.width: appIcon.isFocused ? 2 : 0
        border.color: Theme.accentColor
    }

    // App icon or text placeholder
    Text {
        id: iconText
        anchors.centerIn: parent
        text: {
            // Try to get first letter of app name
            if (appIcon.appId.length > 0) {
                return appIcon.appId.charAt(0).toUpperCase();
            }
            return "?";
        }
        color: Theme.foregroundColor
        font.pixelSize: Theme.fontSizeIcon
        font.bold: appIcon.isFocused
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        onClicked: appIcon.clicked()
        cursorShape: Qt.PointingHandCursor
    }

    // Process for launching apps
    Process {
        id: launchProcess
        running: false
    }

    // Process for closing overview
    Process {
        id: closeOverviewProcess
        command: ["niri", "msg", "action", "toggle-overview"]
        running: false
    }

    onClicked: {
        if (appIcon.isPinned && !appIcon.isRunning) {
            // Launch app via app2unit
            launchProcess.command = ["app2unit", "-s", "a", "--", appIcon.appId];
            launchProcess.running = true;
        }

        // Always close overview on any click
        closeOverviewProcess.running = true;
    }
}
