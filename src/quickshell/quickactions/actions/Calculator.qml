import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import QtQml
import Quickshell
import Quickshell.Io
import "../../reusables"
import "../../"
import "CalculatorEngine.js" as Engine

Item {
    id: root

    property int requestedLayoutTemplate: 1
    property bool isActiveTab: typeof isCurrentTarget !== "undefined" ? isCurrentTarget : true
    property string safeActiveEdge: typeof activeEdge !== "undefined" ? activeEdge : "left"

    property bool stateLoaded: false
    property var interceptedShortcuts: ["Return", "Enter"]

    function s(val) {
        return typeof scaleFunc === "function" ? scaleFunc(val) : val;
    }

    property bool advanced: false

    property real baseW: s(advanced ? 580 : 380)
    property real baseL: s(advanced ? 420 : 350)

    property real preferredWidth: (root.safeActiveEdge === "bottom" || root.safeActiveEdge === "top") ? baseL + s(100) : baseW
    property real preferredExtraLength: (root.safeActiveEdge === "bottom" || root.safeActiveEdge === "top") ? baseW - s(60) : baseL

    property real counterRotation: {
        if (root.safeActiveEdge === "right") return 180;
        if (root.safeActiveEdge === "bottom") return 90;
        if (root.safeActiveEdge === "top") return -90;
        return 0;
    }

    property string expr: ""
    property string preview: ""
    property string lastExpr: ""
    property string repeatSuffix: ""
    property string errorCode: ""
    property bool evaluated: false
    property string angleMode: "deg"
    property bool inverse: false
    property bool copiedFlash: false
    readonly property bool hasInputFocus: field.hasFocus
    property var history: []

    readonly property string subText: {
        let dummy = I18n.currentLang;
        if (root.errorCode !== "") return I18n.t("quickactions.calculator.error." + root.errorCode);
        if (root.evaluated) return "";
        return root.preview;
    }

    readonly property var sciGroups: [
        ["inv", "sin", "cos", "tan", "angle"],
        ["pi", "sinh", "cosh", "tanh", "e"],
        ["pow", "sq", "sqrt", "ln", "log"],
        ["fact", "abs", "recip", "exp", "tenpow"]
    ]
    readonly property var shiftable: ["sin", "cos", "tan", "sinh", "cosh", "tanh", "sq", "sqrt"]

    readonly property bool containerOpen: typeof isExpandedState !== "undefined" ? isExpandedState : true
    readonly property bool popupAllowed: root.visible && root.isActiveTab && root.containerOpen
    onPopupAllowedChanged: {
        if (!root.popupAllowed) {
            modeDropdown.closePopup();
            field.releaseFocus();
        }
    }

    readonly property var mainKeys: {
        let dummy = I18n.currentLang;
        return [
            { id: "clear", label: I18n.t("quickactions.calculator.clear"), kind: "danger" },
            { id: "back", icon: "󰁮" },
            { id: "paren", label: "( )", kind: "operator" },
            { id: "÷", label: "÷", kind: "operator" },
            { id: "7", label: "7" }, { id: "8", label: "8" }, { id: "9", label: "9" },
            { id: "×", label: "×", kind: "operator" },
            { id: "4", label: "4" }, { id: "5", label: "5" }, { id: "6", label: "6" },
            { id: "−", label: "−", kind: "operator" },
            { id: "1", label: "1" }, { id: "2", label: "2" }, { id: "3", label: "3" },
            { id: "+", label: "+", kind: "operator" },
            { id: "0", label: "0" },
            { id: ".", label: "." },
            { id: "%", label: "%", kind: "operator" },
            { id: "equals", label: "=", kind: "primary" }
        ];
    }

    readonly property var shortcutKeys: [
        { seq: "0", id: "0" }, { seq: "1", id: "1" }, { seq: "2", id: "2" }, { seq: "3", id: "3" },
        { seq: "4", id: "4" }, { seq: "5", id: "5" }, { seq: "6", id: "6" }, { seq: "7", id: "7" },
        { seq: "8", id: "8" }, { seq: "9", id: "9" },
        { seq: ".", id: "." },
        { seq: "+", id: "+" }, { seq: "-", id: "−" }, { seq: "*", id: "×" }, { seq: "/", id: "÷" },
        { seq: "^", id: "^" }, { seq: "%", id: "%" }, { seq: "!", id: "fact" },
        { seq: "(", id: "(" }, { seq: ")", id: ")" }, { seq: "=", id: "equals" },
        { seq: "Backspace", id: "back" }, { seq: "Delete", id: "clear" },
        { seq: "Ctrl+C", id: "copy" }, { seq: "Ctrl+V", id: "paste" }
    ]

    function getStorageDir() {
        return (typeof Caching !== "undefined" && Caching.stateDir ? Caching.stateDir : ((Quickshell.env("HOME") || "") + "/.local/state/serpantinum")) + "/quickactions";
    }

    Process {
        id: saveStateProc
    }

    Process {
        id: loadStateProc
        command: ["bash", "-c", "FILE='" + root.getStorageDir() + "/calculator.json'; if [ -f \"$FILE\" ]; then cat \"$FILE\"; else echo '{}'; fi"]
        stdout: StdioCollector {
            id: loadStateOut
            onStreamFinished: root.restoreState(loadStateOut.text)
        }
    }

    Process {
        id: pasteProc
        command: ["sh", "-c", "command -v wl-paste >/dev/null 2>&1 && wl-paste --no-newline 2>/dev/null"]
        stdout: StdioCollector {
            id: pasteOut
            onStreamFinished: root.insertText(pasteOut.text)
        }
    }

    Timer {
        id: copiedTimer
        interval: 1400
        onTriggered: root.copiedFlash = false
    }

    Component.onCompleted: loadStateProc.running = true

    function restoreState(rawText) {
        let txt = (rawText || "").trim();
        if (txt !== "") {
            try {
                let data = JSON.parse(txt);
                if (data && Array.isArray(data.history)) {
                    root.history = data.history.filter(h => h && typeof h.expr === "string" && typeof h.result === "string");
                }
                if (data && ["deg", "rad", "grad"].indexOf(data.angleMode) !== -1) root.angleMode = data.angleMode;
                if (data && data.advanced !== undefined) root.advanced = !!data.advanced;
            } catch (e) {}
        }
        root.stateLoaded = true;
    }

    function saveState() {
        if (!root.stateLoaded) return;
        let dir = root.getStorageDir();
        let jsonStr = JSON.stringify({ history: root.history, angleMode: root.angleMode, advanced: root.advanced });
        saveStateProc.running = false;
        saveStateProc.command = ["bash", "-c", "mkdir -p '" + dir + "' && printf '%s\\n' '" + jsonStr.replace(/'/g, "'\\''") + "' > '" + dir + "/calculator.json'"];
        saveStateProc.running = true;
    }

    onAngleModeChanged: {
        recompute();
        saveState();
    }
    onAdvancedChanged: saveState()

    onExprChanged: {
        recompute();
        if (field.text !== root.expr) field.text = root.expr;
    }

    function typed(text) {
        let wantsEquals = String(text).indexOf("=") !== -1;
        let clean = Engine.sanitizeTyped(text);
        root.evaluated = false;
        root.lastExpr = "";
        root.errorCode = "";
        root.expr = clean;
        if (field.text !== clean) field.text = clean;
        if (wantsEquals) root.equals();
    }

    function recompute() {
        root.preview = "";
        if (root.evaluated) return;
        let e = Engine.trimTrailing(root.expr);
        if (e === "" || !Engine.hasOperation(e)) return;
        try {
            let text = Engine.format(Engine.evaluate(Engine.closeParens(e), root.angleMode));
            if (text !== e) root.preview = text;
        } catch (err) {}
    }

    function lastChar() {
        let t = root.expr.replace(/\s+$/, "");
        return t.charAt(t.length - 1);
    }

    function isDigit(c) {
        return c >= "0" && c <= "9";
    }

    function isOperatorChar(c) {
        return c !== "" && "+−×÷^".indexOf(c) !== -1;
    }

    function endsWithOperand() {
        let c = root.lastChar();
        return root.isDigit(c) || c === ")" || c === "π" || c === "e" || c === "%" || c === "!";
    }

    function beginEntry() {
        if (root.evaluated) {
            root.evaluated = false;
            root.lastExpr = "";
            root.expr = "";
        }
        root.errorCode = "";
    }

    function continueFromResult() {
        if (root.evaluated) {
            root.evaluated = false;
            root.lastExpr = "";
        }
        root.errorCode = "";
    }

    function inputDigit(d) {
        root.beginEntry();
        let m = /(\d*\.?\d*)$/.exec(root.expr);
        let seg = m ? m[1] : "";
        if (seg === "0") {
            if (d === "0") return;
            root.expr = root.expr.slice(0, -1) + d;
            return;
        }
        root.expr += d;
    }

    function inputDot() {
        root.beginEntry();
        let m = /(\d*\.?\d*)$/.exec(root.expr);
        let seg = m ? m[1] : "";
        if (seg.indexOf(".") !== -1) return;
        root.expr += seg === "" ? "0." : ".";
    }

    function inputOperator(op) {
        root.continueFromResult();
        if (root.expr === "") {
            if (op === "−") root.expr = "−";
            return;
        }
        let c = root.lastChar();
        if (root.isOperatorChar(c)) {
            if (op === "−" && (c === "×" || c === "÷" || c === "^")) {
                root.expr += op;
                return;
            }
            let e = root.expr.replace(/\s+$/, "");
            while (e !== "" && root.isOperatorChar(e.charAt(e.length - 1))) e = e.slice(0, -1);
            if (e === "") return;
            root.expr = e + op;
        } else if (c === "(") {
            if (op === "−") root.expr += op;
        } else {
            root.expr += op;
        }
    }

    function inputPostfix(token) {
        root.continueFromResult();
        if (!root.endsWithOperand()) return;
        root.expr += token;
    }

    function inputFunction(token) {
        root.beginEntry();
        root.expr += token;
    }

    function inputConstant(c) {
        root.beginEntry();
        root.expr += c;
    }

    function inputOpenParen() {
        root.beginEntry();
        root.expr += "(";
    }

    function inputCloseParen() {
        root.continueFromResult();
        let c = root.lastChar();
        if (Engine.openParens(root.expr) === 0 || c === "(" || root.isOperatorChar(c)) return;
        root.expr += ")";
    }

    function inputSmartParen() {
        if (Engine.openParens(root.expr) > 0 && root.endsWithOperand()) root.inputCloseParen();
        else root.inputOpenParen();
    }

    function backspace() {
        root.errorCode = "";
        root.evaluated = false;
        root.lastExpr = "";
        root.expr = Engine.removeLastToken(root.expr);
    }

    function clearAll() {
        root.evaluated = false;
        root.lastExpr = "";
        root.errorCode = "";
        root.expr = "";
        root.preview = "";
    }

    function pushHistory(expression, result) {
        let list = root.history.slice();
        let top = list.length > 0 ? list[list.length - 1] : null;
        if (!top || top.expr !== expression || top.result !== result) {
            list.push({ expr: expression, result: result, ts: Date.now() });
        }
        if (list.length > 100) list = list.slice(list.length - 100);
        root.history = list;
        root.saveState();
    }

    function clearHistory() {
        root.history = [];
        root.saveState();
    }

    function trailingOperation(expression) {
        let depth = 0;
        let found = -1;
        for (let i = 0; i < expression.length; i++) {
            let ch = expression.charAt(i);
            if (ch === "(") depth++;
            else if (ch === ")") depth--;
            else if (depth === 0 && i > 0 && "+−×÷^".indexOf(ch) !== -1) {
                let prev = expression.slice(0, i).replace(/\s+$/, "").slice(-1);
                if (prev !== "" && (root.isDigit(prev) || prev === ")" || prev === "π" || prev === "e" || prev === "%" || prev === "!")) found = i;
            }
        }
        return found === -1 ? "" : expression.slice(found).replace(/\s+$/, "");
    }

    function equals() {
        let repeating = root.evaluated;
        let source = root.expr;
        if (repeating) {
            if (root.repeatSuffix === "") return;
            source = (source.charAt(0) === "−" ? "(" + source + ")" : source) + root.repeatSuffix;
        }
        let e = Engine.trimTrailing(source);
        if (e === "") return;
        let closed = Engine.closeParens(e);
        try {
            let text = Engine.format(Engine.evaluate(closed, root.angleMode));
            if (closed !== text) root.pushHistory(closed, text);
            if (!repeating) root.repeatSuffix = root.trailingOperation(closed);
            root.errorCode = "";
            root.preview = "";
            root.lastExpr = closed;
            root.evaluated = true;
            root.expr = text;
        } catch (err) {
            root.errorCode = err.message === "div0" || err.message === "domain" ? err.message : (err.message === "empty" ? "" : "syntax");
        }
    }

    function insertText(text) {
        let t = Engine.normalizeClipboard(text || "");
        if (t === "" || t.length > 256 || !Engine.isValid(t)) {
            root.errorCode = "paste";
            return;
        }
        root.beginEntry();
        root.expr += t;
    }

    function copyText(text) {
        if (!text) return;
        Quickshell.execDetached(["wl-copy", "--", Engine.toPlain(text)]);
        root.copiedFlash = true;
        copiedTimer.restart();
    }

    function copyDisplay() {
        if (root.evaluated || root.preview === "") root.copyText(root.expr);
        else root.copyText(root.preview);
    }

    function pasteClipboard() {
        if (!pasteProc.running) pasteProc.running = true;
    }

    function handle(id) {
        switch (id) {
        case "inv": root.inverse = !root.inverse; break;
        case "angle": root.angleMode = root.angleMode === "deg" ? "rad" : (root.angleMode === "rad" ? "grad" : "deg"); break;
        case "paren": root.inputSmartParen(); break;
        case "copy": root.copyDisplay(); break;
        case "paste": root.pasteClipboard(); break;
        case "clear": root.clearAll(); break;
        case "back": root.backspace(); break;
        case "equals": root.equals(); break;
        case ".": root.inputDot(); break;
        case "+": case "−": case "×": case "÷": case "^": root.inputOperator(id); break;
        case "%": root.inputPostfix("%"); break;
        case "fact": root.inputPostfix("!"); break;
        case "sq": root.inputPostfix(root.inverse ? "^3" : "^2"); break;
        case "recip": root.inputPostfix("^(−1)"); break;
        case "abs": root.inputFunction("abs("); break;
        case "exp": root.inputFunction("e^("); break;
        case "tenpow": root.inputFunction("10^("); break;
        case "pow": root.inputOperator("^"); break;
        case "(": root.inputOpenParen(); break;
        case ")": root.inputCloseParen(); break;
        case "pi": root.inputConstant("π"); break;
        case "e": root.inputConstant("e"); break;
        case "sin": root.inputFunction(root.inverse ? "sin⁻¹(" : "sin("); break;
        case "cos": root.inputFunction(root.inverse ? "cos⁻¹(" : "cos("); break;
        case "tan": root.inputFunction(root.inverse ? "tan⁻¹(" : "tan("); break;
        case "sinh": root.inputFunction(root.inverse ? "sinh⁻¹(" : "sinh("); break;
        case "cosh": root.inputFunction(root.inverse ? "cosh⁻¹(" : "cosh("); break;
        case "tanh": root.inputFunction(root.inverse ? "tanh⁻¹(" : "tanh("); break;
        case "ln": root.inputFunction("ln("); break;
        case "log": root.inputFunction("log("); break;
        case "sqrt": root.inputFunction(root.inverse ? "∛(" : "√("); break;
        default:
            if (id.length === 1 && root.isDigit(id)) root.inputDigit(id);
            break;
        }
    }

    function sciLabel(id) {
        let dummy = I18n.currentLang;
        let inv = root.inverse;
        switch (id) {
        case "inv": return "⇧⁻¹";
        case "angle": return I18n.t("quickactions.calculator." + root.angleMode);
        case "sin": return inv ? "sin⁻¹" : "sin";
        case "cos": return inv ? "cos⁻¹" : "cos";
        case "tan": return inv ? "tan⁻¹" : "tan";
        case "sinh": return inv ? "sinh⁻¹" : "sinh";
        case "cosh": return inv ? "cosh⁻¹" : "cosh";
        case "tanh": return inv ? "tanh⁻¹" : "tanh";
        case "pi": return "π";
        case "e": return "e";
        case "ln": return "ln";
        case "log": return "log";
        case "sqrt": return inv ? "∛" : "√";
        case "sq": return inv ? "x³" : "x²";
        case "abs": return "|x|";
        case "exp": return "eˣ";
        case "tenpow": return "10ˣ";
        case "recip": return "x⁻¹";
        case "pow": return "xʸ";
        case "fact": return "x!";
        }
        return id;
    }

    readonly property bool shortcutsEnabled: root.isActiveTab && root.visible && !field.hasFocus

    Instantiator {
        model: root.shortcutKeys
        delegate: Shortcut {
            enabled: root.shortcutsEnabled
            sequence: modelData.seq
            onActivated: root.handle(modelData.id)
        }
    }

    Shortcut { enabled: root.shortcutsEnabled; sequence: "Return"; onActivated: root.handle("equals") }
    Shortcut { enabled: root.shortcutsEnabled; sequence: "Enter"; onActivated: root.handle("equals") }

    Item {
        id: orientedRoot
        anchors.centerIn: parent
        width: (root.counterRotation % 180 !== 0) ? parent.height : parent.width
        height: (root.counterRotation % 180 !== 0) ? parent.width : parent.height
        rotation: root.counterRotation
        clip: true

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: root.s(10)
            spacing: root.s(8)

            RowLayout {
                Layout.fillWidth: true
                Layout.fillHeight: false
                Layout.preferredHeight: root.s(32)
                layoutDirection: I18n.layoutDirection
                spacing: root.s(6)

                Dropdown {
                    id: modeDropdown
                    Layout.preferredWidth: root.s(150)
                    Layout.preferredHeight: root.s(32)
                    fuzzySearch: false
                    options: {
                        let dummy = I18n.currentLang;
                        return [I18n.t("quickactions.calculator.mode.normal"), I18n.t("quickactions.calculator.mode.advanced")];
                    }
                    accentColor: ThemeBackend.blue
                    baseColor: ThemeBackend.surface0
                    hoverColor: ThemeBackend.surface1
                    dropdownColor: ThemeBackend.surface0
                    borderColor: Qt.alpha(ThemeBackend.surface2, 0.6)
                    textColor: ThemeBackend.text
                    activeTextColor: ThemeBackend.mantle
                    cornerRadius: ThemeBackend.borderRadius
                    fontPixelSize: Math.round(root.s(12))
                    onSelected: function(index, value) {
                        root.advanced = index === 1;
                    }
                    Binding { target: modeDropdown; property: "currentIndex"; value: root.advanced ? 1 : 0 }
                }

                Text {
                    Layout.fillWidth: true
                    text: I18n.t("quickactions.calculator.copied")
                    visible: root.copiedFlash
                    color: ThemeBackend.blue
                    font.family: ThemeBackend.fontFamily
                    font.pixelSize: root.s(12)
                    font.bold: true
                    horizontalAlignment: Text.AlignHCenter
                }

                Item {
                    Layout.fillWidth: true
                    visible: !root.copiedFlash
                }

                DeleteButton {
                    visible: root.history.length > 0
                    size: root.s(32)
                    cornerRadius: ThemeBackend.borderRadius
                    iconFontSize: root.s(15)
                    accentColor: ThemeBackend.surface0
                    bgOpacity: ThemeBackend.elementOpacity
                    onClicked: root.clearHistory()
                }

                IconButton {
                    size: root.s(32)
                    cornerRadius: ThemeBackend.borderRadius
                    buttonIcon: "󰆒"
                    iconFontSize: root.s(15)
                    accentColor: ThemeBackend.surface0
                    textColor: ThemeBackend.text
                    bgOpacity: ThemeBackend.elementOpacity
                    onClicked: root.handle("paste")
                }

                IconButton {
                    size: root.s(32)
                    cornerRadius: ThemeBackend.borderRadius
                    buttonIcon: "󰆏"
                    iconFontSize: root.s(15)
                    accentColor: ThemeBackend.surface0
                    textColor: ThemeBackend.text
                    bgOpacity: ThemeBackend.elementOpacity
                    onClicked: root.handle("copy")
                }
            }

            Rectangle {
                id: displayBox
                Layout.fillWidth: true
                Layout.fillHeight: true
                radius: ThemeBackend.borderRadius
                clip: true
                color: displayGlass.active ? "transparent" : Qt.alpha(ThemeBackend.surface0, ThemeBackend.elementOpacity)

                GlassFill {
                    id: displayGlass
                    anchors.fill: parent
                    radius: parent.radius
                    tintColor: ThemeBackend.surface0
                    tintAmount: 0.3
                }

                ColumnLayout {
                    anchors.fill: parent
                    spacing: 0

                    Item {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        Layout.minimumHeight: 0

                        Text {
                            anchors.centerIn: parent
                            width: parent.width - root.s(28)
                            visible: root.history.length === 0
                            text: I18n.t("quickactions.calculator.no_history")
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                            wrapMode: Text.WordWrap
                            color: ThemeBackend.subtext0
                            font.family: ThemeBackend.fontFamily
                            font.pixelSize: root.s(13)
                        }

                    ListView {
                        id: historyList
                        anchors.fill: parent
                        clip: true
                        verticalLayoutDirection: ListView.BottomToTop
                        model: root.history.length
                        boundsBehavior: Flickable.StopAtBounds

                        ScrollBar.vertical: ScrollBar {
                            active: historyList.moving
                            policy: ScrollBar.AsNeeded
                            width: root.s(4)
                            contentItem: Rectangle {
                                implicitWidth: root.s(4)
                                radius: root.s(2)
                                color: ThemeBackend.surface2
                            }
                        }

                        delegate: Item {
                            id: historyRow
                            width: historyList.width
                            height: root.s(36)
                            property var entry: root.history[root.history.length - 1 - index]

                            Rectangle {
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.bottom: parent.bottom
                                height: 1
                                color: Qt.alpha(ThemeBackend.surface2, 0.5)
                            }

                            Item {
                                anchors.left: parent.left
                                anchors.leftMargin: root.s(14)
                                anchors.verticalCenter: parent.verticalCenter
                                width: parent.width * 0.45
                                height: parent.height

                                Text {
                                    anchors.fill: parent
                                    text: historyRow.entry ? historyRow.entry.expr : ""
                                    verticalAlignment: Text.AlignVCenter
                                    elide: Text.ElideRight
                                    color: exprMouse.containsMouse ? ThemeBackend.blue : ThemeBackend.text
                                    font.family: ThemeBackend.fontFamily
                                    font.pixelSize: root.s(15)
                                }

                                MouseArea {
                                    id: exprMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    acceptedButtons: Qt.LeftButton | Qt.RightButton
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: mouse => {
                                        if (!historyRow.entry) return;
                                        if (mouse.button === Qt.RightButton) root.copyText(historyRow.entry.expr);
                                        else root.insertText(historyRow.entry.expr);
                                    }
                                }
                            }

                            Text {
                                anchors.centerIn: parent
                                text: "="
                                color: ThemeBackend.subtext0
                                font.family: ThemeBackend.fontFamily
                                font.pixelSize: root.s(14)
                            }

                            Item {
                                anchors.right: parent.right
                                anchors.rightMargin: root.s(14)
                                anchors.verticalCenter: parent.verticalCenter
                                width: parent.width * 0.4
                                height: parent.height

                                Text {
                                    anchors.fill: parent
                                    text: historyRow.entry ? historyRow.entry.result : ""
                                    horizontalAlignment: Text.AlignRight
                                    verticalAlignment: Text.AlignVCenter
                                    elide: Text.ElideLeft
                                    color: resultMouse.containsMouse ? ThemeBackend.blue : ThemeBackend.text
                                    font.family: ThemeBackend.fontFamily
                                    font.pixelSize: root.s(16)
                                    font.bold: true
                                }

                                MouseArea {
                                    id: resultMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    acceptedButtons: Qt.LeftButton | Qt.RightButton
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: mouse => {
                                        if (!historyRow.entry) return;
                                        if (mouse.button === Qt.RightButton) root.copyText(historyRow.entry.result);
                                        else root.insertText(historyRow.entry.result);
                                    }
                                }
                            }
                        }
                    }

                    }

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 1
                        color: Qt.alpha(ThemeBackend.surface2, 0.5)
                    }

                    Text {
                        Layout.fillWidth: true
                        Layout.fillHeight: false
                        Layout.preferredHeight: visible ? root.s(22) : 0
                        Layout.leftMargin: root.s(14)
                        Layout.rightMargin: root.s(14)
                        visible: text !== ""
                        text: root.subText
                        horizontalAlignment: Text.AlignRight
                        verticalAlignment: Text.AlignVCenter
                        elide: Text.ElideLeft
                        font.family: ThemeBackend.fontFamily
                        font.pixelSize: root.s(15)
                        color: root.errorCode !== "" ? ThemeBackend.red : ThemeBackend.subtext0
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        Layout.fillHeight: false
                        Layout.preferredHeight: root.s(54)
                        Layout.leftMargin: root.s(6)
                        Layout.rightMargin: root.s(14)
                        spacing: root.s(8)

                        Input {
                            id: field
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            baseColor: "transparent"
                            accentColor: ThemeBackend.blue
                            textColor: ThemeBackend.text
                            subTextColor: ThemeBackend.subtext0
                            cornerRadius: 0
                            horizontalPadding: root.s(8)
                            fontPixelSize: Math.round(root.s(26))
                            horizontalAlignment: TextInput.AlignRight
                            placeholderText: "0"
                            isWidgetVisible: root.visible
                            onTextEdited: newText => root.typed(newText)
                            onAccepted: root.handle("equals")
                        }

                    }
                }
            }

            Row {
                id: keypad
                Layout.fillWidth: true
                Layout.preferredHeight: Math.round(root.s(170))
                spacing: keypad.blockGap

                readonly property real blockGap: Math.round(root.s(14))
                readonly property real unitW: root.advanced ? (width - blockGap) / 8 : width / 4
                readonly property real unitH: height / 5

                Row {
                    id: sciBlock
                    visible: root.advanced
                    height: parent.height

                    Repeater {
                        model: root.sciGroups

                        delegate: ColumnLayout {
                            id: sciGroup
                            spacing: 0
                            property var groupKeys: modelData

                            Repeater {
                                model: sciGroup.groupKeys

                                delegate: CalculatorKey {
                                    cellWidth: keypad.unitW
                                    cellHeight: keypad.unitH
                                    keyMargin: Math.round(root.s(2))
                                    cornerRadius: Math.round(root.s(10))
                                    textFontSize: Math.round(root.s(13))
                                    buttonText: root.sciLabel(modelData)
                                    kind: modelData === "angle" ? "operator" : "normal"
                                    active: modelData === "inv" && root.inverse
                                    alt: root.inverse && root.shiftable.indexOf(modelData) !== -1
                                    onClicked: root.handle(modelData)
                                }
                            }
                        }
                    }
                }

                GridLayout {
                    id: mainGrid
                    width: keypad.unitW * 4
                    height: parent.height
                    columns: 4
                    rowSpacing: 0
                    columnSpacing: 0

                    Repeater {
                        model: root.mainKeys

                        delegate: CalculatorKey {
                            columnSpan: modelData.span !== undefined ? modelData.span : 1
                            cellWidth: keypad.unitW
                            cellHeight: keypad.unitH
                            keyMargin: Math.round(root.s(2))
                            cornerRadius: Math.round(root.s(10))
                            textFontSize: Math.round(root.s(17))
                            iconFontSize: Math.round(root.s(16))
                            buttonText: modelData.label !== undefined ? modelData.label : ""
                            buttonIcon: modelData.icon !== undefined ? modelData.icon : ""
                            kind: modelData.kind !== undefined ? modelData.kind : "normal"
                            onClicked: root.handle(modelData.id)
                        }
                    }
                }
            }
        }
    }
}
