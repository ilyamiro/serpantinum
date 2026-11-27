import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import "../../"
import "../"

Rectangle {
    id: root
    Layout.fillWidth: true

    property var rootObj: null

    readonly property var effectiveRootObj: searchAnchor.effectiveRootObj

    function s(val) {
        let dummy = effectiveRootObj;
        return (dummy && typeof dummy.s === "function") ? dummy.s(val) : Scaler.s(val);
    }

    property string settingId: ""
    property string searchTab: ""
    property string searchSubTab: ""
    property string searchKeywords: ""
    property string section: ""

    readonly property string effectiveSection: searchAnchor.effectiveSection
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

    readonly property string effectiveSettingId: searchAnchor.effectiveSettingId

    property real highlightFlash: 0.0
    property int handledHighlightToken: -1
    property alias registeredSearchKey: searchAnchor.registeredSearchKey

    GuideSearchAnchor {
        id: searchAnchor
        targetItem: root
        rootObj: root.rootObj
        settingId: root.settingId
        title: root.title
        description: root.description
        icon: root.icon
        searchTab: root.searchTab
        searchSubTab: root.searchSubTab
        searchKeywords: root.searchKeywords
        section: root.section
        searchable: root.searchable
        unavailable: root.hiddenByConfig
        indexableCheck: function() { return root.isIndexable(); }
    }

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
        return searchAnchor.isOwnTabLive();
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
        searchAnchor.ensureVisibleInFlickable();
    }

    signal highlightTriggered()

    function triggerHighlightAnimation() {
        root.highlightTriggered();
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
        searchAnchor.scheduleRegister();
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
        return searchAnchor.resolveTabInfo();
    }

    function registerWithSearch() {
        searchAnchor.registerWithSearch();
    }

    function unregisterFromSearch() {
        searchAnchor.unregisterFromSearch();
    }

    Component.onCompleted: {
        checkHighlight();
    }
    Component.onDestruction: {
        releaseRevealHolds();
    }

    readonly property var blobPlacement: {
        let child = root;
        let p = root.parent;
        let nested = false;
        while (p) {
            if (p.isBlobColumn) return { inBlob: true, nested: nested, holder: child, column: p };
            if (p.isGroupSubWrapper) nested = true;
            if (p.tabIndex !== undefined || p.isGuidePopup || p.isGuideTab) break;
            child = p;
            p = p.parent;
        }
        return { inBlob: false, nested: false, holder: null, column: null };
    }
    readonly property bool inBlob: blobPlacement.inBlob

    readonly property bool blobDividerVisible: {
        let pl = blobPlacement;
        if (!pl.inBlob || pl.nested) return false;
        let sibs = pl.column.children;
        for (let i = 0; i < sibs.length; i++) {
            if (sibs[i] === pl.holder) return false;
            if (sibs[i].visible && sibs[i].height > 0.01) return true;
        }
        return false;
    }

    property real cornerRadius: ThemeBackend.borderRadius
    property color baseColor: root.inBlob ? (root.blobPlacement.nested ? Qt.alpha(ThemeBackend.surface1, 0.25) : "transparent") : Qt.alpha(ThemeBackend.surface0, 0.4)
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
    property real iconCornerRadius: ThemeBackend.borderRadius
    property color iconAccentColor: "transparent"
    property color iconTextColor: ThemeBackend.subtext0
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
    property real stackBelowWidth: 560
    readonly property bool stacked: !root.fillControlWidth && root.width < root.s(root.stackBelowWidth)
    property bool showDivider: false
    property color dividerColor: Qt.alpha(ThemeBackend.surface1, 0.3)

    property bool clickable: false

    signal clicked()
    signal rightClicked()
    signal iconClicked()

    default property alias content: controlRow.data
    property alias bottomContent: bottomCol.data

    radius: root.cornerRadius
    readonly property color stateColor: {
        let base = (root.clickable && cardMa.containsMouse) ? root.hoverColor : root.baseColor;
        if (root.dimmed) base = Qt.alpha(base, base.a * 0.5);
        if (root.highlightFlash > 0.001) {
            let k = root.dimmed ? 0.2 : 0.16;
            if (root.inBlob) {
                if (base.a < 0.001) {
                    let cardAlpha = 0.4;
                    let overlayAlpha = k * cardAlpha / (1 - k + k * cardAlpha);
                    return Qt.rgba(ThemeBackend.mauve.r, ThemeBackend.mauve.g, ThemeBackend.mauve.b, root.highlightFlash * overlayAlpha);
                }
            }
            return Qt.tint(base, Qt.rgba(ThemeBackend.mauve.r, ThemeBackend.mauve.g, ThemeBackend.mauve.b, root.highlightFlash * k));
        }
        return base;
    }
    readonly property bool glassActive: rowGlassLoader.item !== null && rowGlassLoader.item.active
    color: root.glassActive ? (root.highlightFlash > 0.001 ? Qt.alpha(ThemeBackend.mauve, root.highlightFlash * 0.12) : "transparent") : stateColor
    clip: true

    implicitHeight: contentCol.implicitHeight + root.verticalPadding * 2

    Behavior on color { ColorAnimation { duration: 150 } }

    Loader {
        id: rowGlassLoader
        anchors.fill: parent
        active: !root.inBlob || root.blobPlacement.nested
        sourceComponent: GlassFill {
            radius: root.cornerRadius
            tintColor: ThemeBackend.surface0
            tintAmount: (root.clickable && cardMa.containsMouse ? 0.34 : 0.26) * (root.dimmed ? 0.5 : 1.0)
            press: root.clickable && cardMa.containsMouse ? 0.2 : 0
            Behavior on press { NumberAnimation { duration: 250; easing.type: Easing.OutCubic } }
            Behavior on tintAmount { NumberAnimation { duration: 150 } }
        }
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
        Behavior on opacity { NumberAnimation { duration: 150 } }

        GridLayout {
            id: mainRow
            layoutDirection: I18n.layoutDirection
            Layout.fillWidth: true
            columnSpacing: root.spacing
            rowSpacing: root.controlSpacing
            columns: (iconBtn.visible ? 1 : 0) + (root.stacked ? 1 : 2)

            Loader {
                id: iconBtn
                active: root.showIcon && root.icon !== ""
                visible: active
                Layout.preferredWidth: active ? root.s(root.iconSize) : 0
                Layout.preferredHeight: active ? root.s(root.iconSize) : 0
                Layout.alignment: Qt.AlignVCenter
                sourceComponent: IconButton {
                    enabled: root.iconInteractive
                    size: root.s(root.iconSize)
                    cornerRadius: root.iconCornerRadius
                    buttonIcon: root.icon
                    iconFontSize: root.s(root.iconFontSize)
                    accentColor: root.dimmed ? ThemeBackend.surface1 : root.iconAccentColor
                    textColor: root.dimmed ? ThemeBackend.subtext0 : root.iconTextColor
                    onClicked: root.iconClicked()
                }
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
                    elide: Text.ElideRight
                    maximumLineCount: root.wrapText ? 99 : 2
                    wrapMode: Text.WordWrap
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
                Layout.fillWidth: root.fillControlWidth || root.stacked
                Layout.columnSpan: root.stacked ? mainRow.columns : 1
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

    Rectangle {
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.leftMargin: root.horizontalPadding
        anchors.rightMargin: root.horizontalPadding
        height: 1
        color: root.dividerColor
        visible: root.blobDividerVisible
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
