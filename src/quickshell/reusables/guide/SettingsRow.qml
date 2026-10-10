import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import "../../"
import "../"

Rectangle {
    id: root
    Layout.fillWidth: true

    property var rootObj: null

    readonly property var effectiveRootObj: {
        if (rootObj) return rootObj;
        let p = root.parent;
        while (p) {
            if (p.rootObj) return p.rootObj;
            if (p.isGuidePopup) return p;
            p = p.parent;
        }
        return null;
    }

    function s(val) {
        let dummy = effectiveRootObj;
        return (dummy && typeof dummy.s === "function") ? dummy.s(val) : val;
    }

    property string settingId: ""
    property string searchTab: ""
    property string searchSubTab: ""
    property string searchKeywords: ""
    property bool searchable: true

    property bool hiddenByConfig: false
    property string unavailableReason: ""

    property int revealHolds: 0
    readonly property bool revealedBySearch: revealHolds > 0
    readonly property bool dimmed: hiddenByConfig
    readonly property string effectiveDescription: (root.dimmed && root.unavailableReason !== "") ? root.unavailableReason : root.description

    visible: !root.hiddenByConfig || root.revealedBySearch

    property bool selfRevealHeld: false
    property var heldGroups: []
    property int highlightLeadInMs: 0

    readonly property string effectiveSettingId: {
        if (settingId && settingId !== "") return settingId;
        if (title && title !== "") {
            return title.toLowerCase().replace(/[^a-z0-9_]/g, "_");
        }
        return "";
    }

    property real highlightFlash: 0.0
    property int handledHighlightToken: -1
    property string registeredSearchKey: ""

    function _releaseGroupList(groups) {
        for (let i = 0; i < groups.length; i++) {
            try {
                if (groups[i] && typeof groups[i].releaseOpen === "function") groups[i].releaseOpen();
            } catch (e) {}
        }
    }

    function acquireRevealHolds() {
        let prevSelfHeld = root.selfRevealHeld;
        let prevGroups = root.heldGroups;

        root.selfRevealHeld = root.hiddenByConfig;
        if (root.selfRevealHeld) root.revealHolds++;

        let groups = [];
        let needsExpand = false;
        let p = root.parent;
        while (p) {
            if (p.tabIndex !== undefined || p.isGuidePopup || p.isGuideTab) break;
            if (p.isGroupSubWrapper && p.ownerGroup && typeof p.ownerGroup.holdOpen === "function") {
                if (!p.ownerGroup.isOpen) needsExpand = true;
                p.ownerGroup.holdOpen();
                groups.push(p.ownerGroup);
            }
            p = p.parent;
        }
        root.heldGroups = groups;

        root.highlightLeadInMs = needsExpand ? 280 : 0;

        if (prevSelfHeld && root.revealHolds > 0) root.revealHolds--;
        root._releaseGroupList(prevGroups);
    }

    function releaseRevealHolds() {
        let selfHeld = root.selfRevealHeld;
        let groups = root.heldGroups;
        root.selfRevealHeld = false;
        root.heldGroups = [];
        if (selfHeld && root.revealHolds > 0) root.revealHolds--;
        root._releaseGroupList(groups);
    }

    function isOwnTabLive() {
        let r = effectiveRootObj;
        if (!r || r.visible !== true) return false;
        let tabIdx = -1;
        let subIdx = -1;
        let p = root.parent;
        while (p) {
            if (subIdx === -1 && p.subTabIndex !== undefined && p.subTabIndex !== null && p.subTabIndex >= 0)
                subIdx = p.subTabIndex;
            if (tabIdx === -1 && p.tabIndex !== undefined && p.tabIndex !== null && p.tabIndex >= 0)
                tabIdx = p.tabIndex;
            p = p.parent;
        }
        if (tabIdx < 0) return false;
        if (tabIdx !== r.currentTab) return false;
        if (subIdx >= 0 && subIdx !== r.currentSubTab) return false;
        return true;
    }

    function isIndexable() {
        if (!root.searchable) return false;
        if (!root.title || root.title === "") return false;
        if (!root.isOwnTabLive()) return true;
        return root.isSettingAvailable();
    }

    function isSettingAvailable() {
        if (!root.searchable) return false;
        if (!root.title || root.title === "") return false;

        let softHidden = null;
        if (root.hiddenByConfig && !root.revealedBySearch) softHidden = root;

        let p = root.parent;
        while (p) {
            if (p.tabIndex !== undefined || p.isGuidePopup || p.isGuideTab) break;
            if (p.isGroupSubWrapper && p.ownerGroup && !p.ownerGroup.isOpen) softHidden = p;
            p = p.parent;
        }

        if (softHidden) {
            let above = softHidden.parent;
            if (!above || !above.visible) return false;
        } else if (!root.visible) {
            return false;
        }

        if (!root.enabled) return false;
        return true;
    }

    function ensureVisibleInFlickable() {
        let p = root.parent;
        let flick = null;
        while (p) {
            if (p.contentY !== undefined && p.contentHeight !== undefined) {
                flick = p;
                break;
            }
            p = p.parent;
        }
        if (flick) {
            let targetPos = root.mapToItem(flick.contentItem, 0, 0);
            if (targetPos) {
                let viewTop = flick.contentY;
                let viewBottom = flick.contentY + flick.height;
                if (targetPos.y < viewTop || targetPos.y + root.height > viewBottom) {
                    flick.contentY = Math.max(0, Math.min(targetPos.y - flick.height / 2 + root.height / 2, flick.contentHeight - flick.height));
                }
            }
        }
    }

    function triggerHighlightAnimation() {
        root.acquireRevealHolds();
        highlightAnimation.restart();
        root.ensureVisibleInFlickable();
        ensureVisibleTimer.restart();
    }

    function checkHighlight() {
        let r = effectiveRootObj;
        if (!r) return;
        if (r.highlightToken === root.handledHighlightToken) return;
        if (r.highlightedSettingId && (r.highlightedSettingId === root.effectiveSettingId || r.highlightedSettingId === root.settingId)) {
            if (!root.isSettingAvailable()) return;
            root.handledHighlightToken = r.highlightToken;
            r.highlightedSettingId = "";
            highlightDelayTimer.restart();
        }
    }

    Connections {
        target: root.effectiveRootObj
        ignoreUnknownSignals: true
        function onHighlightTokenChanged() {
            root.checkHighlight();
        }
    }

    onVisibleChanged: {
        searchRegTimer.restart();
        if (visible) {
            root.checkHighlight();
        }
    }

    Timer {
        id: ensureVisibleTimer
        interval: 320
        repeat: false
        onTriggered: root.ensureVisibleInFlickable()
    }

    Timer {
        id: highlightDelayTimer
        interval: 80
        repeat: false
        onTriggered: root.triggerHighlightAnimation()
    }

    SequentialAnimation {
        id: highlightAnimation
        PropertyAction { target: root; property: "highlightFlash"; value: 0.0 }
        PauseAnimation { duration: root.highlightLeadInMs }
        NumberAnimation { target: root; property: "highlightFlash"; from: 0.0; to: 1.0; duration: 400; easing.type: Easing.OutCubic }
        PauseAnimation { duration: 1500 }
        NumberAnimation { target: root; property: "highlightFlash"; from: 1.0; to: 0.0; duration: 900; easing.type: Easing.InOutSine }
        ScriptAction { script: root.releaseRevealHolds() }
    }

    function resolveTabInfo() {
        let tab = searchTab;
        let subtab = searchSubTab;

        if (tab !== "" && subtab !== "") {
            return { tab: tab, subtab: subtab };
        }

        let p = root.parent;
        let targetTabIdx = -1;
        let targetSubTabIdx = -1;

        while (p) {
            if (targetSubTabIdx === -1 && p.subTabIndex !== undefined && p.subTabIndex !== null && p.subTabIndex >= 0) {
                targetSubTabIdx = p.subTabIndex;
            }
            if (targetTabIdx === -1 && p.tabIndex !== undefined && p.tabIndex !== null && p.tabIndex >= 0) {
                targetTabIdx = p.tabIndex;
            }
            p = p.parent;
        }

        let r = effectiveRootObj;
        if (r && r.tabsModel && targetTabIdx >= 0 && targetTabIdx < r.tabsModel.length) {
            let tModel = r.tabsModel[targetTabIdx];
            if (tab === "") {
                tab = tModel.key || tModel.id || "";
            }
            if (subtab === "" && tModel.subtabs && targetSubTabIdx >= 0 && targetSubTabIdx < tModel.subtabs.length) {
                subtab = tModel.subtabs[targetSubTabIdx].key || tModel.subtabs[targetSubTabIdx].id || "";
            }
        }

        return { tab: tab, subtab: subtab };
    }

    function registerWithSearch() {
        let r = effectiveRootObj;
        if (!r || typeof r.registerSearchItem !== "function") return;
        if (!root.isIndexable()) {
            unregisterFromSearch();
            return;
        }

        let info = resolveTabInfo();
        let searchKey = info.tab + "|" + info.subtab + "|" + root.effectiveSettingId;

        if (root.registeredSearchKey !== "" && root.registeredSearchKey !== searchKey) {
            r.unregisterSearchItem(root.registeredSearchKey);
        }
        root.registeredSearchKey = searchKey;

        r.registerSearchItem({
            key: searchKey,
            id: root.effectiveSettingId,
            title: root.title,
            desc: root.description,
            description: root.description,
            tab: info.tab,
            subtab: info.subtab,
            icon: root.icon,
            keywords: root.searchKeywords,
            target: root,
            unavailable: root.hiddenByConfig
        });
    }

    function unregisterFromSearch() {
        let r = effectiveRootObj;
        if (!r || typeof r.unregisterSearchItem !== "function") return;
        let keyToUnregister = root.registeredSearchKey;
        if (!keyToUnregister || keyToUnregister === "") {
            let info = resolveTabInfo();
            if (root.effectiveSettingId !== "") {
                keyToUnregister = info.tab + "|" + info.subtab + "|" + root.effectiveSettingId;
            }
        }
        if (keyToUnregister && keyToUnregister !== "") {
            r.unregisterSearchItem(keyToUnregister);
            root.registeredSearchKey = "";
        }
    }

    Timer {
        id: searchRegTimer
        interval: 10
        repeat: false
        onTriggered: root.registerWithSearch()
    }

    Component.onCompleted: {
        searchRegTimer.restart();
        checkHighlight();
    }
    Component.onDestruction: {
        releaseRevealHolds();
        unregisterFromSearch();
    }

    onTitleChanged: searchRegTimer.restart()
    onDescriptionChanged: searchRegTimer.restart()
    onIconChanged: searchRegTimer.restart()
    onSearchableChanged: searchRegTimer.restart()
    onSearchTabChanged: searchRegTimer.restart()
    onSearchSubTabChanged: searchRegTimer.restart()
    onSettingIdChanged: searchRegTimer.restart()
    onHiddenByConfigChanged: searchRegTimer.restart()

    property real cornerRadius: ThemeBackend.borderRadius
    property color baseColor: Qt.alpha(ThemeBackend.surface0, 0.4)
    property color hoverColor: Qt.alpha(ThemeBackend.surface1, 0.4)
    property color borderColor: "transparent"
    property int borderWidth: 0

    property real horizontalPadding: root.s(14)
    property real verticalPadding: root.s(12)
    property real spacing: root.s(12)
    property real innerSpacing: root.s(12)
    property real textSpacing: root.s(2)
    property real controlSpacing: root.s(8)
    property real bottomSpacing: root.s(12)

    property string icon: ""
    property bool showIcon: icon !== ""
    property int iconSize: 32
    property int iconFontSize: 16
    property int iconOffsetX: 0
    property int iconOffsetY: 0
    property real iconCornerRadius: ThemeBackend.borderRadius
    property color iconAccentColor: ThemeBackend.surface0
    property color iconTextColor: "#ffffff"
    property bool iconInteractive: false

    property string title: ""
    property string description: ""
    property string fontFamily: ThemeBackend.fontFamily
    property int titlePixelSize: 13
    property int descriptionPixelSize: 11
    property bool titleBold: false
    property color titleColor: ThemeBackend.text
    property color descriptionColor: ThemeBackend.subtext0
    property bool wrapText: false

    property Component titleBadge: null
    property Component customLeftContent: null

    property bool fillControlWidth: false
    property bool showDivider: false
    property color dividerColor: Qt.alpha(ThemeBackend.surface1, 0.3)

    property bool clickable: false
    property bool animateHeight: false
    property int animationDuration: 250

    signal clicked()
    signal rightClicked()
    signal iconClicked()

    default property alias content: controlRow.data
    property alias bottomContent: bottomCol.data

    radius: root.cornerRadius
    color: {
        let base = (root.clickable && cardMa.containsMouse) ? root.hoverColor : root.baseColor;
        if (root.dimmed) base = Qt.alpha(base, base.a * 0.5);
        if (root.highlightFlash > 0.001) {
            let k = root.dimmed ? 0.2 : 0.12;
            return Qt.tint(base, Qt.rgba(ThemeBackend.mauve.r, ThemeBackend.mauve.g, ThemeBackend.mauve.b, root.highlightFlash * k));
        }
        return base;
    }
    border.color: root.borderColor
    border.width: root.borderWidth
    clip: true

    implicitHeight: contentCol.implicitHeight + root.verticalPadding * 2

    Behavior on color { ColorAnimation { duration: 180 } }
    Behavior on border.color { ColorAnimation { duration: 180 } }
    Behavior on implicitHeight {
        enabled: root.animateHeight
        NumberAnimation { duration: root.animationDuration; easing.type: Easing.OutCubic }
    }

    MouseArea {
        id: cardMa
        anchors.fill: parent
        enabled: root.clickable && root.enabled
        hoverEnabled: root.clickable && root.enabled
        cursorShape: (root.clickable && root.enabled) ? Qt.PointingHandCursor : Qt.ArrowCursor
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        z: -1
        onClicked: function(mouse) {
            if (mouse.button === Qt.RightButton) {
                root.rightClicked();
            } else {
                root.clicked();
            }
        }
    }

    ColumnLayout {
        id: contentCol
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.leftMargin: root.horizontalPadding
        anchors.rightMargin: root.horizontalPadding
        anchors.verticalCenter: parent.verticalCenter
        spacing: root.innerSpacing

        opacity: root.dimmed ? 0.4 : 1.0
        Behavior on opacity { NumberAnimation { duration: 180 } }

        RowLayout {
            id: mainRow
            layoutDirection: I18n.layoutDirection
            Layout.fillWidth: true
            spacing: root.spacing

            IconButton {
                id: iconBtn
                visible: root.showIcon && root.icon !== ""
                enabled: root.iconInteractive
                size: root.s(root.iconSize)
                Layout.preferredWidth: visible ? root.s(root.iconSize) : 0
                Layout.preferredHeight: visible ? root.s(root.iconSize) : 0
                Layout.alignment: Qt.AlignVCenter
                cornerRadius: root.iconCornerRadius
                buttonIcon: root.icon
                iconFontSize: root.s(root.iconFontSize)
                iconOffsetX: root.s(root.iconOffsetX)
                iconOffsetY: root.s(root.iconOffsetY)
                accentColor: root.dimmed ? ThemeBackend.surface1 : root.iconAccentColor
                textColor: root.dimmed ? ThemeBackend.subtext0 : root.iconTextColor
                onClicked: root.iconClicked()
            }

            Loader {
                id: leftCustomLoader
                active: root.customLeftContent !== null
                sourceComponent: root.customLeftContent
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignVCenter
                visible: active
            }

            ColumnLayout {
                id: textCol
                visible: !leftCustomLoader.active && (root.title !== "" || root.effectiveDescription !== "" || titleBadgeLoader.active)
                Layout.fillWidth: true
                Layout.minimumWidth: 0
                Layout.alignment: Qt.AlignVCenter
                spacing: root.textSpacing

                RowLayout {
                    layoutDirection: I18n.layoutDirection
                    Layout.fillWidth: true
                    spacing: root.s(6)
                    visible: root.title !== "" || titleBadgeLoader.active

                    Text {
                        Layout.fillWidth: !titleBadgeLoader.active
                        text: root.title
                        font.family: root.fontFamily
                        font.pixelSize: root.s(root.titlePixelSize)
                        font.bold: root.titleBold
                        color: root.dimmed ? ThemeBackend.subtext0 : root.titleColor
                        horizontalAlignment: I18n.textAlignment
                        elide: root.wrapText ? Text.ElideNone : Text.ElideRight
                        wrapMode: root.wrapText ? Text.WordWrap : Text.NoWrap
                        visible: text !== ""
                    }

                    Loader {
                        id: titleBadgeLoader
                        active: root.titleBadge !== null
                        sourceComponent: root.titleBadge
                        Layout.alignment: Qt.AlignVCenter
                        visible: active
                    }

                    Item {
                        Layout.fillWidth: true
                        visible: titleBadgeLoader.active
                    }
                }

                Text {
                    Layout.fillWidth: true
                    text: root.effectiveDescription
                    font.family: root.fontFamily
                    font.pixelSize: root.s(root.descriptionPixelSize)
                    color: root.dimmed ? ThemeBackend.subtext0 : root.descriptionColor
                    horizontalAlignment: I18n.textAlignment
                    elide: root.wrapText ? Text.ElideNone : Text.ElideRight
                    wrapMode: root.wrapText ? Text.WordWrap : Text.NoWrap
                    visible: text !== ""
                }
            }

            Item {
                Layout.fillWidth: true
                visible: !root.fillControlWidth && !textCol.visible && !leftCustomLoader.active
            }

            RowLayout {
                id: controlRow
                enabled: !root.dimmed
                Layout.fillWidth: root.fillControlWidth
                Layout.alignment: root.fillControlWidth ? Qt.AlignVCenter : ((I18n.rtl ? Qt.AlignLeft : Qt.AlignRight) | Qt.AlignVCenter)
                spacing: root.controlSpacing
            }
        }

        Rectangle {
            id: dividerLine
            Layout.fillWidth: true
            height: 1
            color: root.dividerColor
            visible: root.showDivider && bottomCol.children.length > 0
        }

        ColumnLayout {
            id: bottomCol
            enabled: !root.dimmed
            Layout.fillWidth: true
            spacing: root.bottomSpacing
            visible: children.length > 0
        }
    }

    MouseArea {
        id: unavailableBlocker
        anchors.fill: parent
        z: 50
        visible: root.dimmed
        enabled: root.dimmed
        hoverEnabled: true
        acceptedButtons: Qt.AllButtons
        cursorShape: Qt.ForbiddenCursor
    }
}
