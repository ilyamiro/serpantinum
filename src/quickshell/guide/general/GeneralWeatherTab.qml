import QtQuick
import QtQuick.Layouts
import "../"
import "../../"
import "../../reusables"
import "../../reusables/guide"

GuideTab {
    id: weatherTabRoot
    subTabIndex: 2

    onVisibleChanged: {
        if (!visible) {
            if (weatherUnitDropdown.isOpen) weatherUnitDropdown.closePopup();
        }
    }

    property var generalSettings: Config.getSetting("general", {})
    property int weatherInterval: generalSettings.weatherInterval !== undefined ? generalSettings.weatherInterval : 15
    property string weatherUnit: generalSettings.weatherUnit !== undefined ? generalSettings.weatherUnit : "metric"

    property var weatherUnitCodes: ["metric", "imperial", "standard"]
    property var weatherUnitNames: [
        I18n.t("guide.general.weatherunit.celsius", "Celsius"),
        I18n.t("guide.general.weatherunit.fahrenheit", "Fahrenheit"),
        I18n.t("guide.general.weatherunit.kelvin", "Kelvin")
    ]

    readonly property var weatherAlertsDefaults: ({
        "enabled": true,
        "dailyForecast": false,
        "governmentWarnings": true,
        "quietHours": true,
        "quietStart": 22,
        "quietEnd": 5,
        "rain_soon": true,
        "snow_soon": true,
        "heavy_rain": true,
        "heavy_snow": true,
        "thunderstorm": true,
        "ice": true,
        "fog": true,
        "temp_rise": true,
        "temp_drop": true,
        "hot": true,
        "cold": true,
        "wind": true,
        "uv": true,
        "air_quality": true
    })

    property var weatherAlerts: Object.assign({}, weatherAlertsDefaults, Config.getSetting("weatherAlerts", weatherAlertsDefaults))

    readonly property bool alertsOn: !!weatherAlerts.enabled
    readonly property bool quietOn: alertsOn && !!weatherAlerts.quietHours
    readonly property bool govAvailable: typeof GovAlerts !== "undefined"

    readonly property var forecastKinds: [
        { key: "rain_soon", title: "Rain soon", desc: "Rain is expected within the next few hours" },
        { key: "snow_soon", title: "Snow soon", desc: "Snow is expected within the next few hours" },
        { key: "heavy_rain", title: "Heavy rain", desc: "Heavy rainfall is forecast" },
        { key: "heavy_snow", title: "Heavy snow", desc: "Heavy snowfall is forecast" },
        { key: "thunderstorm", title: "Thunderstorms", desc: "Thunderstorms are forecast" },
        { key: "ice", title: "Ice", desc: "Icy conditions are forecast" },
        { key: "fog", title: "Fog", desc: "Fog is forecast" },
        { key: "temp_rise", title: "Temperature rise", desc: "The temperature is expected to rise sharply" },
        { key: "temp_drop", title: "Temperature drop", desc: "The temperature is expected to fall sharply" },
        { key: "hot", title: "Heat", desc: "Very high temperatures are forecast" },
        { key: "cold", title: "Cold", desc: "Very low temperatures are forecast" },
        { key: "wind", title: "Strong wind", desc: "Strong winds are forecast" },
        { key: "uv", title: "UV index", desc: "The UV index is expected to be high" },
        { key: "air_quality", title: "Air quality", desc: "Poor air quality is forecast" }
    ]

    Connections {
        target: Config
        function onSettingsLoaded() {
            let gs = Config.getSetting("general", {});
            weatherTabRoot.generalSettings = gs;
            weatherTabRoot.weatherInterval = gs.weatherInterval !== undefined ? gs.weatherInterval : 15;
            weatherTabRoot.weatherUnit = gs.weatherUnit !== undefined ? gs.weatherUnit : "metric";
            weatherTabRoot.weatherAlerts = Object.assign({}, weatherTabRoot.weatherAlertsDefaults, Config.getSetting("weatherAlerts", weatherTabRoot.weatherAlertsDefaults));
            if (weatherIntervalSelector.value !== weatherTabRoot.weatherInterval) {
                weatherIntervalSelector.value = weatherTabRoot.weatherInterval;
            }
        }
    }

    function saveGeneral() {
        if (typeof Config !== "undefined" && !Config.dataReady) return;
        let current = Object.assign({}, Config.getSetting("general", {}));
        current.weatherInterval = weatherTabRoot.weatherInterval;
        current.weatherUnit = weatherTabRoot.weatherUnit;
        Config.setSetting("general", current);
    }

    function setAlert(key, value) {
        if (typeof Config !== "undefined" && !Config.dataReady) return;
        let next = Object.assign({}, weatherTabRoot.weatherAlertsDefaults, Config.getSetting("weatherAlerts", weatherTabRoot.weatherAlertsDefaults));
        next[key] = value;
        Config.setSetting("weatherAlerts", next);
        weatherTabRoot.weatherAlerts = next;
    }

    function govStatusLabel(status) {
        if (status === "ok") return I18n.t("guide.weather.government.status.ok", "Connected");
        if (status === "partial") return I18n.t("guide.weather.government.status.partial", "Partially connected");
        if (status === "unavailable") return I18n.t("guide.weather.government.status.unavailable", "Unavailable");
        if (status === "disabled") return I18n.t("guide.weather.government.status.disabled", "Disabled");
        return I18n.t("guide.weather.government.status.unknown", "Unknown");
    }

    function govStatusText() {
        let status = govAvailable ? GovAlerts.status : "unknown";
        let last = govAvailable && GovAlerts.lastSuccess > 0
            ? Qt.formatDateTime(new Date(GovAlerts.lastSuccess), "yyyy-MM-dd HH:mm")
            : I18n.t("guide.weather.government.never", "Never");
        let ok = govAvailable ? GovAlerts.sourcesOk : 0;
        let total = govAvailable ? GovAlerts.sourcesTotal : 0;
        return [
            govStatusLabel(status),
            I18n.t("guide.weather.government.last_success", "Last success") + ": " + last,
            I18n.t("guide.weather.government.sources", "Sources reachable") + ": " + ok + "/" + total
        ].join(" · ");
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
                    rootObj: weatherTabRoot.rootObj
                    icon: "󰔛"
                    title: I18n.t("guide.general.weatherinterval.title", "Weather polling interval")
                    description: I18n.t("guide.general.weatherinterval.desc", "Polling frequency in minutes")

                    NumberSelector {
                        id: weatherIntervalSelector
                        implicitWidth: rootObj.s(180)
                        implicitHeight: rootObj.s(32)
                        from: 1
                        to: 1440
                        stepSize: 1
                        decimals: 0
                        suffix: " min"
                        value: weatherTabRoot.weatherInterval
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
                            if (val !== weatherTabRoot.weatherInterval && val >= 1) {
                                weatherTabRoot.weatherInterval = val;
                                weatherTabRoot.saveGeneral();
                                if (typeof Weather !== "undefined") {
                                    Weather.refreshInterval = weatherTabRoot.weatherInterval * 60000;
                                }
                            }
                        }
                    }
                }

                SettingsRow {
                    rootObj: weatherTabRoot.rootObj
                    icon: "󰔏"
                    title: I18n.t("guide.general.weatherunit.title", "Weather unit")
                    description: I18n.t("guide.general.weatherunit.desc", "Temperature scale for weather displays")

                    Dropdown {
                        id: weatherUnitDropdown
                        implicitWidth: rootObj.s(180)
                        implicitHeight: rootObj.s(32)
                        options: weatherTabRoot.weatherUnitNames
                        currentIndex: {
                            let idx = weatherTabRoot.weatherUnitCodes.indexOf(weatherTabRoot.weatherUnit);
                            return idx !== -1 ? idx : 0;
                        }
                        accentColor: ThemeBackend.mauve
                        baseColor: ThemeBackend.surface0
                        hoverColor: ThemeBackend.surface1
                        dropdownColor: ThemeBackend.surface0
                        borderColor: Qt.alpha(ThemeBackend.surface2, 0.6)
                        textColor: ThemeBackend.text
                        activeTextColor: ThemeBackend.crust
                        cornerRadius: ThemeBackend.borderRadius
                        fontPixelSize: rootObj.s(11)
                        onValueChanged: function(index, value) {
                            weatherTabRoot.weatherUnit = weatherTabRoot.weatherUnitCodes[index];
                            weatherTabRoot.saveGeneral();
                            if (typeof Weather !== "undefined") {
                                Weather.unit = weatherTabRoot.weatherUnit;
                            }
                        }
                    }
                }
            }

            SettingsBlob {
                SettingsRow {
                    rootObj: weatherTabRoot.rootObj
                    icon: "󰖕"
                    title: I18n.t("guide.weather.enabled.title", "Weather alerts")
                    description: I18n.t("guide.weather.enabled.desc", "Send notifications when the weather changes or warnings are issued")
                    settingId: "weather_alerts_enabled"

                    Toggle {
                        checked: weatherTabRoot.alertsOn
                        accentColor: ThemeBackend.mauve
                        baseColor: ThemeBackend.surface1
                        handleColor: ThemeBackend.crust
                        handleOffColor: ThemeBackend.text
                        onToggled: function(c) {
                            weatherTabRoot.setAlert("enabled", c);
                        }
                    }
                }
            }

            SettingsBlob {
                opacity: weatherTabRoot.alertsOn ? 1.0 : 0.5

                SettingsRow {
                    rootObj: weatherTabRoot.rootObj
                    icon: "󰖕"
                    title: I18n.t("guide.weather.daily.title", "Twice-daily forecast")
                    description: I18n.t("guide.weather.daily.desc", "Send a morning and evening summary of the day's conditions")
                    settingId: "weather_daily_forecast"

                    Toggle {
                        enabled: weatherTabRoot.alertsOn
                        checked: weatherTabRoot.weatherAlerts.dailyForecast === true
                        accentColor: ThemeBackend.mauve
                        baseColor: ThemeBackend.surface1
                        handleColor: ThemeBackend.crust
                        handleOffColor: ThemeBackend.text
                        onToggled: function(c) {
                            weatherTabRoot.setAlert("dailyForecast", c);
                        }
                    }
                }

                SettingsRow {
                    rootObj: weatherTabRoot.rootObj
                    icon: "󰖕"
                    title: I18n.t("guide.weather.government.title", "Government warnings")
                    description: I18n.t("guide.weather.government.desc", "Send official severe weather warnings for your location")
                    settingId: "weather_government_warnings"

                    Toggle {
                        enabled: weatherTabRoot.alertsOn
                        checked: weatherTabRoot.weatherAlerts.governmentWarnings === true
                        accentColor: ThemeBackend.mauve
                        baseColor: ThemeBackend.surface1
                        handleColor: ThemeBackend.crust
                        handleOffColor: ThemeBackend.text
                        onToggled: function(c) {
                            weatherTabRoot.setAlert("governmentWarnings", c);
                        }
                    }
                }

                SettingsRow {
                    rootObj: weatherTabRoot.rootObj
                    icon: "󰋼"
                    title: I18n.t("guide.weather.government.status.title", "Warning source status")
                    description: weatherTabRoot.govStatusText()
                    settingId: "weather_government_status"
                }
            }

            SettingsBlob {
                opacity: weatherTabRoot.alertsOn ? 1.0 : 0.5

                SettingsRow {
                    rootObj: weatherTabRoot.rootObj
                    icon: "󰖔"
                    title: I18n.t("guide.weather.quiet.title", "Quiet hours")
                    description: I18n.t("guide.weather.quiet.desc", "Hold back non-urgent alerts during these hours. Severe government warnings, thunderstorms and ice still arrive")
                    settingId: "weather_quiet_hours"

                    Toggle {
                        enabled: weatherTabRoot.alertsOn
                        checked: weatherTabRoot.weatherAlerts.quietHours === true
                        accentColor: ThemeBackend.mauve
                        baseColor: ThemeBackend.surface1
                        handleColor: ThemeBackend.crust
                        handleOffColor: ThemeBackend.text
                        onToggled: function(c) {
                            weatherTabRoot.setAlert("quietHours", c);
                        }
                    }
                }

                Item {
                    id: quietRangeHolder
                    Layout.fillWidth: true
                    Layout.preferredHeight: weatherTabRoot.quietOn ? quietRangeRow.implicitHeight : 0
                    visible: Layout.preferredHeight > 0.5
                    clip: true
                    Behavior on Layout.preferredHeight { NumberAnimation { duration: 250; easing.type: Easing.OutCubic } }

                    SettingsRow {
                        id: quietRangeRow
                        width: parent.width
                        rootObj: weatherTabRoot.rootObj
                        icon: "󰔛"
                        title: I18n.t("guide.weather.quiet.range.title", "Quiet period")
                        description: I18n.t("guide.weather.quiet.range.desc", "Drag the handles to choose when alerts are held back")
                        settingId: "weather_quiet_range"

                        TimeRangeSlider {
                            start: weatherTabRoot.weatherAlerts.quietStart
                            end: weatherTabRoot.weatherAlerts.quietEnd
                            accentColor: ThemeBackend.mauve
                            trackColor: ThemeBackend.surface2
                            textColor: ThemeBackend.text
                            subTextColor: ThemeBackend.subtext0
                            onCommitted: function(st, en) {
                                weatherTabRoot.setAlert("quietStart", st);
                                weatherTabRoot.setAlert("quietEnd", en);
                            }
                        }
                    }
                }
            }

            SettingsBlob {
                opacity: weatherTabRoot.alertsOn ? 1.0 : 0.5

                Repeater {
                    model: weatherTabRoot.forecastKinds

                    SettingsRow {
                        required property var modelData

                        rootObj: weatherTabRoot.rootObj
                        icon: "󰖕"
                        title: I18n.t("guide.weather.kinds." + modelData.key + ".title", modelData.title)
                        description: I18n.t("guide.weather.kinds." + modelData.key + ".desc", modelData.desc)
                        settingId: "weather_kind_" + modelData.key

                        Toggle {
                            enabled: weatherTabRoot.alertsOn
                            checked: weatherTabRoot.weatherAlerts[modelData.key] === true
                            accentColor: ThemeBackend.mauve
                            baseColor: ThemeBackend.surface1
                            handleColor: ThemeBackend.crust
                            handleOffColor: ThemeBackend.text
                            onToggled: function(c) {
                                weatherTabRoot.setAlert(modelData.key, c);
                            }
                        }
                    }
                }
            }
        }
    }
}
