import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Services.UPower
import "../../"
import "../../bar"
import "../../reusables"
import "../../reusables/guide"

Item {
    id: barModulesRoot
    required property var rootObj
    required property int tabIndex
    property int subTabIndex: 1

    anchors.fill: parent
    visible: rootObj.currentTab === tabIndex && (rootObj.currentSubTab === undefined || rootObj.currentSubTab === subTabIndex)
    opacity: visible ? 1.0 : 0.0
    property real slideY: visible ? 0 : rootObj.s(10)

    Behavior on slideY { NumberAnimation { duration: 250; easing.type: Easing.OutQuart } }
    transform: Translate { y: slideY }
    Behavior on opacity { NumberAnimation { duration: 250 } }

    property real cardRadius: ThemeBackend.clampedBorderRadius

    property bool isDesktop: (typeof UPower !== "undefined" && UPower.displayDevice && UPower.displayDevice.ready) ? !UPower.displayDevice.isLaptopBattery : (typeof SystemInfo !== "undefined" ? SystemInfo.isDesktop : false)

    property string barPosition: {
        let bs = Config.getSetting("bar", {});
        return bs && bs.position !== undefined ? bs.position : "top";
    }
    readonly property bool isSideBar: barPosition === "left" || barPosition === "right"

    property string workspacesStyle: {
        let bs = Config.getSetting("bar", {});
        if (bs && bs.workspacesStyle) return bs.workspacesStyle;
        return "pills";
    }

    property int workspaceCount: {
        let bs = Config.getSetting("bar", {});
        if (bs && bs.workspaceCount !== undefined) return bs.workspaceCount;
        return 8;
    }

    property bool hideEmptyWorkspaces: {
        let bs = Config.getSetting("bar", {});
        if (bs && bs.hideEmptyWorkspaces !== undefined) return Boolean(bs.hideEmptyWorkspaces);
        return false;
    }

    property string timeStyle: {
        let bs = Config.getSetting("bar", {});
        if (bs && bs.timeStyle) return bs.timeStyle;
        return "classic";
    }

    property bool timeShowDate: {
        let bs = Config.getSetting("bar", {});
        if (bs && bs.timeShowDate !== undefined) return bs.timeShowDate;
        if (bs && bs.showDate !== undefined) return bs.showDate;
        return true;
    }

    property string timeFormat: {
        let bs = Config.getSetting("bar", {});
        if (bs && bs.time && bs.time.format !== undefined) return bs.time.format;
        return "HH:mm:ss";
    }

    property int visBarCount: {
        let bs = Config.getSetting("bar", {});
        if (bs && bs.visBarCount !== undefined) return bs.visBarCount;
        return 16;
    }

    property string visAlignment: {
        let bs = Config.getSetting("bar", {});
        if (bs && bs.visAlignment) return bs.visAlignment;
        return "center";
    }

    property bool visContinuous: {
        let bs = Config.getSetting("bar", {});
        if (bs && bs.visContinuous !== undefined) return Boolean(bs.visContinuous);
        return false;
    }

    property string sysmonStyle: {
        let bs = Config.getSetting("bar", {});
        if (bs && bs.sysmonStyle) return bs.sysmonStyle;
        if (bs && bs.sysmon && bs.sysmon.style) return bs.sysmon.style;
        return "wave";
    }

    property var sysmonStats: {
        let bs = Config.getSetting("bar", {});
        if (bs && Array.isArray(bs.sysmonStats)) return bs.sysmonStats;
        if (bs && bs.sysmon && Array.isArray(bs.sysmon.stats)) return bs.sysmon.stats;
        if (bs && (bs.sysmonShowCpu !== undefined || bs.sysmonShowRam !== undefined || bs.sysmonShowTemp !== undefined || bs.sysmonShowDisk !== undefined)) {
            let stats = [];
            if (bs.sysmonShowCpu !== false) stats.push("cpu");
            if (bs.sysmonShowRam !== false) stats.push("ram");
            if (bs.sysmonShowTemp !== false) stats.push("temp");
            if (bs.sysmonShowDisk === true) stats.push("disk");
            return stats;
        }
        return ["cpu", "ram", "temp"];
    }

    readonly property var workspaceStyles: BarModuleRegistry.variantList("workspaces")
    readonly property var timeStyles: BarModuleRegistry.variantList("timedate")
    readonly property var batStyles: BarModuleRegistry.variantList("bat")

    property string batStyle: {
        let bs = Config.getSetting("bar", {});
        if (bs && bs.batStyle) return bs.batStyle;
        return "classic";
    }

    property bool batShowPercent: {
        let bs = Config.getSetting("bar", {});
        if (bs && bs.batShowPercent !== undefined) return Boolean(bs.batShowPercent);
        return true;
    }

    property bool batShowIcon: {
        let bs = Config.getSetting("bar", {});
        if (bs && bs.batShowIcon !== undefined) return Boolean(bs.batShowIcon);
        return true;
    }

    readonly property var previewWidget: ({
        "s": function(v) { return rootObj ? rootObj.s(v) : v; },
        "workspaceCount": 5,
        "activeIndex": 1,
        "isCompact": false,
        "isOccupied": function(idx) { return idx === 0 || idx === 1 || idx === 2; },
        "focusWorkspace": function(idx) {},
        "barWindow": { "startupCascadeFinished": true },
        "moduleActive": true
    })

    QtObject {
        id: previewTimeWidgetObj
        function s(v) { return rootObj ? rootObj.s(v) : v; }
        property bool isCompact: false
        property bool showDate: barModulesRoot.timeShowDate
        property string timeStr: (typeof DateTime !== "undefined" && DateTime.time) ? DateTime.time : "14:28"
        property string hourStr: (typeof DateTime !== "undefined" && DateTime.hour) ? DateTime.hour : "14"
        property string minuteStr: (typeof DateTime !== "undefined" && DateTime.minute) ? DateTime.minute : "28"
        property string secondStr: (typeof DateTime !== "undefined" && DateTime.second) ? DateTime.second : "00"
        property string dayStr: (typeof DateTime !== "undefined" && DateTime.day) ? DateTime.day : "18"
        property string monthStr: (typeof DateTime !== "undefined" && DateTime.monthShort) ? DateTime.monthShort : "Sep"
        property string fullDateStr: (typeof DateTime !== "undefined" && DateTime.fullDate) ? DateTime.fullDate : "Fri, Sep 18"
        property string dateStr: (typeof DateTime !== "undefined" && DateTime.fullDate) ? DateTime.fullDate : "Fri, Sep 18"
        property var barWindow: ({ "startupCascadeFinished": true, "s": function(v) { return rootObj ? rootObj.s(v) : v; } })
        property bool moduleActive: barModulesRoot.visible
    }

    QtObject {
        id: previewVisWidgetObj
        function s(v) { return rootObj ? rootObj.s(v) : v; }
        property bool isCompact: false
        property int barCount: barModulesRoot.visBarCount
        property string visAlignment: barModulesRoot.visAlignment
        property bool visContinuous: barModulesRoot.visContinuous
        property bool isPreview: true
        property var barWindow: ({ "startupCascadeFinished": true, "isStartupReady": true, "s": function(v) { return rootObj ? rootObj.s(v) : v; } })
        property bool moduleActive: barModulesRoot.visible
    }

    QtObject {
        id: previewSysWidgetObj
        function s(v) { return rootObj ? rootObj.s(v) : v; }
        property bool isCompact: false
        property string sysmonStyle: barModulesRoot.sysmonStyle
        property var sysmonStats: barModulesRoot.sysmonStats
        property bool isPreview: true
        property var barWindow: ({ "startupCascadeFinished": true, "isStartupReady": true, "isDataReady": true, "s": function(v) { return rootObj ? rootObj.s(v) : v; } })
        property bool moduleActive: barModulesRoot.visible
    }

    QtObject {
        id: previewBatWidgetObj
        function s(v) { return rootObj ? rootObj.s(v) : v; }
        property bool isCompact: false
        property string batStyle: barModulesRoot.batStyle
        property bool batShowPercent: barModulesRoot.batShowPercent
        property bool batShowIcon: barModulesRoot.batShowIcon
        property bool isPreview: true
        property var barWindow: ({ "startupCascadeFinished": true, "isStartupReady": true, "isDataReady": true, "s": function(v) { return rootObj ? rootObj.s(v) : v; } })
        property bool moduleActive: barModulesRoot.visible
    }

    function getFaceUrl(moduleId, variantId) {
        if (!moduleId) return "";
        let modId = (variantId !== undefined) ? moduleId : "workspaces";
        let vId = (variantId !== undefined) ? variantId : moduleId;
        return BarModuleRegistry.variantFaceFile(modId, vId, barModulesRoot.isSideBar);
    }

    function syncSettings() {
        let bs = Config.getSetting("bar", {});
        barModulesRoot.barPosition = (bs && bs.position !== undefined) ? bs.position : "top";

        if (bs && bs.workspacesStyle) {
            barModulesRoot.workspacesStyle = bs.workspacesStyle;
        } else {
            barModulesRoot.workspacesStyle = "pills";
        }

        if (bs && bs.workspaceCount !== undefined) {
            barModulesRoot.workspaceCount = bs.workspaceCount;
        } else {
            barModulesRoot.workspaceCount = 8;
        }

        if (bs && bs.hideEmptyWorkspaces !== undefined) {
            barModulesRoot.hideEmptyWorkspaces = Boolean(bs.hideEmptyWorkspaces);
        } else {
            barModulesRoot.hideEmptyWorkspaces = false;
        }

        if (bs && bs.timeStyle) {
            barModulesRoot.timeStyle = bs.timeStyle;
        } else {
            barModulesRoot.timeStyle = "classic";
        }

        if (bs && bs.timeShowDate !== undefined) {
            barModulesRoot.timeShowDate = bs.timeShowDate;
        } else if (bs && bs.showDate !== undefined) {
            barModulesRoot.timeShowDate = bs.showDate;
        } else {
            barModulesRoot.timeShowDate = true;
        }

        if (bs && bs.time && bs.time.format !== undefined) {
            barModulesRoot.timeFormat = bs.time.format;
        } else {
            barModulesRoot.timeFormat = "HH:mm:ss";
        }

        if (bs && bs.visBarCount !== undefined) {
            barModulesRoot.visBarCount = bs.visBarCount;
        } else {
            barModulesRoot.visBarCount = 16;
        }

        if (bs && bs.visAlignment) {
            barModulesRoot.visAlignment = bs.visAlignment;
        } else {
            barModulesRoot.visAlignment = "center";
        }

        if (bs && bs.visContinuous !== undefined) {
            barModulesRoot.visContinuous = Boolean(bs.visContinuous);
        } else {
            barModulesRoot.visContinuous = false;
        }

        if (bs && bs.sysmonStyle) {
            barModulesRoot.sysmonStyle = bs.sysmonStyle;
        } else {
            barModulesRoot.sysmonStyle = "wave";
        }

        if (bs && Array.isArray(bs.sysmonStats)) {
            barModulesRoot.sysmonStats = bs.sysmonStats;
        } else if (bs && (bs.sysmonShowCpu !== undefined || bs.sysmonShowRam !== undefined || bs.sysmonShowTemp !== undefined || bs.sysmonShowDisk !== undefined)) {
            let stats = [];
            if (bs.sysmonShowCpu !== false) stats.push("cpu");
            if (bs.sysmonShowRam !== false) stats.push("ram");
            if (bs.sysmonShowTemp !== false) stats.push("temp");
            if (bs.sysmonShowDisk === true) stats.push("disk");
            barModulesRoot.sysmonStats = stats;
        } else {
            barModulesRoot.sysmonStats = ["cpu", "ram", "temp"];
        }

        if (bs && bs.batStyle) {
            barModulesRoot.batStyle = bs.batStyle;
        } else {
            barModulesRoot.batStyle = "classic";
        }

        if (bs && bs.batShowPercent !== undefined) {
            barModulesRoot.batShowPercent = Boolean(bs.batShowPercent);
        } else {
            barModulesRoot.batShowPercent = true;
        }

        if (bs && bs.batShowIcon !== undefined) {
            barModulesRoot.batShowIcon = Boolean(bs.batShowIcon);
        } else {
            barModulesRoot.batShowIcon = true;
        }
    }

    function setWorkspacesStyle(styleName) {
        barModulesRoot.workspacesStyle = styleName;
        let current = Config.getSetting("bar", {});
        current.workspacesStyle = styleName;
        if (current.sideWorkspacesStyle !== undefined) delete current.sideWorkspacesStyle;
        Config.setSetting("bar", current);
    }

    function setWorkspaceCount(count) {
        barModulesRoot.workspaceCount = count;
        let current = Config.getSetting("bar", {});
        current.workspaceCount = count;
        if (current.sideWorkspaceCount !== undefined) delete current.sideWorkspaceCount;
        Config.setSetting("bar", current);
    }

    function setHideEmptyWorkspaces(val) {
        barModulesRoot.hideEmptyWorkspaces = val;
        let current = Config.getSetting("bar", {});
        current.hideEmptyWorkspaces = val;
        if (current.sideHideEmptyWorkspaces !== undefined) delete current.sideHideEmptyWorkspaces;
        Config.setSetting("bar", current);
    }

    function setTimeStyle(styleName) {
        barModulesRoot.timeStyle = styleName;
        let current = Config.getSetting("bar", {});
        current.timeStyle = styleName;
        if (current.sideTimeStyle !== undefined) delete current.sideTimeStyle;
        Config.setSetting("bar", current);
    }

    function setTimeShowDate(show) {
        barModulesRoot.timeShowDate = show;
        let current = Config.getSetting("bar", {});
        current.timeShowDate = show;
        if (current.showDate !== undefined) delete current.showDate;
        if (current.sideTimeShowDate !== undefined) delete current.sideTimeShowDate;
        Config.setSetting("bar", current);
    }

    function setTimeFormat(fmt) {
        barModulesRoot.timeFormat = fmt;
        let current = Config.getSetting("bar", {});
        if (!current.time) current.time = {};
        current.time.format = fmt;
        if (current.sideTime !== undefined) delete current.sideTime;
        Config.setSetting("bar", current);
    }

    function setVisBarCount(count) {
        barModulesRoot.visBarCount = count;
        let current = Config.getSetting("bar", {});
        current.visBarCount = count;
        Config.setSetting("bar", current);
    }

    function setVisAlignment(align) {
        barModulesRoot.visAlignment = align;
        let current = Config.getSetting("bar", {});
        current.visAlignment = align;
        Config.setSetting("bar", current);
    }

    function setVisContinuous(val) {
        barModulesRoot.visContinuous = val;
        let current = Config.getSetting("bar", {});
        current.visContinuous = val;
        Config.setSetting("bar", current);
    }

    function setSysmonStyle(styleName) {
        barModulesRoot.sysmonStyle = styleName;
        let current = Config.getSetting("bar", {});
        current.sysmonStyle = styleName;
        Config.setSetting("bar", current);
    }

    function isSysmonStatEnabled(stat) {
        return barModulesRoot.sysmonStats && barModulesRoot.sysmonStats.indexOf(stat) !== -1;
    }

    function toggleSysmonStat(stat, enabled) {
        let list = barModulesRoot.sysmonStats ? barModulesRoot.sysmonStats.slice() : ["cpu", "ram", "temp"];
        let allStats = ["cpu", "ram", "temp", "disk"];
        let set = {};
        for (let i = 0; i < list.length; i++) set[list[i]] = true;
        if (enabled) {
            set[stat] = true;
        } else {
            delete set[stat];
        }
        let res = [];
        for (let i = 0; i < allStats.length; i++) {
            if (set[allStats[i]]) res.push(allStats[i]);
        }
        barModulesRoot.sysmonStats = res;
        let current = Config.getSetting("bar", {});
        current.sysmonStats = res;
        Config.setSetting("bar", current);
    }

    function setBatStyle(styleName) {
        barModulesRoot.batStyle = styleName;
        let current = Config.getSetting("bar", {});
        current.batStyle = styleName;
        Config.setSetting("bar", current);
    }

    function setBatShowPercent(val) {
        barModulesRoot.batShowPercent = val;
        let current = Config.getSetting("bar", {});
        current.batShowPercent = val;
        Config.setSetting("bar", current);
    }

    function setBatShowIcon(val) {
        barModulesRoot.batShowIcon = val;
        let current = Config.getSetting("bar", {});
        current.batShowIcon = val;
        Config.setSetting("bar", current);
    }

    onVisAlignmentChanged: {
        let a = barModulesRoot.visAlignment;
        if (visAlignSwitch) {
            if (barModulesRoot.isSideBar) {
                visAlignSwitch.currentIndex = (a === "left" || a === "top") ? 0 : ((a === "right" || a === "bottom") ? 2 : 1);
            } else {
                visAlignSwitch.currentIndex = (a === "top" || a === "left") ? 0 : ((a === "bottom" || a === "right") ? 2 : 1);
            }
        }
    }

    onIsSideBarChanged: {
        let a = barModulesRoot.visAlignment;
        if (visAlignSwitch) {
            if (barModulesRoot.isSideBar) {
                visAlignSwitch.currentIndex = (a === "left" || a === "top") ? 0 : ((a === "right" || a === "bottom") ? 2 : 1);
            } else {
                visAlignSwitch.currentIndex = (a === "top" || a === "left") ? 0 : ((a === "bottom" || a === "right") ? 2 : 1);
            }
        }
    }

    onVisibleChanged: {
        if (visible) {
            syncSettings();
        }
    }

    Component.onCompleted: {
        syncSettings();
    }

    Connections {
        target: Config
        function onSettingsLoaded() {
            barModulesRoot.syncSettings();
        }
    }

    Flickable {
        anchors.fill: parent
        anchors.topMargin: rootObj.s(4)
        anchors.leftMargin: rootObj.s(8)
        anchors.rightMargin: rootObj.s(8)
        anchors.bottomMargin: rootObj.s(4)
        contentHeight: modulesCol.implicitHeight + rootObj.s(16)
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
            id: modulesCol
            width: parent.width - (parent.contentHeight > parent.height ? rootObj.s(6) : 0)
            spacing: rootObj.s(12)

            Rectangle {
                id: workspacesModuleBox
                Layout.fillWidth: true
                implicitHeight: workspacesCardLayout.implicitHeight + rootObj.s(24)
                radius: ThemeBackend.borderRadius
                color: Qt.alpha(ThemeBackend.surface0, 0.4)
                border.color: Qt.alpha(ThemeBackend.surface1, 0.4)
                border.width: 1
                clip: true

                ColumnLayout {
                    id: workspacesCardLayout
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.margins: rootObj.s(12)
                    spacing: rootObj.s(6)

                    RowLayout {
                        Layout.fillWidth: true
                        Layout.bottomMargin: rootObj.s(6)
                        Layout.leftMargin: rootObj.s(4)
                        Layout.rightMargin: rootObj.s(4)
                        spacing: rootObj.s(8)

                        Text {
                            text: I18n.t("guide.bar.modules.workspaces.name", "Workspaces")
                            font.family: ThemeBackend.fontFamily
                            font.pixelSize: rootObj.s(16)
                            font.bold: true
                            color: ThemeBackend.text
                        }
                    }

                    SettingsRow {
                        rootObj: barModulesRoot.rootObj
                        baseColor: Qt.alpha(ThemeBackend.surface1, 0.35)
                        icon: "󰮯"
                        title: I18n.t("guide.bar.workspaces.title")
                        description: I18n.t("guide.bar.workspaces.desc")

                        NumberSelector {
                            id: workspaceCountSelector
                            Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                            implicitWidth: rootObj.s(140)
                            implicitHeight: rootObj.s(32)
                            from: 2
                            to: 10
                            stepSize: 1
                            decimals: 0
                            value: barModulesRoot.workspaceCount
                            baseColor: ThemeBackend.surface0
                            accentColor: ThemeBackend.mauve
                            buttonColor: ThemeBackend.surface1
                            buttonTextColor: ThemeBackend.text
                            textColor: ThemeBackend.text
                            subTextColor: ThemeBackend.subtext0
                            borderColor: Qt.alpha(ThemeBackend.surface2, 0.6)
                            cornerRadius: ThemeBackend.borderRadius
                            fontFamily: ThemeBackend.fontFamily
                            fontPixelSize: rootObj.s(12)
                            onValueChanged: {
                                let rounded = Math.round(workspaceCountSelector.value);
                                if (barModulesRoot.workspaceCount !== rounded) {
                                    barModulesRoot.setWorkspaceCount(rounded);
                                }
                            }
                            onTriggered: {
                                barModulesRoot.setWorkspaceCount(Math.round(workspaceCountSelector.value));
                            }
                        }
                    }

                    SettingsRow {
                        rootObj: barModulesRoot.rootObj
                        baseColor: Qt.alpha(ThemeBackend.surface1, 0.35)
                        icon: "󰈈"
                        title: I18n.t("guide.bar.workspaces.hide_empty.title", "Hide empty workspaces")
                        description: I18n.t("guide.bar.workspaces.hide_empty.desc", "Show only occupied workspaces and the active one")

                        Toggle {
                            Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                            checked: barModulesRoot.hideEmptyWorkspaces
                            accentColor: ThemeBackend.mauve
                            baseColor: ThemeBackend.surface1
                            handleColor: ThemeBackend.crust
                            handleOffColor: ThemeBackend.text
                            onToggled: function(c) {
                                barModulesRoot.setHideEmptyWorkspaces(c);
                            }
                        }
                    }

                    SettingsRow {
                        id: workspacesStyleRow
                        rootObj: barModulesRoot.rootObj
                        settingId: "bar_workspaces_style"
                        searchKeywords: "pills numbers pacman workspaces style"
                        baseColor: Qt.alpha(ThemeBackend.surface1, 0.35)
                        icon: "󰮯"
                        title: I18n.t("guide.bar.workspaces.style.title", "Workspaces Style")
                        description: I18n.t("guide.bar.workspaces.style.desc", "Choose the visual style for workspace indicators")

                        bottomContent: GridLayout {
                            id: stylesGrid
                            Layout.fillWidth: true
                            columns: Math.max(1, Math.min(3, Math.floor(workspacesCardLayout.width / rootObj.s(160))))
                            rowSpacing: rootObj.s(10)
                            columnSpacing: rootObj.s(10)

                            Repeater {
                                model: barModulesRoot.workspaceStyles
                                delegate: Rectangle {
                                    id: styleCard
                                    required property var modelData
                                    required property int index

                                    readonly property bool isSelected: barModulesRoot.workspacesStyle === modelData.id
                                    property real popScale: 1.0
                                    property real flashOpacity: 0.0

                                    Layout.fillWidth: true
                                    Layout.preferredWidth: 1
                                    implicitHeight: styleInnerCol.implicitHeight + rootObj.s(16)
                                    radius: ThemeBackend.borderRadius
                                    clip: true

                                    color: cardMouse.pressed
                                        ? Qt.darker(ThemeBackend.surface0, 1.15)
                                        : (isSelected
                                            ? (cardHover.hovered ? Qt.lighter(ThemeBackend.surface0, 1.30) : Qt.lighter(ThemeBackend.surface0, 1.24))
                                            : (cardHover.hovered ? Qt.lighter(ThemeBackend.surface0, 1.10) : ThemeBackend.surface0))

                                    border.width: 1
                                    border.color: isSelected
                                        ? Qt.alpha(ThemeBackend.surface2, 0.75)
                                        : (cardHover.hovered ? Qt.alpha(ThemeBackend.surface2, 0.5) : Qt.alpha(ThemeBackend.surface1, 0.4))

                                    Behavior on color { ColorAnimation { duration: 180 } }
                                    Behavior on border.color { ColorAnimation { duration: 180 } }

                                    scale: (cardMouse.pressed ? 0.985 : (cardHover.hovered ? 1.015 : 1.0)) * styleCard.popScale
                                    Behavior on scale { NumberAnimation { duration: 250; easing.type: Easing.OutQuint } }

                                    HoverHandler {
                                        id: cardHover
                                    }

                                    Rectangle {
                                        anchors.fill: parent
                                        radius: parent.radius
                                        color: "#ffffff"
                                        opacity: styleCard.flashOpacity
                                        PropertyAnimation on opacity { id: flashAnim; to: 0; duration: 350; easing.type: Easing.OutExpo }
                                    }

                                    SequentialAnimation {
                                        id: popAnim
                                        NumberAnimation { target: styleCard; property: "popScale"; to: 1.02; duration: 100; easing.type: Easing.OutQuad }
                                        NumberAnimation { target: styleCard; property: "popScale"; to: 1.0; duration: 350; easing.type: Easing.OutQuint }
                                    }

                                    MouseArea {
                                        id: cardMouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            popAnim.start();
                                            styleCard.flashOpacity = 0.15;
                                            flashAnim.start();
                                            if (typeof Sounds !== "undefined") {
                                                Sounds.playSfx("reusables/clickbutton/click.wav");
                                            }
                                            barModulesRoot.setWorkspacesStyle(modelData.id);
                                        }
                                    }

                                    ColumnLayout {
                                        id: styleInnerCol
                                        anchors.left: parent.left
                                        anchors.right: parent.right
                                        anchors.top: parent.top
                                        anchors.margins: rootObj.s(8)
                                        spacing: rootObj.s(8)

                                        Rectangle {
                                            id: previewBox
                                            Layout.fillWidth: true
                                            implicitHeight: rootObj.s(barModulesRoot.isSideBar ? 160 : 72)
                                            radius: ThemeBackend.borderRadius
                                            color: Qt.darker(ThemeBackend.mantle, 1.1)
                                            clip: true

                                            Item {
                                                anchors.fill: parent
                                                enabled: false

                                                Loader {
                                                    id: facePreviewLoader
                                                    anchors.centerIn: parent
                                                    width: item ? item.implicitWidth : 0
                                                    height: item ? item.implicitHeight : 0
                                                    scale: Math.min(1.0, Math.min((previewBox.width - rootObj.s(16)) / Math.max(1, width), (previewBox.height - rootObj.s(16)) / Math.max(1, height)))
                                                    asynchronous: false
                                                    source: barModulesRoot.getFaceUrl("workspaces", modelData.id)

                                                    onLoaded: {
                                                        if (item) {
                                                            item.width = Qt.binding(function() { return item.implicitWidth; });
                                                            item.height = Qt.binding(function() { return item.implicitHeight; });
                                                            item.widget = barModulesRoot.previewWidget;
                                                        }
                                                    }
                                                }

                                                RowLayout {
                                                    anchors.centerIn: parent
                                                    visible: !barModulesRoot.isSideBar && (facePreviewLoader.status === Loader.Error || !facePreviewLoader.item)
                                                    spacing: rootObj.s(6)

                                                    Repeater {
                                                        model: 5
                                                        delegate: Rectangle {
                                                            required property int index
                                                            readonly property bool isActive: index === 1
                                                            width: modelData.id === "pills"
                                                                ? (isActive ? rootObj.s(22) : rootObj.s(8))
                                                                : rootObj.s(18)
                                                            height: modelData.id === "pills" ? rootObj.s(8) : rootObj.s(18)
                                                            radius: modelData.id === "pills" ? height / 2 : rootObj.s(4)
                                                            color: isActive ? ThemeBackend.mauve : Qt.alpha(ThemeBackend.surface2, 0.7)

                                                            Text {
                                                                anchors.centerIn: parent
                                                                visible: modelData.id === "numbers"
                                                                text: String(index + 1)
                                                                font.family: ThemeBackend.fontFamily
                                                                font.pixelSize: rootObj.s(10)
                                                                font.bold: isActive
                                                                color: isActive ? ThemeBackend.crust : ThemeBackend.text
                                                            }

                                                            Text {
                                                                anchors.centerIn: parent
                                                                visible: modelData.id === "pacman"
                                                                text: isActive ? "󰮯" : "•"
                                                                font.family: ThemeBackend.fontFamily
                                                                font.pixelSize: rootObj.s(14)
                                                                font.bold: false
                                                                color: isActive ? ThemeBackend.yellow : ThemeBackend.subtext0
                                                            }
                                                        }
                                                    }
                                                }

                                                ColumnLayout {
                                                    anchors.centerIn: parent
                                                    visible: barModulesRoot.isSideBar && (facePreviewLoader.status === Loader.Error || !facePreviewLoader.item)
                                                    spacing: rootObj.s(6)

                                                    Repeater {
                                                        model: 5
                                                        delegate: Rectangle {
                                                            required property int index
                                                            readonly property bool isActive: index === 1
                                                            width: rootObj.s(18)
                                                            height: modelData.id === "pills"
                                                                ? (isActive ? rootObj.s(36) : rootObj.s(18))
                                                                : rootObj.s(18)
                                                            radius: modelData.id === "pills" ? width / 2 : rootObj.s(4)
                                                            color: isActive ? ThemeBackend.mauve : Qt.alpha(ThemeBackend.surface2, 0.7)

                                                            Text {
                                                                anchors.centerIn: parent
                                                                visible: modelData.id === "numbers"
                                                                text: String(index + 1)
                                                                font.family: ThemeBackend.fontFamily
                                                                font.pixelSize: rootObj.s(10)
                                                                font.bold: isActive
                                                                color: isActive ? ThemeBackend.crust : ThemeBackend.text
                                                            }

                                                            Text {
                                                                anchors.centerIn: parent
                                                                visible: modelData.id === "pacman"
                                                                text: isActive ? "󰮯" : "•"
                                                                font.family: ThemeBackend.fontFamily
                                                                font.pixelSize: rootObj.s(14)
                                                                font.bold: false
                                                                color: isActive ? ThemeBackend.yellow : ThemeBackend.subtext0
                                                            }
                                                        }
                                                    }
                                                }
                                            }

                                            Rectangle {
                                                anchors.fill: parent
                                                radius: parent.radius
                                                color: "transparent"
                                                border.width: 1
                                                border.color: Qt.alpha(ThemeBackend.surface2, 0.25)
                                            }
                                        }

                                        Text {
                                            Layout.fillWidth: true
                                            Layout.leftMargin: rootObj.s(2)
                                            Layout.rightMargin: rootObj.s(2)
                                            Layout.bottomMargin: rootObj.s(2)
                                            text: modelData.name
                                            font.family: ThemeBackend.fontFamily
                                            font.pixelSize: rootObj.s(13)
                                            font.weight: Font.Bold
                                            color: ThemeBackend.text
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }

            Rectangle {
                id: timeDateModuleBox
                Layout.fillWidth: true
                implicitHeight: timeDateCardLayout.implicitHeight + rootObj.s(24)
                radius: ThemeBackend.borderRadius
                color: Qt.alpha(ThemeBackend.surface0, 0.4)
                border.color: Qt.alpha(ThemeBackend.surface1, 0.4)
                border.width: 1
                clip: true

                ColumnLayout {
                    id: timeDateCardLayout
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.margins: rootObj.s(12)
                    spacing: rootObj.s(6)

                    RowLayout {
                        Layout.fillWidth: true
                        Layout.bottomMargin: rootObj.s(6)
                        Layout.leftMargin: rootObj.s(4)
                        Layout.rightMargin: rootObj.s(4)
                        spacing: rootObj.s(8)

                        Text {
                            text: I18n.t("guide.bar.modules.timedate.name", "Time & Date")
                            font.family: ThemeBackend.fontFamily
                            font.pixelSize: rootObj.s(16)
                            font.bold: true
                            color: ThemeBackend.text
                        }
                    }

                    SettingsRow {
                        rootObj: barModulesRoot.rootObj
                        baseColor: Qt.alpha(ThemeBackend.surface1, 0.35)
                        icon: "󰃭"
                        title: I18n.t("guide.bar.timedate.show_date.title", "Show Date")
                        description: I18n.t("guide.bar.timedate.show_date.desc", "Display the date text alongside the clock")

                        Toggle {
                            Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                            checked: barModulesRoot.timeShowDate
                            accentColor: ThemeBackend.mauve
                            baseColor: ThemeBackend.surface1
                            handleColor: ThemeBackend.crust
                            handleOffColor: ThemeBackend.text
                            onToggled: function(c) {
                                barModulesRoot.setTimeShowDate(c);
                            }
                        }
                    }

                    SettingsRow {
                        rootObj: barModulesRoot.rootObj
                        baseColor: Qt.alpha(ThemeBackend.surface1, 0.35)
                        icon: "󰅐"
                        title: I18n.t("guide.bar.time.title", "Time Format")
                        description: I18n.t("guide.bar.time.desc", "Format pattern (e.g. HH:mm:ss)")

                        Input {
                            Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                            implicitWidth: rootObj.s(140)
                            implicitHeight: rootObj.s(32)
                            text: barModulesRoot.timeFormat
                            placeholderText: "HH:mm:ss"
                            baseColor: ThemeBackend.surface0
                            accentColor: ThemeBackend.mauve
                            textColor: ThemeBackend.text
                            subTextColor: ThemeBackend.subtext0
                            borderColor: Qt.alpha(ThemeBackend.surface2, 0.6)
                            cornerRadius: ThemeBackend.borderRadius
                            fontPixelSize: rootObj.s(11)
                            onTextEdited: function(newText) {
                                barModulesRoot.setTimeFormat(newText);
                            }
                            onAccepted: function(finalText) {
                                barModulesRoot.setTimeFormat(finalText);
                            }
                        }
                    }

                    SettingsRow {
                        id: timeStyleRow
                        rootObj: barModulesRoot.rootObj
                        settingId: "bar_timedate_style"
                        searchKeywords: "classic material badge time date clock style"
                        baseColor: Qt.alpha(ThemeBackend.surface1, 0.35)
                        icon: "󰥔"
                        title: I18n.t("guide.bar.timedate.style.title", "Time & Date Style")
                        description: I18n.t("guide.bar.timedate.style.desc", "Choose the visual style for the clock and date display")

                        bottomContent: GridLayout {
                            id: timeStylesGrid
                            Layout.fillWidth: true
                            columns: Math.max(1, Math.min(3, Math.floor(timeDateCardLayout.width / rootObj.s(160))))
                            rowSpacing: rootObj.s(10)
                            columnSpacing: rootObj.s(10)

                            Repeater {
                                model: barModulesRoot.timeStyles
                                delegate: Rectangle {
                                    id: timeStyleCard
                                    required property var modelData
                                    required property int index

                                    readonly property bool isSelected: barModulesRoot.timeStyle === modelData.id
                                    property real popScale: 1.0
                                    property real flashOpacity: 0.0

                                    Layout.fillWidth: true
                                    Layout.preferredWidth: 1
                                    implicitHeight: timeStyleInnerCol.implicitHeight + rootObj.s(16)
                                    radius: ThemeBackend.borderRadius
                                    clip: true

                                    color: timeCardMouse.pressed
                                        ? Qt.darker(ThemeBackend.surface0, 1.15)
                                        : (isSelected
                                            ? (timeCardHover.hovered ? Qt.lighter(ThemeBackend.surface0, 1.30) : Qt.lighter(ThemeBackend.surface0, 1.24))
                                            : (timeCardHover.hovered ? Qt.lighter(ThemeBackend.surface0, 1.10) : ThemeBackend.surface0))

                                    border.width: 1
                                    border.color: isSelected
                                        ? Qt.alpha(ThemeBackend.surface2, 0.75)
                                        : (timeCardHover.hovered ? Qt.alpha(ThemeBackend.surface2, 0.5) : Qt.alpha(ThemeBackend.surface1, 0.4))

                                    Behavior on color { ColorAnimation { duration: 180 } }
                                    Behavior on border.color { ColorAnimation { duration: 180 } }

                                    scale: (timeCardMouse.pressed ? 0.985 : (timeCardHover.hovered ? 1.015 : 1.0)) * timeStyleCard.popScale
                                    Behavior on scale { NumberAnimation { duration: 250; easing.type: Easing.OutQuint } }

                                    HoverHandler {
                                        id: timeCardHover
                                    }

                                    Rectangle {
                                        anchors.fill: parent
                                        radius: parent.radius
                                        color: "#ffffff"
                                        opacity: timeStyleCard.flashOpacity
                                        PropertyAnimation on opacity { id: timeFlashAnim; to: 0; duration: 350; easing.type: Easing.OutExpo }
                                    }

                                    SequentialAnimation {
                                        id: timePopAnim
                                        NumberAnimation { target: timeStyleCard; property: "popScale"; to: 1.02; duration: 100; easing.type: Easing.OutQuad }
                                        NumberAnimation { target: timeStyleCard; property: "popScale"; to: 1.0; duration: 350; easing.type: Easing.OutQuint }
                                    }

                                    MouseArea {
                                        id: timeCardMouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            timePopAnim.start();
                                            timeStyleCard.flashOpacity = 0.15;
                                            timeFlashAnim.start();
                                            if (typeof Sounds !== "undefined") {
                                                Sounds.playSfx("reusables/clickbutton/click.wav");
                                            }
                                            barModulesRoot.setTimeStyle(modelData.id);
                                        }
                                    }

                                    ColumnLayout {
                                        id: timeStyleInnerCol
                                        anchors.left: parent.left
                                        anchors.right: parent.right
                                        anchors.top: parent.top
                                        anchors.margins: rootObj.s(8)
                                        spacing: rootObj.s(8)

                                        Rectangle {
                                            id: timePreviewBox
                                            Layout.fillWidth: true
                                            implicitHeight: rootObj.s(barModulesRoot.isSideBar ? 140 : 72)
                                            radius: ThemeBackend.borderRadius
                                            color: Qt.darker(ThemeBackend.mantle, 1.1)
                                            clip: true

                                            Item {
                                                anchors.fill: parent
                                                enabled: false

                                                Loader {
                                                    id: timeFacePreviewLoader
                                                    anchors.centerIn: parent
                                                    width: item ? item.implicitWidth : 0
                                                    height: item ? item.implicitHeight : 0
                                                    scale: Math.min(1.0, Math.min((timePreviewBox.width - rootObj.s(16)) / Math.max(1, width), (timePreviewBox.height - rootObj.s(16)) / Math.max(1, height)))
                                                    asynchronous: false
                                                    source: barModulesRoot.getFaceUrl("timedate", modelData.id)

                                                    onLoaded: {
                                                        if (item) {
                                                            item.width = Qt.binding(function() { return item.implicitWidth; });
                                                            item.height = Qt.binding(function() { return item.implicitHeight; });
                                                            item.widget = previewTimeWidgetObj;
                                                        }
                                                    }
                                                }

                                                RowLayout {
                                                    anchors.centerIn: parent
                                                    visible: !barModulesRoot.isSideBar && (timeFacePreviewLoader.status === Loader.Error || !timeFacePreviewLoader.item)
                                                    spacing: rootObj.s(6)

                                                    Text {
                                                        text: "14:28:00"
                                                        font.family: ThemeBackend.fontFamily
                                                        font.pixelSize: rootObj.s(13)
                                                        font.bold: true
                                                        color: ThemeBackend.text
                                                    }
                                                }

                                                ColumnLayout {
                                                    anchors.centerIn: parent
                                                    visible: barModulesRoot.isSideBar && (timeFacePreviewLoader.status === Loader.Error || !timeFacePreviewLoader.item)
                                                    spacing: rootObj.s(3)

                                                    Text {
                                                        Layout.alignment: Qt.AlignHCenter
                                                        text: "14"
                                                        font.family: ThemeBackend.fontFamily
                                                        font.pixelSize: rootObj.s(13)
                                                        font.bold: true
                                                        color: ThemeBackend.blue
                                                    }

                                                    Text {
                                                        Layout.alignment: Qt.AlignHCenter
                                                        text: "28"
                                                        font.family: ThemeBackend.fontFamily
                                                        font.pixelSize: rootObj.s(13)
                                                        font.bold: true
                                                        color: ThemeBackend.sapphire
                                                    }

                                                    Rectangle {
                                                        Layout.alignment: Qt.AlignHCenter
                                                        width: rootObj.s(14)
                                                        height: 2
                                                        radius: 1
                                                        color: ThemeBackend.surface1
                                                    }

                                                    Text {
                                                        Layout.alignment: Qt.AlignHCenter
                                                        text: "18"
                                                        font.family: ThemeBackend.fontFamily
                                                        font.pixelSize: rootObj.s(10)
                                                        font.bold: true
                                                        color: ThemeBackend.text
                                                    }

                                                    Text {
                                                        Layout.alignment: Qt.AlignHCenter
                                                        text: "Sep"
                                                        font.family: ThemeBackend.fontFamily
                                                        font.pixelSize: rootObj.s(8)
                                                        font.bold: true
                                                        color: ThemeBackend.subtext0
                                                    }
                                                }
                                            }

                                            Rectangle {
                                                anchors.fill: parent
                                                radius: parent.radius
                                                color: "transparent"
                                                border.width: 1
                                                border.color: Qt.alpha(ThemeBackend.surface2, 0.25)
                                            }
                                        }

                                        Text {
                                            Layout.fillWidth: true
                                            Layout.leftMargin: rootObj.s(2)
                                            Layout.rightMargin: rootObj.s(2)
                                            Layout.bottomMargin: rootObj.s(2)
                                            text: modelData.name
                                            font.family: ThemeBackend.fontFamily
                                            font.pixelSize: rootObj.s(13)
                                            font.weight: Font.Bold
                                            color: ThemeBackend.text
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }

            Rectangle {
                id: visModuleBox
                Layout.fillWidth: true
                implicitHeight: visCardLayout.implicitHeight + rootObj.s(24)
                radius: ThemeBackend.borderRadius
                color: Qt.alpha(ThemeBackend.surface0, 0.4)
                border.color: Qt.alpha(ThemeBackend.surface1, 0.4)
                border.width: 1
                clip: true

                ColumnLayout {
                    id: visCardLayout
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.margins: rootObj.s(12)
                    spacing: rootObj.s(6)

                    RowLayout {
                        Layout.fillWidth: true
                        Layout.bottomMargin: rootObj.s(6)
                        Layout.leftMargin: rootObj.s(4)
                        Layout.rightMargin: rootObj.s(4)
                        spacing: rootObj.s(8)

                        Text {
                            text: I18n.t("guide.bar.modules.vis", "Visualizer")
                            font.family: ThemeBackend.fontFamily
                            font.pixelSize: rootObj.s(16)
                            font.bold: true
                            color: ThemeBackend.text
                        }
                    }

                    Rectangle {
                        id: visPreviewBox
                        Layout.fillWidth: true
                        implicitHeight: rootObj.s(barModulesRoot.isSideBar ? 120 : 72)
                        radius: ThemeBackend.borderRadius
                        color: Qt.darker(ThemeBackend.mantle, 1.1)
                        border.color: Qt.alpha(ThemeBackend.surface2, 0.25)
                        border.width: 1
                        clip: true

                        Item {
                            anchors.fill: parent
                            enabled: false

                            Rectangle {
                                anchors.centerIn: parent
                                width: (visFacePreviewLoader.item ? visFacePreviewLoader.item.implicitWidth : 0) * visFacePreviewLoader.scale
                                height: (visFacePreviewLoader.item ? visFacePreviewLoader.item.implicitHeight : rootObj.s(32)) * visFacePreviewLoader.scale
                                radius: ThemeBackend.borderRadius
                                color: Qt.alpha(ThemeBackend.surface0, 0.5)
                                border.color: Qt.alpha(ThemeBackend.surface2, 0.4)
                                border.width: 1
                                visible: width > 0 && height > 0
                            }

                            Loader {
                                id: visFacePreviewLoader
                                anchors.centerIn: parent
                                width: item ? item.implicitWidth : 0
                                height: item ? item.implicitHeight : rootObj.s(32)
                                scale: Math.min(1.0, Math.min((visPreviewBox.width - rootObj.s(16)) / Math.max(1, width), (visPreviewBox.height - rootObj.s(16)) / Math.max(1, height)))
                                asynchronous: false
                                source: barModulesRoot.isSideBar ? Qt.resolvedUrl("../../bar/faces/vis/SideVisFace.qml") : Qt.resolvedUrl("../../bar/faces/vis/VisFace.qml")

                                onLoaded: {
                                    if (item) {
                                        item.widget = previewVisWidgetObj;
                                        item.width = Qt.binding(function() { return item.implicitWidth; });
                                        item.height = Qt.binding(function() { return item.implicitHeight; });
                                    }
                                }
                            }
                        }
                    }

                    SettingsRow {
                        rootObj: barModulesRoot.rootObj
                        settingId: "bar_vis_bar_count"
                        searchKeywords: "visualizer bars count amount cava"
                        baseColor: Qt.alpha(ThemeBackend.surface1, 0.35)
                        icon: "󰝚"
                        title: I18n.t("guide.bar.vis.bars.title", "Amount of Bars")
                        description: I18n.t("guide.bar.vis.bars.desc", "Number of frequency bars to display")

                        NumberSelector {
                            id: visBarCountSelector
                            Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                            implicitWidth: rootObj.s(140)
                            implicitHeight: rootObj.s(32)
                            from: 4
                            to: 64
                            stepSize: 1
                            decimals: 0
                            value: barModulesRoot.visBarCount
                            baseColor: ThemeBackend.surface0
                            accentColor: ThemeBackend.mauve
                            buttonColor: ThemeBackend.surface1
                            buttonTextColor: ThemeBackend.text
                            textColor: ThemeBackend.text
                            subTextColor: ThemeBackend.subtext0
                            borderColor: Qt.alpha(ThemeBackend.surface2, 0.6)
                            cornerRadius: ThemeBackend.borderRadius
                            fontFamily: ThemeBackend.fontFamily
                            fontPixelSize: rootObj.s(12)
                            onValueChanged: {
                                let rounded = Math.round(visBarCountSelector.value);
                                if (barModulesRoot.visBarCount !== rounded) {
                                    barModulesRoot.setVisBarCount(rounded);
                                }
                            }
                            onTriggered: {
                                barModulesRoot.setVisBarCount(Math.round(visBarCountSelector.value));
                            }
                        }
                    }

                    SettingsRow {
                        rootObj: barModulesRoot.rootObj
                        settingId: "bar_vis_alignment"
                        searchKeywords: "visualizer alignment center top bottom align"
                        baseColor: Qt.alpha(ThemeBackend.surface1, 0.35)
                        icon: "󰆑"
                        title: I18n.t("guide.bar.vis.alignment.title", "Alignment")
                        description: I18n.t("guide.bar.vis.alignment.desc", "Center the visualizer or align to top or bottom")

                        Switch {
                            id: visAlignSwitch
                            Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                            implicitWidth: rootObj.s(220)
                            implicitHeight: rootObj.s(32)
                            cornerRadius: ThemeBackend.borderRadius
                            fontPixelSize: rootObj.s(11)
                            options: barModulesRoot.isSideBar
                                ? [
                                    I18n.t("guide.bar.vis.align.left", "Left"),
                                    I18n.t("guide.bar.vis.align.center", "Center"),
                                    I18n.t("guide.bar.vis.align.right", "Right")
                                ]
                                : [
                                    I18n.t("guide.bar.vis.align.top", "Top"),
                                    I18n.t("guide.bar.vis.align.center", "Center"),
                                    I18n.t("guide.bar.vis.align.bottom", "Bottom")
                                ]
                            currentIndex: {
                                let a = barModulesRoot.visAlignment;
                                if (barModulesRoot.isSideBar) {
                                    if (a === "left" || a === "top") return 0;
                                    if (a === "right" || a === "bottom") return 2;
                                    return 1;
                                } else {
                                    if (a === "top" || a === "left") return 0;
                                    if (a === "bottom" || a === "right") return 2;
                                    return 1;
                                }
                            }
                            accentColor: ThemeBackend.mauve
                            baseColor: ThemeBackend.surface0
                            textColor: ThemeBackend.text
                            activeTextColor: ThemeBackend.crust
                            onValueChanged: function(index, value) {
                                let align = "center";
                                if (barModulesRoot.isSideBar) {
                                    align = index === 0 ? "left" : (index === 2 ? "right" : "center");
                                } else {
                                    align = index === 0 ? "top" : (index === 2 ? "bottom" : "center");
                                }
                                barModulesRoot.setVisAlignment(align);
                            }
                        }
                    }

                    SettingsRow {
                        rootObj: barModulesRoot.rootObj
                        settingId: "bar_vis_continuous"
                        searchKeywords: "visualizer continuous wave smooth fluid"
                        baseColor: Qt.alpha(ThemeBackend.surface1, 0.35)
                        icon: "󰓃"
                        title: I18n.t("guide.bar.vis.continuous.title", "Continuous Wave")
                        description: I18n.t("guide.bar.vis.continuous.desc", "Render a smooth fluid wave instead of discrete bars")

                        Toggle {
                            Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                            checked: barModulesRoot.visContinuous
                            accentColor: ThemeBackend.mauve
                            baseColor: ThemeBackend.surface1
                            handleColor: ThemeBackend.crust
                            handleOffColor: ThemeBackend.text
                            onToggled: function(c) {
                                barModulesRoot.setVisContinuous(c);
                            }
                        }
                    }
                }
            }

            Rectangle {
                id: sysmonModuleBox
                Layout.fillWidth: true
                implicitHeight: sysmonCardLayout.implicitHeight + rootObj.s(24)
                radius: ThemeBackend.borderRadius
                color: Qt.alpha(ThemeBackend.surface0, 0.4)
                border.color: Qt.alpha(ThemeBackend.surface1, 0.4)
                border.width: 1
                clip: true

                ColumnLayout {
                    id: sysmonCardLayout
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.margins: rootObj.s(12)
                    spacing: rootObj.s(6)

                    RowLayout {
                        Layout.fillWidth: true
                        Layout.bottomMargin: rootObj.s(6)
                        Layout.leftMargin: rootObj.s(4)
                        Layout.rightMargin: rootObj.s(4)
                        spacing: rootObj.s(8)

                        Text {
                            text: I18n.t("guide.bar.modules.sysmon", "System Monitor")
                            font.family: ThemeBackend.fontFamily
                            font.pixelSize: rootObj.s(16)
                            font.bold: true
                            color: ThemeBackend.text
                        }
                    }

                    Rectangle {
                        id: sysmonPreviewBox
                        Layout.fillWidth: true
                        implicitHeight: rootObj.s(barModulesRoot.isSideBar ? 150 : 72)
                        radius: ThemeBackend.borderRadius
                        color: Qt.darker(ThemeBackend.mantle, 1.1)
                        border.color: Qt.alpha(ThemeBackend.surface2, 0.25)
                        border.width: 1
                        clip: true

                        Item {
                            anchors.fill: parent
                            enabled: false

                            Rectangle {
                                anchors.centerIn: parent
                                width: (sysmonFacePreviewLoader.item ? sysmonFacePreviewLoader.item.implicitWidth : 0) * sysmonFacePreviewLoader.scale
                                height: (sysmonFacePreviewLoader.item ? sysmonFacePreviewLoader.item.implicitHeight : rootObj.s(32)) * sysmonFacePreviewLoader.scale
                                radius: ThemeBackend.borderRadius
                                color: Qt.alpha(ThemeBackend.surface0, 0.5)
                                border.color: Qt.alpha(ThemeBackend.surface2, 0.4)
                                border.width: 1
                                visible: width > 0 && height > 0
                            }

                            Loader {
                                id: sysmonFacePreviewLoader
                                anchors.centerIn: parent
                                width: item ? item.implicitWidth : 0
                                height: item ? item.implicitHeight : rootObj.s(32)
                                scale: Math.min(1.0, Math.min((sysmonPreviewBox.width - rootObj.s(16)) / Math.max(1, width), (sysmonPreviewBox.height - rootObj.s(16)) / Math.max(1, height)))
                                asynchronous: false
                                source: barModulesRoot.isSideBar ? Qt.resolvedUrl("../../bar/faces/sysmon/SideSysMonFace.qml") : Qt.resolvedUrl("../../bar/faces/sysmon/SysMonFace.qml")

                                onLoaded: {
                                    if (item) {
                                        item.widget = previewSysWidgetObj;
                                        item.width = Qt.binding(function() { return item.implicitWidth; });
                                        item.height = Qt.binding(function() { return item.implicitHeight; });
                                    }
                                }
                            }
                        }
                    }

                    SettingsRow {
                        rootObj: barModulesRoot.rootObj
                        settingId: "bar_sysmon_style"
                        searchKeywords: "sysmon system monitor circle style wave ring"
                        baseColor: Qt.alpha(ThemeBackend.surface1, 0.35)
                        icon: "󱐋"
                        title: I18n.t("guide.bar.sysmon.style.title", "Circle Style")
                        description: I18n.t("guide.bar.sysmon.style.desc", "Visual appearance of the progress rings")

                        Switch {
                            Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                            implicitWidth: rootObj.s(200)
                            implicitHeight: rootObj.s(32)
                            cornerRadius: ThemeBackend.borderRadius
                            fontPixelSize: rootObj.s(11)
                            options: [
                                I18n.t("guide.bar.sysmon.style.wave", "Wave"),
                                I18n.t("guide.bar.sysmon.style.circle", "Circle")
                            ]
                            currentIndex: barModulesRoot.sysmonStyle === "circle" ? 1 : 0
                            accentColor: ThemeBackend.mauve
                            baseColor: ThemeBackend.surface0
                            textColor: ThemeBackend.text
                            activeTextColor: ThemeBackend.crust
                            onValueChanged: function(index, value) {
                                barModulesRoot.setSysmonStyle(index === 1 ? "circle" : "wave");
                            }
                        }
                    }

                    SettingsRow {
                        rootObj: barModulesRoot.rootObj
                        settingId: "bar_sysmon_cpu"
                        searchKeywords: "sysmon cpu processor load usage"
                        baseColor: Qt.alpha(ThemeBackend.surface1, 0.35)
                        icon: "󰍛"
                        title: I18n.t("guide.bar.sysmon.cpu.title", "CPU Usage")
                        description: I18n.t("guide.bar.sysmon.cpu.desc", "Display processor utilization ring")

                        Toggle {
                            Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                            checked: barModulesRoot.isSysmonStatEnabled("cpu")
                            accentColor: ThemeBackend.mauve
                            baseColor: ThemeBackend.surface1
                            handleColor: ThemeBackend.crust
                            handleOffColor: ThemeBackend.text
                            onToggled: function(c) {
                                barModulesRoot.toggleSysmonStat("cpu", c);
                            }
                        }
                    }

                    SettingsRow {
                        rootObj: barModulesRoot.rootObj
                        settingId: "bar_sysmon_ram"
                        searchKeywords: "sysmon ram memory usage"
                        baseColor: Qt.alpha(ThemeBackend.surface1, 0.35)
                        icon: "󰘚"
                        title: I18n.t("guide.bar.sysmon.ram.title", "Memory Usage")
                        description: I18n.t("guide.bar.sysmon.ram.desc", "Display memory (RAM) utilization ring")

                        Toggle {
                            Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                            checked: barModulesRoot.isSysmonStatEnabled("ram")
                            accentColor: ThemeBackend.mauve
                            baseColor: ThemeBackend.surface1
                            handleColor: ThemeBackend.crust
                            handleOffColor: ThemeBackend.text
                            onToggled: function(c) {
                                barModulesRoot.toggleSysmonStat("ram", c);
                            }
                        }
                    }

                    SettingsRow {
                        rootObj: barModulesRoot.rootObj
                        settingId: "bar_sysmon_temp"
                        searchKeywords: "sysmon temperature temp degrees"
                        baseColor: Qt.alpha(ThemeBackend.surface1, 0.35)
                        icon: "󰔏"
                        title: I18n.t("guide.bar.sysmon.temp.title", "Temperature")
                        description: I18n.t("guide.bar.sysmon.temp.desc", "Display system temperature ring")

                        Toggle {
                            Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                            checked: barModulesRoot.isSysmonStatEnabled("temp")
                            accentColor: ThemeBackend.mauve
                            baseColor: ThemeBackend.surface1
                            handleColor: ThemeBackend.crust
                            handleOffColor: ThemeBackend.text
                            onToggled: function(c) {
                                barModulesRoot.toggleSysmonStat("temp", c);
                            }
                        }
                    }

                    SettingsRow {
                        rootObj: barModulesRoot.rootObj
                        settingId: "bar_sysmon_disk"
                        searchKeywords: "sysmon disk storage usage space drive"
                        baseColor: Qt.alpha(ThemeBackend.surface1, 0.35)
                        icon: "󰋊"
                        title: I18n.t("guide.bar.sysmon.disk.title", "Disk Usage")
                        description: I18n.t("guide.bar.sysmon.disk.desc", "Display storage disk utilization ring")

                        Toggle {
                            Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                            checked: barModulesRoot.isSysmonStatEnabled("disk")
                            accentColor: ThemeBackend.mauve
                            baseColor: ThemeBackend.surface1
                            handleColor: ThemeBackend.crust
                            handleOffColor: ThemeBackend.text
                            onToggled: function(c) {
                                barModulesRoot.toggleSysmonStat("disk", c);
                            }
                        }
                    }
                }
            }

            Rectangle {
                id: batteryModuleBox
                visible: !barModulesRoot.isDesktop
                Layout.fillWidth: true
                implicitHeight: visible ? (batteryCardLayout.implicitHeight + rootObj.s(24)) : 0
                radius: ThemeBackend.borderRadius
                color: Qt.alpha(ThemeBackend.surface0, 0.4)
                border.color: Qt.alpha(ThemeBackend.surface1, 0.4)
                border.width: 1
                clip: true

                ColumnLayout {
                    id: batteryCardLayout
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.margins: rootObj.s(12)
                    spacing: rootObj.s(6)

                    RowLayout {
                        Layout.fillWidth: true
                        Layout.bottomMargin: rootObj.s(6)
                        Layout.leftMargin: rootObj.s(4)
                        Layout.rightMargin: rootObj.s(4)
                        spacing: rootObj.s(8)

                        Text {
                            text: I18n.t("guide.bar.modules.battery", "Battery")
                            font.family: ThemeBackend.fontFamily
                            font.pixelSize: rootObj.s(16)
                            font.bold: true
                            color: ThemeBackend.text
                        }
                    }

                    Rectangle {
                        id: batPreviewBox
                        Layout.fillWidth: true
                        implicitHeight: rootObj.s(barModulesRoot.isSideBar ? 120 : 72)
                        radius: ThemeBackend.borderRadius
                        color: Qt.darker(ThemeBackend.mantle, 1.1)
                        border.color: Qt.alpha(ThemeBackend.surface2, 0.25)
                        border.width: 1
                        clip: true

                        Item {
                            anchors.fill: parent
                            enabled: false

                            Loader {
                                id: batFacePreviewLoader
                                anchors.centerIn: parent
                                width: item ? item.implicitWidth : 0
                                height: item ? item.implicitHeight : 0
                                scale: Math.min(1.0, Math.min((batPreviewBox.width - rootObj.s(16)) / Math.max(1, width), (batPreviewBox.height - rootObj.s(16)) / Math.max(1, height)))
                                asynchronous: false
                                source: barModulesRoot.isSideBar
                                    ? Qt.resolvedUrl("../../bar/faces/bat/SideBatFace.qml")
                                    : Qt.resolvedUrl("../../bar/faces/bat/BatFace.qml")

                                onLoaded: {
                                    if (item) {
                                        item.widget = previewBatWidgetObj;
                                        item.width = Qt.binding(function() { return item.implicitWidth; });
                                        item.height = Qt.binding(function() { return item.implicitHeight; });
                                    }
                                }
                            }
                        }
                    }

                    SettingsRow {
                        rootObj: barModulesRoot.rootObj
                        settingId: "bar_bat_show_percent"
                        searchKeywords: "battery charge percentage percent number"
                        baseColor: Qt.alpha(ThemeBackend.surface1, 0.35)
                        icon: "󰚥"
                        title: I18n.t("guide.bar.bat.show_percent.title", "Show Percentage")
                        description: I18n.t("guide.bar.bat.show_percent.desc", "Display the numeric battery charge percentage")
                        visible: !barModulesRoot.isSideBar
                        searchable: !barModulesRoot.isSideBar
                        hiddenByConfig: barModulesRoot.isSideBar

                        Toggle {
                            Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                            checked: barModulesRoot.batShowPercent
                            accentColor: ThemeBackend.mauve
                            baseColor: ThemeBackend.surface1
                            handleColor: ThemeBackend.crust
                            handleOffColor: ThemeBackend.text
                            onToggled: function(c) {
                                barModulesRoot.setBatShowPercent(c);
                            }
                        }
                    }

                    SettingsRow {
                        rootObj: barModulesRoot.rootObj
                        settingId: "bar_bat_show_icon"
                        searchKeywords: "battery icon symbol indicator"
                        baseColor: Qt.alpha(ThemeBackend.surface1, 0.35)
                        icon: "󰁹"
                        title: I18n.t("guide.bar.bat.show_icon.title", "Show Icon")
                        description: I18n.t("guide.bar.bat.show_icon.desc", "Display the battery icon or graphic indicator")

                        Toggle {
                            Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                            checked: barModulesRoot.batShowIcon
                            accentColor: ThemeBackend.mauve
                            baseColor: ThemeBackend.surface1
                            handleColor: ThemeBackend.crust
                            handleOffColor: ThemeBackend.text
                            onToggled: function(c) {
                                barModulesRoot.setBatShowIcon(c);
                            }
                        }
                    }

                    SettingsRow {
                        id: batStyleRow
                        rootObj: barModulesRoot.rootObj
                        settingId: "bar_bat_style"
                        searchKeywords: "battery style look visual classic minimal ios android capsule"
                        baseColor: Qt.alpha(ThemeBackend.surface1, 0.35)
                        icon: "󰂄"
                        title: I18n.t("guide.bar.bat.style.title", "Battery Style")
                        description: I18n.t("guide.bar.bat.style.desc", "Choose the visual appearance of the battery indicator")

                        bottomContent: GridLayout {
                            id: batStylesGrid
                            Layout.fillWidth: true
                            columns: Math.max(1, Math.min(3, Math.floor(batteryCardLayout.width / rootObj.s(160))))
                            rowSpacing: rootObj.s(10)
                            columnSpacing: rootObj.s(10)

                            Repeater {
                                model: barModulesRoot.batStyles
                                delegate: Rectangle {
                                    id: batStyleCard
                                    required property var modelData
                                    required property int index

                                    readonly property bool isSelected: barModulesRoot.batStyle === modelData.id
                                    property real popScale: 1.0
                                    property real flashOpacity: 0.0

                                    Layout.fillWidth: true
                                    Layout.preferredWidth: 1
                                    implicitHeight: batStyleInnerCol.implicitHeight + rootObj.s(16)
                                    radius: ThemeBackend.borderRadius
                                    clip: true

                                    color: cardMouse.pressed
                                        ? Qt.darker(ThemeBackend.surface0, 1.15)
                                        : (isSelected
                                            ? (cardHover.hovered ? Qt.lighter(ThemeBackend.surface0, 1.30) : Qt.lighter(ThemeBackend.surface0, 1.24))
                                            : (cardHover.hovered ? Qt.lighter(ThemeBackend.surface0, 1.10) : ThemeBackend.surface0))

                                    border.width: 1
                                    border.color: isSelected
                                        ? Qt.alpha(ThemeBackend.surface2, 0.75)
                                        : (cardHover.hovered ? Qt.alpha(ThemeBackend.surface2, 0.5) : Qt.alpha(ThemeBackend.surface1, 0.4))

                                    Behavior on color { ColorAnimation { duration: 180 } }
                                    Behavior on border.color { ColorAnimation { duration: 180 } }

                                    scale: (cardMouse.pressed ? 0.985 : (cardHover.hovered ? 1.015 : 1.0)) * batStyleCard.popScale
                                    Behavior on scale { NumberAnimation { duration: 250; easing.type: Easing.OutQuint } }

                                    HoverHandler {
                                        id: cardHover
                                    }

                                    Rectangle {
                                        anchors.fill: parent
                                        radius: parent.radius
                                        color: "#ffffff"
                                        opacity: batStyleCard.flashOpacity
                                        PropertyAnimation on opacity { id: batFlashAnim; to: 0; duration: 350; easing.type: Easing.OutExpo }
                                    }

                                    SequentialAnimation {
                                        id: batPopAnim
                                        NumberAnimation { target: batStyleCard; property: "popScale"; to: 1.02; duration: 100; easing.type: Easing.OutQuad }
                                        NumberAnimation { target: batStyleCard; property: "popScale"; to: 1.0; duration: 350; easing.type: Easing.OutQuint }
                                    }

                                    MouseArea {
                                        id: cardMouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            batPopAnim.start();
                                            batStyleCard.flashOpacity = 0.15;
                                            batFlashAnim.start();
                                            if (typeof Sounds !== "undefined") {
                                                Sounds.playSfx("reusables/clickbutton/click.wav");
                                            }
                                            barModulesRoot.setBatStyle(modelData.id);
                                        }
                                    }

                                    ColumnLayout {
                                        id: batStyleInnerCol
                                        anchors.left: parent.left
                                        anchors.right: parent.right
                                        anchors.top: parent.top
                                        anchors.margins: rootObj.s(8)
                                        spacing: rootObj.s(8)

                                        Rectangle {
                                            id: batCardPreviewBox
                                            Layout.fillWidth: true
                                            implicitHeight: rootObj.s(barModulesRoot.isSideBar ? 140 : 72)
                                            radius: ThemeBackend.borderRadius
                                            color: Qt.darker(ThemeBackend.mantle, 1.1)
                                            clip: true

                                            Item {
                                                anchors.fill: parent
                                                enabled: false

                                                QtObject {
                                                    id: cardMockWidget
                                                    function s(v) { return rootObj ? rootObj.s(v) : v; }
                                                    property bool isCompact: false
                                                    property string batStyle: modelData.id
                                                    property bool batShowPercent: barModulesRoot.batShowPercent
                                                    property bool batShowIcon: barModulesRoot.batShowIcon
                                                    property bool isPreview: true
                                                    property var barWindow: ({
                                                        "startupCascadeFinished": true,
                                                        "isStartupReady": true,
                                                        "isDataReady": true,
                                                        "s": function(v) { return rootObj ? rootObj.s(v) : v; }
                                                    })
                                                    property bool moduleActive: barModulesRoot.visible
                                                }

                                                Loader {
                                                    id: batCardFaceLoader
                                                    anchors.centerIn: parent
                                                    width: item ? item.implicitWidth : 0
                                                    height: item ? item.implicitHeight : 0
                                                    scale: Math.min(1.0, Math.min((batCardPreviewBox.width - rootObj.s(16)) / Math.max(1, width), (batCardPreviewBox.height - rootObj.s(16)) / Math.max(1, height)))
                                                    asynchronous: false
                                                    source: barModulesRoot.isSideBar
                                                        ? Qt.resolvedUrl("../../bar/faces/bat/SideBatFace.qml")
                                                        : Qt.resolvedUrl("../../bar/faces/bat/BatFace.qml")

                                                    onLoaded: {
                                                        if (item) {
                                                            item.width = Qt.binding(function() { return item.implicitWidth; });
                                                            item.height = Qt.binding(function() { return item.implicitHeight; });
                                                            item.widget = cardMockWidget;
                                                        }
                                                    }
                                                }
                                            }

                                            Rectangle {
                                                anchors.fill: parent
                                                radius: parent.radius
                                                color: "transparent"
                                                border.width: 1
                                                border.color: Qt.alpha(ThemeBackend.surface2, 0.25)
                                            }
                                        }

                                        Text {
                                            Layout.fillWidth: true
                                            Layout.leftMargin: rootObj.s(2)
                                            Layout.rightMargin: rootObj.s(2)
                                            Layout.bottomMargin: rootObj.s(2)
                                            text: modelData.name
                                            font.family: ThemeBackend.fontFamily
                                            font.pixelSize: rootObj.s(13)
                                            font.weight: Font.Bold
                                            color: ThemeBackend.text
                                        }
                                    }
                                }
                            }

                            Item {
                                Layout.fillWidth: true
                                Layout.preferredWidth: 1
                                visible: batStylesGrid.columns === 3
                            }
                        }
                    }
                }
            }
        }
    }
}
