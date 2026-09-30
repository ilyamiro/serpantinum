import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import "../../"
import "../../reusables"

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

    readonly property var workspaceStyles: [
        {
            "id": "pills",
            "name": I18n.t("guide.bar.modules.workspaces.style.name.pills", "Pills"),
            "desc": I18n.t("guide.bar.modules.workspaces.style.pills", "Minimal pill indicators"),
            "icon": "󰮯",
            "faceFile": isSideBar ? "workspaces/faces/SidePillsFace.qml" : "workspaces/faces/PillsFace.qml"
        },
        {
            "id": "numbers",
            "name": I18n.t("guide.bar.modules.workspaces.style.name.numbers", "Numbers"),
            "desc": I18n.t("guide.bar.modules.workspaces.style.numbers", "Numbered indices"),
            "icon": "󰎦",
            "faceFile": isSideBar ? "workspaces/faces/SideNumbersFace.qml" : "workspaces/faces/NumbersFace.qml"
        },
        {
            "id": "pacman",
            "name": I18n.t("guide.bar.modules.workspaces.style.name.pacman", "Pacman"),
            "desc": I18n.t("guide.bar.modules.workspaces.style.pacman", "Animated arcade dots"),
            "icon": "󰮯",
            "faceFile": isSideBar ? "workspaces/faces/SidePacmanFace.qml" : "workspaces/faces/PacmanFace.qml"
        }
    ]

    readonly property var timeStyles: [
        {
            "id": "classic",
            "name": I18n.t("guide.bar.modules.timedate.style.name.classic", "Classic"),
            "desc": I18n.t("guide.bar.modules.timedate.style.classic", "Clean stacked time and date"),
            "icon": "󰥔",
            "faceFile": isSideBar ? "timedate/faces/SideClassicFace.qml" : "timedate/faces/ClassicFace.qml"
        },
        {
            "id": "material",
            "name": I18n.t("guide.bar.modules.timedate.style.name.material", "Material"),
            "desc": I18n.t("guide.bar.modules.timedate.style.material", "Diagonal bold accent numbers"),
            "icon": "󰸗",
            "faceFile": isSideBar ? "timedate/faces/SideMaterialFace.qml" : "timedate/faces/MaterialFace.qml"
        },
        {
            "id": "badge",
            "name": I18n.t("guide.bar.modules.timedate.style.name.badge", "Badge"),
            "desc": I18n.t("guide.bar.modules.timedate.style.badge", "Pill-capsule segmented cards"),
            "icon": "󰃰",
            "faceFile": isSideBar ? "timedate/faces/SideBadgeFace.qml" : "timedate/faces/BadgeFace.qml"
        }
    ]

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
        property bool moduleActive: true
    }

    function getFaceUrl(file) {
        if (!file) return "";
        let base = isSideBar ? "../../bar/sidemodules/" : "../../bar/modules/";
        let path = file.indexOf("/") !== -1 ? file : ("workspaces/faces/" + file);
        return Qt.resolvedUrl(base + path);
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

                    GridLayout {
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
                                                source: barModulesRoot.getFaceUrl(modelData.faceFile)

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

                    GridLayout {
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
                                                source: barModulesRoot.getFaceUrl(modelData.faceFile)

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
                                                    text: I18n.t("weather.months.sep")
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
    }
}
