import QtQuick
import Quickshell

import "../../common"
import "../widgets"

PanelWindow { // qmllint disable uncreatable-type
    id: dock

    required property var screenData

    screen: screenData
    anchors.bottom: true

    implicitHeight: Theme.dockHeight
    implicitWidth: dockContent.width + Theme.dockPadding * 4
    exclusiveZone: 0
    color: "transparent"

    visible: NiriState.isOverviewActive && screenData.name === NiriState.focusedOutputName

    ListModel {
        id: windowsModel
    }

    Connections {
        target: NiriState
        function onWindowsChanged() {
            dock._sync();
        }
    }

    Component.onCompleted: _sync()
    onVisibleChanged: if (visible)
        _sync()

    function _sync() {
        var windows = NiriState.windows;

        // Build target list with sort key from column position
        var target = [];
        for (var i = 0; i < windows.length; i++) {
            var win = windows[i];
            if (!win.app_id)
                continue;
            var col = 999;
            if (win.layout && win.layout.pos_in_scrolling_layout)
                col = win.layout.pos_in_scrolling_layout[0];
            target.push({
                windowId: win.id,
                appId: win.app_id,
                title: win.title || "",
                isFocused: win.is_focused || false,
                col: col
            });
        }
        target.sort(function (a, b) {
            return a.col - b.col;
        });

        // Remove closed windows (iterate backwards)
        for (var i = windowsModel.count - 1; i >= 0; i--) {
            var wid = windowsModel.get(i).windowId;
            var found = false;
            for (var j = 0; j < target.length; j++) {
                if (target[j].windowId === wid) {
                    found = true;
                    break;
                }
            }
            if (!found)
                windowsModel.remove(i);
        }

        // Insert new and reorder to match niri column order
        for (var i = 0; i < target.length; i++) {
            var t = target[i];
            var currentIdx = -1;
            for (var j = i; j < windowsModel.count; j++) {
                if (windowsModel.get(j).windowId === t.windowId) {
                    currentIdx = j;
                    break;
                }
            }

            if (currentIdx === -1) {
                windowsModel.insert(i, t);
            } else if (currentIdx !== i) {
                windowsModel.move(currentIdx, i, 1);
                windowsModel.set(i, t);
            } else {
                windowsModel.set(i, t);
            }
        }
    }

    // Pill background
    Rectangle {
        anchors.centerIn: parent
        width: dockContent.width + Theme.dockPadding * 4
        height: Theme.dockIconSize + Theme.dockPadding * 2
        radius: Theme.dockRadius
        color: Theme.panelBackground

        Behavior on width {
            NumberAnimation {
                duration: 200
                easing.type: Easing.OutCubic
            }
        }
    }

    ListView {
        id: dockContent
        anchors.centerIn: parent
        orientation: ListView.Horizontal
        width: contentWidth
        height: Theme.dockIconSize
        spacing: Theme.dockSpacing
        interactive: false

        model: windowsModel

        move: Transition {
            NumberAnimation {
                properties: "x"
                duration: 250
                easing.type: Easing.OutCubic
            }
        }
        moveDisplaced: Transition {
            NumberAnimation {
                properties: "x"
                duration: 250
                easing.type: Easing.OutCubic
            }
        }
        add: Transition {
            NumberAnimation {
                properties: "opacity"
                from: 0
                to: 1
                duration: 150
                easing.type: Easing.OutCubic
            }
        }
        addDisplaced: Transition {
            NumberAnimation {
                properties: "x"
                duration: 250
                easing.type: Easing.OutCubic
            }
        }
        remove: Transition {
            NumberAnimation {
                properties: "opacity"
                to: 0
                duration: 150
                easing.type: Easing.OutCubic
            }
        }
        removeDisplaced: Transition {
            NumberAnimation {
                properties: "x"
                duration: 250
                easing.type: Easing.OutCubic
            }
        }

        delegate: AppIcon {
            appId: model.appId // qmllint disable unqualified
            title: model.title // qmllint disable unqualified
            windowId: model.windowId // qmllint disable unqualified
            isFocused: model.isFocused // qmllint disable unqualified
            isRunning: true
            isPinned: false
        }
    }
}
