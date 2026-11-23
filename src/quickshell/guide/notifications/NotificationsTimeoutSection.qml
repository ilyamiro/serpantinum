import QtQuick
import QtQuick.Layouts
import "../../"
import "../../reusables"
import "../../reusables/guide"

SettingsBlob {
    id: section
    required property var tab
    readonly property var rootObj: tab.rootObj

    component TimeoutStepper: NumberSelector {
        required property string settingKey
        Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
        implicitWidth: section.rootObj.s(130)
        implicitHeight: section.rootObj.s(32)
        from: 0
        to: 300
        stepSize: 1
        decimals: 0
        suffix: "s"
        specialZeroText: I18n.t("guide.notifications.timeout_never", "Never")
        baseColor: ThemeBackend.surface0
        accentColor: ThemeBackend.mauve
        buttonColor: ThemeBackend.surface1
        buttonTextColor: ThemeBackend.text
        textColor: ThemeBackend.text
        borderColor: Qt.alpha(ThemeBackend.surface2, 0.6)
        cornerRadius: ThemeBackend.borderRadius
        fontPixelSize: section.rootObj.s(11)
        onValueChanged: {
            let secs = Math.round(value);
            if (secs !== section.tab[settingKey]) {
                section.tab[settingKey] = secs;
                section.tab.updateNotifSetting(settingKey, secs);
            }
        }
    }

    SettingsRow {
        rootObj: section.tab.rootObj
        settingId: "notifications_timeout_low"
        searchKeywords: "notifications low urgency timeout duration seconds expire dismiss"
        icon: "󰂜"
        title: I18n.t("guide.notifications.timeout_low.title", "Low urgency timeout")
        description: I18n.t("guide.notifications.timeout_low.desc", "How long low urgency notifications stay on screen")

        TimeoutStepper { settingKey: "timeoutLow"; value: section.tab.timeoutLow }
    }

    SettingsRow {
        rootObj: section.tab.rootObj
        settingId: "notifications_timeout_normal"
        searchKeywords: "notifications normal default timeout duration seconds expire dismiss"
        icon: "󰂚"
        title: I18n.t("guide.notifications.timeout_normal.title", "Normal timeout")
        description: I18n.t("guide.notifications.timeout_normal.desc", "How long regular notifications stay on screen")

        TimeoutStepper { settingKey: "timeoutNormal"; value: section.tab.timeoutNormal }
    }

    SettingsRow {
        rootObj: section.tab.rootObj
        settingId: "notifications_timeout_critical"
        searchKeywords: "notifications critical urgent high timeout duration seconds expire dismiss"
        icon: "󰂞"
        title: I18n.t("guide.notifications.timeout_critical.title", "Urgent timeout")
        description: I18n.t("guide.notifications.timeout_critical.desc", "How long urgent notifications stay on screen")

        TimeoutStepper { settingKey: "timeoutCritical"; value: section.tab.timeoutCritical }
    }

    SettingsRow {
        rootObj: section.tab.rootObj
        settingId: "notifications_override_timeouts"
        searchKeywords: "notifications override force app timeouts duration ignore"
        icon: "󰔛"
        title: I18n.t("guide.notifications.override_timeouts.title", "Override app timeouts")
        description: I18n.t("guide.notifications.override_timeouts.desc", "By default the values above are only used when the app doesn't set its own timeout. Turn on to always use them")

        Toggle {
            Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
            checked: section.tab.overrideAppTimeouts
            accentColor: ThemeBackend.mauve
            baseColor: ThemeBackend.surface1
            handleColor: ThemeBackend.crust
            handleOffColor: ThemeBackend.text
            onToggled: function(c) {
                section.tab.overrideAppTimeouts = c;
                section.tab.updateNotifSetting("overrideAppTimeouts", c);
            }
        }
    }
}
