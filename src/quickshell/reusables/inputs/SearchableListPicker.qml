import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import "../../"
import "../"

GuideModal {
    id: picker

    preferredWidth: s(480)
    padding: s(12)
    contentSpacing: s(10)
    showHeader: false

    property var items: []
    property string query: ""
    property string selectedId: ""
    property bool multiSelect: true
    property int maxRows: 7
    property string placeholderText: typeof I18n !== "undefined" ? I18n.t("guide.dock.picker.search", "Search apps...") : "Search..."
    property string emptyText: typeof I18n !== "undefined" ? I18n.t("guide.dock.picker.empty", "No matching applications") : "No matching items"
    property string doneText: typeof I18n !== "undefined" ? I18n.t("guide.dock.picker.done", "Done") : "Done"
    property string cancelText: typeof I18n !== "undefined" ? I18n.t("guide.wellbeing.settings.picker_cancel", "Cancel") : "Cancel"
    property string applyText: typeof I18n !== "undefined" ? I18n.t("guide.wellbeing.settings.picker_apply", "Apply") : "Apply"
    property string fallbackIcon: "󰏘"
    property var filterFn: null
    property var isSelectedFn: null

    readonly property alias searchInput: searchInput

    readonly property var filteredItems: {
        let q = picker.query.trim().toLowerCase();
        let src = picker.items || [];
        let out = [];
        for (let i = 0; i < src.length; i++) {
            let item = src[i];
            if (!item) continue;
            if (typeof picker.filterFn === "function") {
                if (picker.filterFn(item, q)) out.push(item);
            } else if (q === "") {
                out.push(item);
            } else {
                let t = String(item.title || item.name || "").toLowerCase();
                let sub = String(item.subtitle || item.comment || "").toLowerCase();
                let idStr = String(item.id || "").toLowerCase();
                if (t.indexOf(q) !== -1 || sub.indexOf(q) !== -1 || idStr.indexOf(q) !== -1) {
                    out.push(item);
                }
            }
        }
        return out;
    }

    signal itemToggled(var item)
    signal itemSelected(var item)
    signal itemApplied(string id, var item)

    function _itemSelected(item) {
        if (!item) return false;
        if (typeof picker.isSelectedFn === "function") return Boolean(picker.isSelectedFn(item));
        if (picker.multiSelect) return Boolean(item.selected);
        return picker.selectedId !== "" && String(item.id || "") === picker.selectedId;
    }

    function _findById(id) {
        let src = picker.items || [];
        for (let i = 0; i < src.length; i++) {
            if (src[i] && String(src[i].id || "") === id) return src[i];
        }
        return null;
    }

    function openPicker() {
        picker.query = "";
        picker.selectedId = "";
        searchInput.text = "";
        picker.open();
        searchInput.forceInputFocus();
    }

    RowLayout {
        Layout.fillWidth: true
        spacing: picker.s(8)

        Input {
            id: searchInput
            Layout.fillWidth: true
            Layout.preferredHeight: picker.s(34)
            placeholderText: picker.placeholderText
            baseColor: ThemeBackend.surface0
            accentColor: ThemeBackend.mauve
            textColor: ThemeBackend.text
            subTextColor: ThemeBackend.subtext0
            borderColor: Qt.alpha(ThemeBackend.surface2, 0.6)
            cornerRadius: ThemeBackend.borderRadius
            fontPixelSize: picker.s(11)
            showClearButton: true
            onTextEdited: function(newText) { picker.query = newText; }
            onCleared: picker.query = ""
            Keys.onEscapePressed: function(event) {
                picker.close();
                event.accepted = true;
            }
        }

        ClickButton {
            visible: picker.multiSelect
            implicitHeight: picker.s(34)
            maxWidth: picker.s(70)
            cornerRadius: ThemeBackend.borderRadius
            buttonText: picker.doneText
            accentColor: ThemeBackend.mauve
            textColor: ThemeBackend.liquidGlass ? ThemeBackend.text : ThemeBackend.crust
            textFontSize: picker.s(11)
            onClicked: picker.close()
        }
    }

    Rectangle {
        Layout.fillWidth: true
        Layout.preferredHeight: 1
        color: Qt.alpha(ThemeBackend.surface1, 0.3)
    }

    Item {
        Layout.fillWidth: true
        Layout.preferredHeight: picker.maxRows * picker.s(48) - picker.s(4)
        clip: true

        ListView {
            id: pickerList
            anchors.fill: parent
            clip: true
            model: picker.filteredItems
            spacing: picker.s(4)
            boundsBehavior: Flickable.StopAtBounds
            property Item hoverItem: null

            GlassLens {
                id: pickerLens
                z: -1
                targetX: pickerList.hoverItem ? pickerList.hoverItem.x : 0
                targetY: pickerList.hoverItem ? pickerList.hoverItem.y : 0
                targetWidth: pickerList.hoverItem ? pickerList.hoverItem.width : 0
                targetHeight: pickerList.hoverItem ? pickerList.hoverItem.height : 0
                radius: ThemeBackend.borderRadius
                tintColor: ThemeBackend.surface0
                tintAmount: 0.3
                shadow: 0
                restPress: 0.2
                magnify: picker.s(4)
                press: pickerList.hoverItem && pickerList.hoverItem.pressed ? 0.8 : 0
            }

            ScrollBar.vertical: StyledScrollBar {
                rootObj: picker.rootObj
            }

            delegate: Rectangle {
                id: row
                required property var modelData
                required property int index

                readonly property bool isSelected: picker._itemSelected(modelData)
                readonly property bool pressed: rowMa.pressed
                readonly property bool lensWanted: rowMa.containsMouse
                readonly property color contentOnSelected: rowGlass.active ? ThemeBackend.text : ThemeBackend.crust
                readonly property string itemTitle: String(modelData.title || modelData.name || modelData.id || "")
                readonly property string itemSubtitle: String(modelData.subtitle || modelData.comment || modelData.id || "")
                readonly property string itemIconSource: String(modelData.iconSource || "")
                readonly property string itemIconGlyph: String(modelData.iconGlyph || (modelData.iconSource ? "" : (modelData.icon || "")))

                width: pickerList.width - picker.s(6)
                height: picker.s(44)
                radius: ThemeBackend.borderRadius
                color: rowGlass.active ? "transparent" : (isSelected ? ThemeBackend.mauve : ((rowMa.containsMouse && !pickerLens.glassActive) ? Qt.alpha(ThemeBackend.surface1, 0.4) : Qt.alpha(ThemeBackend.surface0, 0.25)))

                Behavior on color { ColorAnimation { duration: 150 } }

                onLensWantedChanged: {
                    if (lensWanted) pickerList.hoverItem = row;
                    else if (pickerList.hoverItem === row) pickerList.hoverItem = null;
                }
                Component.onDestruction: {
                    if (pickerList.hoverItem === row) pickerList.hoverItem = null;
                }

                GlassFill {
                    id: rowGlass
                    anchors.fill: parent
                    radius: parent.radius
                    allowed: row.isSelected || (rowMa.containsMouse && !pickerLens.glassActive)
                    forceClear: row.isSelected
                    tintColor: row.isSelected ? ThemeBackend.text : ThemeBackend.surface0
                    tintAmount: row.isSelected ? 0.1 : 0.3
                    tintStrength: row.isSelected ? 1.0 : 0.5
                    press: rowMa.pressed ? 0.8 : (row.isSelected ? 0.6 : 0.2)
                }

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: picker.s(8)
                    anchors.rightMargin: picker.s(8)
                    spacing: picker.s(8)

                    Rectangle {
                        implicitWidth: picker.s(28)
                        implicitHeight: picker.s(28)
                        Layout.alignment: Qt.AlignVCenter
                        radius: Math.round(picker.s(28) * 0.28)
                        color: iconGlass.active ? "transparent" : (row.isSelected ? Qt.tint(ThemeBackend.surface0, Qt.rgba(ThemeBackend.mauve.r, ThemeBackend.mauve.g, ThemeBackend.mauve.b, 0.2)) : ThemeBackend.surface0)
                        clip: true

                        GlassFill {
                            id: iconGlass
                            anchors.fill: parent
                            radius: parent.radius
                            forceClear: row.isSelected
                            tintColor: row.isSelected ? ThemeBackend.text : ThemeBackend.surface2
                            tintAmount: row.isSelected ? 0.1 : 0.3
                        }

                        Image {
                            id: rowIconImg
                            anchors.fill: parent
                            anchors.margins: picker.s(3)
                            fillMode: Image.PreserveAspectFit
                            asynchronous: true
                            mipmap: true
                            sourceSize: {
                                let sz = Math.max(1, Math.ceil(picker.s(28) * (Screen.devicePixelRatio || 1)));
                                return Qt.size(sz, sz);
                            }
                            visible: row.itemIconSource !== "" && status === Image.Ready && !AppMatcher.iconMissing(source)
                            source: row.itemIconSource
                        }

                        Text {
                            anchors.centerIn: parent
                            visible: !rowIconImg.visible
                            text: row.itemIconGlyph !== "" ? row.itemIconGlyph : (row.itemTitle !== "" ? row.itemTitle.charAt(0).toUpperCase() : picker.fallbackIcon)
                            font.family: ThemeBackend.fontFamily
                            font.pixelSize: row.itemIconGlyph !== "" ? picker.s(14) : picker.s(12)
                            font.bold: row.itemIconGlyph === ""
                            color: row.isSelected ? (rowGlass.active ? ThemeBackend.text : ThemeBackend.mauve) : ThemeBackend.text
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        Layout.alignment: Qt.AlignVCenter
                        spacing: picker.s(1)

                        Text {
                            text: row.itemTitle
                            font.family: ThemeBackend.fontFamily
                            font.pixelSize: picker.s(11)
                            font.weight: row.isSelected ? Font.Bold : Font.Medium
                            color: row.isSelected ? row.contentOnSelected : ThemeBackend.text
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                            Behavior on color { ColorAnimation { duration: 150 } }
                        }

                        Text {
                            text: row.itemSubtitle
                            font.family: ThemeBackend.fontFamily
                            font.pixelSize: picker.s(9)
                            color: row.isSelected ? row.contentOnSelected : ThemeBackend.subtext0
                            opacity: row.isSelected ? 0.9 : 0.85
                            elide: Text.ElideMiddle
                            Layout.fillWidth: true
                            Behavior on color { ColorAnimation { duration: 150 } }
                        }
                    }
                }

                MouseArea {
                    id: rowMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (typeof Sounds !== "undefined") Sounds.playSfx("reusables/iconbutton/click.wav");
                        if (picker.multiSelect) {
                            picker.itemToggled(row.modelData);
                        } else {
                            let idStr = String(row.modelData.id || "");
                            picker.selectedId = row.isSelected ? "" : idStr;
                            picker.itemSelected(row.modelData);
                        }
                    }
                    onDoubleClicked: {
                        if (!picker.multiSelect) {
                            let idStr = String(row.modelData.id || "");
                            picker.selectedId = idStr;
                            picker.itemApplied(idStr, row.modelData);
                            picker.close();
                        }
                    }
                }
            }

            Item {
                anchors.fill: parent
                visible: picker.filteredItems.length === 0

                Text {
                    anchors.centerIn: parent
                    text: picker.emptyText
                    font.family: ThemeBackend.fontFamily
                    font.pixelSize: picker.s(11)
                    color: ThemeBackend.subtext0
                }
            }
        }
    }

    RowLayout {
        Layout.fillWidth: true
        spacing: picker.s(8)
        visible: !picker.multiSelect

        ClickButton {
            Layout.fillWidth: true
            implicitHeight: picker.s(34)
            cornerRadius: ThemeBackend.borderRadius
            buttonText: picker.cancelText
            accentColor: ThemeBackend.surface1
            textColor: ThemeBackend.text
            textFontSize: picker.s(11)
            onClicked: picker.close()
        }

        ClickButton {
            Layout.fillWidth: true
            implicitHeight: picker.s(34)
            enabled: picker.selectedId !== ""
            opacity: enabled ? 1.0 : 0.5
            cornerRadius: ThemeBackend.borderRadius
            buttonText: picker.applyText
            accentColor: ThemeBackend.mauve
            textColor: ThemeBackend.liquidGlass ? ThemeBackend.text : ThemeBackend.crust
            textFontSize: picker.s(11)
            onClicked: {
                picker.itemApplied(picker.selectedId, picker._findById(picker.selectedId));
                picker.close();
            }
        }
    }
}
