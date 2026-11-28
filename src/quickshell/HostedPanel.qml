import QtQuick

Item {
    id: hostedRoot
    visible: false
    focus: true

    property var exitCallback: null
    property bool handlesEscape: false
    property Item initialFocusItem: null
    property int focusDelay: 50

    signal dismissRequested()

    function s(val) {
        return Scaler.s(val);
    }

    function handleEscape() {
        return false;
    }

    function activate(arg) {
        if (arg !== undefined && arg !== null && String(arg) !== "" && typeof gotoTab === "function") {
            gotoTab(String(arg));
        }
    }

    function finishExit() {
        if (hostedRoot.exitCallback) {
            let cb = hostedRoot.exitCallback;
            hostedRoot.exitCallback = null;
            cb();
        } else {
            hostedRoot.dismissRequested();
        }
    }

    function startExit(onFinished) {
        hostedRoot.exitCallback = onFinished;
        hostedRoot.finishExit();
    }

    function scheduleFocus() {
        let target = hostedRoot.initialFocusItem || hostedRoot;
        if (typeof target.forceInputFocus === "function") {
            target.forceInputFocus();
        } else {
            target.forceActiveFocus();
        }
        focusTimer.restart();
    }

    function stopFocusTimer() {
        focusTimer.stop();
    }

    Timer {
        id: focusTimer
        interval: hostedRoot.focusDelay
        repeat: false
        onTriggered: {
            if (!hostedRoot.visible) return;
            let target = hostedRoot.initialFocusItem || hostedRoot;
            if (typeof target.forceInputFocus === "function") {
                target.forceInputFocus();
            } else {
                target.forceActiveFocus();
            }
        }
    }
}
