import QtQuick
import Quickshell
import "."

// Minecraft-style lock screen drawn over Serpantinum's own lock UI.
// It only shows state: the real password field, PAM and focus stay in Lock.qml, so keys
// keep going there. Clicks on the scenery ask Lock.qml to open the password panel.
Item {
    id: root

    // ---- state from Lock.qml
    property int pwLength: 0
    property bool failed: false
    property bool authenticating: false
    property bool inputActive: false
    property bool unlocking: false
    property string kbLayout: ""
    property int batCap: 0
    property bool charging: false
    property bool hasBattery: true
    property string mediaTitle: ""
    property string mediaArtist: ""
    property bool fingerprint: false
    property string fingerprintText: ""
    property bool locked: false

    signal activate()
    signal suspendRequested()
    signal rebootRequested()
    signal poweroffRequested()

    readonly property int px: Math.max(3, Math.round(height / 270))
    readonly property string userName: {
        let u = Quickshell.env("USER") || "гравець";
        return u.charAt(0).toUpperCase() + u.slice(1);
    }

    // ---- time of day
    property date now: new Date()
    Timer { interval: 1000; running: root.visible; repeat: true; onTriggered: root.now = new Date() }
    readonly property real hour: now.getHours() + now.getMinutes() / 60

    // ---- hearts: every failed attempt costs one heart
    property int hearts: 10
    onFailedChanged: {
        if (!failed) return;
        hearts = Math.max(0, hearts - 2);
        shake.restart();
        steve.hurt(["Ой!", "Ай! Не той пароль", "Боляче!", "Спробуй ще"][Math.floor(Math.random() * 4)]);
    }
    onUnlockingChanged: if (unlocking) steve.celebrate("З поверненням!")
    onLockedChanged: {
        if (!locked) return;
        hearts = 10;
        splash.pick();
        steve.active = false;
        steve.active = true;
    }

    // Scenery takes clicks so the old UI below never gets them.
    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.AllButtons
        onPressed: root.activate()
    }

    McSky {
        id: sky
        anchors.fill: parent
        px: root.px
        hour: root.hour
        active: root.visible
    }

    Terrain {
        id: terrain
        anchors.fill: parent
        px: root.px
        night: sky.night
    }

    // ---- clock styled like the game logo
    Item {
        id: logo
        anchors.horizontalCenter: parent.horizontalCenter
        y: root.height * 0.07
        width: logoText.implicitWidth
        height: logoText.implicitHeight
        readonly property string title: Qt.formatTime(root.now, "HH:mm")
        readonly property int size: root.px * 30

        Repeater {
            model: 6
            Text {
                x: (6 - index) * root.px * 0.7
                y: (6 - index) * root.px * 0.7
                text: logo.title
                font.family: "Monocraft"
                font.bold: true
                font.pixelSize: logo.size
                color: index === 0 ? "#141414" : "#3a3a3a"
            }
        }
        Text {
            id: logoText
            text: logo.title
            font.family: "Monocraft"
            font.bold: true
            font.pixelSize: logo.size
            color: "#c6c6c6"
            style: Text.Outline
            styleColor: "#1a1a1a"
        }
        Item {
            width: logoText.width
            height: logoText.height * 0.48
            clip: true
            Text {
                text: logo.title
                font.family: "Monocraft"
                font.bold: true
                font.pixelSize: logo.size
                color: "#e8e8e8"
            }
        }

        McText {
            id: splash
            x: logo.width - width * 0.5
            y: logo.height * 0.75
            rotation: -18
            color: "#ffff55"
            font.pixelSize: root.px * 6
            readonly property var lines: [
                "Привіт, " + root.userName + "!", "Гру призупинено!", "Кріпери не пройдуть!", "Стів охороняє!",
                "Не забудь пароль!", "100% Arch!", "Тепер з Hyprland!", "Збудовано з блоків!", "AFK!",
                "Відійшов по алмази!", "Ctrl+Alt+Del не допоможе!", "Також спробуйте Serpantinum!"
            ]
            function pick() { text = lines[Math.floor(Math.random() * lines.length)]; }
            Component.onCompleted: pick()
            SequentialAnimation on scale {
                loops: Animation.Infinite
                running: root.visible
                NumberAnimation { from: 1.0; to: 1.08; duration: 260; easing.type: Easing.InOutSine }
                NumberAnimation { from: 1.08; to: 1.0; duration: 260; easing.type: Easing.InOutSine }
            }
        }
    }

    McText {
        id: dateLine
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: logo.bottom
        anchors.topMargin: root.px * 6
        text: {
            let s = root.now.toLocaleDateString(Qt.locale("uk_UA"), "dddd, d MMMM");
            return s.charAt(0).toUpperCase() + s.slice(1);
        }
        font.pixelSize: root.px * 6
        color: "#e0e0e0"
    }

    // ---- pause panel
    Item {
        id: panel
        width: root.px * 110
        height: form.implicitHeight + root.px * 12
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: dateLine.bottom
        anchors.topMargin: root.px * 14
        transform: Translate { id: shakeT; x: 0 }

        SequentialAnimation {
            id: shake
            loops: 3
            NumberAnimation { target: shakeT; property: "x"; to: root.px * 3; duration: 40 }
            NumberAnimation { target: shakeT; property: "x"; to: -root.px * 3; duration: 80 }
            NumberAnimation { target: shakeT; property: "x"; to: 0; duration: 40 }
        }

        Rectangle {
            anchors.fill: parent
            color: Qt.rgba(0, 0, 0, 0.55)
            border.width: 2
            border.color: "#000000"
        }

        Column {
            id: form
            anchors.top: parent.top
            anchors.topMargin: root.px * 6
            anchors.horizontalCenter: parent.horizontalCenter
            width: parent.width - root.px * 12
            spacing: root.px * 3

            McText {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "Гру призупинено"
                font.pixelSize: root.px * 7
            }

            McText {
                text: "Пароль гравця " + root.userName
                color: "#a0a0a0"
                font.pixelSize: root.px * 4
            }

            // Mirror of the real (hidden) password field.
            Item {
                width: parent.width
                height: root.px * 11
                Rectangle {
                    anchors.fill: parent
                    color: "#000000"
                    border.width: 2
                    border.color: root.inputActive ? "#ffffff" : "#a0a0a0"
                }
                Row {
                    anchors.left: parent.left
                    anchors.leftMargin: root.px * 3
                    anchors.verticalCenter: parent.verticalCenter
                    McText {
                        visible: root.pwLength > 0
                        text: "*".repeat(Math.min(root.pwLength, 28))
                        font.pixelSize: root.px * 5
                        color: "#e0e0e0"
                    }
                    McText {
                        visible: root.inputActive && caret.on
                        text: "_"
                        font.pixelSize: root.px * 5
                        color: "#e0e0e0"
                    }
                }
                McText {
                    visible: root.pwLength === 0 && !root.inputActive
                    anchors.left: parent.left
                    anchors.leftMargin: root.px * 3
                    anchors.verticalCenter: parent.verticalCenter
                    text: "почни друкувати..."
                    font.pixelSize: root.px * 5
                    color: "#707070"
                }
                McText {
                    visible: root.kbLayout !== ""
                    anchors.right: parent.right
                    anchors.rightMargin: root.px * 3
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.kbLayout
                    font.pixelSize: root.px * 4
                    color: "#a0a0a0"
                }
                Timer {
                    id: caret
                    property bool on: true
                    interval: 500
                    repeat: true
                    running: root.inputActive && root.visible
                    onTriggered: on = !on
                }
            }

            // Health bar
            Row {
                spacing: root.px
                Repeater {
                    model: 5
                    Canvas {
                        width: root.px * 9
                        height: root.px * 8
                        antialiasing: false
                        property int fill: Math.max(0, Math.min(2, root.hearts - index * 2))
                        onFillChanged: requestPaint()
                        Component.onCompleted: requestPaint()
                        onPaint: {
                            let ctx = getContext("2d");
                            ctx.reset();
                            let p = root.px;
                            let rows = [".XX.XX..", "XRRXRRX.", "XRRRRRX.", "XRRRRRX.", ".XRRRX..", "..XRX...", "...X...."];
                            for (let y = 0; y < rows.length; y++)
                                for (let x = 0; x < 8; x++) {
                                    let ch = rows[y][x];
                                    if (ch === ".") continue;
                                    let full = fill === 2 || (fill === 1 && x < 4);
                                    ctx.fillStyle = ch === "X" ? "#1a0000" : (full ? (y === 1 && x === 1 ? "#ffb0b0" : "#e01818") : "#3a1a1a");
                                    ctx.fillRect(x * p, y * p, p, p);
                                }
                        }
                    }
                }
            }

            McText {
                id: statusLine
                width: parent.width
                wrapMode: Text.WordWrap
                font.pixelSize: root.px * 4
                text: root.unlocking ? "Завантаження світу..."
                    : root.authenticating ? "Перевіряю пароль..."
                    : root.failed ? "Неправильний пароль!"
                    : root.fingerprint && root.fingerprintText !== "" ? root.fingerprintText
                    : root.inputActive ? "Enter — продовжити, Esc — сховати"
                    : "Натисни будь-яку клавішу"
                color: root.failed ? "#ff5555" : (root.unlocking ? "#55ff55" : "#d0d0d0")
                property bool pulsing: !root.inputActive && root.visible
                onPulsingChanged: if (!pulsing) opacity = 1
                SequentialAnimation on opacity {
                    running: statusLine.pulsing
                    loops: Animation.Infinite
                    NumberAnimation { to: 0.4; duration: 700 }
                    NumberAnimation { to: 1.0; duration: 700 }
                }
            }
        }
    }

    // ---- bottom left: battery as a durability bar, and what's playing
    Column {
        anchors.left: parent.left
        anchors.bottom: parent.bottom
        anchors.margins: root.px * 5
        spacing: root.px * 2
        z: 5

        Row {
            visible: root.hasBattery
            spacing: root.px * 2
            McText {
                anchors.verticalCenter: parent.verticalCenter
                text: root.charging ? "Заряджається" : "Батарея"
                font.pixelSize: root.px * 4
            }
            Item {
                anchors.verticalCenter: parent.verticalCenter
                width: root.px * 40
                height: root.px * 3
                Rectangle { anchors.fill: parent; color: "#000000" }
                Rectangle {
                    height: parent.height - root.px
                    width: parent.width * Math.max(0, Math.min(100, root.batCap)) / 100
                    // durability colors: green -> yellow -> red
                    color: Qt.hsva(Math.max(0, Math.min(1, root.batCap / 100)) * 0.33, 1, 1, 1)
                }
            }
            McText {
                anchors.verticalCenter: parent.verticalCenter
                text: root.batCap + "%"
                font.pixelSize: root.px * 4
            }
        }
        McText {
            visible: root.mediaTitle !== ""
            text: "♪ " + root.mediaTitle + (root.mediaArtist !== "" ? " — " + root.mediaArtist : "")
            font.pixelSize: root.px * 4
            color: "#55ffff"
            width: Math.min(implicitWidth, root.width * 0.4)
            elide: Text.ElideRight
        }
    }

    // ---- bottom right: power buttons
    Row {
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.margins: root.px * 5
        spacing: root.px * 2
        z: 5
        McButton {
            height: root.px * 10
            label: "Сон"
            fontSize: root.px * 4
            onClicked: root.suspendRequested()
        }
        McButton {
            height: root.px * 10
            label: "Перезавантажити"
            fontSize: root.px * 4
            onClicked: root.rebootRequested()
        }
        McButton {
            height: root.px * 10
            label: "Вимкнути"
            fontSize: root.px * 4
            onClicked: root.poweroffRequested()
        }
    }

    // ---- Steve
    SteveVisitor {
        id: steve
        anchors.fill: parent
        z: 10
        active: root.visible
        style: "nether"
        target: terrain.groundItem
        homeFrac: 0.3
        px: root.px
        forcedPose: root.pwLength > 0 ? "back" : ""
        sleeping: !root.inputActive && root.pwLength === 0 && (root.hour >= 23 || root.hour < 6)
        phrases: ["Привіт, " + root.userName + "!", "Повертайся швидше!", "Я охороняю цей комп", "Пароль пам'ятаєш?",
                  "Кріпер позаду!", "Хочу алмазів", "Нудно...", "Гей!", "Покрафтимо?"]
        onArrivedSignal: say("Я посторожу, " + root.userName + "!")
    }

    // ---- "You died!" after running out of hearts (a joke: typing still works)
    Rectangle {
        anchors.fill: parent
        z: 50
        visible: root.hearts <= 0 && !root.unlocking
        color: Qt.rgba(0.55, 0, 0, 0.6)

        MouseArea { anchors.fill: parent; onPressed: { root.hearts = 10; root.activate(); } }

        Column {
            anchors.centerIn: parent
            spacing: root.px * 8
            McText {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "Ви загинули!"
                font.pixelSize: root.px * 18
            }
            McText {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "Причина: забагато неправильних паролів"
                font.pixelSize: root.px * 5
                color: "#e0e0e0"
            }
            McButton {
                anchors.horizontalCenter: parent.horizontalCenter
                width: root.px * 80
                height: root.px * 11
                label: "Відродитися"
                fontSize: root.px * 5
                onClicked: { root.hearts = 10; root.activate(); }
            }
        }
    }
}
