pragma Singleton

import QtQuick

QtObject {
    // Colors
    readonly property color backgroundColor: "#c4a7e7"
    readonly property color foregroundColor: "#393552"
    readonly property color accentColor: "#393552"

    // Panel
    readonly property int panelHeight: 32
    readonly property color panelBackground: backgroundColor

    // Dock
    readonly property int dockHeight: 64
    readonly property int dockIconSize: 40
    readonly property int dockSpacing: 8
    readonly property int dockWidth: 256

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
