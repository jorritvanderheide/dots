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

    // Animate the surface width in sync with the pill so the Wayland surface
    // doesn't snap to the new size while the pill and icons are still easing
    // into it (which otherwise clips the rightmost icon on both grow and
    // shrink transitions).
    Behavior on implicitWidth {
        NumberAnimation {
            duration: 200
            easing.type: Easing.OutCubic
        }
    }

    exclusiveZone: 0
    color: "transparent"

    readonly property string targetMonitor: AppConfig.monitor !== "" ? AppConfig.monitor : NiriState.focusedOutputName
    readonly property bool shouldShow: NiriState.isOverviewActive && screenData.name === targetMonitor

    // Canonical ids of pinned apps ordered by most-recent close first. Drives
    // placement within the pinned section so the last-closed app sits leftmost
    // (next to running) and oldest closes drift to the right.
    property var closedPinHistory: []

    // Counts of each section, updated by _sync. Used to place the running↔pinned
    // divider and to decide whether to show it at all.
    property int runningCount: 0
    property int pinnedCount: 0

    // Slide-in from bottom: 0 = offscreen below, 1 = at rest.
    property real slideProgress: 0
    Behavior on slideProgress {
        NumberAnimation {
            duration: 250
            easing.type: Easing.OutCubic
        }
    }

    // Stay mapped while the exit animation plays.
    visible: shouldShow || slideProgress > 0.001

    onShouldShowChanged: slideProgress = shouldShow ? 1 : 0

    ListModel {
        id: windowsModel
    }

    Connections {
        target: NiriState
        function onWindowsChanged() {
            dock._sync();
        }
        function onWorkspacesChanged() {
            dock._sync();
        }
    }

    Connections {
        target: AppConfig
        function onPinnedAppsChanged() {
            dock._sync();
        }
    }

    Component.onCompleted: {
        slideProgress = shouldShow ? 1 : 0;
        _sync();
    }
    onVisibleChanged: if (visible)
        _sync()

    function _sync() {
        var windows = NiriState.windows;
        var workspaces = NiriState.workspaces;
        var rawPinned = AppConfig.pinnedApps || [];

        // Active workspace id for this dock's monitor. Used to filter windows
        // so the dock only shows what's on the currently visible workspace.
        // Falls back to "any workspace on this monitor" if no active workspace
        // is marked yet (e.g. before niri's first WorkspaceActivated event).
        var activeWorkspaceId = -1;
        var monitorWorkspaceIds = {};
        for (var wi = 0; wi < workspaces.length; wi++) {
            var ws = workspaces[wi];
            if (ws.output !== dock.screenData.name)
                continue;
            monitorWorkspaceIds[ws.id] = true;
            if (ws.is_active && activeWorkspaceId === -1)
                activeWorkspaceId = ws.id;
        }

        // Quickshell's heuristicLookup only checks id + StartupWMClass, so we
        // also scan DesktopEntries.applications for matches by Name and by
        // the exec binary name. This catches pins like "zed" (Name=Zed but
        // id=dev.zed.Zed) and "signal-desktop" (id match only).
        var allApps = DesktopEntries.applications || [];

        function execBinary(entry) {
            if (!entry || !entry.command || !entry.command.length)
                return "";
            var bin = entry.command[0] || "";
            var slash = bin.lastIndexOf("/");
            if (slash !== -1)
                bin = bin.substring(slash + 1);
            return bin.toLowerCase();
        }

        function entryAliases(entry, fallback) {
            var aliases = fallback ? [fallback] : [];
            if (entry) {
                if (entry.id)
                    aliases.push(entry.id.toLowerCase());
                if (entry.name)
                    aliases.push(entry.name.toLowerCase());
                if (entry.startupClass)
                    aliases.push(entry.startupClass.toLowerCase());
                var bin = execBinary(entry);
                if (bin)
                    aliases.push(bin);
            }
            // Dedup
            var uniq = {};
            var out = [];
            for (var j = 0; j < aliases.length; j++) {
                if (!uniq[aliases[j]]) {
                    uniq[aliases[j]] = true;
                    out.push(aliases[j]);
                }
            }
            return out;
        }

        function findEntry(query) {
            var lower = (query || "").toLowerCase();
            if (!lower)
                return null;
            var e = DesktopEntries.heuristicLookup(lower);
            if (e)
                return e;
            for (var i = 0; i < allApps.length; i++) {
                var a = allApps[i];
                if (!a)
                    continue;
                if (a.id && a.id.toLowerCase() === lower)
                    return a;
                if (a.name && a.name.toLowerCase() === lower)
                    return a;
                if (a.startupClass && a.startupClass.toLowerCase() === lower)
                    return a;
                if (execBinary(a) === lower)
                    return a;
                // Strip "-desktop" suffix when the user pins the bare name
                if (a.id) {
                    var aLower = a.id.toLowerCase();
                    if (aLower.length > 8 && aLower.substring(aLower.length - 8) === "-desktop" && aLower.substring(0, aLower.length - 8) === lower)
                        return a;
                }
            }
            return null;
        }

        function resolvePin(pinDef) {
            // pinDef is either a raw string (bare pin) or { id, aliases }
            var id = typeof pinDef === "string" ? pinDef : (pinDef.id || "");
            var extraAliases = (typeof pinDef === "object" && pinDef.aliases) ? pinDef.aliases : [];
            var lower = id.toLowerCase();
            var entry = findEntry(id);
            var aliases = entryAliases(entry, lower);
            for (var ei = 0; ei < extraAliases.length; ei++) {
                var a = (extraAliases[ei] || "").toLowerCase();
                if (a && aliases.indexOf(a) === -1)
                    aliases.push(a);
            }
            return {
                canonicalId: entry && entry.id ? entry.id.toLowerCase() : lower,
                entry: entry,
                aliases: aliases
            };
        }

        var pinInfos = [];
        for (var pi = 0; pi < rawPinned.length; pi++) {
            pinInfos.push(resolvePin(rawPinned[pi]));
        }

        function matchPinIndex(winAppId) {
            var lower = (winAppId || "").toLowerCase();
            for (var pi = 0; pi < pinInfos.length; pi++) {
                if (pinInfos[pi].aliases.indexOf(lower) !== -1)
                    return pi;
            }
            // Second chance: resolve the window's entry and compare alias sets
            var winEntry = findEntry(winAppId);
            if (winEntry) {
                var winAliases = entryAliases(winEntry, lower);
                for (var pi2 = 0; pi2 < pinInfos.length; pi2++) {
                    var pa = pinInfos[pi2].aliases;
                    for (var k = 0; k < pa.length; k++) {
                        if (winAliases.indexOf(pa[k]) !== -1)
                            return pi2;
                    }
                }
            }
            return -1;
        }

        function fallbackCanonical(winAppId) {
            var lower = (winAppId || "").toLowerCase();
            var entry = findEntry(winAppId);
            return entry && entry.id ? entry.id.toLowerCase() : lower;
        }

        // Running windows on THIS screen, sorted by column position.
        var running = [];
        var runningPinIndexes = {};
        for (var i = 0; i < windows.length; i++) {
            var win = windows[i];
            if (!win.app_id)
                continue;
            if (activeWorkspaceId !== -1) {
                if (win.workspace_id !== activeWorkspaceId)
                    continue;
            } else {
                // No active workspace detected yet: fall back to showing
                // anything on this monitor so the dock isn't silently empty.
                if (!monitorWorkspaceIds[win.workspace_id])
                    continue;
            }

            var col = 999;
            if (win.layout && win.layout.pos_in_scrolling_layout)
                col = win.layout.pos_in_scrolling_layout[0];

            var pinIdx = matchPinIndex(win.app_id);
            var canonicalId = pinIdx !== -1 ? pinInfos[pinIdx].canonicalId : fallbackCanonical(win.app_id);

            running.push({
                windowId: win.id,
                appId: canonicalId,
                title: win.title || "",
                isFocused: win.is_focused || false,
                isRunning: true,
                isPinned: pinIdx !== -1,
                col: col
            });
            if (pinIdx !== -1)
                runningPinIndexes[pinIdx] = true;
        }
        running.sort(function (a, b) {
            return a.col - b.col;
        });

        // Detect pinned windows that genuinely closed (not just moved off the
        // active workspace) so we can push them to the leftmost position of
        // the pinned section. Use NiriState.windows (global across workspaces)
        // to distinguish "closed" from "still alive elsewhere".
        var aliveWindowIds = {};
        for (var aw = 0; aw < windows.length; aw++) {
            aliveWindowIds[windows[aw].id] = true;
        }
        for (var ck = 0; ck < windowsModel.count; ck++) {
            var ckItem = windowsModel.get(ck);
            if (ckItem.windowId < 0 || !ckItem.isPinned)
                continue;
            if (aliveWindowIds[ckItem.windowId])
                continue;
            var prev = dock.closedPinHistory.indexOf(ckItem.appId);
            if (prev !== -1)
                dock.closedPinHistory.splice(prev, 1);
            dock.closedPinHistory.unshift(ckItem.appId);
        }

        // Pinned apps with no running window become static placeholders.
        // Order: recently closed (leftmost, by closedPinHistory), then any
        // configured pins that haven't been opened yet in their config order.
        var pinned = [];
        var pinnedByCid = {};
        for (var pi3 = 0; pi3 < pinInfos.length; pi3++) {
            pinnedByCid[pinInfos[pi3].canonicalId] = pi3;
        }
        var seenPinIdx = {};

        for (var h = 0; h < dock.closedPinHistory.length; h++) {
            var hcid = dock.closedPinHistory[h];
            var hpi = pinnedByCid[hcid];
            if (hpi === undefined)
                continue;
            if (runningPinIndexes[hpi])
                continue;
            seenPinIdx[hpi] = true;
            pinned.push({
                windowId: -(hpi + 1),
                appId: pinInfos[hpi].canonicalId,
                title: "",
                isFocused: false,
                isRunning: false,
                isPinned: true,
                col: -1
            });
        }

        for (var pi2 = 0; pi2 < pinInfos.length; pi2++) {
            if (runningPinIndexes[pi2])
                continue;
            if (seenPinIdx[pi2])
                continue;
            pinned.push({
                windowId: -(pi2 + 1),
                appId: pinInfos[pi2].canonicalId,
                title: "",
                isFocused: false,
                isRunning: false,
                isPinned: true,
                col: -1
            });
        }

        // Running windows first (column order), pinned placeholders on the right.
        var target = running.concat(pinned);
        dock.runningCount = running.length;
        dock.pinnedCount = pinned.length;

        // Pre-pass: relabel existing model entries so launching/closing a
        // pinned app reuses the same delegate, letting ListView animate the
        // move instead of fading an entry out and a new one back in.
        //
        // A pin has at most ONE placeholder slot (windowId = -(pi+1)), so if
        // the model contains N former-running entries for the same pin (e.g.
        // two windows of a pinned app after a workspace switch), only one
        // gets relabeled to the placeholder. The rest keep their positive
        // windowIds and get cleaned up by the remove phase below, since those
        // ids aren't in `target`.
        var demotedPlaceholder = {};
        for (var k = 0; k < windowsModel.count; k++) {
            var item = windowsModel.get(k);
            if (item.windowId < 0) {
                // Pinned placeholder: promote to running if the app launched
                for (var r = 0; r < running.length; r++) {
                    if (running[r].appId === item.appId) {
                        windowsModel.setProperty(k, "windowId", running[r].windowId);
                        windowsModel.setProperty(k, "isRunning", true);
                        windowsModel.setProperty(k, "isFocused", running[r].isFocused);
                        windowsModel.setProperty(k, "title", running[r].title);
                        windowsModel.setProperty(k, "col", running[r].col);
                        break;
                    }
                }
            } else {
                // Running window: demote to pinned placeholder if it closed
                var stillRunning = false;
                for (var r = 0; r < running.length; r++) {
                    if (running[r].windowId === item.windowId) {
                        stillRunning = true;
                        break;
                    }
                }
                if (!stillRunning && !demotedPlaceholder[item.appId]) {
                    for (var p = 0; p < pinned.length; p++) {
                        if (pinned[p].appId === item.appId) {
                            windowsModel.setProperty(k, "windowId", pinned[p].windowId);
                            windowsModel.setProperty(k, "isRunning", false);
                            windowsModel.setProperty(k, "isFocused", false);
                            windowsModel.setProperty(k, "title", "");
                            windowsModel.setProperty(k, "col", -1);
                            demotedPlaceholder[item.appId] = true;
                            break;
                        }
                    }
                }
            }
        }

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

    // Content wrapper that slides vertically. Layer-shell clips to the panel
    // surface bounds, so translating the wrapper past the bottom edge hides it.
    Item {
        id: slidingContent
        width: parent.width
        height: parent.height
        y: parent.height * (1 - dock.slideProgress)

        // Pill background. `clip: true` prevents delegates that haven't been
        // caught up to yet (during the resize animation) from rendering past
        // the pill edge. ListView + divider live INSIDE the pill so they're
        // bounded by its width.
        Rectangle {
            id: pill
            anchors.centerIn: parent
            width: dockContent.width + Theme.dockPadding * 4
            height: Theme.dockIconSize + Theme.dockPadding * 2
            radius: Theme.dockRadius
            color: Theme.panelBackground
            clip: true

            Behavior on width {
                NumberAnimation {
                    duration: 200
                    easing.type: Easing.OutCubic
                }
            }

            // Subtle separator between running and pinned sections.
            Rectangle {
                visible: dock.runningCount > 0 && dock.pinnedCount > 0
                width: 1
                height: Theme.dockIconSize * 0.6
                color: Theme.foregroundColor
                opacity: 0.15
                y: dockContent.y + (dockContent.height - height) / 2
                x: dockContent.x + dock.runningCount * (Theme.dockIconSize + Theme.dockSpacing) - Theme.dockSpacing / 4 - width / 2

                Behavior on x {
                    NumberAnimation {
                        duration: 250
                        easing.type: Easing.OutCubic
                    }
                }
                Behavior on opacity {
                    NumberAnimation {
                        duration: 150
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

                delegate: Item {
                    // Widen the first pinned delegate so there's extra breathing
                    // room for the divider (spacing/4 on each side of it).
                    readonly property int leftPad: (index === dock.runningCount && dock.runningCount > 0) ? Theme.dockSpacing / 2 : 0
                    width: Theme.dockIconSize + leftPad
                    height: Theme.dockIconSize

                    AppIcon {
                        x: parent.leftPad
                        width: Theme.dockIconSize
                        height: Theme.dockIconSize
                        appId: model.appId // qmllint disable unqualified
                        title: model.title // qmllint disable unqualified
                        windowId: model.windowId // qmllint disable unqualified
                        isFocused: model.isFocused // qmllint disable unqualified
                        isRunning: model.isRunning // qmllint disable unqualified
                        isPinned: model.isPinned // qmllint disable unqualified
                    }
                }
            }
        }
    }
}
