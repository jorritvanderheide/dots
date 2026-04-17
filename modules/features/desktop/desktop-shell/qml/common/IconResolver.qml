pragma Singleton

import QtQuick
import Quickshell

QtObject {
    id: iconResolver

    // Resolve app_id to an icon theme name. Go through the installed desktop
    // entry so apps whose window app_id differs from their icon name (e.g.
    // signal → signal-desktop, Code → com.visualstudio.code) still resolve.
    function getIconName(appId) {
        if (!appId)
            return "";

        var entry = DesktopEntries.heuristicLookup(appId.toLowerCase());
        if (entry && entry.icon)
            return entry.icon;

        return appId;
    }

    // Get first letter fallback for text display
    function getFirstLetter(appId) {
        if (appId && appId.length > 0) {
            return appId.charAt(0).toUpperCase();
        }
        return "?";
    }
}
