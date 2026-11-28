import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import "../"
import "../reusables"

GuideTab {
    id: osdTabRoot

    property bool selectorOpen: false
    property bool gridEnabled: false
    property bool showBarBox: true

    ConfigSection {
        id: osdCfg
        section: "osd"
        defaults: ({
            "horizontalPosition": 50,
            "verticalPosition": 90,
            "orientation": "horizontal",
            "showCapsLock": true,
            "showNumLock": true,
            "showAirplane": true,
            "showKeyboardLayout": false,
            "attachToBar": true
        })
    }

    readonly property int horizontalPosition: Number(osdCfg.values.horizontalPosition !== undefined ? osdCfg.values.horizontalPosition : 50)
    readonly property int verticalPosition: Number(osdCfg.values.verticalPosition !== undefined ? osdCfg.values.verticalPosition : 90)
    readonly property string orientation: String(osdCfg.values.orientation !== undefined ? osdCfg.values.orientation : "horizontal")
    readonly property bool isVertical: orientation === "vertical"
    readonly property bool showCapsLock: Boolean(osdCfg.values.showCapsLock !== undefined ? osdCfg.values.showCapsLock : true)
    readonly property bool showNumLock: Boolean(osdCfg.values.showNumLock !== undefined ? osdCfg.values.showNumLock : true)
    readonly property bool showAirplane: Boolean(osdCfg.values.showAirplane !== undefined ? osdCfg.values.showAirplane : true)
    readonly property bool showKeyboardLayout: Boolean(osdCfg.values.showKeyboardLayout !== undefined ? osdCfg.values.showKeyboardLayout : false)
    readonly property bool attachToBar: Boolean(osdCfg.values.attachToBar !== undefined ? osdCfg.values.attachToBar : true)

    readonly property bool isCustomPos: {
        let h = horizontalPosition;
        let v = verticalPosition;
        return !(
            (h === 50 && v === 90) ||
            (h === 10 && v === 90) ||
            (h === 90 && v === 90) ||
            (h === 50 && v === 10) ||
            (h === 10 && v === 10) ||
            (h === 90 && v === 10)
        );
    }

    onIsCustomPosChanged: {
        if (isCustomPos) {
            posDropdown.currentIndex = -1;
        }
    }

    function applyPosition(h, v) {
        if (screenSelector) {
            screenSelector.horizontalPosition = h;
            screenSelector.verticalPosition = v;
        }
        osdCfg.setDebounced("horizontalPosition", h, 100);
        osdCfg.setDebounced("verticalPosition", v, 100);
    }

    function setPosFromIndex(index) {
        if (index === 0) applyPosition(50, 90);
        else if (index === 1) applyPosition(10, 90);
        else if (index === 2) applyPosition(90, 90);
        else if (index === 3) applyPosition(50, 10);
        else if (index === 4) applyPosition(10, 10);
        else if (index === 5) applyPosition(90, 10);
    }

    function updateOsdSetting(key, value) {
        osdCfg.set(key, value);
    }

    onVisibleChanged: {
        if (!visible) {
            osdCfg.flush();
            selectorOpen = false;
            if (posDropdown.isOpen) posDropdown.closePopup();
        }
    }

    GuideScrollView {
        rootObj: osdTabRoot.rootObj

            SettingsBlob {
                SettingsRow {
                    id: posSettingsRow
                    rootObj: osdTabRoot.rootObj
                    settingId: "osd_position"
                    searchKeywords: "osd on-screen display position placement orientation horizontal vertical volume brightness"
                    icon: "󰍹"
                    title: I18n.t("guide.osd.position.title", "Screen position")
                    titleBold: true
                    wrapText: true
                    description: I18n.t("guide.osd.position.desc", "Select a preset position or drag on screen")
                    innerSpacing: (osdTabRoot.selectorOpen || selectorWrapper.implicitHeight > 0) ? rootObj.s(12) : 0
                    bottomSpacing: 0

                    ClickButton {
                        implicitHeight: rootObj.s(32)
                        horizontalPadding: rootObj.s(12)
                        buttonText: osdTabRoot.selectorOpen ? I18n.t("guide.osd.position.close_selector", "Close the selector") : I18n.t("guide.osd.position.select_on_screen", "Select on screen...")
                        buttonIcon: osdTabRoot.selectorOpen ? "󰅖" : "󰍹"
                        iconFontSize: rootObj.s(13)
                        textFontSize: rootObj.s(11)
                        accentColor: osdTabRoot.selectorOpen ? ThemeBackend.mauve : ThemeBackend.surface0
                        textColor: osdTabRoot.selectorOpen ? ThemeBackend.crust : ThemeBackend.text
                        cornerRadius: ThemeBackend.borderRadius
                        onClicked: {
                            osdTabRoot.selectorOpen = !osdTabRoot.selectorOpen;
                        }
                    }

                    Rectangle {
                        id: osdCustomBadge
                        Layout.alignment: Qt.AlignVCenter
                        implicitHeight: rootObj.s(32)
                        implicitWidth: osdTabRoot.isCustomPos ? (customPosText.implicitWidth + rootObj.s(20)) : 0
                        radius: ThemeBackend.borderRadius
                        color: gf1.active ? "transparent" : ThemeBackend.surface0

                        GlassFill {
                            id: gf1
                            anchors.fill: parent
                            radius: parent.radius
                            tintColor: ThemeBackend.surface0
                            tintAmount: 0.25
                        }
                        clip: true
                        opacity: osdTabRoot.isCustomPos ? 1.0 : 0.0
                        visible: opacity > 0.001

                        Behavior on implicitWidth { NumberAnimation { duration: 250; easing.type: Easing.OutCubic } }
                        Behavior on opacity { NumberAnimation { duration: 250; easing.type: Easing.OutCubic } }

                        Text {
                            id: customPosText
                            anchors.centerIn: parent
                            text: I18n.t("guide.position.custom", "Custom") + " (" + osdTabRoot.horizontalPosition + "%, " + osdTabRoot.verticalPosition + "%)"
                            font.family: ThemeBackend.fontFamily
                            font.pixelSize: rootObj.s(11)
                            font.bold: true
                            color: "#ffffff"
                        }
                    }

                    Dropdown {
                        id: posDropdown
                        Layout.alignment: Qt.AlignVCenter
                        Layout.preferredWidth: rootObj.s(180)
                        Layout.preferredHeight: rootObj.s(32)
                        options: [
                            I18n.t("guide.osd.position.bottom_center", "Bottom center"),
                            I18n.t("guide.osd.position.bottom_left", "Bottom left"),
                            I18n.t("guide.osd.position.bottom_right", "Bottom right"),
                            I18n.t("guide.osd.position.top_center", "Top center"),
                            I18n.t("guide.osd.position.top_left", "Top left"),
                            I18n.t("guide.osd.position.top_right", "Top right")
                        ]
                        currentIndex: {
                            if (osdTabRoot.isCustomPos) return -1;
                            let v = osdTabRoot.verticalPosition;
                            let h = osdTabRoot.horizontalPosition;
                            if (v === 90 && h === 50) return 0;
                            if (v === 90 && h === 10) return 1;
                            if (v === 90 && h === 90) return 2;
                            if (v === 10 && h === 50) return 3;
                            if (v === 10 && h === 10) return 4;
                            if (v === 10 && h === 90) return 5;
                            return -1;
                        }
                        accentColor: ThemeBackend.mauve
                        baseColor: ThemeBackend.surface0
                        hoverColor: ThemeBackend.surface1
                        dropdownColor: ThemeBackend.surface0
                        borderColor: Qt.alpha(ThemeBackend.surface2, 0.6)
                        textColor: ThemeBackend.text
                        activeTextColor: ThemeBackend.crust
                        cornerRadius: ThemeBackend.borderRadius
                        fontPixelSize: rootObj.s(11)
                        onValueChanged: function(index, value) {
                            osdTabRoot.setPosFromIndex(index);
                        }
                        onSelected: function(index, value) {
                            osdTabRoot.setPosFromIndex(index);
                        }
                    }

                    Binding {
                        target: posDropdown
                        property: "currentIndex"
                        value: {
                            if (osdTabRoot.isCustomPos) return -1;
                            let v = osdTabRoot.verticalPosition;
                            let h = osdTabRoot.horizontalPosition;
                            if (v === 90 && h === 50) return 0;
                            if (v === 90 && h === 10) return 1;
                            if (v === 90 && h === 90) return 2;
                            if (v === 10 && h === 50) return 3;
                            if (v === 10 && h === 10) return 4;
                            if (v === 10 && h === 90) return 5;
                            return -1;
                        }
                    }

                    bottomContent: [
                        Item {
                            id: selectorWrapper
                            Layout.fillWidth: true
                            property bool isOpen: osdTabRoot.selectorOpen
                            clip: true
                            visible: implicitHeight > 0
                            opacity: isOpen ? 1.0 : 0.0
                            property real openProgress: isOpen ? 1 : 0
                            implicitHeight: selectorBox.implicitHeight * openProgress

                            Behavior on opacity { NumberAnimation { duration: 250; easing.type: Easing.OutCubic } }
                            Behavior on openProgress { NumberAnimation { duration: 250; easing.type: Easing.OutCubic } }

                            Rectangle {
                                id: selectorBox
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.top: parent.top
                                height: implicitHeight
                                implicitHeight: selectorInnerCol.implicitHeight + rootObj.s(24)
                                radius: ThemeBackend.borderRadius
                                color: gf2.active ? "transparent" : Qt.alpha(ThemeBackend.surface1, 0.35)

                                GlassFill {
                                    id: gf2
                                    anchors.fill: parent
                                    radius: parent.radius
                                    tintColor: Qt.alpha(ThemeBackend.surface1, 0.35)
                                    tintAmount: 0.25
                                }

                                ColumnLayout {
                                    id: selectorInnerCol
                                    anchors.left: parent.left
                                    anchors.right: parent.right
                                    anchors.top: parent.top
                                    anchors.margins: rootObj.s(12)
                                    spacing: rootObj.s(10)

                                    RowLayout {
                                        Layout.fillWidth: true
                                        spacing: rootObj.s(6)

                                        ClickButton {
                                            enabled: false
                                            Layout.preferredWidth: rootObj.s(140)
                                            implicitHeight: rootObj.s(26)
                                            cornerRadius: rootObj.s(6)
                                            horizontalPadding: rootObj.s(6)
                                            textFontSize: rootObj.s(11)
                                            accentColor: ThemeBackend.surface1
                                            textColor: "#ffffff"
                                            buttonText: "X: " + osdTabRoot.horizontalPosition + "%  Y: " + osdTabRoot.verticalPosition + "%"
                                        }

                                        IconButton {
                                            size: rootObj.s(26)
                                            cornerRadius: rootObj.s(6)
                                            buttonIcon: "󰕰"
                                            iconFontSize: rootObj.s(13)
                                            accentColor: osdTabRoot.gridEnabled ? ThemeBackend.mauve : ThemeBackend.surface1
                                            textColor: osdTabRoot.gridEnabled ? ThemeBackend.crust : ThemeBackend.text
                                            onClicked: {
                                                osdTabRoot.gridEnabled = !osdTabRoot.gridEnabled;
                                            }
                                        }

                                        IconButton {
                                            size: rootObj.s(26)
                                            cornerRadius: rootObj.s(6)
                                            buttonIcon: "󰑐"
                                            iconFontSize: rootObj.s(13)
                                            accentColor: ThemeBackend.surface1
                                            textColor: ThemeBackend.text
                                            onClicked: {
                                                osdTabRoot.applyPosition(50, 90);
                                            }
                                        }

                                        Switch {
                                            Layout.alignment: Qt.AlignVCenter
                                            implicitWidth: rootObj.s(160)
                                            implicitHeight: rootObj.s(26)
                                            cornerRadius: rootObj.s(6)
                                            fontPixelSize: rootObj.s(11)
                                            options: [I18n.t("guide.osd.orientation.horizontal", "Horizontal"), I18n.t("guide.osd.orientation.vertical", "Vertical")]
                                            currentIndex: osdTabRoot.orientation === "vertical" ? 1 : 0
                                            accentColor: ThemeBackend.mauve
                                            baseColor: Qt.alpha(ThemeBackend.surface0, 0.4)
                                            textColor: ThemeBackend.text
                                            activeTextColor: ThemeBackend.crust
                                            onValueChanged: function(index, value) {
                                                let orient = index === 1 ? "vertical" : "horizontal";
                                                osdTabRoot.updateOsdSetting("orientation", orient);
                                            }
                                        }

                                        Item {
                                            Layout.fillWidth: true
                                        }

                                        RowLayout {
                                            spacing: rootObj.s(8)
                                            Layout.alignment: Qt.AlignRight | Qt.AlignVCenter

                                            Text {
                                                text: I18n.t("guide.common.show_bar", "Show bar")
                                                font.family: ThemeBackend.fontFamily
                                                font.pixelSize: rootObj.s(11)
                                                color: ThemeBackend.subtext0
                                            }

                                            Toggle {
                                                checked: osdTabRoot.showBarBox
                                                accentColor: ThemeBackend.mauve
                                                baseColor: ThemeBackend.surface1
                                                handleColor: ThemeBackend.crust
                                                handleOffColor: ThemeBackend.text
                                                onToggled: function(c) {
                                                    osdTabRoot.showBarBox = c;
                                                }
                                            }
                                        }
                                    }

                                    ScreenPositionSelector {
                                        id: screenSelector
                                        Layout.fillWidth: true
                                        horizontalPosition: osdTabRoot.horizontalPosition
                                        verticalPosition: osdTabRoot.verticalPosition
                                        gridEnabled: osdTabRoot.gridEnabled
                                        showBar: osdTabRoot.showBarBox
                                        dragWidth: osdTabRoot.isVertical ? rootObj.s(43) : rootObj.s(173)
                                        dragHeight: osdTabRoot.isVertical ? rootObj.s(173) : rootObj.s(43)

                                        onPositionChanged: (hPos, vPos) => {
                                            posDropdown.currentIndex = -1;
                                            osdCfg.setDebounced("horizontalPosition", hPos, 100);
                                            osdCfg.setDebounced("verticalPosition", vPos, 100);
                                        }

                                        onDragFinished: {
                                            posDropdown.currentIndex = -1;
                                            osdCfg.flush();
                                        }

                                        Rectangle {
                                            anchors.fill: parent
                                            radius: rootObj.s(11)
                                            color: osdPreviewGlass.active ? "transparent" : ThemeBackend.base
                                            clip: true

                                            GlassFill {
                                                id: osdPreviewGlass
                                                anchors.fill: parent
                                                radius: parent.radius
                                                tintColor: ThemeBackend.base
                                                tintAmount: 0.35
                                                shadow: 1
                                            }

                                            RowLayout {
                                                visible: !osdTabRoot.isVertical
                                                anchors.fill: parent
                                                anchors.leftMargin: rootObj.s(7)
                                                anchors.rightMargin: rootObj.s(12)
                                                spacing: rootObj.s(9)

                                                Rectangle {
                                                    Layout.preferredWidth: parent.height - rootObj.s(10)
                                                    Layout.preferredHeight: parent.height - rootObj.s(10)
                                                    Layout.alignment: Qt.AlignVCenter
                                                    radius: rootObj.s(7)
                                                    color: osdIconGlassH.active ? "transparent" : ThemeBackend.surface1

                                                    GlassFill {
                                                        id: osdIconGlassH
                                                        anchors.fill: parent
                                                        radius: parent.radius
                                                        tintColor: ThemeBackend.surface1
                                                        tintAmount: 0.3
                                                    }

                                                    Text {
                                                        anchors.centerIn: parent
                                                        text: "󰕾"
                                                        font.family: ThemeBackend.iconFont
                                                        font.pixelSize: rootObj.s(18)
                                                        color: Qt.lighter(ThemeBackend.sapphire, 1.5)
                                                    }
                                                }

                                                Draggable {
                                                    Layout.fillWidth: true
                                                    Layout.preferredHeight: rootObj.s(18)
                                                    Layout.alignment: Qt.AlignVCenter
                                                    showValueBubble: false
                                                    alwaysShowHandle: true
                                                    value: 65
                                                    backgroundColor: ThemeBackend.surface1
                                                    accentColor: Qt.lighter(ThemeBackend.sapphire, 1.5)
                                                    gradColor1: accentColor
                                                    gradColor2: Qt.lighter(accentColor, 1.05)
                                                    gradColor3: Qt.lighter(accentColor, 1.10)
                                                    cornerRadius: rootObj.s(5)
                                                    handleSize: rootObj.s(16)
                                                    handleColor: Qt.lighter(accentColor, 1.3)
                                                }
                                            }

                                            ColumnLayout {
                                                visible: osdTabRoot.isVertical
                                                anchors.fill: parent
                                                anchors.topMargin: rootObj.s(7)
                                                anchors.bottomMargin: rootObj.s(12)
                                                spacing: rootObj.s(9)

                                                Rectangle {
                                                    Layout.preferredWidth: parent.width - rootObj.s(10)
                                                    Layout.preferredHeight: parent.width - rootObj.s(10)
                                                    Layout.alignment: Qt.AlignHCenter
                                                    radius: rootObj.s(7)
                                                    color: osdIconGlassV.active ? "transparent" : ThemeBackend.surface1

                                                    GlassFill {
                                                        id: osdIconGlassV
                                                        anchors.fill: parent
                                                        radius: parent.radius
                                                        tintColor: ThemeBackend.surface1
                                                        tintAmount: 0.3
                                                    }

                                                    Text {
                                                        anchors.centerIn: parent
                                                        text: "󰕾"
                                                        font.family: ThemeBackend.iconFont
                                                        font.pixelSize: rootObj.s(18)
                                                        color: Qt.lighter(ThemeBackend.sapphire, 1.5)
                                                    }
                                                }

                                                Draggable {
                                                    Layout.fillHeight: true
                                                    Layout.preferredWidth: rootObj.s(16)
                                                    Layout.alignment: Qt.AlignHCenter
                                                    vertical: true
                                                    showValueBubble: false
                                                    alwaysShowHandle: true
                                                    value: 65
                                                    backgroundColor: ThemeBackend.surface1
                                                    accentColor: Qt.lighter(ThemeBackend.sapphire, 1.5)
                                                    gradColor1: accentColor
                                                    gradColor2: Qt.lighter(accentColor, 1.05)
                                                    gradColor3: Qt.lighter(accentColor, 1.10)
                                                    cornerRadius: rootObj.s(5)
                                                    handleSize: rootObj.s(16)
                                                    handleColor: Qt.lighter(accentColor, 1.3)
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    ]
                }

                SettingsRow {
                    rootObj: osdTabRoot.rootObj
                    settingId: "osd_attach_bar"
                    searchKeywords: "osd attach snap bar solid fill popup"
                    icon: "󱂬"
                    title: I18n.t("guide.osd.attach_bar.title", "Attach to the bar in solid/fill style")
                    description: I18n.t("guide.osd.attach_bar.desc", "Snap OSD popups to the status bar in solid or fill mode. When disabled, the OSD always stays in the configured position.")
                    wrapText: true

                    Toggle {
                        Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                        checked: osdTabRoot.attachToBar
                        accentColor: ThemeBackend.mauve
                        baseColor: ThemeBackend.surface1
                        handleColor: ThemeBackend.crust
                        handleOffColor: ThemeBackend.text
                        onToggled: function(c) {
                            osdTabRoot.updateOsdSetting("attachToBar", c);
                        }
                    }
                }
            }

            GridLayout {
                Layout.fillWidth: true
                columns: 2
                columnSpacing: rootObj.s(6)
                rowSpacing: rootObj.s(6)

                SettingsBlob {
                    Layout.fillWidth: true
                    Layout.preferredWidth: 1
                    Layout.alignment: Qt.AlignTop
                    baseColor: osdTabRoot.isVertical ? Qt.alpha(ThemeBackend.surface0, 0.18) : Qt.alpha(ThemeBackend.surface0, 0.4)

                    SettingsRow {
                        rootObj: osdTabRoot.rootObj
                        settingId: "osd_capslock"
                        searchKeywords: "osd caps lock keyboard indicator popup"
                        icon: "󰘲"
                        title: I18n.t("guide.osd.capslock.title", "Show on Caps Lock")
                        titlePixelSize: 12
                        wrapText: true
                        stackBelowWidth: 0
                        titleColor: osdTabRoot.isVertical ? ThemeBackend.subtext0 : ThemeBackend.text
                        opacity: osdTabRoot.isVertical ? 0.6 : 1.0
                        Behavior on opacity { NumberAnimation { duration: 250 } }
                        spacing: rootObj.s(10)

                        Text {
                            visible: osdTabRoot.isVertical
                            Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                            text: I18n.t("guide.common.unavailable", "Unavailable")
                            font.family: ThemeBackend.fontFamily
                            font.pixelSize: rootObj.s(11)
                            font.bold: true
                            color: ThemeBackend.subtext0
                        }

                        Toggle {
                            visible: !osdTabRoot.isVertical
                            enabled: !osdTabRoot.isVertical
                            Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                            checked: osdTabRoot.showCapsLock
                            accentColor: ThemeBackend.mauve
                            baseColor: ThemeBackend.surface1
                            handleColor: ThemeBackend.crust
                            handleOffColor: ThemeBackend.text
                            onToggled: function(c) {
                                osdTabRoot.updateOsdSetting("showCapsLock", c);
                            }
                        }
                    }
                }

                SettingsBlob {
                    Layout.fillWidth: true
                    Layout.preferredWidth: 1
                    Layout.alignment: Qt.AlignTop
                    baseColor: osdTabRoot.isVertical ? Qt.alpha(ThemeBackend.surface0, 0.18) : Qt.alpha(ThemeBackend.surface0, 0.4)

                    SettingsRow {
                        rootObj: osdTabRoot.rootObj
                        settingId: "osd_numlock"
                        searchKeywords: "osd num lock numpad keyboard indicator popup"
                        icon: "󰎤"
                        title: I18n.t("guide.osd.numlock.title", "Show on Num Lock")
                        titlePixelSize: 12
                        wrapText: true
                        stackBelowWidth: 0
                        titleColor: osdTabRoot.isVertical ? ThemeBackend.subtext0 : ThemeBackend.text
                        opacity: osdTabRoot.isVertical ? 0.6 : 1.0
                        Behavior on opacity { NumberAnimation { duration: 250 } }
                        spacing: rootObj.s(10)

                        Text {
                            visible: osdTabRoot.isVertical
                            Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                            text: I18n.t("guide.common.unavailable", "Unavailable")
                            font.family: ThemeBackend.fontFamily
                            font.pixelSize: rootObj.s(11)
                            font.bold: true
                            color: ThemeBackend.subtext0
                        }

                        Toggle {
                            visible: !osdTabRoot.isVertical
                            enabled: !osdTabRoot.isVertical
                            Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                            checked: osdTabRoot.showNumLock
                            accentColor: ThemeBackend.mauve
                            baseColor: ThemeBackend.surface1
                            handleColor: ThemeBackend.crust
                            handleOffColor: ThemeBackend.text
                            onToggled: function(c) {
                                osdTabRoot.updateOsdSetting("showNumLock", c);
                            }
                        }
                    }
                }

                SettingsBlob {
                    Layout.fillWidth: true
                    Layout.preferredWidth: 1
                    Layout.alignment: Qt.AlignTop
                    baseColor: osdTabRoot.isVertical ? Qt.alpha(ThemeBackend.surface0, 0.18) : Qt.alpha(ThemeBackend.surface0, 0.4)

                    SettingsRow {
                        rootObj: osdTabRoot.rootObj
                        settingId: "osd_airplane"
                        searchKeywords: "osd airplane flight mode rfkill wifi wireless indicator popup"
                        icon: "󰀝"
                        title: I18n.t("guide.osd.airplane.title", "Show on airplane mode")
                        titlePixelSize: 12
                        wrapText: true
                        stackBelowWidth: 0
                        titleColor: osdTabRoot.isVertical ? ThemeBackend.subtext0 : ThemeBackend.text
                        opacity: osdTabRoot.isVertical ? 0.6 : 1.0
                        Behavior on opacity { NumberAnimation { duration: 250 } }
                        spacing: rootObj.s(10)

                        Text {
                            visible: osdTabRoot.isVertical
                            Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                            text: I18n.t("guide.common.unavailable", "Unavailable")
                            font.family: ThemeBackend.fontFamily
                            font.pixelSize: rootObj.s(11)
                            font.bold: true
                            color: ThemeBackend.subtext0
                        }

                        Toggle {
                            visible: !osdTabRoot.isVertical
                            enabled: !osdTabRoot.isVertical
                            Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                            checked: osdTabRoot.showAirplane
                            accentColor: ThemeBackend.mauve
                            baseColor: ThemeBackend.surface1
                            handleColor: ThemeBackend.crust
                            handleOffColor: ThemeBackend.text
                            onToggled: function(c) {
                                osdTabRoot.updateOsdSetting("showAirplane", c);
                            }
                        }
                    }
                }

                SettingsBlob {
                    Layout.fillWidth: true
                    Layout.preferredWidth: 1
                    Layout.alignment: Qt.AlignTop
                    baseColor: osdTabRoot.isVertical ? Qt.alpha(ThemeBackend.surface0, 0.18) : Qt.alpha(ThemeBackend.surface0, 0.4)

                    SettingsRow {
                        rootObj: osdTabRoot.rootObj
                        settingId: "osd_keyboard_layout"
                        searchKeywords: "osd keyboard layout language switch input xkb indicator popup"
                        icon: "󰌌"
                        title: I18n.t("guide.osd.keyboard_layout.title", "Show on keyboard layout")
                        titlePixelSize: 12
                        wrapText: true
                        stackBelowWidth: 0
                        titleColor: osdTabRoot.isVertical ? ThemeBackend.subtext0 : ThemeBackend.text
                        opacity: osdTabRoot.isVertical ? 0.6 : 1.0
                        Behavior on opacity { NumberAnimation { duration: 250 } }
                        spacing: rootObj.s(10)

                        Text {
                            visible: osdTabRoot.isVertical
                            Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                            text: I18n.t("guide.common.unavailable", "Unavailable")
                            font.family: ThemeBackend.fontFamily
                            font.pixelSize: rootObj.s(11)
                            font.bold: true
                            color: ThemeBackend.subtext0
                        }

                        Toggle {
                            visible: !osdTabRoot.isVertical
                            enabled: !osdTabRoot.isVertical
                            Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                            checked: osdTabRoot.showKeyboardLayout
                            accentColor: ThemeBackend.mauve
                            baseColor: ThemeBackend.surface1
                            handleColor: ThemeBackend.crust
                            handleOffColor: ThemeBackend.text
                            onToggled: function(c) {
                                osdTabRoot.updateOsdSetting("showKeyboardLayout", c);
                            }
                        }
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                Layout.topMargin: rootObj.s(4)
                Layout.leftMargin: rootObj.s(4)
                Layout.rightMargin: rootObj.s(4)
                spacing: rootObj.s(12)

                Item { Layout.fillWidth: true }

                ClickButton {
                    Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                    implicitHeight: rootObj.s(36)
                    horizontalPadding: rootObj.s(16)
                    buttonText: I18n.t("guide.osd.test", "Test OSD")
                    buttonIcon: "󰕾"
                    iconFontSize: rootObj.s(16)
                    textFontSize: rootObj.s(12)
                    accentColor: ThemeBackend.mauve
                    textColor: ThemeBackend.crust
                    cornerRadius: ThemeBackend.borderRadius
                    onClicked: {
                        OsdController.show("volume");
                    }
                }
            }
        }
    }
