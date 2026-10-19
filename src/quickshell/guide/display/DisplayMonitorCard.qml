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

    property bool monitorPowered: monSettings && monSettings.powerEnabled !== undefined ? monSettings.powerEnabled : (modelData && modelData.active !== undefined ? modelData.active : true)
    property bool filterEnabled: monSettings && monSettings.enabled !== undefined ? monSettings.enabled : false
    property bool filterAuto: monSettings && monSettings.auto !== undefined ? monSettings.auto : false
    property real currentTemp: monSettings && monSettings.temperature !== undefined ? monSettings.temperature : 50
    property real currentScale: modelData.scale !== undefined ? modelData.scale : 1.0

    readonly property color cardTint: monitorPowered ? Qt.alpha(ThemeBackend.surface0, 0.4) : Qt.darker(Qt.alpha(ThemeBackend.surface0, 0.4), 1.1)
    color: monDelegateGlass.active ? "transparent" : cardTint
    border.color: monitorPowered ? Qt.alpha(ThemeBackend.surface1, 0.4) : Qt.darker(Qt.alpha(ThemeBackend.surface1, 0.4), 1.1)
    border.width: ThemeBackend.liquidGlass ? 0 : 1

    GlassFill {
        id: monDelegateGlass
        anchors.fill: parent
        radius: parent.radius
        tintColor: monDelegate.cardTint
        tintAmount: 0.25
    }

    property real targetHeight: boxLayout.implicitHeight + rootObj.s(24)
    property bool appeared: false

    implicitHeight: appeared ? targetHeight : 0
    opacity: appeared ? 1.0 : 0.0

    Behavior on implicitHeight { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
    Behavior on opacity { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
    Behavior on color { ColorAnimation { duration: 250 } }
    Behavior on border.color { ColorAnimation { duration: 250 } }

    Component.onCompleted: {
        appeared = true;
    }

    property var resDims: modelData.dimensions ? modelData.dimensions.split("x") : ["1920", "1080"]
    property int monWidth: parseInt(resDims[0]) || 1920
    property int monHeight: parseInt(resDims[1]) || 1080
    property var validScales: monDelegate.tab.validScalesForResolution(monWidth, monHeight)
    readonly property int currentScaleIndex: {
        let i = validScales.indexOf(currentScale);
        if (i >= 0) return i;
        let nearest = monDelegate.tab.nearestValidScaleFromList(validScales, currentScale);
        let ni = validScales.indexOf(nearest);
        return ni >= 0 ? ni : 0;
    }

    onMonSettingsChanged: {
        if (!monSettings) return;
        if (monSettings.powerEnabled !== undefined) {
            monitorPowered = monSettings.powerEnabled;
        }
        filterEnabled = monSettings.enabled !== undefined ? monSettings.enabled : false;
        filterAuto = monSettings.auto !== undefined ? monSettings.auto : false;
        if (monDelegate.tab.pendingMonName !== monName && !temperatureSlider.pressed) {
            currentTemp = monSettings.temperature !== undefined ? monSettings.temperature : 50;
        }
    }

    onModelDataChanged: {
        if (monSettings.powerEnabled === undefined && modelData.active !== undefined) {
            monitorPowered = modelData.active;
        }
        if (monDelegate.tab.pendingMonScaleName !== monName) {
            currentScale = modelData.scale !== undefined ? modelData.scale : 1.0;
        }
    }

    ColumnLayout {
        id: boxLayout
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
                text: modelData.name
                font.family: ThemeBackend.fontFamily
                font.pixelSize: rootObj.s(16)
                font.bold: true
                color: ThemeBackend.text
            }

            Item { Layout.fillWidth: true }

            Text {
                text: modelData.dimensions + " • " + modelData.framerate + "Hz"
                font.family: ThemeBackend.fontFamily
                font.pixelSize: rootObj.s(12)
                color: ThemeBackend.subtext0
            }
        }

        SettingsRow {
            visible: monDelegate.tab.monitorsList.length > 1
            rootObj: monDelegate.rootObj
            baseColor: Qt.alpha(ThemeBackend.surface1, 0.35)
            icon: "󰐥"
            title: I18n.t("guide.display.enable.title", "Enable Monitor")
            description: I18n.t("guide.display.enable.desc", "Turn display output on or off")

            Toggle {
                id: powerToggle
                checked: monDelegate.monitorPowered
                accentColor: ThemeBackend.mauve
                baseColor: ThemeBackend.surface1
                handleColor: ThemeBackend.crust
                handleOffColor: ThemeBackend.text
                onToggled: function(c) {
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

        SettingsGroup {
            rootObj: monDelegate.rootObj
            icon: "󰖔"
            title: I18n.t("guide.display.bluelight.title")
            description: I18n.t("guide.display.bluelight.desc")
            expanded: monDelegate.filterEnabled

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
                    BlueLight.setEnabled(monDelegate.monName, c);
                    monDelegate.tab.refreshDisplaySettings();
                }

                Binding {
                    target: filterToggle
                    property: "checked"
                    value: monDelegate.filterEnabled
                }
            }

            subSettings: [
                SettingsRow {
                    rootObj: monDelegate.rootObj
                    baseColor: Qt.alpha(ThemeBackend.surface1, 0.35)
                    icon: "󰥔"
                    title: I18n.t("guide.display.schedule.title")
                    description: I18n.t("guide.display.schedule.desc") + " " + monDelegate.tab.scheduleDescription

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
                            BlueLight.setAuto(monDelegate.monName, c);
                            monDelegate.tab.refreshDisplaySettings();
                        }

                        Binding {
                            target: autoToggle
                            property: "checked"
                            value: monDelegate.filterAuto
                        }
                    }
                },

                Item {
                    id: tempSectionWrapper
                    Layout.fillWidth: true
                    property bool isOpen: !monDelegate.filterAuto
                    clip: true
                    visible: implicitHeight > 0
                    opacity: isOpen ? 1.0 : 0.0
                    implicitHeight: isOpen ? tempInnerBox.implicitHeight : 0

                    Behavior on opacity { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
                    Behavior on implicitHeight { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }

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
                            implicitWidth: rootObj.s(220)
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
            ]
        }

        SettingsRow {
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
                implicitWidth: rootObj.s(220)
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
