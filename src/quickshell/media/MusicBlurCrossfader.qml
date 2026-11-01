import QtQuick
import QtQuick.Window
import "../"

Item {
    required property var root
    id: blurCrossfader
    anchors.fill: parent
    visible: ThemeBackend.elementOpacity >= 0.999
    property string blurUrl: root.activeBlur ? (root.activeBlur.startsWith("file://") || root.activeBlur.startsWith("http") ? root.activeBlur : "file://" + root.activeBlur) : ""
    property bool showingA: true

    Image {
        id: blurA
        anchors.fill: parent
        fillMode: Image.PreserveAspectCrop
        opacity: blurCrossfader.showingA && status === Image.Ready && root.hasTargetPlayer ? 0.9 : 0.0
        Behavior on opacity { NumberAnimation { duration: 800; easing.type: Easing.InOutQuad } }
    }

    Image {
        id: blurB
        anchors.fill: parent
        fillMode: Image.PreserveAspectCrop
        opacity: !blurCrossfader.showingA && status === Image.Ready && root.hasTargetPlayer ? 0.9 : 0.0
        Behavior on opacity { NumberAnimation { duration: 800; easing.type: Easing.InOutQuad } }
    }

    Rectangle {
        anchors.fill: parent
        opacity: (root.hasTargetPlayer && root.activeBlur) ? 1.0 : 0.0
        gradient: Gradient {
            GradientStop { position: 0.0; color: Qt.alpha(ThemeBackend.base, 0.55); Behavior on color { ColorAnimation { duration: 600 } } }
            GradientStop { position: 0.5; color: Qt.alpha(ThemeBackend.base, 0.72); Behavior on color { ColorAnimation { duration: 600 } } }
            GradientStop { position: 1.0; color: Qt.alpha(ThemeBackend.base, 0.90); Behavior on color { ColorAnimation { duration: 600 } } }
        }
        Behavior on opacity { NumberAnimation { duration: 800; easing.type: Easing.InOutQuad } }
    }

    onBlurUrlChanged: {
        if (!blurUrl) {
            blurA.source = "";
            blurB.source = "";
            return;
        }
        if (showingA) {
            blurB.source = blurUrl;
            showingA = false;
        } else {
            blurA.source = blurUrl;
            showingA = true;
        }
    }

    Component.onCompleted: {
        if (blurUrl) {
            blurA.source = blurUrl;
            showingA = true;
        }
    }
}
