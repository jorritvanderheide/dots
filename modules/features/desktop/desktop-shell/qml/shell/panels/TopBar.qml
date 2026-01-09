import QtQuick
import Quickshell

import "../../common"
import "../widgets"

PanelWindow { // qmllint disable uncreatable-type
    id: topBar

    required property var screenData

    screen: screenData
    anchors {
        top: true
        left: true
        right: true
    }

    implicitHeight: Theme.panelHeight
    color: Theme.panelBackground

    // Left section - App launcher and workspaces
    Row {
        id: leftSection
        anchors {
            left: parent.left
            leftMargin: Theme.paddingSmall
            top: parent.top
            bottom: parent.bottom
        }
        spacing: Theme.spacingSmall

        AppLauncher {
            onClicked: {
                console.log("App launcher clicked");
                // Future: Open app launcher
            }
        }

        // Future: Add Workspaces widget here
    }

    // Center section - Window title or info
    Item {
        id: centerSection
        anchors.centerIn: parent
        width: childrenRect.width
        height: parent.height

        WindowTitle {
            title: "Quickshell Bar - " + topBar.screenData.name
        }
    }

    // Right section - System indicators
    Row {
        id: rightSection
        anchors {
            right: parent.right
            rightMargin: Theme.paddingMedium
            top: parent.top
            bottom: parent.bottom
        }
        spacing: Theme.spacingMedium

        // Future: Add SystemTray widget here

        Clock {
            timeFormat: "hh:mm"
        }
    }
}
