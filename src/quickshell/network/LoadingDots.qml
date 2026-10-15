import QtQuick
import "../"

Row {
    spacing: Scaler.s(4)
    property color dotCol: ThemeBackend.text
    Repeater {
        model: 3
        Rectangle {
            width: Scaler.s(5); height: Scaler.s(5); radius: Scaler.s(2.5); color: dotCol
            SequentialAnimation on y {
                loops: Animation.Infinite
                running: window.visible && parent.visible
                PauseAnimation { duration: index * 100 }
                NumberAnimation { from: 0; to: Scaler.s(-5); duration: 250; easing.type: Easing.OutSine }
                NumberAnimation { from: Scaler.s(-5); to: 0; duration: 250; easing.type: Easing.InSine }
                PauseAnimation { duration: (2 - index) * 100 }
            }
        }
    }
}
