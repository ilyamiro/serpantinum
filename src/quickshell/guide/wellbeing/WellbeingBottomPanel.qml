import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../../"
import "../../reusables"

Item {
    id: bottomPanel
    required property var tab
    readonly property var rootObj: tab.rootObj
    Layout.fillWidth: true
    Layout.fillHeight: false
    Layout.preferredHeight: appList.implicitHeight * (1.0 - tab.appViewFocus) + rootObj.s(300) * tab.appViewFocus

    opacity: bottomPanel.tab.introBottom
    transform: Translate { y: rootObj.s(30) * (1 - bottomPanel.tab.introBottom) }

    Column {
        id: appList
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        spacing: rootObj.s(8)

        opacity: 1.0 - bottomPanel.tab.appViewFocus
        visible: opacity > 0
        transform: Translate { x: rootObj.s(-30) * bottomPanel.tab.appViewFocus }
        scale: 0.95 + (0.05 * (1.0 - bottomPanel.tab.appViewFocus))

        Text {
            visible: bottomPanel.tab.appListModel.count === 0
            width: appList.width
            topPadding: rootObj.s(24)
            bottomPadding: rootObj.s(24)
            horizontalAlignment: Text.AlignHCenter
            font.family: ThemeBackend.fontFamily
            font.weight: Font.Medium
            font.pixelSize: rootObj.s(13)
            color: bottomPanel.tab.textDim
            text: I18n.t("guide.wellbeing.no_data")
        }

        Repeater {
            model: bottomPanel.tab.appListModel

            delegate: Rectangle {
                id: appDelegateCard
                width: appList.width
                height: rootObj.s(52)
                radius: ThemeBackend.borderRadius
                color: gfRow.active ? "transparent" : (rowMa.containsMouse ? Qt.alpha(ThemeBackend.surface1, 0.45) : Qt.alpha(ThemeBackend.surface0, 0.4))

                Behavior on color { ColorAnimation { duration: 150 } }

                transform: Translate { y: (index * rootObj.s(12)) * (1 - bottomPanel.tab.introBottom) }

                GlassFill {
                    id: gfRow
                    anchors.fill: parent
                    radius: parent.radius
                    tintColor: Qt.alpha(ThemeBackend.surface0, 0.4)
                    tintAmount: 0.25
                    press: rowMa.pressed ? 0.8 : (rowMa.containsMouse ? 0.25 : 0)
                    Behavior on press { NumberAnimation { duration: 250; easing.type: Easing.OutCubic } }
                }

                MouseArea {
                    id: rowMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        bottomPanel.tab.selectedAppClass = model.appClass;
                        bottomPanel.tab.selectedAppName = model.name;
                        bottomPanel.tab.selectedAppIcon = model.icon;
                        bottomPanel.tab.appDate = new Date();
                        bottomPanel.tab.requestDataUpdate();
                    }
                }

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: rootObj.s(12)
                    anchors.rightMargin: rootObj.s(12)
                    spacing: rootObj.s(10)

                    Rectangle {
                        id: iconWrapper
                        implicitWidth: rootObj.s(32)
                        implicitHeight: rootObj.s(32)
                        Layout.preferredWidth: rootObj.s(32)
                        Layout.preferredHeight: rootObj.s(32)
                        Layout.alignment: Qt.AlignVCenter
                        radius: Math.round(rootObj.s(32) * 0.28)
                        color: gf6.active ? "transparent" : ThemeBackend.surface0

                        GlassFill {
                            id: gf6
                            anchors.fill: parent
                            radius: parent.radius
                            tintColor: ThemeBackend.surface0
                            tintAmount: 0.25
                        }
                        clip: true

                        Image {
                            anchors.fill: parent
                            anchors.margins: rootObj.s(4)
                            fillMode: Image.PreserveAspectFit
                            asynchronous: true
                            smooth: true
                            mipmap: true
                            visible: model.icon !== "" && status === Image.Ready
                            source: {
                                let ic = model.icon || "";
                                if (!ic) return "";
                                if (ic.startsWith("file://") || ic.startsWith("image://") || ic.startsWith("http://") || ic.startsWith("https://")) return ic;
                                return ic.startsWith("/") ? "file://" + ic : "image://icon/" + ic;
                            }
                        }

                        Text {
                            anchors.centerIn: parent
                            visible: !model.icon || model.icon === ""
                            text: model.name ? model.name.charAt(0).toUpperCase() : "?"
                            font.family: ThemeBackend.fontFamily
                            font.pixelSize: rootObj.s(13)
                            font.bold: true
                            color: bottomPanel.tab.textMain
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        Layout.alignment: Qt.AlignVCenter
                        spacing: -rootObj.s(1)

                        Text {
                            Layout.fillWidth: true
                            font.family: ThemeBackend.fontFamily
                            font.weight: Font.DemiBold
                            font.pixelSize: rootObj.s(13)
                            color: bottomPanel.tab.textMain
                            text: model.name
                            elide: Text.ElideRight
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: rootObj.s(8)

                            Item {
                                Layout.fillWidth: true
                                Layout.alignment: Qt.AlignVCenter
                                height: rootObj.s(10)
                                Rectangle {
                                    anchors.fill: parent
                                    radius: rootObj.s(5)
                                    color: pbTrack1.active ? "transparent" : ThemeBackend.surface1

                                    GlassFill {
                                        id: pbTrack1
                                        anchors.fill: parent
                                        radius: parent.radius
                                        tintColor: ThemeBackend.surface1
                                        tintAmount: 0.22
                                    }
                                }
                                Item {
                                    height: parent.height
                                    width: Math.max(rootObj.s(10), parent.width * (model.percent / 100.0) * bottomPanel.tab.introAppBars)
                                    Behavior on width {
                                        enabled: bottomPanel.tab.introAppBars === 1.0
                                        NumberAnimation { duration: 600; easing.type: Easing.OutQuint }
                                    }

                                    Rectangle {
                                        anchors.fill: parent
                                        radius: rootObj.s(5)
                                        color: ThemeBackend.mauve
                                        visible: !pbFill1.active
                                    }

                                    GlassFill {
                                        id: pbFill1
                                        anchors.fill: parent
                                        radius: rootObj.s(5)
                                        forceClear: true
                                        tintColor: ThemeBackend.mauve
                                        tintAmount: 0.6
                                        tintStrength: 1.0
                                    }
                                }
                            }

                            ClickButton {
                                enabled: false
                                Layout.alignment: Qt.AlignVCenter
                                Layout.preferredHeight: rootObj.s(25)
                                horizontalPadding: rootObj.s(8)
                                cornerRadius: Math.min(ThemeBackend.borderRadius, rootObj.s(6))
                                textFontSize: rootObj.s(13)
                                accentColor: Qt.alpha(ThemeBackend.surface1, 0.7)
                                textColor: bottomPanel.tab.textSub
                                buttonText: bottomPanel.tab.formatTimeList(model.seconds)
                            }
                        }
                    }
                }
            }
        }
    }

    Rectangle {
        id: appChartCard
        anchors.fill: parent
        radius: ThemeBackend.borderRadius
        color: gf7.active ? "transparent" : Qt.alpha(ThemeBackend.surface0, 0.4)

        GlassFill {
            id: gf7
            anchors.fill: parent
            radius: parent.radius
            tintColor: Qt.alpha(ThemeBackend.surface0, 0.4)
            tintAmount: 0.25
        }

        opacity: bottomPanel.tab.appViewFocus
        visible: opacity > 0
        transform: Translate { x: rootObj.s(30) * (1 - bottomPanel.tab.appViewFocus) }
        scale: 0.95 + (0.05 * bottomPanel.tab.appViewFocus)

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: rootObj.s(12)
            spacing: rootObj.s(10)

            RowLayout {
                Layout.alignment: Qt.AlignHCenter
                spacing: rootObj.s(6)

                IconButton {
                    enabled: false
                    size: rootObj.s(22)
                    Layout.preferredWidth: rootObj.s(22)
                    Layout.preferredHeight: rootObj.s(22)
                    cornerRadius: ThemeBackend.borderRadius
                    buttonIcon: "󰘖"
                    iconFontSize: rootObj.s(13)
                    accentColor: ThemeBackend.surface0
                    textColor: bottomPanel.tab.textAccent
                }

                Text {
                    font.family: ThemeBackend.fontFamily
                    font.weight: Font.DemiBold
                    font.pixelSize: rootObj.s(13)
                    color: bottomPanel.tab.textMain
                    text: I18n.t("guide.wellbeing.daily_usage")
                }
            }

            RowLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: rootObj.s(3)

                Repeater {
                    model: 48
                    delegate: Item {
                        Layout.fillWidth: true
                        Layout.fillHeight: true

                        Rectangle {
                            anchors.bottom: parent.bottom
                            width: parent.width
                            height: Math.max(rootObj.s(4), parent.height * fill)
                            radius: rootObj.s(2)
                            readonly property real hourValue: (bottomPanel && bottomPanel.tab) ? (bottomPanel.tab.hourlyData[index] || 0) : 0
                            property real fill: (bottomPanel && bottomPanel.tab) ? (hourValue / Math.max(bottomPanel.tab.maxHourlyTotal, 1)) * bottomPanel.tab.introAppBars : 0
                            color: hourGlass.active ? "transparent" : (hourValue > 0 ? ThemeBackend.blue : ThemeBackend.surface1)

                            GlassFill {
                                id: hourGlass
                                anchors.fill: parent
                                radius: parent.radius
                                forceClear: parent.hourValue > 0
                                tintColor: parent.hourValue > 0 ? ThemeBackend.blue : ThemeBackend.surface1
                                tintAmount: parent.hourValue > 0 ? 0.6 : 0.22
                                tintStrength: 1.0
                            }

                            Behavior on fill {
                                enabled: bottomPanel.tab.introAppBars === 1.0 && !bottomPanel.tab.hourlyCleared
                                NumberAnimation { duration: 600; easing.type: Easing.OutQuint }
                            }
                            Behavior on color { ColorAnimation { duration: 400 } }

                            MouseArea {
                                anchors.fill: parent
                                hoverEnabled: true
                                onEntered: { parent.opacity = 0.7 }
                                onExited: { parent.opacity = 1.0 }
                            }
                        }
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                Text { font.family: ThemeBackend.fontFamily; font.weight: Font.Medium; font.pixelSize: rootObj.s(10); color: bottomPanel.tab.textDim; text: "00:00" }
                Item { Layout.fillWidth: true }
                Text { font.family: ThemeBackend.fontFamily; font.weight: Font.Medium; font.pixelSize: rootObj.s(10); color: bottomPanel.tab.textDim; text: "06:00" }
                Item { Layout.fillWidth: true }
                Text { font.family: ThemeBackend.fontFamily; font.weight: Font.Medium; font.pixelSize: rootObj.s(10); color: bottomPanel.tab.textDim; text: "12:00" }
                Item { Layout.fillWidth: true }
                Text { font.family: ThemeBackend.fontFamily; font.weight: Font.Medium; font.pixelSize: rootObj.s(10); color: bottomPanel.tab.textDim; text: "18:00" }
                Item { Layout.fillWidth: true }
                Text { font.family: ThemeBackend.fontFamily; font.weight: Font.Medium; font.pixelSize: rootObj.s(10); color: bottomPanel.tab.textDim; text: "23:00" }
            }
        }
    }
}
