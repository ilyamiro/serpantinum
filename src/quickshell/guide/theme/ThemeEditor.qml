import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import "../../"
import "../../reusables"

GuideModal {
    id: themeEditorPopup

    title: themeEditorPopup.editingThemeName === ""
        ? I18n.t("guide.theme_editor.title", "Create custom theme")
        : I18n.t("guide.theme_editor.edit_title", "Edit custom theme")
    preferredWidth: s(680)
    padding: s(20)
    cornerRadius: ThemeBackend.clampedBorderRadius
    contentSpacing: s(16)

    property real tileWidth: 0
    property string editingThemeName: ""
    property var currentColors: ({})

    readonly property var colorKeys: [
        "base", "mantle", "crust",
        "surface0", "surface1", "surface2",
        "overlay0", "overlay1", "overlay2",
        "subtext0", "subtext1", "text",
        "lavender", "blue", "sapphire", "sky", "teal", "green",
        "yellow", "peach", "maroon", "red", "mauve", "pink", "flamingo", "rosewater"
    ]

    readonly property var colorTranslationKeys: ({
        "surface0": "surf0",
        "surface1": "surf1",
        "surface2": "surf2",
        "overlay0": "over0",
        "overlay1": "over1",
        "overlay2": "over2",
        "subtext0": "sub0",
        "subtext1": "sub1"
    })

    signal saveRequested(var themeObj)

    function colorLabel(key) {
        let translationKey = colorTranslationKeys[key] || key;
        return I18n.t("guide.theme_editor.colors." + translationKey, key);
    }

    function openForNew() {
        editingThemeName = "";
        themeNameInput.text = "";

        let initial = {};
        for (let i = 0; i < colorKeys.length; i++) {
            let k = colorKeys[i];
            initial[k] = ThemeBackend[k] !== undefined
                ? ThemeBackend[k].toString()
                : "#000000";
        }

        currentColors = initial;
        open();
        themeNameInput.forceInputFocus();
    }

    function openForEdit(themeObj) {
        if (!themeObj) return;

        editingThemeName = themeObj.name || "";
        themeNameInput.text = editingThemeName;

        let initial = {};
        let src = themeObj.colors || {};

        for (let i = 0; i < colorKeys.length; i++) {
            let k = colorKeys[i];

            if (src[k] !== undefined) {
                initial[k] = src[k];
            } else {
                initial[k] = ThemeBackend[k] !== undefined
                    ? ThemeBackend[k].toString()
                    : "#000000";
            }
        }

        currentColors = initial;
        open();
        themeNameInput.forceInputFocus();
    }

    function commitSave() {
        let name = themeNameInput.text.trim();

        if (!name) {
            themeNameInput.triggerShake();
            return;
        }

        let themeObj = {
            "name": name,
            "isCustom": true,
            "category": "user",
            "colors": currentColors
        };

        themeEditorPopup.saveRequested(themeObj);
        close();
    }

    RowLayout {
        Layout.fillWidth: true
        spacing: themeEditorPopup.s(10)

        Input {
            id: themeNameInput
            Layout.fillWidth: true
            Layout.preferredHeight: themeEditorPopup.s(36)
            placeholderText: I18n.t("guide.theme_editor.name_placeholder", "Theme name...")
            baseColor: ThemeBackend.surface0
            accentColor: ThemeBackend.mauve
            textColor: ThemeBackend.text
            subTextColor: ThemeBackend.subtext0
            borderColor: Qt.alpha(ThemeBackend.surface2, 0.6)
            cornerRadius: ThemeBackend.borderRadius
            fontPixelSize: themeEditorPopup.s(12)
            onAccepted: themeEditorPopup.commitSave()
        }

        IconButton {
            size: themeEditorPopup.s(36)
            Layout.preferredWidth: themeEditorPopup.s(36)
            Layout.preferredHeight: themeEditorPopup.s(36)
            cornerRadius: ThemeBackend.borderRadius
            buttonIcon: "󰄬"
            iconFontSize: themeEditorPopup.s(16)
            accentColor: ThemeBackend.mauve
            textColor: ThemeBackend.crust
            onClicked: themeEditorPopup.commitSave()
        }
    }

    Flickable {
        Layout.fillWidth: true
        Layout.preferredHeight: themeEditorPopup.s(320)
        contentHeight: colorsGrid.implicitHeight
        contentWidth: width
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        ScrollBar.vertical: StyledScrollBar {
            rootObj: themeEditorPopup.rootObj
        }

        GridLayout {
            id: colorsGrid
            width: parent.width - themeEditorPopup.s(8)
            columns: 2
            rowSpacing: themeEditorPopup.s(8)
            columnSpacing: themeEditorPopup.s(12)

            Repeater {
                model: themeEditorPopup.colorKeys

                delegate: RowLayout {
                    Layout.fillWidth: true
                    spacing: themeEditorPopup.s(8)

                    Rectangle {
                        Layout.preferredWidth: themeEditorPopup.s(28)
                        Layout.preferredHeight: themeEditorPopup.s(28)
                        radius: themeEditorPopup.s(6)
                        color: themeEditorPopup.currentColors[modelData] || "#000000"
                    }

                    Text {
                        text: themeEditorPopup.colorLabel(modelData)
                        color: ThemeBackend.text
                        font.family: ThemeBackend.fontFamily
                        font.pixelSize: themeEditorPopup.s(12)
                        Layout.preferredWidth: themeEditorPopup.s(80)
                        elide: Text.ElideRight
                    }

                    Input {
                        Layout.fillWidth: true
                        Layout.preferredHeight: themeEditorPopup.s(28)
                        text: themeEditorPopup.currentColors[modelData] || ""
                        baseColor: ThemeBackend.surface0
                        accentColor: ThemeBackend.mauve
                        textColor: ThemeBackend.text
                        subTextColor: ThemeBackend.subtext0
                        borderColor: Qt.alpha(ThemeBackend.surface2, 0.6)
                        cornerRadius: themeEditorPopup.s(6)
                        fontPixelSize: themeEditorPopup.s(11)

                        onTextEdited: newText => {
                            let c = themeEditorPopup.currentColors;
                            c[modelData] = newText;
                            themeEditorPopup.currentColors = c;
                        }
                    }
                }
            }
        }
    }
}
