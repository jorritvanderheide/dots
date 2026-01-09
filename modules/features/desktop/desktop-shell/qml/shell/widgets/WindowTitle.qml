import QtQuick

import "../../common"

Item {
    id: windowTitle
    width: titleText.width
    height: parent.height

    property string title: ""

    Text {
        id: titleText
        anchors.centerIn: parent
        text: windowTitle.title
        color: Theme.foregroundColor
        font.pixelSize: Theme.fontSizeNormal
    }
}
