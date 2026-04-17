import QtQuick
import Quickshell
import Quickshell.Io

import "../../common"

Item {
    id: appIcon
    width: Theme.dockIconSize
    height: Theme.dockIconSize

    property string appId: ""
    property string title: ""
    property int windowId: -1
    property bool isFocused: false
    property bool isRunning: false
    property bool isPinned: false

    signal clicked

    // Hover lift
    transform: Translate {
        y: mouseArea.containsMouse ? -2 : 0
        Behavior on y {
            NumberAnimation {
                duration: 120
                easing.type: Easing.OutCubic
            }
        }
    }

    // Background circle
    Rectangle {
        id: bg
        anchors.fill: parent
        radius: width / 2
        color: Theme.foregroundColor
        opacity: appIcon.isFocused ? 0.25 : (mouseArea.containsMouse ? 0.12 : 0)

        Behavior on opacity {
            NumberAnimation {
                duration: 120
                easing.type: Easing.OutCubic
            }
        }
    }

    // App icon
    Image {
        id: iconImage
        anchors.centerIn: parent
        width: Theme.dockIconSize * 0.7
        height: Theme.dockIconSize * 0.7
        source: "image://icon/" + IconResolver.getIconName(appIcon.appId)
        sourceSize: Qt.size(width, height)
        fillMode: Image.PreserveAspectFit
        smooth: true
        visible: status === Image.Ready

        onStatusChanged: {
            if (status === Image.Error)
                iconText.visible = true;
        }
    }

    // Fallback text when icon not available
    Text {
        id: iconText
        anchors.centerIn: parent
        text: IconResolver.getFirstLetter(appIcon.appId)
        color: Theme.foregroundColor
        font.pixelSize: Theme.fontSizeIcon
        font.bold: appIcon.isFocused
        visible: false
    }

    // Running indicator dot
    Rectangle {
        visible: appIcon.isRunning
        width: appIcon.isFocused ? 6 : 4
        height: width
        radius: width / 2
        color: Theme.foregroundColor
        anchors {
            bottom: parent.bottom
            bottomMargin: -1
            horizontalCenter: parent.horizontalCenter
        }

        Behavior on width {
            NumberAnimation {
                duration: 120
                easing.type: Easing.OutCubic
            }
        }
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        onClicked: appIcon.clicked()
        cursorShape: Qt.PointingHandCursor
    }

    Process {
        id: focusProcess
        running: false
    }

    Process {
        id: launchProcess
        running: false
    }

    Process {
        id: closeOverviewProcess
        command: ["niri", "msg", "action", "toggle-overview"]
        running: false
    }

    onClicked: {
        if (appIcon.isRunning && appIcon.windowId !== -1) {
            focusProcess.command = ["niri", "msg", "action", "focus-window", "--id", String(appIcon.windowId)];
            focusProcess.running = true;
        } else if (appIcon.isPinned && !appIcon.isRunning) {
            // Resolve appId to the real desktop entry so apps like Signal
            // (app_id "signal", desktop file "signal-desktop.desktop") launch
            // via the entry's Exec line rather than the raw app_id.
            var entry = DesktopEntries.heuristicLookup(appIcon.appId);
            if (entry) {
                entry.execute();
            } else {
                launchProcess.command = ["app2unit", "-s", "a", "--", appIcon.appId];
                launchProcess.running = true;
            }
        }

        closeOverviewProcess.running = true;
    }
}
