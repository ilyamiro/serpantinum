pragma Singleton
import QtQuick
import "../../"
import "../../widgets"
import "../../bar"

QtObject {
    id: registry

    readonly property var lockTypeIds: ["clock", "avatar", "user", "lockstatus", "password", "fingerprint", "keyboard", "battery", "notifications"]

    readonly property var types: ({
        "clock": {
            icon: String.fromCodePoint(0xF0954),
            nameKey: "lock.redactor.element.clock",
            scopes: ["screen"],
            widgetKey: "time",
            defaultVariant: "lockscreen",
            w: 420,
            h: 200,
            migrateZeroSize: true
        },
        "avatar": {
            icon: String.fromCodePoint(0xF0009),
            file: "elements/LockAvatarElement.qml",
            scopes: ["panel"],
            w: 200, h: 200, minW: 60, minH: 60, maxW: 400, maxH: 400,
            aspect: 1,
            variants: ["round", "rounded"]
        },
        "user": {
            icon: String.fromCodePoint(0xF0004),
            file: "elements/LockUserElement.qml",
            scopes: ["panel"],
            w: 380, h: 44, minW: 100, minH: 32, maxW: 1000, maxH: 80,
            variants: ["filled", "plain"]
        },
        "lockstatus": {
            icon: String.fromCodePoint(0xF033E),
            file: "elements/LockLockStatusElement.qml",
            scopes: ["panel"],
            w: 190, h: 44, minW: 80, minH: 32, maxW: 1000, maxH: 80,
            variants: ["filled", "plain"]
        },
        "password": {
            icon: String.fromCodePoint(0xF0306),
            file: "elements/LockPasswordElement.qml",
            scopes: ["panel"],
            requiredIn: "panel",
            providesPasswordInput: true,
            deletable: false,
            w: 380, h: 44, minW: 160, minH: 32, maxW: 1000, maxH: 80,
            variants: ["filled", "glass"]
        },
        "fingerprint": {
            icon: String.fromCodePoint(0xF0237),
            file: "elements/LockFingerprintElement.qml",
            scopes: ["screen", "panel"],
            scaled: true,
            defaultVariant: "classic",
            variants: ["classic", "ring", "scanner", "pulse", "orbit", "liquid"],
            variantAliases: { "labeled": "classic", "icon": "classic" },
            defaults: { showText: true },
            variantPropertyMigrations: {
                "icon": { showText: false }
            },
            additionalSettings: [
                {
                    id: "showText",
                    type: "toggle",
                    property: "showText",
                    label: I18n.t("lock.redactor.setting.show_text", "Show text"),
                    row: "bottom",
                    defaultValue: true
                }
            ]
        },
        "keyboard": {
            icon: String.fromCodePoint(0xF030C),
            file: "elements/LockKeyboardElement.qml",
            scopes: ["panel"],
            scaled: true,
            barModule: "kb",
            defaultVariant: "button",
            variantAliases: { "filled": "button", "plain": "text" }
        },
        "battery": {
            icon: String.fromCodePoint(0xF0079),
            file: "elements/LockBatteryElement.qml",
            scopes: ["panel"],
            scaled: true,
            barModule: "bat",
            defaultVariant: "button",
            variantAliases: { "filled": "button", "plain": "text" }
        },
        "notifications": {
            icon: String.fromCodePoint(0xF009A),
            file: "elements/LockNotificationsElement.qml",
            scopes: ["screen", "panel"],
            w: 400, h: 440, minW: 220, minH: 140, maxW: 800, maxH: 1000,
            variants: ["card", "plain"]
        }
    })

    function isWidget(type) {
        let t = registry.types[type];
        return (!!t && !!t.widgetKey) || String(type).indexOf("widget:") === 0;
    }

    function widgetKey(type) {
        let t = registry.types[type];
        if (t && t.widgetKey) return t.widgetKey;
        return String(type).indexOf("widget:") === 0 ? String(type).substring(7) : "";
    }

    function hasType(type) {
        if (registry.isWidget(type)) return WidgetRegistry.types[registry.widgetKey(type)] !== undefined;
        return registry.types[type] !== undefined;
    }

    function allowedIn(type, scope) {
        let t = registry.types[type];
        if (t && Array.isArray(t.scopes)) return t.scopes.indexOf(scope) >= 0;
        if (registry.isWidget(type)) return true;
        return false;
    }

    function isScaled(type) {
        let t = registry.types[type];
        return !!t && !t.widgetKey && t.scaled === true;
    }

    function isDeletable(type) {
        let t = registry.types[type];
        if (t) return t.deletable !== false;
        return registry.isWidget(type);
    }

    function requiredTypes(scope) {
        return registry.lockTypeIds.filter(id => registry.types[id] && registry.types[id].requiredIn === scope);
    }

    function providesPasswordInput(type) {
        let t = registry.types[type];
        return !!t && t.providesPasswordInput === true;
    }

    function typeName(type) {
        let t = registry.types[type];
        if (t && t.nameKey) return I18n.t(t.nameKey);
        if (registry.isWidget(type)) {
            let w = WidgetRegistry.types[registry.widgetKey(type)];
            return w ? w.name : "";
        }
        return I18n.t("lock.redactor.element." + type);
    }

    function typeIcon(type) {
        let t = registry.types[type];
        if (t && t.icon) return t.icon;
        if (registry.isWidget(type)) {
            let w = WidgetRegistry.types[registry.widgetKey(type)];
            return w ? w.icon : "";
        }
        return "";
    }

    function variantList(type) {
        if (registry.isWidget(type)) {
            return WidgetRegistry.variantList(registry.widgetKey(type)).map(v => ({ id: v.id, name: v.label || v.id }));
        }
        let t = registry.types[type];
        if (!t) return [];
        if (t.barModule) return BarModuleRegistry.variantList(t.barModule).map(v => ({ id: v.id, name: v.name }));
        return (t.variants || []).map(id => ({ id: id, name: I18n.t("lock.redactor.variant." + type + "." + id) }));
    }

    function variantProps(type, variant) {
        if (registry.isWidget(type)) return WidgetRegistry.variantProps(registry.widgetKey(type), variant);
        return null;
    }

    function variantCircleMask(type, variant) {
        if (registry.isWidget(type)) return WidgetRegistry.variantCircleMask(registry.widgetKey(type), variant);
        return false;
    }

    function additionalSettings(type, row, variant) {
        if (registry.isWidget(type)) return WidgetRegistry.additionalSettings(registry.widgetKey(type), row, variant);
        let t = registry.types[type];
        if (!t || !t.additionalSettings) return [];
        return t.additionalSettings.filter(s => (s.row || "top") === row);
    }

    function hasVariant(type, variantId) {
        return registry.variantList(type).some(v => v.id === variantId);
    }

    function defaultVariant(type) {
        let t = registry.types[type];
        if (t && t.defaultVariant) return t.defaultVariant;
        if (registry.isWidget(type)) return WidgetRegistry.defaultVariant(registry.widgetKey(type));
        if (!t || !t.variants) return "";
        return t.variants[0] || "";
    }

    function normalizeVariant(type, variantId) {
        let t = registry.types[type];
        return t && t.variantAliases && t.variantAliases[variantId] ? t.variantAliases[variantId] : variantId;
    }

    function defaultSize(type) {
        let t = registry.types[type];
        if (t && t.w > 0 && t.h > 0) return { w: t.w, h: t.h };
        if (registry.isWidget(type)) return WidgetRegistry.defaultSize(registry.widgetKey(type));
        if (!t || t.scaled) return { w: 0, h: 0 };
        return { w: t.w || 0, h: t.h || 0 };
    }

    function limits(type) {
        let t = registry.types[type];
        if (!t || t.widgetKey || t.scaled) return null;
        return { minW: t.minW, minH: t.minH, maxW: t.maxW, maxH: t.maxH, aspect: t.aspect || 0 };
    }

    function faceSource(type, variant) {
        if (registry.isWidget(type)) return WidgetRegistry.faceFile(registry.widgetKey(type), variant);
        let t = registry.types[type];
        return t ? t.file : "";
    }

    function migrateEntry(raw, entry) {
        let t = registry.types[raw.itype];
        if (!t) return;
        if (t.migrateZeroSize && entry.iw <= 0) {
            let cs = registry.defaultSize(raw.itype);
            entry.ix -= cs.w / 2;
            entry.iy -= cs.h / 2;
            entry.iw = cs.w;
            entry.ih = cs.h;
        }
        if (t.defaults) {
            for (let k in t.defaults) {
                if (entry[k] === undefined) entry[k] = t.defaults[k];
            }
        }
        if (t.variantPropertyMigrations && raw.ivariant && t.variantPropertyMigrations[raw.ivariant]) {
            let mig = t.variantPropertyMigrations[raw.ivariant];
            for (let mk in mig) {
                if (raw[mk] === undefined) entry[mk] = mig[mk];
            }
        }
    }

    function lockTypeList(scope) {
        return registry.lockTypeIds
            .filter(id => registry.allowedIn(id, scope) && registry.isDeletable(id))
            .map(id => ({ id: id, icon: registry.typeIcon(id), name: registry.typeName(id) }));
    }
}
