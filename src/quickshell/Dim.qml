import QtQuick
import Quickshell
import Quickshell.Wayland

Scope {
    id: dimScope

    property bool active: false
    property real opacity: 0.5
    property bool blockInput: false
    property int duration: 250
    property string namespace: "serpantinum-dim"

    signal clicked()

    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: dimWindow
            required property var modelData

            screen: modelData
            visible: dimRect.opacity > 0
            color: "transparent"

            anchors {
                top: true
                bottom: true
                left: true
                right: true
            }

            WlrLayershell.namespace: dimScope.namespace
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.exclusionMode: ExclusionMode.Ignore
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

            mask: dimScope.blockInput ? null : emptyMask

            Region {
                id: emptyMask
            }

            Rectangle {
                id: dimRect
                anchors.fill: parent
                color: "black"
                opacity: dimScope.active ? dimScope.opacity : 0.0

                Behavior on opacity {
                    NumberAnimation {
                        duration: dimScope.duration
                        easing.type: Easing.InOutQuad
                    }
                }
            }

            MouseArea {
                anchors.fill: parent
                enabled: dimScope.active && dimScope.blockInput
                hoverEnabled: dimScope.blockInput
                onClicked: dimScope.clicked()
            }
        }
    }
}
