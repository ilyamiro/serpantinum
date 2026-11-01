#!/usr/bin/env bash
# Renders previews/sprites.png from the current PetArt.js (offscreen, no window).
set -euo pipefail
HERE="$(cd "$(dirname "$(realpath "${BASH_SOURCE[0]}")")/.." && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
mkdir -p "$TMP/src/pet" "$TMP/tools" "$TMP/previews"
cp "$HERE/src/pet/PetArt.js" "$HERE/src/pet/PetSprite.qml" "$TMP/src/pet/"
cp "$HERE/tools/preview.qml" "$TMP/tools/"
QT_QPA_PLATFORM=offscreen timeout 30 /usr/lib/qt6/bin/qml "$TMP/tools/preview.qml"
mkdir -p "$HERE/previews"
cp "$TMP/previews/sprites.png" "$HERE/previews/sprites.png"
echo "wrote $HERE/previews/sprites.png"
