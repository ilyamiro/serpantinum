import QtQuick
import QtQuick.Layouts

Item {
    id: root

    property string style: "default"
    property bool thumbnail: false
    readonly property string wallpaperSource: "file://" + Caching.getCacheDir("wallpaper") + "/current_wallpaper.png"
    readonly property bool mediaActive: typeof MprisController !== "undefined" && MprisController.activePlayer !== null
    readonly property string mediaTitle: mediaActive ? (MprisController.trackTitle || "Nothing playing") : "Nothing playing"
    readonly property string mediaArtist: mediaActive ? (MprisController.trackArtist || "") : ""
    readonly property color ink: "#f5f2ff"
    readonly property color muted: "#b9b4c8"
    readonly property color panel: "#171522"
    readonly property color panelRaised: "#211e2e"
    readonly property color accent: style === "focus" ? "#8ed8c0" : "#bda3ff"
    readonly property real unit: Math.min(width / 1600, height / 900)

    clip: true

    Image {
        anchors.fill: parent
        source: root.wallpaperSource
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        cache: true
        opacity: root.thumbnail ? 0.32 : 0.58
    }

    Rectangle { anchors.fill: parent; color: "#080710"; opacity: 0.52 }

    Item {
        anchors.fill: parent
        visible: root.style === "default"

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.top
            anchors.topMargin: root.height * 0.09
            text: Qt.formatDateTime(new Date(), "hh:mm")
            color: root.ink
            font.pixelSize: root.thumbnail ? root.height * 0.18 : root.height * 0.20
            font.weight: Font.Light
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.top
            anchors.topMargin: root.height * 0.30
            text: Qt.formatDateTime(new Date(), "dddd, d MMMM")
            color: root.muted
            font.pixelSize: root.thumbnail ? root.height * 0.035 : root.height * 0.045
        }

        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: root.height * 0.12
            spacing: root.thumbnail ? 5 : 12

            Rectangle {
                width: root.width * (root.thumbnail ? 0.20 : 0.22)
                height: root.height * (root.thumbnail ? 0.38 : 0.42)
                radius: root.thumbnail ? 7 : 16
                color: Qt.alpha(root.panelRaised, 0.94)
                border.color: Qt.alpha(root.accent, 0.3)
                border.width: 1
                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: root.thumbnail ? 6 : 14
                    spacing: root.thumbnail ? 2 : 6
                    Text { text: "Weather"; color: root.muted; font.pixelSize: root.thumbnail ? 6 : 10 }
                    Text { text: "☀  26°"; color: root.ink; font.pixelSize: root.thumbnail ? 10 : 18; font.weight: Font.DemiBold }
                    Text { text: "Clear skies"; color: root.muted; font.pixelSize: root.thumbnail ? 5 : 9 }
                }
            }

            Rectangle {
                width: root.width * (root.thumbnail ? 0.34 : 0.38)
                height: root.height * (root.thumbnail ? 0.48 : 0.54)
                radius: root.thumbnail ? 8 : 18
                color: Qt.alpha(root.panel, 0.96)
                border.color: Qt.alpha(root.accent, 0.4)
                border.width: 1
                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: root.thumbnail ? 7 : 18
                    spacing: root.thumbnail ? 3 : 9
                    Item { Layout.fillHeight: true }
                    Text { Layout.alignment: Qt.AlignHCenter; text: "Welcome back"; color: root.ink; font.pixelSize: root.thumbnail ? 7 : 15; font.weight: Font.DemiBold }
                    Text { Layout.alignment: Qt.AlignHCenter; text: "Sign in to continue"; color: root.muted; font.pixelSize: root.thumbnail ? 5 : 9 }
                    Rectangle { Layout.fillWidth: true; height: root.thumbnail ? 13 : 30; radius: height / 2; color: "#25222f"; border.color: "#3a3549"; Text { anchors.centerIn: parent; text: "Password   →"; color: root.muted; font.pixelSize: root.thumbnail ? 5 : 9 } }
                    Item { Layout.fillHeight: true }
                }
            }

            Rectangle {
                width: root.width * (root.thumbnail ? 0.20 : 0.22)
                height: root.height * (root.thumbnail ? 0.38 : 0.42)
                radius: root.thumbnail ? 7 : 16
                color: Qt.alpha(root.panelRaised, 0.94)
                border.color: Qt.alpha(root.accent, 0.3)
                border.width: 1
                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: root.thumbnail ? 6 : 14
                    spacing: root.thumbnail ? 2 : 6
                    Text { text: "System"; color: root.muted; font.pixelSize: root.thumbnail ? 6 : 10 }
                    Text { text: "▱ 100%"; color: root.ink; font.pixelSize: root.thumbnail ? 9 : 16; font.weight: Font.DemiBold }
                    Text { text: "Network ready"; color: root.muted; font.pixelSize: root.thumbnail ? 5 : 9 }
                }
            }
        }

        Rectangle {
            visible: !root.thumbnail
            anchors.left: parent.left
            anchors.leftMargin: parent.width * 0.055
            anchors.bottom: parent.bottom
            anchors.bottomMargin: parent.height * 0.09
            width: parent.width * 0.26
            height: parent.height * 0.13
            radius: 12
            color: Qt.alpha(root.panel, 0.82)
            border.color: Qt.alpha(root.accent, 0.24)
            border.width: 1
            Column {
                anchors.centerIn: parent
                spacing: 3
                Text { text: "Now playing"; color: root.accent; font.pixelSize: 9; font.letterSpacing: 1 }
                Text { text: root.mediaTitle; color: root.ink; font.pixelSize: 12; font.weight: Font.DemiBold; elide: Text.ElideRight; width: parent.parent.width * 0.82 }
                Text { text: root.mediaArtist; color: root.muted; font.pixelSize: 8; visible: text !== "" }
            }
        }
    }

    Item {
        anchors.fill: parent
        visible: root.style === "compact"
        Rectangle { x: parent.width * 0.11; y: parent.height * 0.18; width: parent.width * 0.22; height: parent.height * 0.64; radius: 16; color: Qt.alpha(root.accent, 0.18); border.color: root.accent; border.width: 1 }
        Text { x: parent.width * 0.15; y: parent.height * 0.36; text: Qt.formatDateTime(new Date(), "hh:mm"); color: root.ink; font.pixelSize: root.thumbnail ? 15 : 32; font.weight: Font.Bold }
        Rectangle { x: parent.width * 0.42; y: parent.height * 0.25; width: parent.width * 0.42; height: parent.height * 0.50; radius: 18; color: Qt.alpha(root.panel, 0.96); border.color: Qt.alpha(root.accent, 0.42); border.width: 1; Text { anchors.centerIn: parent; text: "Enter password"; color: root.muted; font.pixelSize: root.thumbnail ? 7 : 13 } }
    }

    Item {
        anchors.fill: parent
        visible: root.style === "focus"
        Rectangle { anchors.centerIn: parent; width: parent.height * (root.thumbnail ? 0.62 : 0.76); height: width; radius: root.thumbnail ? 16 : 28; color: Qt.alpha(root.panel, 0.96); border.color: root.accent; border.width: 2 }
        Column {
            anchors.centerIn: parent
            spacing: root.thumbnail ? 4 : 12
            Text { anchors.horizontalCenter: parent.horizontalCenter; text: "FOCUS"; color: root.accent; font.pixelSize: root.thumbnail ? 6 : 10; font.letterSpacing: 2 }
            Text { anchors.horizontalCenter: parent.horizontalCenter; text: Qt.formatDateTime(new Date(), "hh:mm"); color: root.ink; font.pixelSize: root.thumbnail ? 14 : 42; font.weight: Font.Light }
            Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter
                width: root.thumbnail ? 55 : 150
                height: root.thumbnail ? 13 : 32
                radius: height / 2
                color: "#262431"
                Text { anchors.centerIn: parent; text: "Unlock"; color: root.muted; font.pixelSize: root.thumbnail ? 6 : 10 }
            }
        }
    }

    Item {
        anchors.fill: parent
        visible: root.style === "tessera"
        Grid {
            anchors.centerIn: parent
            columns: 2
            spacing: root.thumbnail ? 4 : 10
            Repeater {
                model: ["Clock", "Weather", "Battery", "Unlock"]
                delegate: Rectangle {
                    width: root.width * (root.thumbnail ? 0.20 : 0.22)
                    height: root.height * (root.thumbnail ? 0.28 : 0.34)
                    radius: root.thumbnail ? 6 : 14
                    color: index === 0 ? Qt.alpha(root.accent, 0.55) : Qt.alpha(root.panel, 0.94)
                    border.color: Qt.alpha(root.accent, 0.35)
                    border.width: 1
                    Text { anchors.centerIn: parent; text: modelData; color: root.ink; font.pixelSize: root.thumbnail ? 6 : 11 }
                }
            }
        }
    }
}
