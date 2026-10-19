import QtQuick
import QtQuick.Layouts
import "../../../"
import "../../../bar"
import "../../../reusables"

Rectangle {
    id: styleCard
    required property var tab
    required property var variant
    required property string moduleId
    property bool selected: false
    property Component widgetComponent: null
    property Component fallback: null
    property real previewSideHeight: 140

    readonly property var rootObj: tab.rootObj
    property real popScale: 1.0
    property real flashOpacity: 0.0

    signal picked(string id)

    Layout.fillWidth: true
    Layout.preferredWidth: 1
    implicitHeight: innerCol.implicitHeight + rootObj.s(16)
    radius: ThemeBackend.borderRadius
    clip: true

    color: ThemeBackend.liquidGlass ? "transparent" : (mouse.pressed
        ? Qt.darker(ThemeBackend.surface0, 1.15)
        : (selected
            ? (hover.hovered ? Qt.lighter(ThemeBackend.surface0, 1.30) : Qt.lighter(ThemeBackend.surface0, 1.24))
            : (hover.hovered ? Qt.lighter(ThemeBackend.surface0, 1.10) : ThemeBackend.surface0)))

    GlassFill {
        id: glass
        anchors.fill: parent
        allowed: tab.inView(parent)
        radius: parent.radius
        tintColor: ThemeBackend.surface0
        tintAmount: styleCard.selected ? 0.45 : 0.25
        press: mouse.pressed ? 0.8 : (hover.hovered ? 0.25 : 0)
        pulse: Math.min(1, styleCard.flashOpacity * 2.5)
        Behavior on press { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
    }

    border.width: ThemeBackend.liquidGlass ? 0 : 1
    border.color: selected
        ? Qt.alpha(ThemeBackend.surface2, 0.75)
        : (hover.hovered ? Qt.alpha(ThemeBackend.surface2, 0.5) : Qt.alpha(ThemeBackend.surface1, 0.4))

    Behavior on color { ColorAnimation { duration: 180 } }
    Behavior on border.color { ColorAnimation { duration: 180 } }

    scale: (mouse.pressed ? 0.985 : (hover.hovered ? 1.015 : 1.0)) * styleCard.popScale
    Behavior on scale { NumberAnimation { duration: 250; easing.type: Easing.OutQuint } }

    HoverHandler {
        id: hover
    }

    Rectangle {
        anchors.fill: parent
        radius: parent.radius
        color: "#ffffff"
        opacity: styleCard.flashOpacity
        visible: !glass.active
        PropertyAnimation on opacity { id: flashAnim; to: 0; duration: 350; easing.type: Easing.OutExpo }
    }

    SequentialAnimation {
        id: popAnim
        NumberAnimation { target: styleCard; property: "popScale"; to: 1.02; duration: 100; easing.type: Easing.OutQuad }
        NumberAnimation { target: styleCard; property: "popScale"; to: 1.0; duration: 350; easing.type: Easing.OutQuint }
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: {
            popAnim.start();
            styleCard.flashOpacity = 0.15;
            flashAnim.start();
            if (typeof Sounds !== "undefined") {
                Sounds.playSfx("reusables/clickbutton/click.wav");
            }
            styleCard.picked(styleCard.variant.id);
        }
    }

    ColumnLayout {
        id: innerCol
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: rootObj.s(8)
        spacing: rootObj.s(8)

        BarModulePreview {
            tab: styleCard.tab
            source: BarModuleRegistry.variantFaceFile(styleCard.moduleId, styleCard.variant.id)
            widgetComponent: styleCard.widgetComponent
            fallback: styleCard.fallback
            variantId: styleCard.variant.id
            sideHeight: styleCard.previewSideHeight
        }

        Text {
            Layout.fillWidth: true
            Layout.leftMargin: rootObj.s(2)
            Layout.rightMargin: rootObj.s(2)
            Layout.bottomMargin: rootObj.s(2)
            text: styleCard.variant.name
            font.family: ThemeBackend.fontFamily
            font.pixelSize: rootObj.s(13)
            font.weight: Font.Bold
            color: ThemeBackend.text
        }
    }
}
