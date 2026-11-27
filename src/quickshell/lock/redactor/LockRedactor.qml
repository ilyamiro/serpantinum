import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import "../../"
import "../../reusables"
import "../../reusables/canvas"
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

    Connections {
        target: LockLayoutStore
        function onRedactorOpenRequested(monitor) {
            root.open(monitor);
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
                readonly property var targetScreen: Compositor.screenByName(win.monitorName) || (Quickshell.screens.length > 0 ? Quickshell.screens[0] : null)
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
                property real pageProgress: win.page
                property bool gridScreen: false
                property bool gridPanel: true

                Component.onCompleted: {
                    LockLayoutStore.setReference(win.screenW, win.screenH);
                    LockLayoutStore.beginHistory();
                }

                Component.onDestruction: LockLayoutStore.endHistory()

                readonly property Item activeScene: win.page === 0 ? screenScene : panelStage.scene
                readonly property bool gridOn: win.page === 0 ? win.gridScreen : win.gridPanel
                readonly property var selProxy: win.activeScene.selectedProxy
                readonly property bool panelMode: win.page === 1 && win.selProxy === null && panelStage.panelSelected
                readonly property Item chromeTarget: win.selProxy ? win.selProxy : (win.panelMode ? panelStage.selectionItem : null)

                Behavior on pageProgress { NumberAnimation { duration: 250; easing.type: Easing.OutCubic } }

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

                function openImagePicker(itemType, itemId, currentPath, rounded) {
                    imagePickerHost.open(itemType, itemId, currentPath, rounded);
                }

                QtObject {
                    id: widgetAdder

                    function addWidget(typeKey) {
                        let t = WidgetRegistry.types[typeKey];
                        if (!t) return;
                        let fullType = "widget:" + typeKey;
                        if (WidgetRegistry.pickerFor(typeKey) || t.requiresFilePicker) {
                            win.openImagePicker(fullType, "", "", false);
                            return;
                        }
                        win.addItem(fullType, "");
                    }
                }

                Shortcut {
                    sequence: "Escape"
                    onActivated: {
                        if (toolbar.dismiss()) return;
                        root.close();
                    }
                }

                Shortcut {
                    sequence: "Left"
                    enabled: !toolbar.panelOpen
                    onActivated: win.go(-1)
                }

                Shortcut {
                    sequence: "Right"
                    enabled: !toolbar.panelOpen
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
                    readonly property real bottomH: Scaler.s(94)
                    readonly property real frameGap: ui.width * 0.03
                    readonly property real k: Math.max(0.05, Math.min(ui.width * 0.84 / win.screenW, pager.height * 0.99 / win.screenH))

                    readonly property var chromeBounds: {
                        let target = win.chromeTarget;
                        if (!target) return { x: 0, y: 0, w: 0, h: 0 };
                        win.page;
                        win.pageProgress;
                        ui.width;
                        ui.height;
                        ui.k;
                        pager.width;
                        pager.height;
                        clockFrame.x;
                        clockFrame.y;
                        clockFrame.scale;
                        panelFrame.x;
                        panelFrame.y;
                        panelFrame.scale;
                        LockLayoutStore.panelX;
                        LockLayoutStore.panelY;
                        LockLayoutStore.panelW;
                        LockLayoutStore.panelH;
                        target.x;
                        target.y;
                        target.width;
                        target.height;
                        let tl = ui.mapFromItem(target, 0, 0);
                        let br = ui.mapFromItem(target, target.width, target.height);
                        return { x: tl.x, y: tl.y, w: br.x - tl.x, h: br.y - tl.y };
                    }

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
                                onImagePickRequested: (itemType, itemId, currentPath, rounded) => win.openImagePicker(itemType, itemId, currentPath, rounded)
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
                                Component.onCompleted: scene.imagePickRequested.connect((itemType, itemId, currentPath, rounded) => win.openImagePicker(itemType, itemId, currentPath, rounded))
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

                    EditorChrome {
                        id: chrome
                        z: 100
                        active: win.chromeTarget !== null && !toolbar.panelOpen
                        dragging: win.activeScene.dragging
                        relativeToTarget: false
                        targetX: ui.chromeBounds.x
                        targetY: ui.chromeBounds.y
                        targetWidth: ui.chromeBounds.w
                        targetHeight: ui.chromeBounds.h
                        boundsWidth: ui.width
                        boundsHeight: ui.height
                        limitY: toolbar.y - Scaler.s(8)
                        selectionGap: 0
                        margin: Scaler.s(14)
                        allowSidePlacement: false

                        readonly property bool hasProxy: win.selProxy !== null
                        readonly property string pType: chrome.hasProxy ? win.selProxy.pType : ""
                        readonly property string pVariant: chrome.hasProxy ? win.selProxy.pVariant : ""

                        itemWidth: chrome.hasProxy ? win.selProxy.gW : LockLayoutStore.panelW
                        itemHeight: chrome.hasProxy ? win.selProxy.gH : LockLayoutStore.panelH
                        defaultWidth: chrome.hasProxy ? win.selProxy.getDefaultSize().w : LockLayoutStore.defaultPanelW
                        itemOpacity: chrome.hasProxy ? win.selProxy.pOpacity : LockLayoutStore.panelOpacity
                        showScale: chrome.hasProxy
                        showRotate: chrome.hasProxy
                        showReset: chrome.hasProxy
                        showDelete: chrome.hasProxy && win.selProxy.deletable
                        showBottomRow: chrome.hasProxy || win.panelMode

                        topSettings: chrome.hasProxy ? LockElementRegistry.additionalSettings(chrome.pType, "top", chrome.pVariant) : []
                        bottomSettings: chrome.hasProxy ? LockElementRegistry.additionalSettings(chrome.pType, "bottom", chrome.pVariant) : []
                        variants: chrome.hasProxy ? LockElementRegistry.variantList(chrome.pType) : []
                        currentVariant: chrome.pVariant
                        targetItem: chrome.hasProxy ? win.selProxy.faceItem : null
                        targetData: chrome.hasProxy ? win.selProxy.rowData : null
                        typeData: (chrome.hasProxy && LockElementRegistry.isWidget(chrome.pType)) ? WidgetRegistry.types[LockElementRegistry.widgetKey(chrome.pType)] : null
                        hostOwner: win.activeScene
                        settingsRevision: LockLayoutStore.revision

                        onRotateClicked: if (win.selProxy) win.selProxy.rotateItem()
                        onResetClicked: if (win.selProxy) win.selProxy.resetItemSize()
                        onDeleteClicked: win.activeScene.removeSelected()
                        onVariantSelected: (variantId) => { if (win.selProxy) win.selProxy.applyVariant(variantId); }
                        onOpacityMoved: (op) => {
                            if (win.selProxy) win.selProxy.setOpacity(op);
                            else LockLayoutStore.setPanelOpacity(op);
                        }
                        onOpacityFinished: { if (win.selProxy) win.selProxy.finalizeSync(); }
                        onSettingPropertyEdited: (propName, val) => {
                            if (win.selProxy) win.activeScene.setWidgetProperty(propName, val, win.selProxy.pId);
                        }
                        onSettingActionTriggered: (actionName) => {
                            if (win.selProxy) win.activeScene.handleAdditionalAction(actionName, win.selProxy);
                        }
                    }

                    WidgetPicker {
                        id: toolbar
                        anchors.bottom: parent.bottom
                        anchors.bottomMargin: Scaler.s(24)
                        anchors.horizontalCenter: parent.horizontalCenter
                        z: 50
                        maxWidth: ui.width - Scaler.s(48)
                        redactor: widgetAdder
                        leadingSections: [{
                            id: "lockscreen",
                            name: I18n.t("lock.redactor.category.lockscreen", "Lock screen"),
                            icon: String.fromCodePoint(0xF033E),
                            items: LockElementRegistry.lockTypeList(win.activeScene.scope)
                        }]

                        onLeadingItemActivated: (id) => win.addItem(id, "")

                        IconButton {
                            size: toolbar.controlHeight
                            cornerRadius: ThemeBackend.borderRadius
                            buttonIcon: "󰕰"
                            iconFontSize: Scaler.s(16)
                            accentColor: win.gridOn ? ThemeBackend.mauve : ThemeBackend.surface0
                            textColor: win.gridOn ? ThemeBackend.crust : ThemeBackend.text
                            onClicked: win.toggleGrid()
                        }

                        IconButton {
                            size: toolbar.controlHeight
                            cornerRadius: ThemeBackend.borderRadius
                            buttonIcon: "󰑐"
                            iconFontSize: Scaler.s(16)
                            accentColor: ThemeBackend.surface0
                            textColor: ThemeBackend.text
                            onClicked: {
                                win.activeScene.selectedId = "";
                                LockLayoutStore.resetScope(win.activeScene.scope);
                            }
                        }

                        ClickButton {
                            maxWidth: Scaler.s(100)
                            implicitHeight: toolbar.controlHeight
                            horizontalPadding: Scaler.s(14)
                            cornerRadius: ThemeBackend.borderRadius
                            buttonText: I18n.t("lock.redactor.done")
                            textFontSize: Scaler.s(12)
                            accentColor: ThemeBackend.mauve
                            textColor: ThemeBackend.crust
                            onClicked: root.close()
                        }
                    }

                    RedactorImagePickerHost {
                        id: imagePickerHost
                        rootObj: ui
                        onImagePicked: (targetType, targetId, filePath, fileName) => {
                            if (targetId !== "") {
                                LockLayoutStore.setItemProperty(targetId, "iimage", filePath);
                            } else if (filePath !== "" && targetType !== "") {
                                win.addItem(targetType, filePath);
                            }
                        }
                    }
                }
            }
        }
    }
}
