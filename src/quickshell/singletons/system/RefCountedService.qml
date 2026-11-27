import QtQuick

Item {
    id: root

    property int subscribers: 0
    readonly property bool active: subscribers > 0

    signal activated()
    signal deactivated()

    function subscribe() {
        let wasActive = subscribers > 0;
        subscribers++;
        if (!wasActive && subscribers > 0) activated();
    }

    function unsubscribe() {
        if (subscribers <= 0) {
            subscribers = 0;
            return;
        }
        subscribers--;
        if (subscribers === 0) deactivated();
    }
}
