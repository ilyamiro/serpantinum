import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import "../../"
import "../../reusables"
import "../../widgets"

Scope {
    id: root

    property bool isActive: false
    property string targetMonitorName: ""
    readonly property int storeRevision: LockLayoutStore.revision

    function open(mon) {
        root.targetMonitorName = (mon && typeof mon === "string") ? mon.trim() : "";
        root.isActive = true;
    }

    function close() {
        LockLayoutStore.flush();
        root.isActive = false;
        root.targetMonitorName = "";
    }

    function toggle(mon) {
        if (root.isActive) {
            root.close();
        } else {
            root.open(mon);
        }
    }

    IpcHandler {
        target: "lock-redactor"

        function open(mon: string): void {
            root.open(mon);
        }

        function toggle(): void {
            root.toggle("");
        }

        function close(): void {
            root.close();
        }
    }

    Loader {
        active: root.isActive

        sourceComponent: Component {
            PanelWindow {
                id: win
                color: "transparent"

                readonly property string monitorName: root.targetMonitorName !== "" ? root.targetMonitorName : (Quickshell.screens.length > 0 ? Quickshell.screens[0].name : "")
                readonly property var targetScreen: Quickshell.screens.find(s => s.name === win.monitorName) || (Quickshell.screens.length > 0 ? Quickshell.screens[0] : null)
                readonly property string safeMonitorName: (win.monitorName || "default").replace(/[^a-zA-Z0-9_-]/g, "_")
                readonly property var lockSettings: Config.getSetting("lockscreen", {})
                readonly property string customBackgroundPath: lockSettings.customBackground ? String(lockSettings.customBackground) : ""
                readonly property bool customBackgroundActive: lockSettings.backgroundMode === "custom" && customBackgroundPath !== ""
                readonly property string desktopWallpaperPath: {
                    Wallpaper.screenWallpaperPaths;
                    return Wallpaper.getWallpaperPath(win.monitorName);
                }
                readonly property string backgroundPath: customBackgroundActive ? customBackgroundPath : desktopWallpaperPath
                readonly property bool backgroundIsVideo: {
                    let lp = win.backgroundPath.toLowerCase();
                    return lp.endsWith(".mp4") || lp.endsWith(".mkv") || lp.endsWith(".mov") || lp.endsWith(".webm");
                }
                readonly property string videoPath: win.backgroundIsVideo ? win.backgroundPath : ""
                readonly property string wallpaperSource: {
                    if (win.customBackgroundActive && !win.backgroundIsVideo) {
                        return "file://" + win.customBackgroundPath;
                    }
                    if (win.customBackgroundActive) {
                        return "";
                    }
                    return "file://" + Caching.getCacheDir("wallpaper") + "/current_wallpaper_" + win.monitorName + ".png";
                }

                screen: win.targetScreen

                WlrLayershell.namespace: "qs-lock-redactor-" + win.safeMonitorName
                WlrLayershell.layer: WlrLayer.Overlay
                WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

                exclusionMode: ExclusionMode.Ignore
                focusable: true

                anchors.top: true
                anchors.left: true
                anchors.right: true
                anchors.bottom: true

                readonly property real screenW: win.targetScreen ? win.targetScreen.width : 1920
                readonly property real screenH: win.targetScreen ? win.targetScreen.height : 1080

                property int page: 0

                Component.onCompleted: {
                    LockLayoutStore.setReference(win.screenW, win.screenH);
                    LockLayoutStore.beginHistory();
                }

                Component.onDestruction: LockLayoutStore.endHistory()
                property real pageProgress: win.page
                property bool gridScreen: false
                property bool gridPanel: true

                readonly property Item activeScene: win.page === 0 ? screenScene : panelStage.scene
                readonly property bool gridOn: win.page === 0 ? win.gridScreen : win.gridPanel
                readonly property var selProxy: win.activeScene.selectedProxy
                readonly property bool panelMode: win.page === 1 && win.selProxy === null && panelStage.panelSelected
                readonly property Item chromeTarget: win.selProxy ? win.selProxy : (win.panelMode ? panelStage.selectionItem : null)

                Behavior on pageProgress { NumberAnimation { duration: 320; easing.type: Easing.OutCubic } }

                function go(delta) {
                    win.page = Math.max(0, Math.min(1, win.page + delta));
                }

                function toggleGrid() {
                    if (win.page === 0) {
                        win.gridScreen = !win.gridScreen;
                        if (win.gridScreen) screenScene.snapAllToGrid();
                    } else {
                        win.gridPanel = !win.gridPanel;
                        if (win.gridPanel) panelStage.scene.snapAllToGrid();
                    }
                }

                function addItem(type, imagePath) {
                    let scene = win.activeScene;
                    if (!LockElementRegistry.allowedIn(type, scene.scope)) return;
                    let def = LockElementRegistry.defaultSize(type);
                    let w = def.w > 0 ? Math.min(def.w, scene.width) : 0;
                    let h = def.h > 0 ? Math.min(def.h, scene.height) : 0;
                    let x = w > 0 ? Math.max(0, (scene.width - w) / 2) : scene.width / 2;
                    let y = h > 0 ? Math.max(0, (scene.height - h) / 2) : scene.height / 2;
                    if (w > 0 && win.gridOn) {
                        x = Math.round(x / scene.gridStep) * scene.gridStep;
                        y = Math.round(y / scene.gridStep) * scene.gridStep;
                    }
                    let entry = LockLayoutStore.makeEntry(type, LockElementRegistry.defaultVariant(type), x, y, w, h);
                    entry.iimage = imagePath || "";
                    scene.selectedId = LockLayoutStore.addItem(scene.scope, entry);
                }

                function openImagePicker(itemId, currentPath, rounded) {
                    imagePickerLoader.targetItemId = itemId;
                    imagePickerLoader.currentPath = currentPath;
                    imagePickerLoader.rounded = rounded;
                    imagePickerLoader.active = true;
                    if (imagePickerLoader.item) imagePickerLoader.item.openPicker(currentPath, rounded);
                }

                QtObject {
                    id: widgetAdder

                    function addWidget(typeKey) {
                        let t = WidgetRegistry.types[typeKey];
                        if (!t) return;
                        if (t.requiresFilePicker) {
                            win.openImagePicker("", "", false);
                            return;
                        }
                        win.addItem("widget:" + typeKey, "");
                    }
                }

                Shortcut {
                    sequence: "Escape"
                    onActivated: root.close()
                }

                Shortcut {
                    sequence: "Left"
                    onActivated: win.go(-1)
                }

                Shortcut {
                    sequence: "Right"
                    onActivated: win.go(1)
                }

                Shortcut {
                    sequence: "Ctrl+Z"
                    onActivated: LockLayoutStore.undo()
                }

                Shortcut {
                    sequences: ["Ctrl+Shift+Z", "Ctrl+Y"]
                    onActivated: LockLayoutStore.redo()
                }

                Shortcut {
                    sequence: "Delete"
                    onActivated: win.activeScene.removeSelected()
                }

                Item {
                    id: ui
                    anchors.fill: parent

                    readonly property real topH: Scaler.s(24)
                    readonly property real bottomH: Scaler.s(136)
                    readonly property real frameGap: ui.width * 0.03
                    readonly property real k: Math.max(0.05, Math.min(ui.width * 0.84 / win.screenW, pager.height * 0.99 / win.screenH))

                    function s(val) {
                        return Scaler.s(val);
                    }

                    Image {
                        anchors.fill: parent
                        source: win.wallpaperSource
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                        sourceSize: Qt.size(ui.width / 2, ui.height / 2)
                    }

                    Rectangle {
                        anchors.fill: parent
                        color: Qt.rgba(ThemeBackend.crust.r, ThemeBackend.crust.g, ThemeBackend.crust.b, 0.78)
                    }

                    Item {
                        id: pager
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.topMargin: ui.topH
                        anchors.bottom: parent.bottom
                        anchors.bottomMargin: ui.bottomH

                        LockStageFrame {
                            id: clockFrame
                            readonly property real distance: Math.abs(0 - win.pageProgress)
                            screenW: win.screenW
                            screenH: win.screenH
                            k: ui.k
                            current: win.page === 0
                            wallpaper: win.wallpaperSource
                            videoPath: win.videoPath
                            x: pager.width / 2 + (0 - win.pageProgress) * (width + ui.frameGap) - width / 2
                            y: (pager.height - height) / 2
                            opacity: Math.max(0.3, 1 - distance * 0.7)
                            scale: 1 - 0.1 * Math.min(1, distance)
                            onActivated: win.page = 0

                            LockScene {
                                id: screenScene
                                width: win.screenW
                                height: win.screenH
                                scope: "screen"
                                k: ui.k
                                active: win.page === 0
                                gridEnabled: win.gridScreen
                                onImagePickRequested: (itemId, currentPath, rounded) => win.openImagePicker(itemId, currentPath, rounded)
                            }
                        }

                        LockStageFrame {
                            id: panelFrame
                            readonly property real distance: Math.abs(1 - win.pageProgress)
                            screenW: win.screenW
                            screenH: win.screenH
                            k: ui.k
                            current: win.page === 1
                            wallpaper: win.wallpaperSource
                            videoPath: win.videoPath
                            x: pager.width / 2 + (1 - win.pageProgress) * (width + ui.frameGap) - width / 2
                            y: (pager.height - height) / 2
                            opacity: Math.max(0.3, 1 - distance * 0.7)
                            scale: 1 - 0.1 * Math.min(1, distance)
                            onActivated: win.page = 1

                            LockPanelStage {
                                id: panelStage
                                width: win.screenW
                                height: win.screenH
                                k: ui.k
                                active: win.page === 1
                                gridEnabled: win.gridPanel
                                Component.onCompleted: scene.imagePickRequested.connect((itemId, currentPath, rounded) => win.openImagePicker(itemId, currentPath, rounded))
                            }
                        }

                        IconButton {
                            anchors.left: parent.left
                            anchors.leftMargin: Scaler.s(32)
                            anchors.verticalCenter: parent.verticalCenter
                            size: Scaler.s(52)
                            cornerRadius: ThemeBackend.borderRadius
                            buttonIcon: "󰅁"
                            iconFontSize: Scaler.s(24)
                            accentColor: ThemeBackend.surface0
                            textColor: ThemeBackend.text
                            opacity: win.page > 0 ? 1.0 : 0.0
                            enabled: win.page > 0
                            Behavior on opacity { NumberAnimation { duration: 150 } }
                            onClicked: win.go(-1)
                        }

                        IconButton {
                            anchors.right: parent.right
                            anchors.rightMargin: Scaler.s(32)
                            anchors.verticalCenter: parent.verticalCenter
                            size: Scaler.s(52)
                            cornerRadius: ThemeBackend.borderRadius
                            buttonIcon: "󰅂"
                            iconFontSize: Scaler.s(24)
                            accentColor: ThemeBackend.surface0
                            textColor: ThemeBackend.text
                            opacity: win.page < 1 ? 1.0 : 0.0
                            enabled: win.page < 1
                            Behavior on opacity { NumberAnimation { duration: 150 } }
                            onClicked: win.go(1)
                        }
                    }

                    ColumnLayout {
                        id: chrome
                        z: 100
                        spacing: Scaler.s(6)
                        visible: win.chromeTarget !== null
                        opacity: win.chromeTarget !== null && !win.activeScene.dragging ? 1.0 : 0.0
                        Behavior on opacity { NumberAnimation { duration: 150 } }

                        readonly property bool hasProxy: win.selProxy !== null
                        readonly property string pType: chrome.hasProxy ? win.selProxy.pType : ""
                        readonly property bool isWidget: chrome.hasProxy && LockElementRegistry.isWidget(chrome.pType)
                        readonly property string widgetKey: chrome.isWidget ? LockElementRegistry.widgetKey(chrome.pType) : ""
                        readonly property var variantsList: chrome.hasProxy ? LockElementRegistry.variantList(chrome.pType) : []
                        readonly property bool hasVariants: chrome.variantsList.length > 1

                        function place() {
                            let target = win.chromeTarget;
                            if (!target) return;
                            let tl = ui.mapFromItem(target, 0, 0);
                            let br = ui.mapFromItem(target, target.width, target.height);
                            let w = chrome.implicitWidth;
                            let h = chrome.implicitHeight;
                            let margin = Scaler.s(14);
                            let limit = toolbar.y - Scaler.s(8);
                            chrome.x = Math.max(Scaler.s(8), Math.min(ui.width - w - Scaler.s(8), (tl.x + br.x) / 2 - w / 2));
                            let y = br.y + margin;
                            if (y + h > limit) y = tl.y - h - margin;
                            if (y < Scaler.s(8)) y = limit - h;
                            chrome.y = Math.max(Scaler.s(8), y);
                        }

                        onVisibleChanged: if (visible) chrome.place()

                        Timer {
                            interval: 33
                            repeat: true
                            running: chrome.visible
                            onTriggered: chrome.place()
                        }

                        Component {
                            id: defaultSettingButton

                            IconButton {
                                id: defBtn
                                property var settingData: null
                                size: Scaler.s(34)
                                cornerRadius: ThemeBackend.borderRadius
                                buttonIcon: (defBtn.settingData && defBtn.settingData.icon) ? defBtn.settingData.icon : ""
                                iconFontSize: Scaler.s((defBtn.settingData && defBtn.settingData.iconFontSize) ? defBtn.settingData.iconFontSize : 16)
                                accentColor: win.activeScene.resolveThemeColor((defBtn.settingData && defBtn.settingData.accentColor) ? defBtn.settingData.accentColor : "surface0")
                                textColor: win.activeScene.resolveThemeColor((defBtn.settingData && defBtn.settingData.textColor) ? defBtn.settingData.textColor : "mauve")
                                onClicked: {
                                    if (defBtn.settingData && defBtn.settingData.action && win.selProxy) {
                                        win.activeScene.handleAdditionalAction(defBtn.settingData.action, win.selProxy);
                                    }
                                }
                            }
                        }

                        component Pill: Rectangle {
                            id: pill
                            property alias label: pillText.text
                            implicitWidth: pillText.implicitWidth + Scaler.s(16)
                            implicitHeight: Scaler.s(34)
                            color: pillGlass.active ? "transparent" : ThemeBackend.surface0
                            radius: ThemeBackend.borderRadius

                            GlassFill {
                                id: pillGlass
                                anchors.fill: parent
                                radius: parent.radius
                                tintColor: ThemeBackend.surface0
                                tintAmount: 0.3
                            }

                            Text {
                                id: pillText
                                anchors.centerIn: parent
                                font.family: ThemeBackend.fontFamily
                                font.pixelSize: Scaler.s(12)
                                font.bold: true
                                color: ThemeBackend.text
                            }
                        }

                        RowLayout {
                            Layout.alignment: Qt.AlignHCenter
                            spacing: Scaler.s(4)

                            Pill {
                                label: chrome.hasProxy
                                    ? Math.round(win.selProxy.gW) + "x" + Math.round(win.selProxy.gH)
                                    : Math.round(LockLayoutStore.panelW) + "x" + Math.round(LockLayoutStore.panelH)
                            }

                            Pill {
                                label: chrome.hasProxy
                                    ? (win.selProxy.gH > 0 ? (win.selProxy.gW / win.selProxy.gH).toFixed(2) : "0.00") + ":1"
                                    : (LockLayoutStore.panelW / LockLayoutStore.panelH).toFixed(2) + ":1"
                            }

                            Pill {
                                visible: chrome.hasProxy
                                label: {
                                    if (!chrome.hasProxy) return "";
                                    let def = win.selProxy.getDefaultSize();
                                    return def.w > 0 ? Math.round((win.selProxy.gW / def.w) * 100) + "%" : "100%";
                                }
                            }

                            LockSettingsRepeater {
                                row: "top"
                                widgetKey: chrome.widgetKey
                                proxy: win.selProxy
                                scene: win.activeScene
                                buttonComponent: defaultSettingButton
                            }

                            IconButton {
                                visible: chrome.hasProxy
                                size: Scaler.s(34)
                                cornerRadius: ThemeBackend.borderRadius
                                buttonIcon: "󰑖"
                                iconFontSize: Scaler.s(16)
                                accentColor: ThemeBackend.surface0
                                textColor: ThemeBackend.text
                                onClicked: if (win.selProxy) win.selProxy.rotateItem()
                            }

                            IconButton {
                                visible: chrome.hasProxy
                                size: Scaler.s(34)
                                cornerRadius: ThemeBackend.borderRadius
                                buttonIcon: "󰑐"
                                iconFontSize: Scaler.s(15)
                                accentColor: ThemeBackend.surface0
                                textColor: ThemeBackend.text
                                onClicked: if (win.selProxy) win.selProxy.resetItemSize()
                            }

                            DeleteButton {
                                visible: chrome.hasProxy && win.selProxy.deletable
                                size: Scaler.s(34)
                                cornerRadius: ThemeBackend.borderRadius
                                iconFontSize: Scaler.s(18)
                                onClicked: win.activeScene.removeSelected()
                            }
                        }

                        RowLayout {
                            visible: chrome.hasProxy || win.panelMode
                            Layout.alignment: Qt.AlignHCenter
                            spacing: Scaler.s(6)

                            LockSettingsRepeater {
                                row: "bottom"
                                widgetKey: chrome.widgetKey
                                elementType: chrome.pType
                                proxy: win.selProxy
                                scene: win.activeScene
                                buttonComponent: defaultSettingButton
                            }

                            Dropdown {
                                id: variantDropdown
                                visible: chrome.hasVariants
                                implicitHeight: Scaler.s(34)
                                implicitWidth: Scaler.s(150)
                                accentColor: ThemeBackend.mauve
                                baseColor: ThemeBackend.surface0
                                dropdownColor: ThemeBackend.base
                                borderColor: ThemeBackend.surface1
                                textColor: ThemeBackend.text
                                activeTextColor: ThemeBackend.crust
                                cornerRadius: ThemeBackend.borderRadius
                                fontPixelSize: Scaler.s(11)
                                fuzzySearch: false
                                options: chrome.variantsList.map(v => v.name)

                                function syncIndex() {
                                    if (!win.selProxy) return;
                                    let i = chrome.variantsList.findIndex(v => v.id === win.selProxy.pVariant);
                                    variantDropdown.currentIndex = i >= 0 ? i : 0;
                                }

                                Component.onCompleted: syncIndex()

                                Connections {
                                    target: win
                                    function onSelProxyChanged() { variantDropdown.syncIndex(); }
                                }

                                Connections {
                                    target: win.selProxy
                                    ignoreUnknownSignals: true
                                    function onPVariantChanged() { variantDropdown.syncIndex(); }
                                }

                                onSelected: (idx, value) => {
                                    if (win.selProxy && idx >= 0 && idx < chrome.variantsList.length) {
                                        win.selProxy.applyVariant(chrome.variantsList[idx].id);
                                    }
                                }
                            }

                            Rectangle {
                                implicitWidth: chrome.hasVariants ? Scaler.s(200) : Scaler.s(280)
                                implicitHeight: Scaler.s(34)
                                color: opacityGlass.active ? "transparent" : ThemeBackend.surface0
                                radius: ThemeBackend.borderRadius

                                GlassFill {
                                    id: opacityGlass
                                    anchors.fill: parent
                                    radius: parent.radius
                                    tintColor: ThemeBackend.surface0
                                    tintAmount: 0.3
                                }

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: Scaler.s(10)
                                    anchors.rightMargin: Scaler.s(10)
                                    spacing: Scaler.s(8)

                                    Text {
                                        text: Math.round((chrome.hasProxy ? win.selProxy.pOpacity : LockLayoutStore.panelOpacity) * 100) + "%"
                                        font.family: ThemeBackend.fontFamily
                                        font.pixelSize: Scaler.s(11)
                                        font.bold: true
                                        color: ThemeBackend.text
                                        Layout.preferredWidth: Scaler.s(32)
                                    }

                                    Draggable {
                                        id: opacitySlider
                                        Layout.fillWidth: true
                                        Layout.preferredHeight: Scaler.s(16)
                                        Layout.alignment: Qt.AlignVCenter
                                        from: 0.0
                                        to: 100.0
                                        value: Math.round((chrome.hasProxy ? win.selProxy.pOpacity : LockLayoutStore.panelOpacity) * 100)
                                        backgroundColor: ThemeBackend.surface1
                                        accentColor: ThemeBackend.mauve
                                        gradColor1: ThemeBackend.mauve
                                        gradColor2: Qt.lighter(ThemeBackend.mauve, 1.05)
                                        gradColor3: Qt.lighter(ThemeBackend.mauve, 1.10)
                                        cornerRadius: ThemeBackend.borderRadius
                                        handleSize: Scaler.s(16)
                                        handleColor: Qt.lighter(ThemeBackend.mauve, 1.15)
                                        handleHoverColor: Qt.lighter(ThemeBackend.mauve, 1.3)
                                        handleDragColor: Qt.lighter(ThemeBackend.mauve, 1.45)
                                        handleBorderColor: Qt.rgba(0, 0, 0, 0.2)
                                        showValueBubble: false

                                        onMoved: val => {
                                            if (win.selProxy) win.selProxy.setOpacity(val / 100.0);
                                            else LockLayoutStore.setPanelOpacity(val / 100.0);
                                        }

                                        onDragFinished: {
                                            if (win.selProxy) win.selProxy.finalizeSync();
                                        }
                                    }
                                }
                            }
                        }
                    }

                    Item {
                        id: toolbar
                        anchors.bottom: parent.bottom
                        anchors.bottomMargin: Scaler.s(24)
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: Math.min(ui.width - Scaler.s(48), itemsRow.implicitWidth + actionsRow.implicitWidth + Scaler.s(80))
                        height: Scaler.s(100)
                        z: 50

                        Rectangle {
                            anchors.fill: parent
                            color: Qt.alpha(ThemeBackend.base, ThemeBackend.elementOpacity)
                            radius: ThemeBackend.borderRadius

                            WallpaperBlur {
                                z: -1
                                anchors.fill: parent
                                radius: parent.radius
                                standalone: true
                            }
                        }

                        Flickable {
                            id: itemsFlick
                            anchors.left: parent.left
                            anchors.leftMargin: Scaler.s(16)
                            anchors.right: actionsRow.left
                            anchors.rightMargin: Scaler.s(20)
                            anchors.verticalCenter: parent.verticalCenter
                            height: parent.height - Scaler.s(32)
                            contentWidth: itemsRow.implicitWidth
                            contentHeight: height
                            clip: true
                            flickableDirection: Flickable.HorizontalFlick
                            boundsBehavior: Flickable.StopAtBounds

                            WheelHandler {
                                onWheel: (event) => {
                                    let delta = event.angleDelta.x !== 0 ? event.angleDelta.x : event.angleDelta.y;
                                    itemsFlick.contentX = Math.max(0, Math.min(Math.max(0, itemsFlick.contentWidth - itemsFlick.width), itemsFlick.contentX - delta));
                                }
                            }

                            RowLayout {
                                id: itemsRow
                                height: itemsFlick.height
                                spacing: Scaler.s(14)

                                Repeater {
                                    model: LockElementRegistry.lockTypeList(win.activeScene.scope)

                                    LockToolbarItem {
                                        icon: modelData.icon
                                        caption: modelData.name
                                        onClicked: win.addItem(modelData.id, "")
                                    }
                                }

                                Rectangle {
                                    Layout.preferredWidth: 1
                                    Layout.preferredHeight: Scaler.s(52)
                                    color: Qt.alpha(ThemeBackend.text, 0.15)
                                }

                                Repeater {
                                    model: WidgetRegistry.typeList()

                                    delegate: Loader {
                                        Layout.alignment: Qt.AlignVCenter
                                        sourceComponent: WidgetRegistry.toolbarComponent(modelData.id)
                                        onLoaded: {
                                            if (item) {
                                                item.typeData = modelData;
                                                item.redactor = widgetAdder;
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        RowLayout {
                            id: actionsRow
                            anchors.right: parent.right
                            anchors.rightMargin: Scaler.s(16)
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: Scaler.s(10)

                            IconButton {
                                size: Scaler.s(40)
                                cornerRadius: ThemeBackend.borderRadius
                                buttonIcon: "󰕰"
                                iconFontSize: Scaler.s(20)
                                accentColor: win.gridOn ? ThemeBackend.mauve : ThemeBackend.surface0
                                textColor: win.gridOn ? ThemeBackend.crust : ThemeBackend.text
                                onClicked: win.toggleGrid()
                            }

                            IconButton {
                                size: Scaler.s(40)
                                cornerRadius: ThemeBackend.borderRadius
                                buttonIcon: "󰑐"
                                iconFontSize: Scaler.s(20)
                                accentColor: ThemeBackend.surface0
                                textColor: ThemeBackend.text
                                onClicked: {
                                    win.activeScene.selectedId = "";
                                    LockLayoutStore.resetScope(win.activeScene.scope);
                                }
                            }

                            ClickButton {
                                maxWidth: Scaler.s(100)
                                implicitHeight: Scaler.s(40)
                                cornerRadius: ThemeBackend.borderRadius
                                buttonText: I18n.t("lock.redactor.done")
                                textFontSize: Scaler.s(14)
                                accentColor: ThemeBackend.mauve
                                textColor: ThemeBackend.crust
                                onClicked: root.close()
                            }
                        }
                    }

                    Loader {
                        id: imagePickerLoader
                        anchors.fill: parent
                        z: 300000
                        active: false

                        property string targetItemId: ""
                        property string currentPath: ""
                        property bool rounded: false

                        sourceComponent: ImagePicker {
                            rootObj: ui

                            onImageSelected: (filePath, fileName) => {
                                if (imagePickerLoader.targetItemId !== "") {
                                    LockLayoutStore.setItemProperty(imagePickerLoader.targetItemId, "iimage", filePath);
                                } else if (filePath !== "") {
                                    win.addItem("widget:image", filePath);
                                }
                                imagePickerLoader.targetItemId = "";
                            }
                        }

                        onLoaded: item.openPicker(imagePickerLoader.currentPath, imagePickerLoader.rounded)
                    }
                }
            }
        }
    }
}
