import QtQuick
import QtQuick.Layouts
import "../../widgets"
import "."

Repeater {
    id: rep

    property string row: "top"
    property string widgetKey: ""
    property string elementType: ""
    property var proxy: null
    property var scene: null
    property Component buttonComponent: null

    model: {
        if (!rep.proxy) return [];
        if (rep.widgetKey !== "") return WidgetRegistry.additionalSettings(rep.widgetKey, rep.row, rep.proxy.pVariant);
        return LockElementRegistry.additionalSettings(rep.elementType, rep.row);
    }

    delegate: Loader {
        id: settingLoader
        Layout.alignment: Qt.AlignVCenter

        readonly property var currentSetting: modelData

        sourceComponent: {
            if (modelData.component) return modelData.component;
            if (modelData.sourceComponent) return modelData.sourceComponent;
            if (modelData.source || modelData.file) return null;
            return rep.buttonComponent;
        }
        source: {
            if (modelData.component || modelData.sourceComponent) return "";
            if (modelData.source) return Qt.resolvedUrl(modelData.source);
            if (modelData.file) return Qt.resolvedUrl(modelData.file);
            return "";
        }

        function setupControl() {
            if (!item || !rep.proxy || !rep.scene) return;
            let proxy = rep.proxy;
            let face = proxy.faceItem;
            let rowData = rep.scene.itemsModel.get(proxy.pIndex);
            try { if (item.settingData !== undefined) item.settingData = settingLoader.currentSetting; } catch (e) {}
            try { if (item.typeData !== undefined) item.typeData = WidgetRegistry.types[rep.widgetKey]; } catch (e) {}
            try { if (item.redactor !== undefined) item.redactor = rep.scene; } catch (e) {}
            try { if (item.proxy !== undefined) item.proxy = proxy; } catch (e) {}
            try { if (item.widgetProxy !== undefined) item.widgetProxy = proxy; } catch (e) {}
            try { if (item.widgetData !== undefined) item.widgetData = rowData; } catch (e) {}
            try { if (item.item !== undefined) item.item = face; } catch (e) {}
            try { if (item.widget !== undefined) item.widget = face || proxy; } catch (e) {}
            try { if (item.targetWidget !== undefined) item.targetWidget = face || proxy; } catch (e) {}
            try { if (item.activeWidgetsModel !== undefined) item.activeWidgetsModel = rep.scene.itemsModel; } catch (e) {}
        }

        onLoaded: setupControl()

        Connections {
            target: rep
            function onProxyChanged() { settingLoader.setupControl(); }
        }

        Connections {
            target: rep.proxy
            ignoreUnknownSignals: true
            function onFaceItemChanged() { settingLoader.setupControl(); }
        }
    }
}
