import QtQuick
import QtQuick.Layouts

Item {
    id: root
    property string style: "default"
    property date now: new Date()

    Timer {
        interval: 1000
        running: true
        repeat: true
        onTriggered: root.now = new Date()
    }

    readonly property string clock: Qt.formatDateTime(now, "hh:mm")
    readonly property string date: Qt.formatDateTime(now, "dddd, d MMMM")
    readonly property color ink: "#f5f2ff"
    readonly property color muted: "#b5b0c8"
    readonly property color panel: "#171522"
    readonly property color accent: style === "focus" ? "#a8c7ff" : "#c8a1ff"

    Rectangle {
        anchors.fill: parent
        color: "#080713"
        clip: true

        Rectangle {
            anchors.fill: parent
            opacity: 0.7
            gradient: Gradient {
                GradientStop { position: 0.0; color: root.style === "tessera" ? "#14233d" : "#171145" }
                GradientStop { position: 0.55; color: "#120d2b" }
                GradientStop { position: 1.0; color: "#05050b" }
            }
        }

        Rectangle { x: parent.width * 0.05; y: parent.height * 0.18; width: parent.width * 0.32; height: parent.height * 0.72; radius: width / 2; color: "#263b75"; opacity: 0.12 }
        Rectangle { x: parent.width * 0.68; y: parent.height * 0.05; width: parent.width * 0.32; height: parent.height * 0.65; radius: width / 2; color: "#a44265"; opacity: 0.10 }

        Text {
            visible: root.style === "default"
            anchors.left: parent.left
            anchors.leftMargin: parent.width * 0.07
            anchors.bottom: parent.bottom
            anchors.bottomMargin: parent.height * 0.16
            text: root.clock
            color: root.ink
            font.family: ThemeBackend.fontFamily
            font.pixelSize: Math.max(24, parent.height * 0.23)
            font.weight: Font.Light
        }

        Text {
            visible: root.style === "default"
            anchors.left: parent.left
            anchors.leftMargin: parent.width * 0.075
            anchors.bottom: parent.bottom
            anchors.bottomMargin: parent.height * 0.10
            text: root.date
            color: root.muted
            font.family: ThemeBackend.fontFamily
            font.pixelSize: Math.max(8, parent.height * 0.035)
        }

        Rectangle {
            visible: root.style === "default"
            anchors.centerIn: parent
            width: parent.width * 0.42
            height: parent.height * 0.64
            radius: 18
            color: Qt.alpha(root.panel, 0.96)
            border.color: Qt.alpha(root.accent, 0.35)
            border.width: 1
            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 18
                spacing: 8
                Item { Layout.fillHeight: true }
                Rectangle { Layout.alignment: Qt.AlignHCenter; width: 48; height: 48; radius: 24; color: "#303043"; border.color: root.accent; border.width: 2 }
                Text { Layout.alignment: Qt.AlignHCenter; text: "Welcome back"; color: root.ink; font.pixelSize: 15; font.weight: Font.DemiBold }
                Rectangle { Layout.fillWidth: true; height: 30; radius: 15; color: "#24222e"; border.color: "#3b384a"; border.width: 1; Text { anchors.centerIn: parent; text: "Password                         →"; color: root.muted; font.pixelSize: 9 } }
                Item { Layout.fillHeight: true }
            }
        }

        Text {
            visible: root.style === "compact"
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.top
            anchors.topMargin: parent.height * 0.12
            text: root.clock
            color: root.ink
            font.family: ThemeBackend.fontFamily
            font.pixelSize: Math.max(34, parent.height * 0.28)
            font.weight: Font.Bold
        }

        Rectangle {
            visible: root.style === "compact"
            anchors.centerIn: parent
            width: parent.width * 0.30
            height: parent.height * 0.40
            radius: 18
            color: root.panel
            border.color: root.accent
            border.width: 1
            Column {
                anchors.centerIn: parent
                spacing: 10
                Text { anchors.horizontalCenter: parent.horizontalCenter; text: "Welcome back"; color: root.ink; font.pixelSize: 13 }
                Rectangle { width: 120; height: 28; radius: 14; color: "#272433"; Text { anchors.centerIn: parent; text: "unlock"; color: root.muted; font.pixelSize: 9 } }
            }
        }

        Rectangle {
            visible: root.style === "focus"
            anchors.centerIn: parent
            width: parent.height * 0.72
            height: parent.height * 0.72
            radius: width / 2
            color: "transparent"
            border.color: Qt.alpha(root.accent, 0.28)
            border.width: 2
            Rectangle { anchors.fill: parent; anchors.margins: 12; radius: width / 2; color: Qt.alpha(root.panel, 0.96); border.color: root.accent; border.width: 1 }
            Column {
                anchors.centerIn: parent
                spacing: 8
                Text { anchors.horizontalCenter: parent.horizontalCenter; text: root.clock; color: root.ink; font.pixelSize: 34; font.weight: Font.Bold }
                Text { anchors.horizontalCenter: parent.horizontalCenter; text: root.date; color: root.muted; font.pixelSize: 9 }
                Rectangle { anchors.horizontalCenter: parent.horizontalCenter; width: 120; height: 28; radius: 14; color: "#282638"; Text { anchors.centerIn: parent; text: "Password  →"; color: root.muted; font.pixelSize: 9 } }
            }
        }

        Row {
            visible: root.style === "tessera"
            anchors.centerIn: parent
            spacing: 8
            Repeater {
                model: [root.clock, "Weather 25°", "Battery 100%"]
                delegate: Rectangle {
                    width: parent.parent.width * 0.22
                    height: parent.parent.height * 0.42
                    radius: 14
                    color: index === 0 ? Qt.alpha(root.accent, 0.72) : root.panel
                    border.color: Qt.alpha(root.accent, 0.35)
                    Text { anchors.centerIn: parent; text: modelData; color: root.ink; font.pixelSize: 10; horizontalAlignment: Text.AlignHCenter }
                }
            }
        }

        Row {
            anchors.right: parent.right
            anchors.rightMargin: parent.width * 0.06
            anchors.bottom: parent.bottom
            anchors.bottomMargin: parent.height * 0.08
            spacing: 8
            Text { text: "◌  25°"; color: root.muted; font.pixelSize: 10 }
            Text { text: "▱  100%"; color: root.muted; font.pixelSize: 10 }
        }
    }
}
