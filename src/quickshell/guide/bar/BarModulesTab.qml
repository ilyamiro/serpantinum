import QtQuick
import QtQuick.Layouts
import Quickshell.Io
import "../../"
import "../../bar"
import "../../reusables"
import "modules"

BarModulesSettings {
    id: barModulesRoot
    deferredStages: 10

    readonly property var configurableModules: ["left", "workspaces", "timedate", "vis", "sysmon", "bat", "wifi", "bt", "vol", "kb", "media"]
    readonly property var moduleOrder: {
        let regIds = BarModuleRegistry.moduleIds();
        return configurableModules.filter(id => regIds.indexOf(id) !== -1);
    }
    property string selectedModule: "left"
    property bool selectionRestored: false

    function selectModule(id) {
        if (selectedModule === id) return;
        selectedModule = id;
        modulesFlick.contentY = 0;
        selectedModuleFile.setText(id + "\n");
    }

    function handleHorizontalKey(dir) {
        const n = moduleOrder.length;
        if (n === 0) return false;
        const i = moduleOrder.indexOf(selectedModule);
        selectModule(moduleOrder[(i + dir + n) % n]);
        return true;
    }

    FileView {
        id: selectedModuleFile
        path: Caching.getCacheDir("guide") + "/bar_module.txt"
        blockLoading: true
        printErrors: false
    }

    Component.onCompleted: {
        const id = selectedModuleFile.text().trim();
        if (moduleOrder.indexOf(id) !== -1) selectedModule = id;
        selectionRestored = true;
    }

    function inView(item) {
        if (!item || !item.visible || !visible) return false;
        void modulesFlick.contentY;
        void modulesFlick.contentHeight;
        void modulesFlick.height;
        void item.y;
        void item.height;
        const top = item.mapToItem(modulesFlick.contentItem, 0, 0).y;
        const margin = modulesFlick.height * 0.5;
        return top + item.height > modulesFlick.contentY - margin && top < modulesFlick.contentY + modulesFlick.height + margin;
    }

    component ModuleSlot: Loader {
        id: slot
        required property string moduleId
        property int stage: 0

        readonly property bool isGroupSubWrapper: true
        readonly property var ownerGroup: slot
        readonly property bool isOpen: barModulesRoot.selectedModule === moduleId
        function holdOpen() { barModulesRoot.selectModule(moduleId); }
        function releaseOpen() {}

        Layout.fillWidth: true
        visible: isOpen
        active: isOpen || barModulesRoot.deferredStage >= stage
    }

    Rectangle {
        id: moduleHeader
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.topMargin: rootObj.s(8)
        anchors.leftMargin: rootObj.s(8)
        anchors.rightMargin: rootObj.s(8)
        implicitHeight: moduleChips.implicitHeight + rootObj.s(16)
        radius: ThemeBackend.borderRadius
        color: ThemeBackend.liquidGlass ? "transparent" : Qt.alpha(ThemeBackend.surface0, 0.4)
        clip: true

        GlassFill {
            anchors.fill: parent
            allowed: barModulesRoot.visible
            radius: parent.radius
            tintColor: Qt.alpha(ThemeBackend.surface0, 0.4)
            tintAmount: 0.25
        }

        Flow {
            id: moduleChips
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.margins: rootObj.s(8)
            layoutDirection: I18n.layoutDirection
            spacing: rootObj.s(6)

            Repeater {
                model: barModulesRoot.selectionRestored ? barModulesRoot.moduleOrder : []
                delegate: ClickButton {
                    required property string modelData
                    readonly property bool selected: barModulesRoot.selectedModule === modelData
                    readonly property var info: BarModuleRegistry.types[modelData] || ({})

                    height: rootObj.s(30)
                    cornerRadius: ThemeBackend.borderRadius
                    horizontalPadding: rootObj.s(10)
                    buttonIcon: info.icon || ""
                    buttonText: info.name || modelData
                    iconFontSize: rootObj.s(14)
                    textFontSize: rootObj.s(12)
                    accentColor: selected ? ThemeBackend.mauve : ThemeBackend.surface0
                    textColor: selected ? ThemeBackend.crust : ThemeBackend.text
                    onClicked: barModulesRoot.selectModule(modelData)
                }
            }
        }
    }

    GuideScrollView {
        id: modulesFlick
        rootObj: barModulesRoot.rootObj
        spacing: rootObj.s(12)
        anchors.topMargin: moduleHeader.y + moduleHeader.height + rootObj.s(10)

        ModuleSlot { moduleId: "left"; sourceComponent: BarMenuCard { tab: barModulesRoot } }
        ModuleSlot { moduleId: "workspaces"; stage: 1; sourceComponent: BarWorkspacesCard { tab: barModulesRoot } }
        ModuleSlot { moduleId: "timedate"; stage: 2; sourceComponent: BarTimeDateCard { tab: barModulesRoot } }
        ModuleSlot { moduleId: "vis"; stage: 3; sourceComponent: BarVisualizerCard { tab: barModulesRoot } }
        ModuleSlot { moduleId: "sysmon"; stage: 4; sourceComponent: BarSysmonCard { tab: barModulesRoot } }
        ModuleSlot {
            moduleId: "bat"
            stage: 5
            sourceComponent: BarToggleModuleCard {
                tab: barModulesRoot
                moduleId: "bat"
                title: I18n.t("guide.bar.modules.battery", "Battery")
                styleSettingId: "bar_bat_style"
                styleKeywords: "battery style look visual classic minimal text button ios android capsule"
                styleIcon: "󰂄"
                styleTitle: I18n.t("guide.bar.bat.style.title", "Battery style")
                styleDescription: I18n.t("guide.bar.bat.style.desc", "Choose the visual appearance of the battery indicator")
                toggles: [
                    {
                        key: "batShowPercent",
                        peerKey: "batShowIcon",
                        settingId: "bar_bat_show_percent",
                        keywords: "battery charge percentage percent number",
                        icon: "󰚥",
                        title: I18n.t("guide.bar.bat.show_percent.title", "Show percentage"),
                        desc: I18n.t("guide.bar.bat.show_percent.desc", "Display the numeric battery charge percentage"),
                        hideOnSideBar: true
                    },
                    {
                        key: "batShowIcon",
                        peerKey: "batShowPercent",
                        settingId: "bar_bat_show_icon",
                        keywords: "battery icon symbol indicator",
                        icon: "󰁹",
                        title: I18n.t("guide.bar.bat.show_icon.title", "Show icon"),
                        desc: I18n.t("guide.bar.bat.show_icon.desc", "Display the battery icon or graphic indicator")
                    }
                ]
            }
        }
        ModuleSlot {
            moduleId: "wifi"
            stage: 6
            sourceComponent: BarToggleModuleCard {
                tab: barModulesRoot
                moduleId: "wifi"
                title: I18n.t("guide.bar.modules.network", "Network")
                styleSettingId: "bar_wifi_style"
                styleKeywords: "network wifi style look button text layout"
                styleIcon: "󰤨"
                styleTitle: I18n.t("guide.bar.wifi.style.title", "Style")
                styleDescription: I18n.t("guide.bar.wifi.style.desc", "Choose the visual appearance of the network module")
                toggles: [
                    {
                        key: "wifiShowIcon",
                        peerKey: "wifiShowName",
                        settingId: "bar_wifi_show_icon",
                        keywords: "network wifi ethernet icon symbol indicator",
                        icon: "󰤨",
                        title: I18n.t("guide.bar.wifi.show_icon.title", "Show icon"),
                        desc: I18n.t("guide.bar.wifi.show_icon.desc", "Display the network icon or signal indicator")
                    },
                    {
                        key: "wifiShowName",
                        peerKey: "wifiShowIcon",
                        settingId: "bar_wifi_show_name",
                        keywords: "network wifi ethernet ssid name title",
                        icon: "󰤥",
                        title: I18n.t("guide.bar.wifi.show_name.title", "Show name"),
                        desc: I18n.t("guide.bar.wifi.show_name.desc", "Display the network SSID or connection status text")
                    }
                ]
            }
        }
        ModuleSlot {
            moduleId: "bt"
            stage: 7
            sourceComponent: BarToggleModuleCard {
                tab: barModulesRoot
                moduleId: "bt"
                title: I18n.t("guide.bar.modules.bluetooth", "Bluetooth")
                styleSettingId: "bar_bt_style"
                styleKeywords: "bluetooth style look button text layout"
                styleIcon: "󰂲"
                styleTitle: I18n.t("guide.bar.bt.style.title", "Style")
                styleDescription: I18n.t("guide.bar.bt.style.desc", "Choose the visual appearance of the bluetooth module")
                toggles: [
                    {
                        key: "btShowIcon",
                        peerKey: "btShowName",
                        settingId: "bar_bt_show_icon",
                        keywords: "bluetooth icon symbol indicator",
                        icon: "󰂲",
                        title: I18n.t("guide.bar.bt.show_icon.title", "Show icon"),
                        desc: I18n.t("guide.bar.bt.show_icon.desc", "Display the bluetooth status icon")
                    },
                    {
                        key: "btShowName",
                        peerKey: "btShowIcon",
                        settingId: "bar_bt_show_name",
                        keywords: "bluetooth device name title connected",
                        icon: "󰂯",
                        title: I18n.t("guide.bar.bt.show_name.title", "Show name"),
                        desc: I18n.t("guide.bar.bt.show_name.desc", "Display the connected bluetooth device name")
                    }
                ]
            }
        }
        ModuleSlot {
            moduleId: "vol"
            stage: 8
            sourceComponent: BarToggleModuleCard {
                tab: barModulesRoot
                moduleId: "vol"
                title: I18n.t("guide.bar.modules.volume", "Volume")
                styleSettingId: "bar_vol_style"
                styleKeywords: "volume audio style look button text layout"
                styleIcon: "󰕾"
                styleTitle: I18n.t("guide.bar.vol.style.title", "Style")
                styleDescription: I18n.t("guide.bar.vol.style.desc", "Choose the visual appearance of the volume module")
                toggles: [
                    {
                        key: "volShowIcon",
                        peerKey: "volShowPercent",
                        settingId: "bar_vol_show_icon",
                        keywords: "volume audio sound icon symbol indicator",
                        icon: "󰕾",
                        title: I18n.t("guide.bar.vol.show_icon.title", "Show icon"),
                        desc: I18n.t("guide.bar.vol.show_icon.desc", "Display the volume speaker icon")
                    },
                    {
                        key: "volShowPercent",
                        peerKey: "volShowIcon",
                        settingId: "bar_vol_show_percent",
                        keywords: "volume percentage percent level audio sound",
                        icon: "󰚥",
                        title: I18n.t("guide.bar.vol.show_percent.title", "Show percentage"),
                        desc: I18n.t("guide.bar.vol.show_percent.desc", "Display the numeric audio volume percentage")
                    }
                ]
            }
        }
        ModuleSlot {
            moduleId: "kb"
            stage: 9
            sourceComponent: BarToggleModuleCard {
                tab: barModulesRoot
                moduleId: "kb"
                title: I18n.t("guide.bar.modules.keyboard", "Keyboard")
                styleSettingId: "bar_kb_style"
                styleKeywords: "keyboard layout style look button text layout"
                styleIcon: "󰌌"
                styleTitle: I18n.t("guide.bar.kb.style.title", "Style")
                styleDescription: I18n.t("guide.bar.kb.style.desc", "Choose the visual appearance of the keyboard module")
                toggles: [
                    {
                        key: "kbShowIcon",
                        settingId: "bar_kb_show_icon",
                        keywords: "keyboard layout icon symbol indicator",
                        icon: "󰌌",
                        title: I18n.t("guide.bar.kb.show_icon.title", "Show icon"),
                        desc: I18n.t("guide.bar.kb.show_icon.desc", "Display the keyboard layout icon"),
                        hideOnSideBar: true
                    }
                ]
            }
        }
        ModuleSlot { moduleId: "media"; stage: 10; sourceComponent: BarMediaCard { tab: barModulesRoot } }
    }
}
