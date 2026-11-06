import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import "../../"
import "../../reusables"

DisplayMainState {
    id: displayTabRoot
    subTabIndex: 0

    Flickable {
        anchors.fill: parent
        anchors.topMargin: rootObj.s(8)
        anchors.leftMargin: rootObj.s(8)
        anchors.rightMargin: rootObj.s(8)
        anchors.bottomMargin: rootObj.s(4)
        contentHeight: settingsCol.implicitHeight + rootObj.s(16)
        contentWidth: width
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        ScrollBar.vertical: ScrollBar {
            active: parent.moving || parent.movingVertically
            width: rootObj.s(4)
            policy: ScrollBar.AsNeeded
            contentItem: Rectangle {
                implicitWidth: rootObj.s(4)
                radius: rootObj.s(2)
                color: ThemeBackend.surface2
            }
        }

        ColumnLayout {
            id: settingsCol
            width: parent.width - (parent.contentHeight > parent.height ? rootObj.s(6) : 0)
            spacing: rootObj.s(12)

            DisplayNotice {
                rootObj: displayTabRoot.rootObj
                shown: displayTabRoot.txnPending
                icon: "󰍹"
                accent: ThemeBackend.peach
                title: I18n.t("guide.display.txn.keep_title")
                message: I18n.t("guide.display.txn.keep_message", { "n": Math.max(0, Math.ceil(displayTabRoot.txnRemaining)) })

                ClickButton {
                    implicitHeight: rootObj.s(32)
                    enabled: !displayTabRoot.txnBusy
                    cornerRadius: ThemeBackend.borderRadius
                    horizontalPadding: rootObj.s(14)
                    buttonText: I18n.t("guide.display.txn.revert")
                    buttonIcon: "󰜺"
                    iconFontSize: rootObj.s(14)
                    textFontSize: rootObj.s(12)
                    accentColor: ThemeBackend.surface1
                    onClicked: displayTabRoot.txnRevert()
                }

                ClickButton {
                    implicitHeight: rootObj.s(32)
                    enabled: !displayTabRoot.txnBusy
                    cornerRadius: ThemeBackend.borderRadius
                    horizontalPadding: rootObj.s(14)
                    buttonText: I18n.t("guide.display.txn.keep")
                    buttonIcon: "󰄬"
                    iconFontSize: rootObj.s(14)
                    textFontSize: rootObj.s(12)
                    accentColor: ThemeBackend.mauve
                    textColor: ThemeBackend.base
                    onClicked: displayTabRoot.txnConfirm()
                }
            }

            DisplayNotice {
                rootObj: displayTabRoot.rootObj
                shown: displayTabRoot.txnNotice !== "" && !displayTabRoot.txnPending
                icon: displayTabRoot.txnNoticeError ? "󰀦" : "󰋼"
                accent: displayTabRoot.txnNoticeError ? ThemeBackend.red : ThemeBackend.mauve
                message: displayTabRoot.txnNotice
            }

            DisplayNotice {
                rootObj: displayTabRoot.rootObj
                shown: displayTabRoot.txnShowPersistHint && !displayTabRoot.txnPending
                icon: "󰆓"
                accent: ThemeBackend.blue
                title: I18n.t("guide.display.txn.persist_title")
                message: I18n.t("guide.display.txn.persist_message")
                detail: 'require("serpantinum/monitors")'
            }

            DisplayArrangementMap {
                tab: displayTabRoot
                visible: displayTabRoot.txnSupported && displayTabRoot.txnAvailable
            }

            DisplayProfilesBar {
                tab: displayTabRoot
                visible: displayTabRoot.txnSupported && displayTabRoot.txnAvailable
            }

            Repeater {
                model: displayTabRoot.monitorsList
                delegate: DisplayMonitorCard { tab: displayTabRoot }
            }
        }
    }
}
