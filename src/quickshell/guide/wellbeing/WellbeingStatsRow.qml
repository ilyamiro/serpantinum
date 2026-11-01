import QtQuick
import QtQuick.Layouts
import "../../"
import "../../reusables"

RowLayout {
    id: stats
    required property var tab
    readonly property var rootObj: tab.rootObj
    readonly property int diff: tab.totalSeconds - tab.yesterdaySeconds
    readonly property bool noData: tab.totalSeconds === 0 && tab.yesterdaySeconds === 0
    readonly property int limit: tab.activeLimitSeconds
    readonly property bool overLimit: limit > 0 && tab.totalSeconds >= limit
    readonly property color deltaColor: ThemeBackend.liquidGlass ? "#ffffff" : (diff > 0 ? ThemeBackend.peach : ThemeBackend.green)

    Layout.fillWidth: true
    Layout.preferredHeight: timeCard.implicitHeight
    spacing: rootObj.s(8)

    opacity: stats.tab.introStats
    transform: Translate { y: rootObj.s(30) * (1 - stats.tab.introStats) }

    Rectangle {
        id: timeCard
        Layout.fillWidth: true
        Layout.preferredWidth: rootObj.s(270)
        Layout.minimumWidth: rootObj.s(230)
        Layout.fillHeight: true
        implicitHeight: timeLayout.implicitHeight + rootObj.s(32)
        radius: ThemeBackend.borderRadius
        color: timeGlass.active ? "transparent" : Qt.alpha(ThemeBackend.surface0, 0.4)

        GlassFill {
            id: timeGlass
            anchors.fill: parent
            radius: parent.radius
            tintColor: Qt.alpha(ThemeBackend.surface0, 0.4)
            tintAmount: 0.25
        }

        ColumnLayout {
            id: timeLayout
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            anchors.margins: rootObj.s(16)
            spacing: rootObj.s(2)

            Text {
                font.family: ThemeBackend.fontFamily
                font.weight: Font.Black
                font.pixelSize: rootObj.s(38)
                color: stats.tab.textMain
                text: stats.tab.formatTimeLarge(stats.tab.animatedTotalSeconds).replace(/ /g, " ")
            }

            RowLayout {
                spacing: rootObj.s(6)

                Text {
                    visible: !stats.noData && stats.diff !== 0
                    font.family: ThemeBackend.iconFont
                    font.pixelSize: rootObj.s(15)
                    color: stats.deltaColor
                    text: stats.diff > 0 ? "󰁝" : "󰁅"
                }

                Text {
                    Layout.fillWidth: true
                    wrapMode: Text.WordWrap
                    font.family: ThemeBackend.fontFamily
                    font.weight: Font.Medium
                    font.pixelSize: rootObj.s(11)
                    color: (stats.noData || stats.diff === 0) ? stats.tab.textDim : stats.deltaColor
                    text: {
                        if (stats.noData) return I18n.t("guide.wellbeing.no_data");
                        if (stats.diff === 0) return I18n.t("guide.wellbeing.same_as_prev");
                        let t = stats.tab.formatTimeList(Math.abs(stats.diff));
                        return stats.diff > 0
                            ? I18n.t("guide.wellbeing.more_than_prev", { "time": t })
                            : I18n.t("guide.wellbeing.less_than_prev", { "time": t });
                    }
                }
            }

            ColumnLayout {
                visible: stats.limit > 0
                Layout.fillWidth: true
                Layout.topMargin: rootObj.s(10)
                spacing: rootObj.s(4)

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: rootObj.s(6)
                    radius: height / 2
                    color: ThemeBackend.surface1

                    Rectangle {
                        height: parent.height
                        width: parent.width * Math.min(1, stats.tab.totalSeconds / Math.max(1, stats.limit))
                        radius: parent.radius
                        color: stats.overLimit ? ThemeBackend.red : ThemeBackend.accent
                        Behavior on width { NumberAnimation { duration: 600; easing.type: Easing.OutQuint } }
                    }
                }

                Text {
                    Layout.fillWidth: true
                    elide: Text.ElideRight
                    font.family: ThemeBackend.fontFamily
                    font.weight: Font.Medium
                    font.pixelSize: rootObj.s(11)
                    color: stats.overLimit && !ThemeBackend.liquidGlass ? ThemeBackend.red : stats.tab.textDim
                    text: stats.overLimit
                        ? I18n.t("guide.wellbeing.limit_reached", { "limit": stats.tab.formatTimeList(stats.limit) })
                        : I18n.t("guide.wellbeing.limit_progress", { "used": stats.tab.formatTimeList(stats.tab.totalSeconds), "limit": stats.tab.formatTimeList(stats.limit) })
                }
            }
        }
    }

    Repeater {
        model: [
            { id: "peak", min: 560 },
            { id: "avg", min: 480 }
        ]

        delegate: Rectangle {
            id: card
            required property var modelData
            readonly property bool shown: stats.width >= rootObj.s(modelData.min)

            visible: shown
            Layout.fillWidth: true
            Layout.preferredWidth: rootObj.s(125)
            Layout.minimumWidth: rootObj.s(100)
            Layout.fillHeight: true
            radius: ThemeBackend.borderRadius
            color: cardGlass.active ? "transparent" : Qt.alpha(ThemeBackend.surface0, 0.4)

            GlassFill {
                id: cardGlass
                anchors.fill: parent
                radius: parent.radius
                tintColor: Qt.alpha(ThemeBackend.surface0, 0.4)
                tintAmount: 0.25
            }

            WellbeingMetric {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                anchors.margins: rootObj.s(14)
                tab: stats.tab
                caption: card.modelData.id === "peak" ? I18n.t("guide.wellbeing.peak_hour") : I18n.t("guide.wellbeing.daily_average")
                value: card.modelData.id === "peak" ? stats.tab.peakHourToday : stats.tab.formatTimeList(stats.tab.averageSeconds)
                valueSize: card.modelData.id === "peak" ? rootObj.s(14) : rootObj.s(22)
            }
        }
    }
}
