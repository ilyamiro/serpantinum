import QtQuick
import QtQuick.Layouts
import "../../"
import "../"

Item {
    id: editor

    required property var rootObj
    property var items: []
    property var lists: []
    property int columns: Math.max(1, lists.length)
    property real boxRadius: ThemeBackend.clampedBorderRadius

    signal edited(var result)

    property string placeholderKey: ""
    property int placeholderIndex: -1
    property var boxes: ({})

    Layout.fillWidth: true
    implicitHeight: grid.implicitHeight

    function itemInfo(id) {
        for (let i = 0; i < items.length; i++) {
            if (items[i].id === id) return items[i];
        }
        return null;
    }

    function idsFor(spec) {
        if (Array.isArray(spec.ids)) return spec.ids.filter(id => itemInfo(id) !== null);
        let taken = {};
        for (let i = 0; i < lists.length; i++) {
            if (Array.isArray(lists[i].ids)) {
                for (let j = 0; j < lists[i].ids.length; j++) taken[lists[i].ids[j]] = true;
            }
        }
        return items.filter(it => !taken[it.id]).map(it => it.id);
    }

    function modelFor(key) {
        let box = boxes[key];
        return box ? box.chipModel : null;
    }

    function validCount(model) {
        let n = 0;
        for (let i = 0; i < model.count; i++) {
            if (!model.get(i).isPlaceholder) n++;
        }
        return n;
    }

    function canMove(fromKey, toKey) {
        if (fromKey === toKey) return true;
        let box = boxes[fromKey];
        if (!box) return false;
        let min = box.spec.minCount || 0;
        return validCount(box.chipModel) - 1 >= min;
    }

    function clearPlaceholders() {
        let keys = Object.keys(boxes);
        for (let k = 0; k < keys.length; k++) {
            let model = boxes[keys[k]].chipModel;
            for (let i = model.count - 1; i >= 0; i--) {
                if (model.get(i).isPlaceholder) model.remove(i, 1);
            }
        }
    }

    function resetPlaceholder() {
        clearPlaceholders();
        placeholderKey = "";
        placeholderIndex = -1;
    }

    function updatePlaceholder(key, index, source) {
        if (placeholderKey === key && placeholderIndex === index) return;
        clearPlaceholders();
        let model = modelFor(key);
        if (!model) return;
        let rawIndex = index;
        if (key === source.listKey) {
            for (let i = 0; i < model.count; i++) {
                let it = model.get(i);
                if (!it.isPlaceholder && it.chipId === source.chipId) {
                    if (index >= i) rawIndex = index + 1;
                    break;
                }
            }
        }
        rawIndex = Math.max(0, Math.min(rawIndex, model.count));
        model.insert(rawIndex, { chipId: source.chipId, isPlaceholder: true, placeholderWidth: source.btnWidth });
        placeholderKey = key;
        placeholderIndex = index;
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
                if (hasPlaceholder && count >= phIndex) unshiftedX -= (phWidth + flow.spacing);
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

    function executeDrop(source) {
        let toKey = placeholderKey;
        let toIdx = placeholderIndex;
        clearPlaceholders();
        placeholderKey = "";
        placeholderIndex = -1;
        if (toKey === "") return;

        let fromModel = modelFor(source.listKey);
        let toModel = modelFor(toKey);
        if (!fromModel || !toModel) return;

        for (let i = 0; i < fromModel.count; i++) {
            let it = fromModel.get(i);
            if (!it.isPlaceholder && it.chipId === source.chipId) {
                fromModel.remove(i, 1);
                break;
            }
        }
        toIdx = Math.max(0, Math.min(toIdx, toModel.count));
        toModel.insert(toIdx, { chipId: source.chipId, isPlaceholder: false, placeholderWidth: 0 });

        let result = {};
        let keys = Object.keys(boxes);
        for (let k = 0; k < keys.length; k++) {
            let model = boxes[keys[k]].chipModel;
            let ids = [];
            for (let i = 0; i < model.count; i++) ids.push(model.get(i).chipId);
            result[keys[k]] = ids;
        }
        editor.edited(result);
    }

    GridLayout {
        id: grid
        anchors.left: parent.left
        anchors.right: parent.right
        columns: editor.columns
        columnSpacing: editor.rootObj.s(10)
        rowSpacing: editor.rootObj.s(10)

        Repeater {
            model: editor.lists.length

            delegate: Rectangle {
                id: box
                required property int index
                readonly property var spec: editor.lists[index] || ({})
                readonly property string key: spec.key || ""
                property alias chipModel: chipModel

                Layout.fillWidth: true
                Layout.preferredWidth: 1
                Layout.fillHeight: true
                implicitHeight: Math.max(editor.rootObj.s(68), titleText.implicitHeight + flowList.implicitHeight + editor.rootObj.s(30))
                color: boxGlass.active ? "transparent" : Qt.alpha(ThemeBackend.base, 0.7)
                radius: editor.boxRadius
                clip: true

                ListModel { id: chipModel }

                function load() {
                    if (editor.placeholderKey !== "") return;
                    chipModel.clear();
                    let ids = editor.idsFor(box.spec);
                    for (let i = 0; i < ids.length; i++) {
                        chipModel.append({ chipId: ids[i], isPlaceholder: false, placeholderWidth: 0 });
                    }
                }

                onSpecChanged: load()
                Connections {
                    target: editor
                    function onItemsChanged() { box.load(); }
                }

                Component.onCompleted: {
                    let b = Object.assign({}, editor.boxes);
                    b[box.key] = box;
                    editor.boxes = b;
                    load();
                }
                Component.onDestruction: {
                    if (editor.boxes[box.key] !== box) return;
                    let b = Object.assign({}, editor.boxes);
                    delete b[box.key];
                    editor.boxes = b;
                }

                GlassFill {
                    id: boxGlass
                    anchors.fill: parent
                    radius: parent.radius
                    tintColor: ThemeBackend.base
                    tintAmount: 0.25
                }

                Text {
                    id: titleText
                    anchors.top: parent.top
                    anchors.topMargin: editor.rootObj.s(10)
                    anchors.left: parent.left
                    anchors.leftMargin: editor.rootObj.s(12)
                    text: box.spec.title || ""
                    font.family: ThemeBackend.fontFamily
                    font.pixelSize: editor.rootObj.s(11)
                    font.weight: Font.Medium
                    color: ThemeBackend.subtext0
                }

                DropArea {
                    anchors.fill: parent
                    onPositionChanged: function(drag) {
                        let src = drag.source;
                        if (!src || src.ownerEditor !== editor) return;
                        if (!editor.canMove(src.listKey, box.key)) {
                            if (editor.placeholderKey === box.key) editor.resetPlaceholder();
                            return;
                        }
                        let idx = editor.getDropIndex(flowList, drag.x - flowList.x, drag.y - flowList.y);
                        editor.updatePlaceholder(box.key, idx, src);
                    }
                    onExited: {
                        if (editor.placeholderKey === box.key) editor.resetPlaceholder();
                    }
                }

                Flow {
                    id: flowList
                    anchors.top: titleText.bottom
                    anchors.topMargin: editor.rootObj.s(8)
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.leftMargin: editor.rootObj.s(12)
                    anchors.rightMargin: editor.rootObj.s(12)
                    spacing: editor.rootObj.s(8)

                    Repeater {
                        model: chipModel

                        delegate: Item {
                            id: chip
                            required property int index
                            required property string chipId
                            required property bool isPlaceholder
                            required property real placeholderWidth

                            readonly property bool isChip: true
                            readonly property var ownerEditor: editor
                            readonly property string listKey: box.key
                            readonly property var info: editor.itemInfo(chipId) || ({})
                            readonly property bool isBeingDragged: dragArea.drag.active
                            readonly property real btnWidth: btn.implicitWidth

                            implicitWidth: isPlaceholder ? placeholderWidth : btn.implicitWidth
                            implicitHeight: editor.rootObj.s(32)
                            width: isPlaceholder ? placeholderWidth : (isBeingDragged ? 0 : btn.implicitWidth)
                            height: (isPlaceholder || !isBeingDragged) ? editor.rootObj.s(32) : 0
                            visible: isPlaceholder || !isBeingDragged

                            Behavior on width {
                                enabled: !chip.isBeingDragged
                                NumberAnimation { duration: 150; easing.type: Easing.OutQuint }
                            }

                            Rectangle {
                                anchors.fill: parent
                                visible: chip.isPlaceholder
                                color: ThemeBackend.subtext0
                                opacity: 0.15
                                radius: ThemeBackend.borderRadius
                            }

                            Item {
                                id: floatWrapper
                                anchors.fill: !dragArea.drag.active ? parent : undefined
                                visible: !chip.isPlaceholder

                                Drag.active: dragArea.drag.active
                                Drag.source: chip
                                Drag.hotSpot.x: width / 2
                                Drag.hotSpot.y: height / 2

                                states: State {
                                    when: dragArea.drag.active
                                    ParentChange { target: floatWrapper; parent: editor }
                                    PropertyChanges {
                                        target: floatWrapper
                                        width: chip.btnWidth
                                        height: editor.rootObj.s(32)
                                        opacity: 0.9
                                        scale: 1.05
                                    }
                                }

                                ClickButton {
                                    id: btn
                                    anchors.fill: parent
                                    buttonText: chip.info.label || chip.chipId
                                    buttonIcon: chip.info.icon || ""
                                    accentColor: ThemeBackend.surface0
                                    textColor: ThemeBackend.text
                                    cornerRadius: ThemeBackend.borderRadius
                                    horizontalPadding: editor.rootObj.s(12)
                                    iconFontSize: editor.rootObj.s(15)
                                    textFontSize: editor.rootObj.s(12)
                                }

                                MouseArea {
                                    id: dragArea
                                    anchors.fill: parent
                                    drag.target: floatWrapper
                                    cursorShape: Qt.OpenHandCursor
                                    onPressed: {
                                        cursorShape = Qt.ClosedHandCursor;
                                        Sounds.playSfx("guide/barconfig/out.wav");
                                    }
                                    onReleased: {
                                        cursorShape = Qt.OpenHandCursor;
                                        Sounds.playSfx("guide/barconfig/in.wav");
                                        floatWrapper.Drag.drop();
                                        if (editor.placeholderKey !== "") editor.executeDrop(chip);
                                        else editor.clearPlaceholders();
                                        floatWrapper.x = 0;
                                        floatWrapper.y = 0;
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
