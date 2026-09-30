import QtQuick

Item {
    id: root

    property string style: "default"
    property bool thumbnail: false
    readonly property string wallpaperSource: "file://" + Caching.getCacheDir("wallpaper") + "/current_wallpaper.png"
    readonly property color ink: "#f4f1ff"
    readonly property color muted: "#b9b3c9"
    readonly property color panel: "#171522"
    readonly property color accent: style === "focus" ? "#8ed8c0" : "#c2a4ff"

    clip: true

    Image {
        anchors.fill: parent
        source: root.wallpaperSource
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        cache: true
        opacity: root.thumbnail ? 0.32 : 0.52
    }

    Rectangle {
        anchors.fill: parent
        color: "#0a0911"
        opacity: 0.64
    }

    // Each style has its own information hierarchy and composition.
    Item {
        anchors.fill: parent
        visible: root.style === "default"

        Text {
            x: parent.width * 0.07
            y: parent.height * 0.18
            text: "SERPANTINUM"
            color: root.accent
            font.pixelSize: Math.max(8, parent.height * (root.thumbnail ? 0.035 : 0.045))
            font.letterSpacing: 2
        }
        Text {
            x: parent.width * 0.065
            y: parent.height * 0.30
            text: Qt.formatDateTime(new Date(), "hh:mm")
            color: root.ink
            font.pixelSize: Math.max(20, parent.height * (root.thumbnail ? 0.22 : 0.28))
            font.weight: Font.Light
        }
        Text {
            x: parent.width * 0.07
            y: parent.height * 0.68
            text: Qt.formatDateTime(new Date(), "dddd, d MMMM")
            color: root.muted
            font.pixelSize: Math.max(8, parent.height * 0.035)
        }

        Rectangle {
            x: parent.width * 0.43
            y: parent.height * 0.18
            width: parent.width * 0.30
            height: parent.height * 0.64
            radius: root.thumbnail ? 10 : 22
            color: Qt.alpha(root.panel, 0.94)
            border.color: Qt.alpha(root.accent, 0.35)
            border.width: 1
            Column {
                anchors.centerIn: parent
                width: parent.width * 0.78
                spacing: root.thumbnail ? 5 : 14
                Text { text: "Welcome back"; color: root.ink; font.pixelSize: root.thumbnail ? 8 : 18; font.weight: Font.DemiBold }
                Text { text: "Sign in to continue"; color: root.muted; font.pixelSize: root.thumbnail ? 6 : 11 }
                Rectangle { width: parent.width; height: root.thumbnail ? 14 : 36; radius: height / 2; color: "#262431"; border.color: "#3a3548"; Text { anchors.centerIn: parent; text: "Password                 →"; color: root.muted; font.pixelSize: root.thumbnail ? 6 : 10 } }
            }
        }

        Column {
            x: parent.width * 0.80
            y: parent.height * 0.30
            spacing: root.thumbnail ? 4 : 10
            Text { text: "WEATHER"; color: root.muted; font.pixelSize: root.thumbnail ? 6 : 9; font.letterSpacing: 1 }
            Text { text: "☀  26°"; color: root.ink; font.pixelSize: root.thumbnail ? 9 : 18; font.weight: Font.DemiBold }
            Text { text: "Battery 100%"; color: root.muted; font.pixelSize: root.thumbnail ? 6 : 10 }
            Text { text: "Network ready"; color: root.muted; font.pixelSize: root.thumbnail ? 6 : 10 }
        }
    }

    Item {
        anchors.fill: parent
        visible: root.style === "compact"
        Rectangle { x: parent.width * 0.12; y: parent.height * 0.18; width: parent.width * 0.20; height: parent.height * 0.64; radius: 18; color: Qt.alpha(root.accent, 0.22); border.color: root.accent; border.width: 1 }
        Text { x: parent.width * 0.16; y: parent.height * 0.36; text: Qt.formatDateTime(new Date(), "hh:mm"); color: root.ink; font.pixelSize: root.thumbnail ? 15 : 34; font.weight: Font.Bold }
        Rectangle { x: parent.width * 0.40; y: parent.height * 0.26; width: parent.width * 0.42; height: parent.height * 0.48; radius: 20; color: Qt.alpha(root.panel, 0.96); border.color: Qt.alpha(root.accent, 0.4); border.width: 1; Text { anchors.centerIn: parent; text: "Enter password"; color: root.muted; font.pixelSize: root.thumbnail ? 7 : 13 } }
    }

    Item {
        anchors.fill: parent
        visible: root.style === "focus"
        Rectangle { anchors.centerIn: parent; width: parent.height * (root.thumbnail ? 0.62 : 0.76); height: width; radius: root.thumbnail ? 16 : 28; color: Qt.alpha(root.panel, 0.95); border.color: root.accent; border.width: 2 }
        Column {
            anchors.centerIn: parent
            spacing: root.thumbnail ? 4 : 12
            Text { anchors.horizontalCenter: parent.horizontalCenter; text: "FOCUS MODE"; color: root.accent; font.pixelSize: root.thumbnail ? 6 : 10; font.letterSpacing: 2 }
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
