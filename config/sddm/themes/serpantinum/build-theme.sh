#!/usr/bin/env bash
set -euo pipefail

theme_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
project_root=$(cd -- "$theme_dir/../../../.." && pwd)
out=${1:?usage: build-theme.sh destination}
assets="$project_root/src/assets"

install -d "$out/assets/sounds/reusables"
install -m644 "$theme_dir"/*.qml "$theme_dir"/{metadata.desktop,theme.conf} "$out/"
install -m644 "$assets"/shaders/effects/{liquid_glass,curtain_wipe}.frag.qsb "$out/"
install -m644 "$assets"/shaders/fluid/{fluid_wave,liquid_fill}.frag.qsb "$out/"
install -m644 "$assets"/{fonts/SymbolsNerdFontMono-Regular.ttf,pushy.gif} "$out/"
install -m644 "$theme_dir/../material-you/bg_dark.jpg" "$out/fallback.jpg"
install -m644 "$project_root/LICENSE.md" "$out/"
for group in input inputfield iconbutton fillbutton clickbutton dropdown; do
    if [[ -d "$assets/sounds/reusables/$group" ]]; then
        cp -R "$assets/sounds/reusables/$group" "$out/assets/sounds/reusables/"
    fi
done
python3 "$theme_dir/adapt-upstream.py" "$project_root/src/quickshell" "$out"
