import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import "../"
import "../mc"

// Window for the Minecraft inventory launcher; shown instead of the stock launcher
// while LauncherController.minecraft is true.
PanelWindow {
    id: win

    readonly property bool shown: LauncherController.isVisible && LauncherController.minecraft

    screen: LauncherController.screen
    visible: shown
    focusable: shown
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.namespace: "qs-applauncher"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: shown ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    anchors { top: true; bottom: true; left: true; right: true }

    Process {
        id: rankFetcher
        command: Caching.qsDir ? ["python3", Caching.qsDir + "/launcher/app_rank.py", "--rank"] : []
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    if (this.text && this.text.trim().length > 0) view.ranks = JSON.parse(this.text);
                } catch (e) {}
            }
        }
    }

    onShownChanged: if (shown && Caching.qsDir) rankFetcher.running = true

    McInventoryView {
        id: view
        anchors.fill: parent
        open: win.shown
        onCloseRequested: LauncherController.hide()
        onLaunch: (name, desktopId) => {
            let entry = DesktopEntries.byId(desktopId);
            if (entry) entry.execute();
            if (Caching.qsDir)
                Quickshell.execDetached(["python3", Caching.qsDir + "/launcher/app_rank.py", "--log-launch", "--name", name]);
            if (typeof Sounds !== "undefined") Sounds.playSfx("reusables/clickbutton/click.wav");
            LauncherController.hide();
        }
    }
}
