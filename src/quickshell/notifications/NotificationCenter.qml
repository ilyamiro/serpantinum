import QtQuick
import QtQuick.Window
import QtQuick.Effects
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import "../"
import "../reusables"

HostedPanel {
    id: root

    property real introContent: 0.0

    onVisibleChanged: {
        if (visible) {
            startupSequence.restart();
            root.scheduleFocus();
        } else {
            root.stopFocusTimer();
            startupSequence.stop();
            closeSequence.stop();
        }
    }

    Component.onCompleted: {
        if (visible) {
            startupSequence.start();
            root.scheduleFocus();
        }
    }

    function startExit(onFinished) {
        startupSequence.stop();
        exitCallback = onFinished;
        closeSequence.restart();
    }

    SequentialAnimation {
        id: startupSequence
        NumberAnimation {
            target: root
            property: "introContent"
            to: 1.0
            duration: 400
            easing.type: Easing.OutQuart
        }
    }

    SequentialAnimation {
        id: closeSequence
        ParallelAnimation {
            NumberAnimation {
                target: root
                property: "introContent"
                to: 0.0
                duration: 250
                easing.type: Easing.InQuart
            }
        }
        ScriptAction {
            script: root.finishExit()
        }
    }

    Rectangle {
        id: sidebarPanel
        anchors.fill: parent
        color: ThemeBackend.faded(ThemeBackend.base)
        radius: ThemeBackend.borderRadius
        clip: true
        opacity: root.introContent

        Rectangle {
            anchors.left: parent.left; anchors.top: parent.top; anchors.bottom: parent.bottom; width: root.s(16)
            color: sidebarPanel.color
        }

        Item {
            anchors.fill: parent
            opacity: introContent
            scale: 0.96 + (0.04 * introContent)
            transform: Translate { y: root.s(40) * (1.0 - introContent) }

            Reserved {
                anchors.centerIn: parent
                imageSize: root.s(220)
                textSize: root.s(15)
            }
        }
    }
}
