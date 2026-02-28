pragma Singleton

import QtQuick
import Quickshell.Io

QtObject {
    id: niriState

    property bool isOverviewActive: false
    property var windows: []
    property var workspaces: []
    property string focusedOutputName: ""

    signal workspaceSwitched(int direction)

    function windowsOnWorkspace(workspaceId) {
        var result = [];
        for (var i = 0; i < windows.length; i++) {
            if (windows[i].workspace_id === workspaceId) {
                result.push(windows[i]);
            }
        }
        return result;
    }

    function _activeWorkspaceIdxForOutput(output, wsList) {
        for (var i = 0; i < wsList.length; i++) {
            if (wsList[i].output === output && wsList[i].is_active) {
                return wsList[i].idx;
            }
        }
        return -1;
    }

    function _updateFocusedOutput() {
        for (var i = 0; i < workspaces.length; i++) {
            if (workspaces[i].is_focused) {
                focusedOutputName = workspaces[i].output || "";
                return;
            }
        }
    }

    property Process eventStream: Process {
        command: ["niri", "msg", "--json", "event-stream"]
        running: true

        stdout: SplitParser {
            onRead: data => {
                try {
                    var event = JSON.parse(data);

                    if (event.WorkspacesChanged) {
                        // Full state dump (initial + structural changes)
                        var newWorkspaces = event.WorkspacesChanged.workspaces || [];
                        var oldWorkspaces = niriState.workspaces;

                        niriState.workspaces = newWorkspaces;
                        niriState._updateFocusedOutput();

                        var output = niriState.focusedOutputName;
                        var oldIdx = niriState._activeWorkspaceIdxForOutput(output, oldWorkspaces);
                        var newIdx = niriState._activeWorkspaceIdxForOutput(output, newWorkspaces);

                        if (oldIdx !== -1 && newIdx !== -1 && oldIdx !== newIdx) {
                            niriState.workspaceSwitched(newIdx > oldIdx ? 1 : -1);
                        }

                    } else if (event.WorkspaceActivated) {
                        // Incremental: a workspace was switched to
                        var activated = event.WorkspaceActivated;
                        var oldWs = niriState.workspaces;

                        // Find the output this workspace belongs to
                        var targetOutput = "";
                        for (var i = 0; i < oldWs.length; i++) {
                            if (oldWs[i].id === activated.id) {
                                targetOutput = oldWs[i].output || "";
                                break;
                            }
                        }

                        var oldIdx = niriState._activeWorkspaceIdxForOutput(targetOutput, oldWs);

                        // Build updated workspaces with new active/focused flags
                        var updated = [];
                        for (var i = 0; i < oldWs.length; i++) {
                            var ws = {};
                            for (var k in oldWs[i]) ws[k] = oldWs[i][k];
                            if (ws.output === targetOutput)
                                ws.is_active = (ws.id === activated.id);
                            if (activated.focused)
                                ws.is_focused = (ws.id === activated.id);
                            updated.push(ws);
                        }

                        niriState.workspaces = updated;
                        niriState._updateFocusedOutput();

                        var newIdx = niriState._activeWorkspaceIdxForOutput(targetOutput, updated);
                        if (oldIdx !== -1 && newIdx !== -1 && oldIdx !== newIdx) {
                            niriState.workspaceSwitched(newIdx > oldIdx ? 1 : -1);
                        }

                    } else if (event.WindowsChanged) {
                        // Full state dump (initial)
                        niriState.windows = event.WindowsChanged.windows || [];

                    } else if (event.WindowOpenedOrChanged) {
                        // Incremental: window added or properties changed
                        var changed = event.WindowOpenedOrChanged.window;
                        var wins = niriState.windows.slice();
                        var found = false;
                        for (var i = 0; i < wins.length; i++) {
                            if (wins[i].id === changed.id) {
                                wins[i] = changed;
                                found = true;
                                break;
                            }
                        }
                        if (!found) wins.push(changed);
                        niriState.windows = wins;

                    } else if (event.WindowClosed) {
                        // Incremental: window removed
                        var closedId = event.WindowClosed.id;
                        var wins = [];
                        for (var i = 0; i < niriState.windows.length; i++) {
                            if (niriState.windows[i].id !== closedId)
                                wins.push(niriState.windows[i]);
                        }
                        niriState.windows = wins;

                    } else if (event.WindowLayoutsChanged) {
                        // Incremental: window positions/sizes changed (column moves)
                        var changes = event.WindowLayoutsChanged.changes || [];
                        var wins = niriState.windows.slice();
                        for (var c = 0; c < changes.length; c++) {
                            var wid = changes[c][0];
                            var newLayout = changes[c][1];
                            for (var i = 0; i < wins.length; i++) {
                                if (wins[i].id === wid) {
                                    var w = {};
                                    for (var k in wins[i]) w[k] = wins[i][k];
                                    w.layout = newLayout;
                                    wins[i] = w;
                                    break;
                                }
                            }
                        }
                        niriState.windows = wins;

                    } else if (event.WindowFocusChanged) {
                        // Incremental: focus moved to different window
                        var focusedId = event.WindowFocusChanged.id;
                        var wins = niriState.windows.slice();
                        for (var i = 0; i < wins.length; i++) {
                            var w = {};
                            for (var k in wins[i]) w[k] = wins[i][k];
                            w.is_focused = (w.id === focusedId);
                            wins[i] = w;
                        }
                        niriState.windows = wins;

                    } else if (event.OverviewOpenedOrClosed) {
                        niriState.isOverviewActive = event.OverviewOpenedOrClosed.is_open || false;
                    }
                } catch (e) {
                    console.error("NiriState: Failed to parse event:", e);
                }
            }
        }

        onRunningChanged: {
            if (!running) {
                console.warn("NiriState: event-stream exited - restarting");
                niriState.restartTimer.running = true;
            }
        }
    }

    property Timer restartTimer: Timer {
        interval: 1000
        onTriggered: niriState.eventStream.running = true
    }
}
