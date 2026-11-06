#!/bin/bash
# Собирает Resources/AppIcon.icns и картинки для GitHub из Resources/Icon/RedQuit.svg.
#
#   ./Scripts/make-icon.sh
set -euo pipefail
cd "$(dirname "$0")/.."

SVG="Resources/Icon/RedQuit.svg"
ICONSET="build/AppIcon.iconset"
mkdir -p build .github

EXTRA_PNG=".github/icon.png:256,Resources/Icon/RedQuit-1024.png:1024" \
    swift Scripts/make-iconset.swift "$SVG" "$ICONSET"
iconutil -c icns "$ICONSET" -o Resources/AppIcon.icns
echo "Готово: Resources/AppIcon.icns, .github/icon.png, Resources/Icon/RedQuit-1024.png"
