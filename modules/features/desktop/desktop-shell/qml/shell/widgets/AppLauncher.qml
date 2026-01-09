import QtQuick

import "../../common"

Item {
    id: appLauncher
    width: launcherIcon.width + Theme.paddingMedium * 2
    height: parent.height

    signal clicked

    Rectangle {
        anchors.fill: parent
        color: mouseArea.containsMouse ? Theme.accentColor : "transparent"
        opacity: 0.2
        radius: 4
    }

    Text {
        id: launcherIcon
        anchors.centerIn: parent
        text: "☰"
        color: Theme.foregroundColor
        font.pixelSize: Theme.fontSizeIcon
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        onClicked: appLauncher.clicked()
        cursorShape: Qt.PointingHandCursor
    }
}
