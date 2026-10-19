import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import "../"
import "../reusables"
import "../reusables/buttons"

Item {
    id: contentArea
    required property var popup
    opacity: popup.introContent
    scale: 0.95 + (0.05 * popup.introContent)
    transform: Translate { y: popup.s(20) * (1.0 - popup.introContent) }

    Repeater {
        id: contentRepeater
        model: popup.tabsModel
        delegate: Item {
            id: tabContentWrapper
            anchors.fill: parent

            property int parentTabIndex: index
            property int tabIndex: parentTabIndex
            property var tabData: modelData
            property bool hasSubtabs: Boolean(tabData.subtabs && tabData.subtabs.length > 0)
            property alias singleLoader: singleTabLoader
            property alias subLoadersRepeater: subRepeat

            property bool isCurrent: popup.currentTab === parentTabIndex
            visible: isCurrent || opacity > 0.001
            opacity: isCurrent ? 1.0 : 0.0
            property real animY: isCurrent ? 0 : popup.s(10)
            transform: Translate { y: tabContentWrapper.animY }

            Behavior on opacity {
                NumberAnimation { duration: 200; easing.type: Easing.OutCubic }
            }
            Behavior on animY {
                NumberAnimation { duration: 240; easing.type: Easing.OutCubic }
            }

            Loader {
                id: singleTabLoader
                anchors.fill: parent
                asynchronous: false
                active: !tabContentWrapper.hasSubtabs
                visible: !tabContentWrapper.hasSubtabs && tabContentWrapper.visible
                property int tabIndex: tabContentWrapper.parentTabIndex
                property int subTabIndex: -1

                function ensureLoaded() {
                    if (status === Loader.Null && tabData.file) {
                        setSource(tabData.file, {
                            "rootObj": popup,
                            "tabIndex": tabContentWrapper.parentTabIndex
                        });
                    }
                }

                onStatusChanged: {
                    if (status === Loader.Error) {
                        console.warn("Guide tab failed to load:", source);
                    }
                }

                onLoaded: {
                    popup.registerTabSearchItems(item);
                    Qt.callLater(function() {
                        popup.registerTabSearchItems(singleTabLoader.item);
                    });
                }

                Component.onCompleted: {
                    if (popup.currentTab === tabContentWrapper.parentTabIndex) ensureLoaded();
                }

                Connections {
                    target: popup
                    function onCurrentTabChanged() {
                        if (popup.currentTab === tabContentWrapper.parentTabIndex && !tabContentWrapper.hasSubtabs) singleTabLoader.ensureLoaded();
                    }
                    function onRequestLoad(order) {
                        if (order === popup.tabLoadOrder(tabContentWrapper.parentTabIndex, -1)) singleTabLoader.ensureLoaded();
                    }
                }

                Connections {
                    target: singleTabLoader.item
                    ignoreUnknownSignals: true
                    function onSearchItemsChanged() {
                        popup.registerTabSearchItems(singleTabLoader.item);
                    }
                    function onSearchEntriesChanged() {
                        popup.registerTabSearchItems(singleTabLoader.item);
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

                    property bool isSubCurrent: popup.currentTab === tabContentWrapper.parentTabIndex && popup.currentSubTab === subIndex
                    visible: isSubCurrent || opacity > 0.001
                    opacity: isSubCurrent ? 1.0 : 0.0
                    property real subAnimY: isSubCurrent ? 0 : popup.s(10)
                    transform: Translate { y: subTabLoader.subAnimY }

                    Behavior on opacity {
                        NumberAnimation { duration: 200; easing.type: Easing.OutCubic }
                    }
                    Behavior on subAnimY {
                        NumberAnimation { duration: 240; easing.type: Easing.OutCubic }
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

                    onStatusChanged: {
                        if (status === Loader.Error) {
                            console.warn("Guide tab failed to load:", source);
                        }
                    }

                    onLoaded: {
                        if (item && item.subTabIndex !== undefined) {
                            item.subTabIndex = subIndex;
                        }
                        popup.registerTabSearchItems(item);
                        Qt.callLater(function() {
                            popup.registerTabSearchItems(subTabLoader.item);
                        });
                    }

                    Component.onCompleted: {
                        if (isSubCurrent) ensureLoaded();
                    }

                    Connections {
                        target: popup
                        function onCurrentTabChanged() {
                            if (popup.currentTab === tabContentWrapper.parentTabIndex && popup.currentSubTab === subIndex) subTabLoader.ensureLoaded();
                        }
                        function onCurrentSubTabChanged() {
                            if (popup.currentTab === tabContentWrapper.parentTabIndex && popup.currentSubTab === subIndex) subTabLoader.ensureLoaded();
                        }
                        function onRequestLoad(order) {
                            if (order === popup.tabLoadOrder(tabContentWrapper.parentTabIndex, subIndex)) subTabLoader.ensureLoaded();
                        }
                    }

                    Connections {
                        target: subTabLoader.item
                        ignoreUnknownSignals: true
                        function onSearchItemsChanged() {
                            popup.registerTabSearchItems(subTabLoader.item);
                        }
                        function onSearchEntriesChanged() {
                            popup.registerTabSearchItems(subTabLoader.item);
                        }
                    }
                }
            }
        }
    }
}
