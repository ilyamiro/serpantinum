pragma Singleton
import QtQuick
import Quickshell
import "../../"
import "../../WindowRegistry.js" as Registry

QtObject {
    id: router

    property var masterWindow: null
    property var idleService: null

    function registerMaster(win) {
        if (win) router.masterWindow = win;
    }

    function unregisterMaster(win) {
        if (!win || router.masterWindow === win) {
            router.masterWindow = null;
        }
    }

    function registerIdle(inst) {
        if (inst) router.idleService = inst;
    }

    function unregisterIdle(inst) {
        if (!inst || router.idleService === inst) {
            router.idleService = null;
        }
    }

    function _standaloneController(id) {
        switch (id) {
        case "launcher": return typeof LauncherController !== "undefined" ? LauncherController : null;
        case "clipboard": return typeof ClipboardController !== "undefined" ? ClipboardController : null;
        case "calendar": return typeof DashboardController !== "undefined" ? DashboardController : null;
        case "desktopmenu": return typeof DesktopMenuController !== "undefined" ? DesktopMenuController : null;
        case "dockappmenu": return typeof DockAppMenuController !== "undefined" ? DockAppMenuController : null;
        case "traymenu": return typeof TrayMenuController !== "undefined" ? TrayMenuController : null;
        case "sidemusic": return typeof SideMusicController !== "undefined" ? SideMusicController : null;
        case "floating": return typeof FloatingController !== "undefined" ? FloatingController : null;
        default: return null;
        }
    }

    function _hideStandalone(id) {
        let ctrl = _standaloneController(id);
        if (!ctrl) return;
        if (id === "floating") {
            if (typeof ctrl.close === "function") ctrl.close(null);
            return;
        }
        if (typeof ctrl.hide === "function") ctrl.hide();
    }

    function _isStandaloneOpen(id) {
        let ctrl = _standaloneController(id);
        if (!ctrl) return false;
        return Boolean(ctrl.isVisible);
    }

    function closeGroup(group, exceptId) {
        if (!group || group === "none") return;
        let resolvedExcept = exceptId ? Registry.resolveId(exceptId) : "";
        let exceptMeta = resolvedExcept ? Registry.getSurface(resolvedExcept) : null;
        let members = Registry.surfacesInGroup(group);
        let closeMaster = false;

        for (let i = 0; i < members.length; i++) {
            let m = members[i];
            if (m.id === resolvedExcept) continue;
            if (m.host === "standalone") {
                _hideStandalone(m.id);
            } else if (m.host === "master") {
                if (!exceptMeta || exceptMeta.host !== "master") {
                    closeMaster = true;
                }
            }
        }

        if (closeMaster && router.masterWindow && router.masterWindow.targetActive !== "hidden") {
            router.masterWindow.switchWidget("hidden", "");
        }
    }

    function closeAll() {
        closeGroup("popover", "");
        closeGroup("modal", "");
        if (router.masterWindow && router.masterWindow.targetActive !== "hidden") {
            router.masterWindow.switchWidget("hidden", "");
        }
    }

    function _effectiveArg(rawId, resolvedId, arg) {
        let a = (arg !== undefined && arg !== null) ? String(arg) : "";
        if (a !== "") return a;
        let raw = rawId ? String(rawId).trim().toLowerCase() : "";
        if (resolvedId === "network" && (raw === "wifi" || raw === "bt" || raw === "bluetooth" || raw === "ethernet")) {
            return raw === "bluetooth" ? "bt" : (raw === "ethernet" ? "eth" : raw);
        }
        return "";
    }

    function open(id, arg, screen) {
        let surface = Registry.getSurface(id);
        if (!surface) return;

        let effectiveArg = _effectiveArg(id, surface.id, arg);
        let scr = screen !== undefined ? screen : null;

        if (surface.id === "hidden") {
            closeAll();
            return;
        }

        if (surface.id === "guide") {
            embeddedSettings("open", effectiveArg, scr);
            return;
        }

        if (surface.exclusiveGroup && surface.exclusiveGroup !== "none") {
            closeGroup(surface.exclusiveGroup, surface.id);
        }

        if (surface.host === "standalone") {
            let ctrl = _standaloneController(surface.id);
            if (!ctrl) return;
            if (surface.id === "floating") {
                if (effectiveArg !== "" && typeof ctrl.showTab === "function") ctrl.showTab(effectiveArg, scr);
                else if (typeof ctrl.open === "function") ctrl.open(scr);
                return;
            }
            if (typeof ctrl.show === "function") {
                if (scr !== null) ctrl.show(scr);
                else ctrl.show();
            }
            return;
        }

        if (surface.host === "master" && router.masterWindow) {
            router.masterWindow.openSurface(surface.id, effectiveArg, scr);
        }
    }

    function close(id) {
        if (id === undefined || id === null || String(id).trim() === "") {
            closeAll();
            return;
        }
        let surface = Registry.getSurface(id);
        if (!surface) return;
        if (surface.host === "standalone") {
            _hideStandalone(surface.id);
        } else if (surface.host === "master" && router.masterWindow) {
            if (router.masterWindow.targetActive === surface.id || router.masterWindow.currentActive === surface.id) {
                router.masterWindow.switchWidget("hidden", "");
            }
        }
    }

    function toggle(id, arg, screen) {
        let surface = Registry.getSurface(id);
        if (!surface) return;

        let effectiveArg = _effectiveArg(id, surface.id, arg);
        let scr = screen !== undefined ? screen : null;

        if (surface.id === "hidden") {
            closeAll();
            return;
        }

        if (surface.id === "guide") {
            embeddedSettings("toggle", effectiveArg, scr);
            return;
        }

        if (surface.host === "standalone") {
            let ctrl = _standaloneController(surface.id);
            if (!ctrl) return;
            if (surface.id === "floating") {
                if (effectiveArg !== "" && typeof ctrl.showTab === "function") ctrl.showTab(effectiveArg, scr);
                else if (typeof ctrl.toggle === "function") ctrl.toggle(scr);
                return;
            }
            let wasOpen = _isStandaloneOpen(surface.id);
            if (!wasOpen && surface.exclusiveGroup && surface.exclusiveGroup !== "none") {
                closeGroup(surface.exclusiveGroup, surface.id);
            }
            if (typeof ctrl.toggle === "function") {
                if (scr !== null) ctrl.toggle(scr);
                else ctrl.toggle();
            }
            return;
        }

        if (surface.host === "master" && router.masterWindow) {
            let mw = router.masterWindow;
            if (mw.targetActive === surface.id) {
                if (effectiveArg !== "" && effectiveArg !== mw.activeArg) {
                    mw.activateCurrent(effectiveArg);
                } else {
                    mw.switchWidget("hidden", "");
                }
            } else {
                if (surface.exclusiveGroup && surface.exclusiveGroup !== "none") {
                    closeGroup(surface.exclusiveGroup, surface.id);
                }
                mw.openSurface(surface.id, effectiveArg, scr);
            }
        }
    }

    function embeddedSettings(action, tab, screen) {
        let act = action || "toggle";
        let t = (tab !== undefined && tab !== null) ? String(tab) : "";
        let mw = router.masterWindow;
        if (!mw) return;

        let isOpen = mw.targetActive === "guide";
        if (act === "close") {
            if (isOpen) mw.switchWidget("hidden", "");
            return;
        }

        if (!isOpen) {
            let meta = Registry.getSurface("guide");
            if (meta && meta.exclusiveGroup && meta.exclusiveGroup !== "none") {
                closeGroup(meta.exclusiveGroup, "guide");
            }
            mw.openSurface("guide", t, screen !== undefined ? screen : null);
            return;
        }

        if (t !== "" && (act === "open" || t !== mw.activeArg)) {
            mw.activateCurrent(t);
        } else if (act === "toggle") {
            mw.switchWidget("hidden", "");
        }
    }

    function reload() {
        Quickshell.reload(true);
    }

    function clearNotifications() {
        NotificationManager.clearNotifications();
    }

    function toggleAirplane() {
        Connectivity.toggleAirplaneMode();
    }

    function toggleBarAutohide() {
        let bar = Config.getSetting("bar", {});
        bar.autohide = !bar.autohide;
        Config.setSetting("bar", bar);
    }

    function handleCommand(cmd, targetWidget, arg) {
        cmd = cmd || "";
        targetWidget = targetWidget || "";
        arg = arg || "";

        if (cmd === "notifications" && targetWidget === "clear") {
            clearNotifications();
            return;
        }

        let isSettingsCmd = cmd === "settings" || targetWidget === "settings";
        let isGuideCmd = cmd === "guide" || targetWidget === "guide";
        if (isSettingsCmd || isGuideCmd) {
            if (isGuideCmd) {
                console.warn("'guide' is deprecated, use 'settings' instead");
            }
            let settingsAction = cmd === "close" ? "close" : (cmd === "open" ? "open" : "toggle");
            let settingsTab = (cmd === "settings" || cmd === "guide") ? targetWidget : arg;
            if (settingsTab === "settings" || settingsTab === "guide") settingsTab = "";
            embeddedSettings(settingsAction, settingsTab);
            return;
        }

        if (cmd === "network" && targetWidget === "airplane") {
            toggleAirplane();
            return;
        }

        if (cmd === "bar" && targetWidget === "autohide") {
            toggleBarAutohide();
            return;
        }

        if (cmd === "close") {
            close(targetWidget);
            return;
        }

        if (cmd === "open") {
            open(targetWidget, arg);
            return;
        }

        if (cmd === "toggle") {
            toggle(targetWidget, arg);
            return;
        }

        let legacySurface = Registry.getSurface(cmd);
        if (legacySurface) {
            toggle(cmd, targetWidget);
        }
    }
}
