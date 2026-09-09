#!/usr/bin/env bash
# Export Songo #5 to an Android APK (debug, arm64-v8a).
# Prereqs configured on this machine:
#   JDK 17            -> ~/Android/jdk17
#   Android SDK       -> ~/Android/Sdk  (cmdline-tools, platform-tools, build-tools;34.0.0, platforms;android-34)
#   Godot templates   -> ~/.local/share/godot/export_templates/4.3.stable/
#   Debug keystore    -> ~/.local/share/godot/keystores/debug.keystore  (also set in Godot editor settings)
set -euo pipefail

GODOT="${GODOT:-/media/main_storage/Development/GD43/Godot_v4.3-stable_linux.x86_64}"
PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OUT="${1:-$PROJECT_DIR/build/android/songo5.apk}"
PRESET="${PRESET:-Android}"
MODE="${MODE:-debug}"   # debug | release

export JAVA_HOME="$HOME/Android/jdk17"
export PATH="$JAVA_HOME/bin:$PATH"

mkdir -p "$(dirname "$OUT")"

echo ">> Exporting preset '$PRESET' ($MODE) -> $OUT"
"$GODOT" --headless --path "$PROJECT_DIR" "--export-$MODE" "$PRESET" "$OUT"

echo ">> Verifying signature"
"$HOME/Android/Sdk/build-tools/34.0.0/apksigner" verify "$OUT"
echo ">> Done: $OUT"
