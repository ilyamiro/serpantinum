import QtQuick
import "../../"
import "../../reusables"
import "../../reusables/guide"

SettingsBlob {
    id: section
    required property var tab
    readonly property var rootObj: tab.rootObj

    SettingsRow {
        rootObj: section.tab.rootObj
        settingId: "general_daily_ping"
        searchKeywords: "telemetry daily ping privacy usage statistics anonymous analytics"
        icon: "󰐰"
        title: I18n.t("guide.general.daily_ping.title") || "Daily ping"
        description: I18n.t("guide.general.daily_ping.desc") || "Send one empty request a day to count active users. No data is attached"

        Checkbox {
            checked: section.tab.dailyPing
            onToggled: function(c) {
                section.tab.setGeneralSetting("dailyPing", c);
            }
        }
    }
}
