import QtQuick
import "../"

SettingsRow {
    id: root

    property bool tempVisible: false
    property bool revealWhenClosed: false
    property bool pinToParent: true

    anchors.top: pinToParent ? parent.top : undefined
    anchors.left: pinToParent ? parent.left : undefined
    anchors.right: pinToParent ? parent.right : undefined

    function checkHighlight() {
        let r = effectiveRootObj;
        if (!r) return;
        if (r.highlightToken === handledHighlightToken) return;
        if (r.highlightedSettingId && (r.highlightedSettingId === effectiveSettingId || r.highlightedSettingId === settingId)) {
            handledHighlightToken = r.highlightToken;
            r.highlightedSettingId = "";
            if (revealWhenClosed) {
                tempVisible = true;
                collapseTimer.restart();
            }
            highlightDelayTimer.restart();
        }
    }

    Timer {
        id: collapseTimer
        interval: 2800
        repeat: false
        onTriggered: root.tempVisible = false
    }
}
