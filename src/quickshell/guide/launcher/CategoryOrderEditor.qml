import QtQuick
import QtQuick.Layouts
import "../../"
import "../../reusables"
import "../../launcher/Categories.js" as Categories

Item {
    id: root

    required property var rootObj

    property var hiddenIds: []
    property string draggedId: ""
    property int placeholderIndex: -1

    signal orderChanged(var order)
    signal hiddenToggled(string catId, bool hidden)

    implicitHeight: flow.childrenRect.height + rootObj.s(8)
    Layout.fillWidth: true

    function s(val) {
        return rootObj.s(val);
    }

    function categoryLabel(id) {
        let def = Categories.get(id);
        let fallback = def ? def.label : id;
        if (typeof I18n === "undefined") return fallback;
        let key = "applauncher.category." + id.toLowerCase();
        let value = I18n.t(key);
        return (value && value !== key) ? value : fallback;
    }

    ListModel { id: chipsModel }

    function load(order, hidden) {
        hiddenIds = hidden ? hidden.slice() : [];
        chipsModel.clear();
        for (let i = 0; i < order.length; i++) {
            let id = order[i];
            if (!Categories.get(id)) continue;
            chipsModel.append({
                catId: id,
                hidden: id !== Categories.ALL_ID && hiddenIds.indexOf(id) !== -1,
                isPlaceholder: false,
                placeholderWidth: 0
            });
        }
    }

    function currentOrder() {
        let result = [];
        for (let i = 0; i < chipsModel.count; i++) {
            let item = chipsModel.get(i);
            if (!item.isPlaceholder) result.push(item.catId);
        }
        return result;
    }

    function clearPlaceholder() {
        for (let i = chipsModel.count - 1; i >= 0; i--) {
            if (chipsModel.get(i).isPlaceholder) chipsModel.remove(i);
        }
        placeholderIndex = -1;
    }

    function updatePlaceholder(index, width) {
        if (index < 0) return;
        if (placeholderIndex === index) {
            for (let i = 0; i < chipsModel.count; i++) {
                if (chipsModel.get(i).isPlaceholder) {
                    chipsModel.setProperty(i, "placeholderWidth", width);
                    break;
                }
            }
            return;
        }

        clearPlaceholder();

        let sourceIndex = -1;
        for (let i = 0; i < chipsModel.count; i++) {
            let item = chipsModel.get(i);
            if (!item.isPlaceholder && item.catId === draggedId) {
                sourceIndex = i;
                break;
            }
        }

        let rawIndex = index;
        if (sourceIndex !== -1 && index >= sourceIndex) rawIndex = index + 1;
        rawIndex = Math.max(0, Math.min(rawIndex, chipsModel.count));
        chipsModel.insert(rawIndex, {
            catId: "",
            hidden: false,
            isPlaceholder: true,
            placeholderWidth: width
        });
        placeholderIndex = index;
    }

    function executeDrop() {
        let target = placeholderIndex;
        let id = draggedId;
        clearPlaceholder();
        if (id === "" || target < 0) return;

        let order = currentOrder();
        let from = order.indexOf(id);
        if (from === -1) return;
        order.splice(from, 1);
        target = Math.max(0, Math.min(target, order.length));
        order.splice(target, 0, id);

        root.orderChanged(order);
        Qt.callLater(function() {
            root.load(order, root.hiddenIds);
        });
    }

    function toggleHidden(catId) {
        if (catId === Categories.ALL_ID) return;
        for (let i = 0; i < chipsModel.count; i++) {
            let item = chipsModel.get(i);
            if (item.isPlaceholder || item.catId !== catId) continue;
            let next = !item.hidden;
            chipsModel.setProperty(i, "hidden", next);
            let hidden = root.hiddenIds.slice();
            let index = hidden.indexOf(catId);
            if (next && index === -1) hidden.push(catId);
            else if (!next && index !== -1) hidden.splice(index, 1);
            root.hiddenIds = hidden;
            root.hiddenToggled(catId, next);
            return;
        }
    }

    function getDropIndex(flow, mx, my) {
        let count = 0;
        let phIndex = -1;
        let phWidth = 0;
        let hasPlaceholder = false;

        for (let i = 0; i < flow.children.length; i++) {
            let child = flow.children[i];
            if (child.isChip && child.isPlaceholder) {
                hasPlaceholder = true;
                phWidth = child.width;
                phIndex = count;
                break;
            }
            if (child.isChip && !child.isBeingDragged) count++;
        }

        count = 0;
        let target = 0;
        let found = false;
        for (let i = 0; i < flow.children.length; i++) {
            let child = flow.children[i];
            if (child.isChip && !child.isBeingDragged && !child.isPlaceholder) {
                let unshiftedX = child.x;
                if (hasPlaceholder && count >= phIndex) {
                    unshiftedX -= (phWidth + flow.spacing);
                }
                let centerX = unshiftedX + child.width / 2;
                let centerY = child.y + child.height / 2;

                if (!found) {
                    if (Math.abs(my - centerY) < child.height / 2 + flow.spacing / 2) {
                        if (mx < centerX) {
                            target = count;
                            found = true;
                        }
                    } else if (my < child.y) {
                        target = count;
                        found = true;
                    }
                }
                count++;
            }
        }
        if (!found) target = count;
        return target;
    }

    Flow {
        id: flow
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        height: childrenRect.height
        spacing: root.s(6)

        Repeater {
            model: chipsModel

            delegate: Rectangle {
                id: chip

                required property int index
                required property string catId
                required property bool hidden
                required property bool isPlaceholder
                required property real placeholderWidth

                property bool isChip: true
                readonly property var definition: Categories.get(catId)
                readonly property bool isBeingDragged: dragArea.drag.active
                readonly property bool isAll: catId === Categories.ALL_ID
                readonly property real chipWidth: contentRow.implicitWidth + root.s(18)

                width: isPlaceholder ? placeholderWidth : (isBeingDragged ? 0 : chipWidth)
                height: root.s(30)
                visible: isPlaceholder || !isBeingDragged
                radius: root.s(6)
                color: isPlaceholder ? "transparent" : (ThemeBackend.liquidGlass ? "transparent" : (hidden ? Qt.alpha(ThemeBackend.surface1, 0.35) : ThemeBackend.surface1))
                border.width: isPlaceholder ? 1 : 0
                border.color: ThemeBackend.subtext0

                Rectangle {
                    anchors.fill: parent
                    visible: chip.isPlaceholder
                    radius: parent.radius
                    color: ThemeBackend.subtext0
                    opacity: 0.15
                }

                Item {
                    id: floatWrapper
                    anchors.fill: !dragArea.drag.active ? parent : undefined
                    visible: !chip.isPlaceholder
                    z: dragArea.drag.active ? 100 : 0

                    Drag.active: dragArea.drag.active
                    Drag.source: chip
                    Drag.hotSpot.x: width / 2
                    Drag.hotSpot.y: height / 2

                    states: [
                        State {
                            when: dragArea.drag.active
                            ParentChange {
                                target: floatWrapper
                                parent: root
                            }
                            PropertyChanges {
                                target: floatWrapper
                                width: chip.chipWidth
                                height: root.s(30)
                                opacity: 0.9
                                scale: 1.05
                                z: 100
                            }
                        }
                    ]

                    Rectangle {
                        anchors.fill: parent
                        radius: chip.radius
                        color: chipGlass.active ? "transparent" : chip.color
                        border.width: 0

                        GlassFill {
                            id: chipGlass
                            anchors.fill: parent
                            radius: parent.radius
                            shadow: 1
                            press: dragArea.drag.active ? 1.0 : (dragArea.containsMouse ? 0.2 : 0.0)
                            tintColor: ThemeBackend.surface1
                            tintAmount: chip.hidden
                                ? 0.12
                                : (dragArea.drag.active ? 0.52 : (dragArea.containsMouse ? 0.38 : 0.28))
                            Behavior on tintAmount { NumberAnimation { duration: 160 } }
                        }
                    }

                    MouseArea {
                        id: dragArea
                        anchors.fill: parent
                        acceptedButtons: Qt.LeftButton
                        cursorShape: dragArea.drag.active ? Qt.ClosedHandCursor : Qt.OpenHandCursor
                        drag.target: floatWrapper

                        onPressed: {
                            root.clearPlaceholder();
                            root.draggedId = chip.catId;
                            if (typeof Sounds !== "undefined") {
                                Sounds.playSfx("guide/barconfig/out.wav");
                            }
                        }

                        onReleased: {
                            if (typeof Sounds !== "undefined") {
                                Sounds.playSfx("guide/barconfig/in.wav");
                            }
                            floatWrapper.Drag.drop();
                            if (root.placeholderIndex >= 0) {
                                root.executeDrop();
                            } else {
                                root.clearPlaceholder();
                            }
                            root.draggedId = "";
                            floatWrapper.x = 0;
                            floatWrapper.y = 0;
                        }
                    }

                    Row {
                        id: contentRow
                        anchors.centerIn: parent
                        spacing: root.s(5)
                        z: 1

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: "󰇙"
                            font.family: ThemeBackend.iconFont
                            font.pixelSize: root.s(11)
                            color: ThemeBackend.subtext0
                            opacity: 0.6
                        }

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: chip.definition ? chip.definition.icon : ""
                            font.family: ThemeBackend.iconFont
                            font.pixelSize: root.s(13)
                            color: chip.hidden ? ThemeBackend.subtext0 : ThemeBackend.text
                        }

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: chip.definition ? root.categoryLabel(chip.catId) : ""
                            font.family: ThemeBackend.fontFamily
                            font.pixelSize: root.s(11)
                            color: chip.hidden ? ThemeBackend.subtext0 : ThemeBackend.text
                        }

                        Item {
                            anchors.verticalCenter: parent.verticalCenter
                            visible: !chip.isAll
                            width: root.s(18)
                            height: root.s(18)

                            Text {
                                anchors.centerIn: parent
                                text: chip.hidden ? "󰈉" : "󰈈"
                                font.family: ThemeBackend.iconFont
                                font.pixelSize: root.s(12)
                                color: eyeMa.containsMouse
                                    ? (chip.hidden ? ThemeBackend.mauve : ThemeBackend.text)
                                    : ThemeBackend.subtext0
                                Behavior on color { ColorAnimation { duration: 120 } }
                            }

                            MouseArea {
                                id: eyeMa
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.toggleHidden(chip.catId)
                            }
                        }
                    }
                }
            }
        }
    }

    DropArea {
        anchors.fill: parent
        onPositionChanged: function(drag) {
            if (root.draggedId === "") return;
            let index = root.getDropIndex(flow, drag.x - flow.x, drag.y - flow.y);
            root.updatePlaceholder(index, drag.source ? drag.source.chipWidth : root.s(80));
        }
        onExited: root.clearPlaceholder()
    }
}
