import QtQuick
import Quickshell
import Quickshell.Io
import "widgets"
import "notifications/weather"
import "notifications/battery"

ShellRoot {
    id: shellRoot

    readonly property bool performanceMode: !!(Config.getSetting("general.performance", false))
    readonly property bool quickactionsEnabled: Config.getSetting("general.quickactions", true) !== false
    readonly property bool dockEnabled: Config.getSetting("dock.enabled", true) !== false
    property bool clipboardLoaded: false
    property bool dashboardLoaded: false

    Connections {
        target: ClipboardController
        function onIsVisibleChanged() {
            if (ClipboardController.isVisible) shellRoot.clipboardLoaded = true;
        }
    }

    Connections {
        target: DashboardController
        function onIsVisibleChanged() {
            if (DashboardController.isVisible) shellRoot.dashboardLoaded = true;
        }
    }

    Connections {
        target: Quickshell
        function onReloadCompleted() { Quickshell.inhibitReloadPopup() }
        function onReloadFailed(errorString) { Quickshell.inhibitReloadPopup() }
    }

    LazyLoader {
        id: screenshotLoader
        ScreenshotOverlay {}
    }

    function ensureScreenshotOverlay() {
        if (!screenshotLoader.item) screenshotLoader.active = true;
        return screenshotLoader.item;
    }

    IpcHandler {
        target: "screenshotOverlay"

        function toggle(img: string, editMode: string, audioPrefs: string, cGeom: string, cGeomVideo: string, cMode: string, cBackend: string, targetMon: string): void {
            let overlay = ensureScreenshotOverlay();
            if (overlay) overlay.toggleOverlay(img, editMode, audioPrefs, cGeom, cGeomVideo, cMode, cBackend, targetMon);
        }

        function activate(img: string, editMode: string, audioPrefs: string, cGeom: string, cGeomVideo: string, cMode: string, cBackend: string, targetMon: string): void {
            let overlay = ensureScreenshotOverlay();
            if (overlay) overlay.activate(img, editMode, audioPrefs, cGeom, cGeomVideo, cMode, cBackend, targetMon);
        }

        function deactivate(): void {
            if (screenshotLoader.item) screenshotLoader.item.deactivate();
        }

        function colorPicker(img: string, targetMon: string): void {
            let overlay = ensureScreenshotOverlay();
            if (overlay) overlay.toggleColorPicker(img, targetMon);
        }
    }

    Main {}
    Bar {}
    Lock {}
    WidgetRedactor {}
    LockRedactor {}

    Launcher {}
    LazyLoader {
        active: shellRoot.clipboardLoaded
        Clipboard {}
    }
    LazyLoader {
        active: shellRoot.dashboardLoaded
        Dashboard {}
    }

    LazyLoader {
        active: PolkitService.isActive
        Polkit {}
    }
    WellbeingLimitOverlay {}
    PopoutManager {}

    Loader {
        active: dockEnabled
        sourceComponent: Dock {}
    }

    Idle {
        id: idleService
        Component.onCompleted: ShellRouter.registerIdle(idleService)
        Component.onDestruction: ShellRouter.unregisterIdle(idleService)
    }
    Variants {
        model: performanceMode ? [] : Quickshell.screens
        delegate: WidgetLoader {
            required property var modelData
            screen: modelData
            monitorName: modelData.name
        }
    }
    Loader {
        active: !performanceMode
        sourceComponent: WallpaperEngine {}
    }
    Loader {
        active: !performanceMode && quickactionsEnabled
        sourceComponent: Floating {}
    }

    Component.onCompleted: {
        Qt.application.organization = "serpantinum";
        Qt.application.domain = "serpantinum.org";
        Qt.application.name = "serpantinum";
        FirstLaunch.checkFirstLaunch();
        SysNotif.checkBattery();
        WeatherAlerts.isQuietNow();
        GovAlerts.refresh();
        DailyPing.start();
    }
}
