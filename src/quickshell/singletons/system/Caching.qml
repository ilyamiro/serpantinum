pragma Singleton
import QtQuick
import Quickshell

QtObject {
    id: root

    readonly property string serpantinumDir: Quickshell.env("SERPANTINUM_DIR") || ""
    readonly property string qsDir: Quickshell.env("QS_DIR") || ""

    readonly property string home: Quickshell.env("HOME") || ""
    readonly property string xdgRuntimeDir: Quickshell.env("XDG_RUNTIME_DIR") || ""
    readonly property string xdgConfigHome: Quickshell.env("XDG_CONFIG_HOME") || (home + "/.config")
    readonly property string xdgDataHome: Quickshell.env("XDG_DATA_HOME") || (home + "/.local/share")
    readonly property string xdgStateHome: Quickshell.env("XDG_STATE_HOME") || (home + "/.local/state")
    readonly property string xdgCacheHome: Quickshell.env("XDG_CACHE_HOME") || (home + "/.cache")
    readonly property string xdgPicturesDir: Quickshell.env("XDG_PICTURES_DIR") || (home + "/Pictures")

    readonly property string configDir: Quickshell.env("QS_CONFIG_DIR") || (xdgConfigHome + "/serpantinum")
    readonly property string dataDir: Quickshell.env("QS_DATA_DIR") || (xdgDataHome + "/serpantinum")
    readonly property string stateDir: Quickshell.env("QS_STATE_DIR") || (xdgStateHome + "/serpantinum")
    readonly property string cacheDir: Quickshell.env("QS_CACHE_DIR") || (xdgCacheHome + "/serpantinum")
    readonly property string runDir: Quickshell.env("QS_RUN_DIR") || ((xdgRuntimeDir !== "" ? xdgRuntimeDir : "/tmp") + "/serpantinum")
    readonly property string logDir: Quickshell.env("QS_LOG_DIR") || (runDir + "/logs")

    property var _ensuredDirs: ({})

    function _ensureDir(dirPath) {
        if (!dirPath || _ensuredDirs[dirPath]) return;
        _ensuredDirs[dirPath] = true;
        Quickshell.execDetached(["mkdir", "-p", dirPath]);
    }

    function _ensureSubdir(base, envName, sub) {
        if (!sub || sub === "serpantinum" || base.endsWith("/" + sub)) {
            _ensureDir(base);
            return base;
        }
        let envPath = Quickshell.env(envName + "_" + sub.toUpperCase());
        let finalPath = envPath ? envPath : (base + "/" + sub);
        _ensureDir(finalPath);
        return finalPath;
    }

    function getConfigDir(widgetName) {
        return _ensureSubdir(configDir, "QS_CONFIG", widgetName);
    }

    function getDataDir(widgetName) {
        return _ensureSubdir(dataDir, "QS_DATA", widgetName);
    }

    function getCacheDir(widgetName) {
        return _ensureSubdir(cacheDir, "QS_CACHE", widgetName);
    }

    function getStateDir(widgetName) {
        return _ensureSubdir(stateDir, "QS_STATE", widgetName);
    }

    function getRunDir(widgetName) {
        return _ensureSubdir(runDir, "QS_RUN", widgetName);
    }

    function getLogDir(widgetName) {
        return _ensureSubdir(logDir, "QS_LOG", widgetName);
    }
}
