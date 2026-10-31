import QtQuick
import QtQuick.Window
import "../../src/quickshell" as Shell
import "../../src/quickshell/bar"
import "../../src/quickshell/bar/faces/media"
import "../../src/quickshell/widgets/faces/music"

Window {
    id: test
    width: 1200
    height: 500
    visible: true
    property bool failed: false
    property real fullWidth: 0
    property real fullHeight: 0
    property bool started: false
    function check(condition, message) {
        if (!condition) { failed = true; console.error("FAIL: " + message); }
    }
    function policy(hide) {
        Shell.Config.rawSettings = {media: {hideWhenIdle: hide, hideUnavailableLyrics: true}};
    }
    function startWhenReady() {
        if (started || !Shell.Config.dataReady) return;
        started = true;
        policy(false);
        sequence.start();
    }
    Connections {
        target: Shell.Config
        function onDataReadyChanged() { test.startWhenReady(); }
    }

    BarModule { id: horizontal; moduleId: "media" }
    BarModule { id: vertical; moduleId: "media"; orientation: "vertical"; x: 450 }
    BarModule { id: compact; moduleId: "media"; isGrouped: true; y: 100 }
    QtObject {
        id: previewTarget
        property bool isPreview: true
        property bool moduleActive: true
        property bool isCompact: false
        property var barWindow: null
        property string orientation: "horizontal"
    }
    MediaFace { id: preview; widget: previewTarget; y: 200 }
    MusicFaceLyricsSimple { id: simple; width: 300; height: 100 }

    Component.onCompleted: {
        for (let path of ["media/MusicPopup.qml", "guide/bar/modules/BarMediaCard.qml", "widgets/Widget.qml", "widgets/faces/music/MusicFaceLyrics.qml"]) {
            let component = Qt.createComponent("../../src/quickshell/" + path);
            if (component.errorString().includes("No PanelWindow backend loaded"))
                console.log("SKIP (offscreen has no layer-shell backend): " + path);
            else
                check(component.status === Component.Ready, path + ": " + component.errorString());
        }
        startWhenReady();
    }

    SequentialAnimation {
        id: sequence
        PauseAnimation { duration: 400 }
        ScriptAction { script: {
            test.fullWidth = horizontal.width;
            test.fullHeight = vertical.height;
            test.check(horizontal.visible && horizontal.width > 0 && compact.visible, "initial module visibility");
            test.check(vertical.visible && vertical.height > 0, "vertical module visibility");
            test.check(Shell.Lyrics.subscribers === 1, "simple lyric face subscribes");
            test.check(simple.visible && !simple.contentVisible,
                "content hidden without hiding subscription owner: visible=" + simple.visible
                + ", contentVisible=" + simple.contentVisible + ", subscribers=" + Shell.Lyrics.subscribers
                + ", dataReady=" + Shell.Config.dataReady + ", settings=" + JSON.stringify(Shell.Config.rawSettings));
            test.policy(true);
            test.check(!horizontal.enabled && !vertical.enabled, "input disabled immediately");
            test.check(horizontal.targetWidth === 0 && vertical.targetHeight === 0, "zero layout targets");
            test.check(preview.isFaceVisible && preview.targetLength > 0, "settings preview survives idle");
        } }
        PauseAnimation { duration: 100 }
        ScriptAction { script: {
            test.check(horizontal.visible && horizontal.opacity > 0 && horizontal.opacity < 1, "fade-out in progress");
            test.check(horizontal.width > 0 && horizontal.width < test.fullWidth, "width animates");
            test.check(vertical.height > 0 && vertical.height < test.fullHeight, "height animates");
            test.policy(false); // reverse a running collapse
        } }
        PauseAnimation { duration: 100 }
        ScriptAction { script: {
            test.check(horizontal.visible && horizontal.enabled && horizontal.width > 0, "reverse collapse");
            test.policy(true); // reverse a running expansion
        } }
        PauseAnimation { duration: 400 }
        ScriptAction { script: {
            test.check(!horizontal.visible && horizontal.width === 0 && !horizontal.enabled, "horizontal fully collapsed");
            test.check(!vertical.visible && vertical.height === 0 && !vertical.enabled, "vertical fully collapsed");
            test.check(!compact.visible && compact.width === 0, "compact fully collapsed");
            test.check(Shell.Lyrics.subscribers === 1, "hidden content retains subscriptions");
            test.policy(false);
        } }
        PauseAnimation { duration: 400 }
        ScriptAction { script: {
            test.check(horizontal.width === test.fullWidth && vertical.height === test.fullHeight, "recover full dimensions");
            test.check(horizontal.opacity === 1 && horizontal.visible, "recover opacity");
            if (!test.failed) console.log("PASS: Components (animation reversal, preview, subscriptions, imports)");
            Qt.quit();
        } }
    }
}
