import QtQuick

import "../../common"

Item {
    id: clock
    width: clockText.width + Theme.paddingMedium * 2
    height: parent.height

    property string timeFormat: "hh:mm"
    property int updateInterval: 60000 // 1 minute

    Text {
        id: clockText
        anchors.centerIn: parent
        text: Qt.formatDateTime(new Date(), clock.timeFormat)
        color: Theme.foregroundColor
        font.pixelSize: Theme.fontSizeNormal

        Timer {
            interval: clock.updateInterval
            running: true
            repeat: true
            onTriggered: clockText.text = Qt.formatDateTime(new Date(), clock.timeFormat)
        }
    }
}
