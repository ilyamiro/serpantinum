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
import "../reusables/display"

GuideTab {
    id: touchpadTabRoot

    property var defaultTouchpadSettings: ({
        "sensitivity": 0.5,
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

    property real currentSensitivity: touchpadSettings && touchpadSettings.sensitivity !== undefined ? Number(touchpadSettings.sensitivity) : 0.5
    property bool currentNaturalScroll: touchpadSettings && touchpadSettings.naturalScroll !== undefined ? Boolean(touchpadSettings.naturalScroll) : true
    property bool currentDisableWhileTyping: touchpadSettings && touchpadSettings.disableWhileTyping !== undefined ? Boolean(touchpadSettings.disableWhileTyping) : false
    property string currentAccelProfile: touchpadSettings && touchpadSettings.accelProfile !== undefined ? String(touchpadSettings.accelProfile) : "flat"

    readonly property string scriptPath: (typeof Caching !== "undefined" && Caching.serpantinumDir ? Caching.serpantinumDir : "") + "/src/scripts/touchpad.sh"

    property bool isReloading: false
    property bool reloadSuccess: false

    function syncSettings() {
        let s = (typeof Config !== "undefined" && typeof Config.getSetting === "function")
            ? Config.getSetting("touchpad", touchpadTabRoot.defaultTouchpadSettings)
            : touchpadTabRoot.defaultTouchpadSettings;
        touchpadTabRoot.touchpadSettings = s;
        touchpadTabRoot.currentSensitivity = (s && s.sensitivity !== undefined) ? Number(s.sensitivity) : 0.5;
        touchpadTabRoot.currentNaturalScroll = (s && s.naturalScroll !== undefined) ? Boolean(s.naturalScroll) : true;
        touchpadTabRoot.currentDisableWhileTyping = (s && s.disableWhileTyping !== undefined) ? Boolean(s.disableWhileTyping) : false;
        touchpadTabRoot.currentAccelProfile = (s && s.accelProfile !== undefined) ? String(s.accelProfile) : "flat";

        // Query live compositor values
        getterProc.running = true;
    }

    function applyLiveSensitivity(val) {
        let rounded = Math.round(val * 100) / 100;
        Quickshell.execDetached(["bash", scriptPath, "live-speed", rounded.toString()]);
    }

    function commitSettings() {
        let current = {
            "sensitivity": Math.round(touchpadTabRoot.currentSensitivity * 100) / 100,
            "naturalScroll": touchpadTabRoot.currentNaturalScroll,
            "disableWhileTyping": touchpadTabRoot.currentDisableWhileTyping,
            "accelProfile": touchpadTabRoot.currentAccelProfile
        };
        Config.setSetting("touchpad", current);
        touchpadTabRoot.touchpadSettings = current;

        Quickshell.execDetached(["bash", scriptPath, "set-speed", current.sensitivity.toString()]);
    }

    function setPreset(val) {
        touchpadTabRoot.currentSensitivity = val;
        applyLiveSensitivity(val);
        commitSettings();
    }

    function reloadHyprland() {
        touchpadTabRoot.isReloading = true;
        commitSettings();
        reloadTimer.restart();
    }

    Timer {
        id: reloadTimer
        interval: 350
        repeat: false
        onTriggered: {
            touchpadTabRoot.isReloading = false;
            touchpadTabRoot.reloadSuccess = true;
            successTimer.restart();
        }
    }

    Timer {
        id: successTimer
        interval: 2500
        repeat: false
        onTriggered: touchpadTabRoot.reloadSuccess = false
    }

    Timer {
        id: debounceTimer
        interval: 180
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

            // Interactive Touchpad Test Surface / Sandbox Card
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: rootObj.s(120)
                radius: ThemeBackend.borderRadius
                color: testGlass.active ? "transparent" : Qt.alpha(ThemeBackend.surface0, 0.45)
                border.color: Qt.alpha(ThemeBackend.surface2, 0.35)
                border.width: 1
                clip: true

                GlassFill {
                    id: testGlass
                    anchors.fill: parent
                    radius: parent.radius
                    tintColor: ThemeBackend.surface0
                    tintAmount: 0.18
                }

                // Grid pattern background lines
                Canvas {
                    id: gridCanvas
                    anchors.fill: parent
                    opacity: 0.15
                    onPaint: {
                        let ctx = getContext("2d");
                        ctx.clearRect(0, 0, width, height);
                        ctx.strokeStyle = ThemeBackend.overlay1;
                        ctx.lineWidth = 1;
                        let step = 24;
                        for (let x = step; x < width; x += step) {
                            ctx.beginPath();
                            ctx.moveTo(x, 0);
                            ctx.lineTo(x, height);
                            ctx.stroke();
                        }
                        for (let y = step; y < height; y += step) {
                            ctx.beginPath();
                            ctx.moveTo(0, y);
                            ctx.lineTo(width, y);
                            ctx.stroke();
                        }
                    }
                }

                // Interactive Pointer tracking ripple
                Item {
                    id: trackerDot
                    x: testMa.mouseX - width / 2
                    y: testMa.mouseY - height / 2
                    width: rootObj.s(32)
                    height: rootObj.s(32)
                    visible: testMa.containsMouse
                    opacity: testMa.containsMouse ? 1.0 : 0.0
                    Behavior on opacity { NumberAnimation { duration: 180 } }

                    Rectangle {
                        anchors.fill: parent
                        radius: width / 2
                        color: Qt.alpha(ThemeBackend.mauve, 0.25)
                        border.color: ThemeBackend.mauve
                        border.width: 1.5

                        Rectangle {
                            anchors.centerIn: parent
                            width: rootObj.s(8)
                            height: rootObj.s(8)
                            radius: width / 2
                            color: ThemeBackend.mauve
                        }
                    }
                }

                MouseArea {
                    id: testMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.CrossCursor
                }

                // Top badges in test card
                RowLayout {
                    anchors.top: parent.top
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.margins: rootObj.s(10)
                    spacing: rootObj.s(8)

                    Rectangle {
                        Layout.preferredHeight: rootObj.s(22)
                        Layout.preferredWidth: badgeRow.implicitWidth + rootObj.s(14)
                        radius: rootObj.s(11)
                        color: Qt.alpha(ThemeBackend.surface1, 0.7)
                        border.color: Qt.alpha(ThemeBackend.surface2, 0.5)
                        border.width: 1

                        RowLayout {
                            id: badgeRow
                            anchors.centerIn: parent
                            spacing: rootObj.s(5)

                            Text {
                                text: "󰟀"
                                font.family: ThemeBackend.iconFont
                                font.pixelSize: rootObj.s(12)
                                color: ThemeBackend.mauve
                            }

                            Text {
                                text: I18n.t("guide.touchpad.test_area.title", "Touchpad test area")
                                font.family: ThemeBackend.fontFamily
                                font.pixelSize: rootObj.s(11)
                                font.bold: true
                                color: ThemeBackend.text
                            }
                        }
                    }

                    Item { Layout.fillWidth: true }

                    // Live stats pill
                    Rectangle {
                        Layout.preferredHeight: rootObj.s(22)
                        Layout.preferredWidth: liveStatRow.implicitWidth + rootObj.s(14)
                        radius: rootObj.s(11)
                        color: Qt.alpha(ThemeBackend.mauve, 0.18)
                        border.color: Qt.alpha(ThemeBackend.mauve, 0.4)
                        border.width: 1

                        RowLayout {
                            id: liveStatRow
                            anchors.centerIn: parent
                            spacing: rootObj.s(6)

                            Text {
                                text: "󰆏"
                                font.family: ThemeBackend.iconFont
                                font.pixelSize: rootObj.s(11)
                                color: ThemeBackend.mauve
                            }

                            Text {
                                text: "Sensitivity: " + (touchpadTabRoot.currentSensitivity > 0 ? "+" : "") + touchpadTabRoot.currentSensitivity.toFixed(2)
                                font.family: ThemeBackend.fontFamily
                                font.pixelSize: rootObj.s(10)
                                font.bold: true
                                color: ThemeBackend.text
                            }

                            Text {
                                text: "•"
                                font.pixelSize: rootObj.s(10)
                                color: ThemeBackend.subtext0
                            }

                            Text {
                                text: "Profile: " + touchpadTabRoot.currentAccelProfile
                                font.family: ThemeBackend.fontFamily
                                font.pixelSize: rootObj.s(10)
                                color: ThemeBackend.subtext0
                            }
                        }
                    }
                }

                // Center hint
                Text {
                    anchors.centerIn: parent
                    visible: !testMa.containsMouse
                    text: I18n.t("guide.touchpad.test_area.hint", "Move pointer here to test cursor speed")
                    font.family: ThemeBackend.fontFamily
                    font.pixelSize: rootObj.s(12)
                    color: Qt.alpha(ThemeBackend.subtext0, 0.6)
                }
            }

            // Main Settings Blob
            SettingsBlob {
                // 1. Cursor Speed / Pointer Sensitivity Row
                SettingsRow {
                    rootObj: touchpadTabRoot.rootObj
                    settingId: "touchpad_sensitivity"
                    icon: "󰆏"
                    title: I18n.t("guide.touchpad.sensitivity.title", "Cursor speed")
                    description: I18n.t("guide.touchpad.sensitivity.desc", "Adjust overall pointer sensitivity (-1.0 to 1.0). 0.0 is default, 0.5 is faster, 1.0 is maximum")
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
                            defaultValue: 0.5
                            showValueBubble: true
                            valueFormatter: function(v) {
                                let rounded = Math.round(v * 100) / 100;
                                return (rounded > 0 ? "+" : "") + rounded.toFixed(2);
                            }
                            value: touchpadTabRoot.currentSensitivity
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
                                touchpadTabRoot.commitSettings();
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
                            prefix: touchpadTabRoot.currentSensitivity > 0 ? "+" : ""
                            value: touchpadTabRoot.currentSensitivity
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
                                if (!isNaN(rounded) && rounded >= -1.0 && rounded <= 1.0 && touchpadTabRoot.currentSensitivity !== rounded) {
                                    touchpadTabRoot.currentSensitivity = rounded;
                                    touchpadTabRoot.applyLiveSensitivity(rounded);
                                    touchpadTabRoot.triggerDebounced(function() {
                                        touchpadTabRoot.commitSettings();
                                    });
                                }
                            }

                            onTriggered: {
                                let rounded = Math.round(sensNumberSelector.value * 100) / 100;
                                touchpadTabRoot.currentSensitivity = rounded;
                                touchpadTabRoot.commitSettings();
                            }
                        }
                    }
                }

                // 2. Preset Buttons Row
                SettingsRow {
                    rootObj: touchpadTabRoot.rootObj
                    settingId: "touchpad_presets"
                    icon: "󰁍"
                    title: I18n.t("guide.touchpad.presets.title", "Speed presets")
                    description: "Quickly switch between common sensitivity levels"
                    searchKeywords: "preset slower default faster maximum sensitivity 0.0 0.5 1.0 -0.5"

                    RowLayout {
                        Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                        spacing: rootObj.s(6)

                        Repeater {
                            model: [
                                { label: I18n.t("guide.touchpad.presets.slower", "Slower (-0.5)"), val: -0.5, icon: "󰁎" },
                                { label: I18n.t("guide.touchpad.presets.default", "Default (0.0)"), val: 0.0, icon: "󰁍" },
                                { label: I18n.t("guide.touchpad.presets.faster", "Faster (+0.5)"), val: 0.5, icon: "󰁕" },
                                { label: I18n.t("guide.touchpad.presets.maximum", "Maximum (+1.0)"), val: 1.0, icon: "󰁝" }
                            ]

                            delegate: Rectangle {
                                id: presetBtn
                                required property var modelData
                                readonly property bool isActive: Math.abs(touchpadTabRoot.currentSensitivity - modelData.val) < 0.04
                                Layout.preferredHeight: rootObj.s(28)
                                Layout.preferredWidth: presetRow.implicitWidth + rootObj.s(16)
                                radius: ThemeBackend.borderRadius
                                color: isActive
                                    ? ThemeBackend.mauve
                                    : (presetMa.containsMouse ? Qt.alpha(ThemeBackend.surface1, 0.8) : Qt.alpha(ThemeBackend.surface0, 0.7))
                                border.color: isActive ? ThemeBackend.mauve : Qt.alpha(ThemeBackend.surface2, 0.5)
                                border.width: 1

                                Behavior on color { ColorAnimation { duration: 110 } }

                                RowLayout {
                                    id: presetRow
                                    anchors.centerIn: parent
                                    spacing: rootObj.s(5)

                                    Text {
                                        text: presetBtn.modelData.icon
                                        font.family: ThemeBackend.iconFont
                                        font.pixelSize: rootObj.s(11)
                                        color: presetBtn.isActive ? ThemeBackend.crust : ThemeBackend.mauve
                                    }

                                    Text {
                                        text: presetBtn.modelData.label
                                        font.family: ThemeBackend.fontFamily
                                        font.pixelSize: rootObj.s(10)
                                        font.weight: presetBtn.isActive ? Font.Bold : Font.Medium
                                        color: presetBtn.isActive ? ThemeBackend.crust : ThemeBackend.text
                                    }
                                }

                                MouseArea {
                                    id: presetMa
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        touchpadTabRoot.setPreset(presetBtn.modelData.val);
                                    }
                                }
                            }
                        }
                    }
                }

                // 3. Acceleration Profile Row
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
                                touchpadTabRoot.currentAccelProfile = next;
                                touchpadTabRoot.commitSettings();
                            }
                        }
                    }
                }

                // 4. Natural Scrolling Row
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
                            touchpadTabRoot.currentNaturalScroll = c;
                            touchpadTabRoot.commitSettings();
                        }
                    }
                }

                // 5. Disable While Typing Row
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
                            touchpadTabRoot.currentDisableWhileTyping = c;
                            touchpadTabRoot.commitSettings();
                        }
                    }
                }
            }

            // Save and Reload Hyprland Section
            SettingsBlob {
                SettingsRow {
                    rootObj: touchpadTabRoot.rootObj
                    settingId: "touchpad_reload_hyprland"
                    icon: "󰑓"
                    title: I18n.t("guide.touchpad.reload.button", "Reload Hyprland")
                    description: I18n.t("guide.touchpad.reload.desc", "Save and reload Hyprland configuration (hyprctl reload)")
                    searchKeywords: "reload hyprland hyprctl reload restart apply"

                    ClickButton {
                        id: reloadBtn
                        Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                        implicitHeight: rootObj.s(32)
                        implicitWidth: rootObj.s(150)
                        buttonText: touchpadTabRoot.reloadSuccess
                            ? I18n.t("guide.touchpad.reload.success", "Hyprland reloaded!")
                            : (touchpadTabRoot.isReloading ? "Reloading..." : "hyprctl reload")
                        buttonIcon: touchpadTabRoot.reloadSuccess ? "󰄬" : "󰑓"
                        accentColor: touchpadTabRoot.reloadSuccess
                            ? ThemeBackend.green
                            : ThemeBackend.mauve
                        textColor: ThemeBackend.crust
                        cornerRadius: ThemeBackend.borderRadius
                        textFontSize: rootObj.s(11)
                        iconFontSize: rootObj.s(13)

                        onClicked: {
                            touchpadTabRoot.reloadHyprland();
                        }
                    }
                }
            }
        }
    }
}
