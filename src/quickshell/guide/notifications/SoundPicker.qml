import QtQuick
import QtQuick.Layouts
import Quickshell
import "../../"
import "../../reusables"

FilePicker {
    id: soundPickerRoot

    preferredWidth: Scaler.s(1040)
    previewWidth: Scaler.s(340)
    titleText: typeof I18n !== "undefined" ? I18n.t("guide.sound_picker.title", "Select notification sound") : "Select notification sound"
    nameFilters: ["*.wav", "*.ogg", "*.mp3", "*.flac", "*.opus", "*.oga", "*.m4a", "*.aac"]
    showPreview: true

    extraPlaces: [
        { name: typeof I18n !== "undefined" ? I18n.t("guide.sound_picker.places.user_sounds", "User sounds") : "User sounds", icon: "󰎈", path: "file://" + Caching.xdgDataHome + "/sounds" },
        { name: typeof I18n !== "undefined" ? I18n.t("guide.sound_picker.places.system_sounds", "System sounds") : "System sounds", icon: "󰓃", path: "file:///usr/share/sounds" }
    ]

    signal soundSelected(string filePath, string fileName)

    onFileSelected: function(filePath, fileName) {
        soundPickerRoot.soundSelected(filePath, fileName);
    }

    function openPicker(initialPath) {
        openWithOptionalPath(initialPath || "");
    }

    previewComponent: Component {
        Item {
            anchors.fill: parent

            Rectangle {
                anchors.fill: parent
                color: gf1.active ? "transparent" : ThemeBackend.surface0

                GlassFill {
                    id: gf1
                    anchors.fill: parent
                    radius: parent.radius
                    tintColor: ThemeBackend.surface0
                    tintAmount: 0.25
                }
                radius: soundPickerRoot.crMedium
                clip: true

                ColumnLayout {
                    anchors.centerIn: parent
                    width: parent.width - Scaler.s(32)
                    spacing: Scaler.s(16)

                    Rectangle {
                        Layout.alignment: Qt.AlignHCenter
                        Layout.preferredWidth: Scaler.s(80)
                        Layout.preferredHeight: Scaler.s(80)
                        radius: soundPickerRoot.crLarge
                        color: gf2.active ? "transparent" : ThemeBackend.surface1

                        GlassFill {
                            id: gf2
                            anchors.fill: parent
                            radius: parent.radius
                            tintColor: ThemeBackend.surface1
                            tintAmount: 0.25
                        }

                        Text {
                            anchors.centerIn: parent
                            text: "󰎈"
                            font.family: ThemeBackend.iconFont
                            font.pixelSize: Scaler.s(36)
                            color: soundPickerRoot.selectedFilePath !== "" ? ThemeBackend.mauve : ThemeBackend.subtext0
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
                                if (soundPickerRoot.selectedFileName !== "") {
                                    try {
                                        return decodeURIComponent(soundPickerRoot.selectedFileName);
                                    } catch (e) {
                                        return soundPickerRoot.selectedFileName;
                                    }
                                }
                                return typeof I18n !== "undefined" ? I18n.t("guide.sound_picker.no_sound_selected", "No sound selected") : "No sound selected";
                            }
                            font.family: ThemeBackend.fontFamily
                            font.weight: Font.Bold
                            font.pixelSize: Scaler.s(14)
                            color: soundPickerRoot.selectedFileName !== "" ? ThemeBackend.text : ThemeBackend.subtext0
                            elide: Text.ElideMiddle
                        }

                        Text {
                            Layout.fillWidth: true
                            horizontalAlignment: Text.AlignHCenter
                            text: soundPickerRoot.selectedFilePath !== "" ? soundPickerRoot.selectedFilePath : ""
                            font.family: ThemeBackend.fontFamily
                            font.pixelSize: Scaler.s(11)
                            color: ThemeBackend.subtext0
                            elide: Text.ElideMiddle
                            visible: soundPickerRoot.selectedFilePath !== ""
                        }
                    }

                    IconButton {
                        id: playSoundButton
                        Layout.alignment: Qt.AlignHCenter
                        Layout.preferredWidth: Scaler.s(44)
                        Layout.preferredHeight: Scaler.s(44)
                        cornerRadius: Scaler.s(12)
                        buttonIcon: "󰐊"
                        iconFontSize: Scaler.s(22)
                        accentColor: ThemeBackend.surface1
                        textColor: isHoveredOrHighlighted ? ThemeBackend.green : ThemeBackend.text
                        enabled: soundPickerRoot.selectedFilePath !== ""
                        opacity: enabled ? 1.0 : 0.4
                        onClicked: {
                            if (typeof Sounds !== "undefined" && typeof Sounds.play === "function") {
                                Sounds.play(soundPickerRoot.selectedFilePath);
                            }
                        }
                    }
                }
            }
        }
    }
}
