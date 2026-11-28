import QtQuick

QtObject {
    id: gate

    property var target: null
    property string acquire: "subscribe"
    property string release: "unsubscribe"
    property var acquireArg: undefined
    property bool wanted: false
    property bool active: false
    property bool ready: false

    property var _acquiredTarget: null
    property string _acquiredRelease: ""
    property var _acquiredArg: undefined

    function _callAcquire(t, fn, arg) {
        if (!t || typeof t[fn] !== "function") return false;
        if (arg !== undefined) t[fn](arg);
        else t[fn]();
        return true;
    }

    function _callRelease(t, fn, arg) {
        if (!t || typeof t[fn] !== "function") return;
        if (arg !== undefined) t[fn](arg);
        else t[fn]();
    }

    function _releaseCurrent() {
        if (!active || !_acquiredTarget) return;
        let oldTarget = _acquiredTarget;
        let oldRelease = _acquiredRelease || release;
        let oldArg = _acquiredArg;
        active = false;
        _acquiredTarget = null;
        _acquiredRelease = "";
        _acquiredArg = undefined;
        _callRelease(oldTarget, oldRelease, oldArg);
    }

    function sync() {
        if (!ready) return;
        if (active && (_acquiredTarget !== target || _acquiredArg !== acquireArg)) {
            _releaseCurrent();
        }
        if (!target) return;
        if (wanted && !active) {
            if (_callAcquire(target, acquire, acquireArg)) {
                _acquiredTarget = target;
                _acquiredRelease = release;
                _acquiredArg = acquireArg;
                active = true;
            }
        } else if (!wanted && active) {
            _releaseCurrent();
        }
    }

    onWantedChanged: sync()
    onTargetChanged: sync()
    onAcquireArgChanged: sync()

    Component.onCompleted: {
        ready = true;
        sync();
    }

    Component.onDestruction: _releaseCurrent()
}
