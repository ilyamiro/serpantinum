import QtQuick
import QtQuick.Layouts
import "../../"
import "../"
import "CanvasGeometry.js" as CanvasGeometry

Loader {
    id: loader

    required property var setting
    property var targetItem: null
    property var targetData: null
    property var typeData: null
    property var hostOwner: null
    property int revision: 0

    signal propertyEdited(string propName, var value)
    signal actionTriggered(string actionName)

    Layout.alignment: Qt.AlignVCenter

    readonly property string controlType: (setting && setting.type) ? String(setting.type) : "button"

    function readValue() {
        let s = loader.setting;
        if (!s || !s.property) return undefined;
        let prop = s.property;
        if (loader.targetItem && loader.targetItem[prop] !== undefined) return loader.targetItem[prop];
        if (loader.targetData && loader.targetData[prop] !== undefined) return loader.targetData[prop];
        if (loader.targetData && loader.targetData.wProps && loader.targetData.wProps[prop] !== undefined) return loader.targetData.wProps[prop];
        return s.defaultValue;
    }

    function writeValue(val) {
        let s = loader.setting;
        if (!s || !s.property) return;
        let prop = s.property;
        if (loader.targetItem) {
            try {
                if (loader.targetItem[prop] !== undefined) loader.targetItem[prop] = val;
                if (Array.isArray(s.mirrorProperties)) {
                    for (let i = 0; i < s.mirrorProperties.length; i++) {
                        let mp = s.mirrorProperties[i];
                        if (loader.targetItem[mp] !== undefined) loader.targetItem[mp] = val;
                    }
                }
            } catch (e) {}
        }
        loader.propertyEdited(prop, val);
    }

    sourceComponent: {
        let s = loader.setting;
        if (!s) return null;
        if (s.component) return s.component;
        if (s.sourceComponent) return s.sourceComponent;
        if (s.source || s.file) return null;
        if (loader.controlType === "number") return numberEditor;
        if (loader.controlType === "segmented") return segmentedEditor;
        if (loader.controlType === "toggle") return toggleEditor;
        if (loader.controlType === "dropdown") return dropdownEditor;
        if (loader.controlType === "text") return textEditor;
        if (loader.controlType === "font") return fontEditor;
        return actionButtonEditor;
    }

    source: {
        let s = loader.setting;
        if (!s || s.component || s.sourceComponent) return "";
        if (s.source) return Qt.resolvedUrl(s.source);
        if (s.file) return Qt.resolvedUrl(s.file);
        return "";
    }

    function syncControl() {
        if (!item) return;
        if (typeof item.syncFromTarget === "function") {
            item.syncFromTarget();
            return;
        }
        try { if (item.settingData !== undefined) item.settingData = loader.setting; } catch (e) {}
        try { if (item.typeData !== undefined) item.typeData = loader.typeData; } catch (e) {}
        try { if (item.redactor !== undefined) item.redactor = loader.hostOwner; } catch (e) {}
        try { if (item.widgetData !== undefined) item.widgetData = loader.targetData; } catch (e) {}
        try { if (item.item !== undefined) item.item = loader.targetItem; } catch (e) {}
        try { if (item.widget !== undefined) item.widget = loader.targetItem; } catch (e) {}
        try { if (item.targetWidget !== undefined) item.targetWidget = loader.targetItem; } catch (e) {}
    }

    onLoaded: syncControl()
    onTargetItemChanged: syncControl()
    onTargetDataChanged: syncControl()
    onSettingChanged: syncControl()
    onRevisionChanged: syncControl()

    Component {
        id: actionButtonEditor
        IconButton {
            size: Scaler.s(34)
            cornerRadius: ThemeBackend.borderRadius
            buttonIcon: (loader.setting && loader.setting.icon) ? loader.setting.icon : ""
            iconFontSize: Scaler.s((loader.setting && loader.setting.iconFontSize) ? loader.setting.iconFontSize : 16)
            accentColor: CanvasGeometry.resolveThemeColor((loader.setting && loader.setting.accentColor) ? loader.setting.accentColor : "surface0", ThemeBackend)
            textColor: CanvasGeometry.resolveThemeColor((loader.setting && loader.setting.textColor) ? loader.setting.textColor : "mauve", ThemeBackend)
            onClicked: {
                if (loader.setting && loader.setting.action) {
                    loader.actionTriggered(loader.setting.action);
                }
            }
        }
    }

    Component {
        id: numberEditor
        Item {
            id: numRoot
            implicitWidth: numSel.implicitWidth
            implicitHeight: numSel.implicitHeight

            function syncFromTarget() {
                let raw = loader.readValue();
                let v = (raw !== undefined && !isNaN(Number(raw))) ? Number(raw) : (loader.setting.defaultValue !== undefined ? loader.setting.defaultValue : 0);
                if (numSel.value !== v) numSel.setValue(v);
            }

            Component.onCompleted: syncFromTarget()

            NumberSelector {
                id: numSel
                anchors.centerIn: parent
                implicitWidth: Scaler.s((loader.setting && loader.setting.width) ? loader.setting.width : 120)
                implicitHeight: Scaler.s((loader.setting && loader.setting.height) ? loader.setting.height : 32)
                from: (loader.setting && loader.setting.min !== undefined) ? loader.setting.min : 0
                to: (loader.setting && loader.setting.max !== undefined) ? loader.setting.max : 100
                stepSize: (loader.setting && loader.setting.step !== undefined) ? loader.setting.step : 1
                decimals: (loader.setting && loader.setting.decimals !== undefined) ? loader.setting.decimals : 0
                suffix: (loader.setting && loader.setting.suffix) ? loader.setting.suffix : ""
                specialZeroText: (loader.setting && loader.setting.specialZeroText) ? loader.setting.specialZeroText : ""
                fontFamily: ThemeBackend.fontFamily
                accentColor: ThemeBackend.mauve
                baseColor: ThemeBackend.surface0
                buttonColor: ThemeBackend.surface1
                textColor: ThemeBackend.text
                buttonTextColor: ThemeBackend.subtext1
                cornerRadius: ThemeBackend.borderRadius

                onTriggered: {
                    let dec = (loader.setting && loader.setting.decimals !== undefined) ? loader.setting.decimals : 0;
                    let factor = Math.pow(10, dec);
                    let val = dec === 0 ? Math.round(numSel.value) : Math.round(numSel.value * factor) / factor;
                    loader.writeValue(val);
                }
            }
        }
    }

    Component {
        id: segmentedEditor
        Item {
            id: segRoot
            readonly property var entries: (loader.setting && Array.isArray(loader.setting.options)) ? loader.setting.options : []
            implicitWidth: segSwitch.implicitWidth
            implicitHeight: segSwitch.implicitHeight

            function optionValue(opt) {
                if (opt && typeof opt === "object") {
                    if (opt.value !== undefined) return opt.value;
                    if (opt.id !== undefined) return opt.id;
                }
                return opt;
            }

            function optionLabel(opt) {
                if (opt && typeof opt === "object") {
                    return opt.label || String(optionValue(opt));
                }
                return String(opt);
            }

            function syncFromTarget() {
                let cur = loader.readValue();
                for (let i = 0; i < segRoot.entries.length; i++) {
                    if (segRoot.optionValue(segRoot.entries[i]) === cur) {
                        if (segSwitch.currentIndex !== i) segSwitch.currentIndex = i;
                        return;
                    }
                }
            }

            Component.onCompleted: syncFromTarget()

            Switch {
                id: segSwitch
                anchors.centerIn: parent
                implicitHeight: Scaler.s((loader.setting && loader.setting.height) ? loader.setting.height : 34)
                implicitWidth: Scaler.s((loader.setting && loader.setting.width) ? loader.setting.width : 160)
                accentColor: ThemeBackend.mauve
                baseColor: ThemeBackend.surface0
                textColor: ThemeBackend.text
                activeTextColor: ThemeBackend.crust
                cornerRadius: ThemeBackend.borderRadius
                fontPixelSize: Scaler.s(11)
                options: segRoot.entries.map(o => segRoot.optionLabel(o))

                onToggled: (idx) => {
                    if (idx < 0 || idx >= segRoot.entries.length) return;
                    loader.writeValue(segRoot.optionValue(segRoot.entries[idx]));
                }
            }
        }
    }

    Component {
        id: toggleEditor
        Item {
            id: togRoot
            implicitWidth: togRow.implicitWidth + Scaler.s(20)
            implicitHeight: Scaler.s(34)

            function syncFromTarget() {
                let raw = loader.readValue();
                let cur = raw === undefined ? Boolean(loader.setting && loader.setting.defaultValue) : Boolean(raw);
                if (togCtrl.checked !== cur) togCtrl.checked = cur;
            }

            Component.onCompleted: syncFromTarget()

            Rectangle {
                anchors.fill: parent
                radius: ThemeBackend.borderRadius
                color: togGlass.active ? "transparent" : ThemeBackend.surface0

                GlassFill {
                    id: togGlass
                    anchors.fill: parent
                    radius: parent.radius
                    tintColor: ThemeBackend.surface0
                    tintAmount: 0.3
                }
            }

            Row {
                id: togRow
                anchors.centerIn: parent
                spacing: Scaler.s(8)

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: (loader.setting && loader.setting.label) ? loader.setting.label : ""
                    font.family: ThemeBackend.fontFamily
                    font.pixelSize: Scaler.s(11)
                    font.bold: true
                    color: ThemeBackend.text
                }

                Toggle {
                    id: togCtrl
                    anchors.verticalCenter: parent.verticalCenter
                    horizontalPadding: 0
                    cornerRadius: ThemeBackend.borderRadius
                    accentColor: ThemeBackend.mauve
                    baseColor: ThemeBackend.surface1
                    handleColor: ThemeBackend.crust
                    handleOffColor: ThemeBackend.text
                    onToggled: function(c) {
                        loader.writeValue(c);
                    }
                }
            }
        }
    }

    Component {
        id: dropdownEditor
        Item {
            id: ddRoot
            readonly property var entries: (loader.setting && Array.isArray(loader.setting.options)) ? loader.setting.options : []
            readonly property string suffix: (loader.setting && loader.setting.suffix) ? loader.setting.suffix : ""
            readonly property bool matchNearest: !!(loader.setting && loader.setting.matchNearest)

            implicitWidth: Scaler.s((loader.setting && loader.setting.width) ? loader.setting.width : 120)
            implicitHeight: Scaler.s((loader.setting && loader.setting.height) ? loader.setting.height : 34)

            function optionValue(opt) {
                if (opt && typeof opt === "object") {
                    if (opt.value !== undefined) return opt.value;
                    if (opt.id !== undefined) return opt.id;
                }
                return opt;
            }

            function optionLabel(opt) {
                if (opt && typeof opt === "object") return opt.label || String(optionValue(opt));
                return String(opt) + ddRoot.suffix;
            }

            function syncFromTarget() {
                if (ddRoot.entries.length === 0) return;
                let cur = loader.readValue();
                if (ddRoot.matchNearest) {
                    let num = Number(cur);
                    let best = 0;
                    for (let i = 1; i < ddRoot.entries.length; i++) {
                        if (Math.abs(Number(ddRoot.optionValue(ddRoot.entries[i])) - num) < Math.abs(Number(ddRoot.optionValue(ddRoot.entries[best])) - num)) {
                            best = i;
                        }
                    }
                    if (ddCtrl.currentIndex !== best) ddCtrl.currentIndex = best;
                    return;
                }
                for (let j = 0; j < ddRoot.entries.length; j++) {
                    if (ddRoot.optionValue(ddRoot.entries[j]) === cur) {
                        if (ddCtrl.currentIndex !== j) ddCtrl.currentIndex = j;
                        return;
                    }
                }
            }

            Component.onCompleted: syncFromTarget()

            Dropdown {
                id: ddCtrl
                anchors.fill: parent
                options: ddRoot.entries.map(o => ddRoot.optionLabel(o))
                fuzzySearch: false
                accentColor: ThemeBackend.mauve
                baseColor: ThemeBackend.surface0
                dropdownColor: ThemeBackend.base
                borderColor: Qt.alpha(ThemeBackend.surface2, 0.6)
                textColor: ThemeBackend.text
                activeTextColor: ThemeBackend.crust
                cornerRadius: ThemeBackend.borderRadius
                fontPixelSize: Scaler.s(11)

                onValueChanged: function(index, value) {
                    if (index < 0 || index >= ddRoot.entries.length) return;
                    let val = ddRoot.optionValue(ddRoot.entries[index]);
                    if (loader.readValue() === val) return;
                    loader.writeValue(val);
                }
            }
        }
    }

    Component {
        id: textEditor
        Item {
            id: txtRoot
            implicitWidth: Scaler.s((loader.setting && loader.setting.width) ? loader.setting.width : 240)
            implicitHeight: Scaler.s((loader.setting && loader.setting.height) ? loader.setting.height : 34)

            function syncFromTarget() {
                if (txtInput.hasFocus) return;
                let raw = loader.readValue();
                let cur = raw !== undefined && raw !== null ? String(raw) : "";
                if (txtInput.text !== cur) txtInput.text = cur;
            }

            Component.onCompleted: syncFromTarget()

            Input {
                id: txtInput
                anchors.fill: parent
                placeholderText: (loader.setting && loader.setting.placeholder) ? loader.setting.placeholder : ""
                fontPixelSize: Scaler.s(12)
                baseColor: ThemeBackend.surface0
                accentColor: ThemeBackend.mauve
                textColor: ThemeBackend.text
                subTextColor: ThemeBackend.subtext0
                borderColor: Qt.alpha(ThemeBackend.surface2, 0.6)
                cornerRadius: ThemeBackend.borderRadius
                horizontalPadding: Scaler.s(10)

                onTextEdited: function(newText) {
                    loader.writeValue(newText);
                }
            }
        }
    }

    Component {
        id: fontEditor
        Item {
            id: fontRoot
            readonly property string defaultLabel: (loader.setting && loader.setting.defaultLabel) ? loader.setting.defaultLabel : I18n.t("widgets.variants.default", "Default")
            readonly property var blockedPatterns: [".notdef", "cursor", "emoji", "symbol", "pcf"]
            property var fontNames: []

            implicitWidth: Scaler.s((loader.setting && loader.setting.width) ? loader.setting.width : 200)
            implicitHeight: Scaler.s((loader.setting && loader.setting.height) ? loader.setting.height : 34)

            function loadFonts() {
                let seen = new Set();
                let names = [];
                let add = function(name) {
                    let key = name.toLowerCase().trim();
                    if (key === "" || seen.has(key)) return;
                    for (let i = 0; i < fontRoot.blockedPatterns.length; i++) {
                        if (key.indexOf(fontRoot.blockedPatterns[i]) !== -1) return;
                    }
                    seen.add(key);
                    names.push(name);
                };
                let bundled = ThemeBackend.bundledNames || [];
                for (let i = 0; i < bundled.length; i++) add(bundled[i]);
                let rest = [];
                let raw = Qt.fontFamilies();
                for (let i = 0; i < raw.length; i++) {
                    if (!seen.has(raw[i].toLowerCase().trim())) rest.push(raw[i]);
                }
                rest.sort(function(a, b) { return a.localeCompare(b); });
                for (let i = 0; i < rest.length; i++) add(rest[i]);
                let cur = loader.readValue();
                if (cur) add(String(cur));
                fontRoot.fontNames = names;
            }

            function syncFromTarget() {
                let raw = loader.readValue();
                let cur = raw !== undefined && raw !== null ? String(raw) : "";
                if (cur !== "" && fontRoot.fontNames.indexOf(cur) === -1) fontRoot.loadFonts();
                let idx = cur === "" ? 0 : fontRoot.fontNames.indexOf(cur) + 1;
                if (fontDropdown.currentIndex !== idx) fontDropdown.currentIndex = idx;
            }

            Component.onCompleted: {
                loadFonts();
                syncFromTarget();
            }

            Dropdown {
                id: fontDropdown
                anchors.fill: parent
                options: [fontRoot.defaultLabel].concat(fontRoot.fontNames)
                placeholderText: (loader.setting && loader.setting.placeholder) ? loader.setting.placeholder : I18n.t("guide.theme.font.select")
                useOptionAsFontFamily: true
                accentColor: ThemeBackend.mauve
                baseColor: ThemeBackend.surface0
                dropdownColor: ThemeBackend.base
                borderColor: Qt.alpha(ThemeBackend.surface2, 0.6)
                textColor: ThemeBackend.text
                activeTextColor: ThemeBackend.crust
                cornerRadius: ThemeBackend.borderRadius
                fontPixelSize: Scaler.s(11)

                onValueChanged: function(index, value) {
                    let val = index <= 0 ? "" : value;
                    if (String(loader.readValue() || "") === val) return;
                    loader.writeValue(val);
                }
            }
        }
    }
}
