import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import "../"
import "../reusables"

Item {
    id: osdTabRoot
    required property var rootObj
    required property int tabIndex

    anchors.fill: parent
    visible: rootObj.currentTab === tabIndex
    opacity: visible ? 1.0 : 0.0
    property real slideY: visible ? 0 : rootObj.s(10)

    Behavior on slideY { NumberAnimation { duration: 250; easing.type: Easing.OutQuart } }
    transform: Translate { y: slideY }
    Behavior on opacity { NumberAnimation { duration: 250 } }

    property bool selectorOpen: false
    property bool gridEnabled: false
    property bool showBarBox: true

    property var defaultOsdSettings: ({
        "horizontalPosition": 50,
        "verticalPosition": 90,
        "orientation": "horizontal",
        "showCapsLock": true,
        "showNumLock": true,
        "showAirplane": true,
        "attachToBar": true
    })

    property var osdSettings: {
        let s = (typeof Config !== "undefined" && Config.rawSettings) ? Config.rawSettings["osd"] : undefined;
        if (s !== undefined && s !== null) return s;
        if (typeof Config !== "undefined" && typeof Config.getSetting === "function") {
            return Config.getSetting("osd", osdTabRoot.defaultOsdSettings);
        }
        return osdTabRoot.defaultOsdSettings;
    }

    property int horizontalPosition: osdSettings && osdSettings.horizontalPosition !== undefined ? osdSettings.horizontalPosition : 50
    property int verticalPosition: osdSettings && osdSettings.verticalPosition !== undefined ? osdSettings.verticalPosition : 90
    property string orientation: osdSettings && osdSettings.orientation !== undefined ? osdSettings.orientation : "horizontal"
    readonly property bool isVertical: orientation === "vertical"
    property bool showCapsLock: osdSettings && osdSettings.showCapsLock !== undefined ? osdSettings.showCapsLock : true
    property bool showNumLock: osdSettings && osdSettings.showNumLock !== undefined ? osdSettings.showNumLock : true
    property bool showAirplane: osdSettings && osdSettings.showAirplane !== undefined ? osdSettings.showAirplane : true
    property bool attachToBar: osdSettings && osdSettings.attachToBar !== undefined ? osdSettings.attachToBar : true

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
        osdTabRoot.horizontalPosition = h;
        osdTabRoot.verticalPosition = v;
        if (screenSelector) {
            screenSelector.horizontalPosition = h;
            screenSelector.verticalPosition = v;
        }
        debounceTimer.restart();
    }

    function setPosFromIndex(index) {
        if (index === 0) applyPosition(50, 90);
        else if (index === 1) applyPosition(10, 90);
        else if (index === 2) applyPosition(90, 90);
        else if (index === 3) applyPosition(50, 10);
        else if (index === 4) applyPosition(10, 10);
        else if (index === 5) applyPosition(90, 10);
    }

    function syncSettings() {
        let s = (typeof Config !== "undefined" && typeof Config.getSetting === "function")
            ? Config.getSetting("osd", osdTabRoot.defaultOsdSettings)
            : osdTabRoot.defaultOsdSettings;
        osdTabRoot.osdSettings = s;
        osdTabRoot.horizontalPosition = s.horizontalPosition !== undefined ? s.horizontalPosition : 50;
        osdTabRoot.verticalPosition = s.verticalPosition !== undefined ? s.verticalPosition : 90;
        osdTabRoot.orientation = s.orientation !== undefined ? s.orientation : "horizontal";
        if (screenSelector) {
            screenSelector.horizontalPosition = osdTabRoot.horizontalPosition;
            screenSelector.verticalPosition = osdTabRoot.verticalPosition;
        }
        osdTabRoot.showCapsLock = s.showCapsLock !== undefined ? s.showCapsLock : true;
        osdTabRoot.showNumLock = s.showNumLock !== undefined ? s.showNumLock : true;
        osdTabRoot.showAirplane = s.showAirplane !== undefined ? s.showAirplane : true;
        osdTabRoot.attachToBar = s.attachToBar !== undefined ? s.attachToBar : true;
    }

    function updateOsdSetting(key, value) {
        let current = JSON.parse(JSON.stringify(Config.getSetting("osd", defaultOsdSettings) || defaultOsdSettings));
        current[key] = value;
        Config.setSetting("osd", current);
        osdTabRoot.osdSettings = current;
    }

    Timer {
        id: debounceTimer
        interval: 100
        repeat: false
        onTriggered: {
            let current = JSON.parse(JSON.stringify(Config.getSetting("osd", defaultOsdSettings) || defaultOsdSettings));
            current.horizontalPosition = osdTabRoot.horizontalPosition;
            current.verticalPosition = osdTabRoot.verticalPosition;
            Config.setSetting("osd", current);
            osdTabRoot.osdSettings = current;
        }
    }

    onVisibleChanged: {
        if (visible) {
            syncSettings();
        } else {
            selectorOpen = false;
            if (posDropdown.isOpen) posDropdown.closePopup();
        }
    }

    Component.onCompleted: {
        syncSettings();
    }

    Connections {
        target: typeof Config !== "undefined" ? Config : null
        function onSettingsLoaded() {
            osdTabRoot.syncSettings();
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
                implicitHeight: posCol.implicitHeight + rootObj.s(24)
                radius: ThemeBackend.borderRadius
                color: Qt.alpha(ThemeBackend.surface0, 0.4)
                border.width: 0

                ColumnLayout {
                    id: posCol
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.leftMargin: rootObj.s(14)
                    anchors.rightMargin: rootObj.s(14)
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: rootObj.s(12)

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: rootObj.s(10)

                        ColumnLayout {
                            spacing: rootObj.s(2)

                            Text {
                                text: I18n.t("guide.osd.position.title", "Screen position")
                                font.family: ThemeBackend.fontFamily
                                font.pixelSize: rootObj.s(13)
                                font.bold: true
                                color: ThemeBackend.text
                            }

                            Text {
                                text: I18n.t("guide.osd.position.desc", "Select a preset position or drag on screen")
                                font.family: ThemeBackend.fontFamily
                                font.pixelSize: rootObj.s(11)
                                color: ThemeBackend.subtext0
                            }
                        }

                        Item {
                            Layout.fillWidth: true
                        }

                        RowLayout {
                            spacing: rootObj.s(8)
                            Layout.alignment: Qt.AlignRight | Qt.AlignVCenter

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
                                color: ThemeBackend.surface0
                                border.width: 1
                                border.color: Qt.alpha(ThemeBackend.surface2, 0.6)
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
                                    I18n.t("guide.osd.position.bottom_center", "Bottom Center"),
                                    I18n.t("guide.osd.position.bottom_left", "Bottom Left"),
                                    I18n.t("guide.osd.position.bottom_right", "Bottom Right"),
                                    I18n.t("guide.osd.position.top_center", "Top Center"),
                                    I18n.t("guide.osd.position.top_left", "Top Left"),
                                    I18n.t("guide.osd.position.top_right", "Top Right")
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
                        }
                    }

                    Item {
                        id: selectorWrapper
                        Layout.fillWidth: true
                        property bool isOpen: osdTabRoot.selectorOpen
                        clip: true
                        visible: implicitHeight > 0
                        opacity: isOpen ? 1.0 : 0.0
                        implicitHeight: isOpen ? selectorInnerCol.implicitHeight : 0

                        Behavior on opacity { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
                        Behavior on implicitHeight { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }

                        ColumnLayout {
                            id: selectorInnerCol
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.top: parent.top
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
                                    accentColor: ThemeBackend.surface0
                                    textColor: "#ffffff"
                                    buttonText: "X: " + osdTabRoot.horizontalPosition + "%  Y: " + osdTabRoot.verticalPosition + "%"
                                }

                                IconButton {
                                    size: rootObj.s(26)
                                    cornerRadius: rootObj.s(6)
                                    buttonIcon: "󰕰"
                                    iconFontSize: rootObj.s(13)
                                    accentColor: osdTabRoot.gridEnabled ? ThemeBackend.mauve : ThemeBackend.surface0
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
                                    accentColor: ThemeBackend.surface0
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
                                    baseColor: ThemeBackend.surface0
                                    textColor: ThemeBackend.text
                                    activeTextColor: ThemeBackend.crust
                                    onValueChanged: function(index, value) {
                                        let orient = index === 1 ? "vertical" : "horizontal";
                                        osdTabRoot.orientation = orient;
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
                                    osdTabRoot.horizontalPosition = hPos;
                                    osdTabRoot.verticalPosition = vPos;
                                    posDropdown.currentIndex = -1;
                                    debounceTimer.restart();
                                }

                                onDragFinished: {
                                    debounceTimer.stop();
                                    posDropdown.currentIndex = -1;
                                    let current = JSON.parse(JSON.stringify(Config.getSetting("osd", defaultOsdSettings) || defaultOsdSettings));
                                    current.horizontalPosition = osdTabRoot.horizontalPosition;
                                    current.verticalPosition = osdTabRoot.verticalPosition;
                                    Config.setSetting("osd", current);
                                    osdTabRoot.osdSettings = current;
                                }

                                Rectangle {
                                    anchors.fill: parent
                                    radius: rootObj.s(11)
                                    color: ThemeBackend.base
                                    border.width: 1
                                    border.color: ThemeBackend.surface0
                                    clip: true

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
                                            color: ThemeBackend.surface1

                                            Text {
                                                anchors.centerIn: parent
                                                text: "󰕾"
                                                font.family: "Iosevka Nerd Font"
                                                font.pixelSize: rootObj.s(18)
                                                color: Qt.lighter(ThemeBackend.sapphire, 1.5)
                                            }
                                        }

                                        Item {
                                            Layout.fillWidth: true
                                            Layout.fillHeight: true

                                            Rectangle {
                                                id: trackBar
                                                anchors.left: parent.left
                                                anchors.right: parent.right
                                                anchors.verticalCenter: parent.verticalCenter
                                                height: rootObj.s(9)
                                                radius: height / 2
                                                color: ThemeBackend.surface1

                                                Rectangle {
                                                    anchors.left: parent.left
                                                    anchors.top: parent.top
                                                    anchors.bottom: parent.bottom
                                                    width: parent.width * 0.65
                                                    radius: parent.radius
                                                    color: Qt.lighter(ThemeBackend.sapphire, 1.5)
                                                }

                                                Rectangle {
                                                    x: (parent.width * 0.65) - (width / 2)
                                                    anchors.verticalCenter: parent.verticalCenter
                                                    width: rootObj.s(16)
                                                    height: rootObj.s(16)
                                                    radius: width / 2
                                                    color: Qt.lighter(ThemeBackend.sapphire, 1.3)
                                                    border.width: 1
                                                    border.color: Qt.rgba(0, 0, 0, 0.25)
                                                }
                                            }
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
                                            color: ThemeBackend.surface1

                                            Text {
                                                anchors.centerIn: parent
                                                text: "󰕾"
                                                font.family: "Iosevka Nerd Font"
                                                font.pixelSize: rootObj.s(18)
                                                color: Qt.lighter(ThemeBackend.sapphire, 1.5)
                                            }
                                        }

                                        Item {
                                            Layout.fillWidth: true
                                            Layout.fillHeight: true

                                            Rectangle {
                                                anchors.top: parent.top
                                                anchors.bottom: parent.bottom
                                                anchors.horizontalCenter: parent.horizontalCenter
                                                width: rootObj.s(9)
                                                radius: width / 2
                                                color: ThemeBackend.surface1

                                                Rectangle {
                                                    anchors.left: parent.left
                                                    anchors.right: parent.right
                                                    anchors.bottom: parent.bottom
                                                    height: parent.height * 0.65
                                                    radius: parent.radius
                                                    color: Qt.lighter(ThemeBackend.sapphire, 1.5)
                                                }

                                                Rectangle {
                                                    y: parent.height - (parent.height * 0.65) - (height / 2)
                                                    anchors.horizontalCenter: parent.horizontalCenter
                                                    width: rootObj.s(16)
                                                    height: rootObj.s(16)
                                                    radius: width / 2
                                                    color: Qt.lighter(ThemeBackend.sapphire, 1.3)
                                                    border.width: 1
                                                    border.color: Qt.rgba(0, 0, 0, 0.25)
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

            RowLayout {
                Layout.fillWidth: true
                spacing: rootObj.s(10)

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredWidth: 1
                    implicitHeight: capsRow.implicitHeight + rootObj.s(24)
                    radius: ThemeBackend.borderRadius
                    color: osdTabRoot.isVertical ? Qt.alpha(ThemeBackend.surface0, 0.18) : Qt.alpha(ThemeBackend.surface0, 0.4)
                    border.width: 0
                    opacity: osdTabRoot.isVertical ? 0.6 : 1.0

                    Behavior on color { ColorAnimation { duration: 250 } }
                    Behavior on opacity { NumberAnimation { duration: 250 } }

                    RowLayout {
                        id: capsRow
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.leftMargin: rootObj.s(14)
                        anchors.rightMargin: rootObj.s(14)
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: rootObj.s(8)

                        Text {
                            Layout.fillWidth: true
                            text: I18n.t("guide.osd.capslock.title", "Show on Caps Lock")
                            font.family: ThemeBackend.fontFamily
                            font.pixelSize: rootObj.s(12)
                            color: osdTabRoot.isVertical ? ThemeBackend.subtext0 : ThemeBackend.text
                            wrapMode: Text.WordWrap

                            Behavior on color { ColorAnimation { duration: 250 } }
                        }

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
                                osdTabRoot.showCapsLock = c;
                                osdTabRoot.updateOsdSetting("showCapsLock", c);
                            }
                        }
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredWidth: 1
                    implicitHeight: numRow.implicitHeight + rootObj.s(24)
                    radius: ThemeBackend.borderRadius
                    color: osdTabRoot.isVertical ? Qt.alpha(ThemeBackend.surface0, 0.18) : Qt.alpha(ThemeBackend.surface0, 0.4)
                    border.width: 0
                    opacity: osdTabRoot.isVertical ? 0.6 : 1.0

                    Behavior on color { ColorAnimation { duration: 250 } }
                    Behavior on opacity { NumberAnimation { duration: 250 } }

                    RowLayout {
                        id: numRow
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.leftMargin: rootObj.s(14)
                        anchors.rightMargin: rootObj.s(14)
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: rootObj.s(8)

                        Text {
                            Layout.fillWidth: true
                            text: I18n.t("guide.osd.numlock.title", "Show on Num Lock")
                            font.family: ThemeBackend.fontFamily
                            font.pixelSize: rootObj.s(12)
                            color: osdTabRoot.isVertical ? ThemeBackend.subtext0 : ThemeBackend.text
                            wrapMode: Text.WordWrap

                            Behavior on color { ColorAnimation { duration: 250 } }
                        }

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
                                osdTabRoot.showNumLock = c;
                                osdTabRoot.updateOsdSetting("showNumLock", c);
                            }
                        }
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredWidth: 1
                    implicitHeight: airRow.implicitHeight + rootObj.s(24)
                    radius: ThemeBackend.borderRadius
                    color: osdTabRoot.isVertical ? Qt.alpha(ThemeBackend.surface0, 0.18) : Qt.alpha(ThemeBackend.surface0, 0.4)
                    border.width: 0
                    opacity: osdTabRoot.isVertical ? 0.6 : 1.0

                    Behavior on color { ColorAnimation { duration: 250 } }
                    Behavior on opacity { NumberAnimation { duration: 250 } }

                    RowLayout {
                        id: airRow
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.leftMargin: rootObj.s(14)
                        anchors.rightMargin: rootObj.s(14)
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: rootObj.s(8)

                        Text {
                            Layout.fillWidth: true
                            text: I18n.t("guide.osd.airplane.title", "Show on Airplane Mode")
                            font.family: ThemeBackend.fontFamily
                            font.pixelSize: rootObj.s(12)
                            color: osdTabRoot.isVertical ? ThemeBackend.subtext0 : ThemeBackend.text
                            wrapMode: Text.WordWrap

                            Behavior on color { ColorAnimation { duration: 250 } }
                        }

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
                                osdTabRoot.showAirplane = c;
                                osdTabRoot.updateOsdSetting("showAirplane", c);
                            }
                        }
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                implicitHeight: attachRow.implicitHeight + rootObj.s(24)
                radius: ThemeBackend.borderRadius
                color: Qt.alpha(ThemeBackend.surface0, 0.4)
                border.width: 0

                RowLayout {
                    id: attachRow
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.leftMargin: rootObj.s(14)
                    anchors.rightMargin: rootObj.s(14)
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: rootObj.s(16)

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: rootObj.s(2)
                        Text {
                            text: I18n.t("guide.osd.attach_bar.title", "Attach to the bar in solid/fill style")
                            font.family: ThemeBackend.fontFamily
                            font.pixelSize: rootObj.s(13)
                            color: ThemeBackend.text
                        }
                        Text {
                            text: I18n.t("guide.osd.attach_bar.desc", "Snap OSD popups to the status bar in solid or fill mode. When disabled, the OSD always stays in the configured position.")
                            font.family: ThemeBackend.fontFamily
                            font.pixelSize: rootObj.s(11)
                            color: ThemeBackend.subtext0
                        }
                    }

                    Toggle {
                        Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                        checked: osdTabRoot.attachToBar
                        accentColor: ThemeBackend.mauve
                        baseColor: ThemeBackend.surface1
                        handleColor: ThemeBackend.crust
                        handleOffColor: ThemeBackend.text
                        onToggled: function(c) {
                            osdTabRoot.attachToBar = c;
                            osdTabRoot.updateOsdSetting("attachToBar", c);
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
                        if (typeof OsdController !== "undefined") {
                            OsdController.show("volume");
                        }
                    }
                }
            }
        }
    }
}
