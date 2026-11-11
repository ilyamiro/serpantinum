import QtQuick
import Quickshell
import Quickshell.Io
import "../../"
import ".."

Scope {
    id: root

    property bool isActive: false
    property string targetMonitorName: ""
    property string targetSelectedWidgetId: ""
    readonly property var activeWidgetsModel: (redactorWindowLoader.item && redactorWindowLoader.item.activeWidgetsModel) ? redactorWindowLoader.item.activeWidgetsModel : null

    function open(mon, widgetId) {
        root.targetMonitorName = (mon && typeof mon === "string") ? mon.trim() : "";
        root.targetSelectedWidgetId = (widgetId && typeof widgetId === "string") ? widgetId.trim() : "";

        if (redactorWindowLoader.item) {
            let win = redactorWindowLoader.item;
            if (root.targetMonitorName !== "" && win.monitorName !== root.targetMonitorName) {
                win.monitorName = root.targetMonitorName;
            }
            if (win.redactorMode) {
                win.redactorMode.selectedId = root.targetSelectedWidgetId;
            }
        }

        root.isActive = true;

        if (Caching.runDir) {
            Quickshell.execDetached(["bash", "-c", "rm -f '" + Caching.runDir + "/redactor_selected_widget' '" + Caching.runDir + "/redactor_target_monitor'"]);
        }
    }

    function close() {
        if (redactorWindowLoader.item && redactorWindowLoader.item.redactorMode) {
            redactorWindowLoader.item.redactorMode.selectedId = "";
        }
        root.targetSelectedWidgetId = "";
        root.targetMonitorName = "";
        root.isActive = false;

        if (Caching.runDir) {
            Quickshell.execDetached(["bash", "-c", "rm -f '" + Caching.runDir + "/redactor_selected_widget' '" + Caching.runDir + "/redactor_target_monitor'"]);
        }
    }

    function toggle(mon, widgetId) {
        if (root.isActive) {
            root.close();
        } else {
            root.open(mon, widgetId);
        }
    }

    IpcHandler {
        target: "redactor"

        function activate(): void {
            root.open("", "");
        }

        function open(mon: string, widgetId: string): void {
            root.open(mon, widgetId);
        }

        function toggle(): void {
            root.toggle("", "");
        }

        function close(): void {
            root.close();
        }
    }

    IpcHandler {
        target: "widget-redactor"

        function activate(): void {
            root.open("", "");
        }

        function open(mon: string, widgetId: string): void {
            root.open(mon, widgetId);
        }

        function toggle(): void {
            root.toggle("", "");
        }

        function close(): void {
            root.close();
        }
    }

    Loader {
        id: redactorWindowLoader
        active: root.isActive

        sourceComponent: Component {
            RedactorWindow {
                host: root
            }
        }
    }
}
