import QtQuick
import QtQuick.Layouts
import "../../"
import "../../reusables"

Rectangle {
    id: chart
    required property var tab
    readonly property var rootObj: tab.rootObj
    readonly property real gap: rootObj.s(3)
    readonly property var dayNames: [
        I18n.t("guide.wellbeing.days.monday"),
        I18n.t("guide.wellbeing.days.tuesday"),
        I18n.t("guide.wellbeing.days.wednesday"),
        I18n.t("guide.wellbeing.days.thursday"),
        I18n.t("guide.wellbeing.days.friday"),
        I18n.t("guide.wellbeing.days.saturday"),
        I18n.t("guide.wellbeing.days.sunday")
    ]
    property int hoverDay: -1
    property int hoverHour: -1

    function cellValue(day, hour) {
        let row = chart.tab.weekHeatmapData[day];
        return (row && row[hour]) ? row[hour] : 0;
    }

    function cellColor(val) {
        if (val <= 0) return Qt.alpha(ThemeBackend.surface1, 0.55);
        let ratio = Math.pow(Math.min(1.0, val / Math.max(chart.tab.maxWeekHour, 1)), 0.6);
        return Qt.alpha(ThemeBackend.mauve, 0.22 + 0.78 * ratio);
    }

    Layout.fillWidth: true
    Layout.preferredHeight: rootObj.s(280)
    radius: ThemeBackend.borderRadius
    color: gf8.active ? "transparent" : Qt.alpha(ThemeBackend.surface0, 0.4)

    GlassFill {
        id: gf8
        anchors.fill: parent
        radius: parent.radius
        tintColor: Qt.alpha(ThemeBackend.surface0, 0.4)
        tintAmount: 0.25
    }

    opacity: chart.tab.introMidLeft
    transform: Translate { y: rootObj.s(20) * (1 - chart.tab.introMidLeft) }

    RowLayout {
        anchors.fill: parent
        anchors.margins: rootObj.s(16)
        spacing: rootObj.s(18)

        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: rootObj.s(6)

            RowLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: rootObj.s(10)

                Column {
                    id: dayLabels
                    Layout.preferredWidth: rootObj.s(34)
                    Layout.fillHeight: true
                    spacing: chart.gap

                    Repeater {
                        model: 7
                        delegate: Text {
                            readonly property bool isTarget: chart.tab.weekData[index] ? !!chart.tab.weekData[index].is_target : false
                            width: dayLabels.width
                            height: (dayLabels.height - chart.gap * 6) / 7
                            text: chart.dayNames[index].substring(0, 3)
                            font.family: ThemeBackend.fontFamily
                            font.weight: (isTarget || chart.hoverDay === index) ? Font.Bold : Font.Medium
                            font.pixelSize: rootObj.s(11)
                            color: (isTarget || chart.hoverDay === index) ? chart.tab.textMain : chart.tab.textSub
                            verticalAlignment: Text.AlignVCenter
                            Behavior on color { ColorAnimation { duration: 150 } }
                        }
                    }
                }

                Item {
                    id: gridArea
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    readonly property real cellW: (width - chart.gap * 23) / 24
                    readonly property real cellH: (height - chart.gap * 6) / 7

                    Repeater {
                        model: 168
                        delegate: Rectangle {
                            readonly property int dayIdx: Math.floor(index / 24)
                            readonly property int hourIdx: index % 24
                            readonly property real val: chart.cellValue(dayIdx, hourIdx)
                            readonly property bool hovered: chart.hoverDay === dayIdx && chart.hoverHour === hourIdx

                            x: hourIdx * (gridArea.cellW + chart.gap)
                            y: dayIdx * (gridArea.cellH + chart.gap)
                            width: gridArea.cellW
                            height: gridArea.cellH
                            radius: Math.min(width, height) * 0.32
                            color: chart.cellColor(val)

                            scale: chart.tab.isWeekView ? 1.0 : 0.5
                            Behavior on scale {
                                NumberAnimation {
                                    duration: 400 + (dayIdx * 30) + (hourIdx * 10)
                                    easing.type: Easing.OutBack
                                }
                            }
                            Behavior on color { ColorAnimation { duration: 500; easing.type: Easing.OutQuint } }
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        function track(mx, my) {
                            let h = Math.floor(mx / (gridArea.cellW + chart.gap));
                            let d = Math.floor(my / (gridArea.cellH + chart.gap));
                            chart.hoverHour = (h >= 0 && h < 24) ? h : -1;
                            chart.hoverDay = (d >= 0 && d < 7) ? d : -1;
                        }
                        onPositionChanged: function(m) { track(m.x, m.y); }
                        onEntered: track(mouseX, mouseY)
                        onExited: { chart.hoverHour = -1; chart.hoverDay = -1; }
                    }

                    Rectangle {
                        id: tip
                        readonly property bool active: chart.hoverDay >= 0 && chart.hoverHour >= 0
                        readonly property real val: active ? chart.cellValue(chart.hoverDay, chart.hoverHour) : 0
                        visible: active
                        z: 5
                        width: tipText.implicitWidth + rootObj.s(20)
                        height: tipText.implicitHeight + rootObj.s(12)
                        radius: rootObj.s(8)
                        color: ThemeBackend.base
                        x: Math.max(0, Math.min(gridArea.width - width, (chart.hoverHour + 0.5) * (gridArea.cellW + chart.gap) - width / 2))
                        y: Math.max(0, chart.hoverDay * (gridArea.cellH + chart.gap) - height - chart.gap)

                        Text {
                            id: tipText
                            anchors.centerIn: parent
                            font.family: ThemeBackend.fontFamily
                            font.weight: Font.DemiBold
                            font.pixelSize: rootObj.s(11)
                            color: ThemeBackend.text
                            text: tip.active
                                ? chart.dayNames[chart.hoverDay] + "  " + chart.tab.formatHour(chart.hoverHour) + " - " + chart.tab.formatHour(chart.hoverHour + 1) + "  " + chart.tab.formatTimeList(tip.val)
                                : ""
                        }
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: rootObj.s(10)

                Item {
                    Layout.preferredWidth: dayLabels.width
                    Layout.preferredHeight: rootObj.s(14)
                }

                Item {
                    Layout.fillWidth: true
                    Layout.preferredHeight: rootObj.s(14)

                    Repeater {
                        model: [0, 6, 12, 18]
                        delegate: Text {
                            x: modelData * (gridArea.cellW + chart.gap)
                            font.family: ThemeBackend.fontFamily
                            font.weight: Font.Medium
                            font.pixelSize: rootObj.s(10)
                            color: chart.tab.textDim
                            text: String(modelData).padStart(2, "0") + ":00"
                        }
                    }
                }
            }

            RowLayout {
                Layout.alignment: Qt.AlignRight
                spacing: rootObj.s(4)

                Text {
                    font.family: ThemeBackend.fontFamily
                    font.weight: Font.Medium
                    font.pixelSize: rootObj.s(10)
                    color: chart.tab.textDim
                    text: I18n.t("guide.wellbeing.less")
                }

                Repeater {
                    model: [0, 0.2, 0.45, 0.7, 1.0]
                    delegate: Rectangle {
                        width: rootObj.s(10)
                        height: rootObj.s(10)
                        radius: rootObj.s(3)
                        color: modelData === 0 ? Qt.alpha(ThemeBackend.surface1, 0.55) : Qt.alpha(ThemeBackend.mauve, 0.22 + 0.78 * Math.pow(modelData, 0.6))
                    }
                }

                Text {
                    font.family: ThemeBackend.fontFamily
                    font.weight: Font.Medium
                    font.pixelSize: rootObj.s(10)
                    color: chart.tab.textDim
                    text: I18n.t("guide.wellbeing.more")
                }
            }
        }

        ColumnLayout {
            visible: chart.width >= rootObj.s(560)
            Layout.preferredWidth: rootObj.s(170)
            Layout.maximumWidth: rootObj.s(170)
            Layout.fillHeight: true
            spacing: rootObj.s(8)

            Repeater {
                model: ["avg", "total", "peak"]
                delegate: Rectangle {
                    id: tile
                    required property string modelData
                    required property int index
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    radius: ThemeBackend.borderRadius
                    color: tileGlass.active ? "transparent" : Qt.alpha(ThemeBackend.surface1, 0.35)

                    GlassFill {
                        id: tileGlass
                        anchors.fill: parent
                        radius: parent.radius
                        tintColor: Qt.alpha(ThemeBackend.surface1, 0.35)
                        tintAmount: 0.25
                    }

                    WellbeingMetric {
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.margins: rootObj.s(14)
                        tab: chart.tab
                        valueSize: tile.modelData === "peak" ? rootObj.s(16) : rootObj.s(20)
                        caption: tile.modelData === "avg" ? I18n.t("guide.wellbeing.daily_average")
                               : tile.modelData === "total" ? I18n.t("guide.wellbeing.week_total")
                               : I18n.t("guide.wellbeing.peak_hours")
                        value: tile.modelData === "avg" ? chart.tab.formatTimeList(chart.tab.averageSeconds)
                             : tile.modelData === "total" ? chart.tab.formatTimeList(chart.tab.weekTotalSeconds)
                             : chart.tab.peakUsageHours
                    }
                }
            }
        }
    }
}
