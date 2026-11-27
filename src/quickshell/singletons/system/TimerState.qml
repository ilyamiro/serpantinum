pragma Singleton
import QtQuick
import "../../"

QtObject {
    id: root
    readonly property var entries: FocusTimer.entries
    readonly property bool isActive: FocusTimer.isActive
}
