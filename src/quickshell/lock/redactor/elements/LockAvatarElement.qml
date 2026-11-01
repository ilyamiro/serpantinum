import QtQuick
import "../../../"
import "../../../reusables"

Item {
    id: el

    property string variant: "round"
    property var ctx: null

    readonly property real side: Math.min(width, height)
    readonly property string avatarSource: {
        if (el.ctx && el.ctx.faceIconPath !== undefined && el.ctx.faceIconPath !== "") return el.ctx.faceIconPath;
        if (SystemInfo.avatarPath === "") return "";
        return SystemInfo.avatarPath.startsWith("file://") ? SystemInfo.avatarPath : "file://" + SystemInfo.avatarPath;
    }

    ImageBox {
        anchors.centerIn: parent
        size: Math.round(el.side)
        cornerRadius: el.variant === "rounded" ? Math.round(ThemeBackend.borderRadius * 1.5) : Math.round(el.side / 2)
        imageRadius: cornerRadius
        source: el.avatarSource
        backgroundColor: el.avatarSource === "" ? ThemeBackend.surface1 : "transparent"

        Text {
            anchors.centerIn: parent
            visible: el.avatarSource === ""
            text: "󰀉"
            font.family: ThemeBackend.iconFont
            font.pixelSize: el.side / 2
            color: ThemeBackend.text
        }
    }
}
