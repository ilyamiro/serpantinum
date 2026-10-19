import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import "../"
import "../reusables"
import "../reusables/buttons"

Rectangle {
    id: sidebar
    required property var popup
    property alias searchInput: settingsSearchInput
    property alias searchResults: searchResultsList
    property alias tabsView: tabsFlickable
    property alias tabsItems: tabsRepeater
    property Item hoverItem: null
    x: I18n.rtl ? (parent.width - width) : 0
    anchors.top: parent.top
    anchors.bottom: parent.bottom
    readonly property real targetWidth: popup.searchActive ? popup.s(340) : popup.s(260)
    width: targetWidth
    
    topLeftRadius: !I18n.rtl ? ThemeBackend.clampedBorderRadius : 0
    bottomLeftRadius: !I18n.rtl ? ThemeBackend.clampedBorderRadius : 0
    topRightRadius: I18n.rtl ? ThemeBackend.clampedBorderRadius : 0
    bottomRightRadius: I18n.rtl ? ThemeBackend.clampedBorderRadius : 0
    
    color: sidebarGlass.active ? "transparent" : Qt.alpha(ThemeBackend.surface0, 0.4)
    opacity: popup.introSidebar

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
    transform: Translate { x: (I18n.rtl ? popup.s(30) : popup.s(-30)) * (1.0 - popup.introSidebar) }

    Behavior on width {
        NumberAnimation {
            id: sidebarWidthAnim
            duration: 240
            easing.type: Easing.OutCubic
        }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: popup.s(16)
        spacing: popup.s(10)

        Item {
            id: searchHeader
            Layout.fillWidth: true
            implicitHeight: popup.s(36)
            Layout.preferredHeight: popup.s(36)

            Text {
                id: settingsTitleText
                x: I18n.rtl ? (parent.width - width) : 0
                anchors.verticalCenter: parent.verticalCenter
                horizontalAlignment: I18n.textAlignment
                text: I18n.t("guide.settings", "Settings")
                font.family: ThemeBackend.fontFamily
                font.pixelSize: popup.s(15)
                font.bold: true
                color: ThemeBackend.text
                opacity: popup.searchActive ? 0.0 : 1.0
                scale: popup.searchActive ? 0.92 : 1.0
                visible: opacity > 0.001

                Behavior on opacity {
                    NumberAnimation {
                        duration: 180
                        easing.type: Easing.OutCubic
                    }
                }
                Behavior on scale {
                    NumberAnimation {
                        duration: 220
                        easing.type: Easing.OutCubic
                    }
                }
            }

            Item {
                id: searchMorphBox
                property real openProgress: popup.searchActive ? 1.0 : 0.0
                Behavior on openProgress { NumberAnimation { duration: 240; easing.type: Easing.OutCubic } }

                x: I18n.rtl ? 0 : (parent.width - width)
                anchors.verticalCenter: parent.verticalCenter
                width: popup.s(36) + (parent.width - popup.s(36)) * openProgress
                height: popup.s(36)
                clip: true

                Input {
                    id: settingsSearchInput
                    anchors.fill: parent
                    implicitHeight: popup.s(36)
                    placeholderText: I18n.t("guide.search.placeholder", "Search settings...")
                    fontPixelSize: popup.s(12)
                    baseColor: Qt.alpha(ThemeBackend.surface0, 0.7)
                    accentColor: ThemeBackend.mauve
                    textColor: ThemeBackend.text
                    subTextColor: ThemeBackend.subtext0
                    borderColor: Qt.alpha(ThemeBackend.surface2, 0.5)
                    cornerRadius: ThemeBackend.borderRadius
                    opacity: popup.searchActive ? 1.0 : 0.0
                    visible: opacity > 0.001
                    enabled: popup.searchActive

                    Behavior on opacity {
                        NumberAnimation {
                            duration: 180
                            easing.type: Easing.OutCubic
                        }
                    }

                    onTextEdited: (txt) => {
                        popup.searchQuery = txt;
                        popup.searchSelectedIndex = -1;
                    }

                    Keys.onEscapePressed: (event) => {
                        popup.closeSearch();
                        event.accepted = true;
                    }
                    Keys.onDownPressed: (event) => {
                        popup.navigateSearch(1);
                        event.accepted = true;
                    }
                    Keys.onUpPressed: (event) => {
                        popup.navigateSearch(-1);
                        event.accepted = true;
                    }
                    Keys.onReturnPressed: (event) => {
                        popup.activateSelectedSearch();
                        event.accepted = true;
                    }
                    Keys.onEnterPressed: (event) => {
                        popup.activateSelectedSearch();
                        event.accepted = true;
                    }
                }

                IconButton {
                    id: closeSearchBtn
                    anchors.right: parent.right
                    anchors.rightMargin: popup.s(4)
                    anchors.verticalCenter: parent.verticalCenter
                    size: popup.s(28)
                    cornerRadius: popup.s(6)
                    buttonIcon: "󰅖"
                    iconFontSize: popup.s(14)
                    accentColor: "transparent"
                    textColor: ThemeBackend.subtext0
                    visible: opacity > 0.001
                    opacity: popup.searchActive ? 1.0 : 0.0
                    enabled: popup.searchActive
                    z: 3

                    Behavior on opacity { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }

                    onClicked: popup.closeSearch()
                }

                IconButton {
                    id: searchBtn
                    anchors.left: parent.left
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    width: popup.s(36)
                    size: popup.s(36)
                    cornerRadius: ThemeBackend.borderRadius
                    buttonIcon: "󰍉"
                    iconFontSize: popup.s(16)
                    glassShadow: 0
                    accentColor: Qt.alpha(ThemeBackend.surface0, 0.7)
                    textColor: ThemeBackend.text
                    visible: opacity > 0.001
                    opacity: popup.searchActive ? 0.0 : 1.0
                    enabled: !popup.searchActive

                    Behavior on opacity {
                        NumberAnimation {
                            duration: 180
                            easing.type: Easing.OutCubic
                        }
                    }

                    onClicked: {
                        popup.openSearch();
                    }
                }
            }
        }

        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true

            GuideSearchResults {
                id: searchResultsList
                popup: sidebar.popup
            }

            Flickable {
                id: tabsFlickable
                anchors.fill: parent
                visible: opacity > 0.001
                opacity: popup.searchActive ? 0.0 : 1.0
                contentHeight: tabsCol.implicitHeight + popup.s(20)
                contentWidth: width
                clip: true
                boundsBehavior: Flickable.StopAtBounds

                Behavior on opacity { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }

                ScrollBar.vertical: ScrollBar {
                    active: tabsFlickable.moving || tabsFlickable.movingVertically
                    width: popup.s(4)
                    policy: ScrollBar.AsNeeded
                    contentItem: Rectangle {
                        implicitWidth: popup.s(4)
                        radius: popup.s(2)
                        color: ThemeBackend.surface2
                    }
                }

                Rectangle {
                    id: activeHighlight
                    z: 0
                    visible: !popup.searchActive || opacity > 0.001
                    radius: ThemeBackend.borderRadius
                    color: activeGlass.active ? "transparent" : ThemeBackend.mauve

                    GlassFill {
                        id: activeGlass
                        anchors.fill: parent
                        radius: parent.radius
                        tintColor: ThemeBackend.mauve
                        tintAmount: 0.5
                        press: 0.3 + 0.7 * activeHighlight.lift
                    }

                    readonly property bool isMoving: Math.abs(x - targetX) > 0.5 || Math.abs(y - targetY) > 0.5 || Math.abs(width - targetW) > 0.5 || Math.abs(height - targetH) > 0.5
                    property real lift: (activeGlass.active && isMoving) ? 1.0 : 0.0
                    Behavior on lift { NumberAnimation { duration: 240; easing.type: Easing.OutCubic } }
                    scale: 1.0 + 0.04 * lift

                    property Item activeGroupItem: (popup.currentTab >= 0 && tabsRepeater && popup.currentTab < tabsRepeater.count) ? tabsRepeater.itemAt(popup.currentTab) : null
                    property bool isSubActive: popup.currentTab === popup.expandedTab && popup.expandedTab !== -1

                    property real targetX: isSubActive ? (I18n.rtl ? 0 : popup.s(26)) : 0
                    property real targetY: {
                        let baseY = activeGroupItem ? activeGroupItem.y : (popup.currentTab * (popup.s(44) + popup.s(4)));
                        if (isSubActive) {
                            return baseY + popup.s(44) + popup.s(4) + popup.currentSubTab * (popup.s(36) + popup.s(4));
                        }
                        return baseY;
                    }
                    property real targetW: isSubActive ? (tabsCol.width - popup.s(26)) : tabsCol.width
                    property real targetH: isSubActive ? popup.s(36) : popup.s(44)

                    x: targetX
                    y: targetY
                    width: targetW
                    height: targetH

                    opacity: popup.getTabOpacity(popup.currentTab)
                    transform: Translate { x: (I18n.rtl ? popup.s(24) : popup.s(-24)) * (1.0 - popup.getTabProgress(popup.currentTab)) }

                    Behavior on x { enabled: !sidebarWidthAnim.running; NumberAnimation { duration: 250; easing.type: Easing.OutQuint } }
                    Behavior on y { enabled: !sidebarWidthAnim.running; NumberAnimation { duration: 250; easing.type: Easing.OutQuint } }
                    Behavior on width { enabled: !sidebarWidthAnim.running; NumberAnimation { duration: 250; easing.type: Easing.OutQuint } }
                    Behavior on height { enabled: !sidebarWidthAnim.running; NumberAnimation { duration: 250; easing.type: Easing.OutQuint } }
                }

                GlassLens {
                    id: hoverLens
                    z: -1
                    readonly property rect hoverRect: {
                        void tabsCol.implicitHeight;
                        void tabsCol.width;
                        if (!sidebar.hoverItem) return Qt.rect(0, 0, 0, 0);
                        const p = sidebar.hoverItem.mapToItem(tabsFlickable.contentItem, 0, 0);
                        return Qt.rect(p.x, p.y, sidebar.hoverItem.width, sidebar.hoverItem.height);
                    }
                    targetX: hoverRect.x
                    targetY: hoverRect.y
                    targetWidth: hoverRect.width
                    targetHeight: hoverRect.height
                    radius: ThemeBackend.borderRadius
                    tintColor: ThemeBackend.surface1
                    tintAmount: 0.25
                    shadow: 0
                    restPress: 0.2
                    magnify: popup.s(4)
                    press: sidebar.hoverItem && sidebar.hoverItem.pressed ? 0.8 : 0
                }

                ColumnLayout {
                    id: tabsCol
                    width: tabsFlickable.width - (tabsFlickable.contentHeight > tabsFlickable.height ? popup.s(6) : 0)
                    spacing: popup.s(4)

                    readonly property var tabItems: tabsRepeater

                    Repeater {
                        id: tabsRepeater
                        model: popup.tabsModel
                        delegate: ColumnLayout {
                            id: tabDelegate
                            required property var modelData
                            required property int index

                            readonly property int tabIndex: index
                            readonly property bool hasSubtabs: Boolean(modelData.subtabs && modelData.subtabs.length > 0)
                            readonly property bool isExpanded: hasSubtabs && popup.expandedTab === tabIndex
                            readonly property real fullSubtabsHeight: hasSubtabs ? (modelData.subtabs.length * popup.s(36) + (modelData.subtabs.length - 1) * popup.s(4) + popup.s(8)) : 0
                            property real expandProgress: isExpanded ? 1.0 : 0.0

                            Behavior on expandProgress {
                                NumberAnimation { duration: 250; easing.type: Easing.OutCubic }
                            }

                            Layout.fillWidth: true
                            spacing: 0

                            opacity: popup.getTabOpacity(tabIndex)
                            transform: Translate { x: popup.s(-24) * (1.0 - popup.getTabProgress(tabIndex)) }

                            Rectangle {
                                id: tabHeaderItem
                                Layout.fillWidth: true
                                Layout.preferredHeight: popup.s(44)
                                implicitHeight: popup.s(44)
                                radius: ThemeBackend.borderRadius
                                z: 1

                                property bool isDirectActive: tabDelegate.hasSubtabs ? (popup.currentTab === tabDelegate.tabIndex && !tabDelegate.isExpanded) : (popup.currentTab === tabDelegate.tabIndex)
                                readonly property bool pressed: tabHeaderMa.pressed
                                readonly property bool lensWanted: tabHeaderMa.containsMouse && !isDirectActive

                                onLensWantedChanged: {
                                    if (lensWanted) sidebar.hoverItem = tabHeaderItem;
                                    else if (sidebar.hoverItem === tabHeaderItem) sidebar.hoverItem = null;
                                }
                                Component.onDestruction: {
                                    if (sidebar.hoverItem === tabHeaderItem) sidebar.hoverItem = null;
                                }

                                color: (tabHoverGlass.active || hoverLens.glassActive || !(tabHeaderMa.containsMouse && !isDirectActive)) ? "transparent" : Qt.alpha(ThemeBackend.surface1, 0.5)
                                Behavior on color { ColorAnimation { duration: 150 } }

                                GlassFill {
                                    id: tabHoverGlass
                                    anchors.fill: parent
                                    radius: parent.radius
                                    allowed: tabHeaderMa.containsMouse && !tabHeaderItem.isDirectActive && !hoverLens.glassActive
                                    tintColor: ThemeBackend.surface1
                                    tintAmount: 0.25
                                    press: tabHeaderMa.pressed ? 0.8 : 0.2
                                }

                                scale: tabHeaderMa.pressed ? 0.98 : 1.0
                                Behavior on scale { NumberAnimation { duration: 250; easing.type: Easing.OutQuint } }

                                RowLayout {
                                    layoutDirection: I18n.layoutDirection
                                    anchors.fill: parent
                                    anchors.leftMargin: I18n.rtl ? popup.s(14) : (popup.s(10) + (tabHeaderItem.isDirectActive ? popup.s(4) : 0))
                                    anchors.rightMargin: I18n.rtl ? (popup.s(10) + (tabHeaderItem.isDirectActive ? popup.s(4) : 0)) : popup.s(14)
                                    spacing: popup.s(10)

                                    Behavior on anchors.leftMargin { NumberAnimation { duration: 400; easing.type: Easing.OutQuint } }
                                    Behavior on anchors.rightMargin { NumberAnimation { duration: 400; easing.type: Easing.OutQuint } }

                                    IconButton {
                                        enabled: false
                                        size: popup.s(32)
                                        Layout.preferredWidth: popup.s(32)
                                        Layout.preferredHeight: popup.s(32)
                                        Layout.alignment: Qt.AlignVCenter
                                        cornerRadius: ThemeBackend.borderRadius
                                        buttonIcon: tabDelegate.modelData.icon || "󰒓"
                                        iconFontSize: popup.s(16)
                                        accentColor: ThemeBackend.surface0
                                        textColor: "#ffffff"
                                    }

                                    Text {
                                        text: I18n.t("guide.tabs." + (tabDelegate.modelData.key || tabDelegate.modelData.id).toLowerCase(), tabDelegate.modelData.name || tabDelegate.modelData.id)
                                        font.family: ThemeBackend.fontFamily
                                        font.weight: tabHeaderItem.isDirectActive ? Font.Bold : Font.Medium
                                        font.pixelSize: popup.s(13)
                                        color: tabHeaderItem.isDirectActive 
                                            ? (activeGlass.active ? ThemeBackend.text : ThemeBackend.crust)
                                            : (tabHeaderMa.containsMouse ? ThemeBackend.text : ThemeBackend.subtext0)
                                        Layout.fillWidth: true
                                        Layout.alignment: Qt.AlignVCenter
                                        horizontalAlignment: I18n.textAlignment
                                        elide: Text.ElideRight
                                        Behavior on color { ColorAnimation { duration: 150 } }
                                    }

                                    Text {
                                        visible: tabDelegate.hasSubtabs
                                        text: "󰅀"
                                        font.family: ThemeBackend.iconFont
                                        font.pixelSize: popup.s(14)
                                        color: tabHeaderItem.isDirectActive 
                                            ? (activeGlass.active ? ThemeBackend.text : ThemeBackend.crust)
                                            : (tabHeaderMa.containsMouse ? ThemeBackend.text : ThemeBackend.subtext0)
                                        Layout.alignment: Qt.AlignVCenter
                                        rotation: tabDelegate.expandProgress * 180 - 180
                                        Behavior on rotation { NumberAnimation { duration: 250; easing.type: Easing.OutCubic } }
                                        Behavior on color { ColorAnimation { duration: 150 } }
                                    }
                                }

                                MouseArea {
                                    id: tabHeaderMa
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
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
                                id: subtabsWrapper
                                visible: tabDelegate.hasSubtabs && tabDelegate.expandProgress > 0.001
                                Layout.fillWidth: true
                                Layout.preferredHeight: tabDelegate.fullSubtabsHeight * tabDelegate.expandProgress
                                implicitHeight: tabDelegate.fullSubtabsHeight * tabDelegate.expandProgress
                                opacity: Math.max(0.0, (tabDelegate.expandProgress - 0.15) / 0.85)
                                clip: true

                                RowLayout {
                                    layoutDirection: I18n.layoutDirection
                                    anchors.fill: parent
                                    anchors.topMargin: popup.s(4)
                                    anchors.bottomMargin: popup.s(4)
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
                                            model: tabDelegate.hasSubtabs ? tabDelegate.modelData.subtabs : []
                                            delegate: Rectangle {
                                                id: subtabItem
                                                required property var modelData
                                                required property int index

                                                readonly property int subIndex: index
                                                readonly property int parentIndex: tabDelegate.tabIndex

                                                Layout.fillWidth: true
                                                Layout.preferredHeight: popup.s(36)
                                                implicitHeight: popup.s(36)
                                                radius: ThemeBackend.borderRadius
                                                z: 1

                                                property bool isSubActive: popup.currentTab === parentIndex && popup.expandedTab === parentIndex && popup.currentSubTab === subIndex
                                                readonly property bool pressed: subtabMa.pressed
                                                readonly property bool lensWanted: subtabMa.containsMouse && !isSubActive

                                                onLensWantedChanged: {
                                                    if (lensWanted) sidebar.hoverItem = subtabItem;
                                                    else if (sidebar.hoverItem === subtabItem) sidebar.hoverItem = null;
                                                }
                                                Component.onDestruction: {
                                                    if (sidebar.hoverItem === subtabItem) sidebar.hoverItem = null;
                                                }

                                                color: (subHoverGlass.active || hoverLens.glassActive || !(subtabMa.containsMouse && !isSubActive)) ? "transparent" : Qt.alpha(ThemeBackend.surface1, 0.5)
                                                Behavior on color { ColorAnimation { duration: 150 } }

                                                GlassFill {
                                                    id: subHoverGlass
                                                    anchors.fill: parent
                                                    radius: parent.radius
                                                    allowed: subtabMa.containsMouse && !subtabItem.isSubActive && !hoverLens.glassActive
                                                    tintColor: ThemeBackend.surface1
                                                    tintAmount: 0.25
                                                    press: subtabMa.pressed ? 0.8 : 0.2
                                                }

                                                scale: subtabMa.pressed ? 0.98 : 1.0
                                                Behavior on scale { NumberAnimation { duration: 250; easing.type: Easing.OutQuint } }

                                                RowLayout {
                                                    layoutDirection: I18n.layoutDirection
                                                    anchors.fill: parent
                                                    anchors.leftMargin: I18n.rtl ? popup.s(10) : (popup.s(8) + (subtabItem.isSubActive ? popup.s(4) : 0))
                                                    anchors.rightMargin: I18n.rtl ? (popup.s(8) + (subtabItem.isSubActive ? popup.s(4) : 0)) : popup.s(10)
                                                    spacing: popup.s(8)

                                                    Behavior on anchors.leftMargin { NumberAnimation { duration: 300; easing.type: Easing.OutQuint } }
                                                    Behavior on anchors.rightMargin { NumberAnimation { duration: 300; easing.type: Easing.OutQuint } }

                                                    IconButton {
                                                        enabled: false
                                                        size: popup.s(26)
                                                        Layout.preferredWidth: popup.s(26)
                                                        Layout.preferredHeight: popup.s(26)
                                                        Layout.alignment: Qt.AlignVCenter
                                                        cornerRadius: ThemeBackend.borderRadius
                                                        buttonIcon: subtabItem.modelData.icon || "󰒓"
                                                        iconFontSize: popup.s(13)
                                                        accentColor: ThemeBackend.surface0
                                                        textColor: "#ffffff"
                                                    }

                                                    Text {
                                                        text: I18n.t("guide.tabs." + (subtabItem.modelData.key || subtabItem.modelData.id).toLowerCase(), subtabItem.modelData.name || subtabItem.modelData.id)
                                                        font.family: ThemeBackend.fontFamily
                                                        font.weight: subtabItem.isSubActive ? Font.Bold : Font.Medium
                                                        font.pixelSize: popup.s(12)
                                                        color: subtabItem.isSubActive ? (activeGlass.active ? ThemeBackend.text : ThemeBackend.crust) : ThemeBackend.subtext0
                                                        Layout.fillWidth: true
                                                        Layout.alignment: Qt.AlignVCenter
                                                        horizontalAlignment: I18n.textAlignment
                                                        elide: Text.ElideRight
                                                        Behavior on color { ColorAnimation { duration: 150 } }
                                                    }
                                                }

                                                MouseArea {
                                                    id: subtabMa
                                                    anchors.fill: parent
                                                    hoverEnabled: true
                                                    cursorShape: Qt.PointingHandCursor
                                                    onClicked: {
                                                        popup.currentTab = parentIndex;
                                                        popup.expandedTab = parentIndex;
                                                        popup.currentSubTab = subIndex;
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

        ClickButton {
            visible: Updater.updateAvailable && !popup.searchActive
            Layout.fillWidth: true
            implicitHeight: popup.s(38)
            cornerRadius: ThemeBackend.borderRadius
            buttonText: I18n.t("guide.update_available")
            buttonIcon: "󰚰"
            iconFontSize: popup.s(16)
            textFontSize: popup.s(13)
            accentColor: ThemeBackend.green
            textColor: ThemeBackend.crust
            opacity: popup.getTabOpacity(popup.tabsModel.length)
            transform: Translate { x: popup.s(-24) * (1.0 - popup.getTabProgress(popup.tabsModel.length)) }
            onClicked: {
                popup.gotoTab("about");
            }
        }
    }
}
