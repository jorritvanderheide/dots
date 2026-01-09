import Quickshell

import "shell/panels"

ShellRoot {
    Variants {
        model: Quickshell.screens

        TopBar {
            property var modelData
            screenData: modelData
        }
    }

    Variants {
        model: Quickshell.screens

        Dock {
            property var modelData
            screenData: modelData
        }
    }
}
