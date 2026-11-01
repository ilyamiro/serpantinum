import QtQuick
import QtQuick.Layouts
import "../../"
import "../../reusables"

RowLayout {
    id: middleSection
    required property var tab
    readonly property var rootObj: tab.rootObj

    Layout.fillWidth: true
    Layout.preferredHeight: rootObj.s(200)
    Layout.fillHeight: false
    spacing: rootObj.s(8)

    Rectangle {
        Layout.fillWidth: true
        Layout.fillHeight: true
        Layout.preferredWidth: rootObj.s(440)
        radius: ThemeBackend.borderRadius
        color: gf4.active ? "transparent" : Qt.alpha(ThemeBackend.surface0, 0.4)

        GlassFill {
            id: gf4
            anchors.fill: parent
            radius: parent.radius
            tintColor: Qt.alpha(ThemeBackend.surface0, 0.4)
            tintAmount: 0.25
        }

        opacity: middleSection.tab.introMidLeft
        transform: Translate { x: rootObj.s(-30) * (1 - middleSection.tab.introMidLeft) }

        Text {
            id: weekTitle
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.topMargin: rootObj.s(12)
            anchors.leftMargin: rootObj.s(14)
            font.family: ThemeBackend.fontFamily
            font.weight: Font.DemiBold
            font.pixelSize: rootObj.s(13)
            color: middleSection.tab.textMain
            text: middleSection.tab.weekRangeStr
        }

        RowLayout {
            anchors.top: weekTitle.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.margins: rootObj.s(10)
            spacing: rootObj.s(8)

            Repeater {
                model: middleSection.tab.weekListModel
                delegate: Item {
                    Layout.fillHeight: true
                    Layout.fillWidth: true

                    MouseArea {
                        id: barMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: middleSection.tab.changeToDate(model.dateStr);
                    }

                    Item {
                        anchors.bottom: dayLbl.top
                        anchors.bottomMargin: rootObj.s(6)
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.margins: rootObj.s(4)
                        height: Math.max(rootObj.s(4), (parent.height - rootObj.s(42)) * (model.total / Math.max(middleSection.tab.maxWeekTotal, 1)) * middleSection.tab.introAppBars)
                        Behavior on height {
                            enabled: middleSection.tab.introAppBars === 1.0
                            NumberAnimation { duration: 600; easing.type: Easing.OutQuint }
                        }

                        Rectangle {
                            anchors.fill: parent
                            radius: rootObj.s(3)
                            color: ThemeBackend.surface2
                            visible: !model.isTarget && !weekBarGlass.active
                            opacity: barMa.containsMouse ? 0.7 : 1.0
                            Behavior on color { ColorAnimation { duration: 400; easing.type: Easing.OutCubic } }
                        }

                        Rectangle {
                            anchors.fill: parent
                            radius: rootObj.s(3)
                            visible: model.isTarget && !weekBarGlass.active
                            opacity: barMa.containsMouse ? 0.7 : 1.0
                            gradient: Gradient {
                                GradientStop { position: 0.0; color: ThemeBackend.mauve }
                                GradientStop { position: 1.0; color: ThemeBackend.blue }
                            }
                        }

                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            anchors.bottom: parent.top
                            anchors.bottomMargin: rootObj.s(4)
                            visible: model.total > 0 && (barMa.containsMouse || model.isTarget)
                            font.family: ThemeBackend.fontFamily
                            font.weight: Font.DemiBold
                            font.pixelSize: rootObj.s(11)
                            color: model.isTarget ? middleSection.tab.textMain : middleSection.tab.textSub
                            text: middleSection.tab.formatTimeList(model.total)
                        }

                        GlassFill {
                            id: weekBarGlass
                            anchors.fill: parent
                            radius: rootObj.s(3)
                            forceClear: model.isTarget
                            tintColor: model.isTarget ? ThemeBackend.mauve : ThemeBackend.surface2
                            tintAmount: model.isTarget ? 0.6 : 0.22
                            tintStrength: 1.0
                            opacity: barMa.containsMouse ? 0.7 : 1.0
                        }
                    }

                    Text {
                        id: dayLbl
                        anchors.bottom: parent.bottom
                        anchors.horizontalCenter: parent.horizontalCenter
                        font.family: ThemeBackend.fontFamily
                        font.weight: Font.DemiBold
                        font.pixelSize: rootObj.s(11)
                        color: ThemeBackend.liquidGlass ? "#ffffff" : (model.isTarget ? ThemeBackend.text : ThemeBackend.overlay0)
                        text: model.dayName
                        Behavior on color { ColorAnimation { duration: 400 } }
                    }
                }
            }
        }
    }

    Rectangle {
        visible: middleSection.width >= rootObj.s(600)
        Layout.fillWidth: true
        Layout.fillHeight: true
        Layout.preferredWidth: rootObj.s(260)
        radius: ThemeBackend.borderRadius
        color: gf5.active ? "transparent" : Qt.alpha(ThemeBackend.surface0, 0.4)

        GlassFill {
            id: gf5
            anchors.fill: parent
            radius: parent.radius
            tintColor: Qt.alpha(ThemeBackend.surface0, 0.4)
            tintAmount: 0.25
        }

        opacity: middleSection.tab.introMidRight
        transform: Translate { x: rootObj.s(30) * (1 - middleSection.tab.introMidRight) }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: rootObj.s(10)
            spacing: rootObj.s(6)

            RowLayout {
                Layout.alignment: Qt.AlignHCenter
                spacing: rootObj.s(6)

                Text {
                    font.family: ThemeBackend.fontFamily
                    font.weight: Font.DemiBold
                    font.pixelSize: rootObj.s(13)
                    color: middleSection.tab.textMain
                    text: middleSection.tab.monthNames[middleSection.tab.activeDate.getMonth()] + " " + middleSection.tab.activeDate.getFullYear()
                }
            }

            Grid {
                Layout.alignment: Qt.AlignCenter
                columns: 7
                flow: Grid.LeftToRight
                spacing: rootObj.s(6)

                Repeater {
                    model: middleSection.tab.monthListModel
                    delegate: Rectangle {
                        width: rootObj.s(22)
                        height: rootObj.s(22)
                        radius: rootObj.s(3)
                        property real intensity: Math.min(1.0, 0.3 + 0.7 * (model.total / middleSection.tab.maxMonthTotal))
                        color: monthGlass.active || model.total === -1 ? "transparent" : (model.total === 0 ? ThemeBackend.surface2 : Qt.rgba(ThemeBackend.mauve.r, ThemeBackend.mauve.g, ThemeBackend.mauve.b, intensity))
                        Behavior on color { ColorAnimation { duration: 700; easing.type: Easing.OutQuint } }


                        GlassFill {
                            id: monthGlass
                            anchors.fill: parent
                            radius: parent.radius
                            forceClear: model.total > 0
                            tintColor: model.total > 0 ? ThemeBackend.mauve : ThemeBackend.surface2
                            tintAmount: model.total > 0 ? 0.25 + 0.45 * parent.intensity : 0.22
                            tintStrength: 1.0
                        }

                        Rectangle {
                            anchors.fill: parent
                            radius: parent.radius
                            color: "transparent"
                        }

                        visible: model.total !== -1
                        scale: 0.7 + (0.3 * middleSection.tab.introMidRight)

                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            enabled: model.total !== -1
                            onClicked: {
                                if (model.total !== -1) {
                                    middleSection.tab.changeToDate(model.dateStr);
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
