import QtQuick
import QtQuick.Window
import QtQuick.Layouts
import "../"
import "../reusables"

Item {
    id: root

    property var leadingSections: []
    property var redactor: null
    property real maxWidth: 0
    default property alias actions: actionsRow.data

    property int currentIndex: -1

    readonly property bool panelOpen: (root.currentIndex >= 0 && root.currentIndex < root.sections.length)
    property Item glassBackdropItem: dockBlur

    readonly property real controlHeight: s(42)
    readonly property real dockPadding: s(10)
    readonly property real groupSpacing: s(12)
    readonly property real tileWidth: s(64)
    readonly property real tileSpacing: s(8)
    readonly property real panelPadding: s(16)

    readonly property real filletRadius: ThemeBackend.borderRadius
    readonly property real drawerMaxWidth: Math.max(root.tileWidth + root.panelPadding * 2, root.width - root.filletRadius * 4)
    readonly property int columns: Math.max(1, Math.floor((root.drawerMaxWidth - root.panelPadding * 2 + root.tileSpacing) / (root.tileWidth + root.tileSpacing)))
    readonly property real drawerTargetWidth: root.shown.items.length === 0
        ? Math.min(root.drawerMaxWidth, noResultsText.implicitWidth + root.panelPadding * 2)
        : root.shownColumns * root.tileWidth + (root.shownColumns - 1) * root.tileSpacing + root.panelPadding * 2
    property real drawerWidth: drawerTargetWidth
    Behavior on drawerWidth { enabled: drawer.visible; NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
    readonly property real drawerTarget: root.panelOpen ? drawerContent.implicitHeight : 0
    property real drawerHeight: drawerTarget
    Behavior on drawerHeight { NumberAnimation { duration: 240; easing.type: Easing.OutCubic } }

    signal leadingItemActivated(string id)

    function s(val) { return Scaler.s(val); }

    function keyOf(entry) { return entry.kind + ":" + entry.id; }

    readonly property var sections: {
        let types = WidgetRegistry.types;
        let placed = {};
        let out = [];

        for (let sec of root.leadingSections) {
            let items = (sec.items || []).map(it => Object.assign({ kind: "leading" }, it));
            if (items.length > 0) out.push({ id: sec.id, name: sec.name, icon: sec.icon, items: items });
        }

        let widgetItem = id => ({ kind: "widget", id: id, icon: types[id].icon || "", name: types[id].name || id });

        for (let cat of WidgetRegistry.categories) {
            let items = Object.keys(types).filter(id => types[id].category === cat.id).map(widgetItem);
            items.forEach(it => placed[it.id] = true);
            if (items.length > 0) out.push({ id: cat.id, name: cat.name, icon: cat.icon, items: items });
        }

        let rest = Object.keys(types).filter(id => !placed[id]).map(widgetItem);
        if (rest.length > 0) {
            out.push({
                id: "__other",
                name: I18n.t("widgets.redactor.category.other", "Other"),
                icon: String.fromCodePoint(0xF0431),
                items: rest
            });
        }
        return out;
    }

    readonly property var allItems: {
        let seen = {};
        let out = [];
        for (let sec of root.sections) {
            for (let it of sec.items) {
                let key = root.keyOf(it);
                if (seen[key]) continue;
                seen[key] = true;
                out.push(it);
            }
        }
        return out;
    }

    readonly property var panelContent: {
        let sec = root.sections[root.currentIndex];
        return { items: sec ? sec.items : [] };
    }

    property var shown: ({ items: [] })

    readonly property int shownColumns: Math.max(1, Math.min(root.columns, root.shown.items.length))

    readonly property var shownSlots: {
        let slots = {};
        root.shown.items.forEach((it, i) => slots[root.keyOf(it)] = i);
        return slots;
    }

    Binding {
        target: root
        property: "shown"
        value: root.panelContent
        when: root.panelOpen
        restoreMode: Binding.RestoreNone
    }

    function activate(entry) {
        if (!entry) return;
        root.close();
        if (entry.kind === "leading") {
            root.leadingItemActivated(entry.id);
        } else if (root.redactor) {
            root.redactor.addWidget(entry.id);
        }
    }

    function revealChip(chip) {
        if (!chip || !chipFlick.interactive) return;
        let target = chipFlick.contentX;
        if (chip.x < target) target = chip.x;
        else if (chip.x + chip.width > target + chipFlick.width) target = chip.x + chip.width - chipFlick.width;
        root.scrollChipsTo(target);
    }

    function scrollChipsTo(x) {
        chipScroll.stop();
        chipScroll.to = Math.max(0, Math.min(chipFlick.contentWidth - chipFlick.width, x));
        chipScroll.start();
    }

    function cycleSection(step) {
        let n = root.sections.length;
        if (n === 0) return;
        let from = root.currentIndex < 0 ? (step > 0 ? -1 : 0) : root.currentIndex;
        root.toggleSection(((from + step) % n + n) % n);
    }

    function toggleSection(index) {
        if (root.currentIndex === index) {
            root.currentIndex = -1;
            return;
        }
        root.revealChip(chipRepeater.itemAt(index));
        root.currentIndex = index;
    }

    function close() {
        root.currentIndex = -1;
    }

    function dismiss() {
        if (!root.panelOpen) return false;
        root.close();
        return true;
    }

    implicitHeight: root.controlHeight + root.dockPadding * 2
    implicitWidth: {
        let natural = dockRow.implicitWidth + root.dockPadding * 2;
        return root.maxWidth > 0 ? Math.min(root.maxWidth, natural) : natural;
    }
    width: implicitWidth
    height: implicitHeight

    onVisibleChanged: if (!visible) root.close()
    onSectionsChanged: if (root.currentIndex >= root.sections.length) root.currentIndex = -1

    onCurrentIndexChanged: {
        let sec = root.sections[root.currentIndex];
        if (sec) WidgetPickerState.lastSectionId = sec.id;
    }

    Component.onCompleted: {
        let idx = root.sections.findIndex(sec => sec.id === WidgetPickerState.lastSectionId);
        if (idx >= 0) root.currentIndex = idx;
    }

    Shortcut {
        sequences: ["Tab", "Right"]
        enabled: root.visible && root.panelOpen
        onActivated: root.cycleSection(1)
    }

    Shortcut {
        sequences: ["Backtab", "Left"]
        enabled: root.visible && root.panelOpen
        onActivated: root.cycleSection(-1)
    }

    Repeater {
        model: Math.min(9, root.sections.length)

        Item {
            required property int index

            Shortcut {
                sequence: String(index + 1)
                enabled: root.visible
                onActivated: root.toggleSection(index)
            }
        }
    }

    Item {
        parent: root.Window.window ? root.Window.window.contentItem : null
        width: parent ? parent.width : 0
        height: parent ? parent.height : 0
        visible: root.panelOpen
        enabled: root.panelOpen

        PointHandler {
            acceptedButtons: Qt.AllButtons
            grabPermissions: PointerHandler.TakeOverForbidden
            target: null
            onActiveChanged: {
                if (!active || !point) return;
                let pt = point.scenePosition || point.position;
                if (!pt) return;
                let inDock = root.contains(root.mapFromItem(null, pt.x, pt.y));
                let inDrawer = drawer.contains(drawer.mapFromItem(null, pt.x, pt.y));
                if (!inDock && !inDrawer) root.close();
            }
        }
    }

    Rectangle {
        anchors.fill: parent
        color: Qt.alpha(ThemeBackend.base, ThemeBackend.elementOpacity)
        radius: ThemeBackend.borderRadius

        WallpaperBlur {
            id: dockBlur
            z: -1
            anchors.fill: parent
            radius: parent.radius
            standalone: true
        }

        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.AllButtons
            onWheel: (wheel) => wheel.accepted = true
        }
    }

    Item {
        id: drawer
        readonly property real fillet: Math.min(root.filletRadius, height)
        readonly property color fill: Qt.alpha(ThemeBackend.base, ThemeBackend.elementOpacity)

        x: Math.round((root.width - width) / 2)
        width: root.drawerWidth
        height: root.drawerHeight
        anchors.bottom: parent.top
        visible: height > 0.5
        enabled: root.panelOpen

        GlassFillets {
            card: drawerBg
            surfaceEnabled: filletRadius > 0.5
            filletRadius: drawer.fillet
            filletDir: Qt.vector2d(0, 1)
        }

        WallpaperBlur {
            anchors.fill: parent
            standalone: true
            topLeftRadius: root.filletRadius
            topRightRadius: root.filletRadius
            bottomLeftRadius: 0
            bottomRightRadius: 0
            filletRadius: drawer.fillet
            filletDir: Qt.vector2d(0, 1)
        }

        Rectangle {
            id: drawerBg
            anchors.fill: parent
            color: drawer.fill
            radius: root.filletRadius
            topLeftRadius: root.filletRadius
            topRightRadius: root.filletRadius
            bottomLeftRadius: 0
            bottomRightRadius: 0
        }

        ShaderEffect {
            visible: drawer.fillet > 0.5
            x: -width
            y: drawer.height - height
            width: drawer.fillet
            height: drawer.fillet
            property vector2d itemSize: Qt.vector2d(width, height)
            property real cornerIndex: 3.0
            property color color: drawer.fill
            fragmentShader: "file://" + Caching.serpantinumDir + "/assets/shaders/ui/corner_cutout.frag.qsb"
        }

        ShaderEffect {
            visible: drawer.fillet > 0.5
            x: drawer.width
            y: drawer.height - height
            width: drawer.fillet
            height: drawer.fillet
            property vector2d itemSize: Qt.vector2d(width, height)
            property real cornerIndex: 2.0
            property color color: drawer.fill
            fragmentShader: "file://" + Caching.serpantinumDir + "/assets/shaders/ui/corner_cutout.frag.qsb"
        }

        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.AllButtons
            onWheel: (wheel) => wheel.accepted = true
        }

        Item {
            anchors.fill: parent
            clip: true

            Item {
                id: drawerContent
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                implicitHeight: (root.shown.items.length === 0 ? s(66) : tileGrid.implicitHeight) + root.panelPadding * 2 - root.dockPadding
                height: implicitHeight
                opacity: root.panelOpen ? 1.0 : 0.0
                Behavior on opacity { NumberAnimation { duration: 180; easing.type: Easing.OutQuad } }

                Text {
                    id: noResultsText
                    visible: root.shown.items.length === 0
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.top: parent.top
                    anchors.topMargin: root.panelPadding
                    height: s(66)
                    verticalAlignment: Text.AlignVCenter
                    text: I18n.t("widgets.redactor.no_results", "Nothing found")
                    font.family: ThemeBackend.fontFamily
                    font.pixelSize: s(12)
                    color: ThemeBackend.subtext0
                }

                GridLayout {
                    id: tileGrid
                    anchors.top: parent.top
                    anchors.topMargin: root.panelPadding
                    anchors.horizontalCenter: parent.horizontalCenter
                    opacity: root.shown.items.length > 0 ? 1.0 : 0.0
                    rowSpacing: s(10)
                    columnSpacing: root.tileSpacing

                    Repeater {
                        model: root.allItems

                        Item {
                            id: tile
                            required property var modelData
                            readonly property int slot: {
                                let pos = root.shownSlots[root.keyOf(modelData)];
                                return pos === undefined ? -1 : pos;
                            }
                
                            visible: tile.slot >= 0
                            Layout.row: Math.floor(Math.max(0, tile.slot) / root.shownColumns)
                            Layout.column: Math.max(0, tile.slot) % root.shownColumns
                            Layout.alignment: Qt.AlignTop
                            implicitWidth: root.tileWidth
                            implicitHeight: tileCol.implicitHeight

                            ColumnLayout {
                                id: tileCol
                                anchors.left: parent.left
                                anchors.right: parent.right
                                spacing: s(6)

                                IconButton {
                                    Layout.alignment: Qt.AlignHCenter
                                    size: s(48)
                                    cornerRadius: ThemeBackend.borderRadius
                                    buttonIcon: tile.modelData.icon || ""
                                    iconFontSize: s(22)
                                    accentColor: ThemeBackend.surface0
                                    textColor: ThemeBackend.text
                                    onClicked: root.activate(tile.modelData)
                                }

                                Text {
                                    Layout.fillWidth: true
                                    horizontalAlignment: Text.AlignHCenter
                                    text: tile.modelData.name || ""
                                    elide: Text.ElideRight
                                    maximumLineCount: 1
                                    font.family: ThemeBackend.fontFamily
                                    font.pixelSize: s(11)
                                    font.bold: true
                                    color: ThemeBackend.subtext0
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    RowLayout {
        id: dockRow
        anchors.fill: parent
        anchors.margins: root.dockPadding
        spacing: root.groupSpacing

        Item {
            Layout.fillWidth: true
            Layout.preferredWidth: chipRow.implicitWidth
            Layout.minimumWidth: s(48)
            Layout.preferredHeight: root.controlHeight
            Layout.alignment: Qt.AlignVCenter

            Flickable {
                id: chipFlick
                anchors.fill: parent
                contentWidth: chipRow.implicitWidth
                contentHeight: height
                clip: contentWidth > width
                interactive: contentWidth > width
                flickableDirection: Flickable.HorizontalFlick
                boundsBehavior: Flickable.StopAtBounds

                NumberAnimation {
                    id: chipScroll
                    target: chipFlick
                    property: "contentX"
                    duration: 220
                    easing.type: Easing.OutCubic
                }

                WheelHandler {
                    enabled: chipFlick.interactive
                    onWheel: (event) => {
                        chipScroll.stop();
                        let delta = event.angleDelta.x !== 0 ? event.angleDelta.x : event.angleDelta.y;
                        chipFlick.contentX = Math.max(0, Math.min(chipFlick.contentWidth - chipFlick.width, chipFlick.contentX - delta));
                    }
                }

                Row {
                    id: chipRow
                    height: chipFlick.height
                    spacing: s(2)

                    Repeater {
                        id: chipRepeater
                        model: root.sections

                        ClickButton {
                            id: chip
                            required property var modelData
                            required property int index
                            readonly property bool current: root.currentIndex === index

                            implicitHeight: root.controlHeight
                            horizontalPadding: s(12)
                            cornerRadius: ThemeBackend.borderRadius
                            buttonIcon: chip.modelData.icon || ""
                            iconFontSize: s(15)
                            buttonText: chip.modelData.name || ""
                            textFontSize: s(12)
                            accentColor: chip.current ? ThemeBackend.mauve : ThemeBackend.surface0
                            textColor: chip.current ? ThemeBackend.crust : (chip.isHoveredOrHighlighted ? ThemeBackend.text : ThemeBackend.subtext0)
                            bgOpacity: chip.current || chip.isHoveredOrHighlighted ? 1.0 : 0.0
                            onClicked: root.toggleSection(chip.index)
                        }
                    }
                }
            }

            IconButton {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                size: s(24)
                cornerRadius: ThemeBackend.borderRadius
                buttonIcon: String.fromCodePoint(0xF0141)
                iconFontSize: s(14)
                accentColor: ThemeBackend.surface1
                textColor: ThemeBackend.text
                visible: chipFlick.interactive && chipFlick.contentX > 1
                onClicked: root.scrollChipsTo(chipFlick.contentX - chipFlick.width * 0.6)
            }

            IconButton {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                size: s(24)
                cornerRadius: ThemeBackend.borderRadius
                buttonIcon: String.fromCodePoint(0xF0142)
                iconFontSize: s(14)
                accentColor: ThemeBackend.surface1
                textColor: ThemeBackend.text
                visible: chipFlick.interactive && chipFlick.contentX < chipFlick.contentWidth - chipFlick.width - 1
                onClicked: root.scrollChipsTo(chipFlick.contentX + chipFlick.width * 0.6)
            }
        }

        RowLayout {
            id: actionsRow
            Layout.alignment: Qt.AlignVCenter
            spacing: s(6)
        }
    }
}
