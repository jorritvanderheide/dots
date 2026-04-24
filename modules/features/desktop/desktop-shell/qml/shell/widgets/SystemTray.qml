import QtQuick
import Quickshell
import Quickshell.Services.SystemTray

import "../../common"

Row {
    id: tray

    spacing: Theme.topBarSpacing

    Repeater {
        model: SystemTray.items

        delegate: Item {
            id: itemRoot
            required property SystemTrayItem modelData

            width: Theme.topBarIconSize
            height: Theme.topBarIconSize
            anchors.verticalCenter: parent.verticalCenter

            Image {
                id: iconImage
                anchors.fill: parent
                source: itemRoot.modelData.icon
                sourceSize: Qt.size(width, height)
                fillMode: Image.PreserveAspectFit
                smooth: true
            }

            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor

                onClicked: mouse => {
                    if (mouse.button === Qt.LeftButton) {
                        if (itemRoot.modelData.onlyMenu && itemRoot.modelData.hasMenu)
                            itemRoot.modelData.display(itemRoot.QsWindow.window, itemRoot.x + itemRoot.width / 2, itemRoot.y + itemRoot.height);
                        else
                            itemRoot.modelData.activate();
                    } else if (mouse.button === Qt.MiddleButton) {
                        itemRoot.modelData.secondaryActivate();
                    } else if (mouse.button === Qt.RightButton) {
                        console.log("tray right-click:", itemRoot.modelData.id, "hasMenu=", itemRoot.modelData.hasMenu);
                        if (itemRoot.modelData.hasMenu)
                            itemRoot.modelData.display(itemRoot.QsWindow.window, itemRoot.x + itemRoot.width / 2, itemRoot.y + itemRoot.height);
                    }
                }

                onWheel: wheel => {
                    const dx = wheel.angleDelta.x;
                    const dy = wheel.angleDelta.y;
                    if (dy !== 0)
                        itemRoot.modelData.scroll(dy, false);
                    if (dx !== 0)
                        itemRoot.modelData.scroll(dx, true);
                }
            }

            QsMenuAnchor {
                id: menuAnchor
                menu: itemRoot.modelData.menu
                anchor.item: itemRoot
                anchor.edges: Edges.Bottom
                anchor.gravity: Edges.Bottom
            }
        }
    }
}
