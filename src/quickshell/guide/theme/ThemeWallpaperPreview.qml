import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import Quickshell
import "../../"
import "../../reusables"

Item {
    id: wpPreviewContainer
    required property var tab
    readonly property var rootObj: tab.rootObj

    Layout.alignment: Qt.AlignHCenter
    Layout.fillWidth: true
    Layout.preferredHeight: rootObj.s(220)
    Layout.topMargin: rootObj.s(6)
    Layout.bottomMargin: rootObj.s(4)

    property real highlightFlash: 0.0
    property int handledHighlightToken: -1

    function resolveTabInfo() {
        let p = wpPreviewContainer.parent;
        let targetTabIdx = -1;
        let targetSubTabIdx = -1;
        while (p) {
            if (targetSubTabIdx === -1 && p.subTabIndex !== undefined) targetSubTabIdx = p.subTabIndex;
            if (targetTabIdx === -1 && p.tabIndex !== undefined) targetTabIdx = p.tabIndex;
            p = p.parent;
        }
        let r = wpPreviewContainer.tab.rootObj;
        let tab = "";
        let subtab = "";
        if (r && r.tabsModel && targetTabIdx >= 0 && targetTabIdx < r.tabsModel.length) {
            let tModel = r.tabsModel[targetTabIdx];
            tab = tModel.key || tModel.id || "";
            if (tModel.subtabs && targetSubTabIdx >= 0 && targetSubTabIdx < tModel.subtabs.length) {
                subtab = tModel.subtabs[targetSubTabIdx].key || tModel.subtabs[targetSubTabIdx].id || "";
            }
        }
        return { tab: tab, subtab: subtab };
    }

    function registerWithSearch() {
        let r = wpPreviewContainer.tab.rootObj;
        if (!r || typeof r.registerSearchItem !== "function") return;
        let info = resolveTabInfo();
        r.registerSearchItem({
            id: "wallpaper",
            title: I18n.t("guide.theme.wallpaper.select") || "Wallpaper",
            desc: I18n.t("guide.theme.wallpaper.desc") || "Select and preview current wallpaper",
            description: I18n.t("guide.theme.wallpaper.desc") || "Select and preview current wallpaper",
            tab: info.tab,
            subtab: info.subtab,
            icon: "󰸉",
            keywords: "wallpaper background image video select screen current desktop",
            target: wpPreviewContainer,
            unavailable: false
        });
    }

    function unregisterFromSearch() {
        let r = wpPreviewContainer.tab.rootObj;
        if (!r || typeof r.unregisterSearchItem !== "function") return;
        r.unregisterSearchItem("wallpaper");
    }

    function ensureVisibleInFlickable() {
        let p = wpPreviewContainer.parent;
        let flick = null;
        while (p) {
            if (p.contentY !== undefined && p.contentHeight !== undefined) {
                flick = p;
                break;
            }
            p = p.parent;
        }
        if (flick) {
            let targetPos = wpPreviewContainer.mapToItem(flick.contentItem, 0, 0);
            if (targetPos) {
                let viewTop = flick.contentY;
                let viewBottom = flick.contentY + flick.height;
                if (targetPos.y < viewTop || targetPos.y + wpPreviewContainer.height > viewBottom) {
                    flick.contentY = Math.max(0, Math.min(targetPos.y - flick.height / 2 + wpPreviewContainer.height / 2, flick.contentHeight - flick.height));
                }
            }
        }
    }

    function triggerHighlightAnimation() {
        highlightAnimation.restart();
        wpPreviewContainer.ensureVisibleInFlickable();
        ensureVisibleTimer.restart();
    }

    function checkHighlight() {
        let r = wpPreviewContainer.tab.rootObj;
        if (!r) return;
        if (r.highlightToken === wpPreviewContainer.handledHighlightToken) return;
        if (r.highlightedSettingId && (r.highlightedSettingId === "wallpaper" || r.highlightedSettingId === "wallpaper_preview")) {
            wpPreviewContainer.handledHighlightToken = r.highlightToken;
            r.highlightedSettingId = "";
            highlightDelayTimer.restart();
        }
    }

    Connections {
        target: wpPreviewContainer.tab.rootObj
        ignoreUnknownSignals: true
        function onHighlightTokenChanged() {
            wpPreviewContainer.checkHighlight();
        }
    }

    onVisibleChanged: {
        searchRegTimer.restart();
        if (visible) {
            wpPreviewContainer.checkHighlight();
        }
    }

    Timer {
        id: searchRegTimer
        interval: 10
        repeat: false
        onTriggered: wpPreviewContainer.registerWithSearch()
    }

    Timer {
        id: ensureVisibleTimer
        interval: 320
        repeat: false
        onTriggered: wpPreviewContainer.ensureVisibleInFlickable()
    }

    Timer {
        id: highlightDelayTimer
        interval: 80
        repeat: false
        onTriggered: wpPreviewContainer.triggerHighlightAnimation()
    }

    SequentialAnimation {
        id: highlightAnimation
        PropertyAction { target: wpPreviewContainer; property: "highlightFlash"; value: 0.0 }
        NumberAnimation { target: wpPreviewContainer; property: "highlightFlash"; from: 0.0; to: 1.0; duration: 400; easing.type: Easing.OutCubic }
        PauseAnimation { duration: 1500 }
        NumberAnimation { target: wpPreviewContainer; property: "highlightFlash"; from: 1.0; to: 0.0; duration: 900; easing.type: Easing.InOutSine }
    }

    Component.onCompleted: {
        searchRegTimer.restart();
        checkHighlight();
    }

    Component.onDestruction: {
        unregisterFromSearch();
    }

    Rectangle {
        id: wpCardMask
        anchors.fill: parent
        radius: ThemeBackend.borderRadius
        color: "black"
        visible: false
        layer.enabled: true
    }

    Item {
        id: wpCardContent
        anchors.fill: parent
        visible: false
        layer.enabled: true

        Rectangle {
            id: wpCardBg
            anchors.fill: parent
            radius: ThemeBackend.borderRadius
            color: gf1.active ? "transparent" : ThemeBackend.surface0

            GlassFill {
                id: gf1
                anchors.fill: parent
                radius: parent.radius
                tintColor: ThemeBackend.surface0
                tintAmount: 0.25
            }
        }

        Image {
            id: wpCardImage
            anchors.fill: parent
            source: wpPreviewContainer.tab.isWallpaperVideo ? ("file://" + Caching.getCacheDir("wallpaper") + "/current_wallpaper.png?rev=" + wpPreviewContainer.tab.wallpaperRevision) : (wpPreviewContainer.tab.currentWallpaperPath ? "file://" + wpPreviewContainer.tab.currentWallpaperPath : "")
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            smooth: true
            mipmap: true
            cache: false
            visible: source !== ""
        }

        Rectangle {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            height: rootObj.s(64)
            radius: ThemeBackend.borderRadius
            gradient: Gradient {
                GradientStop { position: 0.0; color: "transparent" }
                GradientStop { position: 0.25; color: Qt.rgba(0, 0, 0, 0.35) }
                GradientStop { position: 1.0; color: Qt.rgba(0, 0, 0, 0.8) }
            }
        }
    }

    MultiEffect {
        anchors.fill: parent
        source: wpCardContent
        maskEnabled: true
        maskSource: wpCardMask
    }

    Rectangle {
        anchors.fill: parent
        radius: ThemeBackend.borderRadius
        color: ThemeBackend.mauve
        opacity: wpPreviewContainer.highlightFlash * 0.2
        visible: opacity > 0.001
        border.color: ThemeBackend.mauve
        border.width: wpPreviewContainer.highlightFlash > 0.01 ? 2 : 0
        Behavior on opacity { NumberAnimation { duration: 180 } }
    }

    IconButton {
        id: videoIndicator
        visible: wpPreviewContainer.tab.isWallpaperVideo
        anchors.centerIn: parent
        size: rootObj.s(50)
        cornerRadius: rootObj.s(16)
        iconFontSize: rootObj.s(20)
        buttonIcon: "󰐊"
        accentColor: ThemeBackend.surface0
        textColor: ThemeBackend.text
        opacity: 1.0
        enabled: false
    }

    RowLayout {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.margins: rootObj.s(12)
        spacing: rootObj.s(12)

        ClickButton {
            id: wpSelectBtn
            Layout.preferredHeight: rootObj.s(32)
            cornerRadius: ThemeBackend.borderRadius
            horizontalPadding: rootObj.s(14)
            buttonIcon: "󰸉"
            iconFontSize: rootObj.s(15)
            buttonText: "Select wallpaper"
            textFontSize: rootObj.s(11)
            accentColor: ThemeBackend.mauve
            textColor: ThemeBackend.base
            contentAlignment: Qt.AlignHCenter
            onClicked: {
                Quickshell.execDetached(["bash", Caching.serpantinumDir + "/scripts/qs_manager.sh", "toggle", "wallpaper"]);
            }
        }

        Item { Layout.fillWidth: true }

        MouseArea {
            id: wpPathMa
            Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
            implicitWidth: wpPathCol.implicitWidth
            implicitHeight: wpPathCol.implicitHeight
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                if (wpPreviewContainer.tab.currentWallpaperPath && wpPreviewContainer.tab.currentWallpaperPath !== "") {
                    let escapeBash = function(str) { return String(str).replace(/(["\\$`])/g, '\\$1'); };
                    Quickshell.execDetached(["bash", "-c", "xdg-open \"$(dirname \"" + escapeBash(wpPreviewContainer.tab.currentWallpaperPath) + "\")\""]);
                }
            }

            ColumnLayout {
                id: wpPathCol
                anchors.right: parent.right
                spacing: rootObj.s(1)

                Text {
                    text: {
                        if (!wpPreviewContainer.tab.currentWallpaperPath) return "No Wallpaper Selected";
                        let fn = wpPreviewContainer.tab.currentWallpaperPath.split("/").pop();
                        return fn || wpPreviewContainer.tab.currentWallpaperPath;
                    }
                    font.family: ThemeBackend.fontFamily
                    font.pixelSize: rootObj.s(12)
                    font.weight: Font.Bold
                    color: "#ffffff"
                    Layout.alignment: Qt.AlignRight
                    elide: Text.ElideLeft
                    Layout.maximumWidth: rootObj.s(320)
                }

                Text {
                    text: wpPreviewContainer.tab.currentWallpaperPath ? wpPreviewContainer.tab.currentWallpaperPath.replace(Quickshell.env("HOME"), "~") : ""
                    font.family: ThemeBackend.fontFamily
                    font.pixelSize: rootObj.s(10)
                    color: Qt.rgba(1, 1, 1, 0.75)
                    Layout.alignment: Qt.AlignRight
                    elide: Text.ElideLeft
                    Layout.maximumWidth: rootObj.s(320)
                    visible: text !== ""
                }
            }
        }
    }
}
