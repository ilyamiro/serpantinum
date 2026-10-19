import QtQuick
import QtQuick.Window
import QtQuick.Layouts
import "../"
import "../reusables"

ColumnLayout {
    required property var screenRoot
    anchors.fill: parent
    anchors.margins: screenRoot.s(14)
    spacing: screenRoot.s(8)

    Item {
        id: weatherBoxFaceContainer
        Layout.fillWidth: true
        Layout.preferredHeight: screenRoot.s(182)
        clip: true

        property string currentHex: Weather.currentHex
        property color accentColor: (currentHex && currentHex.length === 7) ? currentHex : ThemeBackend.mauve

        Rectangle {
            anchors.fill: parent
            anchors.topMargin: screenRoot.s(1.5)
            anchors.bottomMargin: -screenRoot.s(1.5)
            radius: screenRoot.s(16)
            color: Qt.rgba(0, 0, 0, 0.14)
        }

        Rectangle {
            anchors.fill: parent
            radius: screenRoot.s(16)
            color: ThemeBackend.faded(Qt.lighter(ThemeBackend.surface0, 1.28))
            border.width: ThemeBackend.liquidGlass ? 0 : 1
            border.color: Qt.rgba(ThemeBackend.text.r, ThemeBackend.text.g, ThemeBackend.text.b, 0.06)

            WallpaperBlur {
                z: -1
                anchors.fill: parent
                radius: parent.radius
                screenOverride: screenRoot.surface.screen
                useSnapshot: true
                standalone: true
            }
        }

        LoaderIcon {
            anchors.centerIn: parent
            width: screenRoot.s(36)
            height: width
            accentColor: ThemeBackend.mauve
            running: Weather.isLoading || !Weather.isReady
            visible: Weather.isLoading || !Weather.isReady
        }

        RowLayout {
            anchors.fill: parent
            anchors.topMargin: screenRoot.s(12)
            anchors.bottomMargin: screenRoot.s(12)
            anchors.leftMargin: screenRoot.s(14)
            anchors.rightMargin: screenRoot.s(14)
            spacing: screenRoot.s(10)
            visible: !(Weather.isLoading || !Weather.isReady)

            ColumnLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.preferredWidth: 1
                spacing: 0

                Text {
                    text: Weather.currentIcon !== "" ? Weather.currentIcon : ""
                    font.family: ThemeBackend.fontFamily
                    font.pixelSize: screenRoot.s(46)
                    color: weatherBoxFaceContainer.accentColor
                    Layout.alignment: Qt.AlignTop | Qt.AlignLeft
                    transform: Translate { y: -screenRoot.s(4) }
                }

                Item {
                    Layout.fillHeight: true
                }

                ColumnLayout {
                    Layout.alignment: Qt.AlignBottom | Qt.AlignLeft
                    spacing: screenRoot.s(1)

                    Text {
                        text: Weather.currentTemp !== "" ? Math.round(parseFloat(Weather.currentTemp)) + "°" : "--°"
                        font.family: ThemeBackend.fontFamily
                        font.pixelSize: screenRoot.s(34)
                        font.weight: Font.Black
                        color: ThemeBackend.text
                        elide: Text.ElideRight
                    }

                    Text {
                        text: I18n.t("calendar.weather.feels") + " " + screenRoot.getFeelsLike()
                        font.family: ThemeBackend.fontFamily
                        font.pixelSize: screenRoot.s(10.5)
                        font.weight: Font.Medium
                        color: ThemeBackend.subtext0
                        elide: Text.ElideRight
                    }
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.preferredWidth: 1.3
                spacing: 0

                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignTop | Qt.AlignRight
                    spacing: screenRoot.s(1)

                    Text {
                        text: (typeof Location !== "undefined" && Location.city && Location.city !== "") ? Location.city : (Weather.data && Weather.data.city ? Weather.data.city : "Unknown")
                        font.family: ThemeBackend.fontFamily
                        font.pixelSize: screenRoot.s(13.5)
                        font.weight: Font.Bold
                        color: ThemeBackend.text
                        horizontalAlignment: Text.AlignRight
                        Layout.fillWidth: true
                        elide: Text.ElideRight
                    }

                    Text {
                        text: Weather.data && Weather.data.forecast && Weather.data.forecast[0] && Weather.data.forecast[0].desc ? Weather.data.forecast[0].desc : (Weather.data && Weather.data.desc ? Weather.data.desc : "")
                        font.family: ThemeBackend.fontFamily
                        font.pixelSize: screenRoot.s(11)
                        font.weight: Font.Medium
                        color: ThemeBackend.subtext0
                        horizontalAlignment: Text.AlignRight
                        Layout.fillWidth: true
                        elide: Text.ElideRight
                    }
                }

                Item {
                    Layout.fillHeight: true
                }

                RowLayout {
                    Layout.alignment: Qt.AlignBottom | Qt.AlignRight
                    spacing: screenRoot.s(8)

                    Repeater {
                        model: screenRoot.hourlyForecastList
                        delegate: ColumnLayout {
                            Layout.alignment: Qt.AlignHCenter | Qt.AlignBottom
                            spacing: screenRoot.s(2)

                            Text {
                                text: Math.round(parseFloat(modelData.temp)) + "°"
                                color: ThemeBackend.subtext0
                                font.family: ThemeBackend.fontFamily
                                font.pixelSize: screenRoot.s(11.5)
                                font.weight: Font.Medium
                                Layout.alignment: Qt.AlignHCenter
                                horizontalAlignment: Text.AlignHCenter
                                transform: Translate { x: 2 }
                            }

                            Text {
                                text: modelData.icon
                                color: modelData.hex && modelData.hex.length === 7 ? modelData.hex : weatherBoxFaceContainer.accentColor
                                font.family: ThemeBackend.fontFamily
                                font.pixelSize: screenRoot.s(20)
                                Layout.alignment: Qt.AlignHCenter
                                horizontalAlignment: Text.AlignHCenter
                                transform: Translate { x: -2 }
                            }

                            Text {
                                text: screenRoot.formatHour(modelData.time)
                                color: ThemeBackend.subtext0
                                font.family: ThemeBackend.fontFamily
                                font.pixelSize: screenRoot.s(9.5)
                                font.weight: Font.Normal
                                Layout.alignment: Qt.AlignHCenter
                                horizontalAlignment: Text.AlignHCenter
                            }
                        }
                    }
                }
            }
        }
    }

    Item {
        id: systemUsageBox
        Layout.fillWidth: true
        Layout.fillHeight: true

        property real sp: screenRoot.s(8)
        function cellX(mx) { return (mx * width) + (mx > 0 ? sp / 2 : 0); }
        function cellY(my) { return (my * height) + (my > 0 ? sp / 2 : 0); }
        function cellW(mx, mw) { return (mw * width) - ((mx > 0 ? sp / 2 : 0) + ((mx + mw) < 0.99 ? sp / 2 : 0)); }
        function cellH(my, mh) { return (mh * height) - ((my > 0 ? sp / 2 : 0) + ((my + mh) < 0.99 ? sp / 2 : 0)); }

        SystemUsageCard {
            x: systemUsageBox.cellX(0.0)
            y: systemUsageBox.cellY(0.0)
            width: systemUsageBox.cellW(0.0, 0.333)
            height: systemUsageBox.cellH(0.0, 0.5)
            value: screenRoot.cpuUsage
            colorBase: Qt.lighter(ThemeBackend.surface0, 1.28)
            colorFill: Qt.lighter(ThemeBackend.mauve, 1.35)
            icon: "\uF2DB"
            title: I18n.t("quickactions.systemusage.cpu")
            valueText: Math.round(screenRoot.cpuUsage * 100) + "%"
            isLive: screenRoot.wingsReveal > 0.98
            hasShadow: true
            compact: true
            bgOpacity: ThemeBackend.elementOpacity
        }

        SystemUsageCard {
            x: systemUsageBox.cellX(0.333)
            y: systemUsageBox.cellY(0.0)
            width: systemUsageBox.cellW(0.333, 0.334)
            height: systemUsageBox.cellH(0.0, 0.5)
            value: screenRoot.ramUsage
            colorBase: Qt.lighter(ThemeBackend.surface0, 1.28)
            colorFill: Qt.lighter(ThemeBackend.mauve, 1.15)
            icon: "\uF538"
            title: I18n.t("quickactions.systemusage.ram")
            valueText: screenRoot.ramUsedGb.toFixed(1) + "G"
            isLive: screenRoot.wingsReveal > 0.98
            hasShadow: true
            compact: true
            bgOpacity: ThemeBackend.elementOpacity
        }

        SystemUsageCard {
            x: systemUsageBox.cellX(0.667)
            y: systemUsageBox.cellY(0.0)
            width: systemUsageBox.cellW(0.667, 0.333)
            height: systemUsageBox.cellH(0.0, 0.5)
            value: Math.max(0.0, Math.min(1.0, screenRoot.tempC / 100.0))
            colorBase: Qt.lighter(ThemeBackend.surface0, 1.28)
            colorFill: ThemeBackend.mauve
            icon: "\uF2C9"
            title: I18n.t("quickactions.systemusage.temp")
            valueText: Math.round(screenRoot.tempC) + "°"
            isLive: screenRoot.wingsReveal > 0.98
            hasShadow: true
            compact: true
            bgOpacity: ThemeBackend.elementOpacity
        }

        SystemUsageCard {
            x: systemUsageBox.cellX(0.0)
            y: systemUsageBox.cellY(0.5)
            width: systemUsageBox.cellW(0.0, 0.5)
            height: systemUsageBox.cellH(0.5, 0.5)
            value: screenRoot.diskUsagePercent
            colorBase: Qt.lighter(ThemeBackend.surface0, 1.28)
            colorFill: Qt.darker(ThemeBackend.mauve, 1.15)
            icon: "\uF0A0"
            title: screenRoot.diskTotalText
            subText: screenRoot.diskUsedText
            valueText: Math.round(screenRoot.diskUsagePercent * 100) + "%"
            isLive: screenRoot.wingsReveal > 0.98
            hasShadow: true
            compact: true
            bgOpacity: ThemeBackend.elementOpacity
        }

        SystemUsageCard {
            x: systemUsageBox.cellX(0.5)
            y: systemUsageBox.cellY(0.5)
            width: systemUsageBox.cellW(0.5, 0.5)
            height: systemUsageBox.cellH(0.5, 0.5)
            value: 0.12
            colorBase: Qt.lighter(ThemeBackend.surface0, 1.28)
            colorFill: Qt.darker(ThemeBackend.mauve, 1.35)
            icon: "󰤨"
            title: I18n.t("quickactions.systemusage.net")
            valueText: ""
            isLive: screenRoot.wingsReveal > 0.98
            hasShadow: true
            compact: true
            bgOpacity: ThemeBackend.elementOpacity

            ColumnLayout {
                anchors.centerIn: parent
                spacing: screenRoot.s(6)

                Rectangle {
                    Layout.preferredHeight: screenRoot.s(26)
                    Layout.preferredWidth: screenRoot.s(108)
                    radius: screenRoot.s(13)
                    color: lockNetGlassA.active ? "transparent" : Qt.rgba(ThemeBackend.surface1.r, ThemeBackend.surface1.g, ThemeBackend.surface1.b, 0.5 * ThemeBackend.elementOpacity)

                    GlassFill {
                        id: lockNetGlassA
                        anchors.fill: parent
                        radius: parent.radius
                        tintColor: ThemeBackend.surface1
                        tintAmount: 0.3
                    }

                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: screenRoot.s(3)
                        spacing: screenRoot.s(5)

                        IconButton {
                            size: Math.round(screenRoot.s(20))
                            cornerRadius: Math.round(screenRoot.s(10))
                            buttonIcon: "\uF063"
                            iconFontSize: Math.round(screenRoot.s(11))
                            accentColor: Qt.rgba(ThemeBackend.green.r, ThemeBackend.green.g, ThemeBackend.green.b, 0.25)
                            bgOpacity: ThemeBackend.elementOpacity
                            textColor: ThemeBackend.green
                            enabled: false
                        }

                        Text {
                            Layout.fillWidth: true
                            text: screenRoot.rxSpeedStr
                            color: ThemeBackend.text
                            font.family: ThemeBackend.fontFamily
                            font.pixelSize: screenRoot.s(11)
                            font.bold: true
                        }
                    }
                }

                Rectangle {
                    Layout.preferredHeight: screenRoot.s(26)
                    Layout.preferredWidth: screenRoot.s(108)
                    radius: screenRoot.s(13)
                    color: lockNetGlassB.active ? "transparent" : Qt.rgba(ThemeBackend.surface1.r, ThemeBackend.surface1.g, ThemeBackend.surface1.b, 0.5 * ThemeBackend.elementOpacity)

                    GlassFill {
                        id: lockNetGlassB
                        anchors.fill: parent
                        radius: parent.radius
                        tintColor: ThemeBackend.surface1
                        tintAmount: 0.3
                    }

                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: screenRoot.s(3)
                        spacing: screenRoot.s(5)

                        IconButton {
                            size: Math.round(screenRoot.s(20))
                            cornerRadius: Math.round(screenRoot.s(10))
                            buttonIcon: "\uF062"
                            iconFontSize: Math.round(screenRoot.s(11))
                            accentColor: Qt.rgba(ThemeBackend.peach.r, ThemeBackend.peach.g, ThemeBackend.peach.b, 0.25)
                            bgOpacity: ThemeBackend.elementOpacity
                            textColor: ThemeBackend.peach
                            enabled: false
                        }

                        Text {
                            Layout.fillWidth: true
                            text: screenRoot.txSpeedStr
                            color: ThemeBackend.text
                            font.family: ThemeBackend.fontFamily
                            font.pixelSize: screenRoot.s(11)
                            font.bold: true
                        }
                    }
                }
            }
        }
    }
}
