#!/usr/bin/env bash
# Package Songo #5 for 64-bit Windows as an installer,
# build/windows/Songo5-Setup.exe, built from these (also left in build/windows/):
#   Songo5.exe                          Songodot's Windows template, with Songo's
#                                       icon and version info
#   Songo5.pck                          the game, loaded from next to the .exe
#   libsongo_engine.windows.x86_64.dll  the music engine
#
#   build_platforms/windows/build_windows.sh [Setup.exe output path]
#
# 1. Copies the "Windows Desktop" preset's release template, Songodot's
#    bin/godot.windows.template_release.x86_64.exe (docker_build/build_windows.sh
#    there, with the gdtaglib and songo_player_harness modules), to Songo5.exe
#    and sets its icon (from the project icon, assets/songo.png) and version
#    info with rcedit (tools/) under Wine, in a Wine prefix of its own.
# 2. Exports the preset's .pck with the Songodot editor in build_platforms/.
#    The .pck stays a separate file rather than embedded: Godot embeds it
#    after rcedit runs, which a script outside the editor can't replicate.
# 3. Copies SongoBGPlayer's Windows engine DLL next to the .exe, where
#    SongoPlayerHarness looks for it. Music plays in-process through WASAPI;
#    there's no background player on Windows, so music stops with Songo.
# 4. Compiles installer.nsi with makensis (in Docker, docker/Dockerfile) into
#    the installer: a per-user install with Start menu and optional desktop
#    shortcuts, and an uninstaller in Apps & features.
#
# Exporting from the editor instead gives one .exe with the .pck embedded but
# no icon (the preset has resource modification off, since it would need
# rcedit set up in each editor's settings).
#
# Needs wine, ImageMagick and Docker. GODOT=<path> uses another Songodot editor,
# ENGINE_DLL=<path> another SongoBGPlayer build (scripts/build_windows.sh
# there, copied into addons/songo_player_harness/bin).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLATFORMS_DIR="$(dirname "$SCRIPT_DIR")"     # build_platforms/
PROJECT_DIR="$(dirname "$PLATFORMS_DIR")"    # Songo-5/
GODOT="${GODOT:-$PLATFORMS_DIR/godot.linuxbsd.editor.x86_64.llvm}"
ENGINE_DLL="${ENGINE_DLL:-$PROJECT_DIR/addons/songo_player_harness/bin/libsongo_engine.windows.x86_64.dll}"
PRESET="Windows Desktop"
OUT_DIR="$PROJECT_DIR/build/windows"
EXE="$OUT_DIR/Songo5.exe"
PCK="$OUT_DIR/Songo5.pck"
RCEDIT="$SCRIPT_DIR/tools/rcedit-x64.exe"
ICON_SRC="$PROJECT_DIR/assets/songo.png"
# Kept apart from ~/.wine, and between runs so only the first one sets it up
export WINEPREFIX="${SONGO_WINEPREFIX:-$OUT_DIR/.wineprefix}"
export WINEDEBUG=-all
# No Mono/Gecko install prompts, rcedit needs neither
export WINEDLLOVERRIDES="mscoree,mshtml="
SETUP="${1:-$OUT_DIR/Songo5-Setup.exe}"
# Relative output paths are relative to where the script was run from
case "$SETUP" in /*) ;; *) SETUP="$PWD/$SETUP" ;; esac
NSIS_IMAGE="${SONGO_NSIS_IMAGE:-songo5-nsis}"

if [ ! -x "$GODOT" ]; then
    echo "!! Songodot editor not found at $GODOT" >&2
    echo "   Copy ../Songodot/bin/godot.linuxbsd.editor.x86_64.llvm into build_platforms/." >&2
    exit 1
fi
for tool in wine magick; do
    command -v "$tool" > /dev/null || { echo "!! $tool not found, it's needed to set the .exe's icon" >&2; exit 1; }
done
if [ ! -f "$RCEDIT" ]; then
    echo "!! $RCEDIT is missing (see tools/README.md)" >&2
    exit 1
fi
if [ ! -f "$ENGINE_DLL" ]; then
    echo "!! SongoBGPlayer's Windows engine not found at $ENGINE_DLL" >&2
    echo "   Build it in ../SongoBGPlayer (scripts/build_windows.sh) and copy bin/libsongo_engine.windows.x86_64.dll into addons/songo_player_harness/bin/." >&2
    exit 1
fi

# The preset's template, which must be a current Songodot one
TEMPLATE="$(awk -v preset="$PRESET" '
    /^\[preset\.[0-9]+\]$/ { section = $0; in_preset = 0 }
    $0 == "name=\"" preset "\"" { in_preset = 1 }
    /^\[preset\.[0-9]+\.options\]$/ { in_options = (in_preset && $0 == substr(section, 1, length(section) - 1) ".options]") }
    in_options && index($0, "custom_template/release=") == 1 {
        value = substr($0, length("custom_template/release=") + 1); gsub(/"/, "", value); print value; exit
    }
' "$PROJECT_DIR/export_presets.cfg")"
if [ -z "$TEMPLATE" ] || [ ! -f "$TEMPLATE" ]; then
    echo "!! The '$PRESET' preset's release template ('$TEMPLATE') doesn't exist." >&2
    echo "   Build it in ../Songodot with docker_build/build_windows.sh." >&2
    exit 1
fi
# Captured first: grep -q stopping early would fail the pipe under pipefail
TEMPLATE_STRINGS="$(strings "$TEMPLATE")"
for class in TagLibLibrary SongoPlayerHarness; do
    grep -q "$class" <<< "$TEMPLATE_STRINGS" \
        || { echo "!! $TEMPLATE has no $class, is it a current Songodot Windows template?" >&2; exit 1; }
done

mkdir -p "$OUT_DIR"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

# Songo's version, eg: "v1.0.0 RC8". Windows wants a numeric file version too.
VERSION="$(sed -n 's/^const VERSION = "\(.*\)"$/\1/p' "$PROJECT_DIR/data/songo_data.gd" | head -n1)"
NUMERIC_VERSION="$(grep -oE '[0-9]+(\.[0-9]+){0,3}' <<< "$VERSION" | head -n1)"
while [ "$(tr -cd . <<< "$NUMERIC_VERSION" | wc -c)" -lt 3 ]; do NUMERIC_VERSION="$NUMERIC_VERSION.0"; done

echo ">> Making Songo5.exe from the template, with Songo's icon and version info ($VERSION)"
rm -f "$EXE" "$OUT_DIR/Songo5.console.exe"
cp -f "$TEMPLATE" "$WORK/Songo5.exe"
# The sizes Godot's own export puts in the .ico
magick "$ICON_SRC" -background none -define icon:auto-resize=256,128,64,48,32,16 "$OUT_DIR/songo.ico"
wine "$RCEDIT" "$WORK/Songo5.exe" \
    --set-icon "$OUT_DIR/songo.ico" \
    --set-file-version "$NUMERIC_VERSION" \
    --set-product-version "$NUMERIC_VERSION" \
    --set-version-string ProductName "Songo #5" \
    --set-version-string FileDescription "Songo #5" \
    --set-version-string ProductVersion "$VERSION" \
    --set-version-string OriginalFilename "Songo5.exe" \
    --set-version-string InternalName "Songo5"
mv "$WORK/Songo5.exe" "$EXE"

echo ">> Exporting preset '$PRESET' -> build/windows/Songo5.pck"
touch "$WORK/started"
"$GODOT" --headless --path "$PROJECT_DIR" --export-pack "$PRESET" "$PCK"
if [ ! "$PCK" -nt "$WORK/started" ]; then
    echo "!! Export didn't produce $PCK" >&2
    exit 1
fi

echo ">> Copying the music engine -> build/windows/$(basename "$ENGINE_DLL")"
cp -f "$ENGINE_DLL" "$OUT_DIR/"

# Only Windows' own DLLs, so the two files are all a user needs
echo ">> Checking neither needs DLLs Windows doesn't have"
for f in "$EXE" "$OUT_DIR/$(basename "$ENGINE_DLL")"; do
    EXTRA="$(objdump -p "$f" | sed -n 's/^\s*DLL Name: //p' | grep -viE '^(kernel32|user32|gdi32|advapi32|shell32|ole32|oleaut32|ws2_32|wsock32|dwrite|bcrypt|secur32|msvcrt|winmm|dwmapi|imm32|shlwapi|uuid|version|dinput8|dxgi|wbemuuid|dsound|avrt|iphlpapi|setupapi|hid|ntdll|crypt32|opengl32|uxtheme|comctl32|comdlg32|propsys|mfplat|mfreadwrite|mfuuid|userenv|winhttp|xinput1_4|api-ms-win-.*)\.dll$' || true)"
    if [ -n "$EXTRA" ]; then
        echo "!! $(basename "$f") needs DLLs that won't be on the user's machine: $EXTRA" >&2
        exit 1
    fi
done

cp -f "$PROJECT_DIR/build_platforms/portmaster/songo5/license/LICENSE.txt" "$OUT_DIR/LICENSE.txt"

echo ">> Building the installer -> $SETUP"
docker build -q -t "$NSIS_IMAGE" "$SCRIPT_DIR/docker" > /dev/null
mkdir -p "$(dirname "$SETUP")"
rm -f "$SETUP"
# As the calling user, so the installer isn't owned by root
docker run --rm \
    --user "$(id -u):$(id -g)" \
    -v "$SCRIPT_DIR:/nsis:ro" \
    -v "$OUT_DIR:/files:ro" \
    -v "$(dirname "$SETUP"):/out" \
    "$NSIS_IMAGE" -V2 \
    -DSRC=/files \
    -DICON=/files/songo.ico \
    -DOUT_FILE="/out/$(basename "$SETUP")" \
    -DVERSION="$VERSION" \
    -DNUMERIC_VERSION="$NUMERIC_VERSION" \
    /nsis/installer.nsi
if [ ! -f "$SETUP" ]; then
    echo "!! makensis didn't produce $SETUP" >&2
    exit 1
fi
# The old portable zip, if an earlier build left one
rm -f "$OUT_DIR/songo5-windows.zip"

echo ">> Done: $SETUP ($(du -h "$SETUP" | cut -f1))"
