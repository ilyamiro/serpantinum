import QtQuick
import "../../"
import "../"

Item {
    id: frame

    property real screenW: 1920
    property real screenH: 1080
    property real k: 0.5
    property bool current: false
    property string wallpaper: ""
    property string videoPath: ""
    default property alias content: contentItem.data
    signal activated()

    width: frame.screenW * frame.k
    height: frame.screenH * frame.k

    Rectangle {
        anchors.fill: parent
        color: ThemeBackend.crust
    }

    Item {
        anchors.fill: parent
        clip: true

        Image {
            anchors.fill: parent
            source: frame.wallpaper
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            sourceSize: Qt.size(frame.width, frame.height)
        }

        Loader {
            anchors.fill: parent
            active: frame.videoPath !== ""
            sourceComponent: VideoLock {
                wallpaperPath: frame.videoPath
            }
        }

        Rectangle {
            anchors.fill: parent
            color: Qt.rgba(ThemeBackend.crust.r, ThemeBackend.crust.g, ThemeBackend.crust.b, 0.35)
        }

        Item {
            id: contentItem
            width: frame.screenW
            height: frame.screenH
            scale: frame.k
            transformOrigin: Item.TopLeft
        }
    }

    Rectangle {
        anchors.fill: parent
        color: "transparent"
        z: 10
    }

    MouseArea {
        anchors.fill: parent
        z: 20
        visible: !frame.current
        cursorShape: Qt.PointingHandCursor
        onClicked: frame.activated()
    }
}
