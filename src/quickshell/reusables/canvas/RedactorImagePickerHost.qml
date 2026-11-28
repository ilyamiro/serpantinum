import QtQuick
import "../"

Loader {
    id: host

    required property var rootObj

    property string targetType: ""
    property string targetId: ""
    property string currentPath: ""
    property bool circleMask: false
    readonly property bool isOpen: host.active && host.item !== null && host.item.visible

    signal imagePicked(string targetType, string targetId, string filePath, string fileName)

    anchors.fill: parent
    z: 300000
    active: false

    function open(typeKey, itemId, curPath, useCircleMask) {
        host.targetType = typeKey || "";
        host.targetId = itemId ? String(itemId) : "";
        host.currentPath = curPath || "";
        host.circleMask = !!useCircleMask;
        host.active = true;
        if (host.status === Loader.Ready && host.item) {
            host.item.openPicker(host.currentPath, host.circleMask);
        }
    }

    onLoaded: {
        if (host.item) {
            host.item.openPicker(host.currentPath, host.circleMask);
        }
    }

    sourceComponent: ImagePicker {
        rootObj: host.rootObj

        onImageSelected: (filePath, fileName) => {
            let tType = host.targetType;
            let tId = host.targetId;
            host.targetType = "";
            host.targetId = "";
            host.imagePicked(tType, tId, filePath, fileName);
        }
    }
}
