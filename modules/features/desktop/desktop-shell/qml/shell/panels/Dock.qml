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
    implicitWidth: Theme.dockWidth
    exclusiveZone: 0
    color: Theme.panelBackground

    // Visibility controlled by overview state and focused monitor
    visible: OverviewMonitor.isOverviewActive && screenData.name === OverviewMonitor.focusedOutputName

    // Calculate unpinned apps once
    property var unpinnedRunningApps: {
        var unpinnedApps = [];
        for (var i = 0; i < OverviewMonitor.runningWindows.length; i++) {
            var window = OverviewMonitor.runningWindows[i];
            var appId = window.app_id || "";
            if (AppConfig.pinnedApps.indexOf(appId) === -1) {
                unpinnedApps.push(window);
            }
        }
        return unpinnedApps;
    }

    // Dock content
    Row {
        id: dockContent
        anchors {
            verticalCenter: parent.verticalCenter
            horizontalCenter: parent.horizontalCenter
        }
        spacing: Theme.dockSpacing

        // Running applications that are not pinned
        Repeater {
            id: runningAppsList
            model: dock.unpinnedRunningApps

            delegate: AppIcon {
                required property var modelData

                appId: modelData.app_id || ""
                title: modelData.title || ""
                isFocused: modelData.is_focused || false
                isRunning: true
                isPinned: false
            }
        }

        // Separator
        Rectangle {
            width: 1
            height: parent.height * 0.8
            anchors.verticalCenter: parent.verticalCenter
            color: Theme.foregroundColor
            opacity: 0.2
            visible: AppConfig.pinnedApps.length > 0 && dock.unpinnedRunningApps.length > 0
        }

        // Pinned applications
        Repeater {
            id: pinnedAppsList
            model: AppConfig.pinnedApps

            delegate: AppIcon {
                required property var modelData

                appId: modelData
                isPinned: true
                isRunning: {
                    // Check if this pinned app is in running windows
                    for (var i = 0; i < OverviewMonitor.runningWindows.length; i++) {
                        if (OverviewMonitor.runningWindows[i].app_id === modelData) {
                            return true;
                        }
                    }
                    return false;
                }
                isFocused: {
                    // Check if this pinned app is focused
                    for (var i = 0; i < OverviewMonitor.runningWindows.length; i++) {
                        var window = OverviewMonitor.runningWindows[i];
                        if (window.app_id === modelData && window.is_focused) {
                            return true;
                        }
                    }
                    return false;
                }
            }
        }
    }
}
