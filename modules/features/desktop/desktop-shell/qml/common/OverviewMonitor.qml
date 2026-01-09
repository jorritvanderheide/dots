pragma Singleton

import QtQuick
import Quickshell.Io

QtObject {
    id: overviewMonitor

    property bool isOverviewActive: false
    property var runningWindows: []
    property string focusedOutputName: ""

    // Poll timer - 150ms for responsive UI
    property Timer pollTimer: Timer {
        interval: 150
        running: true
        repeat: true
        onTriggered: {
            overviewMonitor.overviewStateProcess.running = true;
            overviewMonitor.windowsProcess.running = true;
            overviewMonitor.focusedOutputProcess.running = true;
        }
    }

    // Process to check overview state
    property Process overviewStateProcess: Process {
        command: ["niri", "msg", "--json", "overview-state"]
        running: false

        stdout: SplitParser {
            onRead: data => {
                try {
                    var result = JSON.parse(data);
                    overviewMonitor.isOverviewActive = result.is_open || false;
                } catch (e) {
                    console.error("OverviewMonitor: Failed to parse overview state:", e);
                }
            }
        }
    }

    // Process to get running windows
    property Process windowsProcess: Process {
        command: ["niri", "msg", "--json", "windows"]
        running: false

        stdout: SplitParser {
            onRead: data => {
                try {
                    overviewMonitor.runningWindows = JSON.parse(data) || [];
                } catch (e) {
                    console.error("OverviewMonitor: Failed to parse windows:", e);
                    overviewMonitor.runningWindows = [];
                }
            }
        }
    }

    // Process to get focused output
    property Process focusedOutputProcess: Process {
        command: ["niri", "msg", "--json", "focused-output"]
        running: false

        stdout: SplitParser {
            onRead: data => {
                try {
                    var result = JSON.parse(data);
                    overviewMonitor.focusedOutputName = result.name || "";
                } catch (e) {
                    console.error("OverviewMonitor: Failed to parse focused output:", e);
                }
            }
        }
    }
}
