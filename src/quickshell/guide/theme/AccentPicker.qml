import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import "../../"
import "../../reusables"

Popup {
    id: accentPickerPopup
    parent: rootObj ? rootObj : undefined
    x: parent && parent.width > 0 ? Math.max(0, Math.round((parent.width - width) / 2)) : 0
    y: parent && parent.height > 0 ? Math.max(0, Math.round((parent.height - height) / 2)) : 0
    modal: true
    dim: true
    width: rootObj ? Math.min(rootObj.width - rootObj.s(32), rootObj.s(560)) : 560
    padding: rootObj ? rootObj.s(20) : 20
    closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutsideParent

    property var rootObj
    property var tab
    property var palette: ({})

    readonly property string currentValue: tab ? String(tab.currentAccent) : "mauve"
    readonly property bool isCustom: currentValue.charAt(0) === "#"
    readonly property string currentName: isCustom ? currentValue.toUpperCase() : labelFor(currentValue)

    readonly property var paletteKeys: [
        "mauve", "pink", "blue", "sapphire", "sky",
        "teal", "green", "yellow", "peach", "red",
        "maroon", "lavender", "flamingo", "rosewater",
        "text", "subtext0", "subtext1",
        "surface0", "surface1", "surface2",
        "overlay0", "overlay1", "overlay2"
    ]

    readonly property var entries: {
        let out = [];
        for (let i = 0; i < paletteKeys.length; i++) {
            let key = paletteKeys[i];
            let value = palette ? palette[key] : undefined;
            let hex = resolveHex(value);
            if (!hex) continue;
            out.push({ key: key, hex: hex, label: labelFor(key) });
        }
        return out;
    }

    function s(value) {
        return rootObj ? rootObj.s(value) : value;
    }

    function resolveHex(value) {
        if (value === undefined || value === null) return "";
        if (typeof value === "string") {
            if (value.trim() === "") return "";
            return value.charAt(0) === "#" ? value : ("#" + value);
        }
        if (typeof value === "object") {
            if (value.hex) return resolveHex(String(value.hex));
            if (value.color) return resolveHex(String(value.color));
            if (value.default && value.default.hex) return resolveHex(String(value.default.hex));
        }
        return "";
    }

    function labelFor(key) {
        let fallback = {
            "surface0": "Surface 0",
            "surface1": "Surface 1",
            "surface2": "Surface 2",
            "overlay0": "Overlay 0",
            "overlay1": "Overlay 1",
            "overlay2": "Overlay 2",
            "subtext0": "Subtext 0",
            "subtext1": "Subtext 1"
        }[key] || (key.charAt(0).toUpperCase() + key.slice(1));
        return I18n.t("guide.theme.accent.palette." + key, fallback);
    }

    function openPicker() {
        palette = (tab && typeof tab.activePalette === "function") ? tab.activePalette() : ({});
        hexInput.text = "";
        hexInput.hasError = false;
        open();
    }

    function apply(value) {
        if (!tab) return;
        if (typeof tab.setAccentValue === "function") {
            tab.setAccentValue(value);
        }
    }

    function applyHex() {
        let raw = String(hexInput.text).trim();
        if (raw === "") return;
        let hex = raw.charAt(0) === "#" ? raw.slice(1) : raw;
        if (hex.length === 3) {
            hex = hex.charAt(0) + hex.charAt(0) + hex.charAt(1) + hex.charAt(1) + hex.charAt(2) + hex.charAt(2);
        }
        if (!/^[0-9a-fA-F]{6}$/.test(hex) && !/^[0-9a-fA-F]{8}$/.test(hex)) {
            hexInput.hasError = true;
            return;
        }
        hexInput.hasError = false;
        apply("#" + hex.toLowerCase());
        hexInput.text = "";
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: accentPickerPopup.s(12)

        RowLayout {
            Layout.fillWidth: true
            spacing: accentPickerPopup.s(10)

            Text {
                text: "󰏘"
                font.family: ThemeBackend.iconFont
                font.pixelSize: accentPickerPopup.s(18)
                color: ThemeBackend.accent
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: accentPickerPopup.s(1)

                Text {
                    text: I18n.t("guide.theme.accent.title", "Accent color")
                    color: ThemeBackend.text
                    font.family: ThemeBackend.fontFamily
                    font.pixelSize: accentPickerPopup.s(13)
                    font.weight: Font.DemiBold
                }

                Text {
                    Layout.fillWidth: true
                    text: I18n.t("guide.theme.accent.desc", "Used by workspace indicators, selections and focus highlights")
                    color: ThemeBackend.subtext0
                    font.family: ThemeBackend.fontFamily
                    font.pixelSize: accentPickerPopup.s(10)
                    wrapMode: Text.WordWrap
                }
            }

            IconButton {
                Layout.preferredWidth: accentPickerPopup.s(28)
                Layout.preferredHeight: accentPickerPopup.s(28)
                cornerRadius: accentPickerPopup.s(6)
                buttonIcon: "󰅖"
                iconFontSize: accentPickerPopup.s(12)
                accentColor: ThemeBackend.surface0
                textColor: ThemeBackend.overlay2
                onClicked: accentPickerPopup.close()
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: accentPickerPopup.s(70)
            radius: accentPickerPopup.s(10)
            color: Qt.alpha(ThemeBackend.surface0, 0.4)
            border.width: 1
            border.color: Qt.alpha(ThemeBackend.surface2, 0.4)

            RowLayout {
                anchors.centerIn: parent
                spacing: accentPickerPopup.s(22)

                Rectangle {
                    Layout.preferredWidth: accentPickerPopup.s(112)
                    Layout.preferredHeight: accentPickerPopup.s(28)
                    radius: accentPickerPopup.s(8)
                    color: ThemeBackend.surface1

                    Row {
                        anchors.centerIn: parent
                        spacing: accentPickerPopup.s(6)

                        Repeater {
                            model: 3

                            Rectangle {
                                width: index === 1 ? accentPickerPopup.s(20) : accentPickerPopup.s(7)
                                height: accentPickerPopup.s(7)
                                radius: accentPickerPopup.s(3.5)
                                color: index === 1 ? ThemeBackend.accent : ThemeBackend.subtext0
                                opacity: index === 1 ? 1.0 : 0.45
                            }
                        }
                    }
                }

                Column {
                    spacing: accentPickerPopup.s(3)

                    Rectangle {
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: accentPickerPopup.s(20)
                        height: accentPickerPopup.s(20)
                        radius: accentPickerPopup.s(6)
                        color: ThemeBackend.surface1
                    }

                    Rectangle {
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: accentPickerPopup.s(6)
                        height: accentPickerPopup.s(6)
                        radius: accentPickerPopup.s(3)
                        color: ThemeBackend.accent
                    }
                }

                Rectangle {
                    Layout.preferredWidth: accentPickerPopup.s(120)
                    Layout.preferredHeight: accentPickerPopup.s(26)
                    radius: accentPickerPopup.s(6)
                    color: Qt.tint(ThemeBackend.surface1, Qt.rgba(ThemeBackend.accent.r, ThemeBackend.accent.g, ThemeBackend.accent.b, 0.28))

                    Text {
                        anchors.left: parent.left
                        anchors.leftMargin: accentPickerPopup.s(8)
                        anchors.verticalCenter: parent.verticalCenter
                        text: I18n.t("guide.theme.accent.selected", "Selected")
                        color: ThemeBackend.text
                        font.family: ThemeBackend.fontFamily
                        font.pixelSize: accentPickerPopup.s(10)
                    }
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: accentPickerPopup.s(8)

            Text {
                Layout.fillWidth: true
                text: I18n.t("guide.theme.accent.palette_title", "Theme palette")
                color: ThemeBackend.subtext0
                font.family: ThemeBackend.fontFamily
                font.pixelSize: accentPickerPopup.s(10)
                font.weight: Font.DemiBold
            }

            Rectangle {
                Layout.preferredWidth: accentPickerPopup.s(10)
                Layout.preferredHeight: accentPickerPopup.s(10)
                radius: accentPickerPopup.s(3)
                color: ThemeBackend.accent
                border.width: 1
                border.color: Qt.alpha(ThemeBackend.text, 0.2)
            }

            Text {
                text: accentPickerPopup.currentName
                color: ThemeBackend.text
                font.family: ThemeBackend.fontFamily
                font.pixelSize: accentPickerPopup.s(10)
            }
        }

        Flickable {
            Layout.fillWidth: true
            Layout.preferredHeight: accentPickerPopup.s(150)
            contentWidth: width
            contentHeight: swatchGrid.implicitHeight
            clip: true
            boundsBehavior: Flickable.StopAtBounds

            ScrollBar.vertical: ScrollBar {
                width: accentPickerPopup.s(4)
                policy: ScrollBar.AsNeeded

                contentItem: Rectangle {
                    radius: accentPickerPopup.s(2)
                    color: ThemeBackend.surface2
                }
            }

            GridLayout {
                id: swatchGrid
                width: parent.width - accentPickerPopup.s(8)
                columns: 6
                columnSpacing: accentPickerPopup.s(4)
                rowSpacing: accentPickerPopup.s(4)

                Repeater {
                    model: accentPickerPopup.entries

                    delegate: Rectangle {
                        id: swatchCell
                        required property var modelData

                        readonly property bool selected: !accentPickerPopup.isCustom
                                                         && accentPickerPopup.currentValue === modelData.key

                        Layout.fillWidth: true
                        Layout.preferredHeight: accentPickerPopup.s(44)
                        radius: accentPickerPopup.s(8)
                        color: swatchArea.containsMouse ? Qt.lighter(ThemeBackend.surface0, 1.25) : "transparent"
                        border.width: selected ? 1 : 0
                        border.color: ThemeBackend.accent

                        ColumnLayout {
                            anchors.centerIn: parent
                            spacing: accentPickerPopup.s(3)

                            Rectangle {
                                Layout.alignment: Qt.AlignHCenter
                                Layout.preferredWidth: accentPickerPopup.s(18)
                                Layout.preferredHeight: accentPickerPopup.s(18)
                                radius: accentPickerPopup.s(5)
                                color: swatchCell.modelData.hex
                                border.width: 1
                                border.color: Qt.alpha(ThemeBackend.text, 0.15)

                                Text {
                                    anchors.centerIn: parent
                                    visible: swatchCell.selected
                                    text: "󰄬"
                                    font.family: ThemeBackend.iconFont
                                    font.pixelSize: accentPickerPopup.s(11)
                                    color: (0.2126 * parent.color.r + 0.7152 * parent.color.g + 0.0722 * parent.color.b) > 0.55
                                           ? ThemeBackend.crust : ThemeBackend.text
                                }
                            }

                            Text {
                                Layout.alignment: Qt.AlignHCenter
                                Layout.maximumWidth: accentPickerPopup.s(72)
                                text: swatchCell.modelData.label
                                color: swatchCell.selected ? ThemeBackend.text : ThemeBackend.subtext0
                                font.family: ThemeBackend.fontFamily
                                font.pixelSize: accentPickerPopup.s(9)
                                elide: Text.ElideRight
                            }
                        }

                        MouseArea {
                            id: swatchArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: accentPickerPopup.apply(swatchCell.modelData.key)
                        }
                    }
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: accentPickerPopup.s(8)

            Input {
                id: hexInput
                Layout.fillWidth: true
                Layout.preferredHeight: accentPickerPopup.s(32)
                placeholderText: I18n.t("guide.theme.accent.hex_placeholder", "Custom hex, e.g. #a88868")
                baseColor: ThemeBackend.surface0
                accentColor: ThemeBackend.accent
                textColor: ThemeBackend.text
                subTextColor: ThemeBackend.subtext0
                borderColor: Qt.alpha(ThemeBackend.surface2, 0.6)
                cornerRadius: ThemeBackend.borderRadius
                fontPixelSize: accentPickerPopup.s(11)
                onTextEdited: hasError = false
                onAccepted: accentPickerPopup.applyHex()
            }

            ClickButton {
                Layout.preferredHeight: accentPickerPopup.s(32)
                cornerRadius: ThemeBackend.borderRadius
                buttonText: I18n.t("guide.theme.accent.apply", "Apply")
                textFontSize: accentPickerPopup.s(11)
                accentColor: ThemeBackend.accent
                textColor: ThemeBackend.crust
                onClicked: accentPickerPopup.applyHex()
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: accentPickerPopup.s(8)

            ClickButton {
                Layout.preferredHeight: accentPickerPopup.s(30)
                cornerRadius: ThemeBackend.borderRadius
                buttonText: I18n.t("guide.theme.accent.reset", "Theme default")
                textFontSize: accentPickerPopup.s(10)
                accentColor: ThemeBackend.surface1
                textColor: ThemeBackend.text
                onClicked: {
                    if (accentPickerPopup.tab && typeof accentPickerPopup.tab.resetAccentValue === "function") {
                        accentPickerPopup.tab.resetAccentValue();
                    }
                }
            }

            Item { Layout.fillWidth: true }

            ClickButton {
                Layout.preferredHeight: accentPickerPopup.s(30)
                cornerRadius: ThemeBackend.borderRadius
                buttonText: I18n.t("common.done", "Done")
                textFontSize: accentPickerPopup.s(10)
                accentColor: ThemeBackend.surface0
                textColor: ThemeBackend.overlay2
                onClicked: accentPickerPopup.close()
            }
        }
    }
}
