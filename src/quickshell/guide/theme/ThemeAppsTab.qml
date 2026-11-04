import QtQuick
import QtQuick.Layouts
import Quickshell
import "../"
import "../../"
import "../../reusables"
import "../../reusables/guide"

GuideTab {
    id: appsTabRoot
    subTabIndex: 1

    property bool showCustomForm: false
    property string formName: ""
    property string formOutput: ""
    property string formConfig: ""
    property string formLine: ""

    readonly property var themedApps: AppTheming.apps.filter(a => a.installed && a.enabled).sort((a, b) => a.name.localeCompare(b.name))
    readonly property var availableApps: AppTheming.apps.filter(a => a.installed && !a.enabled).sort((a, b) => a.name.localeCompare(b.name))
    readonly property var addOptions: availableApps.map(a => a.name).concat([I18n.t("guide.theme.apps.add.custom")])

    function noteFor(app) {
        if (app.error !== "") return I18n.t("guide.theme.apps.status.error", { detail: app.error });
        if (app.issues.length > 0) {
            let issue = app.issues[0];
            return I18n.t("guide.theme.apps.issue." + issue.code, { file: issue.file, line: issue.line });
        }
        if (app.hint !== "") return I18n.t("guide.theme.apps.hint." + app.hint);
        return "";
    }

    function resetForm() {
        formName = "";
        formOutput = "";
        formConfig = "";
        formLine = "";
        AppTheming.createError = "";
    }

    function submitForm() {
        AppTheming.createCustom(formName.trim(), formOutput.trim(), formConfig.trim(), formLine.trim());
    }

    Connections {
        target: AppTheming
        function onCreated(appId) {
            appsTabRoot.showCustomForm = false;
            appsTabRoot.resetForm();
        }
    }

    onVisibleChanged: {
        if (visible) AppTheming.refresh();
    }

    Component.onCompleted: AppTheming.refresh()

    Flickable {
        anchors.fill: parent
        anchors.topMargin: rootObj.s(8)
        anchors.leftMargin: rootObj.s(8)
        anchors.rightMargin: rootObj.s(8)
        anchors.bottomMargin: rootObj.s(4)
        contentHeight: appsCol.implicitHeight
        contentWidth: width
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        ColumnLayout {
            id: appsCol
            width: parent.width
            spacing: rootObj.s(6)

            Rectangle {
                id: appsCard
                Layout.fillWidth: true
                clip: true
                radius: ThemeBackend.borderRadius
                color: appsCardGlass.active ? "transparent" : Qt.alpha(ThemeBackend.surface0, 0.4)
                implicitHeight: cardLayout.implicitHeight + rootObj.s(12)

                GlassFill {
                    id: appsCardGlass
                    anchors.fill: parent
                    radius: parent.radius
                    tintColor: Qt.alpha(ThemeBackend.surface0, 0.4)
                    tintAmount: 0.25
                }

                ColumnLayout {
                    id: cardLayout
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    spacing: 0

                    SettingsRow {
                        rootObj: appsTabRoot.rootObj
                        settingId: "app_theming"
                        searchKeywords: "app theming apps gtk qt kitty cava terminal editor colors palette matugen templates custom"
                        icon: "󰏗"
                        title: I18n.t("guide.theme.apps.list.title")
                        description: I18n.t("guide.theme.apps.list.desc")
                        baseColor: "transparent"
                        hoverColor: "transparent"
                        borderWidth: 0
                        color: highlightFlash > 0.001 ? Qt.rgba(ThemeBackend.mauve.r, ThemeBackend.mauve.g, ThemeBackend.mauve.b, highlightFlash * 0.18) : "transparent"

                        titleBadge: Component {
                            Text {
                                text: "(" + appsTabRoot.themedApps.length + ")"
                                font.family: ThemeBackend.fontFamily
                                font.pixelSize: rootObj.s(11)
                                color: ThemeBackend.subtext0
                            }
                        }

                        IconButton {
                            size: rootObj.s(32)
                            Layout.preferredWidth: rootObj.s(32)
                            Layout.preferredHeight: rootObj.s(32)
                            Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                            cornerRadius: ThemeBackend.borderRadius
                            buttonIcon: "󰉋"
                            iconFontSize: rootObj.s(16)
                            accentColor: ThemeBackend.surface0
                            textColor: ThemeBackend.text
                            onClicked: AppTheming.openFolder("")
                        }

                        Dropdown {
                            id: addDropdown
                            Layout.preferredWidth: rootObj.s(200)
                            Layout.preferredHeight: rootObj.s(32)
                            Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                            options: appsTabRoot.addOptions
                            currentIndex: -1
                            placeholderText: I18n.t("guide.theme.apps.add.title")
                            fontFamily: ThemeBackend.fontFamily
                            accentColor: ThemeBackend.mauve
                            baseColor: ThemeBackend.surface0
                            hoverColor: ThemeBackend.surface1
                            dropdownColor: ThemeBackend.surface0
                            borderColor: Qt.alpha(ThemeBackend.surface2, 0.6)
                            textColor: ThemeBackend.text
                            activeTextColor: ThemeBackend.crust
                            cornerRadius: ThemeBackend.borderRadius
                            fontPixelSize: rootObj.s(11)
                            onSelected: function(index, value) {
                                if (index >= 0 && index < appsTabRoot.availableApps.length) {
                                    AppTheming.setEnabled(appsTabRoot.availableApps[index].id, true);
                                } else if (index === appsTabRoot.availableApps.length) {
                                    appsTabRoot.resetForm();
                                    appsTabRoot.showCustomForm = true;
                                }
                                addDropdown.currentIndex = -1;
                            }
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        height: 1
                        color: Qt.alpha(ThemeBackend.surface1, 0.3)
                    }

                    Grid {
                        id: appsGrid
                        Layout.fillWidth: true
                        Layout.leftMargin: rootObj.s(12)
                        Layout.rightMargin: rootObj.s(12)
                        Layout.topMargin: rootObj.s(12)
                        Layout.bottomMargin: rootObj.s(4)
                        columns: 3
                        rowSpacing: rootObj.s(8)
                        columnSpacing: rootObj.s(8)
                        visible: appsTabRoot.themedApps.length > 0

                        readonly property real colWidth: Math.max(0, ((cardLayout.width - rootObj.s(24)) - columnSpacing * 2) / 3)

                        Repeater {
                            model: appsTabRoot.themedApps

                            delegate: Rectangle {
                                id: appTile
                                required property var modelData
                                required property int index
                                readonly property bool problem: modelData.error !== "" || modelData.issues.length > 0

                                width: appsGrid.colWidth
                                height: rootObj.s(48)
                                radius: ThemeBackend.borderRadius
                                color: appTileGlass.active ? "transparent" : Qt.alpha(ThemeBackend.surface1, 0.3)

                                GlassFill {
                                    id: appTileGlass
                                    anchors.fill: parent
                                    radius: parent.radius
                                    tintColor: Qt.alpha(ThemeBackend.surface1, 0.3)
                                    tintAmount: 0.25
                                }

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: rootObj.s(8)
                                    anchors.rightMargin: rootObj.s(8)
                                    spacing: rootObj.s(8)

                                    IconButton {
                                        size: rootObj.s(32)
                                        cornerRadius: ThemeBackend.borderRadius
                                        buttonIcon: appTile.problem ? "󰀦" : (appTile.modelData.icon !== "" ? appTile.modelData.icon : "󰏘")
                                        iconFontSize: rootObj.s(16)
                                        accentColor: ThemeBackend.surface1
                                        textColor: appTile.problem ? ThemeBackend.red : ThemeBackend.mauve
                                        Layout.alignment: Qt.AlignVCenter
                                        enabled: false
                                    }

                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        Layout.alignment: Qt.AlignVCenter
                                        spacing: rootObj.s(1)

                                        Text {
                                            text: appTile.modelData.name
                                            font.family: ThemeBackend.fontFamily
                                            font.pixelSize: rootObj.s(12)
                                            font.bold: true
                                            color: ThemeBackend.text
                                            elide: Text.ElideRight
                                            Layout.fillWidth: true
                                        }

                                        Text {
                                            text: appTile.problem ? I18n.t("guide.theme.apps.needs_attention") : (appTile.modelData.outputs.length > 0 ? appTile.modelData.outputs[0] : "")
                                            font.family: ThemeBackend.fontFamily
                                            font.pixelSize: rootObj.s(10)
                                            color: appTile.problem ? ThemeBackend.red : ThemeBackend.subtext0
                                            elide: Text.ElideMiddle
                                            Layout.fillWidth: true
                                        }
                                    }

                                    IconButton {
                                        visible: appTile.modelData.custom && appTile.modelData.builtin
                                        size: rootObj.s(28)
                                        cornerRadius: Math.min(ThemeBackend.borderRadius, rootObj.s(8))
                                        buttonIcon: "󰦛"
                                        iconFontSize: rootObj.s(14)
                                        accentColor: ThemeBackend.surface1
                                        textColor: ThemeBackend.text
                                        Layout.alignment: Qt.AlignVCenter
                                        onClicked: AppTheming.reset(appTile.modelData.id)
                                    }

                                    IconButton {
                                        size: rootObj.s(28)
                                        cornerRadius: Math.min(ThemeBackend.borderRadius, rootObj.s(8))
                                        buttonIcon: "󰏫"
                                        iconFontSize: rootObj.s(14)
                                        accentColor: ThemeBackend.surface1
                                        textColor: ThemeBackend.text
                                        Layout.alignment: Qt.AlignVCenter
                                        onClicked: {
                                            if (appTile.modelData.custom) AppTheming.openFolder(appTile.modelData.dir);
                                            else AppTheming.customize(appTile.modelData.id);
                                        }
                                    }

                                    DeleteButton {
                                        size: rootObj.s(28)
                                        cornerRadius: Math.min(ThemeBackend.borderRadius, rootObj.s(8))
                                        iconFontSize: rootObj.s(14)
                                        Layout.alignment: Qt.AlignVCenter
                                        onClicked: AppTheming.setEnabled(appTile.modelData.id, false)
                                    }
                                }
                            }
                        }
                    }

                    Item {
                        Layout.fillWidth: true
                        Layout.preferredHeight: rootObj.s(40)
                        Layout.margins: rootObj.s(12)
                        visible: appsTabRoot.themedApps.length === 0

                        Text {
                            anchors.centerIn: parent
                            text: AppTheming.loaded ? I18n.t("guide.theme.apps.empty") : I18n.t("guide.theme.apps.loading")
                            font.family: ThemeBackend.fontFamily
                            font.pixelSize: rootObj.s(12)
                            color: ThemeBackend.subtext0
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        Layout.leftMargin: rootObj.s(14)
                        Layout.rightMargin: rootObj.s(14)
                        Layout.topMargin: rootObj.s(8)
                        Layout.bottomMargin: rootObj.s(6)
                        spacing: rootObj.s(6)
                        visible: noteRepeater.count > 0

                        Repeater {
                            id: noteRepeater
                            model: appsTabRoot.themedApps.filter(a => appsTabRoot.noteFor(a) !== "")

                            delegate: Text {
                                required property var modelData
                                readonly property bool problem: modelData.error !== "" || modelData.issues.length > 0
                                Layout.fillWidth: true
                                wrapMode: Text.Wrap
                                textFormat: Text.PlainText
                                font.family: ThemeBackend.fontFamily
                                font.pixelSize: rootObj.s(11)
                                color: problem ? ThemeBackend.red : ThemeBackend.subtext0
                                text: modelData.name + ": " + appsTabRoot.noteFor(modelData)
                            }
                        }
                    }
                }
            }

            SettingsBlob {
                visible: appsTabRoot.showCustomForm

                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.margins: rootObj.s(14)
                    spacing: rootObj.s(8)

                    Text {
                        Layout.fillWidth: true
                        color: ThemeBackend.text
                        font.family: ThemeBackend.fontFamily
                        font.pixelSize: rootObj.s(13)
                        text: I18n.t("guide.theme.apps.form.title")
                    }

                    Text {
                        Layout.fillWidth: true
                        color: ThemeBackend.subtext0
                        font.family: ThemeBackend.fontFamily
                        font.pixelSize: rootObj.s(11)
                        wrapMode: Text.WordWrap
                        text: I18n.t("guide.theme.apps.form.desc")
                    }

                    Repeater {
                        model: [
                            { key: "name", label: I18n.t("guide.theme.apps.form.name"), hint: I18n.t("guide.theme.apps.form.name_hint") },
                            { key: "output", label: I18n.t("guide.theme.apps.form.output"), hint: "~/.config/myapp/colors.conf" },
                            { key: "config", label: I18n.t("guide.theme.apps.form.config"), hint: "~/.config/myapp/config" },
                            { key: "line", label: I18n.t("guide.theme.apps.form.line"), hint: "include colors.conf" }
                        ]

                        delegate: RowLayout {
                            id: fieldRow
                            required property var modelData
                            Layout.fillWidth: true
                            spacing: rootObj.s(10)

                            Text {
                                Layout.preferredWidth: rootObj.s(150)
                                color: ThemeBackend.subtext0
                                font.family: ThemeBackend.fontFamily
                                font.pixelSize: rootObj.s(11)
                                elide: Text.ElideRight
                                text: fieldRow.modelData.label
                            }

                            Input {
                                Layout.fillWidth: true
                                implicitHeight: rootObj.s(32)
                                text: fieldRow.modelData.key === "name" ? appsTabRoot.formName
                                    : fieldRow.modelData.key === "output" ? appsTabRoot.formOutput
                                    : fieldRow.modelData.key === "config" ? appsTabRoot.formConfig
                                    : appsTabRoot.formLine
                                placeholderText: fieldRow.modelData.hint
                                baseColor: ThemeBackend.surface0
                                accentColor: ThemeBackend.mauve
                                textColor: ThemeBackend.text
                                subTextColor: ThemeBackend.subtext0
                                borderColor: Qt.alpha(ThemeBackend.surface2, 0.6)
                                cornerRadius: ThemeBackend.borderRadius
                                fontPixelSize: rootObj.s(11)
                                onTextEdited: function(newText) {
                                    if (fieldRow.modelData.key === "name") appsTabRoot.formName = newText;
                                    else if (fieldRow.modelData.key === "output") appsTabRoot.formOutput = newText;
                                    else if (fieldRow.modelData.key === "config") appsTabRoot.formConfig = newText;
                                    else appsTabRoot.formLine = newText;
                                }
                                onAccepted: appsTabRoot.submitForm()
                            }
                        }
                    }

                    Text {
                        Layout.fillWidth: true
                        visible: AppTheming.createError !== ""
                        color: ThemeBackend.red
                        font.family: ThemeBackend.fontFamily
                        font.pixelSize: rootObj.s(11)
                        wrapMode: Text.WordWrap
                        text: {
                            let known = ["name_required", "output_required", "bad_path", "same_file", "config_line_pair", "output_exists"];
                            let code = known.indexOf(AppTheming.createError) >= 0 ? AppTheming.createError : "failed";
                            return I18n.t("guide.theme.apps.form.error." + code);
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: rootObj.s(8)

                        Item { Layout.fillWidth: true }

                        ClickButton {
                            Layout.preferredWidth: desiredWidth
                            Layout.preferredHeight: rootObj.s(32)
                            horizontalPadding: rootObj.s(14)
                            cornerRadius: ThemeBackend.borderRadius
                            buttonText: I18n.t("guide.theme.apps.form.cancel")
                            textFontSize: rootObj.s(12)
                            accentColor: ThemeBackend.surface0
                            textColor: ThemeBackend.text
                            onClicked: {
                                appsTabRoot.showCustomForm = false;
                                appsTabRoot.resetForm();
                            }
                        }

                        ClickButton {
                            Layout.preferredWidth: desiredWidth
                            Layout.preferredHeight: rootObj.s(32)
                            horizontalPadding: rootObj.s(14)
                            cornerRadius: ThemeBackend.borderRadius
                            buttonText: I18n.t("guide.theme.apps.form.create")
                            buttonIcon: "󰐕"
                            textFontSize: rootObj.s(12)
                            iconFontSize: rootObj.s(14)
                            accentColor: ThemeBackend.mauve
                            textColor: ThemeBackend.crust
                            enabled: !AppTheming.creating && appsTabRoot.formName.trim() !== "" && appsTabRoot.formOutput.trim() !== ""
                            opacity: enabled ? 1.0 : 0.5
                            onClicked: appsTabRoot.submitForm()
                        }
                    }
                }
            }
        }
    }
}
