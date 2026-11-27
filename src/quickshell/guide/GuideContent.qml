import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import "../"
import "../reusables"
import "../reusables/buttons"

Item {
    id: contentArea
    required property var popup
    property alias searchInput: searchField
    property alias searchResults: resultsList
    function currentActiveItem() {
        let w = contentRepeater.itemAt(popup.currentTab);
        return w ? w.currentItem() : null;
    }

    readonly property real searchHeaderHeight: popup.s(64)

    component TabSlotLoader: Loader {
        id: slotLoader
        property int slotTabIndex: -1
        property int slotSubTabIndex: -1
        property string slotFile: ""
        property bool slotEnabled: true
        property bool slotCurrent: true

        property int tabIndex: slotTabIndex
        property int subTabIndex: slotSubTabIndex
        readonly property int order: popup.tabLoadOrder(slotTabIndex, slotSubTabIndex)

        anchors.fill: parent
        asynchronous: false
        active: slotEnabled
        visible: slotEnabled && (slotCurrent || opacity > 0.001)
        opacity: slotCurrent && status === Loader.Ready ? 1.0 : 0.0

        Behavior on opacity {
            NumberAnimation { duration: 150; easing.type: Easing.OutCubic }
        }

        function ensureLoaded() {
            if (status === Loader.Null && slotFile !== "") {
                let props = {
                    "rootObj": popup,
                    "tabIndex": slotTabIndex
                };
                if (slotSubTabIndex >= 0) {
                    props["subTabIndex"] = slotSubTabIndex;
                }
                setSource(Qt.resolvedUrl(slotFile), props);
            }
        }

        function release() {
            if (status === Loader.Null) return;
            popup.setSlotLoaded(order, false);
            source = "";
        }

        onStatusChanged: {
            if (status === Loader.Ready) popup.setSlotLoaded(order, true);
            if (status === Loader.Error) {
                console.warn("Guide tab failed to load:", source);
            }
        }

        Connections {
            target: popup
            enabled: slotLoader.slotEnabled
            function onRequestLoad(order) {
                if (order === slotLoader.order) slotLoader.ensureLoaded();
            }
            function onReleaseTab(order) {
                if (order === slotLoader.order && order !== popup.currentSlot) slotLoader.release();
            }
        }
    }

    opacity: popup.introContent
    scale: 0.95 + (0.05 * popup.introContent)
    transform: Translate { y: popup.s(20) * (1.0 - popup.introContent) }

    Item {
        id: body
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.right: parent.right
    Repeater {
        id: contentRepeater
        model: popup.tabsModel
        delegate: Item {
            id: tabContentWrapper
            x: 0
            y: 0

            property int parentTabIndex: index
            property int tabIndex: parentTabIndex
            property var tabData: modelData
            property bool hasSubtabs: Boolean(tabData.subtabs && tabData.subtabs.length > 0)
            property alias singleLoader: singleTabLoader
            property alias subLoadersRepeater: subRepeat
            function currentItem() {
                if (hasSubtabs) {
                    let sub = subRepeat.itemAt(popup.currentSubTab);
                    return sub ? sub.item : null;
                }
                return singleTabLoader.item;
            }

            property bool isCurrent: popup.currentTab === parentTabIndex
            visible: isCurrent || opacity > 0.001
            opacity: isCurrent ? 1.0 : 0.0

            Behavior on opacity {
                NumberAnimation { duration: 150; easing.type: Easing.OutCubic }
            }

            Binding {
                target: tabContentWrapper
                property: "width"
                value: body.width
                when: tabContentWrapper.visible
            }

            Binding {
                target: tabContentWrapper
                property: "height"
                value: body.height
                when: tabContentWrapper.visible
            }

            TabSlotLoader {
                id: singleTabLoader
                slotTabIndex: tabContentWrapper.parentTabIndex
                slotSubTabIndex: -1
                slotFile: tabContentWrapper.tabData.file || ""
                slotEnabled: !tabContentWrapper.hasSubtabs
                slotCurrent: tabContentWrapper.visible
            }

            Repeater {
                id: subRepeat
                model: tabContentWrapper.hasSubtabs ? tabData.subtabs : []

                delegate: TabSlotLoader {
                    id: subTabLoader
                    required property int index
                    required property var modelData
                    property int subIndex: index
                    property var subData: modelData
                    slotTabIndex: tabContentWrapper.parentTabIndex
                    slotSubTabIndex: index
                    slotFile: modelData.file || ""
                    slotEnabled: true
                    slotCurrent: popup.currentTab === tabContentWrapper.parentTabIndex && popup.currentSubTab === index
                }
            }
        }
    }
    }

    Rectangle {
        id: searchOverlay
        anchors.fill: parent
        color: Qt.alpha(ThemeBackend.base, ThemeBackend.elementOpacity)
        topRightRadius: !I18n.rtl ? ThemeBackend.clampedBorderRadius : 0
        bottomRightRadius: !I18n.rtl ? ThemeBackend.clampedBorderRadius : 0
        topLeftRadius: I18n.rtl ? ThemeBackend.clampedBorderRadius : 0
        bottomLeftRadius: I18n.rtl ? ThemeBackend.clampedBorderRadius : 0
        property real reveal: popup.searchActive ? 1.0 : 0.0
        Behavior on reveal { NumberAnimation { duration: 250; easing.type: Easing.OutQuint } }
        visible: popup.searchActive || reveal > 0.001
        opacity: reveal
        z: 10

        WallpaperBlur {
            z: -1
            anchors.fill: parent
            standalone: true
            topLeftRadius: parent.topLeftRadius
            topRightRadius: parent.topRightRadius
            bottomLeftRadius: parent.bottomLeftRadius
            bottomRightRadius: parent.bottomRightRadius
        }

        Item {
            id: header
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            height: contentArea.searchHeaderHeight
            transform: Translate { y: popup.s(-10) * (1.0 - searchOverlay.reveal) }

            Input {
                id: searchField
                anchors.verticalCenter: parent.verticalCenter
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.leftMargin: popup.s(12)
                anchors.rightMargin: popup.s(12)
                implicitHeight: popup.s(40)
                height: popup.s(40)
                leadingIcon: "󰍉"
                placeholderText: I18n.t("guide.search.placeholder", "Search settings...")
                showClearButton: true
                fontPixelSize: popup.s(12)
                baseColor: Qt.alpha(ThemeBackend.surface0, 0.6)
                accentColor: ThemeBackend.mauve
                textColor: ThemeBackend.text
                subTextColor: ThemeBackend.subtext0
                borderColor: Qt.alpha(ThemeBackend.surface2, 0.4)
                cornerRadius: ThemeBackend.borderRadius

                onTextEdited: (txt) => {
                    popup.searchQuery = txt;
                    popup.searchSelectedIndex = 0;
                }
                onCleared: {
                    popup.searchQuery = "";
                    popup.searchSelectedIndex = 0;
                }

                Keys.onEscapePressed: (event) => {
                    if (popup.searchQuery !== "") {
                        searchField.text = "";
                        popup.searchQuery = "";
                    } else {
                        popup.closeSearch();
                    }
                    event.accepted = true;
                }
                Keys.onDownPressed: (event) => { popup.navigateSearch(1); event.accepted = true; }
                Keys.onUpPressed: (event) => { popup.navigateSearch(-1); event.accepted = true; }
                Keys.onReturnPressed: (event) => { popup.activateSelectedSearch(); event.accepted = true; }
                Keys.onEnterPressed: (event) => { popup.activateSelectedSearch(); event.accepted = true; }
            }
        }

        GuideSearchResults {
            id: resultsList
            popup: contentArea.popup
            anchors.top: header.bottom
            anchors.bottom: parent.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.leftMargin: popup.s(12)
            anchors.rightMargin: popup.s(12)
            anchors.bottomMargin: popup.s(8)
            transform: Translate { y: popup.s(12) * (1.0 - searchOverlay.reveal) }
        }
    }
}
