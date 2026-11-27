pragma Singleton
import QtQuick

QtObject {
    id: root

    signal geometryChanged(string monitor, string widgetId, real x, real y, real w, real h, real opacity, real rotation)
    signal positionChanged(string monitor, string widgetId, real x, real y)
    signal opacityChanged(string monitor, string widgetId, real opacity)
    signal rotationChanged(string monitor, string widgetId, real rotation)
    signal variantChanged(string monitor, string widgetId, string variant)
    signal imagePathChanged(string monitor, string widgetId, string imagePath)
    signal propertyChanged(string monitor, string widgetId, string propName, var val)
    signal widgetAdded(string monitor, string widgetId, string type, real x, real y, real w, real h, real opacity, string imagePath, real rotation, string variant)
    signal widgetRemoved(string monitor, string widgetId)
    signal widgetsCleared(string monitor)
    signal presetApplied(string monitor, var widgetsList)
    signal bringToFrontRequested(string monitor, string widgetId)
    signal redactModeChanged(string monitor, bool active)

    function matchesMonitor(a: string, b: string): bool {
        let sa = String(a || "").trim().toLowerCase();
        let sb = String(b || "").trim().toLowerCase();
        if (sa === "" || sb === "") return false;
        if (sa === sb) return true;
        return sa.replace(/[^a-z0-9_-]/g, "_") === sb.replace(/[^a-z0-9_-]/g, "_");
    }

    function setPosition(monitor: string, widgetId: string, x: real, y: real): void {
        root.positionChanged(monitor, widgetId, x, y);
    }

    function setGeometry(monitor: string, widgetId: string, x: real, y: real, w: real, h: real, opacity: real, rotation: real): void {
        root.geometryChanged(monitor, widgetId, x, y, w, h, opacity, rotation);
    }

    function setOpacity(monitor: string, widgetId: string, opacity: real): void {
        root.opacityChanged(monitor, widgetId, opacity);
    }

    function setRotation(monitor: string, widgetId: string, rotation: real): void {
        root.rotationChanged(monitor, widgetId, rotation);
    }

    function setVariant(monitor: string, widgetId: string, variant: string): void {
        root.variantChanged(monitor, widgetId, variant);
    }

    function setImagePath(monitor: string, widgetId: string, imagePath: string): void {
        root.imagePathChanged(monitor, widgetId, imagePath);
    }

    function setProperty(monitor: string, widgetId: string, propName: string, val: var): void {
        let m = monitor;
        let id = widgetId;
        let prop = propName;
        let v = val;
        if (v === undefined && prop !== undefined) {
            v = prop;
            prop = id;
            id = m;
            m = "";
        }
        root.propertyChanged(m, id, prop, v);
    }

    function addWidget(monitor: string, widgetId: string, type: string, x: real, y: real, w: real, h: real, opacity: real, imagePath: string, rotation: real, variant: string): void {
        root.widgetAdded(monitor, widgetId, type, x, y, w, h, opacity, imagePath, rotation, variant || "");
    }

    function removeWidget(monitor: string, widgetId: string): void {
        root.widgetRemoved(monitor, widgetId);
    }

    function clearWidgets(monitor: string): void {
        root.widgetsCleared(monitor);
    }

    function applyPreset(monitor: string, widgetsList: var, clearFirst: bool): void {
        let len = (widgetsList && widgetsList.length !== undefined) ? widgetsList.length : 0;
        if (!widgetsList || len === 0) return;
        root.presetApplied(monitor, widgetsList);
    }

    function bringToFront(monitor: string, widgetId: string): void {
        root.bringToFrontRequested(monitor, widgetId);
    }

    function setRedactMode(monitor: string, active: bool): void {
        root.redactModeChanged(monitor, active);
    }
}
