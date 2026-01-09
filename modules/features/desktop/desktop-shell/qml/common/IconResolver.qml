pragma Singleton

import QtQuick

QtObject {
    id: iconResolver

    // Convert app_id to icon name
    // Most apps follow the convention: app_id matches icon name
    function getIconName(appId) {
        if (!appId)
            return "";

        // Handle common mappings
        var mappings = {
            "org.gnome.Nautilus": "org.gnome.Nautilus",
            "code": "com.visualstudio.code",
            "zen-beta": "zen-browser",
            "ghostty": "utilities-terminal"
        };

        return mappings[appId] || appId;
    }

    // Get first letter fallback for text display
    function getFirstLetter(appId) {
        if (appId && appId.length > 0) {
            return appId.charAt(0).toUpperCase();
        }
        return "?";
    }
}
