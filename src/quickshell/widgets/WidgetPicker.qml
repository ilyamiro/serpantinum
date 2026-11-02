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
    property string query: ""
    property int highlightIndex: 0

    readonly property bool typing: searchInput.hasFocus
    readonly property bool searching: root.query.trim() !== ""
    readonly property bool panelOpen: root.searching || (root.currentIndex >= 0 && root.currentIndex < root.sections.length)
    property Item glassBackdropItem: dockBlur

    readonly property real controlHeight: s(34)
    readonly property real dockPadding: s(8)
    readonly property real groupSpacing: s(12)
    readonly property real tileWidth: s(64)
    readonly property real tileSpacing: s(8)
    readonly property real panelPadding: s(16)

    readonly property int columns: Math.max(1, Math.floor((root.width - root.panelPadding * 2 + root.tileSpacing) / (root.tileWidth + root.tileSpacing)))
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

    readonly property var panelContent: {
        if (root.searching) return { search: true, items: root.results };
        let sec = root.sections[root.currentIndex];
        return { search: false, items: sec ? sec.items : [] };
    }

    property var shown: ({ search: false, items: [] })

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

    function toggleSection(index) {
        if (root.query !== "") searchInput.clear();
        if (root.currentIndex === index) {
            root.currentIndex = -1;
            return;
        }
        root.revealChip(chipRepeater.itemAt(index));
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

    onVisibleChanged: if (!visible) root.close()
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
                if (!surface.contains(surface.mapFromItem(null, pt.x, pt.y))) root.close();
            }
        }
    }

    Item {
        id: surface
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: root.height + root.drawerHeight

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

        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.AllButtons
            onWheel: (wheel) => wheel.accepted = true
        }
    }

    Item {
        id: drawer
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.top
        height: root.drawerHeight
        clip: true
        visible: height > 0.5
        enabled: root.panelOpen

        Item {
            id: drawerContent
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            implicitHeight: tileGrid.implicitHeight + root.panelPadding * 2 - root.dockPadding
            height: implicitHeight
            opacity: root.panelOpen ? 1.0 : 0.0
            Behavior on opacity { NumberAnimation { duration: 180; easing.type: Easing.OutQuad } }

            Text {
                visible: root.shown.items.length === 0
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.top: parent.top
                anchors.topMargin: root.panelPadding
                height: tileGrid.implicitHeight
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
                        readonly property bool highlighted: root.shown.search && tile.slot === root.highlightIndex

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

                                Rectangle {
                                    anchors.fill: parent
                                    anchors.margins: -s(3)
                                    radius: ThemeBackend.borderRadius + s(3)
                                    color: "transparent"
                                    border.width: s(2)
                                    border.color: ThemeBackend.mauve
                                    opacity: tile.highlighted ? 1.0 : 0.0
                                    Behavior on opacity { NumberAnimation { duration: 120 } }
                                }
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
                                color: tile.highlighted ? ThemeBackend.text : ThemeBackend.subtext0
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
}
