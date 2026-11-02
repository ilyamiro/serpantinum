import QtQuick
import QtQuick.Window
import QtQuick.Layouts
import "../"
import "../reusables"

Item {
    id: root

    property var categories: []
    property var leadingSections: []
    property var widgetCounts: ({})
    property var redactor: null
    property real maxWidth: 0
    property int maxColumns: 6
    default property alias actions: actionsRow.data

    property int currentIndex: -1
    property string query: ""

    readonly property bool typing: searchInput.hasFocus
    readonly property bool panelOpen: root.query.trim() !== "" || (root.currentIndex >= 0 && root.currentIndex < root.sections.length)
    property Item glassBackdropItem: dockBlur

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

        for (let cat of root.categories) {
            let items = [];
            for (let id of (cat.types || [])) {
                if (!types[id] || placed[id]) continue;
                placed[id] = true;
                items.push(widgetItem(id));
            }
            if (items.length > 0) out.push({ id: cat.id, name: cat.name, icon: cat.icon, items: items });
        }

        let rest = Object.keys(types).filter(id => !placed[id]).map(widgetItem);
        if (rest.length > 0) {
            out.push({
                id: "other",
                name: I18n.t("widgets.redactor.category.other", "Other"),
                icon: String.fromCodePoint(0xF0431),
                items: rest
            });
        }
        return out;
    }

    readonly property var results: {
        let q = root.query.trim().toLowerCase();
        if (q === "") return [];
        let seen = {};
        let out = [];
        for (let sec of root.sections) {
            let sectionHit = String(sec.name || "").toLowerCase().includes(q);
            for (let it of sec.items) {
                let key = it.kind + ":" + it.id;
                if (seen[key]) continue;
                if (sectionHit || String(it.name || "").toLowerCase().includes(q) || String(it.id).toLowerCase().includes(q)) {
                    seen[key] = true;
                    out.push(it);
                }
            }
        }
        return out;
    }

    readonly property var panelContent: {
        if (root.query.trim() !== "") {
            return { title: I18n.t("widgets.redactor.results", "Results"), icon: String.fromCodePoint(0xF0349), items: root.results };
        }
        let sec = root.sections[root.currentIndex];
        return sec ? { title: sec.name, icon: sec.icon, items: sec.items } : { title: "", icon: "", items: [] };
    }

    property var shown: ({ title: "", icon: "", items: [] })

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

    function toggleSection(index) {
        if (root.query !== "") searchInput.clear();
        root.currentIndex = root.currentIndex === index ? -1 : index;
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

    function playClick() {
        if (typeof Sounds !== "undefined") Sounds.playSfx("reusables/iconbutton/click.wav");
    }

    implicitHeight: s(72)
    implicitWidth: {
        let natural = dockRow.implicitWidth + s(28);
        return root.maxWidth > 0 ? Math.min(root.maxWidth, natural) : natural;
    }
    width: implicitWidth
    height: implicitHeight

    onVisibleChanged: if (!visible) root.close()
    onSectionsChanged: if (root.currentIndex >= root.sections.length) root.currentIndex = -1

    Shortcut {
        sequence: "Ctrl+F"
        enabled: root.visible
        onActivated: root.focusSearch()
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
        anchors.leftMargin: s(14)
        anchors.rightMargin: s(14)
        spacing: s(12)

        Input {
            id: searchInput
            Layout.preferredWidth: s(180)
            Layout.preferredHeight: s(40)
            Layout.alignment: Qt.AlignVCenter
            placeholderText: I18n.t("widgets.redactor.search", "Search widgets")
            leadingIcon: String.fromCodePoint(0xF0349)
            baseColor: ThemeBackend.surface0
            bgOpacity: ThemeBackend.glassActive ? 0.0 : 1.0
            accentColor: ThemeBackend.mauve
            textColor: ThemeBackend.text
            subTextColor: ThemeBackend.subtext0
            borderColor: Qt.alpha(ThemeBackend.surface2, 0.6)
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
                if (root.results.length > 0) root.activate(root.results[0]);
            }
        }

        Rectangle {
            Layout.preferredWidth: 1
            Layout.preferredHeight: s(36)
            Layout.alignment: Qt.AlignVCenter
            color: Qt.alpha(ThemeBackend.text, 0.15)
        }

        Flickable {
            id: chipFlick
            Layout.fillWidth: true
            Layout.preferredWidth: chipRow.implicitWidth
            Layout.minimumWidth: s(48)
            Layout.preferredHeight: s(44)
            Layout.alignment: Qt.AlignVCenter
            contentWidth: chipRow.implicitWidth
            contentHeight: height
            clip: contentWidth > width
            interactive: contentWidth > width
            flickableDirection: Flickable.HorizontalFlick
            boundsBehavior: Flickable.StopAtBounds

            WheelHandler {
                enabled: chipFlick.interactive
                onWheel: (event) => {
                    let delta = event.angleDelta.x !== 0 ? event.angleDelta.x : event.angleDelta.y;
                    chipFlick.contentX = Math.max(0, Math.min(chipFlick.contentWidth - chipFlick.width, chipFlick.contentX - delta));
                }
            }

            Row {
                id: chipRow
                height: chipFlick.height
                spacing: s(8)

                Repeater {
                    model: root.sections

                    Item {
                        id: chip
                        required property var modelData
                        required property int index
                        readonly property bool current: root.query.trim() === "" && root.currentIndex === index
                        readonly property bool hovered: chipMa.containsMouse
                        readonly property color fg: chip.current && !ThemeBackend.liquidGlass ? ThemeBackend.crust : ThemeBackend.text

                        width: chipContent.implicitWidth + s(28)
                        height: chipRow.height

                        Rectangle {
                            anchors.fill: parent
                            radius: ThemeBackend.borderRadius
                            color: chipGlass.active ? "transparent" : (chip.current ? ThemeBackend.mauve : (chip.hovered ? Qt.lighter(ThemeBackend.surface0, 1.12) : ThemeBackend.surface0))
                            Behavior on color { ColorAnimation { duration: 150 } }

                            GlassFill {
                                id: chipGlass
                                anchors.fill: parent
                                radius: parent.radius
                                tintColor: chip.current ? ThemeBackend.mauve : ThemeBackend.surface0
                                tintAmount: chip.current ? 0.55 : (chip.hovered ? 0.42 : 0.3)
                                Behavior on tintAmount { NumberAnimation { duration: 150 } }
                            }
                        }

                        Row {
                            id: chipContent
                            anchors.centerIn: parent
                            spacing: s(8)

                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: chip.modelData.icon || ""
                                font.family: ThemeBackend.iconFont
                                font.pixelSize: s(18)
                                color: chip.fg
                            }

                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: chip.modelData.name || ""
                                font.family: ThemeBackend.fontFamily
                                font.pixelSize: s(13)
                                font.bold: true
                                color: chip.fg
                            }
                        }

                        MouseArea {
                            id: chipMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                root.playClick();
                                root.toggleSection(chip.index);
                            }
                        }
                    }
                }
            }
        }

        Rectangle {
            Layout.preferredWidth: 1
            Layout.preferredHeight: s(36)
            Layout.alignment: Qt.AlignVCenter
            color: Qt.alpha(ThemeBackend.text, 0.15)
            visible: actionsRow.children.length > 0
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
            readonly property int count: root.countFor(tile.entry)
            readonly property bool primary: !!tile.entry && root.query.trim() !== "" && root.results.length > 0 && root.results[0].kind === tile.entry.kind && root.results[0].id === tile.entry.id

            implicitWidth: s(76)
            implicitHeight: tileCol.implicitHeight

            ColumnLayout {
                id: tileCol
                anchors.left: parent.left
                anchors.right: parent.right
                spacing: s(6)

                IconButton {
                    id: tileBtn
                    Layout.alignment: Qt.AlignHCenter
                    size: s(48)
                    cornerRadius: ThemeBackend.borderRadius
                    buttonIcon: tile.entry ? tile.entry.icon : ""
                    iconFontSize: s(22)
                    accentColor: ThemeBackend.surface0
                    textColor: ThemeBackend.text
                    action_highlight: tile.primary
                    onClicked: root.activate(tile.entry)

                    Rectangle {
                        visible: tile.count > 0
                        anchors.top: parent.top
                        anchors.right: parent.right
                        anchors.topMargin: -s(5)
                        anchors.rightMargin: -s(5)
                        width: Math.max(height, badgeText.implicitWidth + s(8))
                        height: s(18)
                        radius: height / 2
                        color: ThemeBackend.mauve

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
                    color: tile.primary ? ThemeBackend.text : ThemeBackend.subtext0
                }
            }
        }
    }

    Item {
        id: panel
        property Item glassBackdropItem: panelBlur

        readonly property int columns: Math.max(1, Math.min(root.maxColumns, root.shown.items.length))

        width: Math.max(s(220), panelCol.implicitWidth + s(32))
        height: panelCol.implicitHeight + s(28)
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.top
        anchors.bottomMargin: s(12)
        transformOrigin: Item.Bottom

        opacity: root.panelOpen ? 1.0 : 0.0
        scale: root.panelOpen ? 1.0 : 0.96
        visible: opacity > 0
        enabled: root.panelOpen
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
            anchors.top: parent.top
            anchors.topMargin: s(14)
            anchors.horizontalCenter: parent.horizontalCenter
            width: panel.width - s(32)
            spacing: s(12)

            RowLayout {
                Layout.fillWidth: true
                spacing: s(8)

                Text {
                    text: root.shown.icon
                    font.family: ThemeBackend.iconFont
                    font.pixelSize: s(16)
                    color: ThemeBackend.mauve
                }

                Text {
                    Layout.fillWidth: true
                    text: root.shown.title
                    elide: Text.ElideRight
                    font.family: ThemeBackend.fontFamily
                    font.pixelSize: s(13)
                    font.bold: true
                    color: ThemeBackend.text
                }

                Text {
                    visible: root.shown.items.length > 0
                    text: root.shown.items.length
                    font.family: ThemeBackend.fontFamily
                    font.pixelSize: s(11)
                    font.bold: true
                    color: ThemeBackend.subtext0
                }
            }

            Text {
                visible: root.shown.items.length === 0
                Layout.alignment: Qt.AlignHCenter
                Layout.bottomMargin: s(4)
                text: I18n.t("widgets.redactor.no_results", "Nothing found")
                font.family: ThemeBackend.fontFamily
                font.pixelSize: s(12)
                color: ThemeBackend.subtext0
            }

            GridLayout {
                visible: root.shown.items.length > 0
                columns: panel.columns
                rowSpacing: s(12)
                columnSpacing: s(10)

                Repeater {
                    model: root.shown.items

                    Loader {
                        id: tileLoader
                        required property var modelData
                        readonly property bool custom: modelData.kind === "widget" && !!(WidgetRegistry.types[modelData.id] && WidgetRegistry.types[modelData.id].toolbarComponent)

                        Layout.alignment: Qt.AlignTop | Qt.AlignHCenter
                        sourceComponent: tileLoader.custom ? WidgetRegistry.toolbarComponent(modelData.id) : defaultTile

                        onLoaded: {
                            if (!item) return;
                            if (tileLoader.custom) {
                                item.typeData = Object.assign({ id: tileLoader.modelData.id }, WidgetRegistry.types[tileLoader.modelData.id]);
                                item.redactor = root.redactor;
                            } else {
                                item.entry = tileLoader.modelData;
                            }
                        }
                    }
                }
            }
        }
    }
}
