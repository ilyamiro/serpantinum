import QtQuick
import QtQuick.Window
import QtQuick.Effects
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import "../"
import "../reusables"

Item {
    id: root
    visible: false
    focus: true

    function s(val) { 
        return Scaler.s(val); 
    }

    property real introContent: 0.0

    Timer {
        id: focusTimer
        interval: 50
        running: false
        repeat: false
        onTriggered: root.forceActiveFocus()
    }

    onVisibleChanged: {
        if (visible) {
            startupSequence.restart();
            focusTimer.restart();
        } else {
            startupSequence.stop();
            closeSequence.stop();
        }
    }

    Component.onCompleted: {
        if (visible) {
            startupSequence.start();
            focusTimer.start();
        }
    }

    property var exitCallback: null

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
                duration: 240
                easing.type: Easing.InQuart
            }
        }
        ScriptAction { 
            script: {
                if (root.exitCallback) {
                    let cb = root.exitCallback;
                    root.exitCallback = null;
                    cb();
                } else {
                    Quickshell.execDetached(["bash", Caching.serpantinumDir + "/scripts/qs_manager.sh", "close"]);
                }
            } 
        }    
    }

    Keys.onEscapePressed: (event) => {
        if (typeof masterWindow !== "undefined" && masterWindow.switchWidget) {
            masterWindow.switchWidget("hidden", "");
        } else {
            closeSequence.restart();
        }
        event.accepted = true;
    }

    Rectangle {
        id: sidebarPanel
        anchors.fill: parent
        color: ThemeBackend.faded(ThemeBackend.base)
        radius: ThemeBackend.borderRadius
        border.width: 1
        border.color: Qt.rgba(ThemeBackend.surface1.r, ThemeBackend.surface1.g, ThemeBackend.surface1.b, 0.9)
        clip: true
        opacity: root.introContent

        Rectangle {
            anchors.left: parent.left; anchors.top: parent.top; anchors.bottom: parent.bottom; width: root.s(16)
            color: sidebarPanel.color
            Rectangle { anchors.top: parent.top; width: parent.width; height: 1; color: sidebarPanel.border.color }
            Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 1; color: sidebarPanel.border.color }
            Rectangle { anchors.left: parent.left; width: 1; height: parent.height; color: sidebarPanel.border.color }
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
