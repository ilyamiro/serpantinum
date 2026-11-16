import QtQuick

WxHero {
    id: flake

    Item {
        anchors.fill: parent
        rotation: flake.phase * 60

        Repeater {
            model: flake.on ? 6 : 0
            delegate: Item {
                required property int index
                anchors.fill: parent
                rotation: index * 60

                Rectangle {
                    x: (parent.width - width) / 2
                    y: parent.height * 0.04
                    width: Math.max(1.5, parent.width * 0.06)
                    height: parent.height * 0.46
                    radius: width / 2
                    color: "#ffffff"
                }
                Rectangle {
                    x: parent.width / 2 - width * 0.9
                    y: parent.height * 0.13
                    width: Math.max(1.2, parent.width * 0.05)
                    height: parent.height * 0.17
                    radius: width / 2
                    color: "#ffffff"
                    rotation: 45
                    transformOrigin: Item.Bottom
                }
                Rectangle {
                    x: parent.width / 2 - width * 0.1
                    y: parent.height * 0.13
                    width: Math.max(1.2, parent.width * 0.05)
                    height: parent.height * 0.17
                    radius: width / 2
                    color: "#ffffff"
                    rotation: -45
                    transformOrigin: Item.Bottom
                }
            }
        }
    }

    Rectangle {
        anchors.centerIn: parent
        width: parent.width * 0.16
        height: width
        radius: width / 2
        color: "#d4efff"
        border.color: "#ffffff"
        border.width: Math.max(1, width * 0.18)
    }
}
