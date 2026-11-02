import QtQuick
import QtQuick.Window
import QtQuick.Layouts
import "../"
import "../reusables"

Item {
    id: root

    property var leadingSections: []
    property var widgetCounts: ({})
    property var redactor: null
    property real maxWidth: 0
    property int maxColumns: 6
    default property alias actions: actionsRow.data

    property int currentIndex: -1
    property string query: ""
    property int highlightIndex: 0
    property real anchorX: width / 2

    readonly property bool typing: searchInput.hasFocus
    readonly property bool searching: root.query.trim() !== ""
    readonly property bool panelOpen: root.searching || (root.currentIndex >= 0 && root.currentIndex < root.sections.length)
    property Item glassBackdropItem: dockBlur

    readonly property real controlHeight: s(40)
    readonly property real tileWidth: s(76)
    readonly property real tileSpacing: s(10)
    readonly property real panelPadding: s(16)

    signal leadingItemActivated(string id)

    function s(val) { return Scaler.s(val); }

    readonly property var sections: {
        let types = WidgetRegistry.types;
        let placed = {};
        let out = [];

        for (let sec of root.leadingSections) {
            let items = (sec.items || []).map(it => Object.assign({ kind: "leading", count: 0 }, it));
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
                let key = it.kind + ":" + it.id;
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

    readonly property int columns: {
        let most = 1;
        for (let sec of root.sections) most = Math.max(most, sec.items.length);
        return Math.min(root.maxColumns, most);
    }

    readonly property var panelContent: {
        if (root.searching) {
            return { title: I18n.t("widgets.redactor.results", "Results"), icon: String.fromCodePoint(0xF0349), index: -1, items: root.results };
        }
        let sec = root.sections[root.currentIndex];
        return sec ? { title: sec.name, icon: sec.icon, index: root.currentIndex, items: sec.items } : { title: "", icon: "", index: -1, items: [] };
    }

    property var shown: ({ title: "", icon: "", index: -1, items: [] })

    Binding {
        target: root
        property: "shown"
        value: root.panelContent
        when: root.panelOpen
        restoreMode: Binding.RestoreNone
    }

    function countFor(entry) {
        if (!entry) return 0;
        if (entry.kind === "leading") return entry.count || 0;
        return root.widgetCounts[entry.id] || 0;
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

    implicitHeight: s(72)
    implicitWidth: {
        let natural = dockRow.implicitWidth + s(32);
        return root.maxWidth > 0 ? Math.min(root.maxWidth, natural) : natural;
    }
    width: implicitWidth
    height: implicitHeight

    onVisibleChanged: if (!visible) root.close()
    onSectionsChanged: if (root.currentIndex >= root.sections.length) root.currentIndex = -1
    onQueryChanged: root.highlightIndex = 0

    component KeyCap: Rectangle {
        id: cap
        property string label: ""
        property bool iconic: false
        implicitWidth: Math.max(implicitHeight, capText.implicitWidth + Scaler.s(10))
        implicitHeight: Scaler.s(18)
        radius: Scaler.s(5)
        color: "transparent"
        border.width: 1
        border.color: Qt.alpha(ThemeBackend.subtext0, 0.4)

        Text {
            id: capText
            anchors.centerIn: parent
            text: cap.label
            font.family: cap.iconic ? ThemeBackend.iconFont : ThemeBackend.fontFamily
            font.pixelSize: cap.iconic ? Scaler.s(12) : Scaler.s(10)
            font.bold: true
            color: ThemeBackend.subtext0
        }
    }

    Shortcut {
        sequence: "Ctrl+F"
        enabled: root.visible
        onActivated: root.focusSearch()
    }

    Shortcut {
        sequence: "Down"
        enabled: root.visible && root.typing && root.results.length > 0
        onActivated: root.moveHighlight(root.columns, false)
    }

    Shortcut {
        sequence: "Up"
        enabled: root.visible && root.typing && root.results.length > 0
        onActivated: root.moveHighlight(-root.columns, false)
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
        anchors.leftMargin: s(16)
        anchors.rightMargin: s(16)
        spacing: s(12)

        Input {
            id: searchInput
            Layout.preferredWidth: s(200)
            Layout.preferredHeight: root.controlHeight
            Layout.alignment: Qt.AlignVCenter
            placeholderText: I18n.t("widgets.redactor.search", "Search widgets")
            leadingIcon: String.fromCodePoint(0xF0349)
            baseColor: ThemeBackend.surface0
            accentColor: ThemeBackend.mauve
            textColor: ThemeBackend.text
            subTextColor: ThemeBackend.subtext0
            borderColor: Qt.alpha(ThemeBackend.surface2, 0.6)
            cornerRadius: ThemeBackend.borderRadius
            fontPixelSize: s(14)
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

        Rectangle {
            Layout.preferredWidth: 1
            Layout.preferredHeight: s(24)
            Layout.alignment: Qt.AlignVCenter
            color: Qt.alpha(ThemeBackend.text, 0.15)
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
                    spacing: s(8)

                    Repeater {
                        id: chipRepeater
                        model: root.sections

                        ClickButton {
                            id: chip
                            required property var modelData
                            required property int index
                            readonly property bool current: !root.searching && root.currentIndex === index

                            implicitHeight: root.controlHeight
                            horizontalPadding: s(14)
                            cornerRadius: ThemeBackend.borderRadius
                            buttonIcon: chip.modelData.icon || ""
                            iconFontSize: s(18)
                            buttonText: chip.modelData.name || ""
                            textFontSize: s(14)
                            accentColor: chip.current ? ThemeBackend.mauve : ThemeBackend.surface0
                            textColor: chip.current ? ThemeBackend.crust : ThemeBackend.text
                            onClicked: root.toggleSection(chip.index)
                        }
                    }
                }
            }

            IconButton {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                size: s(28)
                cornerRadius: ThemeBackend.borderRadius
                buttonIcon: String.fromCodePoint(0xF0141)
                iconFontSize: s(16)
                accentColor: ThemeBackend.surface1
                textColor: ThemeBackend.text
                visible: chipFlick.interactive && chipFlick.contentX > 1
                onClicked: root.scrollChipsTo(chipFlick.contentX - chipFlick.width * 0.6)
            }

            IconButton {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                size: s(28)
                cornerRadius: ThemeBackend.borderRadius
                buttonIcon: String.fromCodePoint(0xF0142)
                iconFontSize: s(16)
                accentColor: ThemeBackend.surface1
                textColor: ThemeBackend.text
                visible: chipFlick.interactive && chipFlick.contentX < chipFlick.contentWidth - chipFlick.width - 1
                onClicked: root.scrollChipsTo(chipFlick.contentX + chipFlick.width * 0.6)
            }
        }

        Rectangle {
            Layout.preferredWidth: 1
            Layout.preferredHeight: s(24)
            Layout.alignment: Qt.AlignVCenter
            color: Qt.alpha(ThemeBackend.text, 0.15)
            visible: actionsRow.visibleChildren.length > 0
        }

        RowLayout {
            id: actionsRow
            Layout.alignment: Qt.AlignVCenter
            spacing: s(10)
        }
    }

    Component {
        id: defaultTile

        Item {
            id: tile
            property var entry: null
            property bool highlighted: false
            readonly property int count: root.countFor(tile.entry)

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
                    buttonIcon: tile.entry ? tile.entry.icon : ""
                    iconFontSize: s(22)
                    accentColor: ThemeBackend.surface0
                    textColor: ThemeBackend.text
                    onClicked: root.activate(tile.entry)

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

                    Rectangle {
                        visible: tile.count > 0
                        anchors.top: parent.top
                        anchors.right: parent.right
                        anchors.topMargin: -s(6)
                        anchors.rightMargin: -s(6)
                        width: Math.max(height, badgeText.implicitWidth + s(10))
                        height: s(20)
                        radius: height / 2
                        color: ThemeBackend.mauve
                        border.width: s(2)
                        border.color: ThemeBackend.base

                        Text {
                            id: badgeText
                            anchors.centerIn: parent
                            text: tile.count
                            font.family: ThemeBackend.fontFamily
                            font.pixelSize: s(10)
                            font.bold: true
                            color: ThemeBackend.crust
                        }
                    }
                }

                Text {
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignHCenter
                    text: tile.entry ? tile.entry.name : ""
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

    Item {
        id: panel
        property Item glassBackdropItem: panelBlur

        readonly property real naturalWidth: root.columns * root.tileWidth + (root.columns - 1) * root.tileSpacing + root.panelPadding * 2
        readonly property real windowX: {
            root.x; root.width;
            let win = root.Window.window;
            return win ? root.mapToItem(null, 0, 0).x : 0;
        }
        readonly property real windowWidth: root.Window.window ? root.Window.width : root.width

        width: Math.max(s(220), naturalWidth)
        height: panelCol.implicitHeight + root.panelPadding * 2
        x: {
            let margin = s(8);
            let minX = margin - panel.windowX;
            let maxX = panel.windowWidth - panel.windowX - panel.width - margin;
            return Math.round(Math.max(minX, Math.min(maxX, root.anchorX - panel.width / 2)));
        }
        anchors.bottom: parent.top
        anchors.bottomMargin: s(12)
        transformOrigin: Item.Bottom

        opacity: root.panelOpen ? 1.0 : 0.0
        scale: root.panelOpen ? 1.0 : 0.96
        visible: opacity > 0
        enabled: root.panelOpen
        Behavior on x { enabled: root.panelOpen; NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
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
            spacing: s(14)

            RowLayout {
                Layout.fillWidth: true
                spacing: s(8)

                Text {
                    Layout.alignment: Qt.AlignVCenter
                    text: root.shown.icon
                    font.family: ThemeBackend.iconFont
                    font.pixelSize: s(16)
                    color: ThemeBackend.mauve
                }

                Text {
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignVCenter
                    text: root.shown.title
                    elide: Text.ElideRight
                    font.family: ThemeBackend.fontFamily
                    font.pixelSize: s(13)
                    font.bold: true
                    color: ThemeBackend.text
                }

                KeyCap {
                    Layout.alignment: Qt.AlignVCenter
                    visible: root.shown.index >= 0 && root.shown.index < 9
                    label: String(root.shown.index + 1)
                }

                KeyCap {
                    Layout.alignment: Qt.AlignVCenter
                    visible: root.shown.index < 0 && root.shown.items.length > 0
                    iconic: true
                    label: String.fromCodePoint(0xF0311)
                }
            }

            Text {
                visible: root.shown.items.length === 0
                Layout.fillWidth: true
                Layout.preferredHeight: s(70)
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                text: I18n.t("widgets.redactor.no_results", "Nothing found")
                font.family: ThemeBackend.fontFamily
                font.pixelSize: s(13)
                color: ThemeBackend.subtext0
            }

            GridLayout {
                visible: root.shown.items.length > 0
                Layout.alignment: Qt.AlignHCenter
                columns: root.columns
                rowSpacing: s(12)
                columnSpacing: root.tileSpacing

                Repeater {
                    model: root.shown.items

                    Item {
                        id: tileSlot
                        required property var modelData
                        required property int index
                        readonly property bool custom: modelData.kind === "widget" && !!(WidgetRegistry.types[modelData.id] && WidgetRegistry.types[modelData.id].toolbarComponent)
                        readonly property bool highlighted: root.searching && root.shown.index < 0 && index === root.highlightIndex

                        Layout.alignment: Qt.AlignTop
                        Layout.preferredWidth: root.tileWidth
                        Layout.preferredHeight: tileLoader.item ? tileLoader.item.implicitHeight : 0

                        Loader {
                            id: tileLoader
                            anchors.horizontalCenter: parent.horizontalCenter
                            sourceComponent: tileSlot.custom ? WidgetRegistry.toolbarComponent(tileSlot.modelData.id) : defaultTile

                            onLoaded: {
                                if (!item) return;
                                if (tileSlot.custom) {
                                    item.typeData = Object.assign({ id: tileSlot.modelData.id }, WidgetRegistry.types[tileSlot.modelData.id]);
                                    item.redactor = root.redactor;
                                } else {
                                    item.entry = tileSlot.modelData;
                                }
                            }

                            Binding {
                                when: !tileSlot.custom && tileLoader.item !== null
                                target: tileLoader.item
                                property: "highlighted"
                                value: tileSlot.highlighted
                            }
                        }
                    }
                }
            }
        }
    }
}
