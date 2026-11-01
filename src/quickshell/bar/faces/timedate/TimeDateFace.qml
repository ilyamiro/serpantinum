import QtQuick
import QtQuick.Layouts
import QtQuick.Window
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import "../../../reusables"
import "../../../"
import "../../"

Item {
    id: root

    property var module: null
    property var widget: root

    property string orientation: module ? module.orientation : "horizontal"
    readonly property bool isVertical: orientation === "vertical"

    readonly property bool isCompact: module ? module.isCompact : false
    readonly property var barWindow: module ? module.barWindow : null
    readonly property bool isRightBar: module ? module.isRightBar : (barWindow ? (barWindow.barPosition === "right") : false)

    property int configRevision: 0

    Connections {
        target: (typeof Config !== "undefined") ? Config : null
        function onSettingsLoaded() { root.configRevision++; }
        function onRawSettingsChanged() { root.configRevision++; }
    }

    property string timeStyle: {
        let dummy = configRevision;
        if (module && module.variant) return module.variant;
        if (typeof Config !== "undefined" && Config.rawSettings && Config.rawSettings.bar) {
            if (Config.rawSettings.bar.timeStyle) return Config.rawSettings.bar.timeStyle;
        }
        return "classic";
    }

    property bool showDate: {
        let dummy = configRevision;
        if (typeof Config !== "undefined" && Config.rawSettings && Config.rawSettings.bar) {
            if (Config.rawSettings.bar.timeShowDate !== undefined) return Config.rawSettings.bar.timeShowDate;
            if (Config.rawSettings.bar.showDate !== undefined) return Config.rawSettings.bar.showDate;
        }
        return true;
    }

    readonly property string timeStr: (typeof DateTime !== "undefined" && DateTime.time) ? DateTime.time : (isVertical ? "14:28" : "")
    readonly property string timeOnlyStr: (typeof DateTime !== "undefined" && DateTime.timeOnly) ? DateTime.timeOnly : (isVertical ? "14:28" : "")
    readonly property string hourStr: (typeof DateTime !== "undefined" && DateTime.hour) ? DateTime.hour : (DateTime.time ? DateTime.time.split(":")[0] : (isVertical ? "14" : ""))
    readonly property string minuteStr: (typeof DateTime !== "undefined" && DateTime.minute) ? DateTime.minute : (DateTime.time ? DateTime.time.split(":")[1] : (isVertical ? "28" : ""))
    readonly property string secondStr: (typeof DateTime !== "undefined" && DateTime.second) ? DateTime.second : ""
    readonly property var timeAmPmStr: isVertical ? ((typeof DateTime !== "undefined" && DateTime.amPm) ? DateTime.amPm : "") : undefined
    readonly property var dayStr: isVertical ? ((typeof DateTime !== "undefined" && DateTime.day) ? DateTime.day : "18") : undefined
    readonly property var monthStr: isVertical ? ((typeof DateTime !== "undefined" && DateTime.monthShort) ? DateTime.monthShort : "Sep") : undefined
    readonly property string fullDateStr: (typeof DateTime !== "undefined" && DateTime.fullDate) ? DateTime.fullDate : (isVertical ? "Fri, Sep 18" : "")
    property int typeInIndex: 0
    property string dateStr: fullDateStr.substring(0, typeInIndex)

    onFullDateStrChanged: {
        if (typeInIndex >= fullDateStr.length) {
            typeInIndex = fullDateStr.length;
        }
    }

    Timer {
        id: typewriterTimer
        interval: 30
        running: (!module || module.moduleActive) && barWindow && barWindow.isStartupReady && typeInIndex < fullDateStr.length
        repeat: true
        onTriggered: typeInIndex += 1
    }

    function s(val) {
        if (barWindow && typeof barWindow.s === "function") return barWindow.cs(val);
        if (typeof Scaler !== "undefined" && typeof Scaler.s === "function") return Math.round(Scaler.s(val));
        return val;
    }

    property real lengthPadding: isVertical ? s(isCompact ? 10 : 12) : s(isCompact ? 12 : 14)
    property real targetLength: (faceLoader.item ? (isVertical ? faceLoader.item.implicitHeight : faceLoader.item.implicitWidth) : 0) + (lengthPadding * 2)

    implicitWidth: isVertical ? (parent ? parent.width : 0) : targetLength
    implicitHeight: isVertical ? targetLength : (parent ? parent.height : 0)

    MouseArea {
        id: bgMouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: {
            if (Caching.serpantinumDir) {
                Quickshell.execDetached(["bash", Caching.serpantinumDir + "/scripts/qs_manager.sh", "toggle", "calendar"]);
            }
        }
    }

    Loader {
        id: faceLoader
        z: 2
        anchors.centerIn: parent
        source: BarModuleRegistry.variantFaceFile("timedate", root.timeStyle)
        onLoaded: {
            if (item) item.widget = root;
        }
    }

    Binding {
        target: faceLoader.item
        property: "widget"
        value: root
    }
}
