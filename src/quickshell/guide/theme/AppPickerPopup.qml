import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import "../../"
import "../../reusables"

Popup {
    id: pickerPopup
    parent: rootObj ? rootObj : undefined
    x: parent && parent.width > 0 ? Math.max(0, Math.round((parent.width - width) / 2)) : 0
    y: parent && parent.height > 0 ? Math.max(0, Math.round((parent.height - height) / 2)) : 0
    modal: true
    dim: true
    width: rootObj ? Math.min(rootObj.width - rootObj.s(32), rootObj.s(480)) : 480
    padding: rootObj ? rootObj.s(12) : 12
    closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutsideParent

    property var rootObj
    property string search: ""

    readonly property int maxRows: 7
    readonly property var appById: {
        let map = {};
        for (let i = 0; i < AppTheming.apps.length; i++) map[AppTheming.apps[i].id] = AppTheming.apps[i];
        return map;
    }

    ListModel { id: idsModel }

    function s(v) {
        return rootObj ? rootObj.s(v) : v;
    }

    function rebuild() {
        let q = search.trim().toLowerCase();
        let ids = AppTheming.apps
            .filter(a => a.installed && (q === "" || a.name.toLowerCase().indexOf(q) !== -1 || a.id.indexOf(q) !== -1))
            .sort((a, b) => a.name.localeCompare(b.name))
            .map(a => a.id);
        let same = ids.length === idsModel.count;
        for (let i = 0; same && i < ids.length; i++) {
            if (idsModel.get(i).appId !== ids[i]) same = false;
        }
        if (same) return;
        idsModel.clear();
        for (let j = 0; j < ids.length; j++) idsModel.append({ appId: ids[j] });
    }

    function openPicker() {
        search = "";
        searchInput.text = "";
        rebuild();
        AppTheming.refresh();
        open();
        searchInput.forceInputFocus();
    }

    onSearchChanged: rebuild()

    Connections {
        target: AppTheming

        function onAppsChanged() {
            pickerPopup.rebuild();
        }
    }

    Connections {
        target: pickerPopup.rootObj ? pickerPopup.rootObj : null

        function onVisibleChanged() {
            if (pickerPopup.rootObj && !pickerPopup.rootObj.visible) pickerPopup.close();
        }
    }

    background: Rectangle {
        radius: ThemeBackend.borderRadius <= 16 ? ThemeBackend.borderRadius * 1.5 : 24
        color: pickerGlass.active ? "transparent" : ThemeBackend.base

        GlassFill {
            id: pickerGlass
            anchors.fill: parent
            radius: parent.radius
            tintColor: ThemeBackend.base
            tintAmount: 0.25
        }
    }

    contentItem: ColumnLayout {
        spacing: pickerPopup.s(10)

        RowLayout {
            Layout.fillWidth: true
            spacing: pickerPopup.s(8)

            Input {
                id: searchInput
                Layout.fillWidth: true
                Layout.preferredHeight: pickerPopup.s(34)
                placeholderText: I18n.t("guide.dock.picker.search")
                baseColor: ThemeBackend.surface0
                accentColor: ThemeBackend.mauve
                textColor: ThemeBackend.text
                subTextColor: ThemeBackend.subtext0
                borderColor: Qt.alpha(ThemeBackend.surface2, 0.6)
                cornerRadius: ThemeBackend.borderRadius
                fontPixelSize: pickerPopup.s(11)
                showClearButton: true
                onTextEdited: function(newText) { pickerPopup.search = newText; }
                onCleared: pickerPopup.search = ""
                Keys.onEscapePressed: function(event) {
                    pickerPopup.close();
                    event.accepted = true;
                }
            }

            ClickButton {
                implicitHeight: pickerPopup.s(34)
                maxWidth: pickerPopup.s(70)
                cornerRadius: ThemeBackend.borderRadius
                buttonText: I18n.t("guide.dock.picker.done")
                accentColor: ThemeBackend.mauve
                textColor: ThemeBackend.liquidGlass ? ThemeBackend.text : ThemeBackend.crust
                textFontSize: pickerPopup.s(11)
                onClicked: pickerPopup.close()
            }
        }

        Rectangle {
            Layout.fillWidth: true
            height: 1
            color: Qt.alpha(ThemeBackend.surface1, 0.3)
        }

        Item {
            Layout.fillWidth: true
            Layout.preferredHeight: pickerPopup.maxRows * pickerPopup.s(48) - pickerPopup.s(4)
            clip: true

            ListView {
                id: pickerList
                anchors.fill: parent
                clip: true
                model: idsModel
                spacing: pickerPopup.s(4)
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
                    magnify: pickerPopup.s(4)
                    press: pickerList.hoverItem && pickerList.hoverItem.pressed ? 0.8 : 0
                }

                ScrollBar.vertical: ScrollBar {
                    active: parent.moving || parent.movingVertically
                    width: pickerPopup.s(4)
                    policy: ScrollBar.AsNeeded
                    contentItem: Rectangle {
                        implicitWidth: pickerPopup.s(4)
                        radius: pickerPopup.s(2)
                        color: ThemeBackend.surface2
                    }
                }

                delegate: Rectangle {
                    id: row
                    required property string appId
                    required property int index

                    readonly property var modelData: pickerPopup.appById[appId] || ({ id: appId, name: appId, icon: "", outputs: [], enabled: false })
                    readonly property bool isAdded: modelData.enabled
                    readonly property bool pressed: rowMa.pressed
                    readonly property bool lensWanted: rowMa.containsMouse
                    readonly property color contentOnAdded: rowGlass.active ? ThemeBackend.text : ThemeBackend.crust

                    width: pickerList.width - pickerPopup.s(6)
                    height: pickerPopup.s(44)
                    radius: ThemeBackend.borderRadius
                    color: rowGlass.active ? "transparent" : (isAdded ? ThemeBackend.mauve : ((rowMa.containsMouse && !pickerLens.glassActive) ? Qt.alpha(ThemeBackend.surface1, 0.4) : Qt.alpha(ThemeBackend.surface0, 0.25)))

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
                        allowed: row.isAdded || (rowMa.containsMouse && !pickerLens.glassActive)
                        forceClear: row.isAdded
                        tintColor: row.isAdded ? ThemeBackend.text : ThemeBackend.surface0
                        tintAmount: row.isAdded ? 0.1 : 0.3
                        tintStrength: row.isAdded ? 1.0 : 0.5
                        press: rowMa.pressed ? 0.8 : (row.isAdded ? 0.6 : 0.2)
                    }

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: pickerPopup.s(8)
                        anchors.rightMargin: pickerPopup.s(8)
                        spacing: pickerPopup.s(8)

                        Rectangle {
                            implicitWidth: pickerPopup.s(28)
                            implicitHeight: pickerPopup.s(28)
                            Layout.alignment: Qt.AlignVCenter
                            radius: Math.round(pickerPopup.s(28) * 0.28)
                            color: iconGlass.active ? "transparent" : (row.isAdded ? Qt.tint(ThemeBackend.surface0, Qt.rgba(ThemeBackend.mauve.r, ThemeBackend.mauve.g, ThemeBackend.mauve.b, 0.2)) : ThemeBackend.surface0)

                            GlassFill {
                                id: iconGlass
                                anchors.fill: parent
                                radius: parent.radius
                                forceClear: row.isAdded
                                tintColor: row.isAdded ? ThemeBackend.text : ThemeBackend.surface2
                                tintAmount: row.isAdded ? 0.1 : 0.3
                            }

                            Text {
                                anchors.centerIn: parent
                                text: row.modelData.icon !== "" ? row.modelData.icon : "󰏘"
                                font.family: ThemeBackend.fontFamily
                                font.pixelSize: pickerPopup.s(14)
                                color: row.isAdded ? (rowGlass.active ? ThemeBackend.text : ThemeBackend.mauve) : ThemeBackend.text
                            }
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            Layout.alignment: Qt.AlignVCenter
                            spacing: pickerPopup.s(1)

                            Text {
                                text: row.modelData.name
                                font.family: ThemeBackend.fontFamily
                                font.pixelSize: pickerPopup.s(11)
                                font.weight: row.isAdded ? Font.Bold : Font.Medium
                                color: row.isAdded ? row.contentOnAdded : ThemeBackend.text
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                                Behavior on color { ColorAnimation { duration: 150 } }
                            }

                            Text {
                                text: row.modelData.outputs.length > 0 ? row.modelData.outputs[0] : row.modelData.id
                                font.family: ThemeBackend.fontFamily
                                font.pixelSize: pickerPopup.s(9)
                                color: row.isAdded ? row.contentOnAdded : ThemeBackend.subtext0
                                opacity: row.isAdded ? 0.9 : 0.85
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
                            AppTheming.setEnabled(row.modelData.id, !row.isAdded);
                        }
                    }
                }

                Item {
                    anchors.fill: parent
                    visible: idsModel.count === 0

                    Text {
                        anchors.centerIn: parent
                        text: AppTheming.loaded ? I18n.t("guide.dock.picker.empty") : I18n.t("guide.theme.apps.loading")
                        font.family: ThemeBackend.fontFamily
                        font.pixelSize: pickerPopup.s(11)
                        color: ThemeBackend.subtext0
                    }
                }
            }
        }
    }
}
