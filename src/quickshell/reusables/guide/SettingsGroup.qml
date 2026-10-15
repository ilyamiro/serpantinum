import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import "../../"
import "../"

Item {
    id: root
    Layout.fillWidth: true

    readonly property bool isSettingsGroup: true

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

    property bool expanded: true
    property bool forceOpen: false

    property int openHolds: 0
    readonly property bool isOpen: expanded || forceOpen || openHolds > 0

    function holdOpen() {
        openHolds++;
    }

    function releaseOpen() {
        if (openHolds > 0) openHolds--;
    }

    property string settingId: ""
    property string searchTab: ""
    property string searchSubTab: ""
    property string searchKeywords: ""
    property bool searchable: false

    property string icon: ""
    property int iconSize: 32
    property int iconFontSize: 16
    property int iconOffsetX: 0
    property int iconOffsetY: 0
    property real iconCornerRadius: ThemeBackend.borderRadius
    property color iconAccentColor: ThemeBackend.surface0
    property color iconTextColor: "#ffffff"

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

    property real expandProgress: isOpen ? 1.0 : 0.0
    Behavior on expandProgress {
        NumberAnimation { duration: 250; easing.type: Easing.InOutCubic }
    }

    default property alias content: headerRow.content
    property alias subSettings: subSettingsCol.data

    implicitHeight: headerRow.implicitHeight + subItemsWrapper.implicitHeight

    SettingsRow {
        id: headerRow
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right

        rootObj: root.rootObj
        settingId: ""
        searchTab: ""
        searchSubTab: ""
        searchKeywords: ""
        searchable: false

        icon: root.icon
        iconSize: root.iconSize
        iconFontSize: root.iconFontSize
        iconOffsetX: root.iconOffsetX
        iconOffsetY: root.iconOffsetY
        iconCornerRadius: root.iconCornerRadius
        iconAccentColor: root.iconAccentColor
        iconTextColor: root.iconTextColor

        title: root.title
        description: root.description
        fontFamily: root.fontFamily
        titlePixelSize: root.titlePixelSize
        descriptionPixelSize: root.descriptionPixelSize
        titleBold: root.titleBold
        titleColor: root.titleColor
        descriptionColor: root.descriptionColor
        wrapText: root.wrapText

        titleBadge: root.titleBadge
        customLeftContent: root.customLeftContent
        fillControlWidth: root.fillControlWidth
    }

    Item {
        id: subItemsWrapper
        readonly property bool isGroupSubWrapper: true
        readonly property var ownerGroup: root

        anchors.top: headerRow.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        clip: true

        visible: root.expandProgress > 0.001
        implicitHeight: (subSettingsContent.implicitHeight + root.s(4)) * root.expandProgress
        opacity: Math.max(0.0, (root.expandProgress - 0.15) / 0.85)

        RowLayout {
            id: subSettingsContent
            layoutDirection: I18n.layoutDirection
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.topMargin: root.s(4)
            spacing: root.s(6)

            Item {
                Layout.preferredWidth: root.s(20)
                Layout.fillHeight: true

                Rectangle {
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    anchors.topMargin: root.s(2)
                    anchors.bottomMargin: root.s(2)
                    width: Math.max(1, root.s(2))
                    radius: root.s(1)
                    color: Qt.rgba(ThemeBackend.surface2.r, ThemeBackend.surface2.g, ThemeBackend.surface2.b, 0.7)
                }
            }

            ColumnLayout {
                id: subSettingsCol
                Layout.fillWidth: true
                spacing: root.s(6)
            }
        }
    }
}
