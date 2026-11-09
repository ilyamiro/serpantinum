import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import "../../"

Rectangle {
    id: avatarPreviewRect
    required property var tab
    readonly property var rootObj: tab.rootObj

    Layout.preferredWidth: rootObj.s(72)
    Layout.preferredHeight: rootObj.s(72)
    radius: ThemeBackend.borderRadius
    color: ThemeBackend.surface0

    Loader {
        anchors.fill: parent
        active: avatarPreviewRect.tab.currentAvatarSourcePath === ""
        sourceComponent: Canvas {
            id: personaCanvas
            renderTarget: Canvas.FramebufferObject
            renderStrategy: Canvas.Immediate

            Connections {
                target: ThemeBackend
                function onSurface2Changed() { personaCanvas.requestPaint(); }
                function onSubtext0Changed() { personaCanvas.requestPaint(); }
                function onTextChanged() { personaCanvas.requestPaint(); }
            }

            onPaint: {
                var ctx = getContext("2d");
                ctx.clearRect(0, 0, width, height);

                var cx = width / 2;
                var headRadius = width * 0.19;
                var headCenterY = height * 0.36;

                ctx.fillStyle = ThemeBackend.surface2;

                ctx.beginPath();
                ctx.arc(cx, headCenterY, headRadius, 0, Math.PI * 2);
                ctx.fill();

                ctx.beginPath();
                ctx.moveTo(cx - width * 0.32, height * 0.88);
                ctx.bezierCurveTo(cx - width * 0.28, height * 0.58, cx + width * 0.28, height * 0.58, cx + width * 0.32, height * 0.88);
                ctx.bezierCurveTo(cx + width * 0.20, height * 0.94, cx - width * 0.20, height * 0.94, cx - width * 0.32, height * 0.88);
                ctx.closePath();
                ctx.fill();
            }
        }
    }

    Loader {
        anchors.fill: parent
        active: avatarPreviewRect.tab.currentAvatarSourcePath !== ""
        sourceComponent: Item {
            Rectangle {
                id: maskRect
                anchors.fill: parent
                radius: ThemeBackend.borderRadius
                color: "black"
                visible: false
                layer.enabled: true
            }

            Image {
                id: avatarImage
                anchors.fill: parent
                visible: false
                source: avatarPreviewRect.tab.currentAvatarSourcePath !== "" ? "file://" + avatarPreviewRect.tab.currentAvatarSourcePath : ""
                fillMode: Image.PreserveAspectCrop
                cache: false
                asynchronous: true
            }

            MultiEffect {
                anchors.fill: parent
                source: avatarImage
                maskEnabled: true
                maskSource: maskRect
            }
        }
    }
}
