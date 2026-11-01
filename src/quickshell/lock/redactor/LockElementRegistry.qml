pragma Singleton
import QtQuick
import "../../"
import "../../widgets"
import "../../bar"
import "../../reusables"

QtObject {
    id: registry

    property Component showTextComponent: Component {
        Item {
            id: settingRoot
            property var proxy: null
            property var redactor: null

            implicitWidth: showTextRow.implicitWidth + Scaler.s(20)
            implicitHeight: Scaler.s(34)

            Rectangle {
                anchors.fill: parent
                radius: ThemeBackend.borderRadius
                color: showTextGlass.active ? "transparent" : ThemeBackend.surface0

                GlassFill {
                    id: showTextGlass
                    anchors.fill: parent
                    radius: parent.radius
                    tintColor: ThemeBackend.surface0
                    tintAmount: 0.3
                }
            }

            Row {
                id: showTextRow
                anchors.centerIn: parent
                spacing: Scaler.s(8)

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: I18n.t("lock.redactor.setting.show_text", "Show text")
                    font.family: ThemeBackend.fontFamily
                    font.pixelSize: Scaler.s(11)
                    font.bold: true
                    color: ThemeBackend.text
                }

                Toggle {
                    anchors.verticalCenter: parent.verticalCenter
                    horizontalPadding: 0
                    cornerRadius: ThemeBackend.borderRadius
                    checked: settingRoot.proxy ? settingRoot.proxy.pShowText : true
                    accentColor: ThemeBackend.accent
                    baseColor: ThemeBackend.surface1
                    handleColor: ThemeBackend.crust
                    handleOffColor: ThemeBackend.text
                    onToggled: function(c) {
                        if (settingRoot.redactor && settingRoot.proxy) settingRoot.redactor.setWidgetProperty("showText", c, settingRoot.proxy.pId);
                    }
                }
            }
        }
    }

    readonly property var lockTypeIds: ["clock", "avatar", "user", "lockstatus", "password", "fingerprint", "keyboard", "battery", "notifications"]

    readonly property var types: ({
        "clock": {
            icon: String.fromCodePoint(0xF0954),
            scopes: ["screen"],
            widgetKey: "time",
            defaultVariant: "lockscreen",
            w: 420, h: 200
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
            additionalSettings: [
                { id: "showText", row: "bottom", component: registry.showTextComponent }
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
        },
    })

    function isWidget(type) {
        return type === "clock" || String(type).indexOf("widget:") === 0;
    }

    function widgetKey(type) {
        return type === "clock" ? registry.types["clock"].widgetKey : String(type).substring(7);
    }

    function hasType(type) {
        if (registry.isWidget(type)) return WidgetRegistry.types[registry.widgetKey(type)] !== undefined;
        return registry.types[type] !== undefined;
    }

    function allowedIn(type, scope) {
        if (registry.isWidget(type)) return true;
        let t = registry.types[type];
        return !!t && t.scopes.indexOf(scope) >= 0;
    }

    function isScaled(type) {
        if (registry.isWidget(type)) return false;
        let t = registry.types[type];
        return !!t && t.scaled === true;
    }

    function isDeletable(type) {
        if (registry.isWidget(type)) return true;
        let t = registry.types[type];
        return !!t && t.deletable !== false;
    }

    function typeName(type) {
        if (type === "clock") return I18n.t("lock.redactor.element.clock");
        if (registry.isWidget(type)) {
            let w = WidgetRegistry.types[registry.widgetKey(type)];
            return w ? w.name : "";
        }
        return I18n.t("lock.redactor.element." + type);
    }

    function typeIcon(type) {
        if (registry.isWidget(type)) {
            let w = WidgetRegistry.types[registry.widgetKey(type)];
            return w ? w.icon : "";
        }
        return registry.types[type] ? registry.types[type].icon : "";
    }

    function variantList(type) {
        if (registry.isWidget(type)) {
            return WidgetRegistry.variantList(registry.widgetKey(type)).map(v => ({ id: v.id, name: v.label || v.id }));
        }
        let t = registry.types[type];
        if (!t) return [];
        if (t.barModule) return BarModuleRegistry.variantList(t.barModule).map(v => ({ id: v.id, name: v.name }));
        return t.variants.map(id => ({ id: id, name: I18n.t("lock.redactor.variant." + type + "." + id) }));
    }

    function additionalSettings(type, row) {
        if (registry.isWidget(type)) return [];
        let t = registry.types[type];
        if (!t || !t.additionalSettings) return [];
        return t.additionalSettings.filter(s => (s.row || "top") === row);
    }

    function hasVariant(type, variantId) {
        return registry.variantList(type).some(v => v.id === variantId);
    }

    function defaultVariant(type) {
        if (type === "clock") return registry.types["clock"].defaultVariant;
        if (registry.isWidget(type)) return WidgetRegistry.defaultVariant(registry.widgetKey(type));
        let t = registry.types[type];
        if (!t) return "";
        return t.defaultVariant || t.variants[0];
    }

    function normalizeVariant(type, variantId) {
        let t = registry.isWidget(type) ? null : registry.types[type];
        return t && t.variantAliases && t.variantAliases[variantId] ? t.variantAliases[variantId] : variantId;
    }

    function defaultSize(type) {
        if (type === "clock") return { w: registry.types["clock"].w, h: registry.types["clock"].h };
        if (registry.isWidget(type)) return WidgetRegistry.defaultSize(registry.widgetKey(type));
        let t = registry.types[type];
        if (!t || t.scaled) return { w: 0, h: 0 };
        return { w: t.w, h: t.h };
    }

    function limits(type) {
        let t = registry.isWidget(type) ? null : registry.types[type];
        if (!t || t.scaled) return null;
        return { minW: t.minW, minH: t.minH, maxW: t.maxW, maxH: t.maxH, aspect: t.aspect || 0 };
    }

    function faceSource(type, variant) {
        if (registry.isWidget(type)) return WidgetRegistry.faceFile(registry.widgetKey(type), variant);
        let t = registry.types[type];
        return t ? t.file : "";
    }

    function lockTypeList(scope) {
        return registry.lockTypeIds
            .filter(id => registry.allowedIn(id, scope) && registry.isDeletable(id))
            .map(id => ({ id: id, icon: registry.typeIcon(id), name: registry.typeName(id) }));
    }
}
