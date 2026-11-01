import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import "../../../"
import "../../../reusables"
import "../../../reusables/guide"

BarModuleCard {
    id: card
    title: I18n.t("guide.bar.modules.vis", "Visualizer")
    moduleId: "vis"

    function syncAlignSwitch() {
        let a = card.tab.visAlignment;
        if (visAlignSwitch) {
            if (card.tab.isSideBar) {
                visAlignSwitch.currentIndex = (a === "left" || a === "top") ? 0 : ((a === "right" || a === "bottom") ? 2 : 1);
            } else {
                visAlignSwitch.currentIndex = (a === "top" || a === "left") ? 0 : ((a === "bottom" || a === "right") ? 2 : 1);
            }
        }
    }

    Connections {
        target: card.tab
        function onVisAlignmentChanged() { card.syncAlignSwitch(); }
        function onIsSideBarChanged() { card.syncAlignSwitch(); }
    }

    widgetComponent: Component {
        BarPreviewWidget {
            property int barCount: tab.visBarCount
            property string visAlignment: tab.visAlignment
            property bool visContinuous: tab.visContinuous
        }
    }

    SettingsRow {
        rootObj: card.rootObj
        settingId: "bar_vis_bar_count"
        searchKeywords: "visualizer bars count amount cava"
        baseColor: Qt.alpha(ThemeBackend.surface1, 0.35)
        icon: "󰝚"
        title: I18n.t("guide.bar.vis.bars.title", "Amount of bars")
        description: I18n.t("guide.bar.vis.bars.desc", "Number of frequency bars to display")

        NumberSelector {
            id: visBarCountSelector
            Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
            implicitWidth: rootObj.s(140)
            implicitHeight: rootObj.s(32)
            from: 4
            to: 64
            stepSize: 1
            decimals: 0
            value: card.tab.visBarCount
            baseColor: ThemeBackend.surface0
            accentColor: ThemeBackend.accent
            buttonColor: ThemeBackend.surface1
            buttonTextColor: ThemeBackend.text
            textColor: ThemeBackend.text
            subTextColor: ThemeBackend.subtext0
            borderColor: Qt.alpha(ThemeBackend.surface2, 0.6)
            cornerRadius: ThemeBackend.borderRadius
            fontFamily: ThemeBackend.fontFamily
            fontPixelSize: rootObj.s(12)
            onValueChanged: {
                let rounded = Math.round(visBarCountSelector.value);
                if (card.tab.visBarCount !== rounded) {
                    card.tab.setVisBarCount(rounded);
                }
            }
            onTriggered: {
                card.tab.setVisBarCount(Math.round(visBarCountSelector.value));
            }
        }
    }

    SettingsRow {
        rootObj: card.rootObj
        settingId: "bar_vis_alignment"
        searchKeywords: "visualizer alignment center top bottom align"
        baseColor: Qt.alpha(ThemeBackend.surface1, 0.35)
        icon: "󰆑"
        title: I18n.t("guide.bar.vis.alignment.title", "Alignment")
        description: I18n.t("guide.bar.vis.alignment.desc", "Center the visualizer or align to top or bottom")

        Switch {
            id: visAlignSwitch
            Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
            implicitWidth: rootObj.s(220)
            implicitHeight: rootObj.s(32)
            cornerRadius: ThemeBackend.borderRadius
            fontPixelSize: rootObj.s(11)
            options: card.tab.isSideBar
                ? [
                    I18n.t("guide.bar.vis.align.left", "Left"),
                    I18n.t("guide.bar.vis.align.center", "Center"),
                    I18n.t("guide.bar.vis.align.right", "Right")
                ]
                : [
                    I18n.t("guide.bar.vis.align.top", "Top"),
                    I18n.t("guide.bar.vis.align.center", "Center"),
                    I18n.t("guide.bar.vis.align.bottom", "Bottom")
                ]
            currentIndex: {
                let a = card.tab.visAlignment;
                if (card.tab.isSideBar) {
                    if (a === "left" || a === "top") return 0;
                    if (a === "right" || a === "bottom") return 2;
                    return 1;
                } else {
                    if (a === "top" || a === "left") return 0;
                    if (a === "bottom" || a === "right") return 2;
                    return 1;
                }
            }
            accentColor: ThemeBackend.accent
            baseColor: ThemeBackend.surface0
            textColor: ThemeBackend.text
            activeTextColor: ThemeBackend.crust
            onValueChanged: function(index, value) {
                let align = "center";
                if (card.tab.isSideBar) {
                    align = index === 0 ? "left" : (index === 2 ? "right" : "center");
                } else {
                    align = index === 0 ? "top" : (index === 2 ? "bottom" : "center");
                }
                card.tab.setVisAlignment(align);
            }
        }
    }

    SettingsRow {
        rootObj: card.rootObj
        settingId: "bar_vis_continuous"
        searchKeywords: "visualizer continuous wave smooth fluid"
        baseColor: Qt.alpha(ThemeBackend.surface1, 0.35)
        icon: "󰓃"
        title: I18n.t("guide.bar.vis.continuous.title", "Continuous wave")
        description: I18n.t("guide.bar.vis.continuous.desc", "Render a smooth fluid wave instead of discrete bars")

        Toggle {
            Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
            checked: card.tab.visContinuous
            accentColor: ThemeBackend.accent
            baseColor: ThemeBackend.surface1
            handleColor: ThemeBackend.crust
            handleOffColor: ThemeBackend.text
            onToggled: function(c) {
                card.tab.setVisContinuous(c);
            }
        }
    }
}
