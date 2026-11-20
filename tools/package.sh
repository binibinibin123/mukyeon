#!/bin/bash
# Builds dist/Mukyeon-<version>-windows.zip: the exported game plus the helper.
# Needs Godot 4.7.2 with its Windows export templates installed, and a MinGW g++.
# Usage: GODOT=/path/to/Godot_v4.7.2-stable_win64_console.exe tools/package.sh 0.1.0
set -euo pipefail
cd "$(dirname "$0")/.."
VERSION="${1:?usage: tools/package.sh VERSION}"
GODOT="${GODOT:-Godot_v4.7.2-stable_win64_console.exe}"

rm -rf dist && mkdir -p dist
g++ -std=c++17 -O2 -municode -mwindows -static helper/helper.cpp -o dist/mukyeon_helper.exe -lws2_32 -lshell32 -luser32
"$GODOT" --headless --path . --export-release "Windows Desktop" dist/Mukyeon.exe
cp README.md LICENSE dist/

cd dist
ZIP="Mukyeon-${VERSION}-windows.zip"
if command -v zip >/dev/null; then
  zip -q "$ZIP" Mukyeon.exe mukyeon_helper.exe README.md LICENSE
else
  powershell -NoProfile -Command "Compress-Archive -Path Mukyeon.exe,mukyeon_helper.exe,README.md,LICENSE -DestinationPath '$ZIP'"
fi
ls -la "$ZIP"
