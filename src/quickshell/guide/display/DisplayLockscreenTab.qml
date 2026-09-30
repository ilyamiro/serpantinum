import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
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

    readonly property var layouts: [
        { value: "default", title: "Default", subtitle: "Wide dashboard", description: "The original Serpantinum dashboard with weather and system wings." },
        { value: "compact", title: "Bloom", subtitle: "Single card", description: "A calm centered card with the important sign-in controls." },
        { value: "focus", title: "Orbit", subtitle: "Focused entry", description: "A larger centered sign-in surface with less surrounding information." },
        { value: "tessera", title: "Tessera", subtitle: "Layered card", description: "A compact layered arrangement with a stronger panel frame." }
    ]

    function selectedValue() {
        const settings = (typeof Config !== "undefined" && Config.rawSettings) ? Config.rawSettings.lockscreen : null
        const value = settings && settings.layout ? settings.layout : "default"
        return layouts.some(item => item.value === value) ? value : "default"
    }

    function choose(value) {
        const current = (typeof Config !== "undefined" && typeof Config.getSetting === "function")
            ? Config.getSetting("lockscreen", { layout: "default" })
            : { layout: "default" }
        current.layout = value
        if (typeof Config !== "undefined" && typeof Config.setSetting === "function")
            Config.setSetting("lockscreen", current)
    }

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
                title: "Lockscreen style"
                description: "Select a style to preview the complete lockscreen arrangement."
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: rootObj.s(250)
                radius: ThemeBackend.borderRadius * 1.25
                color: ThemeBackend.crust
                clip: true

                Loader {
                    anchors.fill: parent
                    anchors.margins: 1
                    source: "LockscreenPreview.qml"
                    property string previewStyle: root.selectedValue()
                    onLoaded: item.style = previewStyle
                    onPreviewStyleChanged: if (item) item.style = previewStyle
                }

                Rectangle {
                    anchors.fill: parent
                    radius: ThemeBackend.borderRadius * 1.25
                    color: "transparent"
                    border.width: 1
                    border.color: Qt.alpha(ThemeBackend.surface2, 0.7)
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: rootObj.s(8)

                Text {
                    text: root.layouts.find(item => item.value === root.selectedValue()).title
                    color: ThemeBackend.text
                    font.family: ThemeBackend.fontFamily
                    font.pixelSize: rootObj.s(15)
                    font.weight: Font.Bold
                }
                Text {
                    Layout.fillWidth: true
                    text: root.layouts.find(item => item.value === root.selectedValue()).description
                    color: ThemeBackend.subtext0
                    font.family: ThemeBackend.fontFamily
                    font.pixelSize: rootObj.s(10)
                    elide: Text.ElideRight
                }

                Rectangle {
                    Layout.alignment: Qt.AlignRight
                    implicitWidth: rootObj.s(128)
                    implicitHeight: rootObj.s(34)
                    radius: height / 2
                    color: ThemeBackend.blue
                    Row {
                        anchors.centerIn: parent
                        spacing: rootObj.s(6)
                        Text { text: "󰏘"; color: ThemeBackend.crust; font.pixelSize: rootObj.s(14) }
                        Text { text: "Choose style"; color: ThemeBackend.crust; font.pixelSize: rootObj.s(11); font.weight: Font.DemiBold }
                    }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            const current = Config.getSetting("lockscreen", { layout: "default" })
                            current.pickerOpen = true
                            Config.setSetting("lockscreen", current)
                        }
                    }
                }
            }

            Flickable {
                visible: false
                Layout.fillWidth: true
                Layout.preferredHeight: rootObj.s(120)
                contentWidth: stylesRow.width
                clip: true
                boundsBehavior: Flickable.StopAtBounds

                Row {
                    id: stylesRow
                    spacing: rootObj.s(8)

                    Repeater {
                        model: root.layouts
                        delegate: Item {
                            id: thumbnail
                            required property var modelData
                            width: rootObj.s(148)
                            height: rootObj.s(112)
                            readonly property bool selected: root.selectedValue() === modelData.value

                            Rectangle {
                                anchors.fill: parent
                                radius: ThemeBackend.borderRadius
                                color: thumbnail.selected ? Qt.alpha(ThemeBackend.mauve, 0.18) : ThemeBackend.surface0
                                border.width: thumbnail.selected ? 2 : 1
                                border.color: thumbnail.selected ? ThemeBackend.mauve : ThemeBackend.surface1
                                clip: true

                                Loader {
                                    anchors.left: parent.left
                                    anchors.right: parent.right
                                    anchors.top: parent.top
                                    anchors.margins: 4
                                    height: rootObj.s(78)
                                    source: "LockscreenPreview.qml"
                                    property string previewStyle: thumbnail.modelData.value
                                    onLoaded: { item.style = previewStyle; item.thumbnail = true }
                                    onPreviewStyleChanged: if (item) item.style = previewStyle
                                }

                                Text {
                                    anchors.left: parent.left
                                    anchors.leftMargin: rootObj.s(8)
                                    anchors.bottom: parent.bottom
                                    anchors.bottomMargin: rootObj.s(7)
                                    text: thumbnail.modelData.title
                                    color: ThemeBackend.text
                                    font.family: ThemeBackend.fontFamily
                                    font.pixelSize: rootObj.s(11)
                                    font.weight: Font.DemiBold
                                }

                                Text {
                                    anchors.right: parent.right
                                    anchors.rightMargin: rootObj.s(8)
                                    anchors.bottom: parent.bottom
                                    anchors.bottomMargin: rootObj.s(7)
                                    visible: thumbnail.selected
                                    text: "✓"
                                    color: ThemeBackend.mauve
                                    font.pixelSize: rootObj.s(14)
                                    font.bold: true
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.choose(thumbnail.modelData.value)
                                }
                            }
                        }
                    }
                }
            }

            SettingsRow {
                rootObj: root.rootObj
                icon: "󰍹"
                title: "Shared security flow"
                description: "The previews are visual only; every style uses the same PAM authentication and password handling."
                titlePixelSize: 12
                descriptionPixelSize: 10
            }
        }
    }
}
