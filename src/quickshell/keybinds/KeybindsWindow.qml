import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import "../"
import "../reusables"
import "KeybindsData.js" as KeybindsData

// Keybind cheatsheet, opened from the about tab or with `serpantinum msg toggle keybinds`.
// The binds are read from Hyprland each time it opens (`hyprctl binds -j`);
// see KeybindsData.js for how they are grouped and described.
Item {
    id: root
    visible: false
    focus: true

    function s(val) {
        return Scaler.s(val);
    }

    property real introContent: 0.0
    property var sections: []
    property bool loading: false
    property bool failed: false
    // Binds only get a section from serpantinum's descriptions; with none of them the config predates them.
    readonly property bool outdated: sections.length > 0 && sections.every(sec => sec.id === "other")

    function refresh() {
        loading = true;
        failed = false;
        bindsProc.running = true;
    }

    Timer {
        id: focusTimer
        interval: 50
        onTriggered: root.forceActiveFocus()
    }

    onVisibleChanged: {
        if (visible) {
            refresh();
            flick.contentY = 0;
            startupSequence.restart();
            focusTimer.restart();
        } else {
            startupSequence.stop();
            closeSequence.stop();
        }
    }

    property var exitCallback: null

    function startExit(onFinished) {
        startupSequence.stop();
        exitCallback = onFinished;
        closeSequence.restart();
    }

    NumberAnimation {
        id: startupSequence
        target: root
        property: "introContent"
        to: 1.0
        duration: 450
        easing.type: Easing.OutQuart
    }

    SequentialAnimation {
        id: closeSequence
        NumberAnimation {
            target: root
            property: "introContent"
            to: 0.0
            duration: 240
            easing.type: Easing.InQuart
        }
        ScriptAction {
            script: {
                if (root.exitCallback) {
                    let cb = root.exitCallback;
                    root.exitCallback = null;
                    cb();
                } else {
                    Quickshell.execDetached(["bash", Caching.serpantinumDir + "/scripts/qs_manager.sh", "close"]);
                }
            }
        }
    }

    Keys.onEscapePressed: (event) => {
        if (typeof masterWindow !== "undefined" && masterWindow.switchWidget) {
            masterWindow.switchWidget("hidden", "");
        } else {
            closeSequence.restart();
        }
        event.accepted = true;
    }

    Process {
        id: bindsProc
        command: ["hyprctl", "binds", "-j"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root.sections = KeybindsData.buildSections(this.text, key => I18n.t(key), I18n.t("guide.about.keybinds.no_description"));
                } catch (e) {
                    root.sections = [];
                    root.failed = true;
                }
                root.loading = false;
            }
        }
        onExited: (exitCode) => {
            if (exitCode !== 0) {
                root.failed = true;
                root.loading = false;
            }
        }
    }

    Rectangle {
        id: panel
        anchors.fill: parent
        color: Qt.alpha(ThemeBackend.base, ThemeBackend.elementOpacity)
        radius: ThemeBackend.borderRadius
        border.width: 0
        border.color: "transparent"
        clip: true
        opacity: root.introContent

        WallpaperBlur {
            z: -1
            anchors.fill: parent
            topLeftRadius: parent.topLeftRadius
            topRightRadius: parent.topRightRadius
            bottomLeftRadius: parent.bottomLeftRadius
            bottomRightRadius: parent.bottomRightRadius
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: root.s(20)
            spacing: root.s(14)
            opacity: root.introContent
            scale: 0.96 + 0.04 * root.introContent
            transform: Translate { y: root.s(24) * (1.0 - root.introContent) }

            RowLayout {
                Layout.fillWidth: true
                spacing: root.s(10)

                Text {
                    text: "󰌌"
                    color: ThemeBackend.mauve
                    font.family: ThemeBackend.fontFamily
                    font.pixelSize: root.s(20)
                }

                Text {
                    Layout.fillWidth: true
                    text: I18n.t("guide.about.keybinds.title")
                    color: ThemeBackend.text
                    font.family: ThemeBackend.fontFamily
                    font.pixelSize: root.s(17)
                    font.bold: true
                }

                IconButton {
                    size: root.s(30)
                    cornerRadius: root.s(8)
                    buttonIcon: "󰅖"
                    iconFontSize: root.s(14)
                    accentColor: ThemeBackend.surface0
                    textColor: ThemeBackend.text
                    onClicked: {
                        if (typeof masterWindow !== "undefined" && masterWindow.switchWidget) {
                            masterWindow.switchWidget("hidden", "");
                        } else {
                            closeSequence.restart();
                        }
                    }
                }
            }

            Text {
                Layout.fillWidth: true
                visible: root.loading || root.failed || root.outdated
                text: root.loading ? I18n.t("guide.about.keybinds.loading")
                    : (root.failed ? I18n.t("guide.about.keybinds.error") : I18n.t("guide.about.keybinds.outdated"))
                color: root.failed ? ThemeBackend.red : ThemeBackend.subtext0
                font.family: ThemeBackend.fontFamily
                font.pixelSize: root.s(12)
                wrapMode: Text.WordWrap
            }

            Flickable {
                id: flick
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                contentHeight: sectionsColumn.implicitHeight
                boundsBehavior: Flickable.StopAtBounds
                ScrollBar.vertical: ScrollBar {
                    id: scrollBar
                    policy: ScrollBar.AsNeeded
                }

                ColumnLayout {
                    id: sectionsColumn
                    // Leave room for the scroll bar so it doesn't cover the key caps.
                    width: flick.width - (flick.contentHeight > flick.height ? scrollBar.width + root.s(8) : 0)
                    spacing: root.s(16)

                    Repeater {
                        model: root.sections

                        ColumnLayout {
                            id: sectionItem
                            required property var modelData
                            required property int index
                            Layout.fillWidth: true
                            spacing: root.s(6)

                            // Sections come in one after another while the window opens.
                            readonly property real reveal: Math.max(0.0, Math.min(1.0, root.introContent * 2.2 - index * 0.18))
                            opacity: reveal
                            transform: Translate { y: root.s(12) * (1.0 - sectionItem.reveal) }

                            Text {
                                text: I18n.t("keybinds.groups." + sectionItem.modelData.id)
                                color: ThemeBackend.mauve
                                font.family: ThemeBackend.fontFamily
                                font.pixelSize: root.s(13)
                                font.bold: true
                            }

                            Repeater {
                                model: sectionItem.modelData.rows

                                Rectangle {
                                    id: bindRow
                                    required property var modelData
                                    Layout.fillWidth: true
                                    implicitHeight: rowLayout.implicitHeight + root.s(16)
                                    radius: ThemeBackend.borderRadius
                                    color: rowGlass.active ? "transparent" : (rowHover.hovered ? Qt.alpha(ThemeBackend.surface0, 0.7) : Qt.alpha(ThemeBackend.surface0, 0.4))
                                    Behavior on color { ColorAnimation { duration: 150 } }

                                    HoverHandler { id: rowHover }

                                    GlassFill {
                                        id: rowGlass
                                        anchors.fill: parent
                                        radius: parent.radius
                                        tintColor: ThemeBackend.surface0
                                        tintAmount: 0.3
                                        press: rowHover.hovered ? 0.25 : 0
                                        Behavior on press { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
                                    }

                                    RowLayout {
                                        id: rowLayout
                                        anchors.left: parent.left
                                        anchors.right: parent.right
                                        anchors.verticalCenter: parent.verticalCenter
                                        anchors.leftMargin: root.s(14)
                                        anchors.rightMargin: root.s(10)
                                        spacing: root.s(12)

                                        Text {
                                            Layout.fillWidth: true
                                            text: bindRow.modelData.label
                                            color: ThemeBackend.text
                                            font.family: ThemeBackend.fontFamily
                                            font.pixelSize: root.s(12)
                                            elide: Text.ElideRight
                                        }

                                        Row {
                                            spacing: root.s(4)

                                            Repeater {
                                                model: bindRow.modelData.combo

                                                Rectangle {
                                                    required property string modelData
                                                    width: keyText.implicitWidth + root.s(14)
                                                    height: keyText.implicitHeight + root.s(8)
                                                    radius: root.s(6)
                                                    color: ThemeBackend.surface0
                                                    border.color: ThemeBackend.surface1
                                                    border.width: 1

                                                    Text {
                                                        id: keyText
                                                        anchors.centerIn: parent
                                                        text: parent.modelData
                                                        color: ThemeBackend.text
                                                        font.family: ThemeBackend.fontFamily
                                                        font.pixelSize: root.s(11)
                                                        font.bold: true
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
            }
        }
    }
}
