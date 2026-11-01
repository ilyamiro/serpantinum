import QtQuick
import "../../"
import "../../reusables"
import "../../widgets"

Item {
    id: miniWidgetContainer
    required property var tab
    required property string monName
    required property real previewWidth
    required property real previewHeight
    required property var modelData
    required property int index

    readonly property string typeStr: modelData.type || modelData.wType || "time"
    readonly property var defSize: (typeof WidgetRegistry !== "undefined" && typeof WidgetRegistry.defaultSize === "function")
        ? WidgetRegistry.defaultSize(typeStr)
        : ({ w: 250, h: 120 })

    readonly property string defVariant: (typeof WidgetRegistry !== "undefined" && typeof WidgetRegistry.defaultVariant === "function")
        ? WidgetRegistry.defaultVariant(typeStr)
        : "default"

    readonly property string variantStr: modelData.variant || modelData.wVariant || miniWidgetContainer.defVariant

    readonly property bool isStretchW: !!(modelData.stretchWidth || modelData.wStretchWidth)
    readonly property bool isStretchH: !!(modelData.stretchHeight || modelData.wStretchHeight)

    readonly property real rawW: modelData.w !== undefined ? modelData.w : (modelData.width !== undefined ? modelData.width : (modelData.wWidth !== undefined ? modelData.wWidth : defSize.w))
    readonly property real rawH: modelData.h !== undefined ? modelData.h : (modelData.height !== undefined ? modelData.height : (modelData.wHeight !== undefined ? modelData.wHeight : defSize.h))

    readonly property real resolvedW: isStretchW ? miniWidgetContainer.previewWidth : miniWidgetContainer.tab.resolveDimension(rawW, miniWidgetContainer.previewWidth, defSize.w)
    readonly property real resolvedH: isStretchH ? miniWidgetContainer.previewHeight : miniWidgetContainer.tab.resolveDimension(rawH, miniWidgetContainer.previewHeight, defSize.h)

    readonly property var resolvedPos: miniWidgetContainer.tab.resolvePosition(modelData, miniWidgetContainer.previewWidth, miniWidgetContainer.previewHeight, resolvedW, resolvedH)

    x: isStretchW ? 0 : resolvedPos.x
    y: isStretchH ? 0 : resolvedPos.y
    width: resolvedW
    height: resolvedH
    opacity: modelData.opacity !== undefined ? modelData.opacity : 1.0
    rotation: modelData.rotation !== undefined ? modelData.rotation : 0

    Loader {
        id: widgetFaceLoader
        anchors.fill: parent
        asynchronous: true
        source: miniWidgetContainer.tab.getFaceUrl(miniWidgetContainer.typeStr, miniWidgetContainer.variantStr)

        onLoaded: {
            if (item) {
                if ("variant" in item) item.variant = miniWidgetContainer.variantStr;
                if ("wVariant" in item) item.wVariant = miniWidgetContainer.variantStr;
                if ("type" in item) item.type = miniWidgetContainer.typeStr;
                if ("wType" in item) item.wType = miniWidgetContainer.typeStr;
                if ("wWidth" in item) item.wWidth = miniWidgetContainer.width;
                if ("wHeight" in item) item.wHeight = miniWidgetContainer.height;
                if ("imagePath" in item) item.imagePath = modelData.imagePath || modelData.wImagePath || "";
                if ("wImagePath" in item) item.wImagePath = modelData.imagePath || modelData.wImagePath || "";
                if ("previewMode" in item) item.previewMode = true;
                if ("screen" in item) item.screen = miniWidgetContainer.tab.getScreen(miniWidgetContainer.monName);
            }
        }
    }

    Rectangle {
        anchors.fill: parent
        visible: widgetFaceLoader.status === Loader.Error
        radius: ThemeBackend.borderRadius
        color: gf1.active ? "transparent" : Qt.alpha(ThemeBackend.surface0, 0.72)

        GlassFill {
            id: gf1
            anchors.fill: parent
            radius: parent.radius
            tintColor: Qt.alpha(ThemeBackend.surface0, 0.72)
            tintAmount: 0.25
        }

        readonly property var typeInfo: (typeof WidgetRegistry !== "undefined" && WidgetRegistry.types && WidgetRegistry.types[miniWidgetContainer.typeStr]) ? WidgetRegistry.types[miniWidgetContainer.typeStr] : null

        Text {
            anchors.centerIn: parent
            text: (parent.typeInfo && parent.typeInfo.icon) ? parent.typeInfo.icon : "󰕰"
            font.family: ThemeBackend.fontFamily
            font.pixelSize: Math.max(12, Math.min(parent.width * 0.4, parent.height * 0.45))
            color: ThemeBackend.accent
        }
    }
}
