import QtQuick
import QtQuick.Layouts
import Quickshell.Io
import "../../"
import "../../bar"
import "../../reusables"
import "modules"

BarModulesSettings {
    id: barModulesRoot
    subTabIndex: 1
    deferredStages: 10

    readonly property var moduleOrder: ["left", "workspaces", "timedate", "vis", "sysmon", "bat", "wifi", "bt", "vol", "kb", "media"]
    property string selectedModule: "left"

    function selectModule(id) {
        if (selectedModule === id) return;
        selectedModule = id;
        modulesFlick.contentY = 0;
        selectedModuleFile.setText(id + "\n");
    }

    function handleHorizontalKey(dir) {
        const n = moduleOrder.length;
        const i = moduleOrder.indexOf(selectedModule);
        selectModule(moduleOrder[(i + dir + n) % n]);
        return true;
    }

    FileView {
        id: selectedModuleFile
        path: Caching.getCacheDir("guide") + "/bar_module.txt"
        blockLoading: true
        printErrors: false
        onLoaded: {
            const id = text().trim();
            if (barModulesRoot.moduleOrder.indexOf(id) !== -1) barModulesRoot.selectedModule = id;
        }
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
        active: barModulesRoot.deferredStage >= stage
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
                model: barModulesRoot.moduleOrder
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
        ModuleSlot { moduleId: "bat"; stage: 5; sourceComponent: BarBatteryCard { tab: barModulesRoot } }
        ModuleSlot { moduleId: "wifi"; stage: 6; sourceComponent: BarNetworkCard { tab: barModulesRoot } }
        ModuleSlot { moduleId: "bt"; stage: 7; sourceComponent: BarBluetoothCard { tab: barModulesRoot } }
        ModuleSlot { moduleId: "vol"; stage: 8; sourceComponent: BarVolumeCard { tab: barModulesRoot } }
        ModuleSlot { moduleId: "kb"; stage: 9; sourceComponent: BarKeyboardCard { tab: barModulesRoot } }
        ModuleSlot { moduleId: "media"; stage: 10; sourceComponent: BarMediaCard { tab: barModulesRoot } }
    }
}
