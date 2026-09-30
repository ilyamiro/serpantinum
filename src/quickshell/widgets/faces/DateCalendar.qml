import QtQuick
import QtQuick.Layouts
import "../../"

Item {
    id: root
    anchors.fill: parent
    clip: true

    property real minWidth: 170
    property real minHeight: 200
    property real maxWidth: 520
    property real maxHeight: 640
    property real minAspect: 0.72
    property real maxAspect: 2.2

    readonly property var now: DateTime.now
    readonly property int year: now.getFullYear()
    readonly property int month: now.getMonth()
    readonly property int today: now.getDate()

    function daysInMonth(y, m) {
        return new Date(y, m + 1, 0).getDate();
    }

    // Monday-first column of the first day of the month
    readonly property int leadingBlanks: (new Date(year, month, 1).getDay() + 6) % 7
    readonly property int dayCount: daysInMonth(year, month)
    readonly property int cellCount: Math.ceil((leadingBlanks + dayCount) / 7) * 7
    readonly property int rowCount: cellCount / 7
    readonly property int firstDay: 1 - leadingBlanks

    readonly property var weekdayInitials: {
        const locale = Qt.locale(I18n.currentLang);
        const out = [];
        // 2024-01-01 fell on a Monday, so this walks Mon -> Sun in order
        for (let i = 0; i < 7; i++) {
            const name = new Date(2024, 0, 1 + i).toLocaleDateString(locale, "ddd");
            out.push(name.charAt(0).toUpperCase());
        }
        return out;
    }

    Rectangle {
        anchors.fill: parent
        radius: ThemeBackend.clampedBorderRadius
        color: ThemeBackend.surface0
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Math.max(12, Math.min(root.width, root.height) * 0.09)
        spacing: root.height * 0.03

        RowLayout {
            Layout.fillWidth: true
            Layout.bottomMargin: root.height * 0.01
            spacing: 0

            Text {
                Layout.fillWidth: true
                text: DateTime.month
                font.family: ThemeBackend.fontFamily
                font.pixelSize: Math.max(12, root.height * 0.058)
                font.weight: Font.Bold
                font.letterSpacing: 1.2
                color: ThemeBackend.text
                elide: Text.ElideRight
            }

            Text {
                text: DateTime.year
                font.family: ThemeBackend.fontFamily
                font.pixelSize: Math.max(10, root.height * 0.046)
                font.weight: Font.DemiBold
                color: ThemeBackend.subtext0
            }
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: root.height * 0.05
            Layout.bottomMargin: root.height * 0.02
            spacing: 0

            Repeater {
                model: root.weekdayInitials
                delegate: Text {
                    required property var modelData
                    required property int index
                    Layout.fillWidth: true
                    text: modelData
                    font.family: ThemeBackend.fontFamily
                    font.pixelSize: Math.max(9, root.height * 0.036)
                    font.weight: Font.DemiBold
                    color: index > 4 ? ThemeBackend.subtext0 : ThemeBackend.mauve
                    horizontalAlignment: Text.AlignHCenter
                }
            }
        }

        Item {
            id: gridHost
            Layout.fillWidth: true
            Layout.fillHeight: true

            // Keep cells close to square in wide layouts, otherwise a landscape
            // widget would stretch each column across the whole width.
            readonly property real cellH: Math.min(height / root.rowCount, width / 7)
            readonly property real cellW: Math.min(width / 7, cellH * 1.8)

            Grid {
                id: dayGrid
                anchors.centerIn: parent
                columns: 7
                rows: root.rowCount

                Repeater {
                    model: root.cellCount
                    delegate: Item {
                        id: cell
                        required property int index

                        implicitWidth: gridHost.cellW
                        implicitHeight: gridHost.cellH

                        readonly property int dayNumber: root.firstDay + index
                        readonly property bool inMonth: dayNumber >= 1 && dayNumber <= root.dayCount
                        readonly property bool isToday: inMonth && dayNumber === root.today
                        readonly property bool isWeekend: index % 7 > 4

                        Rectangle {
                            anchors.centerIn: parent
                            width: Math.min(parent.width, parent.height) * 0.8
                            height: width
                            radius: ThemeBackend.borderRadius
                            color: cell.isToday ? ThemeBackend.mauve : "transparent"
                            border.width: 1
                            border.color: cell.isToday ? ThemeBackend.mauve : Qt.alpha(ThemeBackend.text, 0.05)
                        }

                        Text {
                            anchors.centerIn: parent
                            width: parent.width
                            height: parent.height
                            text: cell.inMonth ? cell.dayNumber : ""
                            font.family: ThemeBackend.fontFamily
                            font.pixelSize: cell.height * 0.44
                            fontSizeMode: Text.Fit
                            minimumPixelSize: 8
                            font.weight: cell.isToday ? Font.Bold : Font.Normal
                            color: cell.isToday ? ThemeBackend.crust : (cell.inMonth ? (cell.isWeekend ? ThemeBackend.subtext0 : ThemeBackend.text) : "transparent")
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                        }
                    }
                }
            }
        }
    }
}
