import QtQuick
import Quickshell

// The pet itself: loaded by PetRoot.qml only while the pet is switched on.
Scope {
    id: root

    function status() { return pet.status(); }
    function eventsText() { return pet.events.join("\n"); }

    PetWindow {
        id: pet
        settings: PetState.settings
    }

    PetTreats {}
}
