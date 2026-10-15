import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import "../"
import "../reusables"

Rectangle {
    id: typeRoot
    width: parent ? parent.width : 0
    implicitHeight: visualItem.implicitHeight
    color: "transparent"

    property var model
    property var root
    property var delegateWrapper
    property bool expanded: false
    property real expandProgress: expanded ? 1.0 : 0.0
    Behavior on expandProgress {
        enabled: !cardHover.draggingV
        NumberAnimation { duration: 250; easing.type: Easing.OutCubic }
    }

    property bool showIcon: true
    property int urgency: model && typeof model.urgency !== "undefined" ? model.urgency : 1

    readonly property bool isDragging: cardHover.draggingH || cardHover.draggingV
    readonly property bool isHovered: cardHover.containsMouse || cardHover.pressed || isDragging
    readonly property bool isPopup: delegateWrapper && delegateWrapper.isPopupContext ? true : false

    property color accentColor: urgency === 2 ? ThemeBackend.red : ThemeBackend.blue
    property string fullSummary: ""
    property string fullBody: ""
    property string combinedBodyText: fullBody
    property int msgCount: 1
    readonly property bool canExpand: fullBody.length > 50 || fullBody.indexOf("\n") !== -1 || (delegateWrapper && delegateWrapper.actionArray && delegateWrapper.actionArray.length > 0)

    property alias bgContent: bgContainer.data
    property alias iconArea: iconContainer.data
    property alias headerArea: headerContentContainer.data
    default property alias faceContent: innerLayout.data

    property bool overrideClick: false
    signal cardClicked()

    property real timestamp: model && model.timestamp ? model.timestamp : Date.now()
    property string timeText: ""

    property bool readState: model && typeof model.read !== "undefined" ? Boolean(model.read) : true
    function forceRead(r) { readState = r; }
    onModelChanged: {
        if (model) {
            readState = typeof model.read !== "undefined" ? Boolean(model.read) : true;
        }
    }

    property bool _soundPlayed: false

    function playPopupSound() {
        if (_soundPlayed) return;
        if (!typeRoot.isPopup) return;
        if (Math.abs(Date.now() - typeRoot.timestamp) > 3000) return;
        let cfg = Config.getSetting("notifications", { "sound": true, "soundFile": "", "dnd": false });
        if (cfg.dnd === true) return;
        let soundEnabled = cfg.sound !== undefined ? cfg.sound : true;
        let soundFile = cfg.soundFile !== undefined ? cfg.soundFile : "";
        if (!soundEnabled || soundFile === "") return;

        if (typeof Sounds !== "undefined") {
            _soundPlayed = true;
            Sounds.play(soundFile);
        }
    }

    onDelegateWrapperChanged: Qt.callLater(playPopupSound)
    onIsPopupChanged: {
        if (isPopup) Qt.callLater(playPopupSound);
    }

    function updateTimeText() {
        let now = new Date();
        let notifDate = new Date(timestamp);
        let diffSec = Math.floor((now.getTime() - notifDate.getTime()) / 1000);

        let fmt = (typeof Config !== "undefined" && Config.rawSettings && Config.rawSettings.bar && Config.rawSettings.bar.time && Config.rawSettings.bar.time.format !== undefined) ? Config.rawSettings.bar.time.format : "HH:mm";
        let timePart = "HH:mm";
        if (fmt.includes("hh:")) {
            timePart = Qt.formatDateTime(notifDate, "hh:mm AP");
        } else {
            timePart = Qt.formatDateTime(notifDate, "HH:mm");
        }

        if (diffSec < 60) {
            timeText = "Just now";
            return;
        }

        let diffMin = Math.floor(diffSec / 60);
        if (diffMin < 60) {
            timeText = diffMin + " min ago";
            return;
        }

        let isSameDay = now.getFullYear() === notifDate.getFullYear() &&
                        now.getMonth() === notifDate.getMonth() &&
                        now.getDate() === notifDate.getDate();

        let yesterday = new Date(now);
        yesterday.setDate(yesterday.getDate() - 1);
        let isYesterday = yesterday.getFullYear() === notifDate.getFullYear() &&
                          yesterday.getMonth() === notifDate.getMonth() &&
                          yesterday.getDate() === notifDate.getDate();

        let diffDays = Math.floor(diffSec / 86400);

        if (isSameDay) {
            timeText = timePart;
        } else if (isYesterday) {
            timeText = "Yesterday " + timePart;
        } else if (diffDays < 7) {
            let dayName = Qt.formatDateTime(notifDate, "dddd");
            timeText = dayName + " " + timePart;
        } else {
            timeText = Qt.formatDateTime(notifDate, "yyyy-MM-dd ") + timePart;
        }
    }

    Connections {
        target: typeof Config !== "undefined" ? Config : null
        function onSettingsLoaded() { updateTimeText(); }
    }

    Timer {
        interval: 10000
        running: true
        repeat: true
        onTriggered: updateTimeText()
    }

    onTimestampChanged: updateTimeText()
    Component.onCompleted: {
        updateTimeText();
        Qt.callLater(playPopupSound);
    }

    function s(val) { return root && typeof root.s === "function" ? root.s(val) : val; }

    function getActionIcon(idStr, textStr) {
        let i = (idStr || "").toLowerCase();
        let t = (textStr || "").toLowerCase();
        if (i.includes("reply") || t.includes("reply")) return "󰗊";
        if (i.includes("open") || t.includes("open")) return "󰏔";
        if (i.includes("close") || t.includes("close") || i.includes("dismiss") || t.includes("dismiss")) return "󰅖";
        if (i.includes("default")) return "󰍜";
        if (i.includes("accept") || t.includes("accept") || i.includes("join") || t.includes("join")) return "󰄬";
        if (i.includes("decline") || t.includes("decline")) return "󰅖";
        return "󰅂";
    }

    function doClose() {
        var n = delegateWrapper ? delegateWrapper.realNotif : null;
        if (n && typeof n.close === "function") {
            n.close();
        }
        if (delegateWrapper && typeof delegateWrapper.removeThisNotif === "function") {
            delegateWrapper.removeThisNotif();
        }
    }

    RetainableLock {
        object: delegateWrapper && delegateWrapper.realNotif ? delegateWrapper.realNotif : null
        locked: true
    }

    property real dragX: 0
    property real dragY: 0
    property bool isDismissing: false

    NumberAnimation {
        id: cardResetAnim
        target: typeRoot
        property: "dragX"
        from: typeRoot.dragX
        to: 0
        duration: 200
        easing.type: Easing.OutCubic
    }

    NumberAnimation {
        id: cardResetAnimY
        target: typeRoot
        property: "dragY"
        from: typeRoot.dragY
        to: 0
        duration: 200
        easing.type: Easing.OutCubic
    }

    NumberAnimation {
        id: cardDismissAnim
        target: typeRoot
        property: "dragX"
        from: typeRoot.dragX
        duration: 200
        easing.type: Easing.OutQuad
        onFinished: {
            doClose();
        }
    }

    MouseArea {
        id: cardHover
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        property real startRootX: 0
        property real startRootY: 0
        property bool draggingH: false
        property bool draggingV: false

        function getTrackingRoot() {
            if (root && typeof root.mapFromItem === "function") return root;
            if (typeRoot.Window && typeRoot.Window.contentItem) return typeRoot.Window.contentItem;
            return typeRoot;
        }

        onPressed: (mouse) => {
            let r = getTrackingRoot();
            let pt = mapToItem(r, mouse.x, mouse.y);
            startRootX = pt.x;
            startRootY = pt.y;
            draggingH = false;
            draggingV = false;
            cardResetAnim.stop();
            cardResetAnimY.stop();
        }

        onPositionChanged: (mouse) => {
            if (!pressed) return;
            let r = getTrackingRoot();
            let pt = mapToItem(r, mouse.x, mouse.y);
            let dx = pt.x - startRootX;
            let dy = pt.y - startRootY;

            if (!draggingH && !draggingV) {
                if (Math.abs(dx) > s(6) && Math.abs(dx) > Math.abs(dy)) {
                    draggingH = true;
                    cardHover.preventStealing = true;
                } else if (Math.abs(dy) > s(6) && Math.abs(dy) >= Math.abs(dx)) {
                    if (typeRoot.canExpand) {
                        draggingV = true;
                        cardHover.preventStealing = true;
                    }
                }
            }

            if (draggingH) {
                typeRoot.dragX = dx;
            } else if (draggingV && typeRoot.canExpand) {
                typeRoot.dragY = dy > 0 ? Math.min(s(3.5), Math.sqrt(dy) * s(0.5)) : 0;
                let targetProg = typeRoot.expanded ? Math.max(0.0, Math.min(1.0, 1.0 + (dy / s(90)))) : Math.max(0.0, Math.min(1.0, dy / s(90)));
                typeRoot.expandProgress = targetProg;
            }
        }

        onReleased: (mouse) => {
            cardHover.preventStealing = false;
            if (draggingH) {
                let threshold = typeRoot.width * 0.18;
                if (Math.abs(typeRoot.dragX) > threshold) {
                    typeRoot.isDismissing = true;
                    cardDismissAnim.from = typeRoot.dragX;
                    cardDismissAnim.to = typeRoot.dragX > 0 ? typeRoot.width * 1.2 : -typeRoot.width * 1.2;
                    cardDismissAnim.start();
                } else {
                    cardResetAnim.from = typeRoot.dragX;
                    cardResetAnim.start();
                }
                draggingH = false;
            } else if (draggingV) {
                cardResetAnimY.from = typeRoot.dragY;
                cardResetAnimY.start();
                if (typeRoot.canExpand) {
                    if (!typeRoot.expanded && typeRoot.expandProgress > 0.35) {
                        typeRoot.expanded = true;
                    } else if (typeRoot.expanded && typeRoot.expandProgress < 0.65) {
                        typeRoot.expanded = false;
                    }
                }
                typeRoot.expandProgress = Qt.binding(() => typeRoot.expanded ? 1.0 : 0.0);
                draggingV = false;
            } else {
                if (typeRoot.readState === false) {
                    typeRoot.forceRead(true);
                    if (model && typeof model.uid !== "undefined") {
                        NotificationManager.markAsRead(model.uid);
                    }
                }

                if (overrideClick) {
                    typeRoot.cardClicked();
                } else {
                    var n = delegateWrapper ? delegateWrapper.realNotif : null;
                    if (n && n.actions && n.actions.length > 0) {
                        var mainAction = null;
                        for (var i = 0; i < n.actions.length; i++) {
                            if (n.actions[i].identifier === "default") {
                                mainAction = n.actions[i];
                                break;
                            }
                        }
                        if (!mainAction && n.actions.length > 0) {
                            mainAction = n.actions[0];
                        }
                        if (mainAction && typeof mainAction.invoke === "function") {
                            mainAction.invoke();
                        }
                    }
                }
            }
        }

        onCanceled: {
            cardHover.preventStealing = false;
            if (draggingH) {
                cardResetAnim.from = typeRoot.dragX;
                cardResetAnim.start();
                draggingH = false;
            }
            if (draggingV) {
                cardResetAnimY.from = typeRoot.dragY;
                cardResetAnimY.start();
                typeRoot.expandProgress = Qt.binding(() => typeRoot.expanded ? 1.0 : 0.0);
                draggingV = false;
            }
        }
    }

    Rectangle {
        id: cardShadow
        anchors.fill: parent
        anchors.topMargin: s(1.5) + Math.max(0, typeRoot.dragY * 0.4)
        anchors.bottomMargin: -(s(1.5) + Math.max(0, typeRoot.dragY * 0.4))
        radius: visualItem.radius
        color: Qt.rgba(0, 0, 0, 0.12 + Math.min(0.06, Math.max(0, typeRoot.dragY / s(3.5)) * 0.06))
        scale: visualItem.scale
        opacity: visualItem.opacity
        transform: Translate {
            x: typeRoot.dragX
            y: typeRoot.dragY
        }
    }

    TextMetrics {
        id: timeMetrics
        font.family: ThemeBackend.fontFamily
        font.pixelSize: s(11)
        text: typeRoot.timeText
    }

    TextMetrics {
        id: collapsedSummaryMetrics
        font.family: ThemeBackend.fontFamily
        font.weight: Font.Bold
        font.pixelSize: typeRoot.isPopup ? s(13) : s(12)
        text: typeRoot.fullSummary
    }

    readonly property real availableTopWidth: Math.max(0, cardContent.width - (typeRoot.showIcon ? s(50) : 0))
    readonly property real expandBtnSpace: (typeRoot.canExpand ? s(28) + s(6) : 0)
    readonly property real dotSpace: s(18)
    readonly property bool timeOnNextRowCollapsed: (collapsedSummaryMetrics.width + dotSpace + timeMetrics.width + expandBtnSpace) > availableTopWidth

    readonly property var summaryWords: {
        let s = (typeRoot.fullSummary || "").trim();
        return s.length > 0 ? s.split(/\s+/) : [];
    }
    readonly property string summaryPrefix: {
        if (summaryWords.length > 1) {
            return summaryWords.slice(0, summaryWords.length - 1).join(" ");
        }
        return typeRoot.fullSummary;
    }
    readonly property string summaryLastWord: {
        if (summaryWords.length > 1) {
            return summaryWords[summaryWords.length - 1];
        }
        return "";
    }

    Rectangle {
        id: visualItem
        anchors.fill: parent
        radius: ThemeBackend.borderRadius
        clip: true
        implicitHeight: cardContent.implicitHeight + s(20)

        property color baseColor: typeRoot.readState === false ? Qt.lighter(ThemeBackend.surface1, 1.05) : ThemeBackend.surface1
        color: (cardHover.pressed && !cardHover.draggingH && !cardHover.draggingV) ? Qt.darker(baseColor, 1.1) : (cardHover.containsMouse && !cardHover.draggingH && !cardHover.draggingV ? Qt.lighter(baseColor, 1.05) : baseColor)

        scale: (cardHover.pressed && !cardHover.draggingH && !cardHover.draggingV) ? 0.98 : 1.0

        Behavior on implicitHeight {
            enabled: !cardHover.draggingV
            NumberAnimation { duration: 250; easing.type: Easing.OutCubic }
        }
        Behavior on color { enabled: !cardHover.draggingH && !cardHover.draggingV; ColorAnimation { duration: 150 } }
        Behavior on scale { enabled: !cardHover.draggingH && !cardHover.draggingV; NumberAnimation { duration: 150; easing.type: Easing.OutQuint } }

        transform: Translate {
            x: typeRoot.dragX
            y: typeRoot.dragY
        }
        opacity: Math.max(0.0, 1.0 - (Math.abs(typeRoot.dragX) / (typeRoot.width * 0.75)))

        Item {
            id: urgencyGlow
            anchors.fill: parent
            visible: opacity > 0
            opacity: typeRoot.urgency === 2 ? pulseFactor : 0.0

            Behavior on opacity {
                enabled: !pulseAnim.running
                NumberAnimation { duration: 250; easing.type: Easing.OutCubic }
            }

            property real pulseFactor: 1.0
            SequentialAnimation on pulseFactor {
                id: pulseAnim
                running: typeRoot.urgency === 2
                loops: Animation.Infinite
                NumberAnimation { to: 0.40; duration: 1800; easing.type: Easing.InOutSine }
                NumberAnimation { to: 1.0; duration: 1800; easing.type: Easing.InOutSine }
            }

            readonly property color deepRed: {
                let h = ThemeBackend.red.hsvHue;
                let sVal = Math.min(0.95, Math.max(0.80, ThemeBackend.red.hsvSaturation * 2.0));
                let vVal = Math.min(0.85, ThemeBackend.red.hsvValue * 0.88);
                return Qt.hsva(h, sVal, vVal, 1.0);
            }

            Rectangle {
                anchors.fill: parent
                radius: visualItem.radius
                color: Qt.rgba(urgencyGlow.deepRed.r, urgencyGlow.deepRed.g, urgencyGlow.deepRed.b, 0.025)
            }

            Rectangle {
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                height: parent.height * 0.55
                radius: visualItem.radius
                color: "transparent"
                gradient: Gradient {
                    GradientStop { position: 0.0; color: Qt.rgba(urgencyGlow.deepRed.r, urgencyGlow.deepRed.g, urgencyGlow.deepRed.b, 0.11) }
                    GradientStop { position: 1.0; color: "transparent" }
                }
            }

            Rectangle {
                anchors.bottom: parent.bottom
                anchors.left: parent.left
                anchors.right: parent.right
                height: parent.height * 0.55
                radius: visualItem.radius
                color: "transparent"
                gradient: Gradient {
                    GradientStop { position: 0.0; color: "transparent" }
                    GradientStop { position: 1.0; color: Qt.rgba(urgencyGlow.deepRed.r, urgencyGlow.deepRed.g, urgencyGlow.deepRed.b, 0.11) }
                }
            }

            Rectangle {
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                anchors.left: parent.left
                width: parent.width * 0.35
                radius: visualItem.radius
                color: "transparent"
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0.0; color: Qt.rgba(urgencyGlow.deepRed.r, urgencyGlow.deepRed.g, urgencyGlow.deepRed.b, 0.11) }
                    GradientStop { position: 1.0; color: "transparent" }
                }
            }

            Rectangle {
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                anchors.right: parent.right
                width: parent.width * 0.35
                radius: visualItem.radius
                color: "transparent"
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0.0; color: "transparent" }
                    GradientStop { position: 1.0; color: Qt.rgba(urgencyGlow.deepRed.r, urgencyGlow.deepRed.g, urgencyGlow.deepRed.b, 0.11) }
                }
            }
        }

        Item {
            id: bgContainer
            anchors.fill: parent
        }

        ColumnLayout {
            id: cardContent
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: s(10)
            spacing: s(4)

            RowLayout {
                Layout.fillWidth: true
                spacing: typeRoot.showIcon ? s(10) : 0
                Layout.alignment: Qt.AlignTop
                layoutDirection: I18n.layoutDirection

                Item {
                    Layout.alignment: Qt.AlignTop
                    Layout.preferredWidth: typeRoot.showIcon ? s(40) : 0
                    Layout.preferredHeight: typeRoot.showIcon ? s(40) : 0
                    visible: typeRoot.showIcon

                    readonly property real boxRadius: s(10)
                    readonly property real boxPadding: s(5)

                    Rectangle {
                        anchors.fill: parent
                        anchors.topMargin: s(1.5)
                        anchors.bottomMargin: -s(1.5)
                        radius: parent.boxRadius
                        color: Qt.rgba(0, 0, 0, 0.12)
                    }

                    Rectangle {
                        anchors.fill: parent
                        radius: parent.boxRadius
                        color: typeRoot.urgency === 2 ? Qt.tint(ThemeBackend.surface2, Qt.rgba(urgencyGlow.deepRed.r, urgencyGlow.deepRed.g, urgencyGlow.deepRed.b, 0.12)) : ThemeBackend.surface2

                        Behavior on color { ColorAnimation { duration: 200 } }
                    }

                    Rectangle {
                        id: iconContainer
                        anchors.fill: parent
                        anchors.margins: parent.boxPadding
                        radius: Math.max(0, parent.boxRadius - parent.boxPadding)
                        color: "transparent"
                        clip: true
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignTop
                    Layout.topMargin: -s(3)
                    spacing: 0

                    Item {
                        id: topHeaderRow
                        Layout.fillWidth: true
                        Layout.preferredHeight: {
                            let singleH = s(28);
                            if (typeRoot.timeOnNextRowCollapsed && typeRoot.expandProgress < 1.0) {
                                let twoLineH = collapsedTwoLineContainer.implicitHeight + s(4);
                                return Math.max(singleH, twoLineH) * (1.0 - typeRoot.expandProgress) + singleH * typeRoot.expandProgress;
                            }
                            return singleH;
                        }

                        RowLayout {
                            id: headerContentContainer
                            x: I18n.rtl ? (parent.width - width) : 0
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: s(6)
                            layoutDirection: I18n.layoutDirection
                            opacity: Math.max(0.0, (typeRoot.expandProgress - 0.25) / 0.75)
                            visible: opacity > 0.0
                        }

                        Text {
                            id: collapsedSummary
                            x: I18n.rtl ? (parent.width - width) : 0
                            anchors.verticalCenter: parent.verticalCenter
                            width: Math.max(0, Math.min(implicitWidth, parent.width - typeRoot.expandBtnSpace - timeMetrics.width - typeRoot.dotSpace))
                            horizontalAlignment: I18n.textAlignment
                            text: typeRoot.fullSummary
                            font.family: ThemeBackend.fontFamily
                            font.weight: Font.Bold
                            font.pixelSize: typeRoot.isPopup ? s(13) : s(12)
                            color: ThemeBackend.text
                            elide: Text.ElideRight
                            maximumLineCount: 1
                            opacity: (!typeRoot.timeOnNextRowCollapsed) ? Math.max(0.0, 1.0 - typeRoot.expandProgress * 3.0) : 0.0
                            visible: opacity > 0.0
                        }

                        Text {
                            id: dotLabel
                            x: I18n.rtl ? (collapsedSummary.x - implicitWidth - s(6)) : (collapsedSummary.x + collapsedSummary.width + s(6))
                            anchors.verticalCenter: parent.verticalCenter
                            text: "•"
                            font.family: ThemeBackend.fontFamily
                            font.pixelSize: s(10)
                            color: ThemeBackend.subtext1
                            opacity: (!typeRoot.timeOnNextRowCollapsed) ? Math.max(0.0, 1.0 - typeRoot.expandProgress * 3.0) : 0.0
                            visible: opacity > 0.0
                        }

                        Text {
                            id: topTimeLabel
                            anchors.verticalCenter: parent.verticalCenter
                            text: typeRoot.timeText
                            font.family: ThemeBackend.fontFamily
                            font.pixelSize: s(11)
                            color: ThemeBackend.subtext1

                            readonly property real startX: I18n.rtl ? (topHeaderRow.width - collapsedSummary.width - s(12) - dotLabel.implicitWidth - implicitWidth) : (collapsedSummary.width + s(12) + dotLabel.implicitWidth)
                            readonly property real endX: I18n.rtl ? typeRoot.expandBtnSpace : Math.max(0, topHeaderRow.width - typeRoot.expandBtnSpace - implicitWidth)
                            x: typeRoot.timeOnNextRowCollapsed ? endX : (startX + (endX - startX) * typeRoot.expandProgress)

                            opacity: typeRoot.timeOnNextRowCollapsed ? Math.max(0.0, (typeRoot.expandProgress - 0.25) / 0.75) : 1.0
                            visible: opacity > 0.0 && text !== ""
                        }

                        Column {
                            id: collapsedTwoLineContainer
                            x: I18n.rtl ? (expandButton.visible ? expandButton.width + s(6) : 0) : 0
                            width: parent.width - (expandButton.visible ? expandButton.width + s(6) : 0)
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: s(1)
                            opacity: typeRoot.timeOnNextRowCollapsed ? Math.max(0.0, 1.0 - typeRoot.expandProgress * 3.0) : 0.0
                            visible: opacity > 0.0

                            Text {
                                width: parent.width
                                horizontalAlignment: I18n.textAlignment
                                text: typeRoot.summaryPrefix
                                font.family: ThemeBackend.fontFamily
                                font.weight: Font.Bold
                                font.pixelSize: typeRoot.isPopup ? s(13) : s(12)
                                color: ThemeBackend.text
                                elide: Text.ElideRight
                                maximumLineCount: 1
                            }

                            Row {
                                spacing: s(5)
                                width: parent.width
                                layoutDirection: I18n.layoutDirection

                                Text {
                                    text: typeRoot.summaryLastWord
                                    font.family: ThemeBackend.fontFamily
                                    font.weight: Font.Bold
                                    font.pixelSize: typeRoot.isPopup ? s(13) : s(12)
                                    color: ThemeBackend.text
                                    visible: typeRoot.summaryLastWord !== ""
                                }

                                Text {
                                    text: "•"
                                    font.family: ThemeBackend.fontFamily
                                    font.pixelSize: s(10)
                                    color: ThemeBackend.subtext1
                                    anchors.verticalCenter: parent.verticalCenter
                                    visible: typeRoot.summaryLastWord !== ""
                                }

                                Text {
                                    text: typeRoot.timeText
                                    font.family: ThemeBackend.fontFamily
                                    font.pixelSize: s(11)
                                    color: ThemeBackend.subtext1
                                    anchors.verticalCenter: parent.verticalCenter
                                    visible: typeRoot.timeText !== ""
                                }
                            }
                        }

                        FlipIcon {
                            id: expandButton
                            x: I18n.rtl ? 0 : (parent.width - width)
                            anchors.verticalCenter: parent.verticalCenter
                            visible: typeRoot.canExpand
                            size: s(28)
                            cornerRadius: s(7)
                            accentColor: ThemeBackend.surface2
                            iconColor: isHoveredOrHighlighted ? ThemeBackend.text : ThemeBackend.subtext1
                            autoToggle: false
                            flipped: typeRoot.expandProgress > 0.5
                            onClicked: typeRoot.expanded = !typeRoot.expanded
                        }
                    }

                    Item {
                        id: expandedSummaryContainer
                        Layout.fillWidth: true
                        Layout.topMargin: -s(2) * typeRoot.expandProgress
                        Layout.preferredHeight: (typeRoot.fullSummary !== "") ? expandedSummary.implicitHeight * Math.min(1.0, typeRoot.expandProgress * 1.1) : 0
                        opacity: Math.max(0.0, (typeRoot.expandProgress - 0.15) / 0.85)
                        visible: opacity > 0.001
                        clip: true

                        Text {
                            id: expandedSummary
                            anchors.top: parent.top
                            anchors.left: parent.left
                            anchors.right: parent.right
                            horizontalAlignment: I18n.textAlignment
                            text: typeRoot.fullSummary
                            font.family: ThemeBackend.fontFamily
                            font.weight: Font.Bold
                            font.pixelSize: typeRoot.isPopup ? s(13) : s(12)
                            color: ThemeBackend.text
                            wrapMode: Text.Wrap
                        }
                    }

                    Item {
                        Layout.fillWidth: true
                        Layout.topMargin: -s(1)
                        Layout.preferredHeight: {
                            if (typeRoot.fullBody === "") return 0;
                            let cH = collapsedBody.implicitHeight;
                            let eH = expandedBody.implicitHeight;
                            return cH + (eH - cH) * typeRoot.expandProgress;
                        }
                        clip: true
                        visible: typeRoot.fullBody !== ""

                        Text {
                            id: collapsedBody
                            anchors.top: parent.top
                            anchors.left: parent.left
                            anchors.right: parent.right
                            horizontalAlignment: I18n.textAlignment
                            text: typeRoot.fullBody
                            font.family: ThemeBackend.fontFamily
                            font.weight: Font.Normal
                            font.pixelSize: typeRoot.isPopup ? s(12) : s(11)
                            color: ThemeBackend.subtext0
                            elide: Text.ElideRight
                            maximumLineCount: 1
                            opacity: Math.max(0.0, 1.0 - typeRoot.expandProgress * 2.5)
                            visible: opacity > 0.001
                        }

                        Text {
                            id: expandedBody
                            anchors.top: parent.top
                            anchors.left: parent.left
                            anchors.right: parent.right
                            horizontalAlignment: I18n.textAlignment
                            text: typeRoot.fullBody
                            font.family: ThemeBackend.fontFamily
                            font.weight: Font.Normal
                            font.pixelSize: typeRoot.isPopup ? s(12) : s(11)
                            color: ThemeBackend.subtext0
                            wrapMode: Text.Wrap
                            textFormat: Text.StyledText
                            opacity: Math.max(0.0, (typeRoot.expandProgress - 0.2) / 0.8)
                            visible: opacity > 0.001
                        }
                    }

                    Item {
                        Layout.fillWidth: true
                        Layout.preferredHeight: innerLayout.implicitHeight * typeRoot.expandProgress
                        opacity: Math.max(0.0, (typeRoot.expandProgress - 0.2) / 0.8)
                        visible: opacity > 0.001
                        clip: true

                        ColumnLayout {
                            id: innerLayout
                            anchors.top: parent.top
                            anchors.left: parent.left
                            anchors.right: parent.right
                            spacing: s(2)
                        }
                    }

                    Item {
                        Layout.fillWidth: true
                        Layout.preferredHeight: (delegateWrapper && delegateWrapper.actionArray && delegateWrapper.actionArray.length > 0) ? (actionLayout.implicitHeight + s(12)) * typeRoot.expandProgress : 0
                        opacity: Math.max(0.0, (typeRoot.expandProgress - 0.2) / 0.8)
                        visible: opacity > 0.001
                        clip: true

                        RowLayout {
                            id: actionLayout
                            anchors.top: parent.top
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.topMargin: s(10)
                            anchors.leftMargin: I18n.rtl ? s(8) : 0
                            anchors.rightMargin: I18n.rtl ? 0 : s(8)
                            spacing: s(8)
                            layoutDirection: I18n.layoutDirection

                            Item {
                                Layout.fillWidth: true
                            }

                            Repeater {
                                model: delegateWrapper ? delegateWrapper.actionArray : []
                                delegate: ClickButton {
                                    readonly property bool isPrimary: index === 0
                                    Layout.minimumWidth: s(84)
                                    Layout.preferredHeight: s(28)
                                    cornerRadius: s(6)
                                    horizontalPadding: s(12)
                                    buttonText: modelData.text || I18n.t("notifications.types.default.action")
                                    textFontSize: typeRoot.isPopup ? s(12) : s(11)
                                    buttonIcon: typeRoot.getActionIcon(modelData.id, modelData.text)
                                    iconFontSize: s(11)
                                    accentColor: isPrimary ? typeRoot.accentColor : ThemeBackend.surface2
                                    textColor: isPrimary ? ThemeBackend.crust : ThemeBackend.subtext1
                                    onTriggered: {
                                        var n = delegateWrapper ? delegateWrapper.realNotif : null;
                                        if (n && n.actions) {
                                            for (var i = 0; i < n.actions.length; i++) {
                                                if (n.actions[i].identifier === modelData.id) {
                                                    n.actions[i].invoke();
                                                    break;
                                                }
                                            }
                                        }
                                        if (delegateWrapper && typeof delegateWrapper.removeThisNotif === "function") {
                                            delegateWrapper.removeThisNotif();
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
