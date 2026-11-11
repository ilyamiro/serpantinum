import QtQuick
import QtQuick.Layouts
import "../../"
import ".."

Loader {
    id: settingLoader

    required property var modelData
    required property var ownerProxy
    required property var faceLoader
    required property var ownerRedactor
    required property Component defaultComponent
    Layout.alignment: Qt.AlignVCenter

    readonly property var currentSetting: modelData
    readonly property var currentProxy: ownerProxy
    readonly property var currentModel: (ownerRedactor.activeWidgetsModel && ownerProxy.wIndex >= 0 && ownerProxy.wIndex < ownerRedactor.activeWidgetsModel.count) ? ownerRedactor.activeWidgetsModel.get(ownerProxy.wIndex) : null
    readonly property var currentFace: faceLoader.item

    sourceComponent: {
        if (modelData.component) return modelData.component;
        if (modelData.sourceComponent) return modelData.sourceComponent;
        if (modelData.source || modelData.file) return null;
        return defaultComponent;
    }
    source: {
        if (modelData.component || modelData.sourceComponent) return "";
        if (modelData.source) return Qt.resolvedUrl(modelData.source);
        if (modelData.file) return Qt.resolvedUrl(modelData.file);
        return "";
    }

    function setupControl() {
        if (!item) return;
        try { if (item.settingData !== undefined) item.settingData = currentSetting; } catch (e) {}
        try { if (item.typeData !== undefined) item.typeData = WidgetRegistry.types[ownerProxy.wType]; } catch (e) {}
        try { if (item.redactor !== undefined) item.redactor = ownerRedactor; } catch (e) {}
        try { if (item.proxy !== undefined) item.proxy = currentProxy; } catch (e) {}
        try { if (item.widgetProxy !== undefined) item.widgetProxy = currentProxy; } catch (e) {}
        try { if (item.widgetData !== undefined) item.widgetData = currentModel; } catch (e) {}
        try { if (item.item !== undefined) item.item = currentFace; } catch (e) {}
        try { if (item.widget !== undefined) item.widget = currentFace || currentProxy; } catch (e) {}
        try { if (item.targetWidget !== undefined) item.targetWidget = currentFace || currentProxy; } catch (e) {}
        try { if (item.activeWidgetsModel !== undefined) item.activeWidgetsModel = ownerRedactor.activeWidgetsModel; } catch (e) {}
    }

    onLoaded: setupControl()

    Connections {
        target: faceLoader
        function onItemChanged() {
            settingLoader.setupControl();
        }
    }

    Connections {
        target: ownerProxy
        function onWIndexChanged() {
            settingLoader.setupControl();
        }
        function onWVariantChanged() {
            settingLoader.setupControl();
        }
    }
}
