import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import QtCore
import Quickshell
import "../../"
import "../../reusables"

Item {
    id: root
    required property var rootObj
    required property int tabIndex
    property int subTabIndex: 2

    anchors.fill: parent
    visible: rootObj.currentTab === tabIndex && rootObj.currentSubTab === subTabIndex
    opacity: visible ? 1.0 : 0.0
    property real slideY: visible ? 0 : rootObj.s(10)

    Behavior on slideY { NumberAnimation { duration: 250; easing.type: Easing.OutQuart } }
    transform: Translate { y: slideY }
    Behavior on opacity { NumberAnimation { duration: 250 } }

    Settings {
        id: lockLayoutSettings
        category: "LockScreen"
        property string layout: "default"
    }

    readonly property var layouts: [
        { value: "default", title: "Veil", subtitle: "Wide dashboard", description: "The full Serpantinum dashboard with weather and system wings." },
        { value: "compact", title: "Bloom", subtitle: "Single card", description: "A calm centered card with the important sign-in controls." },
        { value: "focus", title: "Orbit", subtitle: "Focused entry", description: "A larger centered sign-in surface with less surrounding information." },
        { value: "tessera", title: "Tessera", subtitle: "Layered card", description: "A compact layered arrangement with a stronger panel frame." }
    ]

    function selectedValue() {
        const value = lockLayoutSettings.layout
        if (value === "compact" || value === "focus" || value === "tessera") return value
        return "default"
    }

    function choose(value) { lockLayoutSettings.layout = value }

    Flickable {
        anchors.fill: parent
        anchors.margins: rootObj.s(8)
        contentHeight: settingsColumn.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        ColumnLayout {
            id: settingsColumn
            width: parent.width
            spacing: rootObj.s(10)

            SettingsRow {
                rootObj: root.rootObj
                icon: "󰌾"
                title: "Lockscreen layout"
                description: "Choose a visual arrangement. Click a preview to apply it."
            }

            GridLayout {
                Layout.fillWidth: true
                columns: 2
                columnSpacing: rootObj.s(8)
                rowSpacing: rootObj.s(8)

                Repeater {
                    model: root.layouts

                    delegate: Item {
                        id: card
                        required property var modelData
                        Layout.fillWidth: true
                        Layout.preferredHeight: rootObj.s(206)
                        readonly property bool selected: root.selectedValue() === modelData.value

                        Rectangle {
                            anchors.fill: parent
                            radius: ThemeBackend.borderRadius * 1.25
                            color: card.selected ? Qt.alpha(ThemeBackend.mauve, 0.14) : ThemeBackend.surface0
                            border.width: card.selected ? 2 : 1
                            border.color: card.selected ? ThemeBackend.mauve : ThemeBackend.surface1

                            ColumnLayout {
                                anchors.fill: parent
                                anchors.margins: rootObj.s(8)
                                spacing: rootObj.s(6)

                                Item {
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: rootObj.s(112)
                                    clip: true

                                    Rectangle { anchors.fill: parent; radius: rootObj.s(10); color: ThemeBackend.crust }

                                    Text {
                                        visible: modelData.value === "default"
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        y: rootObj.s(10)
                                        text: "10:29"
                                        color: ThemeBackend.text
                                        font.family: ThemeBackend.fontFamily
                                        font.pixelSize: rootObj.s(24)
                                        font.weight: Font.Light
                                    }

                                    Rectangle {
                                        visible: modelData.value === "default"
                                        anchors.centerIn: parent
                                        width: parent.width * 0.72
                                        height: rootObj.s(48)
                                        radius: rootObj.s(8)
                                        color: ThemeBackend.surface0
                                        border.color: ThemeBackend.surface2
                                        border.width: 1
                                        Text { anchors.centerIn: parent; text: "user   •   password"; color: ThemeBackend.subtext0; font.pixelSize: rootObj.s(8) }
                                    }

                                    Rectangle {
                                        visible: modelData.value === "default"
                                        anchors.left: parent.left
                                        anchors.bottom: parent.bottom
                                        width: parent.width * 0.23
                                        height: rootObj.s(22)
                                        radius: rootObj.s(5)
                                        color: ThemeBackend.surface1
                                    }

                                    Text {
                                        visible: modelData.value === "compact"
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        y: rootObj.s(12)
                                        text: "10:29"
                                        color: ThemeBackend.text
                                        font.family: ThemeBackend.fontFamily
                                        font.pixelSize: rootObj.s(30)
                                        font.weight: Font.Bold
                                    }

                                    Rectangle {
                                        visible: modelData.value === "compact"
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        anchors.bottom: parent.bottom
                                        width: parent.width * 0.52
                                        height: rootObj.s(42)
                                        radius: rootObj.s(12)
                                        color: ThemeBackend.surface0
                                        border.color: ThemeBackend.mauve
                                        border.width: 1
                                        Text { anchors.centerIn: parent; text: "unlock"; color: ThemeBackend.subtext1; font.pixelSize: rootObj.s(9) }
                                    }

                                    Rectangle {
                                        visible: modelData.value === "focus"
                                        anchors.centerIn: parent
                                        width: parent.width * 0.62
                                        height: parent.height * 0.78
                                        radius: rootObj.s(12)
                                        color: ThemeBackend.surface0
                                        border.color: ThemeBackend.blue
                                        border.width: 1
                                        Column {
                                            anchors.centerIn: parent
                                            spacing: rootObj.s(5)
                                            Text { anchors.horizontalCenter: parent.horizontalCenter; text: "10:29"; color: ThemeBackend.text; font.pixelSize: rootObj.s(19); font.weight: Font.Bold }
                                            Rectangle { width: rootObj.s(70); height: rootObj.s(13); radius: rootObj.s(6); color: ThemeBackend.surface2 }
                                        }
                                    }

                                    Rectangle {
                                        visible: modelData.value === "tessera"
                                        anchors.centerIn: parent
                                        width: parent.width * 0.75
                                        height: parent.height * 0.62
                                        radius: rootObj.s(8)
                                        color: ThemeBackend.surface0
                                        border.color: ThemeBackend.surface2
                                        border.width: 1
                                        Rectangle { anchors.left: parent.left; anchors.top: parent.top; width: parent.width * 0.32; height: parent.height; color: Qt.alpha(ThemeBackend.mauve, 0.42); radius: rootObj.s(8) }
                                        Text { anchors.centerIn: parent; text: "10:29   /   unlock"; color: ThemeBackend.text; font.pixelSize: rootObj.s(9) }
                                    }

                                    Rectangle {
                                        anchors.fill: parent
                                        radius: rootObj.s(10)
                                        color: "transparent"
                                        border.width: card.selected ? 1 : 0
                                        border.color: Qt.alpha(ThemeBackend.mauve, 0.8)
                                    }
                                }

                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: rootObj.s(6)
                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        spacing: 0
                                        Text { text: card.modelData.title; color: ThemeBackend.text; font.family: ThemeBackend.fontFamily; font.pixelSize: rootObj.s(12); font.weight: Font.Bold }
                                        Text { text: card.modelData.subtitle; color: ThemeBackend.subtext0; font.family: ThemeBackend.fontFamily; font.pixelSize: rootObj.s(9) }
                                    }
                                    Text { visible: card.selected; text: "✓"; color: ThemeBackend.mauve; font.pixelSize: rootObj.s(16); font.bold: true }
                                }

                                Text {
                                    Layout.fillWidth: true
                                    text: card.modelData.description
                                    color: ThemeBackend.subtext0
                                    font.family: ThemeBackend.fontFamily
                                    font.pixelSize: rootObj.s(9)
                                    elide: Text.ElideRight
                                    maximumLineCount: 1
                                }
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.choose(card.modelData.value)
                            }
                        }
                    }
                }
            }

            SettingsRow {
                rootObj: root.rootObj
                icon: "󰍹"
                title: "Shared security flow"
                description: "Every layout uses the same PAM authentication, password handling, and unlock animation."
                titlePixelSize: 12
                descriptionPixelSize: 10
            }
        }
    }
}
