import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import "../../"
import "../"

Popup {
    id: modalRoot

    property var rootObj: null
    property string title: ""
    property bool showHeader: title !== ""
    property bool showCloseButton: true
    property real preferredWidth: s(480)
    property real cornerRadius: ThemeBackend.borderRadius <= 16 ? ThemeBackend.borderRadius * 1.5 : 24
    property real glassTintAmount: 0.25
    property real contentSpacing: s(12)
    property bool _modalCounted: false

    default property alias content: bodyCol.data

    function s(val) {
        return (rootObj && typeof rootObj.s === "function") ? rootObj.s(val) : Scaler.s(val);
    }

    function _incrementModalCount() {
        if (modalRoot._modalCounted) return;
        if (modalRoot.rootObj && modalRoot.rootObj.openModalCount !== undefined) {
            modalRoot.rootObj.openModalCount++;
            modalRoot._modalCounted = true;
        }
    }

    function _decrementModalCount() {
        if (!modalRoot._modalCounted) return;
        modalRoot._modalCounted = false;
        if (modalRoot.rootObj && modalRoot.rootObj.openModalCount !== undefined && modalRoot.rootObj.openModalCount > 0) {
            modalRoot.rootObj.openModalCount--;
        }
    }

    parent: {
        if (rootObj) {
            return rootObj.contentItem ? rootObj.contentItem : rootObj;
        }
        return Overlay.overlay ? Overlay.overlay : undefined;
    }
    x: parent && parent.width > 0 ? Math.max(0, Math.round((parent.width - width) / 2)) : 0
    y: parent && parent.height > 0 ? Math.max(0, Math.round((parent.height - height) / 2)) : 0
    width: parent && parent.width > 0 ? Math.min(parent.width - s(32), preferredWidth) : preferredWidth
    padding: s(16)
    modal: true
    dim: true
    closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutsideParent

    onOpened: _incrementModalCount()
    onClosed: _decrementModalCount()
    Component.onDestruction: _decrementModalCount()

    Connections {
        target: modalRoot.rootObj ? modalRoot.rootObj : null
        function onVisibleChanged() {
            if (modalRoot.rootObj && !modalRoot.rootObj.visible) {
                modalRoot.close();
            }
        }
    }

    Connections {
        target: modalRoot.parent && modalRoot.parent !== modalRoot.rootObj ? modalRoot.parent : null
        function onVisibleChanged() {
            if (modalRoot.parent && !modalRoot.parent.visible) {
                modalRoot.close();
            }
        }
    }

    background: Rectangle {
        radius: modalRoot.cornerRadius
        color: modalGlass.active ? "transparent" : ThemeBackend.base

        GlassFill {
            id: modalGlass
            anchors.fill: parent
            radius: parent.radius
            tintColor: ThemeBackend.base
            tintAmount: modalRoot.glassTintAmount
        }
    }

    contentItem: ColumnLayout {
        spacing: modalRoot.contentSpacing

        RowLayout {
            Layout.fillWidth: true
            visible: modalRoot.showHeader

            Text {
                text: modalRoot.title
                color: ThemeBackend.text
                font.family: ThemeBackend.fontFamily
                font.pixelSize: modalRoot.s(16)
                font.bold: true
                Layout.fillWidth: true
                elide: Text.ElideRight
            }

            CloseButton {
                visible: modalRoot.showCloseButton
                size: modalRoot.s(30)
                cornerRadius: modalRoot.s(8)
                iconFontSize: modalRoot.s(14)
                onClicked: modalRoot.close()
            }
        }

        ColumnLayout {
            id: bodyCol
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: modalRoot.contentSpacing
        }
    }
}
