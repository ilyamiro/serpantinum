import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import "../../"
import "../../reusables"

Popup {
    id: issuePopup
    parent: rootObj ? rootObj : undefined
    x: parent && parent.width > 0 ? Math.max(0, Math.round((parent.width - width) / 2)) : 0
    y: parent && parent.height > 0 ? Math.max(0, Math.round((parent.height - height) / 2)) : 0
    modal: true
    dim: true
    width: rootObj ? Math.min(rootObj.width - rootObj.s(32), rootObj.s(520)) : 520
    padding: rootObj ? rootObj.s(20) : 20
    closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutsideParent

    property var rootObj
    property var app: null
    property int copiedIndex: -1

    readonly property var manualCodes: ["missing_config", "system_config", "read_only", "manual"]

    readonly property var entries: {
        let out = [];
        if (!app) return out;
        if (app.error !== "") {
            out.push({ text: I18n.t("guide.theme.apps.status.error", { detail: "" }), code: app.error, file: "" });
        }
        for (let i = 0; i < app.issues.length; i++) {
            let issue = app.issues[i];
            let manual = manualCodes.indexOf(issue.code) >= 0;
            out.push({
                text: I18n.t("guide.theme.apps.issue." + issue.code, { file: issue.display || issue.file, line: manual ? "" : issue.line }),
                code: manual ? issue.line : "",
                file: manual ? issue.file : ""
            });
        }
        return out;
    }

    function openFor(appData) {
        app = appData;
        copiedIndex = -1;
        open();
    }

    Connections {
        target: issuePopup.rootObj ? issuePopup.rootObj : null

        function onVisibleChanged() {
            if (issuePopup.rootObj && !issuePopup.rootObj.visible) issuePopup.close();
        }
    }

    Connections {
        target: AppTheming

        function onAppsChanged() {
            if (!issuePopup.app) return;
            let fresh = AppTheming.apps.find(a => a.id === issuePopup.app.id);
            if (!fresh || !fresh.enabled || (fresh.error === "" && fresh.issues.length === 0)) {
                issuePopup.close();
                return;
            }
            issuePopup.app = fresh;
        }
    }

    background: Rectangle {
        radius: ThemeBackend.clampedBorderRadius
        color: popupGlass.active ? "transparent" : ThemeBackend.base

        GlassFill {
            id: popupGlass
            anchors.fill: parent
            radius: parent.radius
            tintColor: ThemeBackend.base
            tintAmount: 0.25
        }
    }

    contentItem: ColumnLayout {
        spacing: rootObj ? rootObj.s(14) : 14

        RowLayout {
            Layout.fillWidth: true
            spacing: rootObj ? rootObj.s(10) : 10

            Text {
                text: "󰀦"
                color: ThemeBackend.red
                font.family: ThemeBackend.fontFamily
                font.pixelSize: rootObj ? rootObj.s(18) : 18
            }

            Text {
                text: issuePopup.app ? issuePopup.app.name : ""
                color: ThemeBackend.text
                font.family: ThemeBackend.fontFamily
                font.pixelSize: rootObj ? rootObj.s(16) : 16
                font.bold: true
                elide: Text.ElideRight
                Layout.fillWidth: true
            }

            CloseButton {
                size: rootObj ? rootObj.s(30) : 30
                cornerRadius: rootObj ? rootObj.s(8) : 8
                iconFontSize: rootObj ? rootObj.s(14) : 14
                onClicked: issuePopup.close()
            }
        }

        Repeater {
            model: issuePopup.entries

            delegate: ColumnLayout {
                id: entryCol
                required property var modelData
                required property int index
                Layout.fillWidth: true
                spacing: rootObj ? rootObj.s(8) : 8

                Text {
                    Layout.fillWidth: true
                    text: entryCol.modelData.text
                    textFormat: Text.PlainText
                    wrapMode: Text.Wrap
                    color: ThemeBackend.text
                    font.family: ThemeBackend.fontFamily
                    font.pixelSize: rootObj ? rootObj.s(12) : 12
                }

                Rectangle {
                    Layout.fillWidth: true
                    visible: entryCol.modelData.code !== ""
                    implicitHeight: codeRow.implicitHeight + (rootObj ? rootObj.s(16) : 16)
                    radius: ThemeBackend.borderRadius
                    color: Qt.alpha(ThemeBackend.surface0, 0.6)

                    RowLayout {
                        id: codeRow
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.leftMargin: rootObj ? rootObj.s(12) : 12
                        anchors.rightMargin: rootObj ? rootObj.s(8) : 8
                        spacing: rootObj ? rootObj.s(8) : 8

                        Text {
                            Layout.fillWidth: true
                            text: entryCol.modelData.code
                            textFormat: Text.PlainText
                            wrapMode: Text.WrapAnywhere
                            color: ThemeBackend.mauve
                            font.family: ThemeBackend.fontFamily
                            font.pixelSize: rootObj ? rootObj.s(11) : 11
                        }

                        IconButton {
                            visible: entryCol.modelData.file !== ""
                            size: rootObj ? rootObj.s(28) : 28
                            cornerRadius: rootObj ? rootObj.s(6) : 6
                            buttonIcon: "󰉋"
                            iconFontSize: rootObj ? rootObj.s(13) : 13
                            accentColor: ThemeBackend.surface1
                            textColor: ThemeBackend.text
                            onClicked: AppTheming.openFolder(entryCol.modelData.file.replace(/\/[^\/]*$/, ""))
                        }

                        IconButton {
                            size: rootObj ? rootObj.s(28) : 28
                            cornerRadius: rootObj ? rootObj.s(6) : 6
                            buttonIcon: issuePopup.copiedIndex === entryCol.index ? "󰄬" : "󰆏"
                            iconFontSize: rootObj ? rootObj.s(13) : 13
                            accentColor: ThemeBackend.surface1
                            textColor: issuePopup.copiedIndex === entryCol.index ? ThemeBackend.green : ThemeBackend.text
                            onClicked: {
                                Quickshell.execDetached(["wl-copy", "--", entryCol.modelData.code]);
                                issuePopup.copiedIndex = entryCol.index;
                            }
                        }
                    }
                }
            }
        }
    }
}
