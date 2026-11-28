import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import "../"
import "../reusables"
import "../reusables/guide"

GuideTab {
    id: dockTabRoot
    deferredStages: 4

    ConfigSection {
        id: dockCfg
        section: "dock"
        defaults: ({
            "enabled": true,
            "position": "bottom",
            "onTop": true,
            "elementSize": 44,
            "floating": false,
            "background": true,
            "exclusive": false,
            "autohide": false,
            "smartAutohide": true,
            "autohideTimeout": 1000,
            "editing": false,
            "apps": [
                { "name": "Kitty", "comment": "Fast, feature-rich, GPU based terminal", "desktop_id": "kitty.desktop", "icon": "kitty" },
                { "name": "Files", "comment": "Access and organize files", "desktop_id": "ski.desktop", "icon": "ski" }
            ],
            "overrideBoundsCorrection": false,
            "enableScrolling": false,
            "visibleElements": 7,
            "hoverScale": 120,
            "cascadeScale": false,
            "iconsOnly": false,
            "focusRunning": true,
            "showRunningIndicators": true,
            "showRunningApps": true,
            "runningScope": "auto"
        })
    }

    readonly property var dockSettings: dockCfg.values
    readonly property bool currentEnabled: Boolean(dockSettings.enabled !== undefined ? dockSettings.enabled : true)
    readonly property string currentPosition: String(dockSettings.position !== undefined ? dockSettings.position : "bottom")
    readonly property bool currentOnTop: Boolean(dockSettings.onTop !== undefined ? dockSettings.onTop : true)
    readonly property bool currentBackground: Boolean(dockSettings.background !== undefined ? dockSettings.background : true)
    readonly property bool currentFloating: Boolean(dockSettings.floating !== undefined ? dockSettings.floating : false)
    readonly property bool currentExclusive: Boolean(dockSettings.exclusive !== undefined ? dockSettings.exclusive : (dockSettings.exclusiveMode !== undefined ? dockSettings.exclusiveMode : false))
    readonly property int currentElementSize: (!isNaN(parseInt(dockSettings.elementSize))) ? parseInt(dockSettings.elementSize) : 44
    readonly property bool currentOverrideBoundsCorrection: Boolean(dockSettings.overrideBoundsCorrection !== undefined ? dockSettings.overrideBoundsCorrection : false)
    readonly property int currentHoverScale: (!isNaN(parseInt(dockSettings.hoverScale))) ? parseInt(dockSettings.hoverScale) : 120
    readonly property bool currentCascadeScale: Boolean(dockSettings.cascadeScale !== undefined ? dockSettings.cascadeScale : false)
    readonly property bool currentIconsOnly: Boolean(dockSettings.iconsOnly !== undefined ? dockSettings.iconsOnly : false)
    readonly property bool currentEnableScrolling: Boolean(dockSettings.enableScrolling !== undefined ? dockSettings.enableScrolling : false)
    readonly property int currentVisibleElements: (!isNaN(parseInt(dockSettings.visibleElements)) && parseInt(dockSettings.visibleElements) > 0) ? parseInt(dockSettings.visibleElements) : 7
    readonly property bool currentSmartAutohide: Boolean(dockSettings.smartAutohide !== undefined ? dockSettings.smartAutohide : true)
    readonly property bool currentAutohide: Boolean(dockSettings.autohide !== undefined ? dockSettings.autohide : false)
    readonly property int currentAutohideTimeout: (!isNaN(parseInt(dockSettings.autohideTimeout))) ? parseInt(dockSettings.autohideTimeout) : 1000
    readonly property bool currentEditing: Boolean(dockSettings.editing !== undefined ? dockSettings.editing : false)
    readonly property var currentAppsList: Array.isArray(dockSettings.apps) ? dockSettings.apps : []
    readonly property bool currentFocusRunning: Boolean(dockSettings.focusRunning !== undefined ? dockSettings.focusRunning : true)
    readonly property bool currentShowRunningIndicators: Boolean(dockSettings.showRunningIndicators !== undefined ? dockSettings.showRunningIndicators : true)
    readonly property bool currentShowRunningApps: Boolean(dockSettings.showRunningApps !== undefined ? dockSettings.showRunningApps : false)
    readonly property string currentRunningScope: dockSettings.runningScope ? String(dockSettings.runningScope) : "auto"

    function updateDockSetting(key, value) {
        dockCfg.set(key, value);
    }

    function updateDockSettingDebounced(key, value) {
        dockCfg.setDebounced(key, value, 120);
    }

    function removeApp(idx) {
        let list = dockTabRoot.currentAppsList ? dockTabRoot.currentAppsList.slice() : [];
        if (idx >= 0 && idx < list.length) {
            list.splice(idx, 1);
            dockCfg.set("apps", list);
        }
    }

    onVisibleChanged: {
        if (!visible) {
            dockCfg.flush();
            if (posDropdown.isOpen) posDropdown.closePopup();
        }
    }

    GuideScrollView {
        id: mainFlickable
        rootObj: dockTabRoot.rootObj

            SettingsRow {
                settingId: "dock_enabled"
                rootObj: dockTabRoot.rootObj
                icon: "󰅀"
                title: I18n.t("guide.dock.enabled.title", "Enable dock")
                description: I18n.t("guide.dock.enabled.desc", "Enable floating application dock")
                searchKeywords: "dock enable toggle show taskbar panel launcher apps"

                Toggle {
                    Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                    checked: dockTabRoot.currentEnabled
                    accentColor: ThemeBackend.mauve
                    baseColor: ThemeBackend.surface1
                    handleColor: ThemeBackend.crust
                    handleOffColor: ThemeBackend.text
                    onToggled: function(val) {
                        dockTabRoot.updateDockSetting("enabled", val);
                    }
                }
            }

            CollapsibleSection {
                open: dockTabRoot.currentEnabled || dockAppsCard.tempVisible
                row: dockAppsCard

                Rectangle {
                    id: dockAppsCard
                    anchors.top: parent.top
                    anchors.left: parent.left
                    anchors.right: parent.right
                    clip: true
                    radius: ThemeBackend.borderRadius
                    readonly property color legacyColor: {
                        let base = Qt.alpha(ThemeBackend.surface0, 0.4);
                        if (highlightFlash > 0.001) {
                            return Qt.tint(base, Qt.rgba(ThemeBackend.mauve.r, ThemeBackend.mauve.g, ThemeBackend.mauve.b, highlightFlash * 0.12));
                        }
                        return base;
                    }
                    color: dockAppsGlass.active ? (highlightFlash > 0.001 ? Qt.alpha(ThemeBackend.mauve, highlightFlash * 0.12) : "transparent") : legacyColor

                    GlassFill {
                        id: dockAppsGlass
                        anchors.fill: parent
                        radius: parent.radius
                        tintColor: ThemeBackend.surface0
                        tintAmount: 0.25
                    }

                    property string settingId: "dock_apps"
                    property string title: I18n.t("guide.dock.apps.title", "Dock applications")
                    property string description: I18n.t("guide.dock.apps.desc", "Configure and organize applications displayed on the dock")
                    property string icon: "󰀻"
                    property string searchKeywords: "applications shortcuts pins favorites"
                    property bool searchable: true

                    property real highlightFlash: 0.0
                    property int handledHighlightToken: -1
                    property bool tempVisible: false

                    GuideSearchAnchor {
                        id: dockAppsSearchAnchor
                        targetItem: dockAppsCard
                        rootObj: dockTabRoot.rootObj
                        settingId: dockAppsCard.settingId
                        title: dockAppsCard.title
                        description: dockAppsCard.description
                        icon: dockAppsCard.icon
                        searchKeywords: dockAppsCard.searchKeywords
                        searchable: dockAppsCard.searchable
                    }

                    function triggerHighlightAnimation() {
                        dockAppsHighlightAnim.restart();
                        dockAppsSearchAnchor.ensureVisibleInFlickable();
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

                    Component.onCompleted: dockAppsCard.checkHighlight()

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
                                    let nextEditing = !dockTabRoot.currentEditing;
                                    dockTabRoot.updateDockSetting("editing", nextEditing);
                                    if (typeof Sounds !== "undefined") {
                                        Sounds.playSfx(nextEditing ? "guide/barconfig/out.wav" : "guide/barconfig/in.wav");
                                    }
                                    dockTabRoot.rootObj.dismissHost();
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
                                    color: appCardGlass1.active ? "transparent" : Qt.alpha(ThemeBackend.surface1, 0.3)

                                    GlassFill {
                                        id: appCardGlass1
                                        anchors.fill: parent
                                        radius: parent.radius
                                        tintColor: Qt.alpha(ThemeBackend.surface1, 0.3)
                                        tintAmount: 0.25
                                    }

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
                                            color: gf1.active ? "transparent" : ThemeBackend.surface0

                                            GlassFill {
                                                id: gf1
                                                anchors.fill: parent
                                                radius: parent.radius
                                                tintColor: ThemeBackend.surface0
                                                tintAmount: 0.25
                                            }
                                            clip: true

                                            Image {
                                                id: appCardIcon
                                                anchors.fill: parent
                                                anchors.margins: dockTabRoot.rootObj.s(4)
                                                fillMode: Image.PreserveAspectFit
                                                asynchronous: true
                                                smooth: true
                                                mipmap: true
                                                sourceSize: {
                                                    let s = Math.max(1, Math.ceil(dockTabRoot.rootObj.s(32) * (Screen.devicePixelRatio || 1)));
                                                    return Qt.size(s, s);
                                                }
                                                property bool failedLoad: false

                                                visible: source !== "" && status === Image.Ready && !failedLoad && !AppMatcher.iconMissing(source)

                                                source: {
                                                    let ic = modelData.icon || "";
                                                    return AppMatcher.iconSource(ic);
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

            SettingsBlob {
                CollapsibleSection {
                    open: dockTabRoot.currentEnabled || positionRow.tempVisible
                    row: positionRow

                    RevealableSettingsRow {
                        id: positionRow
                        settingId: "dock_position"
                        rootObj: dockTabRoot.rootObj
                        icon: "󰍹"
                        title: I18n.t("guide.dock.position.title", "Dock position")
                        description: I18n.t("guide.dock.position.desc", "Select the screen edge to anchor the dock")
                        searchKeywords: "dock position edge side bottom top left right anchor placement"
                        revealWhenClosed: !dockTabRoot.currentEnabled

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
                                dockTabRoot.updateDockSetting("position", pos);
                            }
                        }
                    }
                }

                CollapsibleSection {
                    open: dockTabRoot.currentEnabled || onTopRow.tempVisible
                    row: onTopRow

                    RevealableSettingsRow {
                        id: onTopRow
                        settingId: "dock_on_top"
                        rootObj: dockTabRoot.rootObj
                        icon: "󰹤"
                        title: I18n.t("guide.dock.on_top.title", "Place dock on top of windows")
                        description: I18n.t("guide.dock.on_top.desc", "Keep the dock visible above application windows")
                        searchKeywords: "dock top above overlay layer windows z-index"
                        revealWhenClosed: !dockTabRoot.currentEnabled

                        Toggle {
                            Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                            checked: dockTabRoot.currentOnTop
                            accentColor: ThemeBackend.mauve
                            baseColor: ThemeBackend.surface1
                            handleColor: ThemeBackend.crust
                            handleOffColor: ThemeBackend.text
                            onToggled: function(val) {
                                dockTabRoot.updateDockSetting("onTop", val);
                            }
                        }
                    }
                }

                CollapsibleSection {
                    open: dockTabRoot.currentEnabled || floatingRow.tempVisible
                    row: floatingRow

                    RevealableSettingsRow {
                        id: floatingRow
                        settingId: "dock_floating"
                        rootObj: dockTabRoot.rootObj
                        icon: "󰉈"
                        title: I18n.t("guide.dock.floating.title", "Floating dock")
                        description: I18n.t("guide.dock.floating.desc", "Detach dock from screen edge with rounded corners")
                        searchKeywords: "dock floating margin gap detached rounded pill"
                        revealWhenClosed: !dockTabRoot.currentEnabled

                        Toggle {
                            Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                            checked: dockTabRoot.currentFloating
                            accentColor: ThemeBackend.mauve
                            baseColor: ThemeBackend.surface1
                            handleColor: ThemeBackend.crust
                            handleOffColor: ThemeBackend.text
                            onToggled: function(val) {
                                dockTabRoot.updateDockSetting("floating", val);
                            }
                        }
                    }
                }

                CollapsibleSection {
                    open: dockTabRoot.currentEnabled || backgroundRow.tempVisible
                    row: backgroundRow

                    RevealableSettingsRow {
                        id: backgroundRow
                        settingId: "dock_background"
                        rootObj: dockTabRoot.rootObj
                        icon: "󰂵"
                        title: I18n.t("guide.dock.background.title", "Draw a background behind apps")
                        description: I18n.t("guide.dock.background.desc", "Show the dock panel behind app icons")
                        searchKeywords: "dock background panel backdrop transparent surface"
                        revealWhenClosed: !dockTabRoot.currentEnabled

                        Toggle {
                            Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                            checked: dockTabRoot.currentBackground
                            accentColor: ThemeBackend.mauve
                            baseColor: ThemeBackend.surface1
                            handleColor: ThemeBackend.crust
                            handleOffColor: ThemeBackend.text
                            onToggled: function(val) {
                                dockTabRoot.updateDockSetting("background", val);
                            }
                        }
                    }
                }

                CollapsibleSection {
                    open: dockTabRoot.currentEnabled || iconsOnlyRow.tempVisible
                    row: iconsOnlyRow

                    RevealableSettingsRow {
                        id: iconsOnlyRow
                        settingId: "dock_icons_only"
                        rootObj: dockTabRoot.rootObj
                        icon: "󰀻"
                        title: I18n.t("guide.dock.icons_only.title", "Icons only")
                        description: I18n.t("guide.dock.icons_only.desc", "Hide the box behind each app and show only its icon")
                        searchKeywords: "dock icons only minimal transparent tiles boxes"
                        revealWhenClosed: !dockTabRoot.currentEnabled

                        Toggle {
                            Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                            checked: dockTabRoot.currentIconsOnly
                            accentColor: ThemeBackend.mauve
                            baseColor: ThemeBackend.surface1
                            handleColor: ThemeBackend.crust
                            handleOffColor: ThemeBackend.text
                            onToggled: function(val) {
                                dockTabRoot.updateDockSetting("iconsOnly", val);
                            }
                        }
                    }
                }

                CollapsibleSection {
                    open: dockTabRoot.currentEnabled || exclusiveRow.tempVisible
                    row: exclusiveRow

                    RevealableSettingsRow {
                        id: exclusiveRow
                        settingId: "dock_exclusive"
                        rootObj: dockTabRoot.rootObj
                        icon: "󰖲"
                        title: I18n.t("guide.dock.exclusive.title", "Exclusive mode")
                        description: I18n.t("guide.dock.exclusive.desc", "Prevent windows from taking space occupied by the dock")
                        searchKeywords: "dock exclusive zone reserve space overlap tiling windows"
                        revealWhenClosed: !dockTabRoot.currentEnabled

                        Toggle {
                            Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                            checked: dockTabRoot.currentExclusive
                            accentColor: ThemeBackend.mauve
                            baseColor: ThemeBackend.surface1
                            handleColor: ThemeBackend.crust
                            handleOffColor: ThemeBackend.text
                            onToggled: function(val) {
                                dockTabRoot.updateDockSetting("exclusive", val);
                            }
                        }
                    }
                }
            }

            Loader {
                Layout.fillWidth: true
                active: dockTabRoot.deferredStage >= 1
                sourceComponent: SettingsBlob {
                    CollapsibleSection {
                        open: dockTabRoot.currentEnabled || elementSizeRow.tempVisible
                        row: elementSizeRow

                        RevealableSettingsRow {
                            id: elementSizeRow
                            settingId: "dock_element_size"
                            rootObj: dockTabRoot.rootObj
                            icon: "󰘖"
                            title: I18n.t("guide.dock.size.title", "Element size")
                            description: I18n.t("guide.dock.size.desc", "Dimensions of individual app buttons in pixels")
                            searchKeywords: "dock icon size height width pixels scale buttons"
                            revealWhenClosed: !dockTabRoot.currentEnabled

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
                                        dockTabRoot.updateDockSettingDebounced("elementSize", rounded);
                                    }
                                }
                                onDragFinished: {
                                    dockTabRoot.updateDockSetting("elementSize", Math.round(sizeSlider.value));
                                }
                            }
                        }
                    }

                    CollapsibleSection {
                        open: dockTabRoot.currentEnabled || overrideBoundsRow.tempVisible
                        row: overrideBoundsRow

                        RevealableSettingsRow {
                            id: overrideBoundsRow
                            settingId: "dock_override_bounds"
                            rootObj: dockTabRoot.rootObj
                            icon: "󰜤"
                            title: I18n.t("guide.dock.override_bounds.title", "Override out-of-screen-bounds size correction")
                            description: I18n.t("guide.dock.override_bounds.desc", "Keep custom element size even if dock exceeds screen limits")
                            searchKeywords: "dock bounds overflow size clamp shrink limit"
                            revealWhenClosed: !dockTabRoot.currentEnabled

                            Toggle {
                                Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                                checked: dockTabRoot.currentOverrideBoundsCorrection
                                accentColor: ThemeBackend.mauve
                                baseColor: ThemeBackend.surface1
                                handleColor: ThemeBackend.crust
                                handleOffColor: ThemeBackend.text
                                onToggled: function(val) {
                                    dockTabRoot.updateDockSetting("overrideBoundsCorrection", val);
                                }
                            }
                        }
                    }

                    CollapsibleSection {
                        open: dockTabRoot.currentEnabled || scrollingGroup.tempVisible
                        row: scrollingGroup

                        SettingsGroup {
                            id: scrollingGroup
                            anchors.top: parent.top
                            anchors.left: parent.left
                            anchors.right: parent.right
                            settingId: "dock_scrolling"
                            searchKeywords: "dock scroll wheel touchpad pagination overflow items"
                            rootObj: dockTabRoot.rootObj
                            icon: "󰍽"
                            title: I18n.t("guide.dock.scrolling.title", "Enable element scrolling")
                            description: I18n.t("guide.dock.scrolling.desc", "Limit visible elements and allow mouse wheel or touchpad scrolling")
                            expanded: dockTabRoot.currentEnableScrolling
                            forceOpen: visibleElementsRow.tempVisible

                            property bool tempVisible: false

                            onHighlighted: {
                                if (!dockTabRoot.currentEnabled) {
                                    tempVisible = true;
                                    scrollingCollapseTimer.restart();
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
                                    dockTabRoot.updateDockSetting("enableScrolling", val);
                                }
                            }

                            subSettings: [
                                RevealableSettingsRow {
                                    id: visibleElementsRow
                                    settingId: "dock_visible_elements"
                                    searchKeywords: "dock visible items count limit scroll max icons"
                                    rootObj: dockTabRoot.rootObj
                                    icon: "󰅫"
                                    title: I18n.t("guide.dock.visible_elements.title", "Visible elements")
                                    description: I18n.t("guide.dock.visible_elements.desc", "Number of dock items visible at the same time")

                                    pinToParent: false
                                    revealWhenClosed: !dockTabRoot.currentEnabled || !dockTabRoot.currentEnableScrolling

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
                                                dockTabRoot.updateDockSetting("visibleElements", v);
                                            }
                                        }
                                    }
                                }
                            ]
                        }
                    }
                }
            }

            Loader {
                Layout.fillWidth: true
                active: dockTabRoot.deferredStage >= 2
                sourceComponent: SettingsBlob {
                    CollapsibleSection {
                        open: dockTabRoot.currentEnabled || hoverScaleRow.tempVisible
                        row: hoverScaleRow

                        RevealableSettingsRow {
                            id: hoverScaleRow
                            settingId: "dock_hover_scale"
                            searchKeywords: "dock hover zoom magnification macos bounce grow scale"
                            rootObj: dockTabRoot.rootObj
                            icon: "󰍔"
                            title: I18n.t("guide.dock.hover_scale.title", "Hover scale effect")
                            description: I18n.t("guide.dock.hover_scale.desc", "Magnification level when hovering over dock items")
                            revealWhenClosed: !dockTabRoot.currentEnabled

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
                                        dockTabRoot.updateDockSettingDebounced("hoverScale", rounded);
                                    }
                                }
                                onDragFinished: {
                                    dockTabRoot.updateDockSetting("hoverScale", Math.round(hoverScaleSlider.value));
                                }
                            }
                        }
                    }

                    CollapsibleSection {
                        open: dockTabRoot.currentEnabled || cascadeScaleRow.tempVisible
                        row: cascadeScaleRow

                        RevealableSettingsRow {
                            id: cascadeScaleRow
                            settingId: "dock_cascade_scale"
                            searchKeywords: "dock cascade wave neighbors magnification hover zoom macos"
                            rootObj: dockTabRoot.rootObj
                            icon: "󰘚"
                            title: I18n.t("guide.dock.cascade_scale.title", "Scale nearest elements")
                            description: I18n.t("guide.dock.cascade_scale.desc", "Cascading magnification on neighboring icons")
                            revealWhenClosed: !dockTabRoot.currentEnabled

                            Toggle {
                                Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                                checked: dockTabRoot.currentCascadeScale
                                accentColor: ThemeBackend.mauve
                                baseColor: ThemeBackend.surface1
                                handleColor: ThemeBackend.crust
                                handleOffColor: ThemeBackend.text
                                onToggled: function(val) {
                                    dockTabRoot.updateDockSetting("cascadeScale", val);
                                }
                            }
                        }
                    }
                }
            }

            Loader {
                Layout.fillWidth: true
                active: dockTabRoot.deferredStage >= 3
                sourceComponent: SettingsBlob {
                    CollapsibleSection {
                        open: dockTabRoot.currentEnabled || autohideGroup.tempVisible
                        row: autohideGroup

                        SettingsGroup {
                            id: autohideGroup
                            anchors.top: parent.top
                            anchors.left: parent.left
                            anchors.right: parent.right
                            settingId: "dock_autohide"
                            searchKeywords: "dock autohide auto hide intellihide edge hover conceal"
                            rootObj: dockTabRoot.rootObj
                            icon: "󰘓"
                            title: I18n.t("guide.dock.autohide.title", "Auto-hide")
                            description: I18n.t("guide.dock.autohide.desc", "Hide the dock when not hovering over the screen edge")
                            expanded: dockTabRoot.currentAutohide || dockTabRoot.currentSmartAutohide
                            forceOpen: autohideTimeoutRow.tempVisible

                            property bool tempVisible: false

                            onHighlighted: {
                                if (!dockTabRoot.currentEnabled) {
                                    tempVisible = true;
                                    autohideCollapseTimer.restart();
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
                                    dockTabRoot.updateDockSetting("autohide", val);
                                }
                            }

                            subSettings: [
                                RevealableSettingsRow {
                                    id: autohideTimeoutRow
                                    settingId: "dock_autohide_delay"
                                    searchKeywords: "dock autohide timeout delay ms duration hide"
                                    rootObj: dockTabRoot.rootObj
                                    icon: "󰔛"
                                    title: I18n.t("guide.dock.timeout.title", "Auto-hide delay")
                                    description: I18n.t("guide.dock.timeout.desc", "Duration before hiding after pointer leaves")

                                    pinToParent: false
                                    revealWhenClosed: !dockTabRoot.currentEnabled || (!dockTabRoot.currentAutohide && !dockTabRoot.currentSmartAutohide)

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
                                                dockTabRoot.updateDockSettingDebounced("autohideTimeout", rounded);
                                            }
                                        }
                                        onDragFinished: {
                                            dockTabRoot.updateDockSetting("autohideTimeout", Math.round(timeoutSlider.value));
                                        }
                                    }
                                }
                            ]
                        }
                    }

                    CollapsibleSection {
                        open: dockTabRoot.currentEnabled || smartAutohideRow.tempVisible
                        row: smartAutohideRow

                        RevealableSettingsRow {
                            id: smartAutohideRow
                            settingId: "dock_smart_autohide"
                            searchKeywords: "dock smart autohide intellihide dodge windows desktop"
                            rootObj: dockTabRoot.rootObj
                            icon: "󱂬"
                            title: I18n.t("guide.dock.smart_autohide.title", "Smart auto-hide")
                            description: I18n.t("guide.dock.smart_autohide.desc", "Auto-hide dock only when windows are open, keep visible on desktop")
                            revealWhenClosed: !dockTabRoot.currentEnabled

                            Toggle {
                                Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                                checked: dockTabRoot.currentSmartAutohide
                                accentColor: ThemeBackend.mauve
                                baseColor: ThemeBackend.surface1
                                handleColor: ThemeBackend.crust
                                handleOffColor: ThemeBackend.text
                                onToggled: function(val) {
                                    dockTabRoot.updateDockSetting("smartAutohide", val);
                                }
                            }
                        }
                    }
                }
            }

            Loader {
                Layout.fillWidth: true
                active: dockTabRoot.deferredStage >= 4
                sourceComponent: SettingsBlob {
                    CollapsibleSection {
                        open: dockTabRoot.currentEnabled || focusRunningRow.tempVisible
                        row: focusRunningRow

                        SettingsRow {
                            id: focusRunningRow
                            anchors.top: parent.top
                            anchors.left: parent.left
                            anchors.right: parent.right
                            settingId: "dock_focus_running"
                            searchKeywords: "dock focus raise switch existing running window click activate"
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
                                    dockTabRoot.updateDockSetting("focusRunning", val);
                                }
                            }
                        }
                    }

                    CollapsibleSection {
                        open: dockTabRoot.currentEnabled || showIndicatorsRow.tempVisible
                        row: showIndicatorsRow

                        SettingsRow {
                            id: showIndicatorsRow
                            anchors.top: parent.top
                            anchors.left: parent.left
                            anchors.right: parent.right
                            settingId: "dock_show_running_indicators"
                            searchKeywords: "dock running indicators dots pills open apps active"
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
                                    dockTabRoot.updateDockSetting("showRunningIndicators", val);
                                }
                            }
                        }
                    }

                    CollapsibleSection {
                        open: dockTabRoot.currentEnabled || showRunningAppsRow.tempVisible
                        row: showRunningAppsRow

                        SettingsRow {
                            id: showRunningAppsRow
                            anchors.top: parent.top
                            anchors.left: parent.left
                            anchors.right: parent.right
                            settingId: "dock_show_running_apps"
                            searchKeywords: "dock running open unpinned apps taskbar windows"
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
                                    dockTabRoot.updateDockSetting("showRunningApps", val);
                                }
                            }
                        }
                    }

                    CollapsibleSection {
                        open: dockTabRoot.currentEnabled || runningScopeRow.tempVisible
                        row: runningScopeRow

                        SettingsRow {
                            id: runningScopeRow
                            anchors.top: parent.top
                            anchors.left: parent.left
                            anchors.right: parent.right
                            settingId: "dock_running_scope"
                            searchKeywords: "dock scope filter monitor workspace output active windows"
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
                                    dockTabRoot.updateDockSetting("runningScope", sc);
                                }
                            }
                        }
                    }
                }
            }
        }
    }
