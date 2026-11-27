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

BarFaceBase {
    id: root

    property string timeStyle: {
        let dummy = configRevision;
        if (module && module.variant) return module.variant;
        return String(readSetting("timeStyle", "", "classic"));
    }

    property bool showDate: {
        let dummy = configRevision;
        if (typeof Config !== "undefined" && Config.rawSettings && Config.rawSettings.bar) {
            if (Config.rawSettings.bar.timeShowDate !== undefined) return Boolean(Config.rawSettings.bar.timeShowDate);
            if (Config.rawSettings.bar.showDate !== undefined) return Boolean(Config.rawSettings.bar.showDate);
        }
        return true;
    }

    readonly property string timeStr: (typeof DateTime !== "undefined" && DateTime.time) ? DateTime.time : (isVertical ? "14:28" : "")
    readonly property string timeOnlyStr: (typeof DateTime !== "undefined" && DateTime.timeOnly) ? DateTime.timeOnly : (isVertical ? "14:28" : "")
    readonly property string hourStr: (typeof DateTime !== "undefined" && DateTime.hours) ? DateTime.hours : "14"
    readonly property string minuteStr: (typeof DateTime !== "undefined" && DateTime.minutes) ? DateTime.minutes : "28"
    readonly property string secondStr: (typeof DateTime !== "undefined" && DateTime.seconds) ? DateTime.seconds : ""
    readonly property string ampmStr: (typeof DateTime !== "undefined" && DateTime.ampm) ? DateTime.ampm : ""
    readonly property string timeAmPmStr: (typeof DateTime !== "undefined" && DateTime.amPm) ? DateTime.amPm : ""
    readonly property string dayStr: (typeof DateTime !== "undefined" && DateTime.day) ? DateTime.day : "18"
    readonly property string monthStr: (typeof DateTime !== "undefined" && DateTime.monthShort) ? DateTime.monthShort : "Sep"
    readonly property string weekdayStr: (typeof DateTime !== "undefined" && DateTime.weekdayShort) ? DateTime.weekdayShort : ""
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
        running: root.moduleActive && barWindow && barWindow.isStartupReady && typeInIndex < fullDateStr.length
        repeat: true
        onTriggered: typeInIndex += 1
    }

    function activate() {
        root.togglePanel("calendar");
    }

    property real lengthPadding: timeStyle === "pill" ? s(isCompact ? 3 : 4) : (isVertical ? s(isCompact ? 10 : 12) : s(isCompact ? 12 : 14))
    property real targetLength: (faceLoader.item ? (isVertical ? faceLoader.item.implicitHeight : faceLoader.item.implicitWidth) : 0) + (lengthPadding * 2)

    implicitWidth: isVertical ? (parent ? parent.width : 0) : targetLength
    implicitHeight: isVertical ? targetLength : (parent ? parent.height : 0)

    MouseArea {
        id: bgMouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.activate()
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
