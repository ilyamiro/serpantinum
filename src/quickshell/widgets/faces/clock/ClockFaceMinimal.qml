import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import "../../../reusables"
import "../../../"

/**
 * DesktopClock.qml
 * Custom styled retro clock using strictly defined local color schemes.
 */
Item {
    id: root

    property real minWidth: Scaler.s(320)
    property real minHeight: Scaler.s(110)
    property real maxWidth: Scaler.s(600)
    property real maxHeight: Scaler.s(400)
    property real minAspect: 1.2
    property real maxAspect: 5.0
    property bool isRound: false

    anchors.fill: parent
    clip: true

    // State & Settings - Set default theme to your custom choice
    property bool isLocked: false
    property string clockTheme: "retro"    // "retro", "cyberpunk", "cream"
    property string clockLang: "en"         // "en" o "es"
    property bool is24h: true
    property real scaleFactor: 1.0

    // Font family fallback
    readonly property string mainFont: "Outfit, sans-serif"

    SystemClock {
        id: sysClock
        precision: SystemClock.Seconds
    }

    // Date Translations
    readonly property var monthsEN: [
        "JANUARY", "FEBRUARY", "MARCH", "APRIL", "MAY", "JUNE",
        "JULY", "AUGUST", "SEPTEMBER", "OCTOBER", "NOVEMBER", "DECEMBER"
    ]
    readonly property var monthsES: [
        "ENERO", "FEBRERO", "MARZO", "ABRIL", "MAYO", "JUNIO",
        "JULIO", "AGOSTO", "SEPTIEMBRE", "OCTUBRE", "NOVIEMBRE", "DICIEMBRE"
    ]
    readonly property var daysEN: [
        "Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"
    ]
    readonly property var daysES: [
        "Domingo", "Lunes", "Martes", "Miércoles", "Jueves", "Viernes", "Sábado"
    ]

    // Time & Date String Formatters
    readonly property string hoursStr: {
        var h = sysClock.date.getHours();
        if (!root.is24h) {
            h = h % 12;
            if (h === 0) h = 12;
        }
        return (h < 10 ? "0" : "") + h;
    }
    readonly property string minutesStr: String(sysClock.date.getMinutes()).padStart(2, '0')
    readonly property string secondsStr: String(sysClock.date.getSeconds()).padStart(2, '0')
    readonly property string monthStr: root.clockLang === "es" ? monthsES[sysClock.date.getMonth()] : monthsEN[sysClock.date.getMonth()]
    readonly property string dayNumberStr: String(sysClock.date.getDate())
    readonly property string dayOfWeekStr: root.clockLang === "es" ? daysES[sysClock.date.getDay()] : daysEN[sysClock.date.getDay()]

    // Strictly custom theme colors — completely detached from ThemeBackend
    readonly property color bgColor: {
        if (root.clockTheme === "cyberpunk") return "#0d1117";
        if (root.clockTheme === "cream") return "#f5ebe0";
        return "#1D3D37"; // Retro Forest Background
    }

    readonly property color bgBorderColor: {
        if (root.clockTheme === "cyberpunk") return "#00ffcc";
        if (root.clockTheme === "cream") return "#e3d5ca";
        return "#142C27"; // Retro Forest Border
    }

    readonly property color hoursColor: {
         return "#0000FF"; // Warm Peach Digits
    }

    readonly property color secondsColor: {
        return "#FF0000"; // Warm Peach Seconds
    }

    readonly property color colonColor: {
        return "#00FF00"; // Pastel Sage Dots
    }

    readonly property color dividerColor: {
        if (root.clockTheme === "cyberpunk") return "#00ffcc";
        if (root.clockTheme === "cream") return "#d5bdaf";
        return "#D8BC9D"; // Soft Sand Divider
    }

    readonly property color dayOfWeekColor: {
        if (root.clockTheme === "cyberpunk") return "#8be9fd";
        if (root.clockTheme === "cream") return "#7f6a55";
        return "#9FBDB2"; // Muted Sage Text
    }

    Rectangle {
        id: clockCard
        anchors.centerIn: parent
        width: Math.min(parent.width * 0.95, Scaler.s(318) * root.scaleFactor)
        height: Math.min(parent.height * 0.90, Scaler.s(106) * root.scaleFactor)
        radius: Scaler.s(20) * root.scaleFactor
        color: root.bgColor
        border.width: 1.5
        border.color: root.bgBorderColor

        layer.enabled: true
        layer.effect: MultiEffect {
            shadowEnabled: true
            shadowColor: "#000000"
            shadowVerticalOffset: Scaler.s(1.5)
            shadowBlur: 0.35
            shadowOpacity: 0.45
        }

        Row {
            anchors.centerIn: parent
            spacing: 0

            // 1. Time Display
            Row {
                anchors.verticalCenter: parent.verticalCenter
                spacing: Scaler.s(7) * root.scaleFactor

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.hoursStr
                    font.family: root.mainFont
                    font.pixelSize: Math.round(Scaler.s(52) * root.scaleFactor)
                    font.weight: Font.ExtraBold
                    color: root.hoursColor
                }

                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: Scaler.s(10) * root.scaleFactor

                    Rectangle {
                        width: Scaler.s(6) * root.scaleFactor
                        height: Scaler.s(6) * root.scaleFactor
                        radius: Scaler.s(2) * root.scaleFactor
                        color: root.colonColor
                    }
                    Rectangle {
                        width: Scaler.s(6) * root.scaleFactor
                        height: Scaler.s(6) * root.scaleFactor
                        radius: Scaler.s(2) * root.scaleFactor
                        color: root.colonColor
                    }
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.minutesStr
                    font.family: root.mainFont
                    font.pixelSize: Math.round(Scaler.s(52) * root.scaleFactor)
                    font.weight: Font.ExtraBold
                    color: root.digitsColor
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.secondsStr
                    font.family: root.mainFont
                    font.pixelSize: Math.round(Scaler.s(20) * root.scaleFactor)
                    font.weight: Font.ExtraBold
                    color: root.secondsColor
                }
            }

            Item { width: Scaler.s(16) * root.scaleFactor; height: 1 }

            // 2. Vertical Divider
            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: Scaler.s(2) * root.scaleFactor
                height: Scaler.s(48) * root.scaleFactor
                radius: 1
                color: root.dividerColor
            }

            Item { width: Scaler.s(14) * root.scaleFactor; height: 1 }

            // 3. Date Block
            Column {
                anchors.verticalCenter: parent.verticalCenter
                spacing: Scaler.s(1) * root.scaleFactor

                Text {
                    text: root.monthStr
                    font.family: root.mainFont
                    font.pixelSize: Math.round(Scaler.s(10) * root.scaleFactor)
                    font.weight: Font.Bold
                    font.letterSpacing: Scaler.s(2) * root.scaleFactor
                    color: root.digitsColor
                }

                Text {
                    text: root.dayNumberStr
                    font.family: root.mainFont
                    font.pixelSize: Math.round(Scaler.s(26) * root.scaleFactor)
                    font.weight: Font.ExtraBold
                    color: root.digitsColor
                }

                Text {
                    text: root.dayOfWeekStr
                    font.family: root.mainFont
                    font.pixelSize: Math.round(Scaler.s(10) * root.scaleFactor)
                    font.weight: Font.DemiBold
                    color: root.dayOfWeekColor
                }
            }
        }
    }
}
