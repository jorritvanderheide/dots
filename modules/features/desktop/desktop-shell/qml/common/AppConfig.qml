// NOTE: this file is the dev-mode fallback used when running quickshell
// directly against the source tree (`qs -c .../qml/`). At NixOS build time,
// desktop-shell.nix replaces this with a version that bakes in the real
// monitor + pinnedApps values from `my.desktop-shell.*`. Env vars
// QS_DOCK_MONITOR / QS_DOCK_PINS still override, which is handy for trying
// different pin sets without rebuilding.

pragma Singleton

import QtQuick
import Quickshell

QtObject {
    readonly property string monitor: Quickshell.env("QS_DOCK_MONITOR") || ""

    readonly property var pinnedApps: {
        var raw = Quickshell.env("QS_DOCK_PINS");
        if (raw) {
            try {
                return JSON.parse(raw);
            } catch (e) {
                console.warn("AppConfig: QS_DOCK_PINS is not valid JSON:", raw);
            }
        }
        // Fallback mirrors modules/hosts/rocinante/configuration.nix so the
        // source-tree launch looks like the built one.
        return ["zen-beta", "zed",
            {
                "id": "obsidian",
                "aliases": ["electron"]
            },
            "signal"];
    }
}
