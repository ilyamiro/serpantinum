import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris
import "../../../reusables"
import "../../../"

Item {
    id: root
    anchors.fill: parent
    clip: true

    property real minWidth: 180
    property real minHeight: 60
    property real maxWidth: 1200
    property real maxHeight: 600
    property real minAspect: 1.2
    property real maxAspect: 5.0
    property bool isRound: false

    property bool lyricsSubscribed: false

    property var widgetData: null
    property var widget: null
    property string lyricsAlignment: "left"

    function updateLyricsAlignment() {
        let w = root.widgetData || root.widget || (parent && (parent.widgetData || parent.widget || parent.item)) || null;
        if (w) {
            if (w.lyricsAlignment !== undefined && w.lyricsAlignment !== "") {
                root.lyricsAlignment = w.lyricsAlignment;
            } else if (w.alignment !== undefined && w.alignment !== "") {
                root.lyricsAlignment = w.alignment;
            }
        }
    }

    onWidgetDataChanged: updateLyricsAlignment()
    onWidgetChanged: updateLyricsAlignment()

    Connections {
        target: root.widgetData || root.widget || (parent ? (parent.widgetData || parent.widget || parent.item) : null)
        ignoreUnknownSignals: true
        function onLyricsAlignmentChanged() {
            root.updateLyricsAlignment();
        }
        function onAlignmentChanged() {
            root.updateLyricsAlignment();
        }
    }

    readonly property real widgetRadius: root.isRound ? (Math.min(root.width, root.height) / 2) : (ThemeBackend.borderRadius * 2)

    function syncSubscription() {
        if (root.visible && !root.lyricsSubscribed) {
            root.lyricsSubscribed = true;
            Lyrics.subscribe();
        } else if (!root.visible && root.lyricsSubscribed) {
            root.lyricsSubscribed = false;
            Lyrics.unsubscribe();
        }
    }

    function getContrastColor(col) {
        if (!col) return "#ffffff";
        let r = Math.round(col.r * 255);
        let g = Math.round(col.g * 255);
        let b = Math.round(col.b * 255);
        let brightness = Math.round((299 * r + 587 * g + 114 * b) / 1000);
        if (brightness < 70) return "#ffffff";
        if (brightness < 120) return "#fafafa";
        if (brightness < 170) return "#f2f2f2";
        if (brightness < 210) return "#e8e8e8";
        if (brightness < 235) return "#444444";
        return "#1e1e2e";
    }

    function getEffectiveBackgroundColor() {
        let baseBg = (typeof ThemeBackend !== "undefined" && ThemeBackend.surface0) ? ThemeBackend.surface0 : Qt.color("#313244");
        if (Lyrics.isMediaActive && Boolean(MprisController.artUrl)) {
            let artCol = (typeof MprisController !== "undefined" && (MprisController.dominantColor || MprisController.backgroundColor)) ? (MprisController.dominantColor || MprisController.backgroundColor) : "";
            let crust = (typeof ThemeBackend !== "undefined" && ThemeBackend.crust) ? ThemeBackend.crust : Qt.color("#11111b");
            if (artCol) {
                let c = Qt.color(artCol);
                return Qt.rgba(
                    c.r * 0.6 + crust.r * 0.4,
                    c.g * 0.6 + crust.g * 0.4,
                    c.b * 0.6 + crust.b * 0.4,
                    1.0
                );
            }
            return Qt.rgba(
                baseBg.r * 0.6 + crust.r * 0.4,
                baseBg.g * 0.6 + crust.g * 0.4,
                baseBg.b * 0.6 + crust.b * 0.4,
                1.0
            );
        }
        return baseBg;
    }

    function getThemePrimaryColor() {
        if (typeof ThemeBackend !== "undefined") {
            if (ThemeBackend.primary) return Qt.color(ThemeBackend.primary);
            if (ThemeBackend.blue) return Qt.color(ThemeBackend.blue);
            if (ThemeBackend.mauve) return Qt.color(ThemeBackend.mauve);
        }
        if (typeof MprisController !== "undefined" && MprisController.primaryColor) {
            return Qt.color(MprisController.primaryColor);
        }
        return Qt.color("#89b4fa");
    }

    function getLuminance(col) {
        if (!col) return 0;
        let c = Qt.color(col);
        let s = [c.r, c.g, c.b].map(function(v) {
            return v <= 0.03928 ? (v / 12.92) : Math.pow((v + 0.055) / 1.055, 2.4);
        });
        return 0.2126 * s[0] + 0.7152 * s[1] + 0.0722 * s[2];
    }

    function getContrastRatio(col1, col2) {
        let l1 = getLuminance(col1);
        let l2 = getLuminance(col2);
        let lighter = Math.max(l1, l2);
        let darker = Math.min(l1, l2);
        return (lighter + 0.05) / (darker + 0.05);
    }

    function areColorsTooSimilar(c1, c2) {
        let col1 = Qt.color(c1);
        let col2 = Qt.color(c2);
        let dr = Math.abs(col1.r - col2.r);
        let dg = Math.abs(col1.g - col2.g);
        let db = Math.abs(col1.b - col2.b);
        let dist = Math.sqrt(dr * dr + dg * dg + db * db);
        if (dist < 0.28) return true;

        let isCol1Blue = (col1.b > col1.r + 0.08 && col1.b > col1.g + 0.04);
        let isCol2Blue = (col2.b > col2.r + 0.08 && col2.b > col2.g + 0.04);
        if (isCol1Blue && isCol2Blue && dist < 0.45) return true;

        return false;
    }

    function blendColors(c1, c2, ratio) {
        let col1 = Qt.color(c1);
        let col2 = Qt.color(c2);
        let t = Math.max(0.0, Math.min(1.0, ratio));
        let r = col1.r * (1.0 - t) + col2.r * t;
        let g = col1.g * (1.0 - t) + col2.r * t;
        let b = col1.b * (1.0 - t) + col2.r * t;
        return Qt.rgba(r, g, b, 1.0);
    }

    function getAdjustedLyricColor() {
        let bg = getEffectiveBackgroundColor();
        let primary = getThemePrimaryColor();
        let targetWhitish = Qt.color(getContrastColor(bg));

        let contrast = getContrastRatio(primary, bg);
        let tooSimilar = areColorsTooSimilar(primary, bg);

        if (contrast >= 5.0 && !tooSimilar) {
            return primary;
        }

        let ratios = [0.25, 0.45, 0.65, 0.80, 0.92, 1.0];
        for (let i = 0; i < ratios.length; i++) {
            let blended = blendColors(primary, targetWhitish, ratios[i]);
            let cr = getContrastRatio(blended, bg);
            let sim = areColorsTooSimilar(blended, bg);
            if (cr >= 4.5 && !sim) {
                return blended;
            }
        }

        if (typeof ThemeBackend !== "undefined") {
            let palette = [
                ThemeBackend.peach,
                ThemeBackend.yellow,
                ThemeBackend.teal,
                ThemeBackend.green,
                ThemeBackend.sapphire,
                ThemeBackend.mauve,
                ThemeBackend.pink
            ];
            for (let i = 0; i < palette.length; i++) {
                if (!palette[i]) continue;
                let c = Qt.color(palette[i]);
                let cr = getContrastRatio(c, bg);
                let sim = areColorsTooSimilar(c, bg);
                if (cr >= 5.0 && !sim) {
                    return c;
                }
            }
        }

        return targetWhitish;
    }

    readonly property color primaryColor: getThemePrimaryColor()
    readonly property color dynamicTextColor: getAdjustedLyricColor()
    readonly property color activeLineColor: root.dynamicTextColor

    readonly property real sideMargin: Math.max(Scaler.s(12), root.width * 0.05)
    readonly property real refWidth: Scaler.s(320)
    readonly property real refHeight: Scaler.s(100)
    readonly property real effectiveSize: Math.sqrt((root.width / Math.max(1, refWidth)) * (root.height / Math.max(1, refHeight)))
    readonly property real fontScale: Math.pow(Math.max(0.3, effectiveSize), 0.38)

    readonly property real baseActiveFont: Math.max(Scaler.s(11), Math.min(root.height * 0.24, Scaler.s(15) * fontScale))

    onVisibleChanged: syncSubscription()

    Component.onCompleted: {
        syncSubscription();
        updateLyricsAlignment();
    }

    Component.onDestruction: {
        if (root.lyricsSubscribed) {
            root.lyricsSubscribed = false;
            Lyrics.unsubscribe();
        }
    }

    LyricsPicker {
        id: lyricsPickerPopup
        targetScreen: (root.Window && root.Window.window) ? root.Window.window.screen : null
        onLyricsSelected: function(filePath, fileName) {
            Lyrics.loadLocalLyricsFile(filePath);
        }
    }

    Rectangle {
        id: bgContainer
        anchors.fill: parent
        color: Qt.alpha(ThemeBackend.surface0, ThemeBackend.elementOpacity)
        radius: root.widgetRadius
        clip: true

        WallpaperBlur {
            z: -1
            anchors.fill: parent
            radius: parent.radius
        }

        Rectangle {
            id: bgMask
            anchors.fill: parent
            radius: root.widgetRadius
            color: "#ffffff"
            visible: false
            layer.enabled: true
        }

        Item {
            id: artMaskedContainer
            anchors.fill: parent
            visible: Lyrics.isMediaActive && Boolean(MprisController.artUrl)
            layer.enabled: true
            layer.effect: MultiEffect {
                maskEnabled: true
                maskSource: bgMask
            }

            Image {
                id: bgArtImg
                anchors.fill: parent
                anchors.margins: -Scaler.s(36)
                source: (Lyrics.isMediaActive && MprisController.artUrl) ? (MprisController.artUrl.startsWith("file://") || MprisController.artUrl.startsWith("http") ? MprisController.artUrl : "file://" + MprisController.artUrl) : ""
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                opacity: (status === Image.Ready && source !== "") ? 1.0 : 0.0
                layer.enabled: true
                layer.effect: MultiEffect {
                    blurEnabled: true
                    blur: 0.55
                    blurMax: 36
                }

                Behavior on opacity {
                    NumberAnimation {
                        duration: 350
                        easing.type: Easing.OutQuad
                    }
                }
            }

            Rectangle {
                id: artDarkScrim
                anchors.fill: parent
                color: Qt.rgba(ThemeBackend.crust.r, ThemeBackend.crust.g, ThemeBackend.crust.b, 0.40)
            }
        }

        LyricsView {
            id: lyricsViewport
            anchors.fill: parent
            alignment: root.lyricsAlignment
            visible: Lyrics.hasLyrics
            sideMargin: root.sideMargin
            baseActiveFont: root.baseActiveFont
            lineHeight: Math.max(Scaler.s(18), root.baseActiveFont * 1.4)
            lineSpacing: Math.max(Scaler.s(2), root.baseActiveFont * 0.25)
            activeLineColor: root.activeLineColor
            inactiveLineColor: ThemeBackend.text || "#cdd6f4"
            fontFamily: ThemeBackend.fontFamily
        }

        ColumnLayout {
            anchors.centerIn: parent
            spacing: Scaler.s(6)
            visible: !Lyrics.hasLyrics
            z: 5

            Text {
                Layout.alignment: Qt.AlignHCenter
                text: "󰎈"
                font.family: ThemeBackend.iconFont
                font.pixelSize: Scaler.s(26)
                color: root.dynamicTextColor
                opacity: 0.75
            }

            Text {
                Layout.alignment: Qt.AlignHCenter
                text: {
                    if (!Lyrics.isMediaActive) return I18n.t("music.nothing_playing");
                    if (Lyrics.loading) return I18n.t("music.searching_lyrics");
                    return I18n.t("music.no_lyrics");
                }
                font.family: ThemeBackend.fontFamily
                font.weight: Font.DemiBold
                font.pixelSize: Scaler.s(12)
                color: ThemeBackend.subtext0
            }

            ClickButton {
                Layout.alignment: Qt.AlignHCenter
                Layout.topMargin: Scaler.s(4)
                visible: Lyrics.isMediaActive && !Lyrics.loading
                implicitHeight: Scaler.s(28)
                horizontalPadding: Scaler.s(14)
                cornerRadius: Scaler.s(8)
                buttonIcon: "󰈔"
                buttonText: typeof I18n !== "undefined" ? I18n.t("music.select_local_file", "Select a local file") : "Select a local file"
                iconFontSize: Scaler.s(14)
                textFontSize: Scaler.s(11)
                accentColor: ThemeBackend.surface0
                bgOpacity: ThemeBackend.elementOpacity
                textColor: ThemeBackend.text
                onClicked: {
                    lyricsPickerPopup.targetScreen = (root.Window && root.Window.window) ? root.Window.window.screen : null;
                    lyricsPickerPopup.openPicker();
                }
            }
        }
    }
}
