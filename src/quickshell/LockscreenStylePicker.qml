import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Wayland

Scope {
    id: root

    readonly property var layouts: [
        { value: "default", title: "Default", subtitle: "Original dashboard", description: "The original Serpantinum lockscreen arrangement." },
        { value: "compact", title: "Bloom", subtitle: "Single card", description: "A calm centered card with the important sign-in controls." },
        { value: "focus", title: "Orbit", subtitle: "Focused entry", description: "A focused circular sign-in arrangement." },
        { value: "tessera", title: "Tessera", subtitle: "Layered card", description: "A compact layered arrangement with stronger framing." }
    ]

    function settingValue() {
        const settings = Config.rawSettings && Config.rawSettings.lockscreen
        const value = settings && settings.layout ? settings.layout : "default"
        return root.layouts.some(item => item.value === value) ? value : "default"
    }

    function setOpen(value) {
        const current = Config.getSetting("lockscreen", { layout: "default" })
        current.pickerOpen = value
        Config.setSetting("lockscreen", current)
    }

    function apply(value) {
        const current = Config.getSetting("lockscreen", { layout: "default" })
        current.layout = value
        current.pickerOpen = false
        Config.setSetting("lockscreen", current)
    }

    Loader {
        id: windowLoader
        active: Boolean(Config.rawSettings && Config.rawSettings.lockscreen && Config.rawSettings.lockscreen.pickerOpen)

        sourceComponent: Component {
            PanelWindow {
                id: pickerWindow
                color: "#080713"
                anchors { top: true; bottom: true; left: true; right: true }
                exclusionMode: ExclusionMode.Ignore
                WlrLayershell.layer: WlrLayer.Overlay
                WlrLayershell.namespace: "qs-lockscreen-style-picker"
                WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

                FocusScope {
                    id: picker
                    anchors.fill: parent
                    focus: true

                    property int selectedIndex: root.layouts.findIndex(item => item.value === root.settingValue())
                    readonly property var selected: root.layouts[selectedIndex] || root.layouts[0]

                    function move(delta) {
                        selectedIndex = (selectedIndex + delta + root.layouts.length) % root.layouts.length
                    }

                    Keys.onPressed: event => {
                        if (event.key === Qt.Key_Escape) root.setOpen(false)
                        else if (event.key === Qt.Key_Left) move(-1)
                        else if (event.key === Qt.Key_Right) move(1)
                        else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) root.apply(selected.value)
                        else return
                        event.accepted = true
                    }

                    Rectangle { anchors.fill: parent; color: "#080713" }

                    RowLayout {
                        anchors.top: parent.top
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.margins: 32
                        spacing: 14

                        Text { text: "󰌾"; color: "#a8c7ff"; font.pixelSize: 26 }
                        Text { text: "Lock screen style"; color: "#f5f2ff"; font.pixelSize: 24; font.weight: Font.DemiBold }
                        Item { Layout.fillWidth: true }
                        Text { text: picker.selected.title; color: "#f5f2ff"; font.pixelSize: 22; font.weight: Font.DemiBold }
                        Text { text: picker.selected.subtitle; color: "#b5b0c8"; font.pixelSize: 20 }
                        Rectangle {
                            implicitWidth: 52; implicitHeight: 52; radius: 26; color: "#292936"
                            Text { anchors.centerIn: parent; text: "×"; color: "#f5f2ff"; font.pixelSize: 28 }
                            MouseArea { anchors.fill: parent; onClicked: root.setOpen(false) }
                        }
                        Rectangle {
                            implicitWidth: 142; implicitHeight: 52; radius: 26; color: "#a8c7ff"
                            Row {
                                anchors.centerIn: parent
                                spacing: 10
                                Text { text: "✓"; color: "#10294c"; font.pixelSize: 20 }
                                Text { text: "Apply"; color: "#10294c"; font.pixelSize: 16; font.weight: Font.DemiBold }
                            }
                            MouseArea { anchors.fill: parent; onClicked: root.apply(picker.selected.value) }
                        }
                    }

                    Rectangle {
                        id: mainPreviewFrame
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.top: parent.top
                        anchors.topMargin: 112
                        width: Math.min(parent.width - 320, 1400)
                        height: width * 0.5625
                        radius: 28
                        color: "#111022"
                        clip: true

                        Loader {
                            anchors.fill: parent
                            anchors.margins: 1
                            source: "guide/display/LockscreenPreview.qml"
                            property string previewStyle: picker.selected.value
                            onLoaded: item.style = previewStyle
                            onPreviewStyleChanged: if (item) item.style = previewStyle
                        }

                        Rectangle {
                            x: 24; y: 24; width: 112; height: 42; radius: 21
                            color: "#12121f"
                            visible: picker.selected.value === root.settingValue()
                            Row {
                                anchors.centerIn: parent
                                spacing: 8
                                Text { text: "✓"; color: "#a8c7ff"; font.pixelSize: 17 }
                                Text { text: "In use"; color: "#f5f2ff"; font.pixelSize: 14 }
                            }
                        }
                    }

                    Rectangle {
                        anchors.left: mainPreviewFrame.left
                        anchors.verticalCenter: mainPreviewFrame.verticalCenter
                        anchors.leftMargin: -76
                        width: 64; height: 64; radius: 32; color: "#343340"
                        Text { anchors.centerIn: parent; text: "‹"; color: "#f5f2ff"; font.pixelSize: 38 }
                        MouseArea { anchors.fill: parent; onClicked: picker.move(-1) }
                    }

                    Rectangle {
                        anchors.right: mainPreviewFrame.right
                        anchors.verticalCenter: mainPreviewFrame.verticalCenter
                        anchors.rightMargin: -76
                        width: 64; height: 64; radius: 32; color: "#343340"
                        Text { anchors.centerIn: parent; text: "›"; color: "#f5f2ff"; font.pixelSize: 38 }
                        MouseArea { anchors.fill: parent; onClicked: picker.move(1) }
                    }

                    Flickable {
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.top: mainPreviewFrame.bottom
                        anchors.topMargin: 72
                        width: Math.min(parent.width - 80, 1780)
                        height: 150
                        contentWidth: styleStrip.width
                        clip: true
                        Row {
                            id: styleStrip
                            spacing: 20
                            Repeater {
                                model: root.layouts
                                delegate: Item {
                                    required property var modelData
                                    required property int index
                                    width: 240; height: 140
                                    Rectangle {
                                        anchors.fill: parent
                                        radius: 18
                                        color: picker.selectedIndex === index ? "#17152a" : "#10101a"
                                        border.width: picker.selectedIndex === index ? 4 : 1
                                        border.color: picker.selectedIndex === index ? "#a8c7ff" : "#252535"
                                        clip: true
                                        Loader {
                                            anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top
                                            anchors.margins: 6; height: 94
                                            source: "guide/display/LockscreenPreview.qml"
                                            property string previewStyle: modelData.value
                                            onLoaded: { item.style = previewStyle; item.thumbnail = true }
                                            onPreviewStyleChanged: if (item) item.style = previewStyle
                                        }
                                        Text { anchors.left: parent.left; anchors.leftMargin: 12; anchors.bottom: parent.bottom; anchors.bottomMargin: 10; text: modelData.title; color: "#f5f2ff"; font.pixelSize: 16; font.weight: Font.DemiBold }
                                        MouseArea { anchors.fill: parent; onClicked: picker.selectedIndex = index }
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
