import QtQuick
import Quickshell
import Quickshell.Io
import "../"

// Earns treats: one per `treatMinutes` of focused coding today (from the wellbeing database)
// and one per finished pomodoro focus session (from the Timer's saved state).
Item {
    id: root
    visible: false

    readonly property string script: Qt.resolvedUrl("pet_stats.py").toString().replace("file://", "")
    readonly property string dbPath: Caching.getStateDir("focustime") + "/focustime.db"
    property int lastPomoState: -1

    function today() {
        let d = new Date();
        let pad = n => (n < 10 ? "0" : "") + n;
        return d.getFullYear() + "-" + pad(d.getMonth() + 1) + "-" + pad(d.getDate());
    }

    function rollDay(date) {
        if (PetState.creditDate === date) return;
        if (PetState.creditDate === "" && PetState.fedTotal === 0 && PetState.treats === 0) {
            PetState.addTreats(3, "welcome");
        }
        PetState.creditDate = date;
        PetState.creditedCoding = 0;
        PetState.creditedPomos = 0;
    }

    Process {
        id: stats
        command: ["python3", "-I", root.script, root.dbPath, JSON.stringify(PetState.codingApps)]
        stdout: StdioCollector {
            id: statsOut
            onStreamFinished: root.onStats(statsOut.text)
        }
    }

    Timer {
        interval: 300000
        repeat: true
        triggeredOnStart: true
        running: PetState.loaded
        onTriggered: {
            stats.running = false;
            stats.running = true;
        }
    }

    function onStats(txt) {
        let d = null;
        try {
            d = JSON.parse(String(txt).trim());
        } catch (e) {
            return;
        }
        if (!d || !d.date) return;
        rollDay(d.date);
        let earned = Math.floor((Number(d.coding_seconds) || 0) / (PetState.minutesPerTreat * 60));
        if (earned > PetState.creditedCoding) {
            let n = earned - PetState.creditedCoding;
            PetState.creditedCoding = earned;
            PetState.addTreats(n, "coding");
        }
    }

    FileView {
        id: pomo
        path: Caching.getRunDir("focustime") + "/saved_state.json"
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: root.onPomo(pomo.text())
    }

    function onPomo(txt) {
        let d = null;
        try {
            d = JSON.parse(String(txt).trim());
        } catch (e) {
            return;
        }
        if (!d || d.pomoState === undefined) return;
        let st = Number(d.pomoState);
        let prev = root.lastPomoState;
        root.lastPomoState = st;
        if (prev === 0 && (st === 1 || st === 2) && PetState.loaded) {
            rollDay(today());
            PetState.creditedPomos++;
            PetState.addTreats(1, "pomodoro");
        }
    }
}
