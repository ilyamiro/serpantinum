import QtQuick
import QtQuick.Layouts
import "../../"
import "../../reusables"
import "../../reusables/guide"

Rectangle {
    id: monDelegate
    required property var tab
    required property var modelData
    required property int index
    readonly property var rootObj: tab.rootObj

    Layout.fillWidth: true
    clip: true
    radius: ThemeBackend.borderRadius

    property string monName: modelData.name
    property var monSettings: (monDelegate.tab && monDelegate.tab.displaySettings && monDelegate.tab.displaySettings.monitors && monDelegate.tab.displaySettings.monitors[monName]) ? monDelegate.tab.displaySettings.monitors[monName] : ({})

    property bool monitorPowered: monDelegate.tab.txnSupported
        ? (modelData && modelData.active !== undefined ? modelData.active : true)
        : (monSettings && monSettings.powerEnabled !== undefined ? monSettings.powerEnabled : (modelData && modelData.active !== undefined ? modelData.active : true))
    property bool filterEnabled: monSettings && monSettings.enabled !== undefined ? monSettings.enabled : false
    property bool filterAuto: monSettings && monSettings.auto !== undefined ? monSettings.auto : false
    property real currentTemp: monSettings && monSettings.temperature !== undefined ? monSettings.temperature : 50
    property real currentScale: modelData.scale !== undefined ? modelData.scale : 1.0

    readonly property color cardTint: monitorPowered ? Qt.alpha(ThemeBackend.surface0, 0.4) : Qt.darker(Qt.alpha(ThemeBackend.surface0, 0.4), 1.1)
    color: monDelegateGlass.active ? "transparent" : cardTint

    GlassFill {
        id: monDelegateGlass
        anchors.fill: parent
        radius: parent.radius
        tintColor: monDelegate.cardTint
        tintAmount: 0.25
    }

    property real targetHeight: boxLayout.implicitHeight + rootObj.s(24)
    property bool appeared: false

    property real appearProgress: appeared ? 1 : 0
    implicitHeight: targetHeight * appearProgress
    opacity: appeared ? 1.0 : 0.0

    Behavior on appearProgress { NumberAnimation { duration: 250; easing.type: Easing.OutCubic } }
    Behavior on opacity { NumberAnimation { duration: 250; easing.type: Easing.OutCubic } }
    Behavior on color { ColorAnimation { duration: 250 } }

    Component.onCompleted: {
        appeared = true;
    }

    property var resDims: modelData.dimensions ? modelData.dimensions.split("x") : ["1920", "1080"]
    property int monWidth: parseInt(resDims[0]) || 1920
    property int monHeight: parseInt(resDims[1]) || 1080
    property var validScales: (modelData.validScales && modelData.validScales.length > 0)
        ? modelData.validScales
        : monDelegate.tab.validScalesForResolution(monWidth, monHeight)

    // ---- mode helpers (Hyprland transactions) ----
    readonly property bool canEditMode: monDelegate.tab.txnSupported && monDelegate.tab.txnAvailable && monitorPowered
                                        && !monDelegate.tab.txnPending && !monDelegate.tab.txnBusy
    readonly property var resolutionList: {
        let seen = {};
        let out = [];
        let modes = modelData.modes || [];
        for (let i = 0; i < modes.length; i++) {
            let key = modes[i][0] + "x" + modes[i][1];
            if (!seen[key]) { seen[key] = true; out.push({ "w": modes[i][0], "h": modes[i][1], "label": key }); }
        }
        out.sort((a, b) => (b.w * b.h) - (a.w * a.h));
        return out;
    }
    readonly property int resolutionIndex: {
        for (let i = 0; i < resolutionList.length; i++)
            if (resolutionList[i].w === modelData.width && resolutionList[i].h === modelData.height) return i;
        return 0;
    }
    readonly property var refreshList: {
        let out = [];
        let modes = modelData.modes || [];
        let sel = resolutionList[resolutionIndex];
        for (let i = 0; i < modes.length; i++)
            if (sel && modes[i][0] === sel.w && modes[i][1] === sel.h) out.push(modes[i][2]);
        out.sort((a, b) => b - a);
        return out;
    }
    readonly property int refreshIndex: {
        for (let i = 0; i < refreshList.length; i++)
            if (Math.abs(refreshList[i] - modelData.refresh) < 0.05) return i;
        return 0;
    }
    readonly property int currentScaleIndex: {
        let i = validScales.indexOf(currentScale);
        if (i >= 0) return i;
        let nearest = monDelegate.tab.nearestValidScaleFromList(validScales, currentScale);
        let ni = validScales.indexOf(nearest);
        return ni >= 0 ? ni : 0;
    }

    onMonSettingsChanged: {
        if (!monSettings) return;
        if (monSettings.powerEnabled !== undefined && !monDelegate.tab.txnSupported) {
            monitorPowered = monSettings.powerEnabled;
        }
        filterEnabled = monSettings.enabled !== undefined ? monSettings.enabled : false;
        filterAuto = monSettings.auto !== undefined ? monSettings.auto : false;
        if (monDelegate.tab.pendingMonName !== monName && !temperatureSlider.pressed) {
            currentTemp = monSettings.temperature !== undefined ? monSettings.temperature : 50;
        }
    }

    onModelDataChanged: {
        if ((monSettings.powerEnabled === undefined || monDelegate.tab.txnSupported) && modelData.active !== undefined) {
            monitorPowered = modelData.active;
        }
        if (monDelegate.tab.pendingMonScaleName !== monName) {
            currentScale = modelData.scale !== undefined ? modelData.scale : 1.0;
        }
    }

    // Two-column layout (see the design mockup): pairs of settings share a row,
    // thin separators group them, and the colour temperature / UI scale rows span both columns.
    GridLayout {
        id: boxLayout
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: rootObj.s(12)
        columns: 2
        uniformCellWidths: true
        columnSpacing: rootObj.s(10)
        rowSpacing: rootObj.s(6)

        Text {
            Layout.columnSpan: 2
            Layout.bottomMargin: rootObj.s(4)
            Layout.leftMargin: rootObj.s(4)
            text: modelData.name
            font.family: ThemeBackend.fontFamily
            font.pixelSize: rootObj.s(16)
            font.bold: true
            color: ThemeBackend.text
        }

        // ---- row 1: power | vertical alignment ----
        SettingsRow {
            Layout.fillWidth: true
            visible: monDelegate.tab.monitorsList.length > 1
            rootObj: monDelegate.rootObj
            baseColor: Qt.alpha(ThemeBackend.surface1, 0.35)
            icon: "󰐥"
            title: I18n.t("guide.display.enable.title", "Enable Monitor")
            description: I18n.t("guide.display.enable.desc", "Turn display output on or off")

            Toggle {
                id: powerToggle
                enabled: !(monDelegate.tab.txnSupported && monDelegate.monitorPowered && monDelegate.tab.txnEnabledCount <= 1)
                opacity: enabled ? 1.0 : 0.5
                checked: monDelegate.monitorPowered
                accentColor: ThemeBackend.mauve
                baseColor: ThemeBackend.surface1
                handleColor: ThemeBackend.crust
                handleOffColor: ThemeBackend.text
                onToggled: function(c) {
                    if (monDelegate.tab.txnSupported) {
                        if (!monDelegate.tab.txnChange(monDelegate.monName, { "enabled": c }))
                            powerToggle.checked = monDelegate.monitorPowered;
                        return;
                    }
                    monDelegate.monitorPowered = c;
                    monDelegate.tab.updateMonitorSetting(monDelegate.monName, "powerEnabled", c);
                    monDelegate.tab.applyMonitorPower(monDelegate.monName, c);
                }

                Binding {
                    target: powerToggle
                    property: "checked"
                    value: monDelegate.monitorPowered
                }
            }
        }

        SettingsRow {
            Layout.fillWidth: true
            visible: monDelegate.tab.txnSupported && monDelegate.tab.txnAvailable
            rootObj: monDelegate.rootObj
            baseColor: Qt.alpha(ThemeBackend.surface1, 0.35)
            icon: "󰑵"
            title: I18n.t("guide.display.orientation.title")
            description: I18n.t("guide.display.orientation.desc")

            Toggle {
                id: verticalToggle
                readonly property bool isVertical: ((modelData.transform || 0) % 2) === 1
                enabled: monDelegate.canEditMode
                opacity: enabled ? 1.0 : 0.5
                checked: isVertical
                accentColor: ThemeBackend.mauve
                baseColor: ThemeBackend.surface1
                handleColor: ThemeBackend.crust
                handleOffColor: ThemeBackend.text
                onToggled: function(c) {
                    if (!monDelegate.tab.txnChange(monDelegate.monName, { "transform": c ? 1 : 0 }))
                        verticalToggle.checked = verticalToggle.isVertical;
                }

                Binding {
                    target: verticalToggle
                    property: "checked"
                    value: verticalToggle.isVertical
                }
            }
        }

        Rectangle {
            Layout.columnSpan: 2
            Layout.fillWidth: true
            Layout.preferredHeight: 1
            Layout.topMargin: rootObj.s(2)
            Layout.bottomMargin: rootObj.s(2)
            visible: monDelegate.tab.txnSupported && monDelegate.tab.txnAvailable
            color: Qt.alpha(ThemeBackend.surface2, 0.5)
        }

        // ---- row 2: resolution | refresh rate ----
        SettingsRow {
            Layout.fillWidth: true
            visible: monDelegate.tab.txnSupported && monDelegate.tab.txnAvailable
            rootObj: monDelegate.rootObj
            baseColor: Qt.alpha(ThemeBackend.surface1, 0.35)
            icon: "󰍹"
            title: I18n.t("guide.display.resolution.title")
            description: I18n.t("guide.display.resolution.desc")

            Dropdown {
                id: resolutionDropdown
                Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                implicitWidth: rootObj.s(150)
                implicitHeight: rootObj.s(32)
                enabled: monDelegate.canEditMode
                fuzzySearch: false
                options: monDelegate.resolutionList.map(r => r.label)
                currentIndex: monDelegate.resolutionIndex
                accentColor: ThemeBackend.mauve
                baseColor: ThemeBackend.surface0
                hoverColor: ThemeBackend.surface1
                dropdownColor: ThemeBackend.surface0
                onSelected: function(index, value) {
                    let r = monDelegate.resolutionList[index];
                    if (!r || (r.w === modelData.width && r.h === modelData.height)) return;
                    // Keep the closest refresh rate that the new resolution offers.
                    let rates = [];
                    for (let i = 0; i < modelData.modes.length; i++)
                        if (modelData.modes[i][0] === r.w && modelData.modes[i][1] === r.h) rates.push(modelData.modes[i][2]);
                    let best = rates[0];
                    for (let j = 0; j < rates.length; j++)
                        if (Math.abs(rates[j] - modelData.refresh) < Math.abs(best - modelData.refresh)) best = rates[j];
                    // A scale that is not valid at the new resolution falls back to the nearest valid one.
                    let valid = monDelegate.tab.txnValidScales(r.w, r.h);
                    let nearest = monDelegate.tab.nearestValidScaleFromList(valid, modelData.scale);
                    if (!monDelegate.tab.txnChange(monDelegate.monName, { "width": r.w, "height": r.h, "refresh": best, "scale": nearest }))
                        resolutionDropdown.currentIndex = monDelegate.resolutionIndex;
                }
            }
        }

        SettingsRow {
            Layout.fillWidth: true
            visible: monDelegate.tab.txnSupported && monDelegate.tab.txnAvailable
            rootObj: monDelegate.rootObj
            baseColor: Qt.alpha(ThemeBackend.surface1, 0.35)
            icon: "󰑐"
            title: I18n.t("guide.display.refresh.title")
            description: I18n.t("guide.display.refresh.desc")

            Dropdown {
                id: refreshDropdown
                Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                implicitWidth: rootObj.s(120)
                implicitHeight: rootObj.s(32)
                enabled: monDelegate.canEditMode && monDelegate.refreshList.length > 1
                fuzzySearch: false
                options: monDelegate.refreshList.map(r => r.toFixed(2) + " Hz")
                currentIndex: monDelegate.refreshIndex
                accentColor: ThemeBackend.mauve
                baseColor: ThemeBackend.surface0
                hoverColor: ThemeBackend.surface1
                dropdownColor: ThemeBackend.surface0
                onSelected: function(index, value) {
                    let hz = monDelegate.refreshList[index];
                    if (hz === undefined || Math.abs(hz - modelData.refresh) < 0.05) return;
                    if (!monDelegate.tab.txnChange(monDelegate.monName, { "refresh": hz }))
                        refreshDropdown.currentIndex = monDelegate.refreshIndex;
                }
            }
        }

        Rectangle {
            Layout.columnSpan: 2
            Layout.fillWidth: true
            Layout.preferredHeight: 1
            Layout.topMargin: rootObj.s(2)
            Layout.bottomMargin: rootObj.s(2)
            visible: monDelegate.tab.txnSupported && monDelegate.tab.txnAvailable
            color: Qt.alpha(ThemeBackend.surface2, 0.5)
        }

        // ---- row 3: blue light filter | automatic schedule ----
        SettingsRow {
            Layout.fillWidth: true
            rootObj: monDelegate.rootObj
            baseColor: Qt.alpha(ThemeBackend.surface1, 0.35)
            icon: "󰖔"
            title: I18n.t("guide.display.gamma.title")
            description: I18n.t("guide.display.gamma.desc")

            Toggle {
                id: filterToggle
                Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                checked: monDelegate.filterEnabled
                accentColor: ThemeBackend.mauve
                baseColor: ThemeBackend.surface1
                handleColor: ThemeBackend.crust
                handleOffColor: ThemeBackend.text
                onToggled: function(c) {
                    monDelegate.filterEnabled = c;
                    Gamma.setEnabled(monDelegate.monName, c);
                    monDelegate.tab.refreshDisplaySettings();
                }

                Binding {
                    target: filterToggle
                    property: "checked"
                    value: monDelegate.filterEnabled
                }
            }
        }

        // The cell always keeps its height so the grid never reflows; only the content fades in.
        Item {
            Layout.fillWidth: true
            implicitHeight: autoRow.implicitHeight

            SettingsRow {
                id: autoRow
                anchors.left: parent.left
                anchors.right: parent.right
                rootObj: monDelegate.rootObj
                baseColor: Qt.alpha(ThemeBackend.surface1, 0.35)
                icon: "󰥔"
                title: I18n.t("guide.display.schedule.title")
                description: I18n.t("guide.display.schedule.desc") + " " + monDelegate.tab.scheduleDescription
                enabled: monDelegate.filterEnabled
                opacity: monDelegate.filterEnabled ? 1.0 : 0.0
                visible: opacity > 0.01

                Behavior on opacity { NumberAnimation { duration: 250; easing.type: Easing.OutCubic } }

                Toggle {
                    id: autoToggle
                    Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                    checked: monDelegate.filterAuto
                    accentColor: ThemeBackend.mauve
                    baseColor: ThemeBackend.surface1
                    handleColor: ThemeBackend.crust
                    handleOffColor: ThemeBackend.text
                    onToggled: function(c) {
                        monDelegate.filterAuto = c;
                        Gamma.setAuto(monDelegate.monName, c);
                        monDelegate.tab.refreshDisplaySettings();
                    }

                    Binding {
                        target: autoToggle
                        property: "checked"
                        value: monDelegate.filterAuto
                    }
                }
            }
        }

        // ---- colour temperature: full width, slides open with the filter ----
        Item {
            id: tempSectionWrapper
            Layout.columnSpan: 2
            Layout.fillWidth: true
            property bool isOpen: monDelegate.filterEnabled && !monDelegate.filterAuto
            clip: true
            visible: implicitHeight > 0
            opacity: isOpen ? 1.0 : 0.0
            property real openProgress: isOpen ? 1 : 0
            implicitHeight: tempInnerBox.implicitHeight * openProgress

            Behavior on opacity { NumberAnimation { duration: 250; easing.type: Easing.OutCubic } }
            Behavior on openProgress { NumberAnimation { duration: 250; easing.type: Easing.OutCubic } }

            SettingsRow {
                id: tempInnerBox
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                rootObj: monDelegate.rootObj
                baseColor: Qt.alpha(ThemeBackend.surface1, 0.35)
                icon: "󰔏"
                title: I18n.t("guide.display.temperature.title")
                description: I18n.t("guide.display.temperature.desc")

                Draggable {
                    id: temperatureSlider
                    Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                    Layout.rightMargin: rootObj.s(8)
                    implicitWidth: rootObj.s(420)
                    implicitHeight: rootObj.s(18)
                    from: 0
                    to: 100
                    stepSize: 1
                    defaultValue: 50
                    showValueBubble: true
                    valueFormatter: function(v) { return Math.round(v).toString() }
                    value: monDelegate.currentTemp
                    backgroundColor: ThemeBackend.surface0
                    accentColor: ThemeBackend.mauve
                    handleColor: ThemeBackend.text
                    handleBorderColor: ThemeBackend.mantle
                    onMoved: function(val) {
                        let rounded = Math.round(val);
                        if (monDelegate.currentTemp !== rounded) {
                            monDelegate.currentTemp = rounded;
                            monDelegate.tab.updateMonitorSettingDebounced(monDelegate.monName, rounded);
                        }
                    }
                    onDragFinished: {
                        monDelegate.tab.flushMonitorSetting(monDelegate.monName);
                    }
                }
            }
        }

        Rectangle {
            Layout.columnSpan: 2
            Layout.fillWidth: true
            Layout.preferredHeight: 1
            Layout.topMargin: rootObj.s(2)
            Layout.bottomMargin: rootObj.s(2)
            visible: monDelegate.tab.compositor !== "mango"
            color: Qt.alpha(ThemeBackend.surface2, 0.5)
        }

        // ---- UI scale: full width ----
        SettingsRow {
            Layout.columnSpan: 2
            Layout.fillWidth: true
            visible: monDelegate.tab.compositor !== "mango"
            rootObj: monDelegate.rootObj
            baseColor: Qt.alpha(ThemeBackend.surface1, 0.35)
            icon: "󰍍"
            title: I18n.t("guide.display.uiscale.title")
            description: I18n.t("guide.display.uiscale.desc")
            controlSpacing: rootObj.s(4)

            LoaderIcon {
                id: scaleLoader
                Layout.preferredWidth: rootObj.s(32)
                Layout.preferredHeight: rootObj.s(32)
                Layout.alignment: Qt.AlignVCenter
                running: monDelegate.tab.scaleDebounceTimer.running && monDelegate.tab.pendingMonScaleName === monDelegate.monName
                accentColor: ThemeBackend.mauve
            }

            Draggable {
                id: uiScaleSlider
                implicitWidth: rootObj.s(420)
                implicitHeight: rootObj.s(18)
                from: 0
                to: Math.max(0, monDelegate.validScales.length - 1)
                stepSize: 1
                defaultValue: monDelegate.validScales.indexOf(1.0) >= 0 ? monDelegate.validScales.indexOf(1.0) : 0
                showValueBubble: true
                showTooltip: true
                alwaysShowHandle: false
                valueFormatter: function(idx) {
                    let i = Math.round(idx);
                    let s = monDelegate.validScales[i] !== undefined ? monDelegate.validScales[i] : 1.0;
                    return s.toFixed(3).replace(/0+$/,'').replace(/\.$/,'.0');
                }
                value: monDelegate.currentScaleIndex
                backgroundColor: ThemeBackend.surface0
                accentColor: ThemeBackend.mauve
                handleColor: ThemeBackend.text
                handleBorderColor: ThemeBackend.mantle
                onMoved: function(idx) {
                    let i = Math.round(idx);
                    let s = monDelegate.validScales[i] !== undefined ? monDelegate.validScales[i] : 1.0;
                    if (monDelegate.currentScale !== s) {
                        monDelegate.currentScale = s;
                        monDelegate.tab.pendingMonScaleName = monDelegate.monName;
                        monDelegate.tab.pendingMonScaleVal = s;
                        monDelegate.tab.scaleDebounceTimer.restart();
                    }
                }
                onDragFinished: {
                    monDelegate.tab.scaleDebounceTimer.stop();
                    if (monDelegate.tab.pendingMonScaleName !== "") {
                        monDelegate.tab.applyMonitorScale(monDelegate.tab.pendingMonScaleName, monDelegate.tab.pendingMonScaleVal);
                        monDelegate.tab.updateMonitorSetting(monDelegate.tab.pendingMonScaleName, "scale", monDelegate.tab.pendingMonScaleVal);
                        monDelegate.tab.pendingMonScaleName = "";
                    }
                }
            }
        }
    }
}
