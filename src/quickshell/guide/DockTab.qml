import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import "../"
import "../reusables"

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
        "elementSize": 44,
        "floating": false,
        "opacity": 100,
        "exclusive": false,
        "autohide": false,
        "autohideTimeout": 1000,
        "editing": false,
        "apps": [],
        "overrideBoundsCorrection": false,
        "enableScrolling": false,
        "visibleElements": 7,
        "hoverScale": 120,
        "cascadeScale": false
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
    property bool currentAutohide: dockSettings && dockSettings.autohide !== undefined ? dockSettings.autohide : false
    property int currentAutohideTimeout: (dockSettings && dockSettings.autohideTimeout !== undefined && !isNaN(parseInt(dockSettings.autohideTimeout))) ? parseInt(dockSettings.autohideTimeout) : 1000
    property bool currentEditing: dockSettings && dockSettings.editing !== undefined ? dockSettings.editing : false
    property var currentAppsList: (dockSettings && Array.isArray(dockSettings.apps)) ? dockSettings.apps : []

    function syncSettings() {
        let s = (typeof Config !== "undefined" && typeof Config.getSetting === "function")
            ? Config.getSetting("dock", dockTabRoot.defaultDockSettings)
            : dockTabRoot.defaultDockSettings;
        dockTabRoot.dockSettings = s;
        dockTabRoot.currentEnabled = s.enabled !== undefined ? s.enabled : true;
        dockTabRoot.currentPosition = s.position !== undefined ? s.position : "bottom";
        dockTabRoot.currentFloating = s.floating !== undefined ? s.floating : false;
        dockTabRoot.currentExclusive = s.exclusive !== undefined ? s.exclusive : (s.exclusiveMode !== undefined ? Boolean(s.exclusiveMode) : false);
        dockTabRoot.currentOpacity = s.opacity !== undefined ? Number(s.opacity) : (s.transparency !== undefined ? Math.max(0, 100 - Number(s.transparency)) : 100);
        dockTabRoot.currentElementSize = (s.elementSize !== undefined && !isNaN(parseInt(s.elementSize))) ? parseInt(s.elementSize) : 44;
        dockTabRoot.currentOverrideBoundsCorrection = s.overrideBoundsCorrection !== undefined ? s.overrideBoundsCorrection : false;
        dockTabRoot.currentHoverScale = (s.hoverScale !== undefined && !isNaN(parseInt(s.hoverScale))) ? parseInt(s.hoverScale) : 120;
        dockTabRoot.currentCascadeScale = s.cascadeScale !== undefined ? Boolean(s.cascadeScale) : false;
        dockTabRoot.currentEnableScrolling = s.enableScrolling !== undefined ? s.enableScrolling : false;
        dockTabRoot.currentVisibleElements = (s.visibleElements !== undefined && !isNaN(parseInt(s.visibleElements)) && parseInt(s.visibleElements) > 0) ? parseInt(s.visibleElements) : 7;
        dockTabRoot.currentAutohide = s.autohide !== undefined ? s.autohide : false;
        dockTabRoot.currentAutohideTimeout = (s.autohideTimeout !== undefined && !isNaN(parseInt(s.autohideTimeout))) ? parseInt(s.autohideTimeout) : 1000;
        dockTabRoot.currentEditing = s.editing !== undefined ? s.editing : false;
        dockTabRoot.currentAppsList = (s.apps && Array.isArray(s.apps)) ? s.apps : [];
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

            Rectangle {
                Layout.fillWidth: true
                implicitHeight: rowEnabledLayout.implicitHeight + rootObj.s(24)
                radius: ThemeBackend.borderRadius
                color: Qt.alpha(ThemeBackend.surface0, 0.4)
                border.width: 0

                RowLayout {
                    id: rowEnabledLayout
                    anchors.left: parent.left
                    anchors.leftMargin: rootObj.s(14)
                    anchors.right: parent.right
                    anchors.rightMargin: rootObj.s(14)
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: rootObj.s(12)

                    IconButton {
                        enabled: false
                        size: rootObj.s(32)
                        Layout.preferredWidth: rootObj.s(32)
                        Layout.preferredHeight: rootObj.s(32)
                        Layout.alignment: Qt.AlignVCenter
                        cornerRadius: ThemeBackend.borderRadius
                        buttonIcon: "󰅀"
                        iconFontSize: rootObj.s(16)
                        accentColor: ThemeBackend.surface0
                        textColor: "#ffffff"
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        Layout.alignment: Qt.AlignVCenter
                        spacing: rootObj.s(2)

                        Text {
                            Layout.fillWidth: true
                            text: I18n.t("guide.dock.enabled.title", "Enable dock")
                            font.family: ThemeBackend.fontFamily
                            font.pixelSize: rootObj.s(13)
                            color: ThemeBackend.text
                        }
                        Text {
                            Layout.fillWidth: true
                            text: I18n.t("guide.dock.enabled.desc", "Enable floating application dock")
                            font.family: ThemeBackend.fontFamily
                            font.pixelSize: rootObj.s(11)
                            color: ThemeBackend.subtext0
                        }
                    }

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
            }

            Rectangle {
                Layout.fillWidth: true
                implicitHeight: rowPosLayout.implicitHeight + rootObj.s(24)
                radius: ThemeBackend.borderRadius
                color: Qt.alpha(ThemeBackend.surface0, 0.4)
                border.width: 0
                visible: dockTabRoot.currentEnabled

                RowLayout {
                    id: rowPosLayout
                    anchors.left: parent.left
                    anchors.leftMargin: rootObj.s(14)
                    anchors.right: parent.right
                    anchors.rightMargin: rootObj.s(14)
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: rootObj.s(12)

                    IconButton {
                        enabled: false
                        size: rootObj.s(32)
                        Layout.preferredWidth: rootObj.s(32)
                        Layout.preferredHeight: rootObj.s(32)
                        Layout.alignment: Qt.AlignVCenter
                        cornerRadius: ThemeBackend.borderRadius
                        buttonIcon: "󰍹"
                        iconOffsetX: -2
                        iconFontSize: rootObj.s(16)
                        accentColor: ThemeBackend.surface0
                        textColor: "#ffffff"
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        Layout.alignment: Qt.AlignVCenter
                        spacing: rootObj.s(2)

                        Text {
                            Layout.fillWidth: true
                            text: I18n.t("guide.dock.position.title", "Dock position")
                            font.family: ThemeBackend.fontFamily
                            font.pixelSize: rootObj.s(13)
                            color: ThemeBackend.text
                        }
                        Text {
                            Layout.fillWidth: true
                            text: I18n.t("guide.dock.position.desc", "Select the screen edge to anchor the dock")
                            font.family: ThemeBackend.fontFamily
                            font.pixelSize: rootObj.s(11)
                            color: ThemeBackend.subtext0
                        }
                    }

                    Dropdown {
                        id: posDropdown
                        Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                        implicitWidth: rootObj.s(180)
                        implicitHeight: rootObj.s(32)
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
                        fontPixelSize: rootObj.s(11)
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

            Rectangle {
                Layout.fillWidth: true
                implicitHeight: rowFloatingLayout.implicitHeight + rootObj.s(24)
                radius: ThemeBackend.borderRadius
                color: Qt.alpha(ThemeBackend.surface0, 0.4)
                border.width: 0
                visible: dockTabRoot.currentEnabled

                RowLayout {
                    id: rowFloatingLayout
                    anchors.left: parent.left
                    anchors.leftMargin: rootObj.s(14)
                    anchors.right: parent.right
                    anchors.rightMargin: rootObj.s(14)
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: rootObj.s(12)

                    IconButton {
                        enabled: false
                        size: rootObj.s(32)
                        Layout.preferredWidth: rootObj.s(32)
                        Layout.preferredHeight: rootObj.s(32)
                        Layout.alignment: Qt.AlignVCenter
                        cornerRadius: ThemeBackend.borderRadius
                        buttonIcon: "󰉈"
                        iconFontSize: rootObj.s(16)
                        accentColor: ThemeBackend.surface0
                        textColor: "#ffffff"
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        Layout.alignment: Qt.AlignVCenter
                        spacing: rootObj.s(2)

                        Text {
                            Layout.fillWidth: true
                            text: I18n.t("guide.dock.floating.title", "Floating dock")
                            font.family: ThemeBackend.fontFamily
                            font.pixelSize: rootObj.s(13)
                            color: ThemeBackend.text
                        }
                        Text {
                            Layout.fillWidth: true
                            text: I18n.t("guide.dock.floating.desc", "Detach dock from screen edge with rounded corners")
                            font.family: ThemeBackend.fontFamily
                            font.pixelSize: rootObj.s(11)
                            color: ThemeBackend.subtext0
                        }
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

            Rectangle {
                Layout.fillWidth: true
                implicitHeight: rowExclusiveLayout.implicitHeight + rootObj.s(24)
                radius: ThemeBackend.borderRadius
                color: Qt.alpha(ThemeBackend.surface0, 0.4)
                border.width: 0
                visible: dockTabRoot.currentEnabled

                RowLayout {
                    id: rowExclusiveLayout
                    anchors.left: parent.left
                    anchors.leftMargin: rootObj.s(14)
                    anchors.right: parent.right
                    anchors.rightMargin: rootObj.s(14)
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: rootObj.s(12)

                    IconButton {
                        enabled: false
                        size: rootObj.s(32)
                        Layout.preferredWidth: rootObj.s(32)
                        Layout.preferredHeight: rootObj.s(32)
                        Layout.alignment: Qt.AlignVCenter
                        cornerRadius: ThemeBackend.borderRadius
                        buttonIcon: "󰖲"
                        iconFontSize: rootObj.s(16)
                        accentColor: ThemeBackend.surface0
                        textColor: "#ffffff"
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        Layout.alignment: Qt.AlignVCenter
                        spacing: rootObj.s(2)

                        Text {
                            Layout.fillWidth: true
                            text: I18n.t("guide.dock.exclusive.title", "Exclusive mode")
                            font.family: ThemeBackend.fontFamily
                            font.pixelSize: rootObj.s(13)
                            color: ThemeBackend.text
                        }
                        Text {
                            Layout.fillWidth: true
                            text: I18n.t("guide.dock.exclusive.desc", "Prevent windows from taking space occupied by the dock")
                            font.family: ThemeBackend.fontFamily
                            font.pixelSize: rootObj.s(11)
                            color: ThemeBackend.subtext0
                        }
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

            Rectangle {
                Layout.fillWidth: true
                implicitHeight: rowOpacityLayout.implicitHeight + rootObj.s(24)
                radius: ThemeBackend.borderRadius
                color: Qt.alpha(ThemeBackend.surface0, 0.4)
                border.width: 0
                visible: dockTabRoot.currentEnabled

                RowLayout {
                    id: rowOpacityLayout
                    anchors.left: parent.left
                    anchors.leftMargin: rootObj.s(14)
                    anchors.right: parent.right
                    anchors.rightMargin: rootObj.s(14)
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: rootObj.s(12)

                    IconButton {
                        enabled: false
                        size: rootObj.s(32)
                        Layout.preferredWidth: rootObj.s(32)
                        Layout.preferredHeight: rootObj.s(32)
                        Layout.alignment: Qt.AlignVCenter
                        cornerRadius: ThemeBackend.borderRadius
                        buttonIcon: "󰂵"
                        iconFontSize: rootObj.s(16)
                        accentColor: ThemeBackend.surface0
                        textColor: "#ffffff"
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        Layout.alignment: Qt.AlignVCenter
                        spacing: rootObj.s(2)

                        Text {
                            Layout.fillWidth: true
                            text: I18n.t("guide.dock.opacity.title", "Dock opacity")
                            font.family: ThemeBackend.fontFamily
                            font.pixelSize: rootObj.s(13)
                            color: ThemeBackend.text
                        }
                        Text {
                            Layout.fillWidth: true
                            text: I18n.t("guide.dock.opacity.desc", "Adjust dock background opacity level")
                            font.family: ThemeBackend.fontFamily
                            font.pixelSize: rootObj.s(11)
                            color: ThemeBackend.subtext0
                        }
                    }

                    Draggable {
                        id: opacitySlider
                        Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                        implicitWidth: rootObj.s(220)
                        implicitHeight: rootObj.s(18)
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

            Rectangle {
                Layout.fillWidth: true
                implicitHeight: sizeCol.implicitHeight + rootObj.s(24)
                radius: ThemeBackend.borderRadius
                color: Qt.alpha(ThemeBackend.surface0, 0.4)
                border.width: 0
                visible: dockTabRoot.currentEnabled

                ColumnLayout {
                    id: sizeCol
                    anchors.left: parent.left
                    anchors.leftMargin: rootObj.s(14)
                    anchors.right: parent.right
                    anchors.rightMargin: rootObj.s(14)
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: rootObj.s(12)

                    RowLayout {
                        id: rowSizeLayout
                        Layout.fillWidth: true
                        Layout.preferredWidth: sizeCol.width
                        spacing: rootObj.s(12)

                        IconButton {
                            enabled: false
                            size: rootObj.s(32)
                            Layout.preferredWidth: rootObj.s(32)
                            Layout.preferredHeight: rootObj.s(32)
                            Layout.alignment: Qt.AlignVCenter
                            cornerRadius: ThemeBackend.borderRadius
                            buttonIcon: "󰘖"
                            iconFontSize: rootObj.s(16)
                            accentColor: ThemeBackend.surface0
                            textColor: "#ffffff"
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            Layout.alignment: Qt.AlignVCenter
                            spacing: rootObj.s(2)

                            Text {
                                Layout.fillWidth: true
                                text: I18n.t("guide.dock.size.title", "Element size")
                                font.family: ThemeBackend.fontFamily
                                font.pixelSize: rootObj.s(13)
                                color: ThemeBackend.text
                            }
                            Text {
                                Layout.fillWidth: true
                                text: I18n.t("guide.dock.size.desc", "Dimensions of individual app buttons in pixels")
                                font.family: ThemeBackend.fontFamily
                                font.pixelSize: rootObj.s(11)
                                color: ThemeBackend.subtext0
                            }
                        }

                        Draggable {
                            id: sizeSlider
                            Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                            implicitWidth: rootObj.s(220)
                            implicitHeight: rootObj.s(18)
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

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredWidth: sizeCol.width
                        height: 1
                        color: Qt.alpha(ThemeBackend.surface1, 0.3)
                    }

                    RowLayout {
                        id: rowOverrideBoundsLayout
                        Layout.fillWidth: true
                        Layout.preferredWidth: sizeCol.width
                        spacing: rootObj.s(12)

                        IconButton {
                            enabled: false
                            size: rootObj.s(32)
                            Layout.preferredWidth: rootObj.s(32)
                            Layout.preferredHeight: rootObj.s(32)
                            Layout.alignment: Qt.AlignVCenter
                            cornerRadius: ThemeBackend.borderRadius
                            buttonIcon: "󰜤"
                            iconFontSize: rootObj.s(16)
                            accentColor: ThemeBackend.surface0
                            textColor: "#ffffff"
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            Layout.alignment: Qt.AlignVCenter
                            spacing: rootObj.s(2)

                            Text {
                                Layout.fillWidth: true
                                text: I18n.t("guide.dock.override_bounds.title", "Override out-of-screen-bounds size correction")
                                font.family: ThemeBackend.fontFamily
                                font.pixelSize: rootObj.s(13)
                                color: ThemeBackend.text
                            }
                            Text {
                                Layout.fillWidth: true
                                text: I18n.t("guide.dock.override_bounds.desc", "Keep custom element size even if dock exceeds screen limits")
                                font.family: ThemeBackend.fontFamily
                                font.pixelSize: rootObj.s(11)
                                color: ThemeBackend.subtext0
                            }
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
            }

            Rectangle {
                Layout.fillWidth: true
                implicitHeight: scaleCol.implicitHeight + rootObj.s(24)
                radius: ThemeBackend.borderRadius
                color: Qt.alpha(ThemeBackend.surface0, 0.4)
                border.width: 0
                visible: dockTabRoot.currentEnabled

                ColumnLayout {
                    id: scaleCol
                    anchors.left: parent.left
                    anchors.leftMargin: rootObj.s(14)
                    anchors.right: parent.right
                    anchors.rightMargin: rootObj.s(14)
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: rootObj.s(12)

                    RowLayout {
                        id: rowHoverScaleLayout
                        Layout.fillWidth: true
                        Layout.preferredWidth: scaleCol.width
                        spacing: rootObj.s(12)

                        IconButton {
                            enabled: false
                            size: rootObj.s(32)
                            Layout.preferredWidth: rootObj.s(32)
                            Layout.preferredHeight: rootObj.s(32)
                            Layout.alignment: Qt.AlignVCenter
                            cornerRadius: ThemeBackend.borderRadius
                            buttonIcon: "󰍔"
                            iconFontSize: rootObj.s(16)
                            accentColor: ThemeBackend.surface0
                            textColor: "#ffffff"
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            Layout.alignment: Qt.AlignVCenter
                            spacing: rootObj.s(2)

                            Text {
                                Layout.fillWidth: true
                                text: I18n.t("guide.dock.hover_scale.title", "Hover scale effect")
                                font.family: ThemeBackend.fontFamily
                                font.pixelSize: rootObj.s(13)
                                color: ThemeBackend.text
                            }
                            Text {
                                Layout.fillWidth: true
                                text: I18n.t("guide.dock.hover_scale.desc", "Magnification level when hovering over dock items")
                                font.family: ThemeBackend.fontFamily
                                font.pixelSize: rootObj.s(11)
                                color: ThemeBackend.subtext0
                            }
                        }

                        Draggable {
                            id: hoverScaleSlider
                            Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                            implicitWidth: rootObj.s(220)
                            implicitHeight: rootObj.s(18)
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

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredWidth: scaleCol.width
                        height: 1
                        color: Qt.alpha(ThemeBackend.surface1, 0.3)
                    }

                    RowLayout {
                        id: rowCascadeScaleLayout
                        Layout.fillWidth: true
                        Layout.preferredWidth: scaleCol.width
                        spacing: rootObj.s(12)

                        IconButton {
                            enabled: false
                            size: rootObj.s(32)
                            Layout.preferredWidth: rootObj.s(32)
                            Layout.preferredHeight: rootObj.s(32)
                            Layout.alignment: Qt.AlignVCenter
                            cornerRadius: ThemeBackend.borderRadius
                            buttonIcon: "󰘚"
                            iconFontSize: rootObj.s(16)
                            accentColor: ThemeBackend.surface0
                            textColor: "#ffffff"
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            Layout.alignment: Qt.AlignVCenter
                            spacing: rootObj.s(2)

                            Text {
                                Layout.fillWidth: true
                                text: I18n.t("guide.dock.cascade_scale.title", "Scale nearest elements")
                                font.family: ThemeBackend.fontFamily
                                font.pixelSize: rootObj.s(13)
                                color: ThemeBackend.text
                            }
                            Text {
                                Layout.fillWidth: true
                                text: I18n.t("guide.dock.cascade_scale.desc", "Cascading magnification on neighboring icons")
                                font.family: ThemeBackend.fontFamily
                                font.pixelSize: rootObj.s(11)
                                color: ThemeBackend.subtext0
                            }
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
            }

            Rectangle {
                Layout.fillWidth: true
                implicitHeight: scrollingCol.implicitHeight + rootObj.s(24)
                radius: ThemeBackend.borderRadius
                color: Qt.alpha(ThemeBackend.surface0, 0.4)
                border.width: 0
                visible: dockTabRoot.currentEnabled

                ColumnLayout {
                    id: scrollingCol
                    anchors.left: parent.left
                    anchors.leftMargin: rootObj.s(14)
                    anchors.right: parent.right
                    anchors.rightMargin: rootObj.s(14)
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: rootObj.s(12)

                    RowLayout {
                        id: rowScrollingLayout
                        Layout.fillWidth: true
                        Layout.preferredWidth: scrollingCol.width
                        spacing: rootObj.s(12)

                        IconButton {
                            enabled: false
                            size: rootObj.s(32)
                            Layout.preferredWidth: rootObj.s(32)
                            Layout.preferredHeight: rootObj.s(32)
                            Layout.alignment: Qt.AlignVCenter
                            cornerRadius: ThemeBackend.borderRadius
                            buttonIcon: "󰍽"
                            iconFontSize: rootObj.s(16)
                            accentColor: ThemeBackend.surface0
                            textColor: "#ffffff"
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            Layout.alignment: Qt.AlignVCenter
                            spacing: rootObj.s(2)

                            Text {
                                Layout.fillWidth: true
                                text: I18n.t("guide.dock.scrolling.title", "Enable element scrolling")
                                font.family: ThemeBackend.fontFamily
                                font.pixelSize: rootObj.s(13)
                                color: ThemeBackend.text
                            }
                            Text {
                                Layout.fillWidth: true
                                text: I18n.t("guide.dock.scrolling.desc", "Limit visible elements and allow mouse wheel or touchpad scrolling")
                                font.family: ThemeBackend.fontFamily
                                font.pixelSize: rootObj.s(11)
                                color: ThemeBackend.subtext0
                            }
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
                    }

                    Item {
                        id: visibleElementsInnerSection
                        Layout.fillWidth: true
                        Layout.preferredWidth: scrollingCol.width
                        clip: true
                        visible: implicitHeight > 0
                        opacity: dockTabRoot.currentEnableScrolling ? 1.0 : 0.0
                        implicitHeight: dockTabRoot.currentEnableScrolling ? (visibleElementsInnerCol.implicitHeight + rootObj.s(4)) : 0

                        Behavior on opacity { NumberAnimation { duration: 250; easing.type: Easing.OutCubic } }
                        Behavior on implicitHeight { NumberAnimation { duration: 250; easing.type: Easing.OutCubic } }

                        ColumnLayout {
                            id: visibleElementsInnerCol
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.top: parent.top
                            spacing: rootObj.s(12)

                            Rectangle {
                                Layout.fillWidth: true
                                Layout.preferredWidth: visibleElementsInnerCol.width
                                height: 1
                                color: Qt.alpha(ThemeBackend.surface1, 0.3)
                            }

                            RowLayout {
                                id: rowVisibleElementsLayout
                                Layout.fillWidth: true
                                Layout.preferredWidth: visibleElementsInnerCol.width
                                spacing: rootObj.s(12)

                                IconButton {
                                    enabled: false
                                    size: rootObj.s(32)
                                    Layout.preferredWidth: rootObj.s(32)
                                    Layout.preferredHeight: rootObj.s(32)
                                    Layout.alignment: Qt.AlignVCenter
                                    cornerRadius: ThemeBackend.borderRadius
                                    buttonIcon: "󰅫"
                                    iconFontSize: rootObj.s(16)
                                    accentColor: ThemeBackend.surface0
                                    textColor: "#ffffff"
                                }

                                ColumnLayout {
                                    Layout.fillWidth: true
                                    Layout.alignment: Qt.AlignVCenter
                                    spacing: rootObj.s(2)

                                    Text {
                                        Layout.fillWidth: true
                                        text: I18n.t("guide.dock.visible_elements.title", "Visible elements")
                                        font.family: ThemeBackend.fontFamily
                                        font.pixelSize: rootObj.s(13)
                                        color: ThemeBackend.text
                                    }
                                    Text {
                                        Layout.fillWidth: true
                                        text: I18n.t("guide.dock.visible_elements.desc", "Number of dock items visible at the same time")
                                        font.family: ThemeBackend.fontFamily
                                        font.pixelSize: rootObj.s(11)
                                        color: ThemeBackend.subtext0
                                    }
                                }

                                NumberSelector {
                                    id: visibleElementsSelector
                                    Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                                    implicitWidth: rootObj.s(120)
                                    implicitHeight: rootObj.s(32)
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
                                    fontPixelSize: rootObj.s(11)

                                    onValueChanged: {
                                        let v = Math.round(visibleElementsSelector.value);
                                        if (!isNaN(v) && v > 0 && dockTabRoot.currentVisibleElements !== v) {
                                            dockTabRoot.currentVisibleElements = v;
                                            dockTabRoot.updateDockSetting("visibleElements", v);
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                implicitHeight: autohideCol.implicitHeight + rootObj.s(24)
                radius: ThemeBackend.borderRadius
                color: Qt.alpha(ThemeBackend.surface0, 0.4)
                border.width: 0
                visible: dockTabRoot.currentEnabled

                ColumnLayout {
                    id: autohideCol
                    anchors.left: parent.left
                    anchors.leftMargin: rootObj.s(14)
                    anchors.right: parent.right
                    anchors.rightMargin: rootObj.s(14)
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: rootObj.s(12)

                    RowLayout {
                        id: rowAutohideLayout
                        Layout.fillWidth: true
                        Layout.preferredWidth: autohideCol.width
                        spacing: rootObj.s(12)

                        IconButton {
                            enabled: false
                            size: rootObj.s(32)
                            Layout.preferredWidth: rootObj.s(32)
                            Layout.preferredHeight: rootObj.s(32)
                            Layout.alignment: Qt.AlignVCenter
                            cornerRadius: ThemeBackend.borderRadius
                            buttonIcon: "󰘓"
                            iconFontSize: rootObj.s(16)
                            accentColor: ThemeBackend.surface0
                            textColor: "#ffffff"
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            Layout.alignment: Qt.AlignVCenter
                            spacing: rootObj.s(2)

                            Text {
                                Layout.fillWidth: true
                                text: I18n.t("guide.dock.autohide.title", "Auto-hide")
                                font.family: ThemeBackend.fontFamily
                                font.pixelSize: rootObj.s(13)
                                color: ThemeBackend.text
                            }
                            Text {
                                Layout.fillWidth: true
                                text: I18n.t("guide.dock.autohide.desc", "Hide the dock when not hovering over the screen edge")
                                font.family: ThemeBackend.fontFamily
                                font.pixelSize: rootObj.s(11)
                                color: ThemeBackend.subtext0
                            }
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
                    }

                    Item {
                        id: timeoutInnerSection
                        Layout.fillWidth: true
                        Layout.preferredWidth: autohideCol.width
                        clip: true
                        visible: implicitHeight > 0
                        opacity: dockTabRoot.currentAutohide ? 1.0 : 0.0
                        implicitHeight: dockTabRoot.currentAutohide ? (timeoutInnerCol.implicitHeight + rootObj.s(4)) : 0

                        Behavior on opacity { NumberAnimation { duration: 250; easing.type: Easing.OutCubic } }
                        Behavior on implicitHeight { NumberAnimation { duration: 250; easing.type: Easing.OutCubic } }

                        ColumnLayout {
                            id: timeoutInnerCol
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.top: parent.top
                            spacing: rootObj.s(12)

                            Rectangle {
                                Layout.fillWidth: true
                                Layout.preferredWidth: timeoutInnerCol.width
                                height: 1
                                color: Qt.alpha(ThemeBackend.surface1, 0.3)
                            }

                            RowLayout {
                                id: rowTimeoutLayout
                                Layout.fillWidth: true
                                Layout.preferredWidth: timeoutInnerCol.width
                                spacing: rootObj.s(12)

                                IconButton {
                                    enabled: false
                                    size: rootObj.s(32)
                                    Layout.preferredWidth: rootObj.s(32)
                                    Layout.preferredHeight: rootObj.s(32)
                                    Layout.alignment: Qt.AlignVCenter
                                    cornerRadius: ThemeBackend.borderRadius
                                    buttonIcon: "󰔛"
                                    iconFontSize: rootObj.s(16)
                                    accentColor: ThemeBackend.surface0
                                    textColor: "#ffffff"
                                }

                                ColumnLayout {
                                    Layout.fillWidth: true
                                    Layout.alignment: Qt.AlignVCenter
                                    spacing: rootObj.s(2)

                                    Text {
                                        Layout.fillWidth: true
                                        text: I18n.t("guide.dock.timeout.title", "Auto-hide delay")
                                        font.family: ThemeBackend.fontFamily
                                        font.pixelSize: rootObj.s(13)
                                        color: ThemeBackend.text
                                    }
                                    Text {
                                        Layout.fillWidth: true
                                        text: I18n.t("guide.dock.timeout.desc", "Duration before hiding after pointer leaves")
                                        font.family: ThemeBackend.fontFamily
                                        font.pixelSize: rootObj.s(11)
                                        color: ThemeBackend.subtext0
                                    }
                                }

                                Draggable {
                                    id: timeoutSlider
                                    Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                                    implicitWidth: rootObj.s(220)
                                    implicitHeight: rootObj.s(18)
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
                        }
                    }
                }
            }

            Rectangle {
                id: dockAppsCard
                Layout.fillWidth: true
                clip: true
                radius: ThemeBackend.borderRadius
                color: Qt.alpha(ThemeBackend.surface0, 0.4)
                border.color: Qt.alpha(ThemeBackend.surface1, 0.4)
                border.width: 1
                visible: dockTabRoot.currentEnabled

                implicitHeight: cardLayout.implicitHeight + rootObj.s(24)

                ColumnLayout {
                    id: cardLayout
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.margins: rootObj.s(12)
                    spacing: rootObj.s(12)

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: rootObj.s(10)

                        Text {
                            text: I18n.t("guide.dock.apps.title", "Dock Applications")
                            font.family: ThemeBackend.fontFamily
                            font.pixelSize: rootObj.s(13)
                            color: ThemeBackend.text
                        }

                        Text {
                            text: "(" + dockTabRoot.currentAppsList.length + " " + (dockTabRoot.currentAppsList.length === 1 ? I18n.t("guide.dock.apps.singular", "app") : I18n.t("guide.dock.apps.plural", "apps")) + ")"
                            font.family: ThemeBackend.fontFamily
                            font.pixelSize: rootObj.s(11)
                            color: ThemeBackend.subtext0
                        }

                        Item { Layout.fillWidth: true }

                        ClickButton {
                            Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                            maxWidth: rootObj.s(160)
                            implicitHeight: rootObj.s(32)
                            cornerRadius: ThemeBackend.borderRadius
                            buttonText: dockTabRoot.currentEditing ? I18n.t("guide.dock.apps.exit_edit", "Exit edit mode") : I18n.t("guide.dock.apps.enter_edit", "Edit")
                            buttonIcon: dockTabRoot.currentEditing ? "󰅖" : "󰏫"
                            iconFontSize: rootObj.s(14)
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
                        rowSpacing: rootObj.s(8)
                        columnSpacing: rootObj.s(8)
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
                                Layout.preferredHeight: rootObj.s(48)
                                radius: ThemeBackend.borderRadius
                                color: Qt.alpha(ThemeBackend.surface1, 0.3)
                                border.color: Qt.alpha(ThemeBackend.surface2, 0.35)
                                border.width: 1

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: rootObj.s(8)
                                    anchors.rightMargin: rootObj.s(8)
                                    spacing: rootObj.s(8)

                                    Rectangle {
                                        id: iconWrapper
                                        implicitWidth: rootObj.s(32)
                                        implicitHeight: rootObj.s(32)
                                        Layout.alignment: Qt.AlignVCenter
                                        radius: Math.round(rootObj.s(32) * 0.28)
                                        color: ThemeBackend.surface0
                                        clip: true

                                        Image {
                                            id: appCardIcon
                                            anchors.fill: parent
                                            anchors.margins: rootObj.s(4)
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
                                            font.pixelSize: rootObj.s(13)
                                            font.bold: true
                                            color: ThemeBackend.text
                                        }
                                    }

                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        Layout.alignment: Qt.AlignVCenter
                                        spacing: rootObj.s(1)

                                        Text {
                                            text: modelData.name || modelData.desktop_id || "App"
                                            font.family: ThemeBackend.fontFamily
                                            font.pixelSize: rootObj.s(12)
                                            font.bold: true
                                            color: ThemeBackend.text
                                            elide: Text.ElideRight
                                            Layout.fillWidth: true
                                        }

                                        Text {
                                            text: modelData.comment || modelData.desktop_id || ""
                                            font.family: ThemeBackend.fontFamily
                                            font.pixelSize: rootObj.s(10)
                                            color: ThemeBackend.subtext0
                                            elide: Text.ElideRight
                                            Layout.fillWidth: true
                                        }
                                    }

                                    DeleteButton {
                                        size: rootObj.s(28)
                                        cornerRadius: Math.min(ThemeBackend.borderRadius, rootObj.s(8))
                                        iconFontSize: rootObj.s(14)
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
                        Layout.preferredHeight: rootObj.s(40)
                        visible: dockTabRoot.currentAppsList.length === 0

                        Text {
                            anchors.centerIn: parent
                            text: I18n.t("guide.dock.apps.empty", "No applications configured for the dock")
                            font.family: ThemeBackend.fontFamily
                            font.pixelSize: rootObj.s(12)
                            color: ThemeBackend.subtext0
                        }
                    }
                }
            }
        }
    }
}
