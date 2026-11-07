import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import "../"
import "../reusables"
import "../reusables/buttons"

Rectangle {
    id: sidebar
    required property var popup
    property alias tabsView: tabsFlickable
    property alias tabsItems: tabsRepeater

    readonly property int curTab: popup ? popup.currentTab : -1
    readonly property int expTab: popup ? popup.expandedTab : -1
    readonly property int curSub: popup ? popup.currentSubTab : -1
    readonly property real headerH: popup.s(40)
    readonly property real subH: popup.s(36)
    readonly property real gap: popup.s(2)
    readonly property real subIndent: popup.compact ? 0 : popup.s(20)
    readonly property real iconBox: popup.s(24)
    readonly property color activeColor: ThemeBackend.mauve
    readonly property color idleColor: ThemeBackend.subtext1
    readonly property color hoverFill: Qt.alpha(ThemeBackend.text, 0.06)

    function itemRadius(h) {
        return Math.min(h / 2, ThemeBackend.borderRadius);
    }

    x: I18n.rtl ? (parent.width - width) : 0
    anchors.top: parent.top
    anchors.bottom: parent.bottom
    width: popup.compact ? popup.s(64) : popup.s(232)
    color: sidebarGlass.active ? "transparent" : Qt.alpha(ThemeBackend.surface0, 0.4)

    topLeftRadius: !I18n.rtl ? ThemeBackend.clampedBorderRadius : 0
    bottomLeftRadius: !I18n.rtl ? ThemeBackend.clampedBorderRadius : 0
    topRightRadius: I18n.rtl ? ThemeBackend.clampedBorderRadius : 0
    bottomRightRadius: I18n.rtl ? ThemeBackend.clampedBorderRadius : 0

    Behavior on width { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }

    opacity: popup.introSidebar
    transform: Translate { x: (I18n.rtl ? popup.s(30) : popup.s(-30)) * (1.0 - popup.introSidebar) }

    GlassFill {
        id: sidebarGlass
        anchors.fill: parent
        topLeftRadius: sidebar.topLeftRadius
        topRightRadius: sidebar.topRightRadius
        bottomLeftRadius: sidebar.bottomLeftRadius
        bottomRightRadius: sidebar.bottomRightRadius
        tintColor: ThemeBackend.surface0
        tintAmount: 0.2
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: popup.s(12)
        spacing: popup.s(8)

        RowLayout {
            layoutDirection: I18n.layoutDirection
            Layout.fillWidth: true
            Layout.preferredHeight: popup.s(40)
            spacing: popup.s(8)

            Text {
                visible: !popup.compact
                Layout.fillWidth: true
                Layout.leftMargin: popup.s(10)
                horizontalAlignment: I18n.textAlignment
                text: I18n.t("guide.settings", "Settings")
                font.family: ThemeBackend.fontFamily
                font.pixelSize: popup.s(15)
                font.bold: true
                color: ThemeBackend.text
            }

            Item { visible: popup.compact; Layout.fillWidth: true }

            IconButton {
                id: searchBtn
                size: popup.s(34)
                Layout.preferredWidth: popup.s(34)
                Layout.preferredHeight: popup.s(34)
                Layout.alignment: Qt.AlignVCenter
                cornerRadius: ThemeBackend.borderRadius
                buttonIcon: "󰍉"
                iconFontSize: popup.s(16)
                glassShadow: 0
                accentColor: popup.searchActive ? Qt.alpha(ThemeBackend.mauve, 0.16) : Qt.alpha(ThemeBackend.surface0, 0.7)
                textColor: popup.searchActive ? ThemeBackend.mauve : ThemeBackend.text
                onClicked: popup.searchActive ? popup.closeSearch() : popup.openSearch()
            }

            Item { visible: popup.compact; Layout.fillWidth: true }
        }

        Flickable {
            id: tabsFlickable
            Layout.fillWidth: true
            Layout.fillHeight: true
            contentHeight: tabsCol.implicitHeight + popup.s(8)
            contentWidth: width
            clip: true
            boundsBehavior: Flickable.StopAtBounds

            Rectangle {
                id: activeHighlight
                z: -1
                radius: sidebar.itemRadius(height)
                color: activeGlass.active ? "transparent" : Qt.alpha(sidebar.activeColor, 0.16)
                visible: activeDelegate !== null
                property bool ready: false
                Timer { interval: 500; running: true; onTriggered: activeHighlight.ready = true }

                GlassFill {
                    id: activeGlass
                    anchors.fill: parent
                    radius: parent.radius
                    tintColor: sidebar.activeColor
                    tintAmount: 0.22
                    press: 0.3 + 0.7 * activeHighlight.lift
                }

                readonly property bool isMoving: Math.abs(y - targetY) > 0.5 || Math.abs(subMix - (isSub ? 1 : 0)) > 0.01
                property real lift: (activeGlass.active && isMoving) ? 1.0 : 0.0
                Behavior on lift { NumberAnimation { duration: 250; easing.type: Easing.OutCubic } }
                scale: 1.0 + 0.04 * lift
                opacity: popup.getTabOpacity(sidebar.curTab)
                transform: Translate { x: (I18n.rtl ? popup.s(24) : popup.s(-24)) * (1.0 - popup.getTabProgress(sidebar.curTab)) }

                readonly property Item activeDelegate: { void tabsRepeater.count; return (sidebar.curTab >= 0) ? tabsRepeater.itemAt(sidebar.curTab) : null; }
                readonly property bool isSub: sidebar.curTab === sidebar.expTab && sidebar.expTab !== -1
                readonly property real baseY: activeDelegate ? activeDelegate.y + activeDelegate.sepH : 0
                readonly property real subIndent: sidebar.subIndent
                property real subMix: isSub ? 1.0 : 0.0
                Behavior on subMix { enabled: activeHighlight.ready; NumberAnimation { duration: 250; easing.type: Easing.OutQuint } }
                readonly property real targetX: subIndent * subMix
                readonly property real targetY: isSub ? baseY + sidebar.headerH + popup.s(4) + sidebar.curSub * (sidebar.subH + sidebar.gap) : baseY
                readonly property real targetW: tabsCol.width - subIndent * subMix
                readonly property real targetH: isSub ? sidebar.subH : sidebar.headerH

                x: targetX
                y: targetY
                width: targetW
                height: targetH

                Behavior on y { enabled: activeHighlight.ready; NumberAnimation { duration: 250; easing.type: Easing.OutQuint } }
                Behavior on height { enabled: activeHighlight.ready; NumberAnimation { duration: 250; easing.type: Easing.OutQuint } }
            }

            ColumnLayout {
                id: tabsCol
                width: tabsFlickable.width
                spacing: sidebar.gap

                Repeater {
                    id: tabsRepeater
                    model: popup.tabsModel
                    delegate: ColumnLayout {
                        id: tabDelegate
                        required property var modelData
                        required property int index

                        readonly property int tabIndex: index
                        opacity: popup.getTabOpacity(tabIndex)
                        transform: Translate { x: (I18n.rtl ? popup.s(24) : popup.s(-24)) * (1.0 - popup.getTabProgress(tabIndex)) }
                        readonly property bool hasSubtabs: Boolean(modelData.subtabs && modelData.subtabs.length > 0)
                        readonly property bool isExpanded: hasSubtabs && sidebar.expTab === tabIndex
                        readonly property real fullSubtabsHeight: hasSubtabs ? (modelData.subtabs.length * sidebar.subH + (modelData.subtabs.length - 1) * sidebar.gap + popup.s(8)) : 0
                        readonly property real sepH: modelData.separatorBefore ? popup.s(14) + 1 : 0
                        property real expandProgress: isExpanded ? 1.0 : 0.0
                        Behavior on expandProgress { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }

                        Layout.fillWidth: true
                        spacing: 0

                        Rectangle {
                            Layout.fillWidth: true
                            Layout.topMargin: popup.s(6)
                            Layout.bottomMargin: popup.s(8)
                            Layout.leftMargin: popup.s(10)
                            Layout.rightMargin: popup.s(10)
                            Layout.preferredHeight: 1
                            visible: !!tabDelegate.modelData.separatorBefore
                            color: Qt.alpha(ThemeBackend.surface2, 0.4)
                        }

                        Rectangle {
                            id: header
                            Layout.fillWidth: true
                            Layout.preferredHeight: sidebar.headerH
                            radius: sidebar.itemRadius(height)
                            property bool active: false
                            Component.onCompleted: active = Qt.binding(() => tabDelegate.hasSubtabs ? (sidebar.curTab === tabDelegate.tabIndex && !tabDelegate.isExpanded) : (sidebar.curTab === tabDelegate.tabIndex))
                            readonly property color fg: active ? sidebar.activeColor : (headerMa.containsMouse ? ThemeBackend.text : sidebar.idleColor)
                            color: (!active && headerMa.containsMouse && !headerHoverGlass.active) ? sidebar.hoverFill : "transparent"
                            Behavior on color { ColorAnimation { duration: 90 } }


                            GlassFill {
                                id: headerHoverGlass
                                anchors.fill: parent
                                radius: parent.radius
                                allowed: headerMa.containsMouse && !header.active
                                tintColor: ThemeBackend.surface1
                                tintAmount: 0.25
                                press: headerMa.pressed ? 0.8 : 0.2
                            }

                            RowLayout {
                                layoutDirection: I18n.layoutDirection
                                anchors.fill: parent
                                anchors.leftMargin: popup.compact ? (header.width - sidebar.iconBox) / 2 : popup.s(14)
                                anchors.rightMargin: popup.compact ? (header.width - sidebar.iconBox) / 2 : popup.s(14)
                                spacing: popup.s(12)

                                Text {
                                    Layout.preferredWidth: sidebar.iconBox
                                    Layout.alignment: Qt.AlignVCenter
                                    horizontalAlignment: Text.AlignHCenter
                                    text: tabDelegate.modelData.icon || "󰒓"
                                    font.family: ThemeBackend.iconFont
                                    font.pixelSize: popup.s(18)
                                    color: header.fg
                                    Behavior on color { ColorAnimation { duration: 90 } }
                                }

                                Text {
                                    visible: !popup.compact
                                    text: I18n.t("guide.tabs." + (tabDelegate.modelData.key || tabDelegate.modelData.id).toLowerCase(), tabDelegate.modelData.name || tabDelegate.modelData.id)
                                    font.family: ThemeBackend.fontFamily
                                    font.weight: Font.Medium
                                    font.pixelSize: popup.s(13)
                                    color: header.fg
                                    Layout.fillWidth: true
                                    Layout.alignment: Qt.AlignVCenter
                                    horizontalAlignment: I18n.textAlignment
                                    elide: Text.ElideRight
                                    Behavior on color { ColorAnimation { duration: 90 } }
                                }

                                Text {
                                    visible: tabDelegate.hasSubtabs && !popup.compact
                                    text: "󰅀"
                                    font.family: ThemeBackend.iconFont
                                    font.pixelSize: popup.s(16)
                                    color: header.fg
                                    Layout.alignment: Qt.AlignVCenter
                                    rotation: tabDelegate.expandProgress * 180
                                }
                            }

                            MouseArea {
                                id: headerMa
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    popup.closeSearch();
                                    popup.forceActiveFocus();
                                    if (tabDelegate.hasSubtabs) {
                                        if (popup.expandedTab === tabDelegate.tabIndex) {
                                            popup.expandedTab = -1;
                                        } else {
                                            popup.expandedTab = tabDelegate.tabIndex;
                                            if (popup.currentTab !== tabDelegate.tabIndex) {
                                                popup.currentTab = tabDelegate.tabIndex;
                                                popup.currentSubTab = 0;
                                            }
                                        }
                                    } else {
                                        popup.expandedTab = -1;
                                        popup.currentTab = tabDelegate.tabIndex;
                                        popup.currentSubTab = 0;
                                    }
                                }
                            }
                        }

                        Item {
                            visible: tabDelegate.hasSubtabs && tabDelegate.expandProgress > 0.001
                            Layout.fillWidth: true
                            Layout.preferredHeight: tabDelegate.fullSubtabsHeight * tabDelegate.expandProgress
                            opacity: Math.max(0.0, (tabDelegate.expandProgress - 0.15) / 0.85)
                            clip: true

                            Rectangle {
                                anchors.fill: parent
                                anchors.topMargin: popup.s(2)
                                anchors.bottomMargin: popup.s(2)
                                radius: ThemeBackend.borderRadius
                                color: Qt.alpha(ThemeBackend.surface1, 0.45)
                                visible: popup.compact
                            }

                            ColumnLayout {
                                anchors.fill: parent
                                anchors.topMargin: popup.s(4)
                                anchors.bottomMargin: popup.s(4)
                                anchors.leftMargin: I18n.rtl ? 0 : sidebar.subIndent
                                anchors.rightMargin: I18n.rtl ? sidebar.subIndent : 0
                                spacing: sidebar.gap

                                    Repeater {
                                        model: tabDelegate.hasSubtabs ? tabDelegate.modelData.subtabs : []
                                        delegate: Rectangle {
                                            id: sub
                                            required property var modelData
                                            required property int index

                                            Layout.fillWidth: true
                                            Layout.preferredHeight: sidebar.subH
                                            radius: sidebar.itemRadius(height)

                                            readonly property int subIndex: index
                                            readonly property int parentIndex: tabDelegate.tabIndex
                                            property bool isCurrent: false
                                            Component.onCompleted: isCurrent = Qt.binding(() => sidebar.curTab === parentIndex && sidebar.expTab === parentIndex && sidebar.curSub === subIndex)
                                            readonly property color fg: isCurrent ? sidebar.activeColor : (subMa.containsMouse ? ThemeBackend.text : sidebar.idleColor)
                                            color: (!isCurrent && subMa.containsMouse && !subHoverGlass.active) ? sidebar.hoverFill : "transparent"
                                            Behavior on color { ColorAnimation { duration: 90 } }


                                            GlassFill {
                                                id: subHoverGlass
                                                anchors.fill: parent
                                                radius: parent.radius
                                                allowed: subMa.containsMouse && !sub.isCurrent
                                                tintColor: ThemeBackend.surface1
                                                tintAmount: 0.25
                                                press: subMa.pressed ? 0.8 : 0.2
                                            }

                                            RowLayout {
                                                layoutDirection: I18n.layoutDirection
                                                anchors.fill: parent
                                                anchors.leftMargin: popup.compact ? (sub.width - sidebar.iconBox) / 2 : popup.s(14)
                                                anchors.rightMargin: popup.compact ? (sub.width - sidebar.iconBox) / 2 : popup.s(14)
                                                spacing: popup.s(12)

                                                Text {
                                                    Layout.preferredWidth: sidebar.iconBox
                                                    Layout.alignment: Qt.AlignVCenter
                                                    horizontalAlignment: Text.AlignHCenter
                                                    text: sub.modelData.icon || "󰒓"
                                                    font.family: ThemeBackend.iconFont
                                                    font.pixelSize: popup.s(16)
                                                    color: sub.fg
                                                    Behavior on color { ColorAnimation { duration: 90 } }
                                                }

                                                Text {
                                                    visible: !popup.compact
                                                    text: I18n.t("guide.tabs." + (sub.modelData.key || sub.modelData.id).toLowerCase(), sub.modelData.name || sub.modelData.id)
                                                    font.family: ThemeBackend.fontFamily
                                                    font.weight: Font.Medium
                                                    font.pixelSize: popup.s(13)
                                                    color: sub.fg
                                                    Layout.fillWidth: true
                                                    Layout.alignment: Qt.AlignVCenter
                                                    horizontalAlignment: I18n.textAlignment
                                                    elide: Text.ElideRight
                                                    Behavior on color { ColorAnimation { duration: 90 } }
                                                }
                                            }

                                            MouseArea {
                                                id: subMa
                                                anchors.fill: parent
                                                hoverEnabled: true
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: {
                                                    popup.closeSearch();
                                                    popup.forceActiveFocus();
                                                    popup.currentTab = tabDelegate.tabIndex;
                                                    popup.expandedTab = tabDelegate.tabIndex;
                                                    popup.currentSubTab = sub.index;
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

        ClickButton {
            visible: Updater.updateAvailable
            Layout.fillWidth: true
            implicitHeight: popup.s(38)
            cornerRadius: ThemeBackend.borderRadius
            buttonText: popup.compact ? "" : I18n.t("guide.update_available")
            buttonIcon: "󰚰"
            iconFontSize: popup.s(16)
            textFontSize: popup.s(13)
            accentColor: ThemeBackend.green
            textColor: ThemeBackend.crust
            onClicked: popup.gotoTab("about")
        }
    }
}
