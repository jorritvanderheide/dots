import QtQuick
import Quickshell

import "../../common"
import "../widgets"

PanelWindow { // qmllint disable uncreatable-type
    id: topBar

    required property var screenData

    screen: screenData
    anchors.top: true
    anchors.left: true
    anchors.right: true

    implicitHeight: Theme.topBarHeight

    exclusiveZone: 0
    color: "transparent"

    readonly property string targetMonitor: AppConfig.monitor !== "" ? AppConfig.monitor : NiriState.focusedOutputName
    readonly property bool shouldShow: NiriState.isOverviewActive && screenData.name === targetMonitor

    // Slide-in from top: 0 = offscreen above, 1 = at rest. Mirrors the Dock's
    // slideProgress but translates the content upward when hidden.
    property real slideProgress: 0
    Behavior on slideProgress {
        NumberAnimation {
            duration: 250
            easing.type: Easing.OutCubic
        }
    }

    visible: shouldShow || slideProgress > 0.001

    onShouldShowChanged: slideProgress = shouldShow ? 1 : 0

    Component.onCompleted: slideProgress = shouldShow ? 1 : 0

    Item {
        id: slidingContent
        width: parent.width
        height: parent.height
        y: -parent.height * (1 - topBar.slideProgress)

        // Clock floats centered so it stays put regardless of how many tray
        // icons or widgets sit on the right.
        Clock {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.verticalCenter: parent.verticalCenter
        }

        Row {
            id: rightWidgets
            anchors.right: parent.right
            anchors.rightMargin: Theme.topBarSideMargin
            anchors.verticalCenter: parent.verticalCenter
            spacing: Theme.topBarSpacing

            SystemTray {}

            Battery {}
        }
    }
}
