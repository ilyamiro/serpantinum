import QtQuick
import QtQuick.Layouts
import "../../"
import "../../reusables"

Rectangle {
    id: chart
    required property var tab
    readonly property var rootObj: tab.rootObj
    Layout.fillWidth: true
    Layout.preferredHeight: rootObj.s(230)
    radius: ThemeBackend.borderRadius
    color: gf8.active ? "transparent" : Qt.alpha(ThemeBackend.surface0, 0.4)

    GlassFill {
        id: gf8
        anchors.fill: parent
        radius: parent.radius
        tintColor: Qt.alpha(ThemeBackend.surface0, 0.4)
        tintAmount: 0.25
    }
    border.color: Qt.alpha(ThemeBackend.surface1, 0.3)
    border.width: ThemeBackend.liquidGlass ? 0 : 1

    opacity: chart.tab.introMidLeft
    transform: Translate { y: rootObj.s(20) * (1 - chart.tab.introMidLeft) }

    RowLayout {
        anchors.fill: parent
        anchors.margins: rootObj.s(12)
        spacing: rootObj.s(12)

        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: rootObj.s(8)

            opacity: chart.tab.introMidLeft
            transform: Translate { x: rootObj.s(-20) * (1 - chart.tab.introMidLeft) }

            Column {
                Layout.preferredWidth: rootObj.s(65)
                Layout.fillHeight: true
                spacing: rootObj.s(3)

                Repeater {
                    model: 7
                    delegate: Text {
                        width: parent.width
                        height: (parent.height - rootObj.s(3) * 6) / 7
                        text: [
                            I18n.t("guide.wellbeing.days.monday"),
                            I18n.t("guide.wellbeing.days.tuesday"),
                            I18n.t("guide.wellbeing.days.wednesday"),
                            I18n.t("guide.wellbeing.days.thursday"),
                            I18n.t("guide.wellbeing.days.friday"),
                            I18n.t("guide.wellbeing.days.saturday"),
                            I18n.t("guide.wellbeing.days.sunday")
                        ][index]
                        font.family: ThemeBackend.fontFamily
                        font.weight: Font.Normal
                        font.pixelSize: rootObj.s(11)
                        color: chart.tab.textSub
                        verticalAlignment: Text.AlignVCenter
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                radius: ThemeBackend.borderRadius
                color: "transparent"
                clip: true

                Column {
                    anchors.fill: parent
                    spacing: rootObj.s(3)

                    Repeater {
                        model: 7
                        delegate: Item {
                            property int dayIndex: index
                            width: parent.width
                            height: (parent.height - rootObj.s(3) * 6) / 7

                            Row {
                                anchors.fill: parent
                                spacing: 0

                                Repeater {
                                    model: 24
                                    delegate: Rectangle {
                                        width: parent.width / 24
                                        height: parent.height
                                        radius: 0

                                        property real val: (chart && chart.tab && chart.tab.weekHeatmapData[dayIndex] && chart.tab.weekHeatmapData[dayIndex][index]) ? chart.tab.weekHeatmapData[dayIndex][index] : 0
                                        property real intensity: Math.min(1.0, 0.2 + 0.8 * (val / Math.max((chart && chart.tab) ? chart.tab.maxWeekHour : 1, 1)))
                                        color: weekCellGlass.active ? "transparent" : (val === 0 ? ThemeBackend.surface1 : Qt.rgba(ThemeBackend.mauve.r, ThemeBackend.mauve.g, ThemeBackend.mauve.b, intensity))

                                        GlassFill {
                                            id: weekCellGlass
                                            anchors.fill: parent
                                            radius: parent.radius
                                            forceClear: parent.val > 0
                                            tintColor: parent.val > 0 ? ThemeBackend.mauve : ThemeBackend.surface1
                                            tintAmount: parent.val > 0 ? 0.25 + 0.45 * parent.intensity : 0.22
                                            tintStrength: 1.0
                                        }

                                        scale: (chart && chart.tab && chart.tab.isWeekView) ? 1.0 : 0.5
                                        Behavior on scale {
                                            NumberAnimation {
                                                duration: 400 + (dayIndex * 30) + (index * 10)
                                                easing.type: Easing.OutBack
                                            }
                                        }
                                        Behavior on color { ColorAnimation { duration: 600; easing.type: Easing.OutQuint } }

                                        MouseArea {
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            onEntered: parent.opacity = 0.7
                                            onExited: parent.opacity = 1.0
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }

        ColumnLayout {
            Layout.preferredWidth: rootObj.s(170)
            Layout.maximumWidth: rootObj.s(170)
            Layout.fillHeight: true
            spacing: rootObj.s(8)

            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                radius: ThemeBackend.borderRadius
                color: gf9.active ? "transparent" : Qt.alpha(ThemeBackend.surface1, 0.35)

                GlassFill {
                    id: gf9
                    anchors.fill: parent
                    radius: parent.radius
                    tintColor: Qt.alpha(ThemeBackend.surface1, 0.35)
                    tintAmount: 0.25
                }
                border.color: Qt.alpha(ThemeBackend.surface2, 0.35)
                border.width: ThemeBackend.liquidGlass ? 0 : 1

                RowLayout {
                    anchors.centerIn: parent
                    spacing: rootObj.s(8)

                    IconButton {
                        enabled: false
                        size: rootObj.s(32)
                        Layout.preferredWidth: rootObj.s(32)
                        Layout.preferredHeight: rootObj.s(32)
                        cornerRadius: ThemeBackend.borderRadius
                        buttonIcon: "󰔛"
                        iconFontSize: rootObj.s(16)
                        accentColor: ThemeBackend.surface0
                        textColor: "#ffffff"
                    }

                    ColumnLayout {
                        spacing: rootObj.s(2)
                        Text {
                            font.family: ThemeBackend.fontFamily
                            font.weight: Font.Medium
                            font.pixelSize: rootObj.s(11)
                            color: chart.tab.textSub
                            text: I18n.t("guide.wellbeing.daily_average")
                        }
                        Text {
                            font.family: ThemeBackend.fontFamily
                            font.weight: Font.Bold
                            font.pixelSize: rootObj.s(16)
                            color: chart.tab.textMain
                            text: chart.tab.formatTimeList(chart.tab.averageSeconds)
                        }
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                radius: ThemeBackend.borderRadius
                color: gf10.active ? "transparent" : Qt.alpha(ThemeBackend.surface1, 0.35)

                GlassFill {
                    id: gf10
                    anchors.fill: parent
                    radius: parent.radius
                    tintColor: Qt.alpha(ThemeBackend.surface1, 0.35)
                    tintAmount: 0.25
                }
                border.color: Qt.alpha(ThemeBackend.surface2, 0.35)
                border.width: ThemeBackend.liquidGlass ? 0 : 1

                RowLayout {
                    anchors.centerIn: parent
                    spacing: rootObj.s(8)

                    IconButton {
                        enabled: false
                        size: rootObj.s(32)
                        Layout.preferredWidth: rootObj.s(32)
                        Layout.preferredHeight: rootObj.s(32)
                        cornerRadius: ThemeBackend.borderRadius
                        buttonIcon: "󰥔"
                        iconFontSize: rootObj.s(16)
                        accentColor: ThemeBackend.surface0
                        textColor: chart.tab.textAccent
                    }

                    ColumnLayout {
                        spacing: rootObj.s(2)
                        Text {
                            font.family: ThemeBackend.fontFamily
                            font.weight: Font.Medium
                            font.pixelSize: rootObj.s(11)
                            color: chart.tab.textSub
                            text: I18n.t("guide.wellbeing.peak_hours")
                        }
                        Text {
                            font.family: ThemeBackend.fontFamily
                            font.weight: Font.Bold
                            font.pixelSize: rootObj.s(13)
                            color: chart.tab.textMain
                            text: chart.tab.peakUsageHours
                        }
                    }
                }
            }
        }
    }
}
