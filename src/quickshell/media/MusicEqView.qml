import QtQuick
import QtQuick.Window
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Effects
import "../"
import "../reusables"

Item {
    id: eqView
    required property var root
    anchors.top: parent.top
    anchors.bottom: parent.bottom
    width: parent.width
    x: root.bottomSectionSwitch.currentIndex === 0 ? 0 : -parent.width - root.s(24)
    opacity: root.bottomSectionSwitch.currentIndex === 0 ? 1.0 : 0.0
    visible: opacity > 0.0

    Behavior on x { NumberAnimation { duration: 420; easing.type: Easing.OutQuart } }
    Behavior on opacity { NumberAnimation { duration: 320; easing.type: Easing.OutCubic } }

    ColumnLayout {
        anchors.fill: parent
        spacing: root.s(12)

        Item {
            Layout.fillWidth: true
            Layout.preferredHeight: root.s(155)

            Row {
                id: eqSliderRow
                anchors.fill: parent
                z: 1

                Repeater {
                    model: [
                        {"idx": 1, "lbl": "31"}, {"idx": 2, "lbl": "63"}, {"idx": 3, "lbl": "125"},
                        {"idx": 4, "lbl": "250"}, {"idx": 5, "lbl": "500"}, {"idx": 6, "lbl": "1k"},
                        {"idx": 7, "lbl": "2k"}, {"idx": 8, "lbl": "4k"}, {"idx": 9, "lbl": "8k"},
                        {"idx": 10, "lbl": "16k"}
                    ]
                    delegate: Item {
                        id: sliderDelegate
                        width: eqSliderRow.width / 10
                        height: eqSliderRow.height

                        opacity: root.introEqSliders
                        transform: Translate {
                            y: root.s(25) * (1 - root.introEqSliders) + (index * root.s(7) * (1 - root.introEqSliders))
                        }

                        property real dist: root.eqLightningProgress - (modelData.idx - 1)
                        property real hitPulse: dist >= 0 && dist < 1.0 ? Math.sin((dist) * Math.PI) : 0.0
                        
                        property real trackPulse: 0.0
                        property real ringPulse: 0.0
                        property real flashFade: 0.0
                        property bool hasFired: false

                        onDistChanged: {
                            if (dist <= 0.05) {
                                hasFired = false;
                            } else if (dist > 0.4 && !hasFired) {
                                hasFired = true;
                                trackPulseAnim.restart();
                                ringPulseAnim.restart();
                                flashFadeAnim.restart();
                            }
                        }

                        SequentialAnimation {
                            id: trackPulseAnim
                            NumberAnimation { target: sliderDelegate; property: "trackPulse"; from: 0.0; to: 1.0; duration: 1000; easing.type: Easing.OutQuart }
                        }
                        SequentialAnimation {
                            id: ringPulseAnim
                            NumberAnimation { target: sliderDelegate; property: "ringPulse"; from: 1.0; to: 0.0; duration: 1500; easing.type: Easing.OutExpo }
                        }
                        SequentialAnimation {
                            id: flashFadeAnim
                            NumberAnimation { target: sliderDelegate; property: "flashFade"; from: 1.0; to: 0.0; duration: 1500; easing.type: Easing.OutSine }
                        }

                        ColumnLayout {
                            anchors.fill: parent
                            spacing: root.s(4)
                            Slider {
                                id: eqSlider
                                Layout.fillHeight: true
                                Layout.alignment: Qt.AlignHCenter
                                orientation: Qt.Vertical
                                from: -12; to: 12
                                stepSize: 1
                                hoverEnabled: true

                                Connections {
                                    target: root
                                    function onEqDataChanged() {
                                        if (!eqSlider.pressed) {
                                            if (root.eqData && root.eqData["b" + modelData.idx] !== undefined) {
                                                var p = Number(root.eqData["b" + modelData.idx]);
                                                if (!isNaN(p)) eqSlider.value = p;
                                            }
                                        }
                                    }
                                }

                                Behavior on value {
                                    enabled: !eqSlider.pressed
                                    NumberAnimation {
                                        duration: 350
                                        easing.type: Easing.OutQuart
                                    }
                                }

                                onPressedChanged: {
                                    if (!pressed) {
                                        var temp = Object.assign({}, root.eqData);
                                        temp["b" + modelData.idx] = Math.round(value);
                                        temp.preset = "Custom";
                                        temp.pending = true;
                                        root.eqData = temp;
                                        
                                        root.lastEqUpdate = Date.now();
                                        
                                        root.execCmd(Caching.qsDir + `/media/equalizer.sh set_band ${modelData.idx} ${Math.round(value)}`);
                                    }
                                }

                                background: Rectangle {
                                    id: trackBg
                                    x: eqSlider.leftPadding + (eqSlider.availableWidth - width) / 2
                                    y: eqSlider.topPadding
                                    implicitWidth: root.s(12)
                                    implicitHeight: root.s(130)
                                    width: root.s(12); height: eqSlider.availableHeight
                                    radius: ThemeBackend.borderRadius
                                    
                                    color: trackGlass.active ? "transparent" : Qt.rgba((ThemeBackend.surface0 ? ThemeBackend.surface0.r : 0.2), (ThemeBackend.surface0 ? ThemeBackend.surface0.g : 0.2), (ThemeBackend.surface0 ? ThemeBackend.surface0.b : 0.3), 0.7 * ThemeBackend.elementOpacity)

                                    GlassFill {
                                        id: trackGlass
                                        anchors.fill: parent
                                        radius: parent.radius
                                        tintColor: ThemeBackend.surface0
                                        tintAmount: 0.3
                                    }

                                    layer.enabled: true
                                    layer.effect: MultiEffect {
                                        id: trackEffect
                                        shadowEnabled: true
                                        shadowColor: "#000000"
                                        shadowOpacity: 0.9
                                        shadowBlur: 0.5
                                        shadowVerticalOffset: 1
                                    }

                                    Rectangle {
                                        z: -1
                                        anchors.centerIn: parent
                                        width: parent.width + root.s(17) + sliderDelegate.ringPulse * root.s(34)
                                        height: parent.height + root.s(17) + sliderDelegate.ringPulse * root.s(51)
                                        radius: parent.radius + root.s(8) + sliderDelegate.ringPulse * root.s(17)
                                        color: "transparent"
                                        border.color: root.eqAccentColor
                                        border.width: root.s(2) + sliderDelegate.ringPulse * root.s(4)
                                        opacity: sliderDelegate.ringPulse * 0.8 * (1.0 - root.eqLightningFade)
                                        
                                        layer.enabled: true
                                        layer.effect: MultiEffect { blurEnabled: true; blurMax: 32; blur: 1.0 }
                                    }

                                    Item {
                                        width: parent.width
                                        height: (1 - eqSlider.visualPosition) * parent.height
                                        y: eqSlider.visualPosition * parent.height
                                        
                                        layer.enabled: true
                                        layer.effect: MultiEffect {
                                            maskEnabled: true
                                            maskSource: eqFillMask
                                        }

                                        Rectangle {
                                            id: eqFillMask
                                            anchors.fill: parent
                                            radius: ThemeBackend.borderRadius
                                            visible: false
                                            layer.enabled: true 
                                        }

                                        GlassFill {
                                            id: eqFillGlass
                                            anchors.fill: parent
                                            radius: ThemeBackend.borderRadius
                                            forceClear: true
                                            tintColor: (root ? root.eqAccentColor : ThemeBackend.mauve)
                                            tintAmount: 0.6
                                            tintStrength: 1.0
                                            press: eqSlider.pressed ? 0.5 : (eqSlider.hovered ? 0.2 : 0)
                                            Behavior on press { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
                                        }

                                        Rectangle {
                                            anchors.fill: parent
                                            color: eqFillGlass.active ? "transparent" : (root ? root.eqAccentColor : ThemeBackend.mauve)

                                            Rectangle {
                                                anchors.fill: parent
                                                opacity: sliderDelegate.flashFade
                                                gradient: Gradient {
                                                    orientation: Gradient.Vertical
                                                    GradientStop { position: 0.0; color: Qt.lighter(root.eqAccentColor, 1.3) }
                                                    GradientStop { position: 0.5; color: root.eqAccentColor }
                                                    GradientStop { position: 1.0; color: "transparent" }
                                                }
                                            }

                                            Rectangle {
                                                width: parent.width
                                                height: root.s(70)
                                                y: (sliderDelegate.trackPulse * (parent.height + height)) - height
                                                opacity: Math.sin(sliderDelegate.trackPulse * Math.PI) * 2.0 * (1.0 - root.eqLightningFade)
                                                
                                                gradient: Gradient {
                                                    orientation: Gradient.Vertical
                                                    GradientStop { position: 0.0; color: "transparent" }
                                                    GradientStop { position: 0.2; color: root.eqAccentColor }
                                                    GradientStop { position: 0.5; color: ThemeBackend.text || "#ffffff" }
                                                    GradientStop { position: 0.8; color: Qt.lighter(root.eqAccentColor, 1.2) }
                                                    GradientStop { position: 1.0; color: "transparent" }
                                                }
                                                
                                                layer.enabled: true
                                                layer.effect: MultiEffect {
                                                    shadowEnabled: true; shadowColor: root.eqAccentColor; shadowBlur: 1.0; shadowOpacity: 1.0
                                                }
                                            }
                                        }
                                    }
                                }

                                handle: Rectangle {
                                    id: eqHandle
                                    x: eqSlider.leftPadding + (eqSlider.availableWidth - width) / 2
                                    y: eqSlider.topPadding + eqSlider.visualPosition * (eqSlider.availableHeight - height)
                                    implicitWidth: root.s(16)
                                    implicitHeight: root.s(16)
                                    width: root.s(16); height: root.s(16)
                                    radius: root.s(8)

                                    property color handleColor: ThemeBackend.text || "#cdd6f4"
                                    property color handleHoverColor: Qt.lighter(root.eqAccentColor, 1.15)
                                    property color handleDragColor: Qt.lighter(root.eqAccentColor, 1.30)

                                    color: eqHandleGlass.active ? "transparent" : (eqSlider.pressed ? handleDragColor : (eqSlider.hovered ? handleHoverColor : handleColor))

                                    GlassFill {
                                        id: eqHandleGlass
                                        anchors.fill: parent
                                        radius: parent.radius
                                        tintColor: parent.handleColor
                                        tintAmount: 0.4
                                        shadow: 1
                                        press: eqSlider.pressed ? 1 : (eqSlider.hovered ? 0.3 : 0)
                                        Behavior on press { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
                                    }
                                    Behavior on color { ColorAnimation { duration: 150 } }

                                    property real targetScale: {
                                        if (eqSlider.pressed) return 1.25;
                                        if (eqSlider.hovered) return 1.08;
                                        return 1.0;
                                    }

                                    Behavior on targetScale {
                                        NumberAnimation {
                                            duration: 150
                                            easing.type: Easing.OutBack
                                        }
                                    }

                                    property real popScale: 1.0
                                    property real flashOpacity: 0.0

                                    SequentialAnimation {
                                        id: eqHandlePopAnim
                                        NumberAnimation { target: eqHandle; property: "popScale"; to: 1.12; duration: 100; easing.type: Easing.OutQuad }
                                        NumberAnimation { target: eqHandle; property: "popScale"; to: 1.0; duration: 200; easing.type: Easing.OutCubic }
                                    }

                                    Connections {
                                        target: eqSlider
                                        function onMoved() {
                                            eqHandlePopAnim.restart();
                                        }
                                        function onPressedChanged() {
                                            if (!eqSlider.pressed) {
                                                eqHandle.flashOpacity = 0.35;
                                                eqHandleFlashAnim.restart();
                                            }
                                        }
                                    }

                                    property var catColors: [
                                        root.eqAccentColor,
                                        ThemeBackend.pink || "#f5c2e7",
                                        ThemeBackend.lavender || "#b4befe",
                                        root.eqAccentColor,
                                        ThemeBackend.blue || "#89b4fa"
                                    ]

                                    Rectangle {
                                        anchors.centerIn: parent
                                        width: parent.width + root.s(31) * sliderDelegate.hitPulse
                                        height: width
                                        radius: width / 2
                                        color: (parent.catColors && parent.catColors.length > 0) ? (parent.catColors[(typeof index !== "undefined" ? index : 0) % parent.catColors.length] || root.eqAccentColor) : root.eqAccentColor
                                        opacity: sliderDelegate.hitPulse * (1.0 - root.eqLightningFade)
                                        layer.enabled: true
                                        layer.effect: MultiEffect { blurEnabled: true; blurMax: 32; blur: 1.0 }
                                    }

                                    Rectangle {
                                        anchors.fill: parent
                                        radius: parent.radius
                                        color: "#ffffff"
                                        opacity: eqHandle.flashOpacity
                                        PropertyAnimation on opacity { id: eqHandleFlashAnim; to: 0; duration: 300; easing.type: Easing.OutCubic }
                                    }

                                    scale: (targetScale * popScale) + (sliderDelegate.hitPulse * 0.4 * (1.0 - root.eqLightningFade))
                                }
                            }
                            Text {
                                text: modelData.lbl
                                color: ThemeBackend.overlay1 || "#7f849c"
                                font.family: ThemeBackend.fontFamily
                                font.pixelSize: root.s(9.5)
                                font.bold: true
                                Layout.alignment: Qt.AlignHCenter
                            }
                        }
                    }
                }
            }

            ShaderEffect {
                id: lightningCanvas
                anchors.fill: parent
                opacity: 1.0 - root.eqLightningFade
                z: 0

                property real animTime: 0.0
                NumberAnimation on animTime {
                    running: root.active
                    loops: Animation.Infinite
                    from: 0; to: 1000
                    duration: 1000000
                }

                property vector2d itemSize: Qt.vector2d(width, height)
                property real time: animTime
                property real progress: root.eqLightningProgress
                property real fade: root.eqLightningFade
                property real scale: root.s(1.0)
                property color accentColor: root.eqAccentColor

                property vector4d bands0: Qt.vector4d(
                    root.eqData.b1 !== undefined ? Number(root.eqData.b1) : 0,
                    root.eqData.b2 !== undefined ? Number(root.eqData.b2) : 0,
                    root.eqData.b3 !== undefined ? Number(root.eqData.b3) : 0,
                    root.eqData.b4 !== undefined ? Number(root.eqData.b4) : 0
                )
                property vector4d bands1: Qt.vector4d(
                    root.eqData.b5 !== undefined ? Number(root.eqData.b5) : 0,
                    root.eqData.b6 !== undefined ? Number(root.eqData.b6) : 0,
                    root.eqData.b7 !== undefined ? Number(root.eqData.b7) : 0,
                    root.eqData.b8 !== undefined ? Number(root.eqData.b8) : 0
                )
                property vector4d bands2: Qt.vector4d(
                    root.eqData.b9 !== undefined ? Number(root.eqData.b9) : 0,
                    root.eqData.b10 !== undefined ? Number(root.eqData.b10) : 0,
                    root.s(10),
                    root.s(30)
                )

                fragmentShader: "file://" + Caching.serpantinumDir + "/assets/shaders/vfx/eq_lightning.frag.qsb"
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: root.s(7)
            
            opacity: root.introPresets
            transform: Translate { y: root.s(18) * (1 - root.introPresets) }

            RowLayout {
                Layout.fillWidth: true
                spacing: root.s(8)
                Repeater {
                    model: ["Flat", "Bass", "Treble", "Vocal"]
                    delegate: MusicPresetButton { required property var modelData; root: eqView.root; name: modelData }
                }
            }
            RowLayout {
                Layout.fillWidth: true
                spacing: root.s(8)
                Repeater {
                    model: ["Pop", "Rock", "Jazz", "Classic"]
                    delegate: MusicPresetButton { required property var modelData; root: eqView.root; name: modelData }
                }
            }
        }
    }
}
