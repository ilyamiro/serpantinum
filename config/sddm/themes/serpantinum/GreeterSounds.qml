import QtQuick
import QtMultimedia

Item {
    id: root
    property real volume: 1
    property int nextHandle: 0
    readonly property var sounds: ({
        "reusables/input/type.wav": input,
        "reusables/iconbutton/click.wav": iconClick,
        "reusables/fillbutton/charge_loop.wav": charge,
        "reusables/fillbutton/button.wav": confirm,
        "reusables/clickbutton/click.wav": click,
        "reusables/clickbutton/click2.wav": secondaryClick,
        "reusables/dropdown/click.wav": dropdownClick,
        "reusables/dropdown/list.wav": dropdownList
    })

    function effectFor(filename) {
        if (!root.enabled || root.volume <= 0 || !Object.prototype.hasOwnProperty.call(root.sounds, filename))
            return null;
        const effect = root.sounds[filename];
        return effect.status === SoundEffect.Ready ? effect : null;
    }

    function play(filename) {
        const effect = root.effectFor(filename);
        if (!effect)
            return;
        effect.stop();
        effect.handle = -1;
        effect.gain = 1;
        effect.loops = 1;
        effect.play();
    }

    function playUntilStopped(filename, volume, loop) {
        const effect = root.effectFor(filename);
        if (!effect)
            return -1;
        effect.stop();
        effect.handle = ++root.nextHandle;
        effect.gain = volume === undefined ? 1 : volume;
        effect.loops = loop ? SoundEffect.Infinite : 1;
        effect.play();
        return effect.handle;
    }

    function stopSfx(handle) {
        if (handle === undefined || handle < 1)
            return;
        for (const filename in root.sounds) {
            const effect = root.sounds[filename];
            if (effect.handle === handle) {
                effect.handle = -1;
                effect.stop();
                return;
            }
        }
    }

    onEnabledChanged: {
        if (!enabled) {
            for (const filename in root.sounds) {
                const effect = root.sounds[filename];
                effect.handle = -1;
                effect.stop();
            }
        }
    }

    component Effect: SoundEffect {
        required property string filename
        property int handle: -1
        property real gain: 1
        source: Qt.resolvedUrl("assets/sounds/reusables/" + filename)
        volume: Math.max(0, Math.min(1, root.volume * gain))
        muted: !root.enabled
    }

    Effect { id: input; filename: "input/type.wav" }
    Effect { id: iconClick; filename: "iconbutton/click.wav" }
    Effect { id: charge; filename: "fillbutton/charge_loop.wav" }
    Effect { id: confirm; filename: "fillbutton/button.wav" }
    Effect { id: click; filename: "clickbutton/click.wav" }
    Effect { id: secondaryClick; filename: "clickbutton/click2.wav" }
    Effect { id: dropdownClick; filename: "dropdown/click.wav" }
    Effect { id: dropdownList; filename: "dropdown/list.wav" }
}
