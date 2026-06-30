//@ pragma UseQApplication

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
}
