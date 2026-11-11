#!/usr/bin/env bash
# Export Songo #5 to a release Android APK (arm64-v8a), using the Songodot
# editor kept in build_platforms/.
#
#   build_platforms/android/build_android.sh [output.apk]
#
# Defaults to build/android/songo5.apk in the project. MODE=debug exports a
# debug APK instead; GODOT=<path> uses another Songodot editor binary.
#
# Prereqs configured on this machine:
#   JDK 17            -> ~/Android/jdk17
#   Android SDK       -> ~/Android/Sdk  (cmdline-tools, platform-tools, build-tools;34.0.0, platforms;android-34)
#   Android NDK       -> ~/Android/Sdk/ndk/23.2.8568313 (for building Songodot's templates)
#   Release keystore  -> set in the Android preset (stored in .godot/export_credentials.cfg);
#                        without one, release builds are signed with the debug keystore
#   Debug keystore    -> ~/.local/share/godot/keystores/debug.keystore  (also set in Godot editor settings)
#
# Songo needs Songodot (../Songodot), the custom engine with the gdtaglib
# module, for both the editor and the Android templates. Stock Godot's won't
# work. build_platforms/godot.linuxbsd.editor.x86_64.llvm is a copy of
# Songodot's bin/godot.linuxbsd.editor.x86_64.llvm; copy it again after
# rebuilding the editor. Build the size-optimized Android templates in
# Songodot with:
#   JAVA_HOME=~/Android/jdk17 scons profile=android_profile.py
#   JAVA_HOME=~/Android/jdk17 scons profile=android_profile.py target=template_debug
# which also runs Gradle and writes bin/android_source.zip, the preset's
# android_source_template.
#
# The preset uses Godot's Gradle build, which the songo_player_harness addon
# needs for its Android plugin (background playback service, media session).
# The build template it builds from lives in android/ (not in git) and is
# reinstalled from android_source.zip whenever that zip changes. The first
# install also downloads Gradle's dependencies, so it needs network and takes a
# few minutes.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLATFORMS_DIR="$(dirname "$SCRIPT_DIR")"     # build_platforms/
PROJECT_DIR="$(dirname "$PLATFORMS_DIR")"    # Songo-5/
GODOT="${GODOT:-$PLATFORMS_DIR/godot.linuxbsd.editor.x86_64.llvm}"
OUT="${1:-$PROJECT_DIR/build/android/songo5.apk}"
PRESET="${PRESET:-Android}"
MODE="${MODE:-release}"   # release | debug

if [ ! -x "$GODOT" ]; then
    echo "!! Songodot editor not found at $GODOT" >&2
    echo "   Copy ../Songodot/bin/godot.linuxbsd.editor.x86_64.llvm into build_platforms/." >&2
    exit 1
