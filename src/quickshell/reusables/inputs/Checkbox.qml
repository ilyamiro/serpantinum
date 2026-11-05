import QtQuick
import QtQuick.Layouts
import "../"
import "../../"

Item {
    id: root
    implicitWidth: mainRow.implicitWidth
    implicitHeight: Math.max(root.size, mainLabel.visible ? mainLabel.implicitHeight : 0)

    property int size: 22
    property real cornerRadius: Math.min(ThemeBackend.borderRadius, root.size * 0.35)
    property int spacing: 10

    property string text: ""
    property int textFontSize: 12

    property bool checked: false
    property color accentColor: ThemeBackend.mauve
    property color baseColor: ThemeBackend.surface0
    property color hoverColor: ThemeBackend.surface2
    property color checkColor: ThemeBackend.crust
    property color textColor: ThemeBackend.text

    property bool action_highlight: false
    property string toggleSound: "reusables/iconbutton/click.wav"

    signal toggled(bool checked)
    signal clicked()

    property real fill: 0.0
    property real draw: 0.0
    property real popScale: 1.0
    property real hover: (btnMa.containsMouse || root.action_highlight) && root.enabled ? 1.0 : 0.0
    Behavior on hover { NumberAnimation { duration: 150 } }

    activeFocusOnTab: root.enabled
    Keys.onPressed: (event) => {
        if (event.key === Qt.Key_Space || event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
            root.toggle();
            event.accepted = true;
        }
    }

    function toggle() {
        if (!root.enabled) return;
        root.checked = !root.checked;
        popAnim.restart();
        if (typeof Sounds !== "undefined") {
            Sounds.playSfx(root.toggleSound);
        }
        root.clicked();
        root.toggled(root.checked);
    }

    Component.onCompleted: {
        root.fill = root.checked ? 1.0 : 0.0;
        root.draw = root.checked ? 1.0 : 0.0;
        checkAnim.armed = true;
    }

    onCheckedChanged: {
        if (!checkAnim.armed) return;
        checkAnim.restart();
    }

    ParallelAnimation {
        id: checkAnim
        property bool armed: false

        NumberAnimation {
            target: root
            property: "fill"
            to: root.checked ? 1.0 : 0.0
            duration: root.checked ? 300 : 220
            easing.type: root.checked ? Easing.OutCubic : Easing.InCubic
        }
        SequentialAnimation {
            PauseAnimation { duration: root.checked ? 110 : 0 }
            NumberAnimation {
                target: root
                property: "draw"
                to: root.checked ? 1.0 : 0.0
                duration: root.checked ? 240 : 130
                easing.type: root.checked ? Easing.OutQuart : Easing.InQuad
            }
        }
    }

    SequentialAnimation {
        id: popAnim
        NumberAnimation { target: root; property: "popScale"; to: 1.12; duration: 90; easing.type: Easing.OutQuad }
        NumberAnimation { target: root; property: "popScale"; to: 1.0; duration: 320; easing.type: Easing.OutQuint }
    }

    RowLayout {
        id: mainRow
        layoutDirection: I18n.layoutDirection
        anchors.verticalCenter: parent.verticalCenter
        spacing: root.spacing

        Item {
            id: box
            implicitWidth: root.size
            implicitHeight: root.size
            Layout.alignment: Qt.AlignVCenter
            opacity: root.enabled ? 1.0 : 0.5
            scale: (btnMa.pressed ? 0.92 : (root.hover > 0.5 ? 1.06 : 1.0)) * root.popScale
            Behavior on scale { NumberAnimation { duration: 250; easing.type: Easing.OutQuint } }

            ShaderEffect {
                anchors.fill: parent
                property vector2d itemSize: Qt.vector2d(width, height)
                property color baseColor: root.baseColor
                property color hoverColor: root.hoverColor
                property color accentColor: root.accentColor
                property color checkColor: root.checkColor
                property vector4d params: Qt.vector4d(root.cornerRadius, 0.0, root.fill, root.draw)
                property vector4d params2: Qt.vector4d(root.hover, Math.max(1.5, root.size * 0.1), 0.0, 0.0)
                fragmentShader: "file://" + Caching.serpantinumDir + "/assets/shaders/ui/checkbox.frag.qsb"
            }
        }

        Text {
            id: mainLabel
            visible: root.text !== ""
            text: root.text
            font.family: ThemeBackend.fontFamily
            font.pixelSize: root.textFontSize
            color: root.textColor
            Layout.alignment: Qt.AlignVCenter
        }
    }

    MouseArea {
        id: btnMa
        anchors.fill: mainRow
        hoverEnabled: root.enabled
        enabled: root.enabled
        cursorShape: root.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
        onClicked: root.toggle()
    }
}
