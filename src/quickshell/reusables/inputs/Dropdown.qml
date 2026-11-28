import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import "../../"
import "../"

Item {
    id: root

    activeFocusOnTab: root.enabled
    Keys.onPressed: (event) => {
        if (event.key === Qt.Key_Space || event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
            if (!root.isOpen) root.openPopup();
            event.accepted = true;
        }
    }
    implicitWidth: 160
    implicitHeight: 32

    property var options: []
    property int currentIndex: 0
    readonly property string currentValue: currentIndex >= 0 && currentIndex < options.length ? options[currentIndex] : ""
    property string placeholderText: I18n.t("common.select")
    property string fontFamily: ThemeBackend.fontFamily
    property bool useOptionAsFontFamily: false

    property bool fuzzySearch: true
    property bool isPathSelector: false
    property bool allowCustomValue: isPathSelector

    property color accentColor: ThemeBackend.blue
    property color baseColor: ThemeBackend.surface0
    property color hoverColor: Qt.lighter(baseColor, 1.2)
    property color dropdownColor: ThemeBackend.base
    property color borderColor: ThemeBackend.surface1
    property color textColor: ThemeBackend.text
    property color iconColor: textColor
    property color activeTextColor: ThemeBackend.crust
    property color subTextColor: ThemeBackend.subtext0

    property real cornerRadius: ThemeBackend.clampedBorderRadius
    property int fontPixelSize: 11
    property int iconSize: 16
    property int charSpacing: 1
    property real horizontalPadding: 12

    property bool enabled: true
    property bool action_highlight: false
    property string clickSound: "reusables/dropdown/click.wav"
    property string listSound: "reusables/dropdown/list.wav"
    property string keySound: "reusables/input/type.wav"

    property var filteredOptions: options
    property bool isEditing: false
    property string searchText: ""

    property real flashOpacity: 0.0
    property real popScale: 1.0
    property bool isOpen: false
    property int visibleCount: 0

    readonly property Item glassBackdrop: glass.backdrop
    readonly property real popupPadding: 4
    readonly property bool popupHovered: popupLoader.item !== null && popupLoader.item.listHovered
    property bool isHoveredOrHighlighted: (btnMa.containsMouse || root.action_highlight) && root.enabled
    readonly property real charSlotStep: searchField.charSlotStep
    readonly property real scrollOffset: searchField.scrollOffset

    signal valueChanged(int index, string value)
    signal selected(int index, string value)
    signal clicked()
    signal opened()
    signal closed()
    signal searchChanged(string text)
    signal editingStarted()
    signal customAccepted(string rawText)

    function fuzzyScore(query, text) {
        let q = String(query).toLowerCase();
        let t = String(text).toLowerCase();
        let qLen = q.length;
        let tLen = t.length;
        if (qLen === 0) return 1;
        if (qLen > tLen) return -1;
        let qIdx = 0;
        let score = 0;
        let consecutive = 0;
        let prevMatchedIdx = -1;

        for (let tIdx = 0; tIdx < tLen && qIdx < qLen; tIdx++) {
            if (t[tIdx] === q[qIdx]) {
                score += 10;
                if (prevMatchedIdx === tIdx - 1) {
                    consecutive++;
                    score += consecutive * 5;
                } else {
                    consecutive = 0;
                }
                if (tIdx === 0 || t[tIdx - 1] === '/' || t[tIdx - 1] === '_' || t[tIdx - 1] === '-' || t[tIdx - 1] === ' ' || t[tIdx - 1] === '.') {
                    score += 15;
                }
                prevMatchedIdx = tIdx;
                qIdx++;
            }
        }
        return qIdx === qLen ? score : -1;
    }

    function mergeOptions(newItems) {
        if (!newItems || newItems.length === 0) return;
        let merged = root.options.slice();
        let seen = {};
        for (let i = 0; i < merged.length; i++) {
            seen[merged[i]] = true;
        }
        let changed = false;
        for (let i = 0; i < newItems.length; i++) {
            if (!seen[newItems[i]]) {
                seen[newItems[i]] = true;
                merged.push(newItems[i]);
                changed = true;
            }
        }
        if (changed) {
            root.options = merged;
            root.filterData();
        }
    }

    function selectOrInsertOption(val) {
        if (!val || val === "") return;
        let opts = root.options.slice();
        let idx = opts.indexOf(val);
        if (idx === -1) {
            opts.unshift(val);
            root.options = opts;
            idx = 0;
        }
        if (root.currentIndex !== idx) {
            root.currentIndex = idx;
            root.valueChanged(idx, val);
        }
        root.selected(idx, val);
    }

    Loader {
        id: legacyPathScanner
        active: root.isPathSelector
        visible: false
        width: 0
        height: 0
        source: "PathDropdown.qml"
    }

    function showPopup() {
        popupLoader.active = true;
        if (popupLoader.item) popupLoader.item.open();
    }

    function hidePopup() {
        if (popupLoader.item) popupLoader.item.close();
    }

    function closePopup() {
        root.hidePopup();
    }

    property bool openUpward: false
    property Item boundsItem: null
    property real popupMaxHeight: 250

    function updatePopupDirection() {
        let viewport = root.boundsItem || root.parent;
        while (!root.boundsItem && viewport && !(viewport.contentY !== undefined && viewport.contentHeight !== undefined)) viewport = viewport.parent;
        if (!viewport && root.Window.window) viewport = root.Window.window.contentItem;
        if (!viewport) {
            root.openUpward = false;
            root.popupMaxHeight = 250;
            return;
        }
        let needed = Math.min(root.filteredOptions.length * 34, 250) + root.popupPadding * 2 + 6;
        let fieldTop = root.mapToItem(viewport, 0, 0).y;
        let spaceBelow = viewport.height - (fieldTop + root.height);
        let spaceAbove = fieldTop;
        root.openUpward = spaceBelow < needed && spaceAbove > spaceBelow;
        let available = (root.openUpward ? spaceAbove : spaceBelow) - root.popupPadding * 2 - 12;
        root.popupMaxHeight = Math.max(34, Math.min(250, available));
    }

    function openPopup() {
        if (filteredOptions.length > 0) {
            root.showPopup();
        }
    }

    function startEditing() {
        if (!root.enabled) return;
        root.isEditing = true;
        root.searchText = "";
        searchField.clear();
        root.filterData();
        searchField.forceInputFocus();
        root.editingStarted();
        if (root.isPathSelector && legacyPathScanner.item && root.currentValue) {
            legacyPathScanner.item.scanPathFor(root.currentValue, function(lines) { root.mergeOptions(lines); });
        }
        if (!root.isOpen && root.filteredOptions.length > 0) {
            root.showPopup();
        }
    }

    function stopEditing() {
        root.isEditing = false;
        root.searchText = "";
        searchField.clear();
        root.filteredOptions = root.options;
    }

    function filterData() {
        if (root.searchText === "") {
            root.filteredOptions = root.options.slice();
        } else {
            if (root.fuzzySearch) {
                let matches = [];
                for (let i = 0; i < root.options.length; i++) {
                    let opt = String(root.options[i]);
                    let score = root.fuzzyScore(root.searchText, opt);
                    if (score >= 0) {
                        matches.push({ opt: root.options[i], score: score, index: i });
                    }
                }
                matches.sort(function(a, b) {
                    return b.score - a.score || a.index - b.index;
                });
                root.filteredOptions = matches.map(function(m) { return m.opt; });
            } else {
                let lower = root.searchText.toLowerCase();
                root.filteredOptions = root.options.filter(function(opt) {
                    return String(opt).toLowerCase().indexOf(lower) !== -1;
                });
            }
        }
        if (root.filteredOptions.length === 0) {
            if (root.isOpen) root.hidePopup();
        } else if (root.isEditing && !root.isOpen) {
            root.showPopup();
        }
    }

    function updateScroll() {
        searchField.updateScroll();
    }

    onOptionsChanged: {
        if (!root.isEditing) {
            root.filteredOptions = root.options;
        } else {
            root.filterData();
        }
    }

    Rectangle {
        id: mainBtn
        anchors.fill: parent
        radius: root.cornerRadius
        color: glass.active ? "transparent" : ((root.isOpen || root.isHoveredOrHighlighted) ? root.hoverColor : root.baseColor)
        opacity: root.enabled ? 1.0 : 0.5

        Behavior on color { ColorAnimation { duration: 150 } }
        Behavior on opacity { NumberAnimation { duration: 150 } }

        GlassFill {
            id: glass
            anchors.fill: parent
            radius: parent.radius
            tintColor: (root.isOpen || root.isHoveredOrHighlighted) ? root.hoverColor : root.baseColor
            tintAmount: (root.isOpen || root.isHoveredOrHighlighted) ? 0.36 : 0.26
            press: btnMa.pressed ? 1 : (root.isOpen ? 0.5 : (root.isHoveredOrHighlighted ? 0.2 : 0))
            Behavior on press { NumberAnimation { duration: 250; easing.type: Easing.OutCubic } }
            Behavior on tintAmount { NumberAnimation { duration: 150 } }
        }

        scale: (!root.enabled ? 1.0 : (btnMa.pressed ? 0.96 : 1.0)) * root.popScale
        Behavior on scale { NumberAnimation { duration: 250; easing.type: Easing.OutQuint } }

        RowLayout {
            layoutDirection: I18n.layoutDirection
            anchors.fill: parent
            anchors.leftMargin: root.horizontalPadding
            anchors.rightMargin: root.horizontalPadding
            spacing: 8

            Item {
                id: contentArea
                Layout.fillWidth: true
                Layout.fillHeight: true

                Text {
                    id: displayText
                    anchors.fill: parent
                    visible: !root.isEditing
                    text: root.currentValue !== "" ? root.currentValue : root.placeholderText
                    font.family: root.useOptionAsFontFamily && root.currentValue !== "" ? root.currentValue : root.fontFamily
                    font.pixelSize: root.fontPixelSize
                    color: root.textColor
                    horizontalAlignment: I18n.textAlignment
                    elide: Text.ElideRight
                    verticalAlignment: Text.AlignVCenter
                }

                AnimatedCharField {
                    id: searchField
                    anchors.fill: parent
                    visible: root.isEditing
                    placeholderText: root.placeholderText
                    fontFamily: root.fontFamily
                    fontPixelSize: root.fontPixelSize
                    textColor: root.textColor
                    placeholderColor: root.subTextColor
                    placeholderOpacity: 0.45
                    selectionColor: root.accentColor
                    caretColor: root.accentColor
                    horizontalAlignment: TextInput.AlignLeft
                    charSpacing: root.charSpacing
                    enabled: root.enabled && root.isEditing
                    actionHighlight: root.action_highlight
                    caretVisible: root.isEditing && (hasFocus || root.action_highlight)
                    caretBlinkRunning: caretVisible
                    handleEscape: true

                    onTextEdited: function(newText) {
                        if (root.isEditing) {
                            root.searchText = newText;
                            if (typeof Sounds !== "undefined") {
                                Sounds.playSfx(root.keySound);
                            }
                            root.filterData();
                            root.searchChanged(newText);
                            if (root.isPathSelector && legacyPathScanner.item && newText.length > 0) {
                                legacyPathScanner.item.scheduleScanFor(newText, function(lines) { root.mergeOptions(lines); });
                            }
                        }
                    }

                    onInputActiveFocusChanged: function(active) {
                        if (!active && !root.isOpen) {
                            root.stopEditing();
                        }
                    }

                    onEscapePressed: {
                        root.hidePopup();
                        root.stopEditing();
                    }

                    onAccepted: function(finalText) {
                        let textVal = finalText.trim();
                        if (root.filteredOptions.length > 0) {
                            let actualValue = root.filteredOptions[0];
                            let actualIndex = root.options.indexOf(actualValue);
                            if (actualIndex !== -1) {
                                if (root.currentIndex !== actualIndex) {
                                    root.currentIndex = actualIndex;
                                    root.valueChanged(actualIndex, actualValue);
                                }
                                root.selected(actualIndex, actualValue);
                            }
                        } else if (root.isPathSelector && textVal !== "") {
                            let expandedVal = (textVal.startsWith("~") && Caching.home !== "") ? (Caching.home + textVal.slice(1)) : textVal;
                            root.selectOrInsertOption(expandedVal);
                        } else if (root.allowCustomValue && textVal !== "") {
                            root.customAccepted(textVal);
                        }
                        root.hidePopup();
                        root.stopEditing();
                    }
                }
            }

            ChevronIcon {
                id: chevronWrapper
                Layout.alignment: Qt.AlignVCenter
                implicitWidth: root.iconSize
                implicitHeight: root.iconSize
                width: root.iconSize
                height: root.iconSize
                color: root.iconColor
                rotation: root.isOpen ? 90 : -90
                Behavior on rotation { NumberAnimation { duration: 250; easing.type: Easing.OutBack } }
            }
        }

        Rectangle {
            id: flashRect
            anchors.fill: parent
            radius: parent.radius
            color: "#ffffff"
            visible: !glass.active
            opacity: root.flashOpacity
            PropertyAnimation on opacity { id: btnFlashAnim; to: 0; duration: 400; easing.type: Easing.OutExpo }
        }

        SequentialAnimation {
            id: btnPopAnim
            NumberAnimation { target: root; property: "popScale"; to: 1.04; duration: 100; easing.type: Easing.OutQuad }
            NumberAnimation { target: root; property: "popScale"; to: 1.0; duration: 400; easing.type: Easing.OutQuint }
        }

        MouseArea {
            id: btnMa
            anchors.fill: parent
            hoverEnabled: root.enabled
            enabled: root.enabled
            cursorShape: root.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor

            onClicked: {
                if (!root.enabled) return;
                btnPopAnim.start();
                root.flashOpacity = 0.2;
                btnFlashAnim.start();

                if (typeof Sounds !== "undefined") {
                    Sounds.playSfx(root.clickSound);
                }
                root.clicked();

                if (root.isEditing) {
                    root.hidePopup();
                    root.stopEditing();
                    return;
                }

                if (root.isOpen) {
                    root.hidePopup();
                } else {
                    if (root.filteredOptions.length > 0) {
                        root.showPopup();
                    }
                }
            }

            onDoubleClicked: {
                if (!root.enabled) return;
                btnPopAnim.start();
                root.flashOpacity = 0.2;
                btnFlashAnim.start();
                root.startEditing();
            }
        }
    }

    Loader {
        id: popupLoader
        active: false
        sourceComponent: popupComponent
    }

    Component {
        id: popupComponent

        Popup {
            id: popup
            parent: root
            readonly property bool listHovered: listHover.hovered
            y: root.openUpward ? -(popup.height + 6) : root.height + 6
            width: root.width
            padding: root.popupPadding
            margins: 0
            transformOrigin: root.openUpward ? Item.Bottom : Item.Top
            closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutsideParent

            background: Rectangle {
                id: popupBg
                radius: Math.min(root.cornerRadius, 16)
                color: popupGlass.active ? "transparent" : root.dropdownColor
                layer.enabled: !ThemeBackend.liquidGlass
                property var glassBackdropItem: root.glassBackdrop

                GlassFill {
                    id: popupGlass
                    anchors.fill: parent
                    radius: parent.radius
                    backdropOverride: root.glassBackdrop
                    followBackdropHover: false
                    tintColor: root.dropdownColor
                    tintAmount: 0.45
                    tintStrength: 1.0
                    shadow: 1
                }
            }

            onAboutToShow: {
                root.updatePopupDirection();
                root.visibleCount = Math.min(root.filteredOptions.length, Math.max(1, Math.floor((root.popupMaxHeight + 2) / 34)));
                root.isOpen = true;
            }

            onAboutToHide: {
                root.isOpen = false;
            }

            onOpened: {
                root.opened();
            }

            onClosed: {
                root.closed();
                if (!searchField.hasFocus) {
                    root.stopEditing();
                }
            }

            enter: Transition {
                NumberAnimation { property: "opacity"; from: 0.0; to: 1.0; duration: 250; easing.type: Easing.OutQuint }
                NumberAnimation { property: "scale"; from: ThemeBackend.liquidGlass ? 0.82 : 0.9; to: 1.0; duration: ThemeBackend.liquidGlass ? 380 : 200; easing.type: ThemeBackend.liquidGlass ? Easing.OutBack : Easing.OutQuint }
            }

            exit: Transition {
                NumberAnimation { property: "opacity"; from: 1.0; to: 0.0; duration: 150; easing.type: Easing.InQuint }
                NumberAnimation { property: "scale"; from: 1.0; to: 0.9; duration: 150; easing.type: Easing.InQuint }
            }

            contentItem: ListView {
                id: listView
                readonly property bool hasOverflow: contentHeight > height + 1
                readonly property Item glassBackdrop: root.glassBackdrop
                readonly property int selectedIndex: root.currentIndex
                readonly property color accentColor: root.accentColor
                readonly property color textColor: root.textColor
                property Item hoverItem: null
                property bool scrolling: false
                implicitHeight: Math.min(contentHeight, root.popupMaxHeight)
                verticalLayoutDirection: root.openUpward ? ListView.BottomToTop : ListView.TopToBottom
                boundsBehavior: Flickable.StopAtBounds
                clip: true
                spacing: 2
                model: root.filteredOptions

                Timer {
                    id: scrollSettleTimer
                    interval: 200
                    onTriggered: listView.scrolling = false
                }

                function refreshHover() {
                    if (!listHover.hovered || !visible) {
                        hoverItem = null;
                        return;
                    }
                    const px = contentX + cursorX;
                    const py = contentY + cursorY;
                    hoverItem = itemAt(px, py) || itemAt(px, py - spacing);
                }

                function scheduleHoverRefresh() {
                    Qt.callLater(refreshHover);
                }

                onCountChanged: scheduleHoverRefresh()
                onScrollingChanged: scheduleHoverRefresh()
                onContentYChanged: {
                    scrolling = true;
                    scrollSettleTimer.restart();
                    refreshHover();
                    scheduleHoverRefresh();
                }

                property real cursorX: 0
                property real cursorY: 0
                onCursorXChanged: refreshHover()
                onCursorYChanged: refreshHover()

                HoverHandler {
                    id: listHover
                    parent: listView
                    onHoveredChanged: listView.refreshHover()
                }

                GlassLens {
                    id: hoverLens
                    parent: listView.contentItem
                    z: 0
                    instant: listView.scrolling
                    targetX: listView.hoverItem ? listView.hoverItem.x : 0
                    targetY: listView.hoverItem ? listView.hoverItem.y : 0
                    targetWidth: listView.hoverItem ? listView.hoverItem.width : 0
                    targetHeight: listView.hoverItem ? listView.hoverItem.height : 0
                    radius: Math.max(2, Math.min(root.cornerRadius - 4, 16))
                    backdropOverride: root.glassBackdrop
                    followBackdropHover: false
                    forceClear: true
                    tintColor: root.textColor
                    tintAmount: 0.14
                    tintStrength: 1.0
                    shadow: 0
                    restPress: 0.25
                    fastDuration: 180
                    slowDuration: 180
                    press: listView.hoverItem && listView.hoverItem.pressed ? 0.8 : 0
                }

                ScrollBar.vertical: ScrollBar {
                    id: vScrollBar
                    width: 8
                    leftPadding: 2
                    rightPadding: 2
                    z: 100
                    policy: listView.hasOverflow ? ScrollBar.AlwaysOn : ScrollBar.AlwaysOff
                    visible: listView.hasOverflow
                    opacity: (listView.hasOverflow && (listHover.hovered || vScrollBar.hovered || vScrollBar.pressed)) ? 1.0 : 0.0
                    Behavior on opacity { NumberAnimation { duration: 150 } }

                    contentItem: Rectangle {
                        radius: 2
                        color: ThemeBackend.liquidGlass ? Qt.alpha(root.textColor, (vScrollBar.pressed || vScrollBar.hovered) ? 0.6 : 0.3) : ((vScrollBar.pressed || vScrollBar.hovered) ? root.accentColor : root.borderColor)
                        Behavior on color { ColorAnimation { duration: 150 } }
                    }

                    background: Rectangle {
                        color: "transparent"
                    }
                }

                delegate: Rectangle {
                    id: delegateRect
                    width: listView.width
                    height: 32
                    radius: Math.max(2, Math.min(root.cornerRadius - 4, 16))

                    property int realIndex: root.options.indexOf(modelData)
                    readonly property bool pressed: itemMa.pressed
                    readonly property var view: ListView.view
                    readonly property bool isSelected: !!view && view.selectedIndex === realIndex
                    property bool shown: root.isEditing
                    property var glassBackdropItem: view ? view.glassBackdrop : null

                    Timer {
                        id: showTimer
                        running: root.isOpen && !root.isEditing && index < root.visibleCount && !delegateRect.shown
                        interval: index * 40 + 20
                        onTriggered: {
                            if (!delegateRect.shown) {
                                delegateRect.shown = true;
                                if (typeof Sounds !== "undefined") {
                                    Sounds.playSfx(root.listSound, 0.75);
                                }
                            }
                        }
                    }

                    Connections {
                        target: root
                        function onIsOpenChanged() {
                            if (root.isOpen) {
                                if (root.isEditing || index >= root.visibleCount) {
                                    delegateRect.shown = true;
                                }
                            } else {
                                delegateRect.shown = false;
                            }
                        }
                        function onIsEditingChanged() {
                            if (root.isEditing) {
                                delegateRect.shown = true;
                            }
                        }
                    }

                    Component.onCompleted: {
                        if (root.isEditing || (root.isOpen && index >= root.visibleCount)) {
                            delegateRect.shown = true;
                        }
                        listView.scheduleHoverRefresh();
                    }

                    opacity: (root.isEditing || shown) ? 1.0 : 0.0
                    transform: Translate {
                        y: (root.isEditing || shown) ? 0 : (root.openUpward ? -8 : 8)
                        Behavior on y { NumberAnimation { duration: 250; easing.type: Easing.OutQuint } }
                    }
                    Behavior on opacity { NumberAnimation { duration: 250; easing.type: Easing.OutQuint } }

                    color: delegateGlass.active ? "transparent" : (root.currentIndex === realIndex ? (ThemeBackend.liquidGlass ? Qt.alpha(root.accentColor, 0.28) : root.accentColor) : ((itemMa.pressed && !hoverLens.glassActive) ? Qt.darker(root.hoverColor, 1.1) : ((itemMa.containsMouse && !hoverLens.glassActive) ? root.hoverColor : "transparent")))
                    Behavior on color { ColorAnimation { duration: 150 } }

                    scale: itemMa.pressed ? 0.96 : ((itemMa.containsMouse && !hoverLens.glassActive) ? 1.02 : 1.0)
                    Behavior on scale { NumberAnimation { duration: 250; easing.type: Easing.OutQuint } }

                    Component.onDestruction: {
                        if (listView.hoverItem === delegateRect) listView.hoverItem = null;
                    }

                    property real flashOpacity: 0.0

                    GlassFill {
                        id: delegateGlass
                        anchors.fill: parent
                        radius: parent.radius
                        allowed: delegateRect.isSelected || (itemMa.containsMouse && !hoverLens.glassActive)
                        forceClear: true
                        backdropOverride: delegateRect.glassBackdropItem
                        followBackdropHover: false
                        tintColor: !delegateRect.view ? "transparent" : (delegateRect.isSelected ? delegateRect.view.accentColor : delegateRect.view.textColor)
                        tintAmount: delegateRect.isSelected ? 0.5 : 0.14
                        tintStrength: 1.0
                        press: itemMa.pressed ? 0.8 : (itemMa.containsMouse ? 0.25 : 0)
                        Behavior on press { NumberAnimation { duration: 250; easing.type: Easing.OutCubic } }
                    }

                    Rectangle {
                        id: itemFlashAnimRect
                        anchors.fill: parent
                        radius: parent.radius
                        color: "#ffffff"
                        visible: !delegateGlass.active
                        opacity: delegateRect.flashOpacity
                        PropertyAnimation on opacity { id: itemFlashAnim; to: 0; duration: 400; easing.type: Easing.OutExpo }
                    }

                    Text {
                        anchors.fill: parent
                        anchors.leftMargin: I18n.rtl ? (listView.hasOverflow ? 12 : 8) : 8
                        anchors.rightMargin: I18n.rtl ? 8 : (listView.hasOverflow ? 12 : 8)
                        horizontalAlignment: I18n.textAlignment
                        text: modelData
                        font.family: root.useOptionAsFontFamily ? modelData : root.fontFamily
                        font.pixelSize: root.fontPixelSize
                        color: (delegateRect.isSelected && !delegateGlass.active && !ThemeBackend.liquidGlass) ? root.activeTextColor : root.textColor
                        elide: Text.ElideRight
                        verticalAlignment: Text.AlignVCenter
                        Behavior on color { ColorAnimation { duration: 150 } }
                    }

                    MouseArea {
                        id: itemMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor

                        function trackCursor(mouse) {
                            const p = itemMa.mapToItem(listView, mouse.x, mouse.y);
                            listView.cursorX = p.x;
                            listView.cursorY = p.y;
                        }

                        onPositionChanged: (mouse) => trackCursor(mouse)
                        onEntered: listView.scheduleHoverRefresh()

                        onClicked: {
                            let selectedVal = modelData;
                            let rIdx = root.options.indexOf(selectedVal);
                            if (rIdx !== -1 && root.currentIndex !== rIdx) {
                                root.currentIndex = rIdx;
                                root.valueChanged(rIdx, selectedVal);
                            }
                            if (rIdx !== -1) {
                                root.selected(rIdx, selectedVal);
                            }
                            popup.close();
                            root.stopEditing();
                            if (typeof Sounds !== "undefined") {
                                Sounds.playSfx(root.clickSound);
                            }
                        }
                    }
                }
            }
        }
    }
}
