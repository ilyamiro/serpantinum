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
    property int maxColumns: 4
    default property alias actions: actionsRow.data

    property int currentIndex: -1
    property string query: ""
    property int highlightIndex: 0
    property real anchorX: width / 2

    readonly property bool typing: searchInput.hasFocus
    readonly property bool searching: root.query.trim() !== ""
    readonly property bool panelOpen: root.searching || (root.currentIndex >= 0 && root.currentIndex < root.sections.length)
    property bool previewsAlive: false
    property Item glassBackdropItem: dockBlur

    readonly property real controlHeight: s(34)
    readonly property real dockPadding: s(8)
    readonly property real groupSpacing: s(12)
    readonly property real cardWidth: s(148)
    readonly property real cardHeight: s(92)
    readonly property real cardSpacing: s(10)
    readonly property real panelPadding: s(12)

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

    function matchRank(text, q) {
        let t = String(text || "").toLowerCase();
        if (t.startsWith(q)) return 0;
        if (t.split(/[\s&\-\/]+/).some(w => w.startsWith(q))) return 1;
        if (t.includes(q)) return 2;
        return -1;
    }

    readonly property var results: {
        let q = root.query.trim().toLowerCase();
        if (q === "") return [];
        let seen = {};
        let ranked = [];
        for (let sec of root.sections) {
            let sectionRank = root.matchRank(sec.name, q);
            let sectionHit = q.length >= 2 && sectionRank >= 0 && sectionRank < 2;
            for (let it of sec.items) {
                let key = root.keyOf(it);
                if (seen[key]) continue;
                let rank = root.matchRank(it.name, q);
                if (rank < 0 && sectionHit) rank = 3;
                if (rank < 0) continue;
                seen[key] = true;
                ranked.push({ rank: rank, order: ranked.length, item: it });
            }
        }
        ranked.sort((a, b) => a.rank - b.rank || a.order - b.order);
        return ranked.map(r => r.item);
    }

    readonly property int shownColumns: Math.max(1, Math.min(root.maxColumns, root.shown.items.length))

    readonly property var panelContent: {
        if (root.searching) return { search: true, items: root.results };
        let sec = root.sections[root.currentIndex];
        return { search: false, items: sec ? sec.items : [] };
    }

    property var shown: ({ search: false, items: [] })

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

    onPanelOpenChanged: {
        if (root.panelOpen) {
            releaseTimer.stop();
            root.previewsAlive = true;
        } else {
            releaseTimer.restart();
        }
    }

    Timer {
        id: releaseTimer
        interval: 4000
        onTriggered: root.previewsAlive = false
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

    function anchorTo(item) {
        if (!item) return;
        root.anchorX = item.mapToItem(root, item.width / 2, 0).x;
    }

    function revealChip(chip) {
        let target = chipFlick.contentX;
        if (!chip || !chipFlick.interactive) return target;
        if (chip.x < target) target = chip.x;
        else if (chip.x + chip.width > target + chipFlick.width) target = chip.x + chip.width - chipFlick.width;
        return root.scrollChipsTo(target);
    }

    function scrollChipsTo(x) {
        let target = Math.max(0, Math.min(chipFlick.contentWidth - chipFlick.width, x));
        chipScroll.stop();
        chipScroll.to = target;
        chipScroll.start();
        return target;
    }

    function toggleSection(index) {
        if (root.query !== "") searchInput.clear();
        if (root.currentIndex === index) {
            root.currentIndex = -1;
            return;
        }
        let chip = chipRepeater.itemAt(index);
        if (chip) {
            let contentX = root.revealChip(chip);
            root.anchorX = chipFlick.mapToItem(root, 0, 0).x + chip.x - contentX + chip.width / 2;
        }
        root.currentIndex = index;
    }

    function moveHighlight(step, wrap) {
        let n = root.results.length;
        if (n === 0) return;
        let next = root.highlightIndex + step;
        if (wrap) next = ((next % n) + n) % n;
        else next = Math.max(0, Math.min(n - 1, next));
        root.highlightIndex = next;
    }

    function focusSearch() {
        root.currentIndex = -1;
        searchInput.forceInputFocus();
    }

    function close() {
        root.currentIndex = -1;
        if (root.query !== "") searchInput.clear();
        searchInput.releaseFocus();
    }

    function dismiss() {
        if (!root.panelOpen && !root.typing) return false;
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

    onVisibleChanged: {
        if (visible) return;
        root.close();
        releaseTimer.stop();
        root.previewsAlive = false;
    }
    onSectionsChanged: if (root.currentIndex >= root.sections.length) root.currentIndex = -1
    onQueryChanged: root.highlightIndex = 0

    Shortcut {
        sequence: "Ctrl+F"
        enabled: root.visible
        onActivated: root.focusSearch()
    }

    Shortcut {
        sequence: "Down"
        enabled: root.visible && root.typing && root.results.length > 0
        onActivated: root.moveHighlight(root.shownColumns, false)
    }

    Shortcut {
        sequence: "Up"
        enabled: root.visible && root.typing && root.results.length > 0
        onActivated: root.moveHighlight(-root.shownColumns, false)
    }

    Shortcut {
        sequence: "Tab"
        enabled: root.visible && root.typing && root.results.length > 0
        onActivated: root.moveHighlight(1, true)
    }

    Shortcut {
        sequence: "Backtab"
        enabled: root.visible && root.typing && root.results.length > 0
        onActivated: root.moveHighlight(-1, true)
    }

    Repeater {
        model: Math.min(9, root.sections.length)

        Item {
            required property int index

            Shortcut {
                sequence: String(index + 1)
                enabled: root.visible && !root.typing
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
                let inPanel = panel.contains(panel.mapFromItem(null, pt.x, pt.y));
                if (!inDock && !inPanel) root.close();
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
    }

    RowLayout {
        id: dockRow
        anchors.fill: parent
        anchors.margins: root.dockPadding
        spacing: root.groupSpacing

        Input {
            id: searchInput
            Layout.preferredWidth: s(176)
            Layout.preferredHeight: root.controlHeight
            Layout.alignment: Qt.AlignVCenter
            placeholderText: I18n.t("widgets.redactor.search", "Search widgets")
            leadingIcon: String.fromCodePoint(0xF0349)
            horizontalPadding: s(10)
            baseColor: ThemeBackend.surface0
            accentColor: ThemeBackend.mauve
            textColor: ThemeBackend.text
            subTextColor: ThemeBackend.subtext0
            borderColor: "transparent"
            cornerRadius: ThemeBackend.borderRadius
            fontPixelSize: s(12)
            showClearButton: true
            unfocusOnOutsideClick: false

            onTextEdited: function(newText) {
                if (root.currentIndex >= 0 || !root.searching) root.anchorTo(searchInput);
                root.currentIndex = -1;
                root.query = newText;
            }
            onCleared: root.query = ""
            onAccepted: function(finalText) {
                if (root.results.length > 0) root.activate(root.results[Math.min(root.highlightIndex, root.results.length - 1)]);
            }
        }

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
                            readonly property bool current: !root.searching && root.currentIndex === index

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

    component PreviewCard: Item {
        id: card
        property var entry: null
        property bool highlighted: false
        property bool live: false
        readonly property bool isWidget: !!card.entry && card.entry.kind === "widget"
        readonly property var faceSize: card.isWidget ? WidgetRegistry.defaultSize(card.entry.id) : ({ w: 1, h: 1 })
        readonly property bool hovered: cardMa.containsMouse
        readonly property bool lit: card.hovered || card.highlighted

        implicitWidth: root.cardWidth
        implicitHeight: frame.height + Scaler.s(6) + label.implicitHeight

        Rectangle {
            id: frame
            width: parent.width
            height: root.cardHeight
            radius: ThemeBackend.borderRadius
            color: frameGlass.active ? "transparent" : Qt.alpha(ThemeBackend.surface0, card.lit ? 0.7 : 0.0)
            border.width: card.highlighted ? Scaler.s(2) : 0
            border.color: ThemeBackend.mauve
            scale: cardMa.pressed ? 0.98 : 1.0
            Behavior on color { ColorAnimation { duration: 150 } }
            Behavior on scale { NumberAnimation { duration: 180; easing.type: Easing.OutQuint } }

            GlassFill {
                id: frameGlass
                anchors.fill: parent
                radius: parent.radius
                opacity: card.lit ? 1.0 : 0.0
                tintColor: ThemeBackend.surface0
                tintAmount: 0.42
                Behavior on opacity { NumberAnimation { duration: 150 } }
            }

            Item {
                id: stage
                anchors.fill: parent
                anchors.margins: Scaler.s(10)
                clip: true

                Item {
                    readonly property real fit: Math.min(stage.width / card.faceSize.w, stage.height / card.faceSize.h)
                    width: card.faceSize.w
                    height: card.faceSize.h
                    x: (stage.width - width * fit) / 2
                    y: (stage.height - height * fit) / 2
                    scale: fit
                    transformOrigin: Item.TopLeft
                    enabled: false

                    Loader {
                        id: faceLoader
                        anchors.fill: parent
                        asynchronous: true
                        active: card.isWidget && card.live
                        source: card.isWidget ? WidgetRegistry.faceFile(card.entry.id, WidgetRegistry.defaultVariant(card.entry.id)) : ""
                        opacity: status === Loader.Ready ? 1.0 : 0.0
                        Behavior on opacity { NumberAnimation { duration: 200 } }

                        onLoaded: {
                            if (!item) return;
                            if ("previewMode" in item) item.previewMode = true;
                            if ("wWidth" in item) item.wWidth = card.faceSize.w;
                            if ("wHeight" in item) item.wHeight = card.faceSize.h;
                        }
                    }
                }
            }

            Text {
                anchors.centerIn: parent
                visible: faceLoader.status !== Loader.Ready
                text: card.entry ? card.entry.icon : ""
                font.family: ThemeBackend.iconFont
                font.pixelSize: Scaler.s(24)
                color: card.lit ? ThemeBackend.text : ThemeBackend.subtext0
            }
        }

        Text {
            id: label
            anchors.top: frame.bottom
            anchors.topMargin: Scaler.s(6)
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            text: card.entry ? card.entry.name : ""
            elide: Text.ElideRight
            maximumLineCount: 1
            font.family: ThemeBackend.fontFamily
            font.pixelSize: Scaler.s(11)
            font.weight: Font.Medium
            color: card.lit ? ThemeBackend.text : ThemeBackend.subtext0
            Behavior on color { ColorAnimation { duration: 150 } }
        }

        MouseArea {
            id: cardMa
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                if (typeof Sounds !== "undefined") Sounds.playSfx("reusables/iconbutton/click.wav");
                root.activate(card.entry);
            }
        }
    }

    Item {
        id: panel
        property Item glassBackdropItem: panelBlur

        readonly property real windowX: {
            root.x; root.width;
            return root.Window.window ? root.mapToItem(null, 0, 0).x : 0;
        }
        readonly property real windowWidth: root.Window.window ? root.Window.width : root.width

        width: root.shownColumns * root.cardWidth + (root.shownColumns - 1) * root.cardSpacing + root.panelPadding * 2
        height: panelCol.implicitHeight + root.panelPadding * 2
        x: {
            let margin = s(8);
            let minX = margin - panel.windowX;
            let maxX = panel.windowWidth - panel.windowX - panel.width - margin;
            return Math.round(Math.max(minX, Math.min(maxX, root.anchorX - panel.width / 2)));
        }
        anchors.bottom: parent.top
        anchors.bottomMargin: s(8)
        transformOrigin: Item.Bottom

        opacity: root.panelOpen ? 1.0 : 0.0
        scale: root.panelOpen ? 1.0 : 0.97
        visible: opacity > 0
        enabled: root.panelOpen
        Behavior on x { enabled: root.panelOpen; NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
        Behavior on width { enabled: root.panelOpen; NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
        Behavior on opacity { NumberAnimation { duration: 160; easing.type: Easing.OutQuad } }
        Behavior on scale { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }

        Rectangle {
            anchors.fill: parent
            color: Qt.alpha(ThemeBackend.base, ThemeBackend.elementOpacity)
            radius: ThemeBackend.borderRadius

            WallpaperBlur {
                id: panelBlur
                z: -1
                anchors.fill: parent
                radius: parent.radius
                standalone: true
            }
        }

        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.AllButtons
            onWheel: (wheel) => wheel.accepted = true
        }

        ColumnLayout {
            id: panelCol
            anchors.fill: parent
            anchors.margins: root.panelPadding
            spacing: 0
            clip: true

            Text {
                visible: root.shown.items.length === 0
                Layout.fillWidth: true
                Layout.preferredHeight: root.cardHeight
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                text: I18n.t("widgets.redactor.no_results", "Nothing found")
                font.family: ThemeBackend.fontFamily
                font.pixelSize: s(12)
                color: ThemeBackend.subtext0
            }

            GridLayout {
                visible: root.shown.items.length > 0
                Layout.alignment: Qt.AlignHCenter
                rowSpacing: s(12)
                columnSpacing: root.cardSpacing

                Repeater {
                    model: root.allItems

                    PreviewCard {
                        id: slotCard
                        required property var modelData
                        readonly property int slot: {
                            let pos = root.shownSlots[root.keyOf(modelData)];
                            return pos === undefined ? -1 : pos;
                        }
                        property bool seen: false

                        visible: slot >= 0
                        Layout.row: Math.floor(Math.max(0, slot) / root.shownColumns)
                        Layout.column: Math.max(0, slot) % root.shownColumns
                        Layout.alignment: Qt.AlignTop
                        entry: modelData
                        live: root.previewsAlive && (slot >= 0 || seen)
                        highlighted: root.shown.search && slot === root.highlightIndex
                        onLiveChanged: seen = live
                    }
                }
            }
        }
    }
}
