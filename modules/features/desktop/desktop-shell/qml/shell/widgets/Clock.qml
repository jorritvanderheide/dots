import QtQuick
import Quickshell

import "../../common"

Text {
    id: clock

    SystemClock {
        id: systemClock
        precision: SystemClock.Minutes
    }

    text: Qt.formatDateTime(systemClock.date, "HH:mm")
    color: Theme.foregroundColor
    font.pixelSize: Theme.fontSizeLarge
    font.bold: true
    verticalAlignment: Text.AlignVCenter
}
