import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import "../"
import "../reusables"

Item {
    id: appPicker
    required property var dockWindow
    required property var dockContainer
    property alias pickerSearchInput: pickerSearchInput

    visible: dockWindow.editMode || opacity > 0.001
    opacity: dockWindow.editMode ? 1.0 : 0.0
    scale: dockWindow.editMode ? 1.0 : 0.94
    z: 100

    Behavior on opacity {
        enabled: dockWindow.initialized && !dockWindow.positionChanging
        NumberAnimation { duration: 260; easing.type: Easing.OutCubic }
    }
    Behavior on scale {
        enabled: dockWindow.initialized && !dockWindow.positionChanging
        NumberAnimation { duration: 280; easing.type: Easing.OutBack; easing.overshoot: 1.1 }
    }

    width: Math.min(dockWindow.effectiveWindowWidth - dockWindow.s(16), dockWindow.isVertical ? dockWindow.s(320) : dockWindow.s(480))

    readonly property int maxPickerItems: dockWindow.isVertical ? 9 : 6
    property int targetItemCount: {
        if (dockWindow.pickerFilteredModel.count > 0) {
            return Math.min(dockWindow.pickerFilteredModel.count, maxPickerItems);
        }
        return maxPickerItems;
    }
    property real targetPickerHeight: dockWindow.s(70) + (targetItemCount * dockWindow.s(48))
    property real animatedPickerHeight: targetPickerHeight
    Behavior on animatedPickerHeight {
        enabled: dockWindow.initialized && !dockWindow.positionChanging
        NumberAnimation { duration: 250; easing.type: Easing.OutCubic }
    }

    height: animatedPickerHeight

    x: {
        if (!dockWindow.isVertical) return Math.round((dockWindow.effectiveWindowWidth - width) / 2);
        if (dockWindow.dockPosition === "left") {
            return Math.round(dockContainer.x + dockContainer.width + dockWindow.s(12));
        }
        if (dockWindow.dockPosition === "right") {
            return Math.round(dockContainer.x - width - dockWindow.s(12));
        }
        return Math.round((dockWindow.effectiveWindowWidth - width) / 2);
    }

    y: {
        if (dockWindow.isVertical) return Math.round((dockWindow.effectiveWindowHeight - height) / 2);
        if (dockWindow.dockPosition === "top") {
            return Math.round(dockContainer.y + dockContainer.height + dockWindow.s(12));
        }
        if (dockWindow.dockPosition === "bottom") {
            return Math.round(dockContainer.y - height - dockWindow.s(12));
        }
        return Math.round((dockWindow.effectiveWindowHeight - height) / 2);
    }

    Rectangle {
        anchors.fill: parent
        radius: ThemeBackend.borderRadius <= 16 ? ThemeBackend.borderRadius * 1.5 : 24
        color: Qt.alpha(ThemeBackend.base, ThemeBackend.elementOpacity)
        border.width: ThemeBackend.liquidGlass ? 0 : 1
        border.color: Qt.alpha(ThemeBackend.surface1, 0.45)
        clip: true

        WallpaperBlur {
            z: -1
            anchors.fill: parent
            radius: parent.radius
            standalone: true
        }

        Item {
            id: pickerContent
            anchors.fill: parent
            anchors.margins: dockWindow.s(12)

            readonly property bool isSearchAtBottom: dockWindow.dockPosition === "top"

            RowLayout {
                id: pickerSearchRow
                anchors.left: parent.left
                anchors.right: parent.right
                y: pickerContent.isSearchAtBottom ? (parent.height - height) : 0
                height: dockWindow.s(34)
                spacing: dockWindow.s(8)

                Input {
                    id: pickerSearchInput
                    Layout.fillWidth: true
                    Layout.preferredHeight: dockWindow.s(34)
                    placeholderText: I18n.t("guide.dock.picker.search", "Search apps...")
                    baseColor: ThemeBackend.surface0
                    bgOpacity: ThemeBackend.glassActive ? 0.0 : 1.0
                    accentColor: ThemeBackend.mauve
                    textColor: ThemeBackend.text
                    subTextColor: ThemeBackend.subtext0
                    borderColor: Qt.alpha(ThemeBackend.surface2, 0.6)
                    cornerRadius: ThemeBackend.borderRadius
                    fontPixelSize: dockWindow.s(11)
                    showClearButton: true
                    focus: dockWindow.editMode
                    onTextEdited: function(newText) {
                        dockWindow.filterPickerApps(newText);
                    }
                    onCleared: {
                        dockWindow.filterPickerApps("");
                    }
                    Keys.onEscapePressed: function(event) {
                        dockWindow.setEditMode(false);
                        event.accepted = true;
                    }
                }

                ClickButton {
                    implicitHeight: dockWindow.s(34)
                    maxWidth: dockWindow.s(70)
                    cornerRadius: ThemeBackend.borderRadius
                    buttonText: I18n.t("guide.dock.picker.done", "Done")
                    accentColor: ThemeBackend.mauve
                    textColor: ThemeBackend.liquidGlass ? ThemeBackend.text : ThemeBackend.crust
                    textFontSize: dockWindow.s(11)
                    onClicked: {
                        dockWindow.setEditMode(false);
                    }
                }
            }

            Rectangle {
                id: pickerDivider
                anchors.left: parent.left
                anchors.right: parent.right
                y: pickerContent.isSearchAtBottom
                   ? (pickerSearchRow.y - dockWindow.s(10) - height)
                   : (pickerSearchRow.y + pickerSearchRow.height + dockWindow.s(10))
                height: 1
                color: Qt.alpha(ThemeBackend.surface1, 0.3)
            }

            Item {
                id: pickerListWrapper
                anchors.left: parent.left
                anchors.right: parent.right
                y: pickerContent.isSearchAtBottom ? 0 : (pickerDivider.y + pickerDivider.height + dockWindow.s(10))
                height: pickerContent.isSearchAtBottom
                        ? Math.max(0, pickerDivider.y - dockWindow.s(10))
                        : Math.max(0, parent.height - y)
                clip: true

                ListView {
                    id: pickerListView
                    anchors.fill: parent
                    clip: true
                    model: dockWindow.pickerFilteredModel
                    spacing: dockWindow.s(4)
                    boundsBehavior: Flickable.StopAtBounds
                    property Item hoverItem: null

                    GlassLens {
                        id: pickerLensItem
                        z: -1
                        targetX: pickerListView.hoverItem ? pickerListView.hoverItem.x : 0
                        targetY: pickerListView.hoverItem ? pickerListView.hoverItem.y : 0
                        targetWidth: pickerListView.hoverItem ? pickerListView.hoverItem.width : 0
                        targetHeight: pickerListView.hoverItem ? pickerListView.hoverItem.height : 0
                        radius: ThemeBackend.borderRadius
                        tintColor: ThemeBackend.surface0
                        tintAmount: 0.3
                        shadow: 0
                        restPress: 0.2
                        magnify: dockWindow.s(4)
                        press: pickerListView.hoverItem && pickerListView.hoverItem.pressed ? 0.8 : 0
                    }

                    ScrollBar.vertical: ScrollBar {
                        active: parent.moving || parent.movingVertically
                        width: dockWindow.s(4)
                        policy: ScrollBar.AsNeeded
                        contentItem: Rectangle {
                            implicitWidth: dockWindow.s(4)
                            radius: dockWindow.s(2)
                            color: ThemeBackend.surface2
                        }
                    }

                    delegate: DockPickerRow {
                        dockWindow: appPicker.dockWindow
                        pickerList: pickerListView
                        pickerLens: pickerLensItem
                    }

                    Item {
                        anchors.fill: parent
                        visible: dockWindow.pickerFilteredModel.count === 0

                        Text {
                            anchors.centerIn: parent
                            text: I18n.t("guide.dock.picker.empty", "No matching applications")
                            font.family: ThemeBackend.fontFamily
                            font.pixelSize: dockWindow.s(11)
                            color: ThemeBackend.subtext0
                        }
                    }
                }
            }
        }
    }
}