fi
# Relative output paths are relative to where the script was run from
case "$OUT" in /*) ;; *) OUT="$PWD/$OUT" ;; esac

export JAVA_HOME="$HOME/Android/jdk17"
export PATH="$JAVA_HOME/bin:$PATH"
export ANDROID_HOME="${ANDROID_HOME:-$HOME/Android/Sdk}"

# The preset's [preset.N] section in export_presets.cfg. Its options are in
# [preset.N.options] there, and its keystore settings in the same section of
# .godot/export_credentials.cfg.
PRESET_SECTION="$(awk -v preset="$PRESET" '
    /^\[preset\.[0-9]+\]$/ { section = $0 }
    $0 == "name=\"" preset "\"" { print section; exit }
' "$PROJECT_DIR/export_presets.cfg")"
if [ -z "$PRESET_SECTION" ]; then
    echo "!! No export preset named '$PRESET' in export_presets.cfg." >&2
    exit 1
fi

# preset_option <cfg file> <key>: the preset's value for key, unquoted
preset_option() {
    [ -f "$1" ] || return 0
    awk -v options="${PRESET_SECTION%]}.options]" -v key="$2" '
        $0 == options { in_options = 1; next }
        /^\[/ { in_options = 0 }
        in_options && index($0, key "=") == 1 {
            value = substr($0, length(key) + 2); sub(/^"/, "", value); sub(/"$/, "", value); print value; exit
        }
    ' "$1"
}

SOURCE_ZIP="$(preset_option "$PROJECT_DIR/export_presets.cfg" gradle_build/android_source_template)"
if [ -z "$SOURCE_ZIP" ] || [ ! -f "$SOURCE_ZIP" ]; then
    echo "!! Preset '$PRESET' has no android_source_template, or '$SOURCE_ZIP' doesn't exist." >&2
    echo "   Build it in Songodot (see the top of this script)." >&2
    exit 1
fi

# Godot refuses to export from a build template installed from a different
# zip, and identifies the zip by its path and MD5, as written here. Installing
# over the old one would leave its files behind (e.g. old GDExtension
# libraries), so it's cleared first.
EXPECTED_VERSION="$SOURCE_ZIP [$(md5sum "$SOURCE_ZIP" | cut -d' ' -f1)]"
INSTALLED_VERSION="$(head -n1 "$PROJECT_DIR/android/.build_version" 2>/dev/null || true)"
INSTALL_TEMPLATE=()
if [ ! -f "$PROJECT_DIR/android/build/build.gradle" ] || [ "$INSTALLED_VERSION" != "$EXPECTED_VERSION" ]; then
    echo ">> Installing the Android build template from $SOURCE_ZIP into android/build"
    rm -rf "$PROJECT_DIR/android/build" "$PROJECT_DIR/android/.build_version"
    INSTALL_TEMPLATE=(--install-android-build-template)
fi

# Release signing. Without a release keystore (in the preset or the
# GODOT_ANDROID_KEYSTORE_RELEASE_* variables), sign with the debug keystore
# from Godot's editor settings instead. Fine for sideloading, but the key is a
# throwaway with a well-known password, Google Play rejects it, and users must
# reinstall if it ever changes, so set a real release keystore for public
# releases. Passed through the environment, which takes precedence over the
# preset, so nothing in the project changes.
if [ "$MODE" = release ] && [ -z "${GODOT_ANDROID_KEYSTORE_RELEASE_PATH:-}" ] \
        && [ -z "$(preset_option "$PROJECT_DIR/.godot/export_credentials.cfg" keystore/release)" ]; then
    EDITOR_SETTINGS="${XDG_CONFIG_HOME:-$HOME/.config}/godot/editor_settings-4.3.tres"
    editor_setting() {
        [ -f "$EDITOR_SETTINGS" ] || return 0
        sed -n "s|^export/android/$1 = \"\(.*\)\"\$|\1|p" "$EDITOR_SETTINGS" | head -n1
    }
    DEBUG_KEYSTORE="$(editor_setting debug_keystore)"
    DEBUG_KEYSTORE="${DEBUG_KEYSTORE:-$HOME/.local/share/godot/keystores/debug.keystore}"
    if [ ! -f "$DEBUG_KEYSTORE" ]; then
        echo "!! No release keystore set and no debug keystore at $DEBUG_KEYSTORE to fall back to." >&2
        exit 1
    fi
    DEBUG_USER="$(editor_setting debug_keystore_user)"
    DEBUG_PASS="$(editor_setting debug_keystore_pass)"
    export GODOT_ANDROID_KEYSTORE_RELEASE_PATH="$DEBUG_KEYSTORE"
    export GODOT_ANDROID_KEYSTORE_RELEASE_USER="${DEBUG_USER:-androiddebugkey}"
    export GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD="${DEBUG_PASS:-android}"
    echo "!! WARNING: no release keystore set; signing this release build with the debug keystore" >&2
    echo "   ($DEBUG_KEYSTORE). OK for sideloading, not for Google Play." >&2
fi

mkdir -p "$(dirname "$OUT")"

echo ">> Exporting preset '$PRESET' ($MODE) -> $OUT"
STARTED="$(mktemp)"
trap 'rm -f "$STARTED"' EXIT
"$GODOT" --headless --path "$PROJECT_DIR" "${INSTALL_TEMPLATE[@]}" "--export-$MODE" "$PRESET" "$OUT"

# A Gradle export that goes wrong can still leave an older APK behind
if [ ! "$OUT" -nt "$STARTED" ]; then
    echo "!! Export didn't produce $OUT" >&2
    exit 1
fi

echo ">> Checking the engine is Songodot's, with gdtaglib built in"
# Captured first: grep -q stopping early would fail the pipe under pipefail
ENGINE_LIB="$(unzip -p "$OUT" lib/arm64-v8a/libgodot_android.so | strings)"
grep -q "TagLibMusicRecord" <<< "$ENGINE_LIB" \
    || { echo "!! libgodot_android.so has no gdtaglib, is the source template from stock Godot?" >&2; exit 1; }
# The old gdtaglib GDExtension would register the same classes again
APK_FILES="$(unzip -l "$OUT")"
if grep -q "libgdtaglib" <<< "$APK_FILES"; then
    echo "!! The old gdtaglib GDExtension library is in the APK" >&2
    exit 1
fi

echo ">> Checking background playback made it in"
for entry in lib/arm64-v8a/libsongo_engine.android.arm64.so "lib/arm64-v8a/libsongo_harness.android.template_$MODE.arm64.so"; do
    unzip -l "$OUT" "$entry" > /dev/null || { echo "!! $entry missing from the APK" >&2; exit 1; }
done
# Captured first: grep -q stopping early would fail the pipe under pipefail
MANIFEST="$("$HOME/Android/Sdk/build-tools/34.0.0/aapt2" dump xmltree "$OUT" --file AndroidManifest.xml)"
grep -q "org.songo.harness.SongoPlaybackService" <<< "$MANIFEST" \
    || { echo "!! The playback service isn't in the APK's manifest" >&2; exit 1; }

echo ">> Verifying signature"
"$HOME/Android/Sdk/build-tools/34.0.0/apksigner" verify "$OUT"
echo ">> Done: $OUT"
