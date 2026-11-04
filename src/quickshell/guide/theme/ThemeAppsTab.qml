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

    readonly property var themedApps: AppTheming.apps.filter(a => a.installed && a.enabled).sort((a, b) => a.name.localeCompare(b.name))

    function subtitleFor(app) {
        if (app.hint !== "") return I18n.t("guide.theme.apps.hint." + app.hint);
        return app.outputs.length > 0 ? app.outputs[0] : "";
    }

    onVisibleChanged: {
        if (visible) {
            AppTheming.refresh();
        } else {
            issuePopup.close();
            pickerPopup.close();
        }
    }

    AppIssuePopup {
        id: issuePopup
        rootObj: appsTabRoot.rootObj
    }

    AppPickerPopup {
        id: pickerPopup
        rootObj: appsTabRoot.rootObj
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

                        ClickButton {
                            Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                            maxWidth: rootObj.s(160)
                            implicitHeight: rootObj.s(32)
                            cornerRadius: ThemeBackend.borderRadius
                            buttonText: I18n.t("guide.theme.apps.add.title")
                            buttonIcon: "󰐕"
                            iconFontSize: rootObj.s(14)
                            textFontSize: rootObj.s(12)
                            accentColor: ThemeBackend.mauve
                            textColor: ThemeBackend.crust
                            onClicked: pickerPopup.openPicker()
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
                        columns: 2
                        rowSpacing: rootObj.s(8)
                        columnSpacing: rootObj.s(8)
                        visible: appsTabRoot.themedApps.length > 0

                        readonly property real colWidth: Math.max(0, ((cardLayout.width - rootObj.s(24)) - columnSpacing) / 2)

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
                                        buttonIcon: appTile.modelData.icon !== "" ? appTile.modelData.icon : "󰏘"
                                        iconFontSize: rootObj.s(16)
                                        accentColor: ThemeBackend.surface1
                                        textColor: ThemeBackend.mauve
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
                                            text: appsTabRoot.subtitleFor(appTile.modelData)
                                            font.family: ThemeBackend.fontFamily
                                            font.pixelSize: rootObj.s(10)
                                            color: ThemeBackend.subtext0
                                            elide: Text.ElideMiddle
                                            Layout.fillWidth: true
                                        }
                                    }

                                    IconButton {
                                        visible: appTile.problem
                                        size: rootObj.s(28)
                                        cornerRadius: Math.min(ThemeBackend.borderRadius, rootObj.s(8))
                                        buttonIcon: "󰀦"
                                        iconFontSize: rootObj.s(14)
                                        accentColor: Qt.alpha(ThemeBackend.red, 0.15)
                                        textColor: ThemeBackend.red
                                        Layout.alignment: Qt.AlignVCenter
                                        onClicked: issuePopup.openFor(appTile.modelData)
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
                }
            }
        }
    }
}
