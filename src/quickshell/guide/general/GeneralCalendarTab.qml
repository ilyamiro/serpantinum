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
            width: parent.width
            spacing: rootObj.s(6)

            SettingsBlob {
                SettingsRow {
                    rootObj: calendarTabRoot.rootObj
                    icon: "󰸗"
                    title: I18n.t("guide.calendar.enabled.title", "Enable Calendar Sync")
                    description: I18n.t("guide.calendar.enabled.desc", "Synchronize events from a remote iCal or cloud calendar URL")
                    settingId: "calendar_enabled"

                    Toggle {
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
            }

            SettingsBlob {
                opacity: calendarTabRoot.calEnabled ? 1.0 : 0.5

                SettingsRow {
                    rootObj: calendarTabRoot.rootObj
                    icon: "󰌷"
                    title: I18n.t("guide.calendar.url.title", "Private iCal / ICS Feed URL")
                    description: I18n.t("guide.calendar.url.desc", "Paste your private Google, Nextcloud, Apple, or Outlook iCal link")
                    settingId: "calendar_url"

                    Input {
                        enabled: calendarTabRoot.calEnabled
                        implicitWidth: rootObj.s(320)
                        implicitHeight: rootObj.s(34)
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

                SettingsRow {
                    rootObj: calendarTabRoot.rootObj
                    icon: "󰔛"
                    title: I18n.t("guide.calendar.interval.title", "Calendar polling interval")
                    description: I18n.t("guide.calendar.interval.desc", "Polling frequency in minutes")
                    settingId: "calendar_interval"

                    NumberSelector {
                        id: calendarIntervalSelector
                        enabled: calendarTabRoot.calEnabled
                        implicitWidth: rootObj.s(180)
                        implicitHeight: rootObj.s(32)
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
                        fontPixelSize: rootObj.s(11)
                        onValueChanged: {
                            let val = Math.round(value);
                            if (val !== calendarTabRoot.calInterval && val >= 1) {
                                calendarTabRoot.calInterval = val;
                                calendarTabRoot.setCalSetting("interval", val);
                            }
                        }
                    }
                }

                SettingsRow {
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
                    settingId: "calendar_sync_now"

                    IconButton {
                        enabled: calendarTabRoot.calEnabled && (typeof Calendar !== "undefined" ? !Calendar.isLoading : true)
                        size: rootObj.s(34)
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
