import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import "../"
import "../../"
import "../../reusables"
import "../../reusables/guide"
import "../../reusables/inputs"
import "../../reusables/buttons"

GuideTab {
    id: calendarTabRoot
    subTabIndex: 3

    property var calendarSettings: Config.getSetting("calendar", {
        "enabled": false,
        "url": "",
        "interval": 15
    })

    property bool calEnabled: calendarSettings.enabled !== undefined ? !!calendarSettings.enabled : false
    property string calUrl: calendarSettings.url !== undefined ? calendarSettings.url : ""
    property int calInterval: calendarSettings.interval !== undefined ? Number(calendarSettings.interval) : 15

    Connections {
        target: Config
        function onSettingsLoaded() {
            let cs = Config.getSetting("calendar", {
                "enabled": false,
                "url": "",
                "interval": 15
            });
            calendarTabRoot.calendarSettings = cs;
            calendarTabRoot.calEnabled = !!cs.enabled;
            calendarTabRoot.calUrl = cs.url || "";
            calendarTabRoot.calInterval = cs.interval !== undefined ? Number(cs.interval) : 15;
            if (calendarIntervalSelector.value !== calendarTabRoot.calInterval) {
                calendarIntervalSelector.value = calendarTabRoot.calInterval;
            }
        }
    }

    function setCalSetting(key, val) {
        let current = Object.assign({}, Config.getSetting("calendar", {}));
        current[key] = val;
        calendarTabRoot.calendarSettings = current;
        Config.setSetting("calendar", current);
    }

    Flickable {
        id: mainFlickable
        anchors.fill: parent
        anchors.topMargin: rootObj.s(8)
        anchors.leftMargin: rootObj.s(8)
        anchors.rightMargin: rootObj.s(8)
        anchors.bottomMargin: rootObj.s(8)
        contentHeight: settingsCol.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        ColumnLayout {
            id: settingsCol
            width: parent.width - (parent.contentHeight > parent.height ? rootObj.s(6) : 0)
            spacing: rootObj.s(6)

            SettingsRow {
                settingId: "calendar_enabled"
                rootObj: calendarTabRoot.rootObj
                icon: "󰅀"
                title: I18n.t("guide.calendar.enabled.title", "Enable Calendar Sync")
                description: I18n.t("guide.calendar.enabled.desc", "Synchronize events from a remote iCal or cloud calendar URL")

                Toggle {
                    Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                    checked: calendarTabRoot.calEnabled
                    accentColor: ThemeBackend.mauve
                    baseColor: ThemeBackend.surface1
                    handleColor: ThemeBackend.crust
                    handleOffColor: ThemeBackend.text
                    onToggled: function(c) {
                        calendarTabRoot.calEnabled = c;
                        calendarTabRoot.setCalSetting("enabled", c);
                        if (c && typeof Calendar !== "undefined") {
                            Calendar.refresh(true);
                        }
                    }
                }
            }

            SettingsBlob {
                CollapsibleSection {
                    open: calendarTabRoot.calEnabled || urlRow.tempVisible
                    row: urlRow

                    RevealableSettingsRow {
                        id: urlRow
                        settingId: "calendar_url"
                        rootObj: calendarTabRoot.rootObj
                        icon: "󰌷"
                        title: I18n.t("guide.calendar.url.title", "Private iCal / ICS Feed URL")
                        description: I18n.t("guide.calendar.url.desc", "Paste your private Google, Nextcloud, Apple, or Outlook iCal link")
                        revealWhenClosed: !calendarTabRoot.calEnabled

                        Input {
                            Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                            implicitWidth: calendarTabRoot.rootObj.s(320)
                            implicitHeight: calendarTabRoot.rootObj.s(34)
                            placeholderText: "https://calendar.google.com/calendar/ical/..."
                            text: calendarTabRoot.calUrl
                            onAccepted: function(newText) {
                                calendarTabRoot.calUrl = newText.trim();
                                calendarTabRoot.setCalSetting("url", newText.trim());
                                if (typeof Calendar !== "undefined") {
                                    Calendar.refresh(true);
                                }
                            }
                        }
                    }
                }

                CollapsibleSection {
                    open: calendarTabRoot.calEnabled || intervalRow.tempVisible
                    row: intervalRow

                    RevealableSettingsRow {
                        id: intervalRow
                        settingId: "calendar_interval"
                        rootObj: calendarTabRoot.rootObj
                        icon: "󰔛"
                        title: I18n.t("guide.calendar.interval.title", "Calendar polling interval")
                        description: I18n.t("guide.calendar.interval.desc", "Polling frequency in minutes")
                        revealWhenClosed: !calendarTabRoot.calEnabled

                        NumberSelector {
                            id: calendarIntervalSelector
                            Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                            implicitWidth: calendarTabRoot.rootObj.s(180)
                            implicitHeight: calendarTabRoot.rootObj.s(32)
                            from: 1
                            to: 1440
                            stepSize: 1
                            decimals: 0
                            suffix: " min"
                            value: calendarTabRoot.calInterval
                            baseColor: ThemeBackend.surface0
                            accentColor: ThemeBackend.mauve
                            buttonColor: ThemeBackend.surface1
                            buttonTextColor: ThemeBackend.text
                            textColor: ThemeBackend.text
                            subTextColor: ThemeBackend.subtext0
                            borderColor: Qt.alpha(ThemeBackend.surface2, 0.6)
                            cornerRadius: ThemeBackend.borderRadius
                            fontPixelSize: calendarTabRoot.rootObj.s(11)
                            onValueChanged: {
                                let val = Math.round(value);
                                if (val !== calendarTabRoot.calInterval && val >= 1) {
                                    calendarTabRoot.calInterval = val;
                                    calendarTabRoot.setCalSetting("interval", val);
                                }
                            }
                        }
                    }
                }

                CollapsibleSection {
                    open: calendarTabRoot.calEnabled || statusRow.tempVisible
                    row: statusRow

                    RevealableSettingsRow {
                        id: statusRow
                        settingId: "calendar_sync_now"
                        rootObj: calendarTabRoot.rootObj
                        icon: "󰑐"
                        title: I18n.t("guide.calendar.syncnow.title", "Sync Status")
                        description: {
                            if (typeof Calendar !== "undefined") {
                                if (Calendar.isLoading) return "Syncing calendar events...";
                                if (Calendar.lastError !== "") return "Error: " + Calendar.lastError;
                                if (Calendar.lastSyncTime > 0) {
                                    let d = new Date(Calendar.lastSyncTime * 1000);
                                    return "Last synced: " + d.toLocaleTimeString() + " (" + Calendar.totalCount + " events loaded)";
                                }
                            }
                            return "Not synced yet";
                        }
                        revealWhenClosed: !calendarTabRoot.calEnabled

                        IconButton {
                            Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                            enabled: typeof Calendar !== "undefined" ? !Calendar.isLoading : true
                            size: calendarTabRoot.rootObj.s(34)
                            buttonIcon: "󰑐"
                            accentColor: ThemeBackend.mauve
                            textColor: ThemeBackend.crust
                            onClicked: {
                                if (typeof Calendar !== "undefined") {
                                    Calendar.refresh(true);
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
