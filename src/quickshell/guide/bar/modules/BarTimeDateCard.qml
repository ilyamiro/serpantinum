import QtQuick
import QtQuick.Layouts
import "../../../"
import "../../../reusables"
import "../../../reusables/guide"

BarModuleCard {
    id: card
    title: I18n.t("guide.bar.modules.timedate.name", "Time & date")
    moduleId: "timedate"
    showPreview: false
    styles: card.tab.timeStyles
    currentStyle: card.tab.timeStyle
    styleSettingId: "bar_timedate_style"
    styleKeywords: "classic material badge time date clock style"
    styleIcon: "󰥔"
    styleTitle: I18n.t("guide.bar.timedate.style.title", "Time & date style")
    styleDescription: I18n.t("guide.bar.timedate.style.desc", "Choose the visual style for the clock and date display")
    onStyleSelected: id => card.tab.setTimeStyle(id)

    widgetComponent: Component {
        BarPreviewWidget {
            isPreview: false
            property bool showDate: tab.timeShowDate
            property string timeStr: (typeof DateTime !== "undefined" && DateTime.time) ? DateTime.time : "14:28"
            property string hourStr: (typeof DateTime !== "undefined" && DateTime.hour) ? DateTime.hour : "14"
            property string minuteStr: (typeof DateTime !== "undefined" && DateTime.minute) ? DateTime.minute : "28"
            property string secondStr: (typeof DateTime !== "undefined" && DateTime.second) ? DateTime.second : "00"
            property string dayStr: (typeof DateTime !== "undefined" && DateTime.day) ? DateTime.day : "18"
            property string monthStr: (typeof DateTime !== "undefined" && DateTime.monthShort) ? DateTime.monthShort : "Sep"
            property string fullDateStr: (typeof DateTime !== "undefined" && DateTime.fullDate) ? DateTime.fullDate : "Fri, Sep 18"
            property string dateStr: (typeof DateTime !== "undefined" && DateTime.fullDate) ? DateTime.fullDate : "Fri, Sep 18"
        }
    }

    variantFallback: Component {
        Item {
            property string variantId

            RowLayout {
                anchors.centerIn: parent
                visible: !card.tab.isSideBar
                spacing: rootObj.s(6)

                Text {
                    text: "14:28:00"
                    font.family: ThemeBackend.fontFamily
                    font.pixelSize: rootObj.s(13)
                    font.bold: true
                    color: ThemeBackend.text
                }
            }

            ColumnLayout {
                anchors.centerIn: parent
                visible: card.tab.isSideBar
                spacing: rootObj.s(3)

                Text {
                    Layout.alignment: Qt.AlignHCenter
                    text: "14"
                    font.family: ThemeBackend.fontFamily
                    font.pixelSize: rootObj.s(13)
                    font.bold: true
                    color: ThemeBackend.blue
                }

                Text {
                    Layout.alignment: Qt.AlignHCenter
                    text: "28"
                    font.family: ThemeBackend.fontFamily
                    font.pixelSize: rootObj.s(13)
                    font.bold: true
                    color: ThemeBackend.sapphire
                }

                Rectangle {
                    Layout.alignment: Qt.AlignHCenter
                    width: rootObj.s(14)
                    height: 2
                    radius: 1
                    color: ThemeBackend.surface1
                }

                Text {
                    Layout.alignment: Qt.AlignHCenter
                    text: "18"
                    font.family: ThemeBackend.fontFamily
                    font.pixelSize: rootObj.s(10)
                    font.bold: true
                    color: ThemeBackend.text
                }

                Text {
                    Layout.alignment: Qt.AlignHCenter
                    text: "Sep"
                    font.family: ThemeBackend.fontFamily
                    font.pixelSize: rootObj.s(8)
                    font.bold: true
                    color: ThemeBackend.subtext0
                }
            }
        }
    }

    SettingsRow {
        rootObj: card.rootObj
        baseColor: Qt.alpha(ThemeBackend.surface1, 0.35)
        icon: "󰃭"
        title: I18n.t("guide.bar.timedate.show_date.title", "Show date")
        description: I18n.t("guide.bar.timedate.show_date.desc", "Display the date text alongside the clock")

        Toggle {
            Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
            checked: card.tab.timeShowDate
            accentColor: ThemeBackend.accent
            baseColor: ThemeBackend.surface1
            handleColor: ThemeBackend.crust
            handleOffColor: ThemeBackend.text
            onToggled: function(c) {
                card.tab.setTimeShowDate(c);
            }
        }
    }

    SettingsRow {
        rootObj: card.rootObj
        baseColor: Qt.alpha(ThemeBackend.surface1, 0.35)
        icon: "󰅐"
        title: I18n.t("guide.bar.time.title", "Time format")
        description: I18n.t("guide.bar.time.desc", "Format pattern (e.g. HH:mm:ss)")

        Input {
            Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
            implicitWidth: rootObj.s(140)
            implicitHeight: rootObj.s(32)
            text: card.tab.timeFormat
            placeholderText: "HH:mm:ss"
            baseColor: ThemeBackend.surface0
            accentColor: ThemeBackend.accent
            textColor: ThemeBackend.text
            subTextColor: ThemeBackend.subtext0
            borderColor: Qt.alpha(ThemeBackend.surface2, 0.6)
            cornerRadius: ThemeBackend.borderRadius
            fontPixelSize: rootObj.s(11)
            onTextEdited: function(newText) {
                card.tab.setTimeFormat(newText);
            }
            onAccepted: function(finalText) {
                card.tab.setTimeFormat(finalText);
            }
        }
    }
}
