import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris
import "../../../reusables"
import "../../../reusables/inputs"
import "../../../"

Item {
    id: root
    anchors.fill: parent

    property real minWidth: 150
    property real minHeight: 64
    property real maxWidth: 800
    property real maxHeight: 300
    property real minAspect: 2.4
    property real maxAspect: 3.2

    property real dynMargin: Math.max(6, Math.min(24, root.height * 0.12))
    property real dynSpacing: Math.max(4, Math.min(20, root.height * 0.08))
    property real btnSize: Math.max(18, Math.min(56, root.height * 0.24))
    property real iconSize: Math.round(btnSize * 0.3)
    property real titleSize: Math.max(10, Math.min(24, root.height * 0.14))
    property real subSize: Math.max(8, Math.min(16, root.height * 0.1))

    property bool showArt: true
    property bool showTime: true
    property bool showArtist: true
    property bool showBars: true

    property bool isVisVisible: visible && showBars

    property bool isSubscribed: false

    onIsVisVisibleChanged: updateSubscription()

    function updateSubscription() {
        if (isVisVisible && !isSubscribed) {
            isSubscribed = true;
            Cava.registerConsumer();
        } else if (!isVisVisible && isSubscribed) {
            isSubscribed = false;
            Cava.unregisterConsumer();
        }
    }

    function updateVisibility() {
        if (height >= 65 && width >= 180) showArt = true;
        else if (height <= 58 || width <= 170) showArt = false;

        if (height >= 85) showTime = true;
        else if (height <= 76) showTime = false;

        if (height >= 65) showArtist = true;
        else if (height <= 58) showArtist = false;

        if (height >= 55) showBars = true;
        else if (height <= 48) showBars = false;
    }

    Component.onCompleted: {
        updateVisibility();
        updateSubscription();
    }

    Component.onDestruction: {
        if (isSubscribed) {
            isSubscribed = false;
            Cava.unregisterConsumer();
        }
    }

    onHeightChanged: updateVisibility()
    onWidthChanged: updateVisibility()

    property var player: MprisController.activePlayer
    property bool isMediaActive: player !== null && player.playbackState !== MprisPlaybackState.Stopped && player.trackTitle !== ""

    property int barCount: 40
    property real barSpacing: Math.max(2, Math.floor(width * 0.008))
    property real qWidth: Math.round(width / 20) * 20
    property int activeBars: Math.min(barCount, Math.max(4, Math.floor(qWidth / (5 + barSpacing))))

    property var rawBarLevels: Cava.barLevels
    property var processedBars: {
        let source = rawBarLevels;
        let count = activeBars;
        let out = [];

        if (!source || source.length === 0) {
            for (let i = 0; i < count; i++) out.push(0.0);
            return out;
        }

        let srcLen = source.length;
        let half = (count - 1) / 2;

        for (let i = 0; i < count; i++) {
            let distFromCenter = Math.abs(i - half);
            let norm = half > 0 ? (distFromCenter / half) : 0;
            let pos = Math.pow(norm, 1.25) * (srcLen - 1);
            let idx0 = Math.floor(pos);
            let idx1 = Math.min(srcLen - 1, idx0 + 1);
            let frac = pos - idx0;

            let v0 = source[idx0] || 0.0;
            let v1 = source[idx1] || 0.0;
            let rawVal = v0 + (v1 - v0) * frac;

            let val = rawVal < 0.03 ? 0.0 : Math.pow((rawVal - 0.03) / 0.97, 1.15);
            val = Math.max(0.0, Math.min(1.0, val)) * 0.55;
            out.push(val);
        }

        return out;
    }

    property var barLevels: processedBars

    function formatTime(sec) {
        sec = Math.floor(sec || 0);
        let m = Math.floor(sec / 60), s = sec % 60;
        return (m < 10 ? "0" : "") + m + ":" + (s < 10 ? "0" : "") + s;
    }

    Rectangle {
        id: bgContainer
        anchors.fill: parent
        color: ThemeBackend.surface0
        radius: ThemeBackend.borderRadius

        Rectangle {
            id: bgMask
            anchors.fill: parent
            radius: bgContainer.radius
            visible: false
            layer.enabled: true
        }

        Item {
            anchors.fill: parent
            visible: root.showBars
            layer.enabled: true
            layer.effect: MultiEffect {
                maskEnabled: true
                maskSource: bgMask
            }

            Row {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                height: Math.max(20, parent.height * 0.55)
                spacing: root.barSpacing

                Repeater {
                    model: root.activeBars
                    delegate: Rectangle {
                        width: (parent.width - (root.activeBars - 1) * root.barSpacing) / root.activeBars
                        height: Math.max(2, level * parent.height * 0.85)
                        topLeftRadius: width * 0.5
                        topRightRadius: width * 0.5
                        bottomLeftRadius: 0
                        bottomRightRadius: 0
                        color: ThemeBackend.mauve
                        opacity: 0.08 + (level * 0.12)
                        anchors.bottom: parent.bottom

                        Behavior on height {
                            NumberAnimation {
                                duration: 75
                                easing.type: Easing.OutCubic
                            }
                        }

                        Behavior on opacity {
                            NumberAnimation {
                                duration: 75
                                easing.type: Easing.OutQuad
                            }
                        }

                        property real level: (root.barLevels && index < root.barLevels.length) ? root.barLevels[index] : 0.0
                    }
                }
            }
        }

        Item {
            anchors.fill: parent
            anchors.margins: root.dynMargin

            Rectangle {
                id: artRect
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                width: root.showArt ? Math.min(200, root.height - root.dynMargin * 2) : 0
                height: width
                radius: ThemeBackend.borderRadius
                color: ThemeBackend.surface1
                border.width: 1
                border.color: (root.isMediaActive && MprisController.isPlaying) ? ThemeBackend.mauve : ThemeBackend.surface1
                visible: root.showArt

                Text {
                    anchors.centerIn: parent
                    text: "󰎈"
                    font.family: ThemeBackend.fontFamily
                    font.pixelSize: parent.width * 0.35
                    color: ThemeBackend.subtext0
                    visible: !root.isMediaActive || !MprisController.artUrl
                }

                Rectangle {
                    id: artMask
                    anchors.fill: parent
                    radius: artRect.radius
                    visible: false
                    layer.enabled: true
                }

                Item {
                    id: artMaskedContainer
                    anchors.fill: parent
                    layer.enabled: true
                    layer.effect: MultiEffect {
                        maskEnabled: true
                        maskSource: artMask
                    }

                    Image {
                        id: artImg
                        anchors.fill: parent
                        source: (root.isMediaActive && MprisController.artUrl) ? (MprisController.artUrl.startsWith("file://") || MprisController.artUrl.startsWith("http") ? MprisController.artUrl : "file://" + MprisController.artUrl) : ""
                        fillMode: Image.PreserveAspectCrop
                        opacity: (root.isMediaActive && status === Image.Ready && MprisController.artUrl !== "") ? 1.0 : 0.0
                        Behavior on opacity { NumberAnimation { duration: 300 } }
                    }
                }
            }

            Item {
                id: detailsColumn
                anchors.left: root.showArt ? artRect.right : parent.left
                anchors.leftMargin: root.showArt ? root.dynSpacing : 0
                anchors.right: parent.right
                anchors.top: root.showArt ? artRect.top : parent.top
                anchors.bottom: root.showArt ? artRect.bottom : parent.bottom

                Item {
                    id: titleClip
                    anchors.top: parent.top
                    anchors.left: parent.left
                    anchors.right: parent.right
                    height: titleTextMain.implicitHeight
                    clip: true

                    property int marqueeSpacing: 30
                    property real scrollProgress: 0.0

                    Item {
                        id: marqueeContainer
                        height: parent.height
                        x: titleTextMain.implicitWidth > titleClip.width ? -titleClip.scrollProgress * (titleTextMain.implicitWidth + titleClip.marqueeSpacing) : 0

                        Row {
                            spacing: titleClip.marqueeSpacing
                            Text {
                                id: titleTextMain
                                text: root.isMediaActive ? (MprisController.trackTitle || "Unknown Track") : I18n.t("music.nothing_playing")
                                font.family: ThemeBackend.fontFamily
                                font.weight: Font.Black
                                font.pixelSize: root.titleSize
                                color: ThemeBackend.text

                                onTextChanged: {
                                    titleClip.scrollProgress = 0.0;
                                }
                            }

                            Text {
                                id: titleTextClone
                                text: titleTextMain.text
                                font.family: ThemeBackend.fontFamily
                                font.weight: Font.Black
                                font.pixelSize: root.titleSize
                                color: ThemeBackend.text
                                visible: titleTextMain.implicitWidth > titleClip.width
                            }
                        }
                    }

                    SequentialAnimation {
                        loops: Animation.Infinite
                        running: titleTextMain.implicitWidth > titleClip.width

                        PauseAnimation { duration: 3000 }
                        NumberAnimation {
                            target: titleClip
                            property: "scrollProgress"
                            from: 0.0
                            to: 1.0
                            duration: (titleTextMain.implicitWidth + titleClip.marqueeSpacing) * 25
                        }
                        PropertyAction { target: titleClip; property: "scrollProgress"; value: 0.0 }
                    }
                }

                Text {
                    id: artistText
                    anchors.top: titleClip.bottom
                    anchors.topMargin: Math.max(1, root.dynSpacing * 0.2)
                    anchors.left: parent.left
                    anchors.right: parent.right
                    text: root.isMediaActive ? (MprisController.trackArtist || "Unknown Artist") : ""
                    font.family: ThemeBackend.fontFamily
                    font.weight: Font.Medium
                    font.pixelSize: root.subSize
                    color: ThemeBackend.subtext1
                    elide: Text.ElideRight
                    visible: root.isMediaActive && root.showArtist
                }

                RowLayout {
                    id: controlsRow
                    anchors.bottom: parent.bottom
                    anchors.left: parent.left
                    spacing: Math.max(2, root.dynSpacing * 0.5)

                    IconButton {
                        Layout.preferredWidth: root.btnSize
                        Layout.preferredHeight: root.btnSize
                        Layout.minimumWidth: 0
                        Layout.minimumHeight: 0
                        cornerRadius: Math.max(4, root.btnSize * 0.2)
                        buttonIcon: "󰒮"
                        iconFontSize: root.iconSize
                        accentColor: ThemeBackend.surface1
                        textColor: isHoveredOrHighlighted ? ThemeBackend.text : ThemeBackend.overlay2
                        onClicked: if (root.player && root.player.canGoPrevious) root.player.previous()
                    }

                    IconButton {
                        Layout.preferredWidth: root.btnSize
                        Layout.preferredHeight: root.btnSize
                        Layout.minimumWidth: 0
                        Layout.minimumHeight: 0
                        cornerRadius: Math.max(4, root.btnSize * 0.2)
                        buttonIcon: (root.isMediaActive && MprisController.isPlaying) ? "󰏤" : "󰐊"
                        iconFontSize: root.iconSize
                        accentColor: ThemeBackend.surface1
                        textColor: isHoveredOrHighlighted ? ThemeBackend.green : ThemeBackend.text
                        onClicked: if (root.player && root.player.canTogglePlaying) root.player.togglePlaying()
                    }

                    IconButton {
                        Layout.preferredWidth: root.btnSize
                        Layout.preferredHeight: root.btnSize
                        Layout.minimumWidth: 0
                        Layout.minimumHeight: 0
                        cornerRadius: Math.max(4, root.btnSize * 0.2)
                        buttonIcon: "󰒭"
                        iconFontSize: root.iconSize
                        accentColor: ThemeBackend.surface1
                        textColor: isHoveredOrHighlighted ? ThemeBackend.text : ThemeBackend.overlay2
                        onClicked: if (root.player && root.player.canGoNext) root.player.next()
                    }
                }

                Item {
                    id: middleArea
                    anchors.top: artistText.visible ? artistText.bottom : titleClip.bottom
                    anchors.bottom: controlsRow.top
                    anchors.left: parent.left
                    anchors.right: parent.right

                    RowLayout {
                        id: seekRow
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.left: parent.left
                        anchors.right: parent.right
                        height: Math.max(14, Math.round(root.subSize * 1.2))
                        spacing: Math.max(4, root.dynSpacing * 0.4)
                        visible: root.showTime && root.isMediaActive

                        Text {
                            text: root.isMediaActive && root.player ? root.formatTime(MprisController.livePosition) : "--:--"
                            font.family: ThemeBackend.fontFamily
                            font.weight: Font.Bold
                            font.pixelSize: Math.max(7, root.subSize * 0.85)
                            color: ThemeBackend.subtext0
                            verticalAlignment: Text.AlignVCenter
                            Layout.alignment: Qt.AlignVCenter
                        }

                        WavySeekBar {
                            id: progBar
                            Layout.fillWidth: true
                            Layout.preferredHeight: Math.max(14, Math.round(root.subSize * 1.2))
                            Layout.maximumHeight: Math.max(14, Math.round(root.subSize * 1.2))
                            Layout.minimumWidth: 0
                            Layout.alignment: Qt.AlignVCenter
                            from: 0.0
                            to: root.player ? root.player.length : 100.0
                            value: MprisController.livePosition
                            playing: root.player ? root.player.isPlaying : false
                            waveColor: ThemeBackend.mauve

                            property bool seekPending: false

                            Timer {
                                id: seekTimer
                                interval: 1000
                                onTriggered: progBar.seekPending = false
                            }

                            Connections {
                                target: MprisController
                                function onLivePositionChanged() {
                                    if (!progBar.isDragging && !progBar.seekPending) {
                                        progBar.value = MprisController.livePosition;
                                    }
                                }
                            }

                            onMoved: val => {
                                if (root.player && root.player.canSeek) {
                                    progBar.seekPending = true;
                                    seekTimer.restart();
                                    progBar.value = val;
                                    root.player.position = val;
                                }
                            }
                        }

                        Text {
                            text: root.isMediaActive && root.player ? root.formatTime(root.player.length) : "--:--"
                            font.family: ThemeBackend.fontFamily
                            font.weight: Font.Bold
                            font.pixelSize: Math.max(7, root.subSize * 0.85)
                            color: ThemeBackend.subtext0
                            verticalAlignment: Text.AlignVCenter
                            Layout.alignment: Qt.AlignVCenter
                        }
                    }
                }
            }
        }
    }
}
