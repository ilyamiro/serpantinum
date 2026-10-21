import QtQuick

// Mini Steve sprite (same look as on the bar's workspace islands).
// pose: "stand", "jump" (both arms up), "wave" (one arm up).
Canvas {
    id: steve
    property int px: 2
    property string pose: "stand"
    property bool facingLeft: false

    width: px * 6
    height: px * 8
    antialiasing: false
    transform: Scale { origin.x: steve.width / 2; xScale: steve.facingLeft ? -1 : 1 }

    readonly property var palette: ({
        "H": "#3b2a1a", "F": "#c69c7a", "e": "#3a3fbf", "b": "#6b4a30",
        "C": "#00a8a8", "c": "#008080", "P": "#46399a", "g": "#5a5a5a"
    })
    readonly property var sprites: ({
        "stand": [".HHHH.", ".HFFH.", ".eFFe.", ".FbbF.", "CCCCCC", "FcCCcF", ".PPPP.", ".gggg."],
        "jump": ["FHHHHF", "CHFFHC", "CeFFeC", ".FbbF.", ".CCCC.", ".cCCc.", ".P..P.", "g....g"],
        "wave": ["FHHHH.", "CHFFH.", "CeFFe.", ".FbbF.", ".CCCCC", ".cCCcF", ".PPPP.", ".gggg."]
    })

    onPoseChanged: requestPaint()
    onPxChanged: requestPaint()
    Component.onCompleted: requestPaint()
    onPaint: {
        let ctx = getContext("2d");
        ctx.reset();
        let sp = sprites[pose] || sprites["stand"];
        for (let y = 0; y < sp.length; y++)
            for (let x = 0; x < sp[y].length; x++) {
                let ch = sp[y][x];
                if (ch === ".") continue;
                ctx.fillStyle = palette[ch];
                ctx.fillRect(x * px, y * px, px, px);
            }
    }
}
