import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import "../"
import "../reusables"
import "../reusables/guide"
import "../reusables/buttons"
import "../reusables/inputs"
import "../reusables/behavior"

GuideTab {
    id: touchpadTabRoot

    property var defaultTouchpadSettings: ({
        "sensitivity": 0.0,
        "naturalScroll": true,
        "disableWhileTyping": false,
        "accelProfile": "flat"
    })

    property var touchpadSettings: {
        let s = (typeof Config !== "undefined" && Config.rawSettings) ? Config.rawSettings["touchpad"] : undefined;
        if (s !== undefined && s !== null) return s;
        if (typeof Config !== "undefined" && typeof Config.getSetting === "function") {
            return Config.getSetting("touchpad", touchpadTabRoot.defaultTouchpadSettings);
        }
        return touchpadTabRoot.defaultTouchpadSettings;
    }

    property real currentSensitivity: touchpadSettings && touchpadSettings.sensitivity !== undefined ? Number(touchpadSettings.sensitivity) : 0.0
    property bool currentNaturalScroll: touchpadSettings && touchpadSettings.naturalScroll !== undefined ? Boolean(touchpadSettings.naturalScroll) : true
    property bool currentDisableWhileTyping: touchpadSettings && touchpadSettings.disableWhileTyping !== undefined ? Boolean(touchpadSettings.disableWhileTyping) : false
    property string currentAccelProfile: touchpadSettings && touchpadSettings.accelProfile !== undefined ? String(touchpadSettings.accelProfile) : "flat"

    readonly property string scriptPath: (typeof Caching !== "undefined" && Caching.serpantinumDir ? Caching.serpantinumDir : "") + "/src/scripts/touchpad.sh"

    function syncSettings() {
        let s = (typeof Config !== "undefined" && typeof Config.getSetting === "function")
            ? Config.getSetting("touchpad", touchpadTabRoot.defaultTouchpadSettings)
            : touchpadTabRoot.defaultTouchpadSettings;
        touchpadTabRoot.touchpadSettings = s;
        touchpadTabRoot.currentSensitivity = (s && s.sensitivity !== undefined) ? Number(s.sensitivity) : 0.0;
        touchpadTabRoot.currentNaturalScroll = (s && s.naturalScroll !== undefined) ? Boolean(s.naturalScroll) : true;
        touchpadTabRoot.currentDisableWhileTyping = (s && s.disableWhileTyping !== undefined) ? Boolean(s.disableWhileTyping) : false;
        touchpadTabRoot.currentAccelProfile = (s && s.accelProfile !== undefined) ? String(s.accelProfile) : "flat";

        getterProc.running = true;
    }

    function applyLiveSensitivity(val) {
        let rounded = Math.round(val * 100) / 100;
        Quickshell.execDetached(["bash", scriptPath, "live-speed", rounded.toFixed(2)]);
    }

    function saveSensitivity(val) {
        let rounded = Math.round(val * 100) / 100;
        touchpadTabRoot.currentSensitivity = rounded;
        let current = JSON.parse(JSON.stringify(touchpadTabRoot.touchpadSettings || touchpadTabRoot.defaultTouchpadSettings));
        current.sensitivity = rounded;
        Config.setSetting("touchpad", current);
        touchpadTabRoot.touchpadSettings = current;
        Quickshell.execDetached(["bash", scriptPath, "set-speed", rounded.toFixed(2)]);
    }

    function saveNaturalScroll(val) {
        touchpadTabRoot.currentNaturalScroll = val;
        let current = JSON.parse(JSON.stringify(touchpadTabRoot.touchpadSettings || touchpadTabRoot.defaultTouchpadSettings));
        current.naturalScroll = val;
        Config.setSetting("touchpad", current);
        touchpadTabRoot.touchpadSettings = current;
        Quickshell.execDetached(["bash", scriptPath, "set-natural-scroll", val ? "true" : "false"]);
    }

    function saveDisableWhileTyping(val) {
        touchpadTabRoot.currentDisableWhileTyping = val;
        let current = JSON.parse(JSON.stringify(touchpadTabRoot.touchpadSettings || touchpadTabRoot.defaultTouchpadSettings));
        current.disableWhileTyping = val;
        Config.setSetting("touchpad", current);
        touchpadTabRoot.touchpadSettings = current;
        Quickshell.execDetached(["bash", scriptPath, "set-disable-while-typing", val ? "true" : "false"]);
    }

    function saveAccelProfile(val) {
        touchpadTabRoot.currentAccelProfile = val;
        let current = JSON.parse(JSON.stringify(touchpadTabRoot.touchpadSettings || touchpadTabRoot.defaultTouchpadSettings));
        current.accelProfile = val;
        Config.setSetting("touchpad", current);
        touchpadTabRoot.touchpadSettings = current;
        Quickshell.execDetached(["bash", scriptPath, "set-accel-profile", val]);
    }

    function resetToDefault() {
        touchpadTabRoot.currentSensitivity = 0.0;
        touchpadTabRoot.currentNaturalScroll = true;
        touchpadTabRoot.currentDisableWhileTyping = false;
        touchpadTabRoot.currentAccelProfile = "flat";

        let current = {
            "sensitivity": 0.0,
            "naturalScroll": true,
            "disableWhileTyping": false,
            "accelProfile": "flat"
        };
        Config.setSetting("touchpad", current);
        touchpadTabRoot.touchpadSettings = current;

        Quickshell.execDetached(["bash", scriptPath, "reset"]);
    }

    Timer {
        id: debounceTimer
        interval: 150
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
        debounceTimer.pendingCallback = cb;
        debounceTimer.restart();
    }

    Process {
        id: getterProc
        running: false
        command: ["bash", scriptPath, "get"]
        stdout: StdioCollector {
            onStreamFinished: {
                let out = this.text;
                if (!out) return;
                try {
                    let d = JSON.parse(out.trim());
                    if (d) {
                        let sens = d.float !== undefined ? d.float : d.sensitivity;
                        if (typeof sens === "number" && !isNaN(sens)) {
                            touchpadTabRoot.currentSensitivity = Math.round(sens * 100) / 100;
                        }
                    }
                } catch(e) {}
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
        target: typeof Config !== "undefined" ? Config : null
        function onSettingsLoaded() {
            touchpadTabRoot.syncSettings();
        }
    }

    Flickable {
        anchors.fill: parent
        anchors.topMargin: rootObj.s(8)
        anchors.leftMargin: rootObj.s(8)
        anchors.rightMargin: rootObj.s(8)
        anchors.bottomMargin: rootObj.s(8)
        contentHeight: settingsCol.implicitHeight + rootObj.s(20)
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        ColumnLayout {
            id: settingsCol
            width: parent.width
            spacing: rootObj.s(10)

            SettingsBlob {
                // 1. Cursor Speed / Pointer Sensitivity Row
                SettingsRow {
                    rootObj: touchpadTabRoot.rootObj
                    settingId: "touchpad_sensitivity"
                    icon: "󰆏"
                    title: I18n.t("guide.touchpad.sensitivity.title", "Cursor speed")
                    description: I18n.t("guide.touchpad.sensitivity.desc", "Adjust overall pointer sensitivity (-1.0 to 1.0). 0.0 is default")
                    searchKeywords: "touchpad cursor speed pointer sensitivity hyprland mouse trackpad"

                    RowLayout {
                        Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                        spacing: rootObj.s(10)

                        Draggable {
                            id: sensSlider
                            Layout.alignment: Qt.AlignVCenter
                            implicitWidth: rootObj.s(180)
                            implicitHeight: rootObj.s(18)
                            from: -1.0
                            to: 1.0
                            stepSize: 0.05
                            defaultValue: 0.0
                            alwaysShowHandle: true
                            showValueBubble: false
                            showTooltip: false
                            valueFormatter: function(v) {
                                let rounded = Math.round(v * 100) / 100;
                                return rounded.toFixed(2);
                            }
                            value: touchpadTabRoot.currentSensitivity

                            Binding {
                                target: sensSlider
                                property: "value"
                                value: touchpadTabRoot.currentSensitivity
                                when: !sensSlider.isDragging
                            }

                            backgroundColor: ThemeBackend.surface0
                            accentColor: ThemeBackend.mauve
                            handleColor: ThemeBackend.text
                            handleBorderColor: ThemeBackend.mantle

                            onMoved: function(val) {
                                let rounded = Math.round(val * 100) / 100;
                                if (touchpadTabRoot.currentSensitivity !== rounded) {
                                    touchpadTabRoot.currentSensitivity = rounded;
                                    touchpadTabRoot.applyLiveSensitivity(rounded);
                                }
                            }

                            onDragFinished: {
                                touchpadTabRoot.saveSensitivity(sensSlider.value);
                            }
                        }

                        NumberSelector {
                            id: sensNumberSelector
                            Layout.alignment: Qt.AlignVCenter
                            implicitWidth: rootObj.s(110)
                            implicitHeight: rootObj.s(32)
                            from: -1.0
                            to: 1.0
                            stepSize: 0.05
                            decimals: 2
                            prefix: ""
                            suffix: ""
                            value: touchpadTabRoot.currentSensitivity

                            Binding {
                                target: sensNumberSelector
                                property: "value"
                                value: touchpadTabRoot.currentSensitivity
                            }

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

                            onValueChanged: function(val) {
                                let num = (typeof val === "number" && !isNaN(val)) ? val : value;
                                let rounded = Math.round(num * 100) / 100;
                                if (!isNaN(rounded) && rounded >= -1.0 && rounded <= 1.0 && Math.abs(touchpadTabRoot.currentSensitivity - rounded) > 0.001) {
                                    touchpadTabRoot.currentSensitivity = rounded;
                                    touchpadTabRoot.applyLiveSensitivity(rounded);
                                    touchpadTabRoot.triggerDebounced(function() {
                                        touchpadTabRoot.saveSensitivity(rounded);
                                    });
                                }
                            }

                            onTriggered: {
                                let rounded = Math.round(sensNumberSelector.value * 100) / 100;
                                touchpadTabRoot.saveSensitivity(rounded);
                            }
                        }
                    }
                }

                // 2. Acceleration Profile Row
                SettingsRow {
                    rootObj: touchpadTabRoot.rootObj
                    settingId: "touchpad_accel_profile"
                    icon: "󰓅"
                    title: I18n.t("guide.touchpad.accel_profile.title", "Acceleration profile")
                    description: I18n.t("guide.touchpad.accel_profile.desc", "Flat profile ensures consistent linear pointer motion without acceleration curves")
                    searchKeywords: "accel profile flat adaptive acceleration pointer"

                    Switch {
                        id: accelSwitch
                        Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                        implicitWidth: rootObj.s(160)
                        implicitHeight: rootObj.s(30)
                        options: ["Flat", "Adaptive"]
                        currentIndex: touchpadTabRoot.currentAccelProfile === "adaptive" ? 1 : 0
                        accentColor: ThemeBackend.mauve
                        baseColor: ThemeBackend.surface0
                        textColor: ThemeBackend.text
                        activeTextColor: ThemeBackend.crust
                        cornerRadius: ThemeBackend.borderRadius
                        fontPixelSize: rootObj.s(11)

                        onValueChanged: function(idx, val) {
                            let next = idx === 1 ? "adaptive" : "flat";
                            if (touchpadTabRoot.currentAccelProfile !== next) {
                                touchpadTabRoot.saveAccelProfile(next);
                            }
                        }
                    }
                }

                // 3. Natural Scrolling Row
                SettingsRow {
                    rootObj: touchpadTabRoot.rootObj
                    settingId: "touchpad_natural_scroll"
                    icon: "󰹹"
                    title: I18n.t("guide.touchpad.natural_scroll.title", "Natural scrolling")
                    description: I18n.t("guide.touchpad.natural_scroll.desc", "Invert scroll direction so content tracks finger movement")
                    searchKeywords: "natural scroll inverse scrolling touchpad gestures"

                    Toggle {
                        id: natScrollToggle
                        Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                        checked: touchpadTabRoot.currentNaturalScroll
                        accentColor: ThemeBackend.mauve
                        baseColor: ThemeBackend.surface0
                        handleColor: ThemeBackend.crust
                        handleOffColor: ThemeBackend.text
                        onToggled: function(c) {
                            touchpadTabRoot.saveNaturalScroll(c);
                        }
                    }
                }

                // 4. Disable While Typing Row
                SettingsRow {
                    rootObj: touchpadTabRoot.rootObj
                    settingId: "touchpad_disable_while_typing"
                    icon: "󰌌"
                    title: I18n.t("guide.touchpad.disable_while_typing.title", "Disable while typing")
                    description: I18n.t("guide.touchpad.disable_while_typing.desc", "Prevent accidental pointer movement while typing on keyboard")
                    searchKeywords: "disable while typing palms touchpad keyboard palm rejection"

                    Toggle {
                        id: dwtToggle
                        Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                        checked: touchpadTabRoot.currentDisableWhileTyping
                        accentColor: ThemeBackend.mauve
                        baseColor: ThemeBackend.surface0
                        handleColor: ThemeBackend.crust
                        handleOffColor: ThemeBackend.text
                        onToggled: function(c) {
                            touchpadTabRoot.saveDisableWhileTyping(c);
                        }
                    }
                }

                // 5. Reset to Default Row
                SettingsRow {
                    rootObj: touchpadTabRoot.rootObj
                    settingId: "touchpad_reset_default"
                    icon: "󰑓"
                    title: I18n.t("guide.touchpad.reset.title", "Reset to default")
                    description: I18n.t("guide.touchpad.reset.desc", "Restore default cursor speed and touchpad settings")
                    searchKeywords: "reset default sensitivity touchpad revert restore"

                    ClickButton {
                        id: resetBtn
                        Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                        implicitHeight: rootObj.s(32)
                        implicitWidth: rootObj.s(150)
                        buttonText: I18n.t("guide.touchpad.reset.button", "Reset to default")
                        buttonIcon: "󰑓"
                        accentColor: ThemeBackend.surface1
                        textColor: ThemeBackend.text
                        cornerRadius: ThemeBackend.borderRadius
                        textFontSize: rootObj.s(11)
                        iconFontSize: rootObj.s(13)

                        onClicked: {
                            touchpadTabRoot.resetToDefault();
                        }
                    }
                }
            }
        }
    }
}
