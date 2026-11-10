import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import "../"
import "../../"
import "../../reusables"
import "../../reusables/guide"

GuideTab {
    id: calendarTabRoot
    subTabIndex: 3
    deferredStages: 2

    property var calendarSettings: Config.getSetting("calendar", {
        "enabled": false,
        "url": "",
        "interval": 15
    })

    property bool calEnabled: calendarSettings.enabled !== undefined ? !!calendarSettings.enabled : false
    property string calUrl: calendarSettings.url !== undefined ? calendarSettings.url : ""
    property int calInterval: calendarSettings.interval !== undefined ? Number(calendarSettings.interval) : 15

    function setCalSetting(key, val) {
        let current = Object.assign({}, calendarTabRoot.calendarSettings);
        current[key] = val;
        calendarTabRoot.calendarSettings = current;
        Config.setSetting("calendar", current);
    }

    Flickable {
        anchors.fill: parent
        contentWidth: width
        contentHeight: contentCol.implicitHeight + calendarTabRoot.s(40)
        boundsBehavior: Flickable.StopAtBounds
        clip: true

        ColumnLayout {
            id: contentCol
            width: parent.width
            spacing: calendarTabRoot.s(16)

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
                        Layout.preferredWidth: calendarTabRoot.s(320)
                        Layout.preferredHeight: calendarTabRoot.s(36)
                        placeholderText: "https://calendar.google.com/calendar/ical/..."
                        text: calendarTabRoot.calUrl
                        onTextCommitted: function(newText) {
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
                    title: I18n.t("guide.calendar.interval.title", "Update Interval")
                    description: I18n.t("guide.calendar.interval.desc", "How often to check for updated calendar events in minutes")
                    settingId: "calendar_interval"

                    Dropdown {
                        enabled: calendarTabRoot.calEnabled
                        Layout.preferredWidth: calendarTabRoot.s(140)
                        Layout.preferredHeight: calendarTabRoot.s(36)
                        model: ["5 minutes", "15 minutes", "30 minutes", "60 minutes"]
                        readonly property var intervalValues: [5, 15, 30, 60]
                        currentIndex: {
                            let idx = intervalValues.indexOf(calendarTabRoot.calInterval);
                            return idx !== -1 ? idx : 1;
                        }
                        onItemClicked: function(index) {
                            calendarTabRoot.setCalSetting("interval", intervalValues[index]);
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
                        size: calendarTabRoot.s(36)
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
