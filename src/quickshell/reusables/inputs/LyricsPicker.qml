import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import "../../"
import "../"

PanelWindow {
    id: lyricsPickerWindow

    color: "transparent"
    visible: false

    WlrLayershell.namespace: "qs-lyrics-picker"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand

    exclusionMode: ExclusionMode.Ignore
    focusable: true

    anchors.top: true
    anchors.left: true
    anchors.right: true
    anchors.bottom: true

    margins.left: 0
    margins.top: 0

    property var targetScreen: null
    screen: targetScreen || (Quickshell.screens.length > 0 ? Quickshell.screens[0] : null)

    readonly property bool opened: filePicker.opened

    signal lyricsSelected(string filePath, string fileName)

    function openPicker(initialPath) {
        visible = true;
        Qt.callLater(() => {
            filePicker.openWithOptionalPath(initialPath || "");
        });
    }

    function closePicker() {
        filePicker.close();
        visible = false;
    }

    Rectangle {
        anchors.fill: parent
        color: Qt.rgba(ThemeBackend.crust.r, ThemeBackend.crust.g, ThemeBackend.crust.b, 0.45)
        visible: filePicker.opened

        MouseArea {
            anchors.fill: parent
            onClicked: lyricsPickerWindow.closePicker()
        }
    }

    FilePicker {
        id: filePicker
        rootObj: lyricsPickerWindow

        preferredWidth: Scaler.s(960)
        preferredHeight: Scaler.s(640)
        previewWidth: Scaler.s(340)
        titleText: typeof I18n !== "undefined" ? I18n.t("guide.lyrics_picker.title", "Select lyrics file") : "Select lyrics file"
        nameFilters: ["*.lrc", "*.txt", "*.yrc"]
        showPreview: true

        places: [
            { name: typeof I18n !== "undefined" ? I18n.t("guide.file_picker.places.home") : "Home", icon: "󰋜", path: "file://" + (Quickshell.env("HOME") || "") },
            { name: typeof I18n !== "undefined" ? I18n.t("guide.file_picker.places.downloads") : "Downloads", icon: "󰇚", path: "file://" + (Quickshell.env("HOME") || "") + "/Downloads" },
            { name: typeof I18n !== "undefined" ? I18n.t("guide.file_picker.places.music", "Music") : "Music", icon: "󰎈", path: "file://" + (Quickshell.env("HOME") || "") + "/Music" },
            { name: typeof I18n !== "undefined" ? I18n.t("guide.file_picker.places.documents", "Documents") : "Documents", icon: "󰈙", path: "file://" + (Quickshell.env("HOME") || "") + "/Documents" }
        ]

        onFileSelected: function(filePath, fileName) {
            lyricsPickerWindow.lyricsSelected(filePath, fileName);
            lyricsPickerWindow.visible = false;
        }

        onClosed: {
            lyricsPickerWindow.visible = false;
        }

        previewComponent: Component {
            Item {
                anchors.fill: parent

                Rectangle {
                    anchors.fill: parent
                    color: ThemeBackend.surface0
                    radius: filePicker.crMedium
                    clip: true

                    ColumnLayout {
                        anchors.centerIn: parent
                        width: parent.width - Scaler.s(32)
                        spacing: Scaler.s(16)

                        Rectangle {
                            Layout.alignment: Qt.AlignHCenter
                            Layout.preferredWidth: Scaler.s(80)
                            Layout.preferredHeight: Scaler.s(80)
                            radius: filePicker.crLarge
                            color: ThemeBackend.surface1

                            Text {
                                anchors.centerIn: parent
                                text: "󰈔"
                                font.family: ThemeBackend.iconFont
                                font.pixelSize: Scaler.s(36)
                                color: filePicker.selectedFilePath !== "" ? ThemeBackend.accent : ThemeBackend.subtext0
                            }
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            Layout.alignment: Qt.AlignHCenter
                            spacing: Scaler.s(4)

                            Text {
                                Layout.fillWidth: true
                                horizontalAlignment: Text.AlignHCenter
                                text: {
                                    if (filePicker.selectedFileName !== "") {
                                        try {
                                            return decodeURIComponent(filePicker.selectedFileName);
                                        } catch (e) {
                                            return filePicker.selectedFileName;
                                        }
                                    }
                                    return typeof I18n !== "undefined" ? I18n.t("guide.lyrics_picker.no_lyrics_selected", "No lyrics selected") : "No lyrics selected";
                                }
                                font.family: ThemeBackend.fontFamily
                                font.weight: Font.Bold
                                font.pixelSize: Scaler.s(14)
                                color: filePicker.selectedFileName !== "" ? ThemeBackend.text : ThemeBackend.subtext0
                                elide: Text.ElideMiddle
                            }

                            Text {
                                Layout.fillWidth: true
                                horizontalAlignment: Text.AlignHCenter
                                text: filePicker.selectedFilePath !== "" ? filePicker.selectedFilePath : ""
                                font.family: ThemeBackend.fontFamily
                                font.pixelSize: Scaler.s(11)
                                color: ThemeBackend.subtext0
                                elide: Text.ElideMiddle
                                visible: filePicker.selectedFilePath !== ""
                            }
                        }
                    }
                }
            }
        }
    }
}
