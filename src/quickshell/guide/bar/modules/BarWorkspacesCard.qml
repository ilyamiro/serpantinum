import QtQuick
import QtQuick.Layouts
import "../../../"
import "../../../reusables"
import "../../../reusables/guide"

BarModuleCard {
    id: card
    title: I18n.t("guide.bar.modules.workspaces.name", "Workspaces")
    moduleId: "workspaces"
    showPreview: false
    variantPreviewSideHeight: 160
    styles: card.tab.workspaceStyles
    currentStyle: card.tab.workspacesStyle
    styleSettingId: "bar_workspaces_style"
    styleKeywords: "pills numbers pacman workspaces style"
    styleIcon: "󰮯"
    styleTitle: I18n.t("guide.bar.workspaces.style.title", "Workspaces style")
    styleDescription: I18n.t("guide.bar.workspaces.style.desc", "Choose the visual style for workspace indicators")
    onStyleSelected: id => card.tab.setWorkspacesStyle(id)

    widgetComponent: Component {
        BarPreviewWidget {
            isPreview: false
            moduleActive: true
            property int workspaceCount: 5
            property int activeIndex: 1
            property var isOccupied: function(idx) { return idx === 0 || idx === 1 || idx === 2; }
            property var focusWorkspace: function(idx) {}
        }
    }

    variantFallback: Component {
        Item {
            property string variantId

            RowLayout {
                anchors.centerIn: parent
                visible: !card.tab.isSideBar
                spacing: rootObj.s(6)

                Repeater {
                    model: 5
                    delegate: Rectangle {
                        required property int index
                        readonly property bool isActive: index === 1
                        width: variantId === "pills"
                            ? (isActive ? rootObj.s(22) : rootObj.s(8))
                            : rootObj.s(18)
                        height: variantId === "pills" ? rootObj.s(8) : rootObj.s(18)
                        Layout.preferredWidth: width
                        Layout.preferredHeight: height
                        radius: variantId === "pills" ? height / 2 : rootObj.s(4)
                        color: isActive ? ThemeBackend.mauve : Qt.alpha(ThemeBackend.surface2, 0.7)

                        Text {
                            anchors.centerIn: parent
                            visible: variantId === "numbers"
                            text: String(index + 1)
                            font.family: ThemeBackend.fontFamily
                            font.pixelSize: rootObj.s(10)
                            font.bold: isActive
                            color: isActive ? ThemeBackend.crust : ThemeBackend.text
                        }

                        Text {
                            anchors.centerIn: parent
                            visible: variantId === "pacman"
                            text: isActive ? "󰮯" : "•"
                            font.family: ThemeBackend.fontFamily
                            font.pixelSize: rootObj.s(14)
                            font.bold: false
                            color: isActive ? ThemeBackend.yellow : ThemeBackend.subtext0
                        }
                    }
                }
            }

            ColumnLayout {
                anchors.centerIn: parent
                visible: card.tab.isSideBar
                spacing: rootObj.s(6)

                Repeater {
                    model: 5
                    delegate: Rectangle {
                        required property int index
                        readonly property bool isActive: index === 1
                        width: rootObj.s(18)
                        height: variantId === "pills"
                            ? (isActive ? rootObj.s(36) : rootObj.s(18))
                            : rootObj.s(18)
                        Layout.preferredWidth: width
                        Layout.preferredHeight: height
                        radius: variantId === "pills" ? width / 2 : rootObj.s(4)
                        color: isActive ? ThemeBackend.mauve : Qt.alpha(ThemeBackend.surface2, 0.7)

                        Text {
                            anchors.centerIn: parent
                            visible: variantId === "numbers"
                            text: String(index + 1)
                            font.family: ThemeBackend.fontFamily
                            font.pixelSize: rootObj.s(10)
                            font.bold: isActive
                            color: isActive ? ThemeBackend.crust : ThemeBackend.text
                        }

                        Text {
                            anchors.centerIn: parent
                            visible: variantId === "pacman"
                            text: isActive ? "󰮯" : "•"
                            font.family: ThemeBackend.fontFamily
                            font.pixelSize: rootObj.s(14)
                            font.bold: false
                            color: isActive ? ThemeBackend.yellow : ThemeBackend.subtext0
                        }
                    }
                }
            }
        }
    }

    SettingsRow {
        rootObj: card.rootObj
        baseColor: Qt.alpha(ThemeBackend.surface1, 0.35)
        icon: "󰮯"
        title: I18n.t("guide.bar.workspaces.title")
        description: I18n.t("guide.bar.workspaces.desc")

        NumberSelector {
            id: workspaceCountSelector
            Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
            implicitWidth: rootObj.s(140)
            implicitHeight: rootObj.s(32)
            from: 2
            to: 10
            stepSize: 1
            decimals: 0
            value: card.tab.workspaceCount
            baseColor: ThemeBackend.surface0
            accentColor: ThemeBackend.mauve
            buttonColor: ThemeBackend.surface1
            buttonTextColor: ThemeBackend.text
            textColor: ThemeBackend.text
            subTextColor: ThemeBackend.subtext0
            borderColor: Qt.alpha(ThemeBackend.surface2, 0.6)
            cornerRadius: ThemeBackend.borderRadius
            fontFamily: ThemeBackend.fontFamily
            fontPixelSize: rootObj.s(12)
            onValueChanged: {
                let rounded = Math.round(workspaceCountSelector.value);
                if (card.tab.workspaceCount !== rounded) {
                    card.tab.setWorkspaceCount(rounded);
                }
            }
            onTriggered: {
                card.tab.setWorkspaceCount(Math.round(workspaceCountSelector.value));
            }
        }
    }

    SettingsRow {
        rootObj: card.rootObj
        baseColor: Qt.alpha(ThemeBackend.surface1, 0.35)
        icon: "󰈈"
        title: I18n.t("guide.bar.workspaces.hide_empty.title", "Hide empty workspaces")
        description: I18n.t("guide.bar.workspaces.hide_empty.desc", "Show only occupied workspaces and the active one")

        Toggle {
            Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
            checked: card.tab.hideEmptyWorkspaces
            accentColor: ThemeBackend.mauve
            baseColor: ThemeBackend.surface1
            handleColor: ThemeBackend.crust
            handleOffColor: ThemeBackend.text
            onToggled: function(c) {
                card.tab.setHideEmptyWorkspaces(c);
            }
        }
    }

    SettingsRow {
        rootObj: card.rootObj
        baseColor: Qt.alpha(ThemeBackend.surface1, 0.35)
        icon: "󰍹"
        title: I18n.t("guide.bar.workspaces.per_monitor.title", "Per-monitor numbering")
        hiddenByConfig: Compositor.name !== "hyprland"
        unavailableReason: I18n.t("guide.bar.workspaces.per_monitor.unavailable", "Available only on Hyprland")
        description: I18n.t("guide.bar.workspaces.per_monitor.desc", "Hyprland only. Number workspaces from 1 on each monitor and set how many workspaces each monitor owns")

        Toggle {
            Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
            checked: card.tab.perMonitorNumbering
            accentColor: ThemeBackend.mauve
            baseColor: ThemeBackend.surface1
            handleColor: ThemeBackend.crust
            handleOffColor: ThemeBackend.text
            onToggled: function(c) {
                card.tab.setPerMonitorNumbering(c);
            }
        }
    }

    Repeater {
        model: (Compositor.name === "hyprland" && card.tab.perMonitorNumbering) ? card.tab.workspaceMonitorNames : []
        delegate: SettingsRow {
            id: monitorRow
            required property string modelData
            rootObj: card.rootObj
            baseColor: Qt.alpha(ThemeBackend.surface1, 0.35)
            icon: "󰍹"
            title: monitorRow.modelData
            description: I18n.t("guide.bar.workspaces.monitor_count.desc", "Workspaces this monitor owns")

            NumberSelector {
                id: monitorCountSelector
                Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                implicitWidth: rootObj.s(140)
                implicitHeight: rootObj.s(32)
                from: 1
                to: 100
                stepSize: 1
                decimals: 0
                value: card.tab.workspaceCountFor(monitorRow.modelData)
                baseColor: ThemeBackend.surface0
                accentColor: ThemeBackend.mauve
                buttonColor: ThemeBackend.surface1
                buttonTextColor: ThemeBackend.text
                textColor: ThemeBackend.text
                subTextColor: ThemeBackend.subtext0
                borderColor: Qt.alpha(ThemeBackend.surface2, 0.6)
                cornerRadius: ThemeBackend.borderRadius
                fontFamily: ThemeBackend.fontFamily
                fontPixelSize: rootObj.s(12)
                onValueChanged: {
                    let rounded = Math.round(monitorCountSelector.value);
                    if (card.tab.workspaceCountFor(monitorRow.modelData) !== rounded) {
                        card.tab.setMonitorWorkspaceCount(monitorRow.modelData, rounded);
                    }
                }
                onTriggered: {
                    card.tab.setMonitorWorkspaceCount(monitorRow.modelData, Math.round(monitorCountSelector.value));
                }
            }
        }
    }
}
