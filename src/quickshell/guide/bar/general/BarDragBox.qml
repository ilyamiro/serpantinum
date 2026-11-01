import QtQuick
import QtQuick.Layouts
import "../../../"
import "../../../reusables"

Rectangle {
    id: dragBoxRoot
    required property var tab
    readonly property var rootObj: tab.rootObj
    Layout.fillWidth: true
    Layout.preferredWidth: 1
    Layout.fillHeight: lName !== "available"
    implicitHeight: Math.max(rootObj.s(lName === "available" ? 68 : 90), titleText.implicitHeight + (flowList.childrenRect.height > 0 ? flowList.childrenRect.height : flowList.implicitHeight) + rootObj.s(30))
    color: dragGlass.active ? "transparent" : Qt.alpha(ThemeBackend.base, 0.7)
    radius: dragBoxRoot.tab.cardRadius
    clip: true

    GlassFill {
        id: dragGlass
        anchors.fill: parent
        radius: parent.radius
        tintColor: ThemeBackend.base
        tintAmount: 0.25
    }

    property var listModel
    property string lName
    property string title: {
        if (lName === "available") return I18n.t("guide.bar.config.available");
        if (lName === "left") return I18n.t("guide.bar.config.left");
        if (lName === "center") return I18n.t("guide.bar.config.center");
        if (lName === "right") return I18n.t("guide.bar.config.right");
        return "";
    }

    MouseArea {
        anchors.fill: parent
        z: 0
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onClicked: {
            dragBoxRoot.tab.clearPendingGroup();
        }
    }

    Text {
        id: titleText
        z: 1
        anchors.top: parent.top
        anchors.topMargin: rootObj.s(10)
        anchors.left: parent.left
        anchors.leftMargin: rootObj.s(12)
        text: dragBoxRoot.title
        font.family: ThemeBackend.fontFamily
        font.pixelSize: rootObj.s(11)
        font.weight: Font.Medium
        color: ThemeBackend.subtext0
    }

    DropArea {
        anchors.fill: parent
        z: 0
        onPositionChanged: function(drag) {
            let mappedX = drag.x - flowList.x;
            let mappedY = drag.y - flowList.y;
            let idx = dragBoxRoot.tab.getDropIndex(flowList, mappedX, mappedY);
            dragBoxRoot.tab.updatePlaceholder(dragBoxRoot.lName, idx, drag.source.btnWidth, drag.source.moduleId, drag.source.moduleLabel, drag.source.moduleIcon, drag.source.listName, drag.source.moduleId);
        }
        onExited: {
            if (dragBoxRoot.tab.currentPlaceholderList === dragBoxRoot.lName) {
                dragBoxRoot.tab.clearPlaceholders();
                dragBoxRoot.tab.currentPlaceholderList = "";
                dragBoxRoot.tab.currentPlaceholderIndex = -1;
            }
        }
    }

    Flow {
        id: flowList
        z: 1
        anchors.top: titleText.bottom
        anchors.topMargin: rootObj.s(8)
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.leftMargin: rootObj.s(12)
        anchors.rightMargin: rootObj.s(12)
        spacing: rootObj.s(8)

        Repeater {
            model: listModel
            delegate: Item {
                id: delegateRoot
                property bool isDelegate: true
                property bool isPlaceholder: model.isPlaceholder !== undefined ? model.isPlaceholder : false
                property string moduleId: model.moduleId
                property string moduleLabel: {
                    if (moduleId === "left") return I18n.t("guide.bar.modules.actions");
                    if (moduleId === "workspaces") return I18n.t("guide.bar.modules.workspaces.name");
                    if (moduleId === "focus") return I18n.t("guide.bar.modules.focus");
                    if (moduleId === "timedate") return I18n.t("guide.bar.modules.timedate.name");
                    if (moduleId === "info") return I18n.t("guide.bar.modules.info");
                    if (moduleId === "weather") return I18n.t("guide.bar.modules.weather");
                    if (moduleId === "media") return I18n.t("guide.bar.modules.media");
                    if (moduleId === "vis") return I18n.t("guide.bar.modules.vis");
                    if (moduleId === "tray") return I18n.t("guide.bar.modules.tray");
                    if (moduleId === "sysmon") return I18n.t("guide.bar.modules.sysmon");
                    if (moduleId === "kb") return I18n.t("guide.bar.modules.keyboard");
                    if (moduleId === "wifi") return I18n.t("guide.bar.modules.network");
                    if (moduleId === "bt") return I18n.t("guide.bar.modules.bluetooth");
                    if (moduleId === "vol") return I18n.t("guide.bar.modules.volume");
                    if (moduleId === "bat") return I18n.t("guide.bar.modules.battery");
                    return model.moduleLabel !== undefined ? model.moduleLabel : moduleId;
                }
                property string moduleIcon: model.moduleIcon
                property string listName: dragBoxRoot.lName
                property int moduleIndex: index

                property bool isBeingDragged: dragArea.drag.active
                property int btnWidth: btn.implicitWidth

                property bool isGrouped: model.groupId !== undefined && model.groupId !== ""
                property bool showError: false

                SequentialAnimation {
                    id: shakeAnim
                    NumberAnimation { target: floatWrapper; property: "x"; to: -2; duration: 50 }
                    NumberAnimation { target: floatWrapper; property: "x"; to: 2; duration: 50 }
                    NumberAnimation { target: floatWrapper; property: "x"; to: -2; duration: 50 }
                    NumberAnimation { target: floatWrapper; property: "x"; to: 2; duration: 50 }
                    NumberAnimation { target: floatWrapper; property: "x"; to: 0; duration: 50 }
                    onStarted: delegateRoot.showError = true
                    onStopped: delegateRoot.showError = false
                }

                function triggerError() {
                    shakeAnim.stop();
                    shakeAnim.start();
                }

                implicitWidth: isPlaceholder ? model.placeholderWidth : btn.implicitWidth
                implicitHeight: rootObj.s(32)
                width: isPlaceholder ? model.placeholderWidth : (isBeingDragged ? 0 : btn.implicitWidth)
                height: isPlaceholder ? rootObj.s(32) : (isBeingDragged ? 0 : rootObj.s(32))
                visible: isPlaceholder || !isBeingDragged

                Behavior on width {
                    enabled: !delegateRoot.isBeingDragged
                    NumberAnimation { duration: 150; easing.type: Easing.OutQuint }
                }

                Rectangle {
                    anchors.fill: parent
                    visible: delegateRoot.isPlaceholder
                    color: "transparent"
                    radius: ThemeBackend.borderRadius
                    Rectangle { anchors.fill: parent; color: ThemeBackend.subtext0; opacity: 0.15; radius: ThemeBackend.borderRadius }
                }

                Item {
                    id: floatWrapper
                    anchors.fill: !dragArea.drag.active ? parent : undefined
                    visible: !delegateRoot.isPlaceholder

                    Drag.active: dragArea.drag.active
                    Drag.source: delegateRoot
                    Drag.hotSpot.x: width / 2
                    Drag.hotSpot.y: height / 2

                    states: [
                        State {
                            when: dragArea.drag.active
                            ParentChange { target: floatWrapper; parent: dragBoxRoot.tab }
                            PropertyChanges {
                                target: floatWrapper
                                width: delegateRoot.btnWidth
                                height: rootObj.s(32)
                                opacity: 0.9
                                scale: 1.05
                            }
                        }
                    ]

                    ClickButton {
                        id: btn
                        anchors.fill: parent
                        buttonText: delegateRoot.moduleLabel
                        buttonIcon: delegateRoot.moduleIcon
                        accentColor: delegateRoot.isGrouped ? dragBoxRoot.tab.getGroupColor(model.groupId) : ThemeBackend.surface0
                        textColor: (delegateRoot.isGrouped && !ThemeBackend.liquidGlass) ? dragBoxRoot.tab.getContrastTextColor(dragBoxRoot.tab.getGroupColor(model.groupId)) : ThemeBackend.text
                        glassTintScale: delegateRoot.isGrouped ? 2.6 : 1.0
                        cornerRadius: ThemeBackend.borderRadius
                        horizontalPadding: rootObj.s(12)
                        iconFontSize: rootObj.s(15)
                        textFontSize: rootObj.s(12)
                        acceptedButtons: Qt.LeftButton | Qt.RightButton

                        onClicked: function() {
                            dragBoxRoot.tab.clearPendingGroup();
                        }

                        onRightClicked: function() {
                            if (delegateRoot.listName === "available") {
                                dragBoxRoot.tab.clearPendingGroup();
                                return;
                            }

                            let m = dragBoxRoot.tab.getModel(delegateRoot.listName);
                            if (!m) return;

                            if (dragBoxRoot.tab.pendingGroupModuleId !== "") {
                                if (dragBoxRoot.tab.pendingGroupModuleId === delegateRoot.moduleId) {
                                    dragBoxRoot.tab.clearPendingGroup();
                                    return;
                                }

                                if (dragBoxRoot.tab.pendingGroupList === delegateRoot.listName) {
                                    dragBoxRoot.tab.uniteElements(dragBoxRoot.tab.pendingGroupModuleId, delegateRoot.moduleId, delegateRoot.listName);
                                    dragBoxRoot.tab.clearPendingGroup();
                                } else {
                                    delegateRoot.triggerError();
                                    dragBoxRoot.tab.clearPendingGroup();
                                }
                                return;
                            }

                            if (dragBoxRoot.tab.getValidItemCount(m) <= 1) {
                                return;
                            }

                            if (model.groupId && model.groupId !== "") {
                                m.setProperty(delegateRoot.moduleIndex, "groupId", "");
                                dragBoxRoot.tab.cleanupGroups();
                                dragBoxRoot.tab.saveModuleModels();
                            } else {
                                dragBoxRoot.tab.pendingGroupModuleId = delegateRoot.moduleId;
                                dragBoxRoot.tab.pendingGroupList = delegateRoot.listName;
                            }
                        }
                    }

                    Rectangle {
                        anchors.fill: parent
                        color: ThemeBackend.red
                        opacity: delegateRoot.showError ? 0.15 : 0.0
                        radius: ThemeBackend.borderRadius
                        Behavior on opacity { NumberAnimation { duration: 250 } }
                        z: 4
                    }

                    Rectangle {
                        anchors.fill: parent
                        color: ThemeBackend.mauve
                        opacity: dragBoxRoot.tab.pendingGroupModuleId === delegateRoot.moduleId ? 0.2 : 0.0
                        radius: ThemeBackend.borderRadius
                        Behavior on opacity { NumberAnimation { duration: 150 } }
                        z: 5
                    }

                    MouseArea {
                        id: dragArea
                        anchors.fill: parent
                        drag.target: floatWrapper
                        cursorShape: Qt.OpenHandCursor
                        acceptedButtons: Qt.LeftButton
                        onPressed: {
                            dragBoxRoot.tab.clearPendingGroup();
                            cursorShape = Qt.ClosedHandCursor
                            if (typeof Sounds !== "undefined") {
                                Sounds.playSfx("guide/barconfig/out.wav");
                            }
                        }
                        onReleased: {
                            cursorShape = Qt.OpenHandCursor
                            if (typeof Sounds !== "undefined") {
                                Sounds.playSfx("guide/barconfig/in.wav");
                            }
                            floatWrapper.Drag.drop();
                            if (dragBoxRoot.tab.currentPlaceholderList !== "") {
                                dragBoxRoot.tab.executeDrop(delegateRoot);
                            } else {
                                dragBoxRoot.tab.clearPlaceholders();
                            }
                            floatWrapper.x = 0;
                            floatWrapper.y = 0;
                        }
                    }
                }
            }
        }
    }
}
