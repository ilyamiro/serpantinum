import QtQuick
import QtQuick.Layouts
import "../../"

Item {
    id: root

    property string text: ""
    property color color: ThemeBackend.text
    property alias font: mainText.font
    property int horizontalAlignment: Text.AlignLeft
    property real marqueeSpacing: 40
    property int pauseDuration: 3000
    property real speed: 25
    property bool active: true

    readonly property real textWidth: mainText.implicitWidth
    readonly property real scrollDistance: textWidth + marqueeSpacing
    readonly property bool canMarquee: active && (textWidth > width) && (width > 0)
    readonly property bool isRunning: scrollAnim.running
    readonly property real scrollX: marqueeContainer.x

    implicitWidth: textWidth
    implicitHeight: mainText.implicitHeight
    Layout.minimumWidth: 0
    clip: true

    function resetMarquee() {
        scrollProgress = 0.0;
        if (canMarquee) {
            scrollAnim.restart();
        } else {
            scrollAnim.stop();
        }
    }

    onCanMarqueeChanged: resetMarquee()
    onWidthChanged: resetMarquee()
    onTextChanged: resetMarquee()
    onActiveChanged: resetMarquee()

    property real scrollProgress: 0.0

    Item {
        id: marqueeContainer
        height: parent.height
        x: root.canMarquee
            ? -Math.round(root.scrollProgress * root.scrollDistance)
            : (root.horizontalAlignment === Text.AlignRight
                ? Math.max(0, root.width - root.textWidth)
                : (root.horizontalAlignment === Text.AlignHCenter
                    ? Math.max(0, Math.round((root.width - root.textWidth) / 2))
                    : 0))

        Row {
            anchors.verticalCenter: parent.verticalCenter
            spacing: root.marqueeSpacing

            Text {
                id: mainText
                text: root.text
                color: root.color
                font.family: ThemeBackend.fontFamily
                font.pixelSize: 12
            }

            Text {
                id: cloneText
                text: root.text
                color: root.color
                font.family: mainText.font.family
                font.pixelSize: mainText.font.pixelSize
                font.weight: mainText.font.weight
                font.bold: mainText.font.bold
                font.italic: mainText.font.italic
                font.capitalization: mainText.font.capitalization
                font.letterSpacing: mainText.font.letterSpacing
                font.wordSpacing: mainText.font.wordSpacing
                font.strikeout: mainText.font.strikeout
                font.underline: mainText.font.underline
                visible: root.canMarquee
            }
        }
    }

    SequentialAnimation {
        id: scrollAnim
        loops: Animation.Infinite
        running: root.canMarquee

        PauseAnimation {
            duration: root.pauseDuration
        }

        NumberAnimation {
            target: root
            property: "scrollProgress"
            from: 0.0
            to: 1.0
            duration: Math.max(1000, Math.round(root.scrollDistance * root.speed))
            easing.type: Easing.Linear
        }

        PropertyAction {
            target: root
            property: "scrollProgress"
            value: 0.0
        }
    }
}
