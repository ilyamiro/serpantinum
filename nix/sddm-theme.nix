{
  lib,
  runCommand,
  python3,
}:
let
  root = ../.;
  source = lib.fileset.toSource {
    root = root;
    fileset = lib.fileset.unions [
      ../LICENSE.md
      ../config/sddm/themes/serpantinum
      ../config/sddm/themes/material-you/bg_dark.jpg
      ../src/assets/pushy.gif
      ../src/assets/fonts/SymbolsNerdFontMono-Regular.ttf
      ../src/assets/shaders/effects/curtain_wipe.frag.qsb
      ../src/assets/shaders/effects/liquid_glass.frag.qsb
      ../src/assets/shaders/fluid/fluid_wave.frag.qsb
      ../src/assets/shaders/fluid/liquid_fill.frag.qsb
      ../src/assets/sounds/reusables
      ../src/quickshell/widgets/faces/clock/ClockFaceLockscreen.qml
      ../src/quickshell/reusables/inputs/PasswordInput.qml
      ../src/quickshell/reusables/buttons/CanvasIconButton.qml
      ../src/quickshell/reusables/buttons/FillButton.qml
      ../src/quickshell/reusables/display/FluidWave.qml
      ../src/quickshell/reusables/display/LiquidFill.qml
    ];
  };
in
runCommand "serpantinum-sddm-theme" { nativeBuildInputs = [ python3 ]; } ''
  bash ${source}/config/sddm/themes/serpantinum/build-theme.sh "$out/share/sddm/themes/serpantinum"
  install -Dm644 ${source}/config/sddm/themes/serpantinum/sync.py "$out/libexec/serpantinum-greeter-sync.py"
  install -Dm644 ${source}/config/sddm/themes/serpantinum/metrics.py "$out/libexec/serpantinum-greeter-metrics.py"
''
