import QtQuick
import QtQuick.Layouts
import "../../"
import "../../reusables"

RowLayout {
    id: stats
    required property var tab
    readonly property var rootObj: tab.rootObj
    Layout.fillWidth: true
    Layout.preferredHeight: rootObj.s(64)
    Layout.maximumHeight: rootObj.s(64)
    Layout.minimumHeight: rootObj.s(64)
    spacing: rootObj.s(6)

    opacity: stats.tab.introStats
    transform: Translate { y: rootObj.s(30) * (1 - stats.tab.introStats) }

    Rectangle {
        Layout.fillWidth: true
        Layout.fillHeight: true
        Layout.preferredWidth: rootObj.s(190)
        radius: ThemeBackend.borderRadius
        color: gf1.active ? "transparent" : Qt.alpha(ThemeBackend.surface0, 0.4)

        GlassFill {
            id: gf1
            anchors.fill: parent
            radius: parent.radius
            tintColor: Qt.alpha(ThemeBackend.surface0, 0.4)
            tintAmount: 0.25
        }
        border.color: Qt.alpha(ThemeBackend.surface1, 0.3)
        border.width: ThemeBackend.liquidGlass ? 0 : 1

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: rootObj.s(14)
            anchors.rightMargin: rootObj.s(14)
            spacing: rootObj.s(10)

            IconButton {
                enabled: false
                size: rootObj.s(36)
                Layout.preferredWidth: rootObj.s(36)
                Layout.preferredHeight: rootObj.s(36)
                Layout.alignment: Qt.AlignVCenter
                cornerRadius: ThemeBackend.borderRadius
                buttonIcon: "󰔛"
                iconFontSize: rootObj.s(19)
                accentColor: ThemeBackend.surface0
                textColor: "#ffffff"
            }

            Text {
                Layout.alignment: Qt.AlignVCenter
                font.family: ThemeBackend.fontFamily
                font.weight: Font.Bold
                font.pixelSize: rootObj.s(20)
                color: stats.tab.textMain
                text: stats.tab.formatTimeList(stats.tab.averageSeconds)
            }

            ColumnLayout {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignVCenter
                spacing: 0

                Text {
                    font.family: ThemeBackend.fontFamily
                    font.weight: Font.DemiBold
                    font.pixelSize: rootObj.s(12)
                    color: stats.tab.textSub
                    text: I18n.t("guide.wellbeing.daily_average")
                    elide: Text.ElideRight
                }

                Text {
                    font.family: ThemeBackend.fontFamily
                    font.weight: Font.Medium
                    font.pixelSize: rootObj.s(11)
                    color: stats.tab.textDim
                    text: stats.tab.weekRangeStr
                    visible: stats.tab.weekRangeStr !== ""
                    elide: Text.ElideRight
                }
            }
        }
    }

    Rectangle {
        Layout.fillWidth: true
        Layout.fillHeight: true
        Layout.preferredWidth: rootObj.s(260)
        radius: ThemeBackend.borderRadius
        color: gf2.active ? "transparent" : Qt.alpha(ThemeBackend.surface0, 0.5)

        GlassFill {
            id: gf2
            anchors.fill: parent
            radius: parent.radius
            tintColor: Qt.alpha(ThemeBackend.surface0, 0.5)
            tintAmount: 0.25
        }
        border.color: Qt.alpha(ThemeBackend.surface1, 0.4)
        border.width: ThemeBackend.liquidGlass ? 0 : 1

        Text {
            anchors.centerIn: parent
            font.family: ThemeBackend.fontFamily
            font.weight: Font.Black
            font.pixelSize: rootObj.s(30)
            color: stats.tab.textMain
            text: stats.tab.formatTimeLarge(stats.tab.animatedTotalSeconds)
        }
    }

    Rectangle {
        Layout.fillWidth: true
        Layout.fillHeight: true
        Layout.preferredWidth: rootObj.s(190)
        radius: ThemeBackend.borderRadius
        color: gf3.active ? "transparent" : Qt.alpha(ThemeBackend.surface0, 0.4)

        GlassFill {
            id: gf3
            anchors.fill: parent
            radius: parent.radius
            tintColor: Qt.alpha(ThemeBackend.surface0, 0.4)
            tintAmount: 0.25
        }
        border.color: Qt.alpha(ThemeBackend.surface1, 0.3)
        border.width: ThemeBackend.liquidGlass ? 0 : 1

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: rootObj.s(14)
            anchors.rightMargin: rootObj.s(14)
            spacing: rootObj.s(12)

            IconButton {
                enabled: false
                size: rootObj.s(36)
                Layout.preferredWidth: rootObj.s(36)
                Layout.preferredHeight: rootObj.s(36)
                Layout.alignment: Qt.AlignVCenter
                cornerRadius: ThemeBackend.borderRadius
                buttonIcon: {
                    let diff = stats.tab.totalSeconds - stats.tab.yesterdaySeconds;
                    return diff > 0 ? "󰁝" : "󰁅";
                }
                iconFontSize: rootObj.s(19)
                accentColor: ThemeBackend.surface0
                textColor: {
                    let diff = stats.tab.totalSeconds - stats.tab.yesterdaySeconds;
                    return diff > 0 ? ThemeBackend.peach : ThemeBackend.green;
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignVCenter
                spacing: 0

                RowLayout {
                    spacing: rootObj.s(4)
                    visible: !(stats.tab.totalSeconds === 0 && stats.tab.yesterdaySeconds === 0) && stats.tab.totalSeconds !== stats.tab.yesterdaySeconds

                    Text {
                        font.family: ThemeBackend.fontFamily
                        font.weight: Font.Bold
                        font.pixelSize: rootObj.s(20)
                        color: {
                            if (ThemeBackend.liquidGlass) return "#ffffff";
                            let diff = stats.tab.totalSeconds - stats.tab.yesterdaySeconds;
                            return diff > 0 ? ThemeBackend.peach : ThemeBackend.green;
                        }
                        text: stats.tab.formatTimeList(Math.abs(stats.tab.totalSeconds - stats.tab.yesterdaySeconds))
                    }
                }

                Text {
                    font.family: ThemeBackend.fontFamily
                    font.weight: Font.DemiBold
                    font.pixelSize: rootObj.s(13)
                    color: stats.tab.textDim
                    text: (stats.tab.totalSeconds === 0 && stats.tab.yesterdaySeconds === 0) ? I18n.t("guide.wellbeing.no_data") : I18n.t("guide.wellbeing.same_time")
                    visible: (stats.tab.totalSeconds === 0 && stats.tab.yesterdaySeconds === 0) || stats.tab.totalSeconds === stats.tab.yesterdaySeconds
                    elide: Text.ElideRight
                }
            }
        }
    }
}
