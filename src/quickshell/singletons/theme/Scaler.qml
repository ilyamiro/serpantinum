pragma Singleton
import QtQuick
import Quickshell
import "../../"

Item {
    id: root
    visible: false

    function scaleFor(screenName) {
        let displayConf = Config.peekSetting("display", null);
        if (screenName && displayConf && displayConf.monitors && displayConf.monitors[screenName] && displayConf.monitors[screenName].scale !== undefined) {
            return displayConf.monitors[screenName].scale;
        }
        let general = Config.peekSetting("general", null);
        return (general && general.uiScale !== undefined) ? general.uiScale : 1.0;
    }

    property real uiScale: {
        let _raw = Config.rawSettings;
        return scaleFor("");
    }

    property real baseScale: uiScale

    function s(val) {
        return val;
    }
}
