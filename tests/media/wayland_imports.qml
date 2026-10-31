import QtQuick
import Quickshell

// Compile the actual components with a layer-shell backend, but do not create
// their objects/windows or activate popup audio integrations.
ShellRoot {
    Component.onCompleted: Qt.callLater(function() {
        let paths = ["media/MusicPopup.qml", "widgets/Widget.qml",
            "widgets/faces/music/MusicFaceLyrics.qml", "guide/bar/modules/BarMediaCard.qml"];
        let failed = false;
        for (let path of paths) {
            let component = Qt.createComponent("../../src/quickshell/" + path);
            if (component.status !== Component.Ready) {
                failed = true;
                console.error("FAIL: Wayland import " + path + ": " + component.errorString());
            }
        }
        if (!failed) console.log("PASS: Wayland component imports (no objects/windows instantiated)");
        Qt.quit();
    })
}
