import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import "../"
import "../reusables"

Item {
    id: idleTabRoot
    required property var rootObj
    required property int tabIndex

    anchors.fill: parent
    visible: rootObj.currentTab === tabIndex
    opacity: visible ? 1.0 : 0.0
    property real slideY: visible ? 0 : rootObj.s(10)

    Behavior on slideY { NumberAnimation { duration: 250; easing.type: Easing.OutQuart } }
    transform: Translate { y: slideY }
    Behavior on opacity { NumberAnimation { duration: 250 } }

    property bool isNiri: false
    property var expandedActionMap: ({})

    function toggleActionExpanded(id) {
        let map = Object.assign({}, idleTabRoot.expandedActionMap);
        map[id] = !map[id];
        idleTabRoot.expandedActionMap = map;
    }

    property var defaultIdleSettings: ({
        "enabled": false,
        "manualInhibit": false,
        "actions": {
            "dim": {
                "id": "dim",
                "name": "Dim Screen",
                "timeout": 120,
                "enabled": true,
                "respectInhibitors": true,
                "mprisInhibit": false,
                "warningTimeout": 0,
                "warningCommand": "",
                "beforeCommand": "",
                "resumeCommand": "",
                "isCustom": false
            },
            "lock": {
                "id": "lock",
                "name": "Lock Session",
                "timeout": 300,
                "enabled": true,
                "respectInhibitors": true,
                "mprisInhibit": false,
                "warningTimeout": 10,
                "warningCommand": "",
                "beforeCommand": "",
                "resumeCommand": "",
                "isCustom": false
            },
            "dpms": {
                "id": "dpms",
                "name": "Display Off (DPMS)",
                "timeout": 360,
                "enabled": true,
                "respectInhibitors": true,
                "mprisInhibit": false,
                "warningTimeout": 0,
                "warningCommand": "",
                "beforeCommand": "",
                "resumeCommand": "",
                "isCustom": false
            },
            "suspend": {
                "id": "suspend",
                "name": "System Suspend",
                "timeout": 600,
                "enabled": true,
                "respectInhibitors": true,
                "mprisInhibit": false,
                "warningTimeout": 30,
                "warningCommand": "",
                "isCustom": false
            }
        },
        "customActions": []
    })

    property var idleSettings: {
        let s = (typeof Config !== "undefined" && Config.rawSettings) ? Config.rawSettings["idle"] : undefined;
        if (s !== undefined && s !== null) return s;
        if (typeof Config !== "undefined" && typeof Config.getSetting === "function") {
            return Config.getSetting("idle", idleTabRoot.defaultIdleSettings);
        }
        return idleTabRoot.defaultIdleSettings;
    }

    Connections {
        target: typeof Config !== "undefined" ? Config : null
        function onSettingsLoaded() {
            idleTabRoot.idleSettings = Qt.binding(function() {
                let s = (typeof Config !== "undefined" && Config.rawSettings) ? Config.rawSettings["idle"] : undefined;
                if (s !== undefined && s !== null) return s;
                if (typeof Config !== "undefined" && typeof Config.getSetting === "function") {
                    return Config.getSetting("idle", idleTabRoot.defaultIdleSettings);
                }
                return idleTabRoot.defaultIdleSettings;
            });
            idleTabRoot.refreshActionIds();
        }
    }

    property bool idleEnabled: idleSettings && idleSettings.enabled !== undefined ? idleSettings.enabled : false
    property bool manualInhibit: idleSettings && idleSettings.manualInhibit !== undefined ? idleSettings.manualInhibit : false

    property var actionIdsList: ["dim", "lock", "dpms", "suspend"]

    function refreshActionIds() {
        let list = ["dim", "lock", "dpms", "suspend"];
        let customs = (idleSettings && idleSettings.customActions && Array.isArray(idleSettings.customActions)) ? idleSettings.customActions : [];
        for (let i = 0; i < customs.length; i++) {
            if (customs[i] && customs[i].id) {
                list.push(customs[i].id);
            }
        }
        let current = idleTabRoot.actionIdsList;
        let same = (current && current.length === list.length);
        if (same) {
            for (let j = 0; j < list.length; j++) {
                if (current[j] !== list[j]) {
                    same = false;
                    break;
                }
            }
        }
        if (!same) {
            idleTabRoot.actionIdsList = list;
        }
    }

    onIdleSettingsChanged: refreshActionIds()

    function isCustomAction(actId) {
        return actId !== "dim" && actId !== "lock" && actId !== "dpms" && actId !== "suspend";
    }

    function getActionData(actId) {
        if (!actId) return null;
        if (actId === "dim" || actId === "lock" || actId === "dpms" || actId === "suspend") {
            let acts = (idleSettings && idleSettings.actions) ? idleSettings.actions : defaultIdleSettings.actions;
            let def = defaultIdleSettings.actions[actId] || {};
            let act = (acts && acts[actId]) ? acts[actId] : {};
            return Object.assign({}, def, act);
        }
        let customs = (idleSettings && idleSettings.customActions && Array.isArray(idleSettings.customActions)) ? idleSettings.customActions : [];
        for (let i = 0; i < customs.length; i++) {
            if (customs[i] && customs[i].id === actId) {
                return customs[i];
            }
        }
        return null;
    }

    function getActionTimeout(act) {
        if (!act || act.timeout === undefined || act.timeout === null || isNaN(act.timeout) || act.timeout <= 0) {
            if (act && act.id === "dim") return 120;
            if (act && act.id === "lock") return 300;
            if (act && act.id === "dpms") return 360;
            if (act && act.id === "suspend") return 600;
            return 300;
        }
        return Math.max(1, Math.round(Number(act.timeout)));
    }

    function isActionPipelineValid(actionObj) {
        if (!actionObj) return true;
        let id = (actionObj.id || "").toLowerCase();
        let builtInOrder = ["dim", "lock", "dpms", "suspend"];
        let idx = builtInOrder.indexOf(id);
        if (idx === -1) return true;

        let acts = (idleSettings && idleSettings.actions) ? idleSettings.actions : defaultIdleSettings.actions;
        let myTimeout = idleTabRoot.getActionTimeout(actionObj);

        for (let j = idx + 1; j < builtInOrder.length; j++) {
            let nextKey = builtInOrder[j];
            let nextAct = (acts && acts[nextKey]) ? Object.assign({}, defaultIdleSettings.actions[nextKey], acts[nextKey]) : defaultIdleSettings.actions[nextKey];
            let nextEnabled = nextAct && nextAct.enabled !== undefined ? nextAct.enabled : true;
            if (nextEnabled) {
                let nextTimeout = idleTabRoot.getActionTimeout(nextAct);
                if (myTimeout >= nextTimeout) return false;
            }
        }
        return true;
    }

    function getActionTitle(act, actId) {
        let id = actId || (act ? act.id : "");
        if (id === "dim") return I18n.t("guide.idle.dim.title", "Dim Screen");
        if (id === "lock") return I18n.t("guide.idle.lock.title", "Lock Session");
        if (id === "dpms") return I18n.t("guide.idle.dpms.title", "Display Off (DPMS)");
        if (id === "suspend") return I18n.t("guide.idle.suspend.title", "System Suspend");
        return (act && act.name) ? act.name : I18n.t("guide.idle.custom_action_fallback", "Custom Action");
    }

    function getDefaultResumeCommand(actId) {
        if (actId === "dpms") return idleTabRoot.isNiri ? "niri msg action power-on-monitors" : "hyprctl dispatch 'hl.dsp.dpms({ action = \"enable\" })' || hyprctl dispatch dpms on";
        return I18n.t("guide.idle.resume_command.placeholder", "Resume command");
    }

    function saveCustomAction(actionObj) {
        let sanitizeId = (actionObj.id || "").replace(/[^a-zA-Z0-9_\-]/g, "").trim();
        if (sanitizeId === "") sanitizeId = "action_" + Date.now();
        actionObj.id = sanitizeId;
        actionObj.isCustom = true;

        let current = JSON.parse(JSON.stringify(Config.getSetting("idle", defaultIdleSettings) || defaultIdleSettings));
        if (!current.customActions || !Array.isArray(current.customActions)) current.customActions = [];
        let customs = current.customActions;
        let idx = customs.findIndex(a => a && a.id === sanitizeId);
        if (idx !== -1) {
            customs[idx] = actionObj;
        } else {
            customs.push(actionObj);
        }
        current.customActions = customs;
        Config.setSetting("idle", current);
        idleTabRoot.refreshActionIds();
    }

    function deleteCustomAction(actionId) {
        let current = JSON.parse(JSON.stringify(Config.getSetting("idle", defaultIdleSettings) || defaultIdleSettings));
        if (!current.customActions || !Array.isArray(current.customActions)) return;
        current.customActions = current.customActions.filter(a => a && a.id !== actionId);
        Config.setSetting("idle", current);
        idleTabRoot.refreshActionIds();
    }

    function createNewAction() {
        let newId = "custom_" + Date.now();
        let newAction = {
            "id": newId,
            "name": I18n.t("guide.idle.custom_action_default", "New Action"),
            "desc": "",
            "timeout": 300,
            "enabled": true,
            "respectInhibitors": true,
            "mprisInhibit": false,
            "warningTimeout": 0,
            "warningCommand": "",
            "command": "",
            "beforeCommand": "",
            "resumeCommand": "",
            "isCustom": true
        };
        idleTabRoot.saveCustomAction(newAction);
    }

    function updateActionProp(actionId, isCustom, propKey, value) {
        if (propKey === "timeout" && (isNaN(value) || value <= 0)) return;
        let current = JSON.parse(JSON.stringify(Config.getSetting("idle", defaultIdleSettings) || defaultIdleSettings));

        if (isCustom) {
            let customs = (current.customActions && Array.isArray(current.customActions)) ? current.customActions : [];
            let found = customs.find(a => a && a.id === actionId);
            if (found) {
                found[propKey] = value;
                current.customActions = customs;
                Config.setSetting("idle", current);
            }
        } else {
            if (!current.actions) current.actions = JSON.parse(JSON.stringify(defaultIdleSettings.actions));
            if (!current.actions[actionId]) current.actions[actionId] = JSON.parse(JSON.stringify(defaultIdleSettings.actions[actionId] || {}));
            current.actions[actionId][propKey] = value;
            Config.setSetting("idle", current);
        }
    }

    function updateRootSetting(propKey, value) {
        let current = JSON.parse(JSON.stringify(Config.getSetting("idle", defaultIdleSettings) || defaultIdleSettings));
        current[propKey] = value;
        Config.setSetting("idle", current);
    }

    Component.onCompleted: {
        let de = (typeof SystemInfo !== "undefined" && SystemInfo.desktopEnv) ? SystemInfo.desktopEnv.toLowerCase() : "";
        idleTabRoot.isNiri = de.indexOf("niri") !== -1;
        idleTabRoot.refreshActionIds();
    }

    Component {
        id: actionCardDelegate
        Rectangle {
            id: actionCard
            required property var modelData
            required property int index

            Layout.fillWidth: true
            implicitHeight: cardMainCol.implicitHeight + rootObj.s(16)
            radius: ThemeBackend.borderRadius
            color: Qt.alpha(ThemeBackend.surface0, 0.4)
            border.color: isPipelineValid ? Qt.alpha(ThemeBackend.surface1, 0.4) : Qt.alpha(ThemeBackend.red, 0.6)
            border.width: 1

            property string actId: typeof modelData === "string" ? modelData : (modelData ? (modelData.id || "") : "")
            property bool isCustomAct: idleTabRoot.isCustomAction(actId)
            property var actData: idleTabRoot.getActionData(actId)

            property bool isExpanded: !!idleTabRoot.expandedActionMap[actId]
            property bool actEnabled: actData && actData.enabled !== undefined ? actData.enabled : true
            property int actTimeout: idleTabRoot.getActionTimeout(actData)
            property int actWarningTimeout: actData && actData.warningTimeout !== undefined && actData.warningTimeout !== null ? Math.max(0, Number(actData.warningTimeout)) : 0
            property bool actRespectInhibitors: actData && actData.respectInhibitors !== undefined ? actData.respectInhibitors : true
            property bool actMprisInhibit: actData && actData.mprisInhibit !== undefined ? actData.mprisInhibit : false
            property string actCmd: actData ? (actData.command || "") : ""
            property string actWarningCmd: actData ? (actData.warningCommand || "") : ""
            property string actBeforeCmd: actData ? (actData.beforeCommand || "") : ""
            property string actResumeCmd: actData ? (actData.resumeCommand || "") : ""
            property string actTitle: idleTabRoot.getActionTitle(actData, actId)
            property bool isPipelineValid: idleTabRoot.isActionPipelineValid(actData)

            readonly property string actIcon: {
                if (actId === "dim") return "󰃛";
                if (actId === "lock") return "󰌾";
                if (actId === "dpms") return "󰍹";
                if (actId === "suspend") return "󰒲";
                return "󰆍";
            }

            Timer {
                id: cardDebounceTimer
                interval: 200
                repeat: false
                property var callback: null
                onTriggered: {
                    if (callback) {
                        callback();
                        callback = null;
                    }
                }
            }

            function debounceAction(cb) {
                cardDebounceTimer.callback = cb;
                cardDebounceTimer.restart();
            }

            ColumnLayout {
                id: cardMainCol
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: rootObj.s(8)
                spacing: 0

                RowLayout {
                    id: cardInnerRow
                    Layout.fillWidth: true
                    spacing: rootObj.s(12)

                    IconButton {
                        enabled: false
                        size: rootObj.s(32)
                        Layout.preferredWidth: rootObj.s(32)
                        Layout.preferredHeight: rootObj.s(32)
                        Layout.alignment: Qt.AlignVCenter
                        cornerRadius: ThemeBackend.borderRadius
                        buttonIcon: actionCard.actIcon
                        iconFontSize: rootObj.s(16)
                        accentColor: ThemeBackend.surface0
                        textColor: "#ffffff"
                    }

                    RowLayout {
                        visible: !actionCard.isCustomAct
                        Layout.alignment: Qt.AlignVCenter
                        spacing: rootObj.s(6)

                        Text {
                            text: actionCard.actTitle
                            font.family: ThemeBackend.fontFamily
                            font.pixelSize: rootObj.s(13)
                            color: ThemeBackend.text
                            elide: Text.ElideRight
                        }

                        Rectangle {
                            visible: !actionCard.isPipelineValid && actionCard.actEnabled
                            implicitWidth: invalidBadgeText.implicitWidth + rootObj.s(8)
                            implicitHeight: rootObj.s(18)
                            radius: rootObj.s(4)
                            color: Qt.alpha(ThemeBackend.red, 0.15)
                            border.color: Qt.alpha(ThemeBackend.red, 0.4)
                            border.width: 1

                            Text {
                                id: invalidBadgeText
                                anchors.centerIn: parent
                                text: I18n.t("guide.idle.order_violation", "Order")
                                font.family: ThemeBackend.fontFamily
                                font.pixelSize: rootObj.s(10)
                                font.bold: true
                                color: ThemeBackend.red
                            }
                        }
                    }

                    Input {
                        visible: actionCard.isCustomAct
                        Layout.preferredWidth: rootObj.s(140)
                        Layout.alignment: Qt.AlignVCenter
                        implicitHeight: rootObj.s(32)
                        text: (actionCard.actData && actionCard.actData.name) ? actionCard.actData.name : ""
                        placeholderText: I18n.t("guide.idle.action_name_placeholder", "Action Name")
                        fontPixelSize: rootObj.s(12)
                        baseColor: ThemeBackend.surface0
                        accentColor: ThemeBackend.mauve
                        textColor: ThemeBackend.text
                        borderColor: Qt.alpha(ThemeBackend.surface2, 0.6)
                        cornerRadius: ThemeBackend.borderRadius
                        onAccepted: function(t) {
                            let val = (typeof t === "string") ? t : text;
                            idleTabRoot.updateActionProp(actionCard.actId, true, "name", val);
                        }
                    }

                    Input {
                        visible: actionCard.isCustomAct
                        Layout.fillWidth: true
                        Layout.alignment: Qt.AlignVCenter
                        implicitHeight: rootObj.s(32)
                        text: actionCard.actCmd
                        placeholderText: I18n.t("guide.idle.command_placeholder", "Command to run")
                        baseColor: ThemeBackend.surface0
                        accentColor: ThemeBackend.mauve
                        textColor: ThemeBackend.text
                        subTextColor: ThemeBackend.subtext0
                        borderColor: Qt.alpha(ThemeBackend.surface2, 0.6)
                        cornerRadius: ThemeBackend.borderRadius
                        fontPixelSize: rootObj.s(11)
                        onAccepted: function(t) {
                            let val = (typeof t === "string") ? t : text;
                            idleTabRoot.updateActionProp(actionCard.actId, true, "command", val);
                        }
                    }

                    Item {
                        Layout.fillWidth: true
                    }

                    RowLayout {
                        Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                        spacing: rootObj.s(8)

                        NumberSelector {
                            Layout.alignment: Qt.AlignVCenter
                            implicitWidth: rootObj.s(115)
                            implicitHeight: rootObj.s(32)
                            from: 10
                            to: 7200
                            stepSize: 10
                            decimals: 0
                            suffix: "s"
                            value: actionCard.actTimeout
                            baseColor: ThemeBackend.surface0
                            accentColor: ThemeBackend.mauve
                            buttonColor: ThemeBackend.surface1
                            buttonTextColor: ThemeBackend.text
                            textColor: ThemeBackend.text
                            borderColor: Qt.alpha(ThemeBackend.surface2, 0.6)
                            cornerRadius: ThemeBackend.borderRadius
                            fontFamily: ThemeBackend.fontFamily
                            fontPixelSize: rootObj.s(11)
                            onValueChanged: function(val) {
                                let num = (typeof val === "number" && !isNaN(val)) ? val : value;
                                let rounded = Math.round(num);
                                if (!isNaN(rounded) && rounded >= 10 && rounded <= 7200 && actionCard.actTimeout !== rounded) {
                                    let targetId = actionCard.actId;
                                    let isCustom = actionCard.isCustomAct;
                                    actionCard.debounceAction(function() {
                                        idleTabRoot.updateActionProp(targetId, isCustom, "timeout", rounded);
                                    });
                                }
                            }
                        }

                        IconButton {
                            Layout.alignment: Qt.AlignVCenter
                            implicitWidth: rootObj.s(28)
                            implicitHeight: rootObj.s(28)
                            cornerRadius: rootObj.s(8)
                            iconOffsetX: -1
                            buttonIcon: "󰒓"
                            iconFontSize: rootObj.s(14)
                            accentColor: actionCard.isExpanded ? Qt.alpha(ThemeBackend.mauve, 0.25) : ThemeBackend.surface0
                            textColor: actionCard.isExpanded ? ThemeBackend.mauve : (isHoveredOrHighlighted ? ThemeBackend.text : ThemeBackend.overlay2)
                            onClicked: {
                                idleTabRoot.toggleActionExpanded(actionCard.actId);
                            }
                        }

                        Toggle {
                            Layout.alignment: Qt.AlignVCenter
                            checked: actionCard.actEnabled
                            accentColor: ThemeBackend.mauve
                            baseColor: ThemeBackend.surface1
                            handleColor: ThemeBackend.crust
                            handleOffColor: ThemeBackend.text
                            onToggled: function(c) {
                                idleTabRoot.updateActionProp(actionCard.actId, actionCard.isCustomAct, "enabled", c);
                            }
                        }

                        DeleteButton {
                            visible: actionCard.isCustomAct
                            Layout.alignment: Qt.AlignVCenter
                            size: rootObj.s(28)
                            cornerRadius: rootObj.s(8)
                            iconFontSize: rootObj.s(14)
                            onClicked: {
                                idleTabRoot.deleteCustomAction(actionCard.actId);
                            }
                        }
                    }
                }

                Item {
                    id: expandableSettingsWrapper
                    Layout.fillWidth: true
                    property bool isOpen: actionCard.isExpanded
                    clip: true
                    visible: implicitHeight > 0
                    opacity: isOpen ? 1.0 : 0.0
                    implicitHeight: isOpen ? (expandedInnerCol.implicitHeight + rootObj.s(8)) : 0

                    Behavior on opacity { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
                    Behavior on implicitHeight { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }

                    ColumnLayout {
                        id: expandedInnerCol
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.topMargin: rootObj.s(8)
                        spacing: rootObj.s(6)

                        Rectangle {
                            Layout.fillWidth: true
                            implicitHeight: rowRespectInhibitorsLayout.implicitHeight + rootObj.s(20)
                            radius: ThemeBackend.borderRadius
                            color: Qt.alpha(ThemeBackend.surface1, 0.35)
                            border.width: 0

                            RowLayout {
                                id: rowRespectInhibitorsLayout
                                anchors.left: parent.left
                                anchors.leftMargin: rootObj.s(14)
                                anchors.right: parent.right
                                anchors.rightMargin: rootObj.s(14)
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: rootObj.s(12)

                                IconButton {
                                    enabled: false
                                    size: rootObj.s(28)
                                    Layout.preferredWidth: rootObj.s(28)
                                    Layout.preferredHeight: rootObj.s(28)
                                    Layout.alignment: Qt.AlignVCenter
                                    cornerRadius: ThemeBackend.borderRadius
                                    buttonIcon: "󰌿"
                                    iconFontSize: rootObj.s(14)
                                    accentColor: ThemeBackend.surface0
                                    textColor: "#ffffff"
                                }

                                ColumnLayout {
                                    Layout.alignment: Qt.AlignVCenter
                                    spacing: rootObj.s(2)

                                    Text {
                                        text: I18n.t("guide.idle.respect_inhibitors.title", "Respect App Inhibitors")
                                        font.family: ThemeBackend.fontFamily
                                        font.pixelSize: rootObj.s(12)
                                        color: ThemeBackend.text
                                    }

                                    Text {
                                        text: I18n.t("guide.idle.respect_inhibitors.desc", "Honor Wayland idle inhibitor locks from applications")
                                        font.family: ThemeBackend.fontFamily
                                        font.pixelSize: rootObj.s(10)
                                        color: ThemeBackend.subtext0
                                    }
                                }

                                Item {
                                    Layout.fillWidth: true
                                }

                                Toggle {
                                    Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                                    checked: actionCard.actRespectInhibitors
                                    accentColor: ThemeBackend.mauve
                                    baseColor: ThemeBackend.surface1
                                    handleColor: ThemeBackend.crust
                                    handleOffColor: ThemeBackend.text
                                    onToggled: function(c) {
                                        idleTabRoot.updateActionProp(actionCard.actId, actionCard.isCustomAct, "respectInhibitors", c);
                                    }
                                }
                            }
                        }

                        Rectangle {
                            Layout.fillWidth: true
                            implicitHeight: rowMprisInhibitLayout.implicitHeight + rootObj.s(20)
                            radius: ThemeBackend.borderRadius
                            color: Qt.alpha(ThemeBackend.surface1, 0.35)
                            border.width: 0

                            RowLayout {
                                id: rowMprisInhibitLayout
                                anchors.left: parent.left
                                anchors.leftMargin: rootObj.s(14)
                                anchors.right: parent.right
                                anchors.rightMargin: rootObj.s(14)
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: rootObj.s(12)

                                IconButton {
                                    enabled: false
                                    size: rootObj.s(28)
                                    Layout.preferredWidth: rootObj.s(28)
                                    Layout.preferredHeight: rootObj.s(28)
                                    Layout.alignment: Qt.AlignVCenter
                                    cornerRadius: ThemeBackend.borderRadius
                                    buttonIcon: "󰝚"
                                    iconFontSize: rootObj.s(14)
                                    accentColor: ThemeBackend.surface0
                                    textColor: "#ffffff"
                                }

                                ColumnLayout {
                                    Layout.alignment: Qt.AlignVCenter
                                    spacing: rootObj.s(2)

                                    Text {
                                        text: I18n.t("guide.idle.mpris_inhibit.title", "Inhibit on Media")
                                        font.family: ThemeBackend.fontFamily
                                        font.pixelSize: rootObj.s(12)
                                        color: ThemeBackend.text
                                    }

                                    Text {
                                        text: I18n.t("guide.idle.mpris_inhibit.desc", "Prevent idle trigger while MPRIS audio/video is playing")
                                        font.family: ThemeBackend.fontFamily
                                        font.pixelSize: rootObj.s(10)
                                        color: ThemeBackend.subtext0
                                    }
                                }

                                Item {
                                    Layout.fillWidth: true
                                }

                                Toggle {
                                    Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                                    checked: actionCard.actMprisInhibit
                                    accentColor: ThemeBackend.mauve
                                    baseColor: ThemeBackend.surface1
                                    handleColor: ThemeBackend.crust
                                    handleOffColor: ThemeBackend.text
                                    onToggled: function(c) {
                                        idleTabRoot.updateActionProp(actionCard.actId, actionCard.isCustomAct, "mprisInhibit", c);
                                    }
                                }
                            }
                        }

                        Rectangle {
                            Layout.fillWidth: true
                            implicitHeight: rowWarningCmdLayout.implicitHeight + rootObj.s(20)
                            radius: ThemeBackend.borderRadius
                            color: Qt.alpha(ThemeBackend.surface1, 0.35)
                            border.width: 0

                            RowLayout {
                                id: rowWarningCmdLayout
                                anchors.left: parent.left
                                anchors.leftMargin: rootObj.s(14)
                                anchors.right: parent.right
                                anchors.rightMargin: rootObj.s(14)
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: rootObj.s(12)

                                IconButton {
                                    enabled: false
                                    size: rootObj.s(28)
                                    Layout.preferredWidth: rootObj.s(28)
                                    Layout.preferredHeight: rootObj.s(28)
                                    Layout.alignment: Qt.AlignVCenter
                                    cornerRadius: ThemeBackend.borderRadius
                                    buttonIcon: "󰀪"
                                    iconFontSize: rootObj.s(14)
                                    accentColor: ThemeBackend.surface0
                                    textColor: "#ffffff"
                                }

                                ColumnLayout {
                                    Layout.alignment: Qt.AlignVCenter
                                    spacing: rootObj.s(2)

                                    Text {
                                        text: I18n.t("guide.idle.warning_command.title", "Warning Command")
                                        font.family: ThemeBackend.fontFamily
                                        font.pixelSize: rootObj.s(12)
                                        color: ThemeBackend.text
                                    }

                                    Text {
                                        text: I18n.t("guide.idle.warning_command.desc", "Offset and command to execute before action")
                                        font.family: ThemeBackend.fontFamily
                                        font.pixelSize: rootObj.s(10)
                                        color: ThemeBackend.subtext0
                                    }
                                }

                                Item {
                                    Layout.fillWidth: true
                                }

                                RowLayout {
                                    Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                                    spacing: rootObj.s(6)

                                    Input {
                                        Layout.alignment: Qt.AlignVCenter
                                        implicitWidth: rootObj.s(220)
                                        implicitHeight: rootObj.s(30)
                                        text: actionCard.actWarningCmd
                                        placeholderText: I18n.t("guide.idle.warning_command.placeholder", "Warning command")
                                        baseColor: ThemeBackend.mantle
                                        accentColor: ThemeBackend.mauve
                                        textColor: ThemeBackend.text
                                        subTextColor: ThemeBackend.subtext0
                                        borderColor: Qt.alpha(ThemeBackend.surface1, 0.8)
                                        cornerRadius: ThemeBackend.borderRadius
                                        fontPixelSize: rootObj.s(11)
                                        onAccepted: function(t) {
                                            let val = (typeof t === "string") ? t : text;
                                            idleTabRoot.updateActionProp(actionCard.actId, actionCard.isCustomAct, "warningCommand", val);
                                        }
                                    }

                                    NumberSelector {
                                        Layout.alignment: Qt.AlignVCenter
                                        implicitWidth: rootObj.s(90)
                                        implicitHeight: rootObj.s(30)
                                        from: 0
                                        to: Math.max(0, actionCard.actTimeout - 5)
                                        stepSize: 5
                                        decimals: 0
                                        suffix: "s"
                                        value: actionCard.actWarningTimeout
                                        baseColor: ThemeBackend.surface0
                                        accentColor: ThemeBackend.mauve
                                        buttonColor: ThemeBackend.surface1
                                        buttonTextColor: ThemeBackend.text
                                        textColor: ThemeBackend.text
                                        borderColor: Qt.alpha(ThemeBackend.surface2, 0.6)
                                        cornerRadius: ThemeBackend.borderRadius
                                        fontFamily: ThemeBackend.fontFamily
                                        fontPixelSize: rootObj.s(11)
                                        onValueChanged: function(val) {
                                            let num = (typeof val === "number" && !isNaN(val)) ? val : value;
                                            let rounded = Math.max(0, Math.round(num));
                                            if (!isNaN(rounded) && actionCard.actWarningTimeout !== rounded) {
                                                let targetId = actionCard.actId;
                                                let isCustom = actionCard.isCustomAct;
                                                actionCard.debounceAction(function() {
                                                    idleTabRoot.updateActionProp(targetId, isCustom, "warningTimeout", rounded);
                                                });
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        Rectangle {
                            visible: actionCard.actId !== "suspend"
                            Layout.fillWidth: true
                            implicitHeight: rowBeforeCmdLayout.implicitHeight + rootObj.s(20)
                            radius: ThemeBackend.borderRadius
                            color: Qt.alpha(ThemeBackend.surface1, 0.35)
                            border.width: 0

                            RowLayout {
                                id: rowBeforeCmdLayout
                                anchors.left: parent.left
                                anchors.leftMargin: rootObj.s(14)
                                anchors.right: parent.right
                                anchors.rightMargin: rootObj.s(14)
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: rootObj.s(12)

                                IconButton {
                                    enabled: false
                                    size: rootObj.s(28)
                                    Layout.preferredWidth: rootObj.s(28)
                                    Layout.preferredHeight: rootObj.s(28)
                                    Layout.alignment: Qt.AlignVCenter
                                    cornerRadius: ThemeBackend.borderRadius
                                    buttonIcon: "󰆍"
                                    iconFontSize: rootObj.s(14)
                                    accentColor: ThemeBackend.surface0
                                    textColor: "#ffffff"
                                }

                                ColumnLayout {
                                    Layout.alignment: Qt.AlignVCenter
                                    spacing: rootObj.s(2)

                                    Text {
                                        text: I18n.t("guide.idle.before_command.title", "Before Command")
                                        font.family: ThemeBackend.fontFamily
                                        font.pixelSize: rootObj.s(12)
                                        color: ThemeBackend.text
                                    }

                                    Text {
                                        text: I18n.t("guide.idle.before_command.desc", "Executed right before the action triggers")
                                        font.family: ThemeBackend.fontFamily
                                        font.pixelSize: rootObj.s(10)
                                        color: ThemeBackend.subtext0
                                    }
                                }

                                Item {
                                    Layout.fillWidth: true
                                }

                                Input {
                                    Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                                    implicitWidth: rootObj.s(280)
                                    implicitHeight: rootObj.s(30)
                                    text: actionCard.actBeforeCmd
                                    placeholderText: I18n.t("guide.idle.before_command.placeholder", "Before action command")
                                    baseColor: ThemeBackend.mantle
                                    accentColor: ThemeBackend.mauve
                                    textColor: ThemeBackend.text
                                    subTextColor: ThemeBackend.subtext0
                                    borderColor: Qt.alpha(ThemeBackend.surface1, 0.8)
                                    cornerRadius: ThemeBackend.borderRadius
                                    fontPixelSize: rootObj.s(11)
                                    onAccepted: function(t) {
                                        let val = (typeof t === "string") ? t : text;
                                        idleTabRoot.updateActionProp(actionCard.actId, actionCard.isCustomAct, "beforeCommand", val);
                                    }
                                }
                            }
                        }

                        Rectangle {
                            visible: actionCard.actId !== "suspend"
                            Layout.fillWidth: true
                            implicitHeight: rowResumeCmdLayout.implicitHeight + rootObj.s(20)
                            radius: ThemeBackend.borderRadius
                            color: Qt.alpha(ThemeBackend.surface1, 0.35)
                            border.width: 0

                            RowLayout {
                                id: rowResumeCmdLayout
                                anchors.left: parent.left
                                anchors.leftMargin: rootObj.s(14)
                                anchors.right: parent.right
                                anchors.rightMargin: rootObj.s(14)
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: rootObj.s(12)

                                IconButton {
                                    enabled: false
                                    size: rootObj.s(28)
                                    Layout.preferredWidth: rootObj.s(28)
                                    Layout.preferredHeight: rootObj.s(28)
                                    Layout.alignment: Qt.AlignVCenter
                                    cornerRadius: ThemeBackend.borderRadius
                                    buttonIcon: "󰑐"
                                    iconFontSize: rootObj.s(14)
                                    accentColor: ThemeBackend.surface0
                                    textColor: "#ffffff"
                                }

                                ColumnLayout {
                                    Layout.alignment: Qt.AlignVCenter
                                    spacing: rootObj.s(2)

                                    Text {
                                        text: I18n.t("guide.idle.resume_command.title", "Resume Command")
                                        font.family: ThemeBackend.fontFamily
                                        font.pixelSize: rootObj.s(12)
                                        color: ThemeBackend.text
                                    }

                                    Text {
                                        text: I18n.t("guide.idle.resume_command.desc", "Executed when user activity resumes")
                                        font.family: ThemeBackend.fontFamily
                                        font.pixelSize: rootObj.s(10)
                                        color: ThemeBackend.subtext0
                                    }
                                }

                                Item {
                                    Layout.fillWidth: true
                                }

                                Input {
                                    Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                                    implicitWidth: rootObj.s(280)
                                    implicitHeight: rootObj.s(30)
                                    text: actionCard.actResumeCmd
                                    placeholderText: idleTabRoot.getDefaultResumeCommand(actionCard.actId)
                                    baseColor: ThemeBackend.mantle
                                    accentColor: ThemeBackend.mauve
                                    textColor: ThemeBackend.text
                                    subTextColor: ThemeBackend.subtext0
                                    borderColor: Qt.alpha(ThemeBackend.surface1, 0.8)
                                    cornerRadius: ThemeBackend.borderRadius
                                    fontPixelSize: rootObj.s(11)
                                    onAccepted: function(t) {
                                        let val = (typeof t === "string") ? t : text;
                                        idleTabRoot.updateActionProp(actionCard.actId, actionCard.isCustomAct, "resumeCommand", val);
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    Flickable {
        anchors.fill: parent
        anchors.topMargin: rootObj.s(8)
        anchors.leftMargin: rootObj.s(8)
        anchors.rightMargin: rootObj.s(8)
        anchors.bottomMargin: rootObj.s(8)
        contentHeight: settingsCol.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        ColumnLayout {
            id: settingsCol
            width: parent.width
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
                    anchors.right: parent.right
                    anchors.leftMargin: rootObj.s(14)
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
                        buttonIcon: "󰒲"
                        iconFontSize: rootObj.s(16)
                        accentColor: ThemeBackend.surface0
                        textColor: "#ffffff"
                    }

                    ColumnLayout {
                        Layout.alignment: Qt.AlignVCenter
                        spacing: rootObj.s(2)
                        Text { text: I18n.t("guide.idle.enabled.title", "Enable Idle System"); font.family: ThemeBackend.fontFamily; font.pixelSize: rootObj.s(13); color: ThemeBackend.text }
                        Text { text: I18n.t("guide.idle.enabled.desc", "Activate power management and lock timeouts"); font.family: ThemeBackend.fontFamily; font.pixelSize: rootObj.s(11); color: ThemeBackend.subtext0 }
                    }

                    Item {
                        Layout.fillWidth: true
                    }

                    Toggle {
                        Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                        checked: idleTabRoot.idleEnabled
                        accentColor: ThemeBackend.mauve
                        baseColor: ThemeBackend.surface1
                        handleColor: ThemeBackend.crust
                        handleOffColor: ThemeBackend.text
                        onToggled: function(c) { idleTabRoot.updateRootSetting("enabled", c); }
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                implicitHeight: rowManualInhibitLayout.implicitHeight + rootObj.s(24)
                radius: ThemeBackend.borderRadius
                color: Qt.alpha(ThemeBackend.surface0, 0.4)
                border.width: 0
                visible: idleTabRoot.idleEnabled

                RowLayout {
                    id: rowManualInhibitLayout
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.leftMargin: rootObj.s(14)
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
                        buttonIcon: "󰅶"
                        iconFontSize: rootObj.s(16)
                        accentColor: ThemeBackend.surface0
                        textColor: "#ffffff"
                    }

                    ColumnLayout {
                        Layout.alignment: Qt.AlignVCenter
                        spacing: rootObj.s(2)
                        Text { text: I18n.t("guide.idle.manual_inhibit.title", "Do Not Disturb (Keep Awake)"); font.family: ThemeBackend.fontFamily; font.pixelSize: rootObj.s(13); color: ThemeBackend.text }
                        Text { text: I18n.t("guide.idle.manual_inhibit.desc", "Manually prevent the system from idling"); font.family: ThemeBackend.fontFamily; font.pixelSize: rootObj.s(11); color: ThemeBackend.subtext0 }
                    }

                    Item {
                        Layout.fillWidth: true
                    }

                    Toggle {
                        Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                        checked: idleTabRoot.manualInhibit
                        accentColor: ThemeBackend.mauve
                        baseColor: ThemeBackend.surface1
                        handleColor: ThemeBackend.crust
                        handleOffColor: ThemeBackend.text
                        onToggled: function(c) { idleTabRoot.updateRootSetting("manualInhibit", c); }
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                implicitHeight: actionsBoxCol.implicitHeight + rootObj.s(24)
                radius: ThemeBackend.borderRadius
                color: Qt.alpha(ThemeBackend.surface0, 0.4)
                border.width: 0
                visible: idleTabRoot.idleEnabled

                ColumnLayout {
                    id: actionsBoxCol
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.margins: rootObj.s(12)
                    spacing: rootObj.s(10)

                    RowLayout {
                        Layout.fillWidth: true
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
                            Layout.alignment: Qt.AlignVCenter
                            spacing: rootObj.s(2)

                            Text {
                                text: I18n.t("guide.idle.actions_header.title", "Idle Timeout Objects")
                                font.family: ThemeBackend.fontFamily
                                font.pixelSize: rootObj.s(14)
                                color: ThemeBackend.text
                            }

                            Text {
                                text: I18n.t("guide.idle.actions_header.desc", "Configure timeouts, built-in triggers, and custom commands")
                                font.family: ThemeBackend.fontFamily
                                font.pixelSize: rootObj.s(11)
                                color: ThemeBackend.subtext0
                            }
                        }

                        Item {
                            Layout.fillWidth: true
                        }

                        IconButton {
                            Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                            size: rootObj.s(32)
                            Layout.preferredWidth: rootObj.s(32)
                            Layout.preferredHeight: rootObj.s(32)
                            cornerRadius: rootObj.s(8)
                            buttonIcon: "󰐕"
                            iconFontSize: rootObj.s(14)
                            accentColor: ThemeBackend.surface0
                            textColor: isHoveredOrHighlighted ? ThemeBackend.text : ThemeBackend.overlay2
                            onClicked: {
                                idleTabRoot.createNewAction();
                            }
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: rootObj.s(8)

                        Repeater {
                            model: idleTabRoot.actionIdsList
                            delegate: actionCardDelegate
                        }
                    }

                    Text {
                        Layout.fillWidth: true
                        Layout.topMargin: rootObj.s(2)
                        wrapMode: Text.WordWrap
                        horizontalAlignment: Text.AlignHCenter
                        text: I18n.t("guide.idle.pipeline_notice", "Order: Dim Screen < Lock Session < Display Off < Suspend. Actions violating this order are excluded.")
                        font.family: ThemeBackend.fontFamily
                        font.pixelSize: rootObj.s(10)
                        color: Qt.alpha(ThemeBackend.subtext0, 0.6)
                    }
                }
            }
        }
    }
}
