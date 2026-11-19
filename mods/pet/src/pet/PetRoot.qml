import QtQuick
import Quickshell
import Quickshell.Io
import "../"
import "../bar"
import "PetVersion.js" as PetVersion

// Always loaded by Shell.qml. Owns the IPC target and the bar bed, and loads the actual pet
// (Pet.qml) only while it's switched on, so "off" really means off but can still be undone.
Scope {
    id: root

    Loader {
        id: petLoader
        active: PetState.enabled
        source: "Pet.qml"
    }

    readonly property var pet: petLoader.item

    function powerHint(on) {
        let key = "SUPER+SHIFT+" + PetVersion.KEY;
        let body = on ? ("Turn it off from its bed's right-click menu or " + key + ".")
                      : ("Click its bed in the bar or press " + key + " to bring it back.");
        Quickshell.execDetached(["notify-send", "-a", "Pet", on ? "Pet is on" : "Pet is off", body]);
    }

    function setPower(on, notify) {
        if (PetState.enabled === on) return;
        if (on) PetState.pendingSummon = true;
        PetState.setEnabled(on);
        if (notify && !on) powerHint(false);
    }

    IpcHandler {
        target: "pet"

        function on(): void { root.setPower(true, true); }
        function off(): void { root.setPower(false, true); }
        function power(): void { root.setPower(!PetState.enabled, true); }
        function toggle(): void {
            if (!PetState.enabled) root.setPower(true, false);
            else PetState.toggle();
        }
        function summon(): void {
            if (!PetState.enabled) root.setPower(true, false);
            else if (!PetState.out) PetState.summonRequested(null);
        }
        function dismiss(): void { if (PetState.enabled && PetState.out) PetState.dismissRequested(); }
        function chase(): void { if (PetState.enabled) PetState.chaseRequested(); }
        function react(kind: string): void { if (PetState.enabled) PetState.reactRequested(kind); }
        function treat(): void { if (PetState.enabled) PetState.requestTreatDrop(PetState.bedFor("")); }
        function give(count: int): void { PetState.addTreats(Math.max(1, count), "gift"); }
        function status(): string {
            let st = root.pet ? root.pet.status() : { present: false };
            st.enabled = PetState.enabled;
            return JSON.stringify(st);
        }
        function menu(): void {
            let b = PetState.bedFor("");
            if (b) b.toggleMenu();
        }
        function events(): string { return root.pet ? root.pet.eventsText() : ""; }
        function version(): string { return PetVersion.STAMP; }
    }

    Connections {
        target: PetState
        function onPowerRequested(on) { root.setPower(on, !on); }
    }

    Component.onCompleted: {
        BarModuleRegistry.registerModule("pet", {
            name: "Pet bed",
            icon: String.fromCodePoint(0xF011B),
            defaultVariant: "default",
            face: Qt.resolvedUrl("PetBedFace.qml").toString()
        });
    }

    Component.onDestruction: BarModuleRegistry.unregisterModule("pet")
}
