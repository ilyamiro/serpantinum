import QtQuick
import QtQuick.Window
import QtQuick.Effects
import "../"

Item {
    required property var root
    id: blurCrossfader
    anchors.fill: parent
    visible: ThemeBackend.elementOpacity >= 0.999
    property string blurUrl: root.activeArtUrl ? (root.activeArtUrl.startsWith("file://") || root.activeArtUrl.startsWith("http") ? root.activeArtUrl : "file://" + root.activeArtUrl) : ""
    property bool showingA: true
    property bool swapping: false

    Timer {
        id: swapEndTimer
        interval: 800
        onTriggered: blurCrossfader.swapping = false
    }

    Timer {
        id: swapTimer
        interval: 150
        onTriggered: {
            let incoming = blurCrossfader.showingA ? blurB : blurA;
            if (incoming.status === Image.Loading) swapTimer.restart();
            else if (incoming.status === Image.Ready) {
                blurCrossfader.swapping = true;
                blurCrossfader.showingA = !blurCrossfader.showingA;
                swapEndTimer.restart();
            }
        }
    }

    Item {
        anchors.fill: parent
        opacity: root.hasTargetPlayer ? 0.9 : 0.01
        layer.enabled: true
        Behavior on opacity { NumberAnimation { duration: 800; easing.type: Easing.InOutQuad } }

        Image {
            id: blurA
            anchors.fill: parent
            anchors.margins: -96
            fillMode: Image.PreserveAspectCrop
            visible: false
        }

        MultiEffect {
            anchors.fill: blurA
            source: blurA
            z: blurCrossfader.showingA ? 2 : 1
            autoPaddingEnabled: false
            blurEnabled: true
            blurMax: 64
            blur: 0.7
            opacity: blurA.status === Image.Ready && (blurCrossfader.showingA || blurCrossfader.swapping) ? 1.0 : 0.01
            Behavior on opacity { NumberAnimation { duration: 800; easing.type: Easing.InOutQuad } }
        }

        Image {
            id: blurB
            anchors.fill: parent
            anchors.margins: -96
            fillMode: Image.PreserveAspectCrop
            visible: false
        }

        MultiEffect {
            anchors.fill: blurB
            source: blurB
            z: !blurCrossfader.showingA ? 2 : 1
            autoPaddingEnabled: false
            blurEnabled: true
            blurMax: 64
            blur: 0.7
            opacity: blurB.status === Image.Ready && (!blurCrossfader.showingA || blurCrossfader.swapping) ? 1.0 : 0.01
            Behavior on opacity { NumberAnimation { duration: 800; easing.type: Easing.InOutQuad } }
        }
    }

    Rectangle {
        anchors.fill: parent
        opacity: (root.hasTargetPlayer && root.activeArtUrl) ? 1.0 : 0.0
        gradient: Gradient {
            GradientStop { position: 0.0; color: Qt.alpha(ThemeBackend.base, 0.62); Behavior on color { ColorAnimation { duration: 600 } } }
            GradientStop { position: 0.5; color: Qt.alpha(ThemeBackend.base, 0.77); Behavior on color { ColorAnimation { duration: 600 } } }
            GradientStop { position: 1.0; color: Qt.alpha(ThemeBackend.base, 0.92); Behavior on color { ColorAnimation { duration: 600 } } }
        }
        Behavior on opacity { NumberAnimation { duration: 800; easing.type: Easing.InOutQuad } }
    }

    onBlurUrlChanged: {
        if (!blurUrl) {
            swapTimer.stop();
            blurA.source = "";
            blurB.source = "";
            return;
        }
        if (showingA) blurB.source = blurUrl;
        else blurA.source = blurUrl;
        swapTimer.restart();
    }

    Component.onCompleted: {
        if (blurUrl) {
            blurA.source = blurUrl;
            showingA = true;
        }
    }
}
