import QtQuick
import "../../"

RefCountedService {
    id: base

    property int activeIndex: 0
    property var activeIndicesByOutput: ({})
    property var occupiedMap: ({})

    property bool watching: false
    signal coreState(var state)

    function subscribeWindows() {
        subscribe();
    }

    function unsubscribeWindows() {
        unsubscribe();
    }

    function subscribeClients() {
        subscribe();
    }

    function unsubscribeClients() {
        unsubscribe();
    }

    function subscribeKeyboard() {
        subscribe();
    }

    function unsubscribeKeyboard() {
        unsubscribe();
    }

    function activeIndexFor(outputName) {
        if (outputName && activeIndicesByOutput && activeIndicesByOutput[outputName] !== undefined) {
            return activeIndicesByOutput[outputName];
        }
        return activeIndex;
    }

    function assign(name, value) {
        if (JSON.stringify(base[name]) === JSON.stringify(value)) return false;
        base[name] = value;
        return true;
    }

    function applyWorkspaces(ws) {
        if (!ws) return;
        if (ws.activeIndex !== undefined && base.activeIndex !== ws.activeIndex) base.activeIndex = ws.activeIndex;
        assign("activeIndicesByOutput", ws.activeIndicesByOutput || {});
        assign("occupiedMap", ws.occupiedMap || {});
    }

    JsonStreamProcess {
        id: coreWatch
        active: base.watching
        command: ["serpantinum-core", "watch", "compositor"]
        restartInterval: 1000
        onMessage: data => base.coreState(data)
    }
}
