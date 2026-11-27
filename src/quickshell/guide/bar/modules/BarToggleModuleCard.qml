import QtQuick
import QtQuick.Layouts
import "../../../"
import "../../../bar"
import "../../../reusables"
import "../../../reusables/guide"

BarModuleCard {
    id: card

    property string styleKey: ""
    property var toggles: []

    readonly property string effectiveStyleKey: styleKey !== "" ? styleKey : card.tab.styleKeyFor(card.moduleId)

    styles: BarModuleRegistry.variantList(card.moduleId)
    currentStyle: String((card.effectiveStyleKey && card.tab.barValues[card.effectiveStyleKey]) || BarModuleRegistry.defaultVariant(card.moduleId))
    onStyleSelected: id => card.tab.setModuleStyle(card.moduleId, id)

    widgetComponent: Component {
        BarPreviewWidget {
            property string wifiStyle: variantId !== "" ? variantId : tab.wifiStyle
            property bool wifiShowIcon: tab.wifiShowIcon
            property bool wifiShowName: tab.wifiShowName
            property string btStyle: variantId !== "" ? variantId : tab.btStyle
            property bool btShowIcon: tab.btShowIcon
            property bool btShowName: tab.btShowName
            property string volStyle: variantId !== "" ? variantId : tab.volStyle
            property bool volShowIcon: tab.volShowIcon
            property bool volShowPercent: tab.volShowPercent
            property string batStyle: variantId !== "" ? variantId : tab.batStyle
            property bool batShowPercent: tab.batShowPercent
            property bool batShowIcon: tab.batShowIcon
            property string kbStyle: variantId !== "" ? variantId : tab.kbStyle
            property bool kbShowIcon: tab.kbShowIcon
        }
    }

    Repeater {
        model: card.toggles

        delegate: SettingsRow {
            id: toggleRow
            required property var modelData
            readonly property bool hideRow: Boolean(modelData.hideOnSideBar) && card.tab.isSideBar
            readonly property bool isChecked: Boolean(card.tab[modelData.key])
            readonly property bool peerChecked: modelData.peerKey ? Boolean(card.tab[modelData.peerKey]) : true

            rootObj: card.rootObj
            settingId: modelData.settingId || ""
            searchKeywords: modelData.keywords || ""
            baseColor: Qt.alpha(ThemeBackend.surface1, 0.35)
            icon: modelData.icon || "󰒓"
            title: modelData.title || ""
            description: modelData.desc || ""
            visible: !hideRow
            searchable: !hideRow
            hiddenByConfig: hideRow

            Toggle {
                Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                checked: toggleRow.isChecked
                enabled: modelData.peerKey ? (!checked || toggleRow.peerChecked) : true
                accentColor: ThemeBackend.mauve
                baseColor: ThemeBackend.surface1
                handleColor: ThemeBackend.crust
                handleOffColor: ThemeBackend.text
                onToggled: function(c) {
                    if (modelData.peerKey) {
                        card.tab.setPairedToggle(modelData.key, modelData.peerKey, c);
                    } else {
                        card.tab.setBarProp(modelData.key, c);
                    }
                }
            }
        }
    }
}
