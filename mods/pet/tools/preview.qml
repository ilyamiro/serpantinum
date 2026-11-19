// Renders a contact sheet of the pet's poses to previews/sprites.png.
// Run: tools/preview.sh
import QtQuick
import QtQuick.Window
import "../src/pet"
import "../src/pet/PetArt.js" as Art

Window {
    id: win
    width: 1500
    height: 1180
    visible: true
    color: "#0c0e13"

    property var pal: Art.makePalette({ fur: "#adc6ff", bed: "#debcdf", phones: "#debcdf", umbrella: "#ffb4ab", text: "#e2e2e9", base: "#0c0e13" })
    property var pal2: Art.makePalette({ fur: "#da702c", bed: "#4385be", phones: "#3aa99f", umbrella: "#d14d41", text: "#cecdc3", base: "#100f0f" })

    function single(name, cw, ch) {
        return { draws: [[Art.sprite(name), 1, 1, false, "x"]], cw: cw, ch: ch };
    }

    property var cases: [
        { l: "walk 0", s: Art.scene({ pose: "walk", frame: 0 }) },
        { l: "walk 1", s: Art.scene({ pose: "walk", frame: 1 }) },
        { l: "walk 2", s: Art.scene({ pose: "walk", frame: 2 }) },
        { l: "walk 3", s: Art.scene({ pose: "walk", frame: 3 }) },
        { l: "run 0", s: Art.scene({ pose: "run", frame: 0 }) },
        { l: "run 1", s: Art.scene({ pose: "run", frame: 1 }) },
        { l: "stand", s: Art.scene({ pose: "stand", frame: 0 }) },
        { l: "stumble", s: Art.scene({ pose: "stumble", face: "alert" }) },
        { l: "crouch", s: Art.scene({ pose: "crouch", face: "side" }) },
        { l: "sit", s: Art.scene({ pose: "sit" }) },
        { l: "blink", s: Art.scene({ pose: "sit", face: "blink" }) },
        { l: "happy", s: Art.scene({ pose: "sit", face: "happy" }) },
        { l: "meow", s: Art.scene({ pose: "sit", face: "meow" }) },
        { l: "up", s: Art.scene({ pose: "sit", face: "up" }) },
        { l: "side", s: Art.scene({ pose: "sit", face: "side" }) },
        { l: "alert !", s: Art.scene({ pose: "sit", face: "alert", fx: [{ g: "bang", dx: 6, dy: -9 }] }) },
        { l: "dizzy", s: Art.scene({ pose: "sit", face: "dizzy", fx: [{ g: "star", dx: -6, dy: -2 }, { g: "star", dx: 2, dy: -4 }, { g: "star", dx: 7, dy: 0 }] }) },
        { l: "tired", s: Art.scene({ pose: "sit", face: "tired" }) },
        { l: "yawn", s: Art.scene({ pose: "sit", face: "yawn" }) },
        { l: "pant+sweat", s: Art.scene({ pose: "sit", face: "pant", sweat: true }) },
        { l: "purr", s: Art.scene({ pose: "sit", face: "love", fx: [{ g: "heart", dx: 5, dy: -6 }, { g: "heart", dx: -4, dy: -10 }] }) },
        { l: "loaf 0 zz", s: Art.scene({ pose: "loaf", frame: 0, face: "sleep", fx: [{ g: "z1", dx: 6, dy: -3 }, { g: "z2", dx: 9, dy: -8 }] }) },
        { l: "loaf 1", s: Art.scene({ pose: "loaf", frame: 1, face: "sleep" }) },
        { l: "flop", s: Art.scene({ pose: "flop", face: "pant" }) },
        { l: "dangle", s: Art.scene({ pose: "dangle", face: "alert" }) },
        { l: "leap", s: Art.scene({ pose: "leap", face: "happy" }) },
        { l: "stretch", s: Art.scene({ pose: "stretch", face: "yawn" }) },
        { l: "eat", s: Art.scene({ pose: "eat", face: "chew" }) },
        { l: "type 0", s: Art.scene({ pose: "type", frame: 0, glasses: true }) },
        { l: "type 1 +phones", s: Art.scene({ pose: "type", frame: 1, glasses: true, phones: true }) },
        { l: "groom 0", s: Art.scene({ pose: "groom", frame: 0, face: "blink" }) },
        { l: "groom 1", s: Art.scene({ pose: "groom", frame: 1, face: "happy" }) },
        { l: "dance b0", s: Art.scene({ pose: "dance", frame: 0, phones: true, bob: 0, fx: [{ g: "note", dx: 8, dy: -6 }] }) },
        { l: "dance b2", s: Art.scene({ pose: "dance", frame: 1, phones: true, bob: 2, face: "happy" }) },
        { l: "umbrella sit", s: Art.scene({ pose: "sit", umbrella: true }) },
        { l: "umbrella walk", s: Art.scene({ pose: "walk", frame: 1, umbrella: true }) },
        { l: "L walk", s: Art.scene({ pose: "walk", frame: 0, facing: -1 }) },
        { l: "L sit side", s: Art.scene({ pose: "sit", face: "side", facing: -1 }) },
        { l: "L type", s: Art.scene({ pose: "type", frame: 0, glasses: true, facing: -1 }) },
        { l: "L loaf zz", s: Art.scene({ pose: "loaf", face: "sleep", facing: -1, fx: [{ g: "z1", dx: 6, dy: -3 }, { g: "z2", dx: 9, dy: -8 }] }) },
        { l: "bed home zz", s: Art.bedScene({ home: true, frame: 0, fx: [{ g: "z1", dx: 8, dy: 5 }, { g: "z2", dx: 10, dy: 1 }] }) },
        { l: "bed peek", s: Art.bedScene({ home: true, frame: 1, face: "tired" }) },
        { l: "bed love", s: Art.bedScene({ home: true, frame: 0, face: "love", fx: [{ g: "heart", dx: -3, dy: 2 }] }) },
        { l: "bed empty", s: Art.bedScene({ home: false }) },
        { l: "fish", s: Art.fishScene() }
    ]

    Flow {
        id: flow
        x: 10
        y: 10
        width: win.width - 20
        spacing: 6

        Repeater {
            model: win.cases
            Column {
                spacing: 2
                Rectangle {
                    width: sp.width
                    height: sp.height
                    color: "#161821"
                    PetSprite {
                        id: sp
                        px: 3
                        colors: index % 9 === 8 ? win.pal2 : win.pal
                        scene: modelData.s
                    }
                }
                Text {
                    text: modelData.l
                    color: "#9aa0b4"
                    font.pixelSize: 11
                }
            }
        }
    }

    Timer {
        interval: 700
        running: true
        onTriggered: win.contentItem.grabToImage(function(r) {
            r.saveToFile(Qt.resolvedUrl("../previews/sprites.png").toString().replace("file://", ""));
            Qt.quit();
        })
    }
}
