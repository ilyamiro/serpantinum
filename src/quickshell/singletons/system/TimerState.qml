pragma Singleton
import QtQuick

QtObject {
    id: root

    property var entries: []
    readonly property bool isActive: entries.length > 0
}
