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
    contentHeight: searchResultsCol.implicitHeight + popup.s(10)
    contentWidth: width
    clip: true
    boundsBehavior: Flickable.StopAtBounds

    ScrollBar.vertical: StyledScrollBar {
        rootObj: searchResultsFlickable.popup
    }

    component SearchGroupHeader: Rectangle {
        id: headerRoot
        required property string title
        property string icon: "󰒓"
        property real rowHeight: popup.s(44)
        property real iconSize: popup.s(32)
        property real iconFontSize: popup.s(16)
        property real titleFontSize: popup.s(13)
        property real leftPad: popup.s(10)
        property real rightPad: popup.s(14)
        property real rowSpacing: popup.s(10)
        signal activated()

        Layout.fillWidth: true
        Layout.preferredHeight: rowHeight
        implicitHeight: rowHeight
        radius: ThemeBackend.borderRadius
        z: 1

        color: (headerGlass.active || !headerMa.containsMouse) ? "transparent" : Qt.alpha(ThemeBackend.surface1, 0.5)
        Behavior on color { ColorAnimation { duration: 150 } }

        GlassFill {
            id: headerGlass
            anchors.fill: parent
            radius: parent.radius
            allowed: headerMa.containsMouse
            tintColor: ThemeBackend.surface1
            tintAmount: 0.25
            press: headerMa.pressed ? 0.8 : 0.2
        }

        scale: headerMa.pressed ? 0.98 : 1.0
        Behavior on scale { NumberAnimation { duration: 250; easing.type: Easing.OutQuint } }

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: headerRoot.leftPad
            anchors.rightMargin: headerRoot.rightPad
            spacing: headerRoot.rowSpacing

            IconButton {
                enabled: false
                size: headerRoot.iconSize
                Layout.preferredWidth: headerRoot.iconSize
                Layout.preferredHeight: headerRoot.iconSize
                Layout.alignment: Qt.AlignVCenter
                cornerRadius: ThemeBackend.borderRadius
                buttonIcon: headerRoot.icon || "󰒓"
                iconFontSize: headerRoot.iconFontSize
                accentColor: "transparent"
                textColor: ThemeBackend.subtext0
            }

            Text {
                text: headerRoot.title
                font.family: ThemeBackend.fontFamily
                font.weight: Font.Medium
                font.pixelSize: headerRoot.titleFontSize
                color: headerMa.containsMouse ? ThemeBackend.text : ThemeBackend.subtext0
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignVCenter
                elide: Text.ElideRight
                Behavior on color { ColorAnimation { duration: 150 } }
            }
        }

        MouseArea {
            id: headerMa
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: headerRoot.activated()
        }
    }

    component SearchResultRow: Rectangle {
        id: itemRow
        required property var modelData
        required property int index

        property bool isSelected: false
        Component.onCompleted: isSelected = Qt.binding(function() {
            if (!popup || !itemRow.modelData) return false;
            let sel = popup.flatSearchResults[popup.searchSelectedIndex];
            return !!sel && (sel === itemRow.modelData || sel.key === itemRow.modelData.key || sel.id === itemRow.modelData.id);
        })

        onIsSelectedChanged: {
            if (isSelected) {
                popup.ensureSearchItemVisible(itemRow);
            }
        }

        Layout.fillWidth: true
        implicitHeight: (itemRow.modelData && itemRow.modelData.desc) ? popup.s(48) : popup.s(38)
        radius: ThemeBackend.borderRadius
        readonly property color legacyColor: itemRow.isSelected
            ? Qt.alpha(ThemeBackend.mauve, 0.16)
            : (itemMa.containsMouse ? Qt.alpha(ThemeBackend.surface1, 0.6) : Qt.alpha(ThemeBackend.surface0, 0.35))
        color: ThemeBackend.liquidGlass ? "transparent" : legacyColor

        Loader {
            anchors.fill: parent
            active: ThemeBackend.liquidGlass
            sourceComponent: GlassFill {
                anchors.fill: parent
                radius: itemRow.radius
                tintColor: itemRow.isSelected ? ThemeBackend.mauve : ThemeBackend.surface0
                tintAmount: itemRow.isSelected ? 0.22 : 0.25
                tintStrength: 0.5
                press: itemMa.pressed ? 0.8 : (itemMa.containsMouse ? 0.2 : 0)
            }
        }

        Behavior on color { ColorAnimation { duration: 150 } }

        MouseArea {
            id: itemMa
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: popup.selectSearchResult(itemRow.modelData)
        }

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: popup.s(8) + (itemRow.isSelected ? popup.s(4) : 0)
            anchors.rightMargin: popup.s(8)
            anchors.topMargin: popup.s(6)
            anchors.bottomMargin: popup.s(6)
            spacing: popup.s(8)

            Behavior on anchors.leftMargin { NumberAnimation { duration: 250; easing.type: Easing.OutQuint } }

            IconButton {
                enabled: false
                size: popup.s(28)
                Layout.preferredWidth: popup.s(28)
                Layout.preferredHeight: popup.s(28)
                Layout.alignment: Qt.AlignVCenter
                cornerRadius: ThemeBackend.borderRadius
                buttonIcon: itemRow.modelData.icon || "󰒓"
                iconFontSize: popup.s(14)
                accentColor: "transparent"
                textColor: itemRow.isSelected ? ThemeBackend.mauve : ThemeBackend.subtext0
            }

            ColumnLayout {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignVCenter
                spacing: 0

                Text {
                    Layout.fillWidth: true
                    text: popup.highlightSearchText(popup.searchItemTitle(itemRow.modelData), itemRow.isSelected)
                    textFormat: Text.StyledText
                    font.family: ThemeBackend.fontFamily
                    font.pixelSize: popup.s(12)
                    font.bold: true
                    color: itemRow.isSelected ? ThemeBackend.mauve : ThemeBackend.text
                    elide: Text.ElideRight
                    Behavior on color { ColorAnimation { duration: 150 } }
                }

                Text {
                    Layout.fillWidth: true
                    text: popup.highlightSearchText(popup.resolveI18nText(itemRow.modelData.desc || ""), itemRow.isSelected)
                    textFormat: Text.StyledText
                    visible: popup.resolveI18nText(itemRow.modelData.desc || "") !== ""
                    font.family: ThemeBackend.fontFamily
                    font.pixelSize: popup.s(10)
                    color: ThemeBackend.subtext0
                    elide: Text.ElideRight
                    Behavior on color { ColorAnimation { duration: 150 } }
                }
            }
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

        RowLayout {
            visible: popup.searchActive && !popup.searchIndexReady && popup.searchQuery.trim() !== ""
            Layout.alignment: Qt.AlignHCenter
            Layout.topMargin: popup.filteredSearchResults.length === 0 ? popup.s(24) : popup.s(6)
            Layout.bottomMargin: popup.s(4)
            spacing: popup.s(8)

            LoaderIcon {
                Layout.preferredWidth: popup.s(18)
                Layout.preferredHeight: popup.s(18)
                Layout.alignment: Qt.AlignVCenter
                running: parent.visible
                accentColor: ThemeBackend.mauve
            }

            Text {
                text: I18n.t("guide.search.indexing", "Indexing settings...")
                font.family: ThemeBackend.fontFamily
                font.pixelSize: popup.s(12)
                color: ThemeBackend.subtext0
                Layout.alignment: Qt.AlignVCenter
            }
        }

        Text {
            visible: popup.searchActive && popup.searchIndexReady && popup.searchQuery.trim() !== "" && popup.filteredSearchResults.length === 0
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

                SearchGroupHeader {
                    title: tabGroup.modelData.title
                    icon: tabGroup.modelData.icon || "󰒓"
                    onActivated: {
                        popup.gotoTab(tabGroup.modelData.tabKey);
                        popup.closeSearch();
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
                            delegate: SearchResultRow {}
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

                                SearchGroupHeader {
                                    title: subGroup.modelData.title
                                    icon: subGroup.modelData.icon || "󰒓"
                                    rowHeight: popup.s(36)
                                    iconSize: popup.s(26)
                                    iconFontSize: popup.s(13)
                                    titleFontSize: popup.s(12)
                                    leftPad: popup.s(8)
                                    rightPad: popup.s(10)
                                    rowSpacing: popup.s(8)
                                    onActivated: {
                                        popup.gotoTab(tabGroup.modelData.tabKey, subGroup.modelData.subKey);
                                        popup.closeSearch();
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
                                            delegate: SearchResultRow {}
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
