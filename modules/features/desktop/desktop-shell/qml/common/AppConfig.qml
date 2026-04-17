// NOTE: monitor and pinned apps are driven by the env vars QS_DOCK_MONITOR
// and QS_DOCK_PINS. The quickshell systemd user unit exports these from the
// NixOS options my.desktop-shell.{monitor,pinnedApps}. For direct dev
// launches against this source tree, prefix the command:
//
//   QS_DOCK_PINS='["zen-beta","zed","obsidian","signal-desktop"]' \
//   QS_DOCK_MONITOR=DP-1 \
//   quickshell -c /etc/nixos/modules/features/desktop/desktop-shell/qml

pragma Singleton

import QtQuick
import Quickshell

QtObject {
    readonly property string monitor: Quickshell.env("QS_DOCK_MONITOR") || ""

    readonly property var pinnedApps: {
        var raw = Quickshell.env("QS_DOCK_PINS");
        if (!raw)
            return [];
        try {
            return JSON.parse(raw);
        } catch (e) {
            console.warn("AppConfig: QS_DOCK_PINS is not valid JSON:", raw);
            return [];
        }
    }
}
