// NOTE: this file is the dev-mode fallback used when running quickshell
// directly against the source tree (`qs -c .../qml/`). At NixOS build time,
// desktop-shell.nix replaces this with a version that bakes in the real
// monitor value from `my.desktop-shell.monitor`. The QS_DOCK_MONITOR env var
// still overrides, which is handy when launching against the source tree.

pragma Singleton

import QtQuick
import Quickshell

QtObject {
    readonly property string monitor: Quickshell.env("QS_DOCK_MONITOR") || ""
}
