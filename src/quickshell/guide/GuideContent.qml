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

    readonly property real searchHeaderHeight: popup.s(64)

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

            Loader {
                id: singleTabLoader
                anchors.fill: parent
                asynchronous: false
                active: !tabContentWrapper.hasSubtabs
                visible: !tabContentWrapper.hasSubtabs && tabContentWrapper.visible
                opacity: status === Loader.Ready ? 1.0 : 0.0
                property int tabIndex: tabContentWrapper.parentTabIndex
                property int subTabIndex: -1
                readonly property int order: popup.tabLoadOrder(tabContentWrapper.parentTabIndex, -1)

                Behavior on opacity {
                    NumberAnimation { duration: 150; easing.type: Easing.OutCubic }
                }

                function ensureLoaded() {
                    if (status === Loader.Null && tabData.file) {
                        setSource(tabData.file, {
                            "rootObj": popup,
                            "tabIndex": tabContentWrapper.parentTabIndex
                        });
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
                    enabled: !tabContentWrapper.hasSubtabs
                    function onRequestLoad(order) {
                        if (order === singleTabLoader.order) singleTabLoader.ensureLoaded();
                    }
                    function onReleaseTab(order) {
                        if (order === singleTabLoader.order && order !== popup.currentSlot) singleTabLoader.release();
                    }
                }
            }

            Repeater {
                id: subRepeat
                model: tabContentWrapper.hasSubtabs ? tabData.subtabs : []

                delegate: Loader {
                    id: subTabLoader
                    anchors.fill: parent
                    asynchronous: false
                    property int subIndex: index
                    property int tabIndex: tabContentWrapper.parentTabIndex
                    property int subTabIndex: subIndex
                    property var subData: modelData
                    readonly property int order: popup.tabLoadOrder(tabContentWrapper.parentTabIndex, subIndex)

                    property bool isSubCurrent: popup.currentTab === tabContentWrapper.parentTabIndex && popup.currentSubTab === subIndex
                    visible: isSubCurrent || opacity > 0.001
                    opacity: isSubCurrent && status === Loader.Ready ? 1.0 : 0.0

                    Behavior on opacity {
                        NumberAnimation { duration: 150; easing.type: Easing.OutCubic }
                    }

                    function ensureLoaded() {
                        if (status === Loader.Null && subData.file) {
                            setSource(subData.file, {
                                "rootObj": popup,
                                "tabIndex": tabContentWrapper.parentTabIndex
                            });
                            if (item && item.subTabIndex !== undefined) {
                                item.subTabIndex = subIndex;
                            }
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

                    onLoaded: {
                        if (item && item.subTabIndex !== undefined) {
                            item.subTabIndex = subIndex;
                        }
                    }

                    Connections {
                        target: popup
                        function onRequestLoad(order) {
                            if (order === subTabLoader.order) subTabLoader.ensureLoaded();
                        }
                        function onReleaseTab(order) {
                            if (order === subTabLoader.order && order !== popup.currentSlot) subTabLoader.release();
                        }
                    }
                }
            }
        }
    }
    }

    Rectangle {
        id: searchOverlay
        anchors.fill: parent
        color: ThemeBackend.base
        topRightRadius: !I18n.rtl ? ThemeBackend.clampedBorderRadius : 0
        bottomRightRadius: !I18n.rtl ? ThemeBackend.clampedBorderRadius : 0
        topLeftRadius: I18n.rtl ? ThemeBackend.clampedBorderRadius : 0
        bottomLeftRadius: I18n.rtl ? ThemeBackend.clampedBorderRadius : 0
        property real reveal: popup.searchActive ? 1.0 : 0.0
        Behavior on reveal { NumberAnimation { duration: 250; easing.type: Easing.OutQuint } }
        visible: popup.searchActive || reveal > 0.001
        opacity: reveal
        z: 10

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
