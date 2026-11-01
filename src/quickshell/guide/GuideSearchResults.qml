import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import "../"
import "../reusables"
import "../reusables/buttons"

Flickable {
    id: searchResultsFlickable
    required property var popup
    property alias column: searchResultsCol
    visible: popup.searchActive
    contentHeight: searchResultsCol.implicitHeight + popup.s(10)
    contentWidth: width
    clip: true
    boundsBehavior: Flickable.StopAtBounds


    ScrollBar.vertical: ScrollBar {
        active: searchResultsFlickable.moving || searchResultsFlickable.movingVertically
        width: popup.s(4)
        policy: ScrollBar.AsNeeded
        contentItem: Rectangle {
            implicitWidth: popup.s(4)
            radius: popup.s(2)
            color: ThemeBackend.surface2
        }
    }

    ColumnLayout {
        id: searchResultsCol
        width: parent.width
        spacing: popup.s(8)

        Text {
            visible: popup.searchActive && popup.searchQuery.trim() === ""
            Layout.fillWidth: true
            Layout.topMargin: popup.s(24)
            horizontalAlignment: Text.AlignHCenter
            text: I18n.t("guide.search.prompt", "Type to search settings...")
            font.family: ThemeBackend.fontFamily
            font.pixelSize: popup.s(12)
            color: ThemeBackend.subtext0
        }

        Text {
            visible: popup.searchActive && popup.searchQuery.trim() !== "" && popup.filteredSearchResults.length === 0
            Layout.fillWidth: true
            Layout.topMargin: popup.s(24)
            horizontalAlignment: Text.AlignHCenter
            text: I18n.t("guide.search.no_results", "No settings found")
            font.family: ThemeBackend.fontFamily
            font.pixelSize: popup.s(12)
            color: ThemeBackend.subtext0
        }

        Repeater {
            id: searchTabsRepeater
            model: popup.groupedSearchResults
            delegate: ColumnLayout {
                id: tabGroup
                required property var modelData
                required property int index

                Layout.fillWidth: true
                spacing: popup.s(4)

                Rectangle {
                    id: tabHeaderItem
                    Layout.fillWidth: true
                    Layout.preferredHeight: popup.s(44)
                    implicitHeight: popup.s(44)
                    radius: ThemeBackend.borderRadius
                    z: 1

                    color: (searchTabHoverGlass.active || !tabHeaderItemMa.containsMouse) ? "transparent" : Qt.alpha(ThemeBackend.surface1, 0.5)
                    Behavior on color { ColorAnimation { duration: 150 } }

                    GlassFill {
                        id: searchTabHoverGlass
                        anchors.fill: parent
                        radius: parent.radius
                        allowed: tabHeaderItemMa.containsMouse
                        tintColor: ThemeBackend.surface1
                        tintAmount: 0.25
                        press: tabHeaderItemMa.pressed ? 0.8 : 0.2
                    }

                    scale: tabHeaderItemMa.pressed ? 0.98 : 1.0
                    Behavior on scale { NumberAnimation { duration: 250; easing.type: Easing.OutQuint } }

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: popup.s(10)
                        anchors.rightMargin: popup.s(14)
                        spacing: popup.s(10)

                        IconButton {
                            enabled: false
                            size: popup.s(32)
                            Layout.preferredWidth: popup.s(32)
                            Layout.preferredHeight: popup.s(32)
                            Layout.alignment: Qt.AlignVCenter
                            cornerRadius: ThemeBackend.borderRadius
                            buttonIcon: tabGroup.modelData.icon || "󰒓"
                            iconFontSize: popup.s(16)
                            accentColor: ThemeBackend.surface0
                            textColor: "#ffffff"
                        }

                        Text {
                            text: tabGroup.modelData.title
                            font.family: ThemeBackend.fontFamily
                            font.weight: Font.Medium
                            font.pixelSize: popup.s(13)
                            color: tabHeaderItemMa.containsMouse ? ThemeBackend.text : ThemeBackend.subtext0
                            Layout.fillWidth: true
                            Layout.alignment: Qt.AlignVCenter
                            elide: Text.ElideRight
                            Behavior on color { ColorAnimation { duration: 150 } }
                        }
                    }

                    MouseArea {
                        id: tabHeaderItemMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            popup.gotoTab(tabGroup.modelData.tabKey);
                            popup.closeSearch();
                        }
                    }
                }

                RowLayout {
                    id: tabIndentRow
                    visible: (tabGroup.modelData.directItems.length + tabGroup.modelData.subgroups.length) > 0
                    Layout.fillWidth: true
                    spacing: popup.s(6)

                    Item {
                        Layout.preferredWidth: popup.s(20)
                        Layout.fillHeight: true

                        Rectangle {
                            anchors.horizontalCenter: parent.horizontalCenter
                            anchors.top: parent.top
                            anchors.bottom: parent.bottom
                            anchors.topMargin: popup.s(2)
                            anchors.bottomMargin: popup.s(2)
                            width: Math.max(1, popup.s(2))
                            radius: popup.s(1)
                            color: Qt.rgba(ThemeBackend.surface2.r, ThemeBackend.surface2.g, ThemeBackend.surface2.b, 0.7)
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: popup.s(4)

                        Repeater {
                            id: directItemsRepeater
                            model: tabGroup.modelData.directItems
                            delegate: Rectangle {
                                id: directItemRow
                                required property var modelData
                                required property int index

                                property bool isSelected: false
                                Component.onCompleted: isSelected = Qt.binding(function() {
                                    if (!popup || !directItemRow.modelData) return false;
                                    let sel = popup.flatSearchResults[popup.searchSelectedIndex];
                                    return !!sel && (sel === directItemRow.modelData || sel.key === directItemRow.modelData.key || sel.id === directItemRow.modelData.id);
                                })

                                onIsSelectedChanged: {
                                    if (isSelected) {
                                        popup.ensureSearchItemVisible(directItemRow);
                                    }
                                }

                                Layout.fillWidth: true
                                implicitHeight: (directItemRow.modelData && (directItemRow.modelData.desc || directItemRow.modelData.description)) ? popup.s(48) : popup.s(38)
                                radius: ThemeBackend.borderRadius
                                readonly property color legacyColor: directItemRow.isSelected
                                    ? ThemeBackend.mauve
                                    : (directItemMa.containsMouse ? Qt.alpha(ThemeBackend.surface1, 0.6) : Qt.alpha(ThemeBackend.surface0, 0.35))
                                color: ThemeBackend.liquidGlass ? "transparent" : legacyColor

                                Loader {
                                    anchors.fill: parent
                                    active: ThemeBackend.liquidGlass
                                    sourceComponent: GlassFill {
                                    id: directItemRowGlass
                                    anchors.fill: parent
                                    radius: parent.radius
                                    tintColor: directItemRow.isSelected ? ThemeBackend.mauve : ThemeBackend.surface0
                                    tintAmount: directItemRow.isSelected ? 0.85 : 0.25
                                    tintStrength: directItemRow.isSelected ? 1.0 : 0.5
                                    press: directItemMa.pressed ? 0.8 : (directItemMa.containsMouse ? 0.2 : 0)
                                }
                                }

                                Behavior on color { ColorAnimation { duration: 150 } }

                                MouseArea {
                                    id: directItemMa
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: popup.selectSearchResult(directItemRow.modelData)
                                }

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: popup.s(8) + (directItemRow.isSelected ? popup.s(4) : 0)
                                    anchors.rightMargin: popup.s(8)
                                    anchors.topMargin: popup.s(6)
                                    anchors.bottomMargin: popup.s(6)
                                    spacing: popup.s(8)

                                    Behavior on anchors.leftMargin { NumberAnimation { duration: 250; easing.type: Easing.OutQuint } }

                                    Rectangle {
                                        Layout.preferredWidth: popup.s(28)
                                        Layout.preferredHeight: popup.s(28)
                                        Layout.alignment: Qt.AlignVCenter
                                        radius: popup.s(6)
                                        color: ThemeBackend.surface0
                                        Text {
                                            anchors.centerIn: parent
                                            text: directItemRow.modelData.icon || "󰒓"
                                            font.family: ThemeBackend.iconFont
                                            font.pixelSize: popup.s(14)
                                            color: "#ffffff"
                                        }
                                    }

                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        Layout.alignment: Qt.AlignVCenter
                                        spacing: 0

                                        Text {
                                            Layout.fillWidth: true
                                            text: popup.resolveI18nText(directItemRow.modelData.title)
                                            font.family: ThemeBackend.fontFamily
                                            font.pixelSize: popup.s(12)
                                            font.bold: true
                                            color: (directItemRow.isSelected && !ThemeBackend.liquidGlass) ? ThemeBackend.crust : ThemeBackend.text
                                            elide: Text.ElideRight

                                            Behavior on color { ColorAnimation { duration: 150 } }
                                        }

                                        Text {
                                            Layout.fillWidth: true
                                            text: popup.resolveI18nText(directItemRow.modelData.desc || directItemRow.modelData.description || "")
                                            visible: text !== ""
                                            font.family: ThemeBackend.fontFamily
                                            font.pixelSize: popup.s(10)
                                            color: (directItemRow.isSelected && !ThemeBackend.liquidGlass) ? Qt.alpha(ThemeBackend.crust, 0.75) : ThemeBackend.subtext0
                                            elide: Text.ElideRight

                                            Behavior on color { ColorAnimation { duration: 150 } }
                                        }
                                    }
                                }
                            }
                        }

                        Repeater {
                            id: subGroupRepeater
                            model: tabGroup.modelData.subgroups
                            delegate: ColumnLayout {
                                id: subGroup
                                required property var modelData
                                required property int index

                                Layout.fillWidth: true
                                spacing: popup.s(4)

                                Rectangle {
                                    id: subtabHeaderItem
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: popup.s(36)
                                    implicitHeight: popup.s(36)
                                    radius: ThemeBackend.borderRadius
                                    z: 1

                                    color: (searchSubHoverGlass.active || !subtabHeaderItemMa.containsMouse) ? "transparent" : Qt.alpha(ThemeBackend.surface1, 0.5)
                                    Behavior on color { ColorAnimation { duration: 150 } }

                                    GlassFill {
                                        id: searchSubHoverGlass
                                        anchors.fill: parent
                                        radius: parent.radius
                                        allowed: subtabHeaderItemMa.containsMouse
                                        tintColor: ThemeBackend.surface1
                                        tintAmount: 0.25
                                        press: subtabHeaderItemMa.pressed ? 0.8 : 0.2
                                    }

                                    scale: subtabHeaderItemMa.pressed ? 0.98 : 1.0
                                    Behavior on scale { NumberAnimation { duration: 250; easing.type: Easing.OutQuint } }

                                    RowLayout {
                                        anchors.fill: parent
                                        anchors.leftMargin: popup.s(8)
                                        anchors.rightMargin: popup.s(10)
                                        spacing: popup.s(8)

                                        IconButton {
                                            enabled: false
                                            size: popup.s(26)
                                            Layout.preferredWidth: popup.s(26)
                                            Layout.preferredHeight: popup.s(26)
                                            Layout.alignment: Qt.AlignVCenter
                                            cornerRadius: ThemeBackend.borderRadius
                                            buttonIcon: subGroup.modelData.icon || "󰒓"
                                            iconFontSize: popup.s(13)
                                            accentColor: ThemeBackend.surface0
                                            textColor: "#ffffff"
                                        }

                                        Text {
                                            text: subGroup.modelData.title
                                            font.family: ThemeBackend.fontFamily
                                            font.weight: Font.Medium
                                            font.pixelSize: popup.s(12)
                                            color: subtabHeaderItemMa.containsMouse ? ThemeBackend.text : ThemeBackend.subtext0
                                            Layout.fillWidth: true
                                            Layout.alignment: Qt.AlignVCenter
                                            elide: Text.ElideRight
                                            Behavior on color { ColorAnimation { duration: 150 } }
                                        }
                                    }

                                    MouseArea {
                                        id: subtabHeaderItemMa
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            popup.gotoTab(tabGroup.modelData.tabKey, subGroup.modelData.subKey);
                                            popup.closeSearch();
                                        }
                                    }
                                }

                                RowLayout {
                                    id: subIndentRow
                                    visible: subGroup.modelData.items.length > 0
                                    Layout.fillWidth: true
                                    spacing: popup.s(6)

                                    Item {
                                        Layout.preferredWidth: popup.s(20)
                                        Layout.fillHeight: true

                                        Rectangle {
                                            anchors.horizontalCenter: parent.horizontalCenter
                                            anchors.top: parent.top
                                            anchors.bottom: parent.bottom
                                            anchors.topMargin: popup.s(2)
                                            anchors.bottomMargin: popup.s(2)
                                            width: Math.max(1, popup.s(2))
                                            radius: popup.s(1)
                                            color: Qt.rgba(ThemeBackend.surface2.r, ThemeBackend.surface2.g, ThemeBackend.surface2.b, 0.7)
                                        }
                                    }

                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        spacing: popup.s(4)

                                        Repeater {
                                            id: subGroupItemsRepeater
                                            model: subGroup.modelData.items
                                            delegate: Rectangle {
                                                id: subItemRow
                                                required property var modelData
                                                required property int index

                                                property bool isSelected: false
                                                Component.onCompleted: isSelected = Qt.binding(function() {
                                                    if (!popup || !subItemRow.modelData) return false;
                                                    let sel = popup.flatSearchResults[popup.searchSelectedIndex];
                                                    return !!sel && (sel === subItemRow.modelData || sel.key === subItemRow.modelData.key || sel.id === subItemRow.modelData.id);
                                                })

                                                onIsSelectedChanged: {
                                                    if (isSelected) {
                                                        popup.ensureSearchItemVisible(subItemRow);
                                                    }
                                                }

                                                Layout.fillWidth: true
                                                implicitHeight: (subItemRow.modelData && (subItemRow.modelData.desc || subItemRow.modelData.description)) ? popup.s(48) : popup.s(38)
                                                radius: ThemeBackend.borderRadius
                                                readonly property color legacyColor: subItemRow.isSelected
                                                    ? ThemeBackend.mauve
                                                    : (subItemMa.containsMouse ? Qt.alpha(ThemeBackend.surface1, 0.6) : Qt.alpha(ThemeBackend.surface0, 0.35))
                                                color: ThemeBackend.liquidGlass ? "transparent" : legacyColor

                                                Loader {
                                    anchors.fill: parent
                                    active: ThemeBackend.liquidGlass
                                    sourceComponent: GlassFill {
                                                    id: subItemRowGlass
                                                    anchors.fill: parent
                                                    radius: parent.radius
                                                    tintColor: subItemRow.isSelected ? ThemeBackend.mauve : ThemeBackend.surface0
                                                    tintAmount: subItemRow.isSelected ? 0.85 : 0.25
                                                    tintStrength: subItemRow.isSelected ? 1.0 : 0.5
                                                    press: subItemMa.pressed ? 0.8 : (subItemMa.containsMouse ? 0.2 : 0)
                                                }
                                }

                                                Behavior on color { ColorAnimation { duration: 150 } }

                                                MouseArea {
                                                    id: subItemMa
                                                    anchors.fill: parent
                                                    hoverEnabled: true
                                                    cursorShape: Qt.PointingHandCursor
                                                    onClicked: popup.selectSearchResult(subItemRow.modelData)
                                                }

                                                RowLayout {
                                                    anchors.fill: parent
                                                    anchors.leftMargin: popup.s(8) + (subItemRow.isSelected ? popup.s(4) : 0)
                                                    anchors.rightMargin: popup.s(8)
                                                    anchors.topMargin: popup.s(6)
                                                    anchors.bottomMargin: popup.s(6)
                                                    spacing: popup.s(8)

                                                    Behavior on anchors.leftMargin { NumberAnimation { duration: 250; easing.type: Easing.OutQuint } }

                                                    Rectangle {
                                        Layout.preferredWidth: popup.s(28)
                                        Layout.preferredHeight: popup.s(28)
                                        Layout.alignment: Qt.AlignVCenter
                                        radius: popup.s(6)
                                        color: ThemeBackend.surface0
                                        Text {
                                            anchors.centerIn: parent
                                            text: subItemRow.modelData.icon || "󰒓"
                                            font.family: ThemeBackend.iconFont
                                            font.pixelSize: popup.s(14)
                                            color: "#ffffff"
                                        }
                                    }

                                                    ColumnLayout {
                                                        Layout.fillWidth: true
                                                        Layout.alignment: Qt.AlignVCenter
                                                        spacing: 0

                                                        Text {
                                                            Layout.fillWidth: true
                                                            text: popup.resolveI18nText(subItemRow.modelData.title)
                                                            font.family: ThemeBackend.fontFamily
                                                            font.pixelSize: popup.s(12)
                                                            font.bold: true
                                                            color: (subItemRow.isSelected && !ThemeBackend.liquidGlass) ? ThemeBackend.crust : ThemeBackend.text
                                                            elide: Text.ElideRight

                                                            Behavior on color { ColorAnimation { duration: 150 } }
                                                        }

                                                        Text {
                                                            Layout.fillWidth: true
                                                            text: popup.resolveI18nText(subItemRow.modelData.desc || subItemRow.modelData.description || "")
                                                            visible: text !== ""
                                                            font.family: ThemeBackend.fontFamily
                                                            font.pixelSize: popup.s(10)
                                                            color: (subItemRow.isSelected && !ThemeBackend.liquidGlass) ? Qt.alpha(ThemeBackend.crust, 0.75) : ThemeBackend.subtext0
                                                            elide: Text.ElideRight

                                                            Behavior on color { ColorAnimation { duration: 150 } }
                                                        }
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
