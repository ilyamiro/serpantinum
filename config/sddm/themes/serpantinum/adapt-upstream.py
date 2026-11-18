"""Package the shared Qt Quick controls with greeter-local services."""
from pathlib import Path
import re
import sys


def adapt(source):
    source = re.sub(r'^import (?:Quickshell\b.*|"\.\..*)\n', "", source, flags=re.M)
    source = source.replace("import QtQuick.Controls\n", "import QtQuick.Controls.Basic\n")
    source = source.replace("    id: root\n", "    id: root\n    required property var greeter\n", 1)
    source = source.replace("ThemeBackend.", "root.greeter.palette.")
    source = source.replace('typeof Sounds !== "undefined"', "root.greeter.sounds !== null")
    source = re.sub(r"\bSounds\b", "root.greeter.sounds", source)
    source = source.replace("I18n.rtl", "root.greeter.rtl")
    source = source.replace("I18n.layoutDirection", "(root.greeter.rtl ? Qt.RightToLeft : Qt.LeftToRight)")
    source = source.replace("I18n.textAlignment", "(root.greeter.rtl ? Text.AlignRight : Text.AlignLeft)")
    return source.replace(".playSfx(", ".play(")


def without(source, start, end):
    offset = source.index(start)
    return source[:offset] + source[source.index(end, offset):]


def main():
    src, out = map(Path, sys.argv[1:])
    clock = adapt((src / "widgets/faces/clock/ClockFaceLockscreen.qml").read_text())
    clock = without(clock, "    property var currentTime:", "    readonly property bool is12h:")
    clock = without(clock, "    Connections {", "    component ShadowText:")
    clock = clock.replace("    readonly property bool is12h:", (
        "    readonly property date currentTime: greeter.time\n"
        "    readonly property string timeFormat: greeter.timeFormat\n"
        "    readonly property bool is12h:"
    ))
    clock = clock.replace("Scaler.s(", "root.greeter.s(")
    clock = clock.replace("Qt.formatDateTime(root.currentTime, root.hourFmt)", (
        'Qt.formatDateTime(root.currentTime, root.hourFmt + (root.is12h ? " AP" : "")).split(" ")[0]'
    ))
    (out / "ClockFaceLockscreen.qml").write_text(clock)

    password = adapt((src / "reusables/inputs/PasswordInput.qml").read_text())
    password = without(password, "    property bool isRevealed:", "    property real revealProgress:")
    # The display manager always starts with the password concealed.
    password = password.replace("    property real revealProgress:", "    property bool isRevealed: false\n    property real revealProgress:")
    password = without(password, "    onIsRevealedChanged:", "    property real typePulse:")
    password = password.replace("    property real typePulse:", "    onIsRevealedChanged: submitButton.triggerSpin()\n\n    property real typePulse:")
    password = password.replace("            id: lockButton\n", "            id: lockButton\n            greeter: root.greeter\n")
    password = password.replace("                id: innerInput\n", (
        "                id: innerInput\n"
        "                inputMethodHints: Qt.ImhHiddenText | Qt.ImhSensitiveData | Qt.ImhNoPredictiveText\n"
        "                Accessible.name: root.placeholderText\n"
    ))
    password = password.replace("event.matches(StandardKey.Copy)", (
        "(event.matches(StandardKey.Copy) || event.matches(StandardKey.Cut))"
    ))
    for name, data in (
        ("PasswordInput.qml", password),
        ("CanvasIconButton.qml", adapt((src / "reusables/buttons/CanvasIconButton.qml").read_text())),
        ("FillButton.qml", adapt((src / "reusables/buttons/FillButton.qml").read_text())),
    ):
        data = re.sub(r"(\s+GlassFill \{\n)", r"\1                greeter: root.greeter\n", data)
        data = re.sub(r"(\s+(?:FluidWave|LiquidFill) \{\n)", r"\1            greeter: root.greeter\n", data)
        (out / name).write_text(data)

    for name in ("FluidWave", "LiquidFill"):
        data = adapt((src / f"reusables/display/{name}.qml").read_text())
        data = data.replace('"file://" + Caching.serpantinumDir + "/assets/shaders/fluid/', '"')
        (out / f"{name}.qml").write_text(data)


if __name__ == "__main__":
    main()
