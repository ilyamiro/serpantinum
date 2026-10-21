import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import "../"
import "../reusables"
import "../reusables/guide"

Item {
    id: dockTabRoot
    required property var rootObj
    required property int tabIndex

    anchors.fill: parent
    visible: rootObj.currentTab === tabIndex
    opacity: visible ? 1.0 : 0.0
    property real slideY: visible ? 0 : rootObj.s(10)

    Behavior on slideY { NumberAnimation { duration: 250; easing.type: Easing.OutQuart } }
    transform: Translate { y: slideY }
    Behavior on opacity { NumberAnimation { duration: 250 } }

    property var defaultDockSettings: ({
        "enabled": true,
        "position": "bottom",
        "onTop": true,
        "elementSize": 44,
        "floating": false,
        "opacity": 100,
        "exclusive": false,
        "autohide": false,
        "smartAutohide": true,
        "autohideTimeout": 1000,
        "editing": false,
        "apps": [],
        "overrideBoundsCorrection": false,
        "enableScrolling": false,
        "visibleElements": 7,
        "hoverScale": 120,
        "cascadeScale": false,
        "focusRunning": true,
        "showRunningIndicators": true,
        "showRunningApps": true,
        "runningScope": "auto"
    })

    property var dockSettings: {
        let s = (typeof Config !== "undefined" && Config.rawSettings) ? Config.rawSettings["dock"] : undefined;
        if (s !== undefined && s !== null) return s;
        if (typeof Config !== "undefined" && typeof Config.getSetting === "function") {
            return Config.getSetting("dock", dockTabRoot.defaultDockSettings);
        }
        return dockTabRoot.defaultDockSettings;
    }

    property bool currentEnabled: dockSettings && dockSettings.enabled !== undefined ? dockSettings.enabled : true
    property string currentPosition: dockSettings && dockSettings.position !== undefined ? dockSettings.position : "bottom"
    property bool currentOnTop: dockSettings && dockSettings.onTop !== undefined ? Boolean(dockSettings.onTop) : true
    property bool currentFloating: dockSettings && dockSettings.floating !== undefined ? dockSettings.floating : false
    property bool currentExclusive: dockSettings && (dockSettings.exclusive !== undefined ? dockSettings.exclusive : (dockSettings.exclusiveMode !== undefined ? dockSettings.exclusiveMode : false)) ? true : false
    property real currentOpacity: {
        if (dockSettings && dockSettings.opacity !== undefined) return Number(dockSettings.opacity);
        if (dockSettings && dockSettings.transparency !== undefined) return Math.max(0, 100 - Number(dockSettings.transparency));
        return 100;
    }
    property int currentElementSize: (dockSettings && dockSettings.elementSize !== undefined && !isNaN(parseInt(dockSettings.elementSize))) ? parseInt(dockSettings.elementSize) : 44
    property bool currentOverrideBoundsCorrection: dockSettings && dockSettings.overrideBoundsCorrection !== undefined ? dockSettings.overrideBoundsCorrection : false
    property int currentHoverScale: (dockSettings && dockSettings.hoverScale !== undefined && !isNaN(parseInt(dockSettings.hoverScale))) ? parseInt(dockSettings.hoverScale) : 120
    property bool currentCascadeScale: dockSettings && dockSettings.cascadeScale !== undefined ? Boolean(dockSettings.cascadeScale) : false
    property bool currentEnableScrolling: dockSettings && dockSettings.enableScrolling !== undefined ? dockSettings.enableScrolling : false
    property int currentVisibleElements: (dockSettings && dockSettings.visibleElements !== undefined && !isNaN(parseInt(dockSettings.visibleElements)) && parseInt(dockSettings.visibleElements) > 0) ? parseInt(dockSettings.visibleElements) : 7
    property bool currentSmartAutohide: dockSettings && dockSettings.smartAutohide !== undefined ? dockSettings.smartAutohide : true
    property bool currentAutohide: dockSettings && dockSettings.autohide !== undefined ? dockSettings.autohide : false
    property int currentAutohideTimeout: (dockSettings && dockSettings.autohideTimeout !== undefined && !isNaN(parseInt(dockSettings.autohideTimeout))) ? parseInt(dockSettings.autohideTimeout) : 1000
    property bool currentEditing: dockSettings && dockSettings.editing !== undefined ? dockSettings.editing : false
    property var currentAppsList: (dockSettings && Array.isArray(dockSettings.apps)) ? dockSettings.apps : []
    property bool currentFocusRunning: dockSettings && dockSettings.focusRunning !== undefined ? Boolean(dockSettings.focusRunning) : true
    property bool currentShowRunningIndicators: dockSettings && dockSettings.showRunningIndicators !== undefined ? Boolean(dockSettings.showRunningIndicators) : true
    property bool currentShowRunningApps: dockSettings && dockSettings.showRunningApps !== undefined ? Boolean(dockSettings.showRunningApps) : false
    property string currentRunningScope: (dockSettings && dockSettings.runningScope) ? dockSettings.runningScope : "auto"

    function syncSettings() {
        let s = (typeof Config !== "undefined" && typeof Config.getSetting === "function")
            ? Config.getSetting("dock", dockTabRoot.defaultDockSettings)
            : dockTabRoot.defaultDockSettings;
        dockTabRoot.dockSettings = s;
        dockTabRoot.currentEnabled = s.enabled !== undefined ? s.enabled : true;
        dockTabRoot.currentPosition = s.position !== undefined ? s.position : "bottom";
        dockTabRoot.currentOnTop = s.onTop !== undefined ? Boolean(s.onTop) : true;
        dockTabRoot.currentFloating = s.floating !== undefined ? s.floating : false;
        dockTabRoot.currentExclusive = s.exclusive !== undefined ? s.exclusive : (s.exclusiveMode !== undefined ? Boolean(s.exclusiveMode) : false);
        dockTabRoot.currentOpacity = s.opacity !== undefined ? Number(s.opacity) : (s.transparency !== undefined ? Math.max(0, 100 - Number(s.transparency)) : 100);
        dockTabRoot.currentElementSize = (s.elementSize !== undefined && !isNaN(parseInt(s.elementSize))) ? parseInt(s.elementSize) : 44;
        dockTabRoot.currentOverrideBoundsCorrection = s.overrideBoundsCorrection !== undefined ? s.overrideBoundsCorrection : false;
        dockTabRoot.currentHoverScale = (s.hoverScale !== undefined && !isNaN(parseInt(s.hoverScale))) ? parseInt(s.hoverScale) : 120;
        dockTabRoot.currentCascadeScale = s.cascadeScale !== undefined ? Boolean(s.cascadeScale) : false;
        dockTabRoot.currentEnableScrolling = s.enableScrolling !== undefined ? s.enableScrolling : false;
        dockTabRoot.currentVisibleElements = (s.visibleElements !== undefined && !isNaN(parseInt(s.visibleElements)) && parseInt(dockSettings.visibleElements) > 0) ? parseInt(s.visibleElements) : 7;
        dockTabRoot.currentSmartAutohide = s.smartAutohide !== undefined ? s.smartAutohide : true;
        dockTabRoot.currentAutohide = s.autohide !== undefined ? s.autohide : false;
        dockTabRoot.currentAutohideTimeout = (s.autohideTimeout !== undefined && !isNaN(parseInt(s.autohideTimeout))) ? parseInt(s.autohideTimeout) : 1000;
        dockTabRoot.currentEditing = s.editing !== undefined ? s.editing : false;
        dockTabRoot.currentAppsList = (s.apps && Array.isArray(s.apps)) ? s.apps : [];
        dockTabRoot.currentFocusRunning = s.focusRunning !== undefined ? Boolean(s.focusRunning) : true;
        dockTabRoot.currentShowRunningIndicators = s.showRunningIndicators !== undefined ? Boolean(s.showRunningIndicators) : true;
        dockTabRoot.currentShowRunningApps = s.showRunningApps !== undefined ? Boolean(s.showRunningApps) : false;
        dockTabRoot.currentRunningScope = s.runningScope ? s.runningScope : "auto";
    }

    function updateDockSetting(key, value) {
        let base = (typeof Config !== "undefined" && typeof Config.getSetting === "function")
            ? Config.getSetting("dock", defaultDockSettings)
            : defaultDockSettings;
        let current = JSON.parse(JSON.stringify(base || defaultDockSettings));
        current[key] = value;
        if (typeof Config !== "undefined" && typeof Config.setSetting === "function") {
            Config.setSetting("dock", current);
        }
        dockTabRoot.dockSettings = current;
    }

    function removeApp(idx) {
        let list = dockTabRoot.currentAppsList ? dockTabRoot.currentAppsList.slice() : [];
        if (idx >= 0 && idx < list.length) {
            list.splice(idx, 1);
            dockTabRoot.currentAppsList = list;
            dockTabRoot.updateDockSetting("apps", list);
        }
    }

    Timer {
        id: dockDebounceTimer
        interval: 120
        repeat: false
        property var pendingCallback: null
        onTriggered: {
            if (pendingCallback) {
                pendingCallback();
                pendingCallback = null;
            }
        }
    }

    function triggerDebounced(cb) {
        dockDebounceTimer.pendingCallback = cb;
        dockDebounceTimer.restart();
    }

    onVisibleChanged: {
        if (visible) {
            syncSettings();
        } else {
            if (posDropdown.isOpen) posDropdown.closePopup();
        }
    }

    Component.onCompleted: syncSettings()

    Connections {
        target: typeof Config !== "undefined" ? Config : null
        function onSettingsLoaded() {
            dockTabRoot.syncSettings();
        }
    }

    Flickable {
        id: mainFlickable
        anchors.fill: parent
        anchors.topMargin: rootObj.s(8)
        anchors.leftMargin: rootObj.s(8)
        anchors.rightMargin: rootObj.s(8)
        anchors.bottomMargin: rootObj.s(8)
        contentHeight: settingsCol.implicitHeight + rootObj.s(16)
        contentWidth: width
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        ScrollBar.vertical: ScrollBar {
            active: parent.moving || parent.movingVertically
            width: rootObj.s(4)
            policy: ScrollBar.AsNeeded
            contentItem: Rectangle {
                implicitWidth: rootObj.s(4)
                radius: rootObj.s(2)
                color: ThemeBackend.surface2
            }
        }

        ColumnLayout {
            id: settingsCol
            width: parent.width - (parent.contentHeight > parent.height ? rootObj.s(6) : 0)
            spacing: rootObj.s(6)

            SettingsRow {
                settingId: "dock_enabled"
                rootObj: dockTabRoot.rootObj
                icon: "󰅀"
                title: I18n.t("guide.dock.enabled.title", "Enable dock")
                description: I18n.t("guide.dock.enabled.desc", "Enable floating application dock")

                Toggle {
                    Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                    checked: dockTabRoot.currentEnabled
                    accentColor: ThemeBackend.mauve
                    baseColor: ThemeBackend.surface1
                    handleColor: ThemeBackend.crust
                    handleOffColor: ThemeBackend.text
                    onToggled: function(val) {
                        dockTabRoot.currentEnabled = val;
                        dockTabRoot.updateDockSetting("enabled", val);
                    }
                }
            }

            Item {
                id: appsCardWrapper
                Layout.fillWidth: true
                clip: true

                readonly property bool shouldBeOpen: dockTabRoot.currentEnabled || dockAppsCard.tempVisible
                visible: height > 0.01

                implicitHeight: shouldBeOpen ? dockAppsCard.implicitHeight : 0
                Behavior on implicitHeight {
                    NumberAnimation { duration: 250; easing.type: Easing.InOutCubic }
                }

                Rectangle {
                    id: dockAppsCard
                    anchors.top: parent.top
                    anchors.left: parent.left
                    anchors.right: parent.right
                    clip: true
                    radius: ThemeBackend.borderRadius
                    color: {
                        let base = Qt.alpha(ThemeBackend.surface0, 0.4);
                        if (highlightFlash > 0.001) {
                            return Qt.tint(base, Qt.rgba(ThemeBackend.mauve.r, ThemeBackend.mauve.g, ThemeBackend.mauve.b, highlightFlash * 0.12));
                        }
                        return base;
                    }
                    border.color: Qt.alpha(ThemeBackend.surface1, 0.4)
                    border.width: 1

                    property string settingId: "dock_apps"
                    property string title: I18n.t("guide.dock.apps.title", "Dock Applications")
                    property string description: I18n.t("guide.dock.apps.desc", "Configure and organize applications displayed on the dock")
                    property string icon: "󰀻"
                    property string searchKeywords: "applications shortcuts pins favorites"
                    property bool searchable: true

                    property real highlightFlash: 0.0
                    property int handledHighlightToken: -1
                    property bool tempVisible: false

                    function ensureVisibleInFlickable() {
                        let flick = mainFlickable;
                        if (!flick) return;
                        let targetPos = dockAppsCard.mapToItem(flick.contentItem, 0, 0);
                        if (targetPos) {
                            let viewTop = flick.contentY;
                            let viewBottom = flick.contentY + flick.height;
                            if (targetPos.y < viewTop || targetPos.y + dockAppsCard.height > viewBottom) {
                                flick.contentY = Math.max(0, Math.min(targetPos.y - flick.height / 2 + dockAppsCard.height / 2, flick.contentHeight - flick.height));
                            }
                        }
                    }

                    function triggerHighlightAnimation() {
                        dockAppsHighlightAnim.restart();
                        dockAppsCard.ensureVisibleInFlickable();
                    }

                    function checkHighlight() {
                        let r = dockTabRoot.rootObj;
                        if (!r) return;
                        if (r.highlightToken === dockAppsCard.handledHighlightToken) return;
                        if (r.highlightedSettingId && (r.highlightedSettingId === dockAppsCard.settingId || r.highlightedSettingId === "dock_apps")) {
                            dockAppsCard.handledHighlightToken = r.highlightToken;
                            r.highlightedSettingId = "";
                            if (!dockTabRoot.currentEnabled) {
                                dockAppsCard.tempVisible = true;
                                appsCardCollapseTimer.restart();
                            }
                            dockAppsDelayTimer.restart();
                        }
                    }

                    Connections {
                        target: dockTabRoot.rootObj
                        ignoreUnknownSignals: true
                        function onHighlightTokenChanged() {
                            dockAppsCard.checkHighlight();
                        }
                    }

                    Timer {
                        id: dockAppsDelayTimer
                        interval: 80
                        repeat: false
                        onTriggered: dockAppsCard.triggerHighlightAnimation()
                    }

                    Timer {
                        id: appsCardCollapseTimer
                        interval: 2800
                        repeat: false
                        onTriggered: dockAppsCard.tempVisible = false
                    }

                    SequentialAnimation {
                        id: dockAppsHighlightAnim
                        NumberAnimation { target: dockAppsCard; property: "highlightFlash"; from: 0.0; to: 1.0; duration: 400; easing.type: Easing.OutCubic }
                        PauseAnimation { duration: 1500 }
                        NumberAnimation { target: dockAppsCard; property: "highlightFlash"; from: 1.0; to: 0.0; duration: 900; easing.type: Easing.InOutSine }
                    }

                    function resolveTabInfo() {
                        let r = dockTabRoot.rootObj;
                        let tabKey = "";
                        let subtabKey = "";
                        if (r && r.tabsModel && dockTabRoot.tabIndex >= 0 && dockTabRoot.tabIndex < r.tabsModel.length) {
                            let tModel = r.tabsModel[dockTabRoot.tabIndex];
                            tabKey = tModel.key || tModel.id || "";
                        }
                        return { tab: tabKey, subtab: subtabKey };
                    }

                    function registerWithSearch() {
                        let r = dockTabRoot.rootObj;
                        if (!r || typeof r.registerSearchItem !== "function") return;
                        if (!dockAppsCard.searchable || !dockAppsCard.title || dockAppsCard.title === "") {
                            if (dockAppsCard.settingId !== "") {
                                r.unregisterSearchItem(dockAppsCard.settingId);
                            }
                            return;
                        }
                        let info = dockAppsCard.resolveTabInfo();
                        r.registerSearchItem({
                            id: dockAppsCard.settingId,
                            title: dockAppsCard.title,
                            desc: dockAppsCard.description,
                            description: dockAppsCard.description,
                            tab: info.tab,
                            subtab: info.subtab,
                            icon: dockAppsCard.icon,
                            keywords: dockAppsCard.searchKeywords,
                            target: dockAppsCard
                        });
                    }

                    function unregisterFromSearch() {
                        let r = dockTabRoot.rootObj;
                        if (!r || typeof r.unregisterSearchItem !== "function") return;
                        if (dockAppsCard.settingId !== "") {
                            r.unregisterSearchItem(dockAppsCard.settingId);
                        }
                    }

                    Timer {
                        id: appsSearchRegTimer
                        interval: 10
                        repeat: false
                        onTriggered: dockAppsCard.registerWithSearch()
                    }

                    Component.onCompleted: {
                        appsSearchRegTimer.restart();
                        dockAppsCard.checkHighlight();
                    }
                    Component.onDestruction: dockAppsCard.unregisterFromSearch()

                    onTitleChanged: appsSearchRegTimer.restart()
                    onDescriptionChanged: appsSearchRegTimer.restart()
                    onIconChanged: appsSearchRegTimer.restart()
                    onSearchableChanged: appsSearchRegTimer.restart()
                    onSettingIdChanged: appsSearchRegTimer.restart()

                    implicitHeight: cardLayout.implicitHeight + dockTabRoot.rootObj.s(24)

                    ColumnLayout {
                        id: cardLayout
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.margins: dockTabRoot.rootObj.s(12)
                        spacing: dockTabRoot.rootObj.s(12)

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: dockTabRoot.rootObj.s(10)

                            Text {
                                text: dockAppsCard.title
                                font.family: ThemeBackend.fontFamily
                                font.pixelSize: dockTabRoot.rootObj.s(13)
                                color: ThemeBackend.text
                            }

                            Text {
                                text: "(" + dockTabRoot.currentAppsList.length + " " + (dockTabRoot.currentAppsList.length === 1 ? I18n.t("guide.dock.apps.singular", "app") : I18n.t("guide.dock.apps.plural", "apps")) + ")"
                                font.family: ThemeBackend.fontFamily
                                font.pixelSize: dockTabRoot.rootObj.s(11)
                                color: ThemeBackend.subtext0
                            }

                            Item { Layout.fillWidth: true }

                            ClickButton {
                                mcStyle: true
                                Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                                maxWidth: dockTabRoot.rootObj.s(160)
                                implicitHeight: dockTabRoot.rootObj.s(32)
                                cornerRadius: ThemeBackend.borderRadius
                                buttonText: dockTabRoot.currentEditing ? I18n.t("guide.dock.apps.exit_edit", "Exit edit mode") : I18n.t("guide.dock.apps.enter_edit", "Edit")
                                buttonIcon: dockTabRoot.currentEditing ? "󰅖" : "󰏫"
                                iconFontSize: dockTabRoot.rootObj.s(14)
                                accentColor: dockTabRoot.currentEditing ? ThemeBackend.red : ThemeBackend.mauve
                                textColor: ThemeBackend.crust
                                onClicked: {
                                    dockTabRoot.currentEditing = !dockTabRoot.currentEditing;
                                    dockTabRoot.updateDockSetting("editing", dockTabRoot.currentEditing);
                                    if (typeof Sounds !== "undefined") {
                                        Sounds.playSfx(dockTabRoot.currentEditing ? "guide/barconfig/out.wav" : "guide/barconfig/in.wav");
                                    }
                                    Quickshell.execDetached(["bash", Caching.serpantinumDir + "/scripts/qs_manager.sh", "close"]);
                                }
                            }
                        }

                        GridLayout {
                            id: appsGrid
                            Layout.fillWidth: true
                            columns: 3
                            rowSpacing: dockTabRoot.rootObj.s(8)
                            columnSpacing: dockTabRoot.rootObj.s(8)
                            visible: dockTabRoot.currentAppsList.length > 0

                            property real colWidth: Math.max(0, (cardLayout.width - appsGrid.columnSpacing * 2) / 3)

                            Repeater {
                                model: dockTabRoot.currentAppsList
                                delegate: Rectangle {
                                    id: appItemCard
                                    required property var modelData
                                    required property int index

                                    Layout.preferredWidth: appsGrid.colWidth
                                    Layout.maximumWidth: appsGrid.colWidth
                                    Layout.fillWidth: false
                                    Layout.preferredHeight: dockTabRoot.rootObj.s(48)
                                    radius: ThemeBackend.borderRadius
                                    color: Qt.alpha(ThemeBackend.surface1, 0.3)
                                    border.color: Qt.alpha(ThemeBackend.surface2, 0.35)
                                    border.width: 1

                                    RowLayout {
                                        anchors.fill: parent
                                        anchors.leftMargin: dockTabRoot.rootObj.s(8)
                                        anchors.rightMargin: dockTabRoot.rootObj.s(8)
                                        spacing: dockTabRoot.rootObj.s(8)

                                        Rectangle {
                                            id: iconWrapper
                                            implicitWidth: dockTabRoot.rootObj.s(32)
                                            implicitHeight: dockTabRoot.rootObj.s(32)
                                            Layout.alignment: Qt.AlignVCenter
                                            radius: Math.round(dockTabRoot.rootObj.s(32) * 0.28)
                                            color: ThemeBackend.surface0
                                            clip: true

                                            Image {
                                                id: appCardIcon
                                                anchors.fill: parent
                                                anchors.margins: dockTabRoot.rootObj.s(4)
                                                fillMode: Image.PreserveAspectFit
                                                asynchronous: true
                                                smooth: true
                                                mipmap: true
                                                property bool failedLoad: false

                                                visible: source !== "" && status === Image.Ready && !failedLoad

                                                source: {
                                                    let ic = modelData.icon || "";
                                                    if (!ic) return "";
                                                    if (ic.startsWith("file://") || ic.startsWith("image://") || ic.startsWith("http://") || ic.startsWith("https://")) return ic;
                                                    return ic.startsWith("/") ? "file://" + ic : "image://icon/" + ic;
                                                }

                                                onStatusChanged: {
                                                    if (status === Image.Error) failedLoad = true;
                                                }
                                            }

                                            Text {
                                                anchors.centerIn: parent
                                                visible: !appCardIcon.visible
                                                text: modelData.name ? modelData.name.charAt(0).toUpperCase() : "?"
                                                font.family: ThemeBackend.fontFamily
                                                font.pixelSize: dockTabRoot.rootObj.s(13)
                                                font.bold: true
                                                color: ThemeBackend.text
                                            }
                                        }

                                        ColumnLayout {
                                            Layout.fillWidth: true
                                            Layout.alignment: Qt.AlignVCenter
                                            spacing: dockTabRoot.rootObj.s(1)

                                            Text {
                                                text: modelData.name || modelData.desktop_id || "App"
                                                font.family: ThemeBackend.fontFamily
                                                font.pixelSize: dockTabRoot.rootObj.s(12)
                                                font.bold: true
                                                color: ThemeBackend.text
                                                elide: Text.ElideRight
                                                Layout.fillWidth: true
                                            }

                                            Text {
                                                text: modelData.comment || modelData.desktop_id || ""
                                                font.family: ThemeBackend.fontFamily
                                                font.pixelSize: dockTabRoot.rootObj.s(10)
                                                color: ThemeBackend.subtext0
                                                elide: Text.ElideRight
                                                Layout.fillWidth: true
                                            }
                                        }

                                        DeleteButton {
                                            size: dockTabRoot.rootObj.s(28)
                                            cornerRadius: Math.min(ThemeBackend.borderRadius, dockTabRoot.rootObj.s(8))
                                            iconFontSize: dockTabRoot.rootObj.s(14)
                                            Layout.alignment: Qt.AlignVCenter
                                            onClicked: {
                                                dockTabRoot.removeApp(index);
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        Item {
                            Layout.fillWidth: true
                            Layout.preferredHeight: dockTabRoot.rootObj.s(40)
                            visible: dockTabRoot.currentAppsList.length === 0

                            Text {
                                anchors.centerIn: parent
                                text: I18n.t("guide.dock.apps.empty", "No applications configured for the dock")
                                font.family: ThemeBackend.fontFamily
                                font.pixelSize: dockTabRoot.rootObj.s(12)
                                color: ThemeBackend.subtext0
                            }
                        }
                    }
                }
            }

            Item {
                id: positionWrapper
                Layout.fillWidth: true
                clip: true
                readonly property bool shouldBeOpen: dockTabRoot.currentEnabled || positionRow.tempVisible
                visible: height > 0.01
                implicitHeight: shouldBeOpen ? positionRow.implicitHeight : 0
                Behavior on implicitHeight {
                    NumberAnimation { duration: 250; easing.type: Easing.InOutCubic }
                }

                SettingsRow {
                    id: positionRow
                    anchors.top: parent.top
                    anchors.left: parent.left
                    anchors.right: parent.right
                    settingId: "dock_position"
                    rootObj: dockTabRoot.rootObj
                    icon: "󰍹"
                    iconOffsetX: -2
                    title: I18n.t("guide.dock.position.title", "Dock position")
                    description: I18n.t("guide.dock.position.desc", "Select the screen edge to anchor the dock")

                    property bool tempVisible: false

                    function checkHighlight() {
                        let r = effectiveRootObj;
                        if (!r) return;
                        if (r.highlightToken === handledHighlightToken) return;
                        if (r.highlightedSettingId && (r.highlightedSettingId === effectiveSettingId || r.highlightedSettingId === settingId)) {
                            handledHighlightToken = r.highlightToken;
                            r.highlightedSettingId = "";
                            if (!dockTabRoot.currentEnabled) {
                                tempVisible = true;
                                positionCollapseTimer.restart();
                            }
                            highlightDelayTimer.restart();
                        }
                    }

                    Timer {
                        id: positionCollapseTimer
                        interval: 2800
                        repeat: false
                        onTriggered: positionRow.tempVisible = false
                    }

                    Dropdown {
                        id: posDropdown
                        Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                        implicitWidth: dockTabRoot.rootObj.s(180)
                        implicitHeight: dockTabRoot.rootObj.s(32)
                        options: [
                            I18n.t("guide.dock.position.bottom", "Bottom"),
                            I18n.t("guide.dock.position.top", "Top"),
                            I18n.t("guide.dock.position.left", "Left"),
                            I18n.t("guide.dock.position.right", "Right")
                        ]
                        currentIndex: {
                            if (dockTabRoot.currentPosition === "top") return 1;
                            if (dockTabRoot.currentPosition === "left") return 2;
                            if (dockTabRoot.currentPosition === "right") return 3;
                            return 0;
                        }
                        accentColor: ThemeBackend.mauve
                        baseColor: ThemeBackend.surface0
                        hoverColor: ThemeBackend.surface1
                        dropdownColor: ThemeBackend.surface0
                        borderColor: Qt.alpha(ThemeBackend.surface2, 0.6)
                        textColor: ThemeBackend.text
                        activeTextColor: ThemeBackend.crust
                        fontPixelSize: dockTabRoot.rootObj.s(11)
                        onValueChanged: function(index, value) {
                            let pos = "bottom";
                            if (index === 1) pos = "top";
                            else if (index === 2) pos = "left";
                            else if (index === 3) pos = "right";
                            dockTabRoot.currentPosition = pos;
                            dockTabRoot.updateDockSetting("position", pos);
                        }
                    }
                }
            }

            Item {
                id: onTopWrapper
                Layout.fillWidth: true
                clip: true
                readonly property bool shouldBeOpen: dockTabRoot.currentEnabled || onTopRow.tempVisible
                visible: height > 0.01
                implicitHeight: shouldBeOpen ? onTopRow.implicitHeight : 0
                Behavior on implicitHeight {
                    NumberAnimation { duration: 250; easing.type: Easing.InOutCubic }
                }

                SettingsRow {
                    id: onTopRow
                    anchors.top: parent.top
                    anchors.left: parent.left
                    anchors.right: parent.right
                    settingId: "dock_on_top"
                    rootObj: dockTabRoot.rootObj
                    icon: "󰹤"
                    title: I18n.t("guide.dock.on_top.title", "Place dock on top of windows")
                    description: I18n.t("guide.dock.on_top.desc", "Keep the dock visible above application windows")

                    property bool tempVisible: false

                    function checkHighlight() {
                        let r = effectiveRootObj;
                        if (!r) return;
                        if (r.highlightToken === handledHighlightToken) return;
                        if (r.highlightedSettingId && (r.highlightedSettingId === effectiveSettingId || r.highlightedSettingId === settingId)) {
                            handledHighlightToken = r.highlightToken;
                            r.highlightedSettingId = "";
                            if (!dockTabRoot.currentEnabled) {
                                tempVisible = true;
                                onTopCollapseTimer.restart();
                            }
                            highlightDelayTimer.restart();
                        }
                    }

                    Timer {
                        id: onTopCollapseTimer
                        interval: 2800
                        repeat: false
                        onTriggered: onTopRow.tempVisible = false
                    }

                    Toggle {
                        Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                        checked: dockTabRoot.currentOnTop
                        accentColor: ThemeBackend.mauve
                        baseColor: ThemeBackend.surface1
                        handleColor: ThemeBackend.crust
                        handleOffColor: ThemeBackend.text
                        onToggled: function(val) {
                            dockTabRoot.currentOnTop = val;
                            dockTabRoot.updateDockSetting("onTop", val);
                        }
                    }
                }
            }

            Item {
                id: floatingWrapper
                Layout.fillWidth: true
                clip: true
                readonly property bool shouldBeOpen: dockTabRoot.currentEnabled || floatingRow.tempVisible
                visible: height > 0.01
                implicitHeight: shouldBeOpen ? floatingRow.implicitHeight : 0
                Behavior on implicitHeight {
                    NumberAnimation { duration: 250; easing.type: Easing.InOutCubic }
                }

                SettingsRow {
                    id: floatingRow
                    anchors.top: parent.top
                    anchors.left: parent.left
                    anchors.right: parent.right
                    settingId: "dock_floating"
                    rootObj: dockTabRoot.rootObj
                    icon: "󰉈"
                    title: I18n.t("guide.dock.floating.title", "Floating dock")
                    description: I18n.t("guide.dock.floating.desc", "Detach dock from screen edge with rounded corners")

                    property bool tempVisible: false

                    function checkHighlight() {
                        let r = effectiveRootObj;
                        if (!r) return;
                        if (r.highlightToken === handledHighlightToken) return;
                        if (r.highlightedSettingId && (r.highlightedSettingId === effectiveSettingId || r.highlightedSettingId === settingId)) {
                            handledHighlightToken = r.highlightToken;
                            r.highlightedSettingId = "";
                            if (!dockTabRoot.currentEnabled) {
                                tempVisible = true;
                                floatingCollapseTimer.restart();
                            }
                            highlightDelayTimer.restart();
                        }
                    }

                    Timer {
                        id: floatingCollapseTimer
                        interval: 2800
                        repeat: false
                        onTriggered: floatingRow.tempVisible = false
                    }

                    Toggle {
                        Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                        checked: dockTabRoot.currentFloating
                        accentColor: ThemeBackend.mauve
                        baseColor: ThemeBackend.surface1
                        handleColor: ThemeBackend.crust
                        handleOffColor: ThemeBackend.text
                        onToggled: function(val) {
                            dockTabRoot.currentFloating = val;
                            dockTabRoot.updateDockSetting("floating", val);
                        }
                    }
                }
            }

            Item {
                id: exclusiveWrapper
                Layout.fillWidth: true
                clip: true
                readonly property bool shouldBeOpen: dockTabRoot.currentEnabled || exclusiveRow.tempVisible
                visible: height > 0.01
                implicitHeight: shouldBeOpen ? exclusiveRow.implicitHeight : 0
                Behavior on implicitHeight {
                    NumberAnimation { duration: 250; easing.type: Easing.InOutCubic }
                }

                SettingsRow {
                    id: exclusiveRow
                    anchors.top: parent.top
                    anchors.left: parent.left
                    anchors.right: parent.right
                    settingId: "dock_exclusive"
                    rootObj: dockTabRoot.rootObj
                    icon: "󰖲"
                    title: I18n.t("guide.dock.exclusive.title", "Exclusive mode")
                    description: I18n.t("guide.dock.exclusive.desc", "Prevent windows from taking space occupied by the dock")

                    property bool tempVisible: false

                    function checkHighlight() {
                        let r = effectiveRootObj;
                        if (!r) return;
                        if (r.highlightToken === handledHighlightToken) return;
                        if (r.highlightedSettingId && (r.highlightedSettingId === effectiveSettingId || r.highlightedSettingId === settingId)) {
                            handledHighlightToken = r.highlightToken;
                            r.highlightedSettingId = "";
                            if (!dockTabRoot.currentEnabled) {
                                tempVisible = true;
                                exclusiveCollapseTimer.restart();
                            }
                            highlightDelayTimer.restart();
                        }
                    }

                    Timer {
                        id: exclusiveCollapseTimer
                        interval: 2800
                        repeat: false
                        onTriggered: exclusiveRow.tempVisible = false
                    }

                    Toggle {
                        Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                        checked: dockTabRoot.currentExclusive
                        accentColor: ThemeBackend.mauve
                        baseColor: ThemeBackend.surface1
                        handleColor: ThemeBackend.crust
                        handleOffColor: ThemeBackend.text
                        onToggled: function(val) {
                            dockTabRoot.currentExclusive = val;
                            dockTabRoot.updateDockSetting("exclusive", val);
                        }
                    }
                }
            }

            Item {
                id: opacityWrapper
                Layout.fillWidth: true
                clip: true
                readonly property bool shouldBeOpen: dockTabRoot.currentEnabled || opacityRow.tempVisible
                visible: height > 0.01
                implicitHeight: shouldBeOpen ? opacityRow.implicitHeight : 0
                Behavior on implicitHeight {
                    NumberAnimation { duration: 250; easing.type: Easing.InOutCubic }
                }

                SettingsRow {
                    id: opacityRow
                    anchors.top: parent.top
                    anchors.left: parent.left
                    anchors.right: parent.right
                    settingId: "dock_opacity"
                    rootObj: dockTabRoot.rootObj
                    icon: "󰂵"
                    title: I18n.t("guide.dock.opacity.title", "Dock opacity")
                    description: I18n.t("guide.dock.opacity.desc", "Adjust dock background opacity level")

                    property bool tempVisible: false

                    function checkHighlight() {
                        let r = effectiveRootObj;
                        if (!r) return;
                        if (r.highlightToken === handledHighlightToken) return;
                        if (r.highlightedSettingId && (r.highlightedSettingId === effectiveSettingId || r.highlightedSettingId === settingId)) {
                            handledHighlightToken = r.highlightToken;
                            r.highlightedSettingId = "";
                            if (!dockTabRoot.currentEnabled) {
                                tempVisible = true;
                                opacityCollapseTimer.restart();
                            }
                            highlightDelayTimer.restart();
                        }
                    }

                    Timer {
                        id: opacityCollapseTimer
                        interval: 2800
                        repeat: false
                        onTriggered: opacityRow.tempVisible = false
                    }

                    Draggable {
                        id: opacitySlider
                        Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                        implicitWidth: dockTabRoot.rootObj.s(220)
                        implicitHeight: dockTabRoot.rootObj.s(18)
                        from: 0
                        to: 100
                        stepSize: 1
                        defaultValue: 100
                        showValueBubble: true
                        valueFormatter: function(v) { return Math.round(v) + "%" }
                        value: dockTabRoot.currentOpacity
                        backgroundColor: ThemeBackend.surface0
                        accentColor: ThemeBackend.mauve
                        handleColor: ThemeBackend.text
                        handleBorderColor: ThemeBackend.mantle
                        onMoved: function(val) {
                            let rounded = Math.round(val);
                            if (dockTabRoot.currentOpacity !== rounded) {
                                dockTabRoot.currentOpacity = rounded;
                                dockTabRoot.triggerDebounced(function() {
                                    dockTabRoot.updateDockSetting("opacity", rounded);
                                });
                            }
                        }
                        onDragFinished: {
                            dockDebounceTimer.stop();
                            dockTabRoot.updateDockSetting("opacity", Math.round(opacitySlider.value));
                        }
                    }
                }
            }

            Item {
                id: elementSizeWrapper
                Layout.fillWidth: true
                clip: true
                readonly property bool shouldBeOpen: dockTabRoot.currentEnabled || elementSizeRow.tempVisible
                visible: height > 0.01
                implicitHeight: shouldBeOpen ? elementSizeRow.implicitHeight : 0
                Behavior on implicitHeight {
                    NumberAnimation { duration: 250; easing.type: Easing.InOutCubic }
                }

                SettingsRow {
                    id: elementSizeRow
                    anchors.top: parent.top
                    anchors.left: parent.left
                    anchors.right: parent.right
                    settingId: "dock_element_size"
                    rootObj: dockTabRoot.rootObj
                    icon: "󰘖"
                    title: I18n.t("guide.dock.size.title", "Element size")
                    description: I18n.t("guide.dock.size.desc", "Dimensions of individual app buttons in pixels")

                    property bool tempVisible: false

                    function checkHighlight() {
                        let r = effectiveRootObj;
                        if (!r) return;
                        if (r.highlightToken === handledHighlightToken) return;
                        if (r.highlightedSettingId && (r.highlightedSettingId === effectiveSettingId || r.highlightedSettingId === settingId)) {
                            handledHighlightToken = r.highlightToken;
                            r.highlightedSettingId = "";
                            if (!dockTabRoot.currentEnabled) {
                                tempVisible = true;
                                elementSizeCollapseTimer.restart();
                            }
                            highlightDelayTimer.restart();
                        }
                    }

                    Timer {
                        id: elementSizeCollapseTimer
                        interval: 2800
                        repeat: false
                        onTriggered: elementSizeRow.tempVisible = false
                    }

                    Draggable {
                        id: sizeSlider
                        Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                        implicitWidth: dockTabRoot.rootObj.s(220)
                        implicitHeight: dockTabRoot.rootObj.s(18)
                        from: 32
                        to: 72
                        stepSize: 2
                        defaultValue: 44
                        showValueBubble: true
                        valueFormatter: function(v) { return Math.round(v) + " px" }
                        value: dockTabRoot.currentElementSize
                        backgroundColor: ThemeBackend.surface0
                        accentColor: ThemeBackend.mauve
                        handleColor: ThemeBackend.text
                        handleBorderColor: ThemeBackend.mantle
                        onMoved: function(val) {
                            let rounded = Math.round(val);
                            if (dockTabRoot.currentElementSize !== rounded) {
                                dockTabRoot.currentElementSize = rounded;
                                dockTabRoot.triggerDebounced(function() {
                                    dockTabRoot.updateDockSetting("elementSize", rounded);
                                });
                            }
                        }
                        onDragFinished: {
                            dockDebounceTimer.stop();
                            dockTabRoot.updateDockSetting("elementSize", Math.round(sizeSlider.value));
                        }
                    }
                }
            }

            Item {
                id: overrideBoundsWrapper
                Layout.fillWidth: true
                clip: true
                readonly property bool shouldBeOpen: dockTabRoot.currentEnabled || overrideBoundsRow.tempVisible
                visible: height > 0.01
                implicitHeight: shouldBeOpen ? overrideBoundsRow.implicitHeight : 0
                Behavior on implicitHeight {
                    NumberAnimation { duration: 250; easing.type: Easing.InOutCubic }
                }

                SettingsRow {
                    id: overrideBoundsRow
                    anchors.top: parent.top
                    anchors.left: parent.left
                    anchors.right: parent.right
                    settingId: "dock_override_bounds"
                    rootObj: dockTabRoot.rootObj
                    icon: "󰜤"
                    title: I18n.t("guide.dock.override_bounds.title", "Override out-of-screen-bounds size correction")
                    description: I18n.t("guide.dock.override_bounds.desc", "Keep custom element size even if dock exceeds screen limits")

                    property bool tempVisible: false

                    function checkHighlight() {
                        let r = effectiveRootObj;
                        if (!r) return;
                        if (r.highlightToken === handledHighlightToken) return;
                        if (r.highlightedSettingId && (r.highlightedSettingId === effectiveSettingId || r.highlightedSettingId === settingId)) {
                            handledHighlightToken = r.highlightToken;
                            r.highlightedSettingId = "";
                            if (!dockTabRoot.currentEnabled) {
                                tempVisible = true;
                                overrideBoundsCollapseTimer.restart();
                            }
                            highlightDelayTimer.restart();
                        }
                    }

                    Timer {
                        id: overrideBoundsCollapseTimer
                        interval: 2800
                        repeat: false
                        onTriggered: overrideBoundsRow.tempVisible = false
                    }

                    Toggle {
                        Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                        checked: dockTabRoot.currentOverrideBoundsCorrection
                        accentColor: ThemeBackend.mauve
                        baseColor: ThemeBackend.surface1
                        handleColor: ThemeBackend.crust
                        handleOffColor: ThemeBackend.text
                        onToggled: function(val) {
                            dockTabRoot.currentOverrideBoundsCorrection = val;
                            dockTabRoot.updateDockSetting("overrideBoundsCorrection", val);
                        }
                    }
                }
            }

            Item {
                id: hoverScaleWrapper
                Layout.fillWidth: true
                clip: true
                readonly property bool shouldBeOpen: dockTabRoot.currentEnabled || hoverScaleRow.tempVisible
                visible: height > 0.01
                implicitHeight: shouldBeOpen ? hoverScaleRow.implicitHeight : 0
                Behavior on implicitHeight {
                    NumberAnimation { duration: 250; easing.type: Easing.InOutCubic }
                }

                SettingsRow {
                    id: hoverScaleRow
                    anchors.top: parent.top
                    anchors.left: parent.left
                    anchors.right: parent.right
                    settingId: "dock_hover_scale"
                    rootObj: dockTabRoot.rootObj
                    icon: "󰍔"
                    title: I18n.t("guide.dock.hover_scale.title", "Hover scale effect")
                    description: I18n.t("guide.dock.hover_scale.desc", "Magnification level when hovering over dock items")

                    property bool tempVisible: false

                    function checkHighlight() {
                        let r = effectiveRootObj;
                        if (!r) return;
                        if (r.highlightToken === handledHighlightToken) return;
                        if (r.highlightedSettingId && (r.highlightedSettingId === effectiveSettingId || r.highlightedSettingId === settingId)) {
                            handledHighlightToken = r.highlightToken;
                            r.highlightedSettingId = "";
                            if (!dockTabRoot.currentEnabled) {
                                tempVisible = true;
                                hoverScaleCollapseTimer.restart();
                            }
                            highlightDelayTimer.restart();
                        }
                    }

                    Timer {
                        id: hoverScaleCollapseTimer
                        interval: 2800
                        repeat: false
                        onTriggered: hoverScaleRow.tempVisible = false
                    }

                    Draggable {
                        id: hoverScaleSlider
                        Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                        implicitWidth: dockTabRoot.rootObj.s(220)
                        implicitHeight: dockTabRoot.rootObj.s(18)
                        from: 100
                        to: 160
                        stepSize: 2
                        defaultValue: 120
                        showValueBubble: true
                        valueFormatter: function(v) { return Math.round(v) + "%" }
                        value: dockTabRoot.currentHoverScale
                        backgroundColor: ThemeBackend.surface0
                        accentColor: ThemeBackend.mauve
                        handleColor: ThemeBackend.text
                        handleBorderColor: ThemeBackend.mantle
                        onMoved: function(val) {
                            let rounded = Math.round(val);
                            if (dockTabRoot.currentHoverScale !== rounded) {
                                dockTabRoot.currentHoverScale = rounded;
                                dockTabRoot.triggerDebounced(function() {
                                    dockTabRoot.updateDockSetting("hoverScale", rounded);
                                });
                            }
                        }
                        onDragFinished: {
                            dockDebounceTimer.stop();
                            dockTabRoot.updateDockSetting("hoverScale", Math.round(hoverScaleSlider.value));
                        }
                    }
                }
            }

            Item {
                id: cascadeScaleWrapper
                Layout.fillWidth: true
                clip: true
                readonly property bool shouldBeOpen: dockTabRoot.currentEnabled || cascadeScaleRow.tempVisible
                visible: height > 0.01
                implicitHeight: shouldBeOpen ? cascadeScaleRow.implicitHeight : 0
                Behavior on implicitHeight {
                    NumberAnimation { duration: 250; easing.type: Easing.InOutCubic }
                }

                SettingsRow {
                    id: cascadeScaleRow
                    anchors.top: parent.top
                    anchors.left: parent.left
                    anchors.right: parent.right
                    settingId: "dock_cascade_scale"
                    rootObj: dockTabRoot.rootObj
                    icon: "󰘚"
                    title: I18n.t("guide.dock.cascade_scale.title", "Scale nearest elements")
                    description: I18n.t("guide.dock.cascade_scale.desc", "Cascading magnification on neighboring icons")

                    property bool tempVisible: false

                    function checkHighlight() {
                        let r = effectiveRootObj;
                        if (!r) return;
                        if (r.highlightToken === handledHighlightToken) return;
                        if (r.highlightedSettingId && (r.highlightedSettingId === effectiveSettingId || r.highlightedSettingId === settingId)) {
                            handledHighlightToken = r.highlightToken;
                            r.highlightedSettingId = "";
                            if (!dockTabRoot.currentEnabled) {
                                tempVisible = true;
                                cascadeScaleCollapseTimer.restart();
                            }
                            highlightDelayTimer.restart();
                        }
                    }

                    Timer {
                        id: cascadeScaleCollapseTimer
                        interval: 2800
                        repeat: false
                        onTriggered: cascadeScaleRow.tempVisible = false
                    }

                    Toggle {
                        Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                        checked: dockTabRoot.currentCascadeScale
                        accentColor: ThemeBackend.mauve
                        baseColor: ThemeBackend.surface1
                        handleColor: ThemeBackend.crust
                        handleOffColor: ThemeBackend.text
                        onToggled: function(val) {
                            dockTabRoot.currentCascadeScale = val;
                            dockTabRoot.updateDockSetting("cascadeScale", val);
                        }
                    }
                }
            }

            Item {
                id: scrollingWrapper
                Layout.fillWidth: true
                clip: true
                readonly property bool shouldBeOpen: dockTabRoot.currentEnabled || scrollingGroup.tempVisible
                visible: height > 0.01
                implicitHeight: shouldBeOpen ? scrollingGroup.implicitHeight : 0
                Behavior on implicitHeight {
                    NumberAnimation { duration: 250; easing.type: Easing.InOutCubic }
                }

                SettingsGroup {
                    id: scrollingGroup
                    anchors.top: parent.top
                    anchors.left: parent.left
                    anchors.right: parent.right
                    settingId: "dock_scrolling"
                    rootObj: dockTabRoot.rootObj
                    icon: "󰍽"
                    title: I18n.t("guide.dock.scrolling.title", "Enable element scrolling")
                    description: I18n.t("guide.dock.scrolling.desc", "Limit visible elements and allow mouse wheel or touchpad scrolling")
                    expanded: dockTabRoot.currentEnableScrolling
                    forceOpen: visibleElementsRow.tempVisible

                    property bool tempVisible: false

                    function checkHighlight() {
                        let r = effectiveRootObj;
                        if (!r) return;
                        if (r.highlightToken === handledHighlightToken) return;
                        if (r.highlightedSettingId && (r.highlightedSettingId === effectiveSettingId || r.highlightedSettingId === settingId)) {
                            handledHighlightToken = r.highlightToken;
                            r.highlightedSettingId = "";
                            if (!dockTabRoot.currentEnabled) {
                                tempVisible = true;
                                scrollingCollapseTimer.restart();
                            }
                            highlightDelayTimer.restart();
                        }
                    }

                    Timer {
                        id: scrollingCollapseTimer
                        interval: 2800
                        repeat: false
                        onTriggered: scrollingGroup.tempVisible = false
                    }

                    Toggle {
                        Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                        checked: dockTabRoot.currentEnableScrolling
                        accentColor: ThemeBackend.mauve
                        baseColor: ThemeBackend.surface1
                        handleColor: ThemeBackend.crust
                        handleOffColor: ThemeBackend.text
                        onToggled: function(val) {
                            dockTabRoot.currentEnableScrolling = val;
                            dockTabRoot.updateDockSetting("enableScrolling", val);
                        }
                    }

                    subSettings: [
                        SettingsRow {
                            id: visibleElementsRow
                            settingId: "dock_visible_elements"
                            rootObj: dockTabRoot.rootObj
                            icon: "󰅫"
                            title: I18n.t("guide.dock.visible_elements.title", "Visible elements")
                            description: I18n.t("guide.dock.visible_elements.desc", "Number of dock items visible at the same time")

                            property bool tempVisible: false

                            function checkHighlight() {
                                let r = effectiveRootObj;
                                if (!r) return;
                                if (r.highlightToken === handledHighlightToken) return;
                                if (r.highlightedSettingId && (r.highlightedSettingId === effectiveSettingId || r.highlightedSettingId === settingId)) {
                                    handledHighlightToken = r.highlightToken;
                                    r.highlightedSettingId = "";
                                    if (!dockTabRoot.currentEnabled || !dockTabRoot.currentEnableScrolling) {
                                        tempVisible = true;
                                        visibleElementsCollapseTimer.restart();
                                    }
                                    highlightDelayTimer.restart();
                                }
                            }

                            Timer {
                                id: visibleElementsCollapseTimer
                                interval: 2800
                                repeat: false
                                onTriggered: visibleElementsRow.tempVisible = false
                            }

                            NumberSelector {
                                id: visibleElementsSelector
                                Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                                implicitWidth: dockTabRoot.rootObj.s(120)
                                implicitHeight: dockTabRoot.rootObj.s(32)
                                from: 1
                                to: 20
                                stepSize: 1
                                decimals: 0
                                value: dockTabRoot.currentVisibleElements
                                baseColor: ThemeBackend.surface0
                                accentColor: ThemeBackend.mauve
                                buttonColor: ThemeBackend.surface1
                                buttonTextColor: ThemeBackend.text
                                textColor: ThemeBackend.text
                                subTextColor: ThemeBackend.subtext0
                                borderColor: Qt.alpha(ThemeBackend.surface2, 0.6)
                                cornerRadius: ThemeBackend.borderRadius
                                fontFamily: ThemeBackend.fontFamily
                                fontPixelSize: dockTabRoot.rootObj.s(11)
                                onValueChanged: {
                                    let v = Math.round(visibleElementsSelector.value);
                                    if (!isNaN(v) && v > 0 && dockTabRoot.currentVisibleElements !== v) {
                                        dockTabRoot.currentVisibleElements = v;
                                        dockTabRoot.updateDockSetting("visibleElements", v);
                                    }
                                }
                            }
                        }
                    ]
                }
            }

            Item {
                id: smartAutohideWrapper
                Layout.fillWidth: true
                clip: true
                readonly property bool shouldBeOpen: dockTabRoot.currentEnabled || smartAutohideRow.tempVisible
                visible: height > 0.01
                implicitHeight: shouldBeOpen ? smartAutohideRow.implicitHeight : 0
                Behavior on implicitHeight {
                    NumberAnimation { duration: 250; easing.type: Easing.InOutCubic }
                }

                SettingsRow {
                    id: smartAutohideRow
                    anchors.top: parent.top
                    anchors.left: parent.left
                    anchors.right: parent.right
                    settingId: "dock_smart_autohide"
                    rootObj: dockTabRoot.rootObj
                    icon: "󱂬"
                    title: I18n.t("guide.dock.smart_autohide.title", "Smart auto-hide")
                    description: I18n.t("guide.dock.smart_autohide.desc", "Auto-hide dock only when windows are open, keep visible on desktop")

                    property bool tempVisible: false

                    function checkHighlight() {
                        let r = effectiveRootObj;
                        if (!r) return;
                        if (r.highlightToken === handledHighlightToken) return;
                        if (r.highlightedSettingId && (r.highlightedSettingId === effectiveSettingId || r.highlightedSettingId === settingId)) {
                            handledHighlightToken = r.highlightToken;
                            r.highlightedSettingId = "";
                            if (!dockTabRoot.currentEnabled) {
                                tempVisible = true;
                                smartAutohideCollapseTimer.restart();
                            }
                            highlightDelayTimer.restart();
                        }
                    }

                    Timer {
                        id: smartAutohideCollapseTimer
                        interval: 2800
                        repeat: false
                        onTriggered: smartAutohideRow.tempVisible = false
                    }

                    Toggle {
                        Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                        checked: dockTabRoot.currentSmartAutohide
                        accentColor: ThemeBackend.mauve
                        baseColor: ThemeBackend.surface1
                        handleColor: ThemeBackend.crust
                        handleOffColor: ThemeBackend.text
                        onToggled: function(val) {
                            dockTabRoot.currentSmartAutohide = val;
                            dockTabRoot.updateDockSetting("smartAutohide", val);
                        }
                    }
                }
            }

            Item {
                id: focusRunningWrapper
                Layout.fillWidth: true
                clip: true
                readonly property bool shouldBeOpen: dockTabRoot.currentEnabled || focusRunningRow.tempVisible
                visible: height > 0.01
                implicitHeight: shouldBeOpen ? focusRunningRow.implicitHeight : 0
                Behavior on implicitHeight {
                    NumberAnimation { duration: 250; easing.type: Easing.InOutCubic }
                }

                SettingsRow {
                    id: focusRunningRow
                    anchors.top: parent.top
                    anchors.left: parent.left
                    anchors.right: parent.right
                    settingId: "dock_focus_running"
                    rootObj: dockTabRoot.rootObj
                    icon: "󱂬"
                    title: I18n.t("guide.dock.focus_running.title", "Focus existing window")
                    description: I18n.t("guide.dock.focus_running.desc", "Clicking an app icon activates its open window instead of launching a new instance")

                    property bool tempVisible: false

                    Toggle {
                        Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                        checked: dockTabRoot.currentFocusRunning
                        accentColor: ThemeBackend.mauve
                        baseColor: ThemeBackend.surface1
                        handleColor: ThemeBackend.crust
                        handleOffColor: ThemeBackend.text
                        onToggled: function(val) {
                            dockTabRoot.currentFocusRunning = val;
                            dockTabRoot.updateDockSetting("focusRunning", val);
                        }
                    }
                }
            }

            Item {
                id: showIndicatorsWrapper
                Layout.fillWidth: true
                clip: true
                readonly property bool shouldBeOpen: dockTabRoot.currentEnabled || showIndicatorsRow.tempVisible
                visible: height > 0.01
                implicitHeight: shouldBeOpen ? showIndicatorsRow.implicitHeight : 0
                Behavior on implicitHeight {
                    NumberAnimation { duration: 250; easing.type: Easing.InOutCubic }
                }

                SettingsRow {
                    id: showIndicatorsRow
                    anchors.top: parent.top
                    anchors.left: parent.left
                    anchors.right: parent.right
                    settingId: "dock_show_running_indicators"
                    rootObj: dockTabRoot.rootObj
                    icon: "󰄯"
                    title: I18n.t("guide.dock.show_running_indicators.title", "Running indicators")
                    description: I18n.t("guide.dock.show_running_indicators.desc", "Show dot or pill indicators on open application icons")

                    property bool tempVisible: false

                    Toggle {
                        Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                        checked: dockTabRoot.currentShowRunningIndicators
                        accentColor: ThemeBackend.mauve
                        baseColor: ThemeBackend.surface1
                        handleColor: ThemeBackend.crust
                        handleOffColor: ThemeBackend.text
                        onToggled: function(val) {
                            dockTabRoot.currentShowRunningIndicators = val;
                            dockTabRoot.updateDockSetting("showRunningIndicators", val);
                        }
                    }
                }
            }

            Item {
                id: showRunningAppsWrapper
                Layout.fillWidth: true
                clip: true
                readonly property bool shouldBeOpen: dockTabRoot.currentEnabled || showRunningAppsRow.tempVisible
                visible: height > 0.01
                implicitHeight: shouldBeOpen ? showRunningAppsRow.implicitHeight : 0
                Behavior on implicitHeight {
                    NumberAnimation { duration: 250; easing.type: Easing.InOutCubic }
                }

                SettingsRow {
                    id: showRunningAppsRow
                    anchors.top: parent.top
                    anchors.left: parent.left
                    anchors.right: parent.right
                    settingId: "dock_show_running_apps"
                    rootObj: dockTabRoot.rootObj
                    icon: "󰘓"
                    title: I18n.t("guide.dock.show_running_apps.title", "Show open applications")
                    description: I18n.t("guide.dock.show_running_apps.desc", "Display unpinned open applications in the dock")

                    property bool tempVisible: false

                    Toggle {
                        Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                        checked: dockTabRoot.currentShowRunningApps
                        accentColor: ThemeBackend.mauve
                        baseColor: ThemeBackend.surface1
                        handleColor: ThemeBackend.crust
                        handleOffColor: ThemeBackend.text
                        onToggled: function(val) {
                            dockTabRoot.currentShowRunningApps = val;
                            dockTabRoot.updateDockSetting("showRunningApps", val);
                        }
                    }
                }
            }

            Item {
                id: runningScopeWrapper
                Layout.fillWidth: true
                clip: true
                readonly property bool shouldBeOpen: dockTabRoot.currentEnabled || runningScopeRow.tempVisible
                visible: height > 0.01
                implicitHeight: shouldBeOpen ? runningScopeRow.implicitHeight : 0
                Behavior on implicitHeight {
                    NumberAnimation { duration: 250; easing.type: Easing.InOutCubic }
                }

                SettingsRow {
                    id: runningScopeRow
                    anchors.top: parent.top
                    anchors.left: parent.left
                    anchors.right: parent.right
                    settingId: "dock_running_scope"
                    rootObj: dockTabRoot.rootObj
                    icon: "󰍹"
                    title: I18n.t("guide.dock.running_scope.title", "Active window scope")
                    description: I18n.t("guide.dock.running_scope.desc", "Filter running windows displayed and controlled by the dock")

                    property bool tempVisible: false

                    Dropdown {
                        id: scopeDropdown
                        Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                        implicitWidth: dockTabRoot.rootObj.s(220)
                        implicitHeight: dockTabRoot.rootObj.s(32)
                        options: [
                            I18n.t("guide.dock.running_scope.auto", "Automatic (compositor default)"),
                            I18n.t("guide.dock.running_scope.all", "All workspaces & monitors"),
                            I18n.t("guide.dock.running_scope.output", "Current monitor only"),
                            I18n.t("guide.dock.running_scope.workspace", "Active workspace only")
                        ]
                        currentIndex: {
                            if (dockTabRoot.currentRunningScope === "all") return 1;
                            if (dockTabRoot.currentRunningScope === "output") return 2;
                            if (dockTabRoot.currentRunningScope === "workspace") return 3;
                            return 0;
                        }
                        accentColor: ThemeBackend.mauve
                        baseColor: ThemeBackend.surface0
                        hoverColor: ThemeBackend.surface1
                        dropdownColor: ThemeBackend.surface0
                        borderColor: Qt.alpha(ThemeBackend.surface2, 0.6)
                        textColor: ThemeBackend.text
                        activeTextColor: ThemeBackend.crust
                        fontPixelSize: dockTabRoot.rootObj.s(11)
                        onValueChanged: function(index, value) {
                            let sc = "auto";
                            if (index === 1) sc = "all";
                            else if (index === 2) sc = "output";
                            else if (index === 3) sc = "workspace";
                            dockTabRoot.currentRunningScope = sc;
                            dockTabRoot.updateDockSetting("runningScope", sc);
                        }
                    }
                }
            }

            Item {
                id: autohideWrapper
                Layout.fillWidth: true
                clip: true
                readonly property bool shouldBeOpen: dockTabRoot.currentEnabled || autohideGroup.tempVisible
                visible: height > 0.01
                implicitHeight: shouldBeOpen ? autohideGroup.implicitHeight : 0
                Behavior on implicitHeight {
                    NumberAnimation { duration: 250; easing.type: Easing.InOutCubic }
                }

                SettingsGroup {
                    id: autohideGroup
                    anchors.top: parent.top
                    anchors.left: parent.left
                    anchors.right: parent.right
                    settingId: "dock_autohide"
                    rootObj: dockTabRoot.rootObj
                    icon: "󰘓"
                    title: I18n.t("guide.dock.autohide.title", "Auto-hide")
                    description: I18n.t("guide.dock.autohide.desc", "Hide the dock when not hovering over the screen edge")
                    expanded: dockTabRoot.currentAutohide || dockTabRoot.currentSmartAutohide
                    forceOpen: autohideTimeoutRow.tempVisible

                    property bool tempVisible: false

                    function checkHighlight() {
                        let r = effectiveRootObj;
                        if (!r) return;
                        if (r.highlightToken === handledHighlightToken) return;
                        if (r.highlightedSettingId && (r.highlightedSettingId === effectiveSettingId || r.highlightedSettingId === settingId)) {
                            handledHighlightToken = r.highlightToken;
                            r.highlightedSettingId = "";
                            if (!dockTabRoot.currentEnabled) {
                                tempVisible = true;
                                autohideCollapseTimer.restart();
                            }
                            highlightDelayTimer.restart();
                        }
                    }

                    Timer {
                        id: autohideCollapseTimer
                        interval: 2800
                        repeat: false
                        onTriggered: autohideGroup.tempVisible = false
                    }

                    Toggle {
                        Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                        checked: dockTabRoot.currentAutohide
                        accentColor: ThemeBackend.mauve
                        baseColor: ThemeBackend.surface1
                        handleColor: ThemeBackend.crust
                        handleOffColor: ThemeBackend.text
                        onToggled: function(val) {
                            dockTabRoot.currentAutohide = val;
                            dockTabRoot.updateDockSetting("autohide", val);
                        }
                    }

                    subSettings: [
                        SettingsRow {
                            id: autohideTimeoutRow
                            settingId: "dock_autohide_delay"
                            rootObj: dockTabRoot.rootObj
                            icon: "󰔛"
                            title: I18n.t("guide.dock.timeout.title", "Auto-hide delay")
                            description: I18n.t("guide.dock.timeout.desc", "Duration before hiding after pointer leaves")

                            property bool tempVisible: false

                            function checkHighlight() {
                                let r = effectiveRootObj;
                                if (!r) return;
                                if (r.highlightToken === handledHighlightToken) return;
                                if (r.highlightedSettingId && (r.highlightedSettingId === effectiveSettingId || r.highlightedSettingId === settingId)) {
                                    handledHighlightToken = r.highlightToken;
                                    r.highlightedSettingId = "";
                                    if (!dockTabRoot.currentEnabled || (!dockTabRoot.currentAutohide && !dockTabRoot.currentSmartAutohide)) {
                                        tempVisible = true;
                                        timeoutCollapseTimer.restart();
                                    }
                                    highlightDelayTimer.restart();
                                }
                            }

                            Timer {
                                id: timeoutCollapseTimer
                                interval: 2800
                                repeat: false
                                onTriggered: autohideTimeoutRow.tempVisible = false
                            }

                            Draggable {
                                id: timeoutSlider
                                Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                                implicitWidth: dockTabRoot.rootObj.s(220)
                                implicitHeight: dockTabRoot.rootObj.s(18)
                                from: 250
                                to: 5000
                                stepSize: 50
                                defaultValue: 1000
                                showValueBubble: true
                                valueFormatter: function(v) { return Math.round(v) + " ms" }
                                value: dockTabRoot.currentAutohideTimeout
                                backgroundColor: ThemeBackend.surface0
                                accentColor: ThemeBackend.mauve
                                handleColor: ThemeBackend.text
                                handleBorderColor: ThemeBackend.mantle
                                onMoved: function(val) {
                                    let rounded = Math.round(val);
                                    if (dockTabRoot.currentAutohideTimeout !== rounded) {
                                        dockTabRoot.currentAutohideTimeout = rounded;
                                        dockTabRoot.triggerDebounced(function() {
                                            dockTabRoot.updateDockSetting("autohideTimeout", rounded);
                                        });
                                    }
                                }
                                onDragFinished: {
                                    dockDebounceTimer.stop();
                                    dockTabRoot.updateDockSetting("autohideTimeout", Math.round(timeoutSlider.value));
                                }
                            }
                        }
                    ]
                }
            }
        }
    }
}
