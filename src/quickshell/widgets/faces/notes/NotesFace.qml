import QtQuick
import QtQuick.Window
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import "../../../reusables"
import "../../../"
import "../../../quickactions/actions/NotesFormat.js" as NotesFormat

Item {
    id: root
    anchors.fill: parent
    clip: true

    property real minWidth: 240
    property real minHeight: 180
    property real maxWidth: 700
    property real maxHeight: 700
    property real minAspect: 0.5
    property real maxAspect: 2.5
    property bool isRound: false

    property string nerdFont: ThemeBackend.iconFont

    property var notesList: []
    property bool fileLoaded: false
    property bool showError: false

    property bool isViewing: false
    property string viewingNoteId: ""
    property string viewingTitle: ""
    property string viewingContent: ""
    property real viewingUpdatedAt: 0
    property real expandProgress: 0.0
    property bool isDraggingV: false

    readonly property var generalSettings: Config.getSetting("general", {})
    readonly property bool quickactionsAvailable: generalSettings.quickactions !== false && !generalSettings.performance

    Behavior on expandProgress {
        enabled: !root.isDraggingV
        NumberAnimation { duration: 250; easing.type: Easing.OutCubic }
    }

    onExpandProgressChanged: {
        if (expandProgress <= 0.001 && isViewing && !isDraggingV) {
            isViewing = false;
            viewingNoteId = "";
        }
    }

    property real currentTimeTicker: 0
    Timer {
        interval: 10000
        running: true
        repeat: true
        onTriggered: root.currentTimeTicker = Date.now()
    }

    readonly property var displayNotesList: {
        let dummy = I18n.currentLang;
        let raw = root.notesList || [];
        let hasPinned = false;
        for (let i = 0; i < raw.length; i++) {
            if (raw[i].pinned) {
                hasPinned = true;
                break;
            }
        }
        let pinnedLabel = I18n.t("quickactions.notes.pinned");
        let recentLabel = I18n.t("quickactions.notes.recent");

        let pinned = [];
        let unpinned = [];
        for (let i = 0; i < raw.length; i++) {
            let item = raw[i];
            let copy = Object.assign({}, item);
            copy.sectionCategory = hasPinned ? (item.pinned ? pinnedLabel : recentLabel) : "";
            if (item.pinned) pinned.push(copy);
            else unpinned.push(copy);
        }
        return pinned.concat(unpinned);
    }

    function formatRelativeTime(timestamp) {
        let fmt = (Config.rawSettings && Config.rawSettings.bar && Config.rawSettings.bar.time && Config.rawSettings.bar.time.format !== undefined) ? Config.rawSettings.bar.time.format : "HH:mm";
        return NotesFormat.formatRelativeTime(timestamp, I18n, fmt);
    }

    function parseNotes(rawText) {
        let txt = (rawText || "").trim();
        if (txt === "") return;
        try {
            let data = JSON.parse(txt);
            if (Array.isArray(data)) root.notesList = data.filter(n => n && n.id !== undefined);
        } catch (e) {}
    }

    function beginViewing(noteItem) {
        root.viewingNoteId = noteItem.id;
        root.viewingTitle = noteItem.title || "";
        root.viewingContent = noteItem.content || "";
        root.viewingUpdatedAt = noteItem.updatedAt || Date.now();
        root.isViewing = true;
    }

    function openNote(noteItem) {
        root.beginViewing(noteItem);
        root.expandProgress = 1.0;
    }

    function closeNote() {
        root.expandProgress = 0.0;
    }

    function openNotes() {
        if (!root.quickactionsAvailable) {
            shakeAnim.stop();
            shakeAnim.start();
            return;
        }
        FloatingController.showNotes(root.Window.window ? root.Window.window.screen : null);
    }

    FileView {
        id: notesFile
        path: Caching.stateDir + "/quickactions/notes.json"
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            root.fileLoaded = true;
            root.parseNotes(typeof text === "function" ? text() : text);
        }
        onLoadFailed: root.fileLoaded = false
    }

    Timer {
        interval: 3000
        repeat: true
        running: !root.fileLoaded
        onTriggered: notesFile.reload()
    }

    SequentialAnimation {
        id: shakeAnim
        NumberAnimation { target: shakeShift; property: "x"; to: -Scaler.s(3); duration: 50 }
        NumberAnimation { target: shakeShift; property: "x"; to: Scaler.s(3); duration: 50 }
        NumberAnimation { target: shakeShift; property: "x"; to: -Scaler.s(3); duration: 50 }
        NumberAnimation { target: shakeShift; property: "x"; to: Scaler.s(3); duration: 50 }
        NumberAnimation { target: shakeShift; property: "x"; to: 0; duration: 50 }
        onStarted: root.showError = true
        onStopped: root.showError = false
    }

    Rectangle {
        anchors.fill: parent
        color: Qt.alpha(ThemeBackend.surface0, ThemeBackend.elementOpacity)
        radius: ThemeBackend.clampedBorderRadius
        clip: true

        WallpaperBlur {
            z: -1
            anchors.fill: parent
            radius: parent.radius
        }

        Item {
            id: mainListView
            anchors.fill: parent
            opacity: Math.max(0.0, 1.0 - root.expandProgress * 1.5)
            visible: opacity > 0.001

            Item {
                id: listControlBar
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                height: Scaler.s(42)

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: Scaler.s(12)
                    anchors.rightMargin: Scaler.s(10)
                    spacing: Scaler.s(8)

                    Text {
                        Layout.fillWidth: true
                        Layout.alignment: Qt.AlignVCenter
                        text: I18n.t("quickactions.tabs.notes", "Notes")
                        elide: Text.ElideRight
                        color: ThemeBackend.text
                        font.family: ThemeBackend.fontFamily
                        font.pixelSize: Scaler.s(13)
                        font.bold: true
                    }

                    Item {
                        id: addWrap
                        Layout.preferredWidth: Scaler.s(32)
                        Layout.preferredHeight: Scaler.s(32)
                        Layout.alignment: Qt.AlignVCenter
                        transform: Translate { id: shakeShift; x: 0 }

                        IconButton {
                            anchors.fill: parent
                            size: Scaler.s(32)
                            cornerRadius: Scaler.s(8)
                            iconFont: root.nerdFont
                            buttonIcon: "󰐕"
                            iconFontSize: Scaler.s(15)
                            accentColor: ThemeBackend.surface1
                            textColor: ThemeBackend.text
                            bgOpacity: ThemeBackend.elementOpacity
                            onClicked: root.openNotes()
                        }

                        Rectangle {
                            anchors.fill: parent
                            radius: Scaler.s(8)
                            color: ThemeBackend.red
                            opacity: root.showError ? 0.15 : 0.0
                            z: 4
                            Behavior on opacity { NumberAnimation { duration: 200 } }
                        }
                    }
                }
            }

            ListView {
                id: notesListView
                anchors.top: listControlBar.bottom
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                anchors.topMargin: Scaler.s(4)
                anchors.bottomMargin: Scaler.s(6)
                anchors.leftMargin: Scaler.s(8)
                anchors.rightMargin: Scaler.s(8)
                spacing: Scaler.s(6)
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                model: root.displayNotesList

                section.property: "sectionCategory"
                section.criteria: ViewSection.FullString
                section.delegate: Item {
                    width: ListView.view ? ListView.view.width : 0
                    height: (section && section !== "") ? Scaler.s(22) : 0
                    visible: section && section !== ""

                    Text {
                        anchors.left: parent.left
                        anchors.leftMargin: Scaler.s(4)
                        anchors.verticalCenter: parent.verticalCenter
                        text: section
                        font.family: ThemeBackend.fontFamily
                        font.weight: Font.Bold
                        font.pixelSize: Scaler.s(10.5)
                        color: ThemeBackend.subtext0
                        opacity: 0.85
                    }
                }

                HoverHandler {
                    id: listHover
                }

                ScrollBar.vertical: ScrollBar {
                    active: listHover.hovered
                    width: Scaler.s(4)
                    policy: listHover.hovered ? ScrollBar.AsNeeded : ScrollBar.AlwaysOff
                    contentItem: Rectangle {
                        implicitWidth: Scaler.s(4)
                        radius: Scaler.s(2)
                        color: ThemeBackend.surface2
                    }
                }

                delegate: Item {
                    id: noteDelegateWrapper
                    width: notesListView.width

                    readonly property bool isTargetNote: root.viewingNoteId === modelData.id
                    property real relativeUpdateTracker: root.currentTimeTicker

                    height: isTargetNote ? (Scaler.s(54) + (Scaler.s(130) - Scaler.s(54)) * root.expandProgress) : Scaler.s(54)

                    scale: itemMouseArea.pressed ? 0.98 : 1.0
                    Behavior on scale { NumberAnimation { duration: 180; easing.type: Easing.OutBack; easing.overshoot: 1.2 } }

                    Rectangle {
                        id: noteItemCard
                        anchors.fill: parent
                        radius: ThemeBackend.borderRadius
                        color: noteGlass.active ? "transparent" : Qt.alpha(itemMouseArea.containsMouse ? Qt.lighter(ThemeBackend.surface1, 1.04) : ThemeBackend.surface1, ThemeBackend.elementOpacity)
                        clip: true

                        GlassFill {
                            id: noteGlass
                            anchors.fill: parent
                            radius: parent.radius
                            tintColor: ThemeBackend.surface1
                            tintAmount: 0.3
                            press: itemMouseArea.pressed ? 0.8 : (itemMouseArea.containsMouse ? 0.2 : 0)
                            Behavior on press { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
                        }

                        Behavior on color { ColorAnimation { duration: 180; easing.type: Easing.OutCubic } }

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: Scaler.s(12)
                            anchors.rightMargin: Scaler.s(12)
                            spacing: Scaler.s(10)

                            Item {
                                Layout.preferredWidth: Scaler.s(30)
                                Layout.preferredHeight: Scaler.s(30)
                                Layout.alignment: Qt.AlignVCenter

                                Rectangle {
                                    anchors.fill: parent
                                    radius: Scaler.s(8)
                                    color: Qt.alpha(ThemeBackend.surface2, ThemeBackend.elementOpacity)

                                    Text {
                                        anchors.centerIn: parent
                                        font.family: root.nerdFont
                                        font.pixelSize: Scaler.s(14)
                                        color: ThemeBackend.subtext0
                                        text: "󰈙"
                                    }
                                }
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                Layout.alignment: Qt.AlignVCenter
                                spacing: Scaler.s(1)

                                Text {
                                    text: modelData.title || I18n.t("quickactions.notes.new_note_title")
                                    color: ThemeBackend.text
                                    font.family: ThemeBackend.fontFamily
                                    font.pixelSize: Scaler.s(12)
                                    font.weight: Font.Medium
                                    Layout.fillWidth: true
                                    elide: Text.ElideRight
                                }

                                Text {
                                    text: {
                                        let c = (modelData.content || "").replace(/\n/g, " ").trim();
                                        return c.length > 0 ? c : "...";
                                    }
                                    color: ThemeBackend.subtext0
                                    opacity: 0.85
                                    font.family: ThemeBackend.fontFamily
                                    font.pixelSize: Scaler.s(10)
                                    font.weight: Font.Normal
                                    Layout.fillWidth: true
                                    elide: Text.ElideRight
                                }
                            }

                            RowLayout {
                                Layout.alignment: Qt.AlignVCenter
                                spacing: Scaler.s(6)

                                Text {
                                    text: {
                                        let tick = noteDelegateWrapper.relativeUpdateTracker;
                                        return root.formatRelativeTime(modelData.updatedAt);
                                    }
                                    color: ThemeBackend.subtext1
                                    font.family: ThemeBackend.fontFamily
                                    font.pixelSize: Scaler.s(10)
                                }

                                FlipIcon {
                                    size: Scaler.s(26)
                                    cornerRadius: Scaler.s(6)
                                    accentColor: ThemeBackend.surface2
                                    bgOpacity: ThemeBackend.elementOpacity
                                    iconColor: isHoveredOrHighlighted ? ThemeBackend.text : ThemeBackend.subtext1
                                    autoToggle: false
                                    flipped: noteDelegateWrapper.isTargetNote && root.expandProgress > 0.5
                                    onClicked: root.openNote(modelData)
                                }
                            }
                        }

                        MouseArea {
                            id: itemMouseArea
                            anchors.fill: parent
                            hoverEnabled: true

                            property real startY: 0
                            property bool draggingV: false

                            onPressed: mouse => {
                                startY = mouse.y;
                                draggingV = false;
                                root.isDraggingV = false;
                            }

                            onPositionChanged: mouse => {
                                if (!pressed) return;
                                let dy = mouse.y - startY;
                                if (!draggingV && dy > Scaler.s(6)) {
                                    draggingV = true;
                                    root.isDraggingV = true;
                                    preventStealing = true;
                                    root.beginViewing(modelData);
                                }

                                if (draggingV) {
                                    root.expandProgress = Math.max(0.0, Math.min(1.0, dy / Scaler.s(90)));
                                }
                            }

                            onReleased: mouse => {
                                preventStealing = false;
                                if (draggingV) {
                                    root.isDraggingV = false;
                                    draggingV = false;
                                    root.expandProgress = root.expandProgress > 0.35 ? 1.0 : 0.0;
                                } else {
                                    root.openNote(modelData);
                                }
                            }

                            onCanceled: {
                                preventStealing = false;
                                if (draggingV) {
                                    root.isDraggingV = false;
                                    draggingV = false;
                                    root.expandProgress = root.expandProgress > 0.35 ? 1.0 : 0.0;
                                }
                            }
                        }
                    }
                }
            }

            Item {
                anchors.centerIn: parent
                visible: root.notesList.length === 0
                width: parent.width - Scaler.s(40)
                height: emptyCol.implicitHeight

                ColumnLayout {
                    id: emptyCol
                    anchors.centerIn: parent
                    spacing: Scaler.s(10)

                    Text {
                        text: "󰈙"
                        font.family: root.nerdFont
                        font.pixelSize: Scaler.s(36)
                        color: ThemeBackend.surface2
                        Layout.alignment: Qt.AlignHCenter
                    }

                    Text {
                        text: I18n.t("widgets.notes.empty", "No notes yet")
                        color: ThemeBackend.subtext0
                        font.family: ThemeBackend.fontFamily
                        font.pixelSize: Scaler.s(12)
                        horizontalAlignment: Text.AlignHCenter
                        wrapMode: Text.WordWrap
                        Layout.fillWidth: true
                        Layout.alignment: Qt.AlignHCenter
                    }
                }
            }
        }

        Item {
            id: viewerView
            anchors.fill: parent
            visible: root.expandProgress > 0.001
            opacity: Math.max(0.0, (root.expandProgress - 0.15) / 0.85)
            scale: 0.96 + 0.04 * root.expandProgress
            transform: Translate { y: Scaler.s(25) * (1.0 - root.expandProgress) }

            Rectangle {
                id: viewerCard
                anchors.fill: parent
                anchors.margins: Scaler.s(8)
                color: viewerGlass.active ? "transparent" : Qt.alpha(ThemeBackend.surface1, ThemeBackend.elementOpacity)
                radius: ThemeBackend.borderRadius
                clip: true

                GlassFill {
                    id: viewerGlass
                    anchors.fill: parent
                    radius: parent.radius
                    tintColor: ThemeBackend.surface1
                    tintAmount: 0.3
                }

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: Scaler.s(8)
                    spacing: Scaler.s(8)

                    Item {
                        Layout.fillWidth: true
                        Layout.preferredHeight: Scaler.s(32)

                        RowLayout {
                            anchors.fill: parent
                            spacing: Scaler.s(8)

                            CloseButton {
                                size: Scaler.s(32)
                                cornerRadius: Scaler.s(8)
                                iconFont: root.nerdFont
                                iconFontSize: Scaler.s(15)
                                textColor: ThemeBackend.text
                                accentColor: ThemeBackend.surface2
                                bgOpacity: ThemeBackend.elementOpacity
                                Layout.alignment: Qt.AlignVCenter
                                onClicked: root.closeNote()
                            }

                            Item {
                                Layout.fillWidth: true
                                Layout.fillHeight: true

                                Text {
                                    anchors.left: parent.left
                                    anchors.right: parent.right
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: NotesFormat.formatPreciseTime(root.viewingUpdatedAt)
                                    color: ThemeBackend.subtext0
                                    font.family: ThemeBackend.fontFamily
                                    font.pixelSize: Scaler.s(10.5)
                                    elide: Text.ElideRight
                                }

                                MouseArea {
                                    id: headerDragArea
                                    anchors.fill: parent
                                    hoverEnabled: true

                                    property real startY: 0
                                    property bool draggingV: false

                                    onPressed: mouse => {
                                        startY = mouse.y;
                                        draggingV = false;
                                        root.isDraggingV = false;
                                    }

                                    onPositionChanged: mouse => {
                                        if (!pressed) return;
                                        let dy = mouse.y - startY;
                                        if (!draggingV && dy > Scaler.s(6)) {
                                            draggingV = true;
                                            root.isDraggingV = true;
                                            preventStealing = true;
                                        }
                                        if (draggingV) {
                                            root.expandProgress = Math.max(0.0, Math.min(1.0, 1.0 - (dy / Scaler.s(90))));
                                        }
                                    }

                                    onReleased: {
                                        preventStealing = false;
                                        if (draggingV) {
                                            root.isDraggingV = false;
                                            draggingV = false;
                                            root.expandProgress = root.expandProgress < 0.65 ? 0.0 : 1.0;
                                        }
                                    }

                                    onCanceled: {
                                        preventStealing = false;
                                        if (draggingV) {
                                            root.isDraggingV = false;
                                            draggingV = false;
                                            root.expandProgress = root.expandProgress < 0.65 ? 0.0 : 1.0;
                                        }
                                    }
                                }
                            }
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: Scaler.s(34)
                        radius: Scaler.s(8)
                        color: Qt.alpha(ThemeBackend.surface0, ThemeBackend.elementOpacity)

                        Text {
                            anchors.fill: parent
                            anchors.leftMargin: Scaler.s(12)
                            anchors.rightMargin: Scaler.s(12)
                            verticalAlignment: Text.AlignVCenter
                            text: root.viewingTitle.trim().length > 0 ? root.viewingTitle.trim() : I18n.t("quickactions.notes.new_note_title")
                            color: ThemeBackend.text
                            font.family: ThemeBackend.fontFamily
                            font.pixelSize: Scaler.s(12.5)
                            font.bold: true
                            elide: Text.ElideRight
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        color: Qt.alpha(ThemeBackend.surface0, ThemeBackend.elementOpacity)
                        radius: Scaler.s(8)

                        Flickable {
                            id: previewFlickable
                            anchors.fill: parent
                            anchors.margins: Scaler.s(10)
                            contentWidth: width
                            contentHeight: previewText.height
                            boundsBehavior: Flickable.StopAtBounds
                            clip: true

                            HoverHandler {
                                id: previewHover
                            }

                            ScrollBar.vertical: ScrollBar {
                                active: previewHover.hovered
                                width: Scaler.s(4)
                                policy: previewHover.hovered ? ScrollBar.AsNeeded : ScrollBar.AlwaysOff
                                contentItem: Rectangle {
                                    implicitWidth: Scaler.s(4)
                                    radius: Scaler.s(2)
                                    color: ThemeBackend.surface2
                                }
                            }

                            Text {
                                id: previewText
                                width: previewFlickable.width
                                textFormat: Text.RichText
                                text: NotesFormat.markdownToHtml(root.viewingContent)
                                color: ThemeBackend.text
                                font.family: ThemeBackend.fontFamily
                                font.pixelSize: Scaler.s(12)
                                wrapMode: Text.WordWrap
                            }
                        }
                    }
                }
            }
        }
    }
}
