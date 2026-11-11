import QtQuick
import QtQuick.Layouts
import "../../"
import ".."
import "../../reusables"

ColumnLayout {
    id: bottomChrome

    readonly property var widgetProxy: parent
    readonly property var preview: parent.preview
    readonly property var redactorMode: parent.redactorMode
    required property Item backdropItem
    property bool dragging: false

    function s(val) { return Scaler.s(val); }

    property Item glassBackdropItem: backdropItem
    z: 40
    opacity: (widgetProxy.isSelected && !dragging && !redactorMode.toolbar.panelOpen) ? 1.0 : 0.0
    visible: opacity > 0
    Behavior on opacity { NumberAnimation { duration: 150 } }
    spacing: s(6)

    Component {
        id: defaultAdditionalButtonComponent
        IconButton {
            id: defBtn
            property var settingData: null
            size: s(34)
            cornerRadius: ThemeBackend.borderRadius
            buttonIcon: (defBtn.settingData && defBtn.settingData.icon) ? defBtn.settingData.icon : ""
            iconFontSize: s((defBtn.settingData && defBtn.settingData.iconFontSize) ? defBtn.settingData.iconFontSize : 16)
            accentColor: redactorMode.resolveThemeColor((defBtn.settingData && defBtn.settingData.accentColor) ? defBtn.settingData.accentColor : "surface0")
            textColor: redactorMode.resolveThemeColor((defBtn.settingData && defBtn.settingData.textColor) ? defBtn.settingData.textColor : "mauve")
            onClicked: {
                if (defBtn.settingData && defBtn.settingData.action) {
                    redactorMode.handleAdditionalAction(defBtn.settingData.action, widgetProxy.wIndex, widgetProxy.wId, widgetProxy);
                }
            }
        }
    }

    readonly property real limitY: (redactorMode.toolbar.opacity > 0.1 && !redactorMode.toolbarObscured) ? redactorMode.toolbar.y : redactorMode.safeHeight

    readonly property bool fitsBelow: (widgetProxy.y + widgetProxy.height + widgetProxy.selectionGap + implicitHeight + s(8)) <= limitY
    readonly property bool fitsAbove: (widgetProxy.y - widgetProxy.selectionGap - implicitHeight - s(8)) >= 0

    readonly property bool fitsRight: (widgetProxy.x + widgetProxy.width + widgetProxy.selectionGap + implicitWidth + s(8)) <= redactorMode.safeWidth
    readonly property bool fitsLeft: (widgetProxy.x - widgetProxy.selectionGap - implicitWidth - s(8)) >= 0

    readonly property int calculatedPosMode: {
        if (fitsBelow) return 0;
        if (fitsAbove) return 1;
        if (fitsRight) return 2;
        if (fitsLeft) return 3;
        return 4;
    }

    property int posMode: 0

    onCalculatedPosModeChanged: {
        if (!dragging) {
            posMode = calculatedPosMode;
        }
    }

    Component.onCompleted: {
        posMode = calculatedPosMode;
    }

    x: {
        if (posMode === 2) {
            return widgetProxy.width + widgetProxy.selectionGap + s(8);
        } else if (posMode === 3) {
            return -widgetProxy.selectionGap - implicitWidth - s(8);
        } else {
            let idealX = (widgetProxy.width - implicitWidth) / 2;
            let screenX = widgetProxy.x + idealX;
            let clampedScreenX = Math.max(s(8), Math.min(redactorMode.safeWidth - implicitWidth - s(8), screenX));
            return clampedScreenX - widgetProxy.x;
        }
    }

    y: {
        if (posMode === 0) {
            return widgetProxy.height + widgetProxy.selectionGap + s(8);
        } else if (posMode === 1) {
            return -widgetProxy.selectionGap - implicitHeight - s(8);
        } else if (posMode === 2 || posMode === 3) {
            let idealY = (widgetProxy.height - implicitHeight) / 2;
            let screenY = widgetProxy.y + idealY;
            let clampedScreenY = Math.max(s(8), Math.min(limitY - implicitHeight - s(8), screenY));
            return clampedScreenY - widgetProxy.y;
        } else {
            let screenY = Math.min(limitY - implicitHeight - s(15), Math.max(s(15), widgetProxy.y + widgetProxy.height - implicitHeight - s(15)));
            return screenY - widgetProxy.y;
        }
    }

    property var variantsList: WidgetRegistry.variantList(widgetProxy.wType)
    property bool hasVariants: variantsList.length > 1

    RowLayout {
        spacing: s(4)
        Layout.alignment: Qt.AlignHCenter

        Rectangle {
            id: pxReadoutPill
            implicitWidth: pxReadoutText.implicitWidth + s(16)
            implicitHeight: s(34)
            color: pxGlass.active ? "transparent" : ThemeBackend.surface0
            radius: ThemeBackend.borderRadius

            GlassFill {
                id: pxGlass
                anchors.fill: parent
                radius: parent.radius
                tintColor: ThemeBackend.surface0
                tintAmount: 0.3
            }

            Text {
                id: pxReadoutText
                anchors.centerIn: parent
                text: Math.round(widgetProxy.model.wWidth) + "x" + Math.round(widgetProxy.model.wHeight)
                font.family: ThemeBackend.fontFamily
                font.pixelSize: s(12)
                font.bold: true
                color: ThemeBackend.text
            }
        }

        Rectangle {
            id: arReadoutPill
            implicitWidth: arReadoutText.implicitWidth + s(16)
            implicitHeight: s(34)
            color: arGlass.active ? "transparent" : ThemeBackend.surface0
            radius: ThemeBackend.borderRadius

            GlassFill {
                id: arGlass
                anchors.fill: parent
                radius: parent.radius
                tintColor: ThemeBackend.surface0
                tintAmount: 0.3
            }

            Text {
                id: arReadoutText
                anchors.centerIn: parent
                text: (widgetProxy.model.wWidth / widgetProxy.model.wHeight).toFixed(2) + ":1"
                font.family: ThemeBackend.fontFamily
                font.pixelSize: s(12)
                font.bold: true
                color: ThemeBackend.text
            }
        }

        Rectangle {
            id: pctReadoutPill
            implicitWidth: pctReadoutText.implicitWidth + s(16)
            implicitHeight: s(34)
            color: pctGlass.active ? "transparent" : ThemeBackend.surface0
            radius: ThemeBackend.borderRadius

            GlassFill {
                id: pctGlass
                anchors.fill: parent
                radius: parent.radius
                tintColor: ThemeBackend.surface0
                tintAmount: 0.3
            }

            Text {
                id: pctReadoutText
                anchors.centerIn: parent
                text: {
                    let def = widgetProxy.getDefaultSize(preview.item);
                    return Math.round((widgetProxy.model.wWidth / def.w) * 100) + "%";
                }
                font.family: ThemeBackend.fontFamily
                font.pixelSize: s(12)
                font.bold: true
                color: ThemeBackend.text
            }
        }

        Repeater {
            model: WidgetRegistry.additionalSettings(widgetProxy.wType, "top", widgetProxy.wVariant)
            delegate: RedactorSettingLoader {
                ownerProxy: widgetProxy
                faceLoader: preview
                ownerRedactor: redactorMode
                defaultComponent: defaultAdditionalButtonComponent
            }
        }

        IconButton {
            id: rotateBtn
            size: s(34)
            cornerRadius: ThemeBackend.borderRadius
            buttonIcon: "󰑖"
            iconFontSize: s(16)
            accentColor: ThemeBackend.surface0
            textColor: ThemeBackend.text
            onClicked: widgetProxy.rotateWidget()
        }

        IconButton {
            id: resetBtn
            size: s(34)
            cornerRadius: ThemeBackend.borderRadius
            buttonIcon: "󰑐"
            iconFontSize: s(15)
            accentColor: ThemeBackend.surface0
            textColor: ThemeBackend.text
            onClicked: widgetProxy.resetWidgetSize()
        }

        DeleteButton {
            id: closeBtn
            size: s(34)
            cornerRadius: ThemeBackend.borderRadius
            iconFontSize: s(18)

            onClicked: redactorMode.removeWidget(widgetProxy.wId)
        }
    }

    RowLayout {
        spacing: s(6)
        Layout.alignment: Qt.AlignHCenter

        Repeater {
            model: WidgetRegistry.additionalSettings(widgetProxy.wType, "bottom", widgetProxy.wVariant)
            delegate: RedactorSettingLoader {
                ownerProxy: widgetProxy
                faceLoader: preview
                ownerRedactor: redactorMode
                defaultComponent: defaultAdditionalButtonComponent
            }
        }

        Dropdown {
            id: variantDropdown
            property var variantsList: bottomChrome.variantsList
            visible: bottomChrome.hasVariants
            implicitHeight: s(34)
            implicitWidth: s(150)
            accentColor: ThemeBackend.mauve
            baseColor: ThemeBackend.surface0
            dropdownColor: ThemeBackend.base
            borderColor: ThemeBackend.surface1
            textColor: ThemeBackend.text
            activeTextColor: ThemeBackend.crust
            cornerRadius: ThemeBackend.borderRadius
            fontPixelSize: s(11)
            fuzzySearch: false
            options: variantsList.map(v => v.label || v.id)

            function updateCurrentIndex() {
                let curVar = widgetProxy.wVariant;
                for (let i = 0; i < variantsList.length; i++) {
                    if (variantsList[i].id === curVar) {
                        currentIndex = i;
                        break;
                    }
                }
            }

            Component.onCompleted: updateCurrentIndex()

            Connections {
                target: widgetProxy
                function onWVariantChanged() {
                    variantDropdown.updateCurrentIndex();
                }
            }

            onSelected: (idx, value) => {
                if (idx >= 0 && idx < variantsList.length) {
                    widgetProxy.applyVariant(variantsList[idx].id);
                }
            }
        }

        Rectangle {
            id: opacityPill
            implicitWidth: bottomChrome.hasVariants ? s(200) : s(280)
            implicitHeight: s(34)
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
                anchors.leftMargin: s(10)
                anchors.rightMargin: s(10)
                spacing: s(8)

                Text {
                    id: opReadoutText
                    text: Math.round(widgetProxy.wOpacity * 100) + "%"
                    font.family: ThemeBackend.fontFamily
                    font.pixelSize: s(11)
                    font.bold: true
                    color: ThemeBackend.text
                    Layout.preferredWidth: s(32)
                }

                Draggable {
                    id: opacitySlider
                    Layout.fillWidth: true
                    Layout.preferredHeight: s(16)
                    Layout.alignment: Qt.AlignVCenter
                    from: 0.0
                    to: 100.0
                    value: Math.round(widgetProxy.wOpacity * 100)
                    backgroundColor: ThemeBackend.surface1
                    accentColor: ThemeBackend.mauve
                    gradColor1: ThemeBackend.mauve
                    gradColor2: Qt.lighter(ThemeBackend.mauve, 1.05)
                    gradColor3: Qt.lighter(ThemeBackend.mauve, 1.10)
                    cornerRadius: ThemeBackend.borderRadius
                    handleSize: s(16)
                    handleColor: Qt.lighter(ThemeBackend.mauve, 1.15)
                    handleHoverColor: Qt.lighter(ThemeBackend.mauve, 1.3)
                    handleDragColor: Qt.lighter(ThemeBackend.mauve, 1.45)
                    handleBorderColor: Qt.rgba(0, 0, 0, 0.2)
                    showValueBubble: false

                    Connections {
                        target: widgetProxy
                        function onWOpacityChanged() {
                            opacitySlider.value = Math.round(widgetProxy.wOpacity * 100);
                        }
                    }

                    onMoved: val => {
                        widgetProxy.model.wOpacity = val / 100.0;
                        widgetProxy.triggerSync();
                    }

                    onDragFinished: {
                        widgetProxy.finalizeSync();
                    }
                }
            }
        }
    }
}
