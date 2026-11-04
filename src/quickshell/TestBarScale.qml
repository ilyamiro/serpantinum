import QtQuick
import Quickshell

// Run with QS_SETTINGS pointing to a temporary JSON file, never your real settings.
ShellRoot {
    Timer {
        interval: 0
        running: true
        onTriggered: {
            if (!Quickshell.env("QS_SETTINGS")) {
                console.error("Set QS_SETTINGS to a temporary JSON file.");
                Qt.exit(1);
                return;
            }

            const cases = [
                { bar: {}, scale: 1, margin: 4, thickness: 40 },
                { bar: { scale: 0.75, margin: 0, height: 28 }, scale: 0.75, margin: 0, thickness: 28 },
                { bar: { scale: 1.5, margin: 24, height: 48 }, scale: 1.5, margin: 24, thickness: 48 },
                { bar: { scale: 0.1, margin: -1, height: 1 }, scale: 0.75, margin: 4, thickness: 28 },
                { bar: { scale: 2, height: 100 }, scale: 1.5, margin: 4, thickness: 48 },
                { bar: { scale: "bad", margin: "bad", height: "bad" }, scale: 1, margin: 4, thickness: 40 }
            ];

            for (const data of cases) {
                Config.rawSettings = { bar: data.bar };
                if (Config.barScale !== data.scale || Config.barMargin !== data.margin || Config.barThickness !== data.thickness) {
                    console.error("Bar settings check failed:", JSON.stringify(data), Config.barScale, Config.barMargin, Config.barThickness);
                    Qt.exit(1);
                    return;
                }
            }

            console.log("Bar settings: all " + cases.length + " cases passed.");
            Qt.quit();
        }
    }
}
