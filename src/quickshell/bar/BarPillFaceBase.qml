import QtQuick
import "../reusables"
import "../"

BarFaceBase {
    id: pillRoot

    property string pillStyle: "button"
    readonly property bool isTextStyle: pillStyle === "text"
    property bool pillVisibleCondition: true
    property bool useImplicitPillLength: false
    property bool previewPadding: true
    property bool slideVertical: false
    property int revealDelay: 0
    property bool showLayout: (!barWindow || isPreview) ? true : (revealDelay > 0 ? false : ((!module || module.moduleActive) && barWindow.isStartupReady && barWindow.isDataReady))
    property real textSpacingVertical: s(isCompact ? 2 : 3)
    property real textSpacingHorizontal: s(isCompact ? 5 : 6)
    property int acceptedTextButtons: Qt.LeftButton
    property Component pillSourceComponent: null

    readonly property alias pillLoader: pillLoader
    readonly property alias textLayout: textLayout
    readonly property alias textMouseArea: textMouseArea
    default property alias textContent: textLayout.data

    signal textClicked(var mouse)
    signal textWheel(var wheel)

    readonly property real pillLength: {
        if (!pillLoader.item) return 0;
        if (useImplicitPillLength) return isVertical ? pillLoader.item.implicitHeight : pillLoader.item.implicitWidth;
        return isVertical ? pillLoader.item.height : pillLoader.item.width;
    }
    readonly property real textLength: isVertical ? textLayout.implicitHeight : textLayout.implicitWidth

    property real targetLength: {
        if (module && !module.moduleActive) return 0;
        if (!pillVisibleCondition) return 0;
        if (isTextStyle) {
            return (textLength > 0) ? (textLength + ((isPreview && !previewPadding) ? 0 : s(isCompact ? (isVertical ? 14 : 12) : 16))) : 0;
        }
        return (pillLength > 0) ? (pillLength + ((isPreview && !previewPadding) ? 0 : s(isCompact ? 8 : 10))) : 0;
    }
    property bool isFaceVisible: showLayout && pillVisibleCondition && targetLength > 0

    function syncImplicitSize() {
        let cross = module ? module.thickness : (parent ? (isVertical ? parent.width : parent.height) : 0);
        implicitWidth = isVertical ? cross : targetLength;
        implicitHeight = isVertical ? targetLength : cross;
    }

    onTargetLengthChanged: syncImplicitSize()
    onIsVerticalChanged: syncImplicitSize()
    onModuleChanged: syncImplicitSize()
    onParentChanged: syncImplicitSize()

    Component.onCompleted: Qt.callLater(pillRoot.syncImplicitSize)

    Timer {
        running: pillRoot.revealDelay > 0 && !pillRoot.isPreview && (!module || module.moduleActive) && barWindow && barWindow.isStartupReady && barWindow.isDataReady && !pillRoot.showLayout
        interval: Math.max(1, pillRoot.revealDelay)
        onTriggered: pillRoot.showLayout = true
    }

    transform: Translate {
        x: (pillRoot.isVertical || pillRoot.showLayout) ? 0 : pillRoot.s(60)
        y: (!pillRoot.slideVertical || !pillRoot.isVertical || pillRoot.showLayout) ? 0 : pillRoot.s(60)
        Behavior on x { NumberAnimation { duration: 800; easing.type: Easing.OutQuint } }
        Behavior on y { NumberAnimation { duration: 800; easing.type: Easing.OutQuint } }
    }

    MouseArea {
        id: textMouseArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        enabled: pillRoot.isTextStyle && !pillRoot.isPreview
        acceptedButtons: pillRoot.acceptedTextButtons
        onClicked: mouse => pillRoot.textClicked(mouse)
        onWheel: wheel => pillRoot.textWheel(wheel)
    }

    AxisFlow {
        id: textLayout
        vertical: pillRoot.isVertical
        horizontalItemAlignment: Grid.AlignHCenter
        verticalItemAlignment: Grid.AlignVCenter
        visible: pillRoot.isTextStyle
        anchors.centerIn: parent
        spacing: pillRoot.isVertical ? pillRoot.textSpacingVertical : pillRoot.textSpacingHorizontal
        opacity: pillRoot.showLayout ? 1.0 : 0.0
        Behavior on opacity { NumberAnimation { duration: 400; easing.type: Easing.OutCubic } }
    }

    Loader {
        id: pillLoader
        visible: !pillRoot.isTextStyle
        anchors.centerIn: parent
        sourceComponent: pillRoot.pillSourceComponent
    }
}
