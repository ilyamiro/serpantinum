pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Bluetooth
import Quickshell.Networking

Item {
    id: root

    readonly property bool wifiEnabled: Networking.wifiEnabled
    property bool _bluetoothEnabled: Boolean(Bluetooth.defaultAdapter && Bluetooth.defaultAdapter.enabled)
    readonly property bool bluetoothEnabled: _bluetoothEnabled
    readonly property bool airplaneMode: !wifiEnabled && !bluetoothEnabled

    property bool wifiBeforeAirplane: true
    property bool btBeforeAirplane: true

    function _syncBluetooth() {
        root._bluetoothEnabled = Boolean(Bluetooth.defaultAdapter && Bluetooth.defaultAdapter.enabled);
    }

    function setWifiEnabled(enabled) {
        Networking.wifiEnabled = Boolean(enabled);
    }

    function setBluetoothEnabled(enabled) {
        if (Bluetooth.defaultAdapter) {
            Bluetooth.defaultAdapter.enabled = Boolean(enabled);
        }
    }

    function setAirplaneMode(enabled) {
        let target = Boolean(enabled);
        if (target) {
            if (root.wifiEnabled || root.bluetoothEnabled) {
                root.wifiBeforeAirplane = root.wifiEnabled;
                root.btBeforeAirplane = root.bluetoothEnabled;
            } else {
                root.wifiBeforeAirplane = true;
                root.btBeforeAirplane = true;
            }
            root.setWifiEnabled(false);
            root.setBluetoothEnabled(false);
        } else {
            let restoreWifi = root.wifiBeforeAirplane;
            let restoreBt = root.btBeforeAirplane;
            if (!restoreWifi && !restoreBt) {
                restoreWifi = true;
                restoreBt = true;
            }
            root.setWifiEnabled(restoreWifi);
            root.setBluetoothEnabled(restoreBt);
        }
    }

    function toggleAirplaneMode() {
        root.setAirplaneMode(!root.airplaneMode);
    }

    Connections {
        target: Bluetooth
        ignoreUnknownSignals: true
        function onDefaultAdapterChanged() {
            root._syncBluetooth();
        }
    }

    Connections {
        target: Bluetooth.defaultAdapter || null
        ignoreUnknownSignals: true
        function onEnabledChanged() {
            root._syncBluetooth();
        }
    }
}
