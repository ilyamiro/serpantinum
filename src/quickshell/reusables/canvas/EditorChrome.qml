import QtQuick
import QtQuick.Layouts
import "../../"
import "../"

ColumnLayout {
    id: chrome

    property bool active: false
    property bool dragging: false
    property bool relativeToTarget: true
    property real targetX: 0
    property real targetY: 0
    property real targetWidth: 0
    property real targetHeight: 0
    property real boundsWidth: 1920
    property real boundsHeight: 1080
    property real limitY: boundsHeight
    property real selectionGap: Scaler.s(8)
    property real margin: Scaler.s(8)
    property bool allowSidePlacement: true

    property real itemWidth: 0
    property real itemHeight: 0
    property real defaultWidth: 0
    property real itemOpacity: 1.0
    property bool showScale: true
    property bool showRotate: true
    property bool showReset: true
    property bool showDelete: true
    property bool showBottomRow: true

    property var topSettings: []
    property var bottomSettings: []
    property var variants: []
    property string currentVariant: ""
    property var targetItem: null
    property var targetData: null
    property var typeData: null
    property var hostOwner: null
    property int settingsRevision: 0

    property Item glassBackdropItem: null

    signal rotateClicked()
    signal resetClicked()
    signal deleteClicked()
    signal variantSelected(string variantId)
    signal opacityMoved(real opacity)
    signal opacityFinished()
    signal settingPropertyEdited(string propName, var value)
    signal settingActionTriggered(string actionName)

    function s(val) { return Scaler.s(val); }

    readonly property bool hasVariants: Array.isArray(chrome.variants) && chrome.variants.length > 1

    z: 40
    spacing: s(6)
    opacity: (chrome.active && !chrome.dragging) ? 1.0 : 0.0
    visible: opacity > 0
    enabled: chrome.active && !chrome.dragging
    Behavior on opacity { NumberAnimation { duration: 150 } }

    readonly property bool fitsBelow: (chrome.targetY + chrome.targetHeight + chrome.selectionGap + implicitHeight + chrome.margin) <= chrome.limitY
    readonly property bool fitsAbove: (chrome.targetY - chrome.selectionGap - implicitHeight - chrome.margin) >= 0
    readonly property bool fitsRight: chrome.allowSidePlacement && (chrome.targetX + chrome.targetWidth + chrome.selectionGap + implicitWidth + chrome.margin) <= chrome.boundsWidth
    readonly property bool fitsLeft: chrome.allowSidePlacement && (chrome.targetX - chrome.selectionGap - implicitWidth - chrome.margin) >= 0

    readonly property int calculatedPosMode: {
        if (fitsBelow) return 0;
        if (fitsAbove) return 1;
        if (fitsRight) return 2;
        if (fitsLeft) return 3;
        return 4;
    }

    property int posMode: 0

    onCalculatedPosModeChanged: {
        if (!chrome.dragging) chrome.posMode = chrome.calculatedPosMode;
    }

    onDraggingChanged: {
        if (!chrome.dragging) chrome.posMode = chrome.calculatedPosMode;
    }

    Component.onCompleted: chrome.posMode = chrome.calculatedPosMode

    readonly property real screenPosX: {
        if (chrome.posMode === 2) {
            return chrome.targetX + chrome.targetWidth + chrome.selectionGap + chrome.margin;
        }
        if (chrome.posMode === 3) {
            return chrome.targetX - chrome.selectionGap - implicitWidth - chrome.margin;
        }
        let idealX = chrome.targetX + (chrome.targetWidth - implicitWidth) / 2;
        return Math.max(s(8), Math.min(chrome.boundsWidth - implicitWidth - s(8), idealX));
    }

    readonly property real screenPosY: {
        if (chrome.posMode === 0) {
            return chrome.targetY + chrome.targetHeight + chrome.selectionGap + chrome.margin;
        }
        if (chrome.posMode === 1) {
            return chrome.targetY - chrome.selectionGap - implicitHeight - chrome.margin;
        }
        if (chrome.posMode === 2 || chrome.posMode === 3) {
            let idealY = chrome.targetY + (chrome.targetHeight - implicitHeight) / 2;
            return Math.max(s(8), Math.min(chrome.limitY - implicitHeight - s(8), idealY));
        }
        return Math.max(s(8), Math.min(chrome.limitY - implicitHeight - s(15), Math.max(s(15), chrome.targetY + chrome.targetHeight - implicitHeight - s(15))));
    }

    x: chrome.relativeToTarget ? (chrome.screenPosX - chrome.targetX) : chrome.screenPosX
    y: chrome.relativeToTarget ? (chrome.screenPosY - chrome.targetY) : chrome.screenPosY

    component ReadoutPill: Rectangle {
        property alias label: pillText.text
        implicitWidth: pillText.implicitWidth + chrome.s(16)
        implicitHeight: chrome.s(34)
        color: pillGlass.active ? "transparent" : ThemeBackend.surface0
        radius: ThemeBackend.borderRadius

        GlassFill {
            id: pillGlass
            anchors.fill: parent
            radius: parent.radius
            tintColor: ThemeBackend.surface0
            tintAmount: 0.3
        }

        Text {
            id: pillText
            anchors.centerIn: parent
            font.family: ThemeBackend.fontFamily
            font.pixelSize: chrome.s(12)
            font.bold: true
            color: ThemeBackend.text
        }
    }

    RowLayout {
        spacing: chrome.s(4)
        Layout.alignment: Qt.AlignHCenter

        ReadoutPill {
            label: Math.round(chrome.itemWidth) + "x" + Math.round(chrome.itemHeight)
        }

        ReadoutPill {
            label: (chrome.itemHeight > 0 ? (chrome.itemWidth / chrome.itemHeight).toFixed(2) : "0.00") + ":1"
        }

        ReadoutPill {
            visible: chrome.showScale
            label: chrome.defaultWidth > 0 ? Math.round((chrome.itemWidth / chrome.defaultWidth) * 100) + "%" : "100%"
        }

        Repeater {
            model: chrome.topSettings
            delegate: SettingControlLoader {
                required property var modelData
                setting: modelData
                targetItem: chrome.targetItem
                targetData: chrome.targetData
                typeData: chrome.typeData
                hostOwner: chrome.hostOwner
                revision: chrome.settingsRevision
                onPropertyEdited: (propName, value) => chrome.settingPropertyEdited(propName, value)
                onActionTriggered: (actionName) => chrome.settingActionTriggered(actionName)
            }
        }

        IconButton {
            visible: chrome.showRotate
            size: chrome.s(34)
            cornerRadius: ThemeBackend.borderRadius
            buttonIcon: "󰑖"
            iconFontSize: chrome.s(16)
            accentColor: ThemeBackend.surface0
            textColor: ThemeBackend.text
            onClicked: chrome.rotateClicked()
        }

        IconButton {
            visible: chrome.showReset
            size: chrome.s(34)
            cornerRadius: ThemeBackend.borderRadius
            buttonIcon: "󰑐"
            iconFontSize: chrome.s(15)
            accentColor: ThemeBackend.surface0
            textColor: ThemeBackend.text
            onClicked: chrome.resetClicked()
        }

        DeleteButton {
            visible: chrome.showDelete
            size: chrome.s(34)
            cornerRadius: ThemeBackend.borderRadius
            iconFontSize: chrome.s(18)
            onClicked: chrome.deleteClicked()
        }
    }

    RowLayout {
        visible: chrome.showBottomRow
        spacing: chrome.s(6)
        Layout.alignment: Qt.AlignHCenter

        Repeater {
            model: chrome.bottomSettings
            delegate: SettingControlLoader {
                required property var modelData
                setting: modelData
                targetItem: chrome.targetItem
                targetData: chrome.targetData
                typeData: chrome.typeData
                hostOwner: chrome.hostOwner
                revision: chrome.settingsRevision
                onPropertyEdited: (propName, value) => chrome.settingPropertyEdited(propName, value)
                onActionTriggered: (actionName) => chrome.settingActionTriggered(actionName)
            }
        }

        Dropdown {
            id: variantDropdown
            visible: chrome.hasVariants
            implicitHeight: chrome.s(34)
            implicitWidth: chrome.s(150)
            accentColor: ThemeBackend.mauve
            baseColor: ThemeBackend.surface0
            dropdownColor: ThemeBackend.base
            borderColor: ThemeBackend.surface1
            textColor: ThemeBackend.text
            activeTextColor: ThemeBackend.crust
            cornerRadius: ThemeBackend.borderRadius
            fontPixelSize: chrome.s(11)
            fuzzySearch: false
            options: Array.isArray(chrome.variants) ? chrome.variants.map(v => v.label || v.name || v.id) : []

            function syncIndex() {
                if (!Array.isArray(chrome.variants) || chrome.variants.length === 0) return;
                let idx = chrome.variants.findIndex(v => v.id === chrome.currentVariant);
                let targetIdx = idx >= 0 ? idx : 0;
                if (variantDropdown.currentIndex !== targetIdx) variantDropdown.currentIndex = targetIdx;
            }

            Component.onCompleted: syncIndex()

            Connections {
                target: chrome
                function onCurrentVariantChanged() { variantDropdown.syncIndex(); }
                function onVariantsChanged() { variantDropdown.syncIndex(); }
            }

            onSelected: (idx, value) => {
                if (Array.isArray(chrome.variants) && idx >= 0 && idx < chrome.variants.length) {
                    chrome.variantSelected(chrome.variants[idx].id);
                }
            }
        }

        Rectangle {
            implicitWidth: chrome.hasVariants ? chrome.s(200) : chrome.s(280)
            implicitHeight: chrome.s(34)
            color: opacityGlass.active ? "transparent" : ThemeBackend.surface0
            radius: ThemeBackend.borderRadius

            GlassFill {
                id: opacityGlass
                anchors.fill: parent
                radius: parent.radius
                tintColor: ThemeBackend.surface0
                tintAmount: 0.3
            }

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: chrome.s(10)
                anchors.rightMargin: chrome.s(10)
                spacing: chrome.s(8)

                Text {
                    text: Math.round(chrome.itemOpacity * 100) + "%"
                    font.family: ThemeBackend.fontFamily
                    font.pixelSize: chrome.s(11)
                    font.bold: true
                    color: ThemeBackend.text
                    Layout.preferredWidth: chrome.s(32)
                }

                Draggable {
                    id: opacitySlider
                    Layout.fillWidth: true
                    Layout.preferredHeight: chrome.s(16)
                    Layout.alignment: Qt.AlignVCenter
                    from: 0.0
                    to: 100.0
                    value: Math.round(chrome.itemOpacity * 100)
                    backgroundColor: ThemeBackend.surface1
                    accentColor: ThemeBackend.mauve
                    gradColor1: ThemeBackend.mauve
                    gradColor2: Qt.lighter(ThemeBackend.mauve, 1.05)
                    gradColor3: Qt.lighter(ThemeBackend.mauve, 1.10)
                    cornerRadius: ThemeBackend.borderRadius
                    handleSize: chrome.s(16)
                    handleColor: Qt.lighter(ThemeBackend.mauve, 1.15)
                    handleHoverColor: Qt.lighter(ThemeBackend.mauve, 1.3)
                    handleDragColor: Qt.lighter(ThemeBackend.mauve, 1.45)
                    handleBorderColor: Qt.rgba(0, 0, 0, 0.2)
                    showValueBubble: false

                    Connections {
                        target: chrome
                        function onItemOpacityChanged() {
                            opacitySlider.value = Math.round(chrome.itemOpacity * 100);
                        }
                    }

                    onMoved: val => chrome.opacityMoved(val / 100.0)
                    onDragFinished: chrome.opacityFinished()
                }
            }
        }
    }
}
