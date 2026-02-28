import Quickshell

import "shell/panels"

ShellRoot {
    Variants {
        model: Quickshell.screens

        Dock {
            property var modelData
            screenData: modelData
        }
    }
}
