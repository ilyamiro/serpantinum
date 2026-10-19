import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../../"
import "../../reusables"

Item {
    id: details
    required property var tab
    readonly property var rootObj: tab.rootObj
    Layout.fillWidth: true
    Layout.fillHeight: true

    opacity: details.tab.introBottom
    transform: Translate { y: rootObj.s(30) * (1 - details.tab.introBottom) }

    ListView {
        id: weekAppList
        anchors.fill: parent
        spacing: rootObj.s(6)
        model: details.tab.weekAppListModel
        interactive: true
        clip: true

        move: Transition { NumberAnimation { properties: "x,y"; duration: 400; easing.type: Easing.OutQuint } }

        ScrollBar.vertical: ScrollBar {
            active: weekAppList.moving || weekAppList.movingVertically
            width: rootObj.s(4)
            policy: ScrollBar.AsNeeded
            contentItem: Rectangle { implicitWidth: rootObj.s(4); radius: rootObj.s(2); color: ThemeBackend.surface2 }
        }

        delegate: Rectangle {
            id: weekAppDelegateCard
            width: ListView.view.width - (weekAppList.contentHeight > weekAppList.height ? rootObj.s(8) : 0)
            height: rootObj.s(52)
            radius: ThemeBackend.borderRadius
            color: gfWeekRow.active ? "transparent" : (weekRowMa.containsMouse ? Qt.alpha(ThemeBackend.surface1, 0.45) : Qt.alpha(ThemeBackend.surface0, 0.4))
            border.color: weekRowMa.containsMouse ? Qt.alpha(ThemeBackend.surface2, 0.45) : Qt.alpha(ThemeBackend.surface1, 0.3)
            border.width: ThemeBackend.liquidGlass ? 0 : 1

            Behavior on color { ColorAnimation { duration: 150 } }
            Behavior on border.color { ColorAnimation { duration: 150 } }

            transform: Translate { y: (index * rootObj.s(12)) * (1 - details.tab.introBottom) }

            GlassFill {
                id: gfWeekRow
                anchors.fill: parent
                radius: parent.radius
                tintColor: Qt.alpha(ThemeBackend.surface0, 0.4)
                tintAmount: 0.25
                press: weekRowMa.pressed ? 0.8 : (weekRowMa.containsMouse ? 0.25 : 0)
                Behavior on press { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
            }

            MouseArea {
                id: weekRowMa
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    details.tab.selectedAppClass = model.appClass;
                    details.tab.selectedAppName = model.name;
                    details.tab.selectedAppIcon = model.icon;
                    details.tab.appDate = new Date();
                    details.tab.isWeekView = false;
                    details.tab.requestDataUpdate();
                }
            }

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: rootObj.s(12)
                anchors.rightMargin: rootObj.s(12)
                spacing: rootObj.s(10)

                Rectangle {
                    implicitWidth: rootObj.s(32)
                    implicitHeight: rootObj.s(32)
                    Layout.preferredWidth: rootObj.s(32)
                    Layout.preferredHeight: rootObj.s(32)
                    Layout.alignment: Qt.AlignVCenter
                    radius: Math.round(rootObj.s(32) * 0.28)
                    color: gf11.active ? "transparent" : ThemeBackend.surface0

                    GlassFill {
                        id: gf11
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
                        color: details.tab.textMain
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
                        color: details.tab.textMain
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
                                color: pbTrack2.active ? "transparent" : ThemeBackend.surface1

                                GlassFill {
                                    id: pbTrack2
                                    anchors.fill: parent
                                    radius: parent.radius
                                    tintColor: ThemeBackend.surface1
                                    tintAmount: 0.22
                                }
                            }
                            Item {
                                height: parent.height
                                width: Math.max(rootObj.s(10), parent.width * (model.percent / 100.0) * details.tab.introAppBars)
                                Behavior on width {
                                    enabled: details.tab.introAppBars === 1.0
                                    NumberAnimation { duration: 600; easing.type: Easing.OutQuint }
                                }

                                Rectangle {
                                    anchors.fill: parent
                                    radius: rootObj.s(5)
                                    color: ThemeBackend.mauve
                                    visible: !pbFill2.active
                                }

                                GlassFill {
                                    id: pbFill2
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
                            textColor: details.tab.textSub
                            buttonText: details.tab.formatTimeList(model.seconds)
                        }
                    }
                }
            }
        }
    }
}
