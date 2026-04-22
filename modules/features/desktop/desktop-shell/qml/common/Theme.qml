// NOTE: color properties are overwritten at Nix build time with the active
// Stylix palette (see default.nix). The defaults below only apply when running
// quickshell against this source tree for live QML iteration.

pragma Singleton

import QtQuick

QtObject {
    // Colors — source-tree fallback matching the active Stylix palette
    // (gruvbox-material-dark-medium base01/base05/base0D). Overwritten at
    // Nix build time with config.lib.stylix.colors.
    readonly property color backgroundColor: "#32302f"
    readonly property color foregroundColor: "#ddc7a1"
    readonly property color accentColor: "#7daea3"

    // Shared
    readonly property color panelBackground: backgroundColor

    // Dock
    readonly property int dockHeight: 56
    readonly property int dockIconSize: 40
    readonly property int dockSpacing: 6
    readonly property int dockPadding: 6
    readonly property int dockRadius: 16

    // Top bar
    readonly property int topBarHeight: 32
    readonly property int topBarPadding: 8
    readonly property int topBarSpacing: 16
    readonly property int topBarIconSize: 16
    readonly property int topBarSideMargin: 16

    // Typography
    readonly property int fontSizeSmall: 12
    readonly property int fontSizeNormal: 14
    readonly property int fontSizeLarge: 16
    readonly property int fontSizeIcon: 20

    // Spacing
    readonly property int spacingTiny: 5
    readonly property int spacingSmall: 10
    readonly property int spacingMedium: 15
    readonly property int spacingLarge: 20

    // Padding
    readonly property int paddingSmall: 8
    readonly property int paddingMedium: 12
    readonly property int paddingLarge: 16
}
