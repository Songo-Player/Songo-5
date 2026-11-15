#!/usr/bin/env bash
# Package Songo #5 for PortMaster: build/portmaster/songo5.zip, holding the
# Songo5.sh launcher and the songo5/ port directory next to this script.
#
#   build_platforms/portmaster/build_portmaster.sh [output.zip]
#
# 1. Exports the arm64 "Linux" preset's .pck into songo5/gamedata/ with the
#    Songodot editor in build_platforms/.
# 2. Copies the Songodot SBC arm64 runtime from build_platforms/ into
#    songo5/runtime/, under the name Songo5.sh runs (runtime="..." there),
#    and SongoBGPlayer's arm64 music engine library and songo_bgplayer daemon
#    next to it, where Songodot's SongoPlayerHarness looks for them.
# 3. Zips Songo5.sh and songo5/ into the output.
#
# PRESET=<name> exports another preset; GODOT=<path> and RUNTIME=<path> use
# other Songodot binaries, ENGINE_LIB=<path> and DAEMON=<path> other
# SongoBGPlayer builds.
#
# Both Godot binaries are copies from Songodot (../Songodot), the custom engine
# with the gdtaglib and songo_player_harness modules built in. Copy them again
# after rebuilding:
#   bin/godot.linuxbsd.editor.x86_64.llvm   (scons platform=linuxbsd target=editor use_llvm=yes)
#   bin/godot.sbc.template_release.arm64.llvm   (docker_build/build_sbc.sh)
# The engine library and daemon come from ../SongoBGPlayer
# (docker_build/build_arm64.sh), copied into addons/songo_player_harness/bin.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLATFORMS_DIR="$(dirname "$SCRIPT_DIR")"     # build_platforms/
PROJECT_DIR="$(dirname "$PLATFORMS_DIR")"    # Songo-5/
GODOT="${GODOT:-$PLATFORMS_DIR/godot.linuxbsd.editor.x86_64.llvm}"
RUNTIME="${RUNTIME:-$PLATFORMS_DIR/godot.sbc.template_release.arm64.llvm}"
ENGINE_LIB="${ENGINE_LIB:-$PROJECT_DIR/addons/songo_player_harness/bin/libsongo_engine.linux.arm64.so}"
DAEMON="${DAEMON:-$PROJECT_DIR/addons/songo_player_harness/bin/songo_bgplayer.linux.arm64}"
PRESET="${PRESET:-Linux}"
OUT="${1:-$PROJECT_DIR/build/portmaster/songo5.zip}"
# Relative output paths are relative to where the script was run from
case "$OUT" in /*) ;; *) OUT="$PWD/$OUT" ;; esac

LAUNCHER="$SCRIPT_DIR/Songo5.sh"
PORT_DIR="$SCRIPT_DIR/songo5"

# songo5/chai_retrofit is a git submodule (Songo-Player/chai_retrofit). Pull
# its latest commit before packaging. This moves the submodule pointer, so
# Songo-5 shows it as modified until that's committed. Offline, or with local
# changes in the submodule, it keeps the current checkout and warns instead.
CHAI_SUBMODULE="build_platforms/portmaster/songo5/chai_retrofit"
echo ">> Pulling the latest chai_retrofit"
if ! git -C "$PROJECT_DIR" submodule update --init --remote -- "$CHAI_SUBMODULE"; then
    echo "!! Couldn't update chai_retrofit, building with the current checkout" >&2
fi
if [ ! -f "$PORT_DIR/chai_retrofit/chai_entry.sh" ]; then
    echo "!! songo5/chai_retrofit is empty. Run: git submodule update --init" >&2
    exit 1
fi
echo "   chai_retrofit at $(git -C "$PORT_DIR/chai_retrofit" log -1 --format='%h %s')"

for f in "$GODOT" "$RUNTIME"; do
    if [ ! -x "$f" ]; then
        echo "!! Songodot binary not found at $f" >&2
        echo "   Copy it from ../Songodot/bin/ into build_platforms/ (see the top of this script)." >&2
        exit 1
    fi
done
for f in "$ENGINE_LIB" "$DAEMON"; do
    if [ ! -f "$f" ]; then
        echo "!! SongoBGPlayer build not found at $f" >&2
        echo "   Build it in ../SongoBGPlayer (docker_build/build_arm64.sh) and copy bin/*linux.arm64* into addons/songo_player_harness/bin/." >&2
        exit 1
    fi
done
if [ ! -f "$LAUNCHER" ] || [ ! -d "$PORT_DIR" ]; then
    echo "!! Expected Songo5.sh and songo5/ next to this script." >&2
    exit 1
fi

# The runtime and .pck names the launcher uses
RUNTIME_NAME="$(sed -n 's/^runtime="\(.*\)"$/\1/p' "$LAUNCHER" | head -n1)"
PCK_NAME="$(sed -n 's/^pck_filename="\(.*\)"$/\1/p' "$LAUNCHER" | head -n1)"
if [ -z "$RUNTIME_NAME" ] || [ -z "$PCK_NAME" ]; then
    echo "!! Couldn't read runtime=\"...\" / pck_filename=\"...\" from Songo5.sh." >&2
    exit 1
fi

# The runtime has gdtaglib and songo_player_harness built in; the old
# GDExtensions would register the same classes again
for old in gdtaglib songo_player_harness; do
    if [ -e "$PORT_DIR/addons/$old" ]; then
        echo "!! songo5/addons/$old is the old GDExtension, which Songodot replaces. Remove it." >&2
        exit 1
    fi
done
# Captured first: grep -q stopping early would fail the pipe under pipefail
RUNTIME_STRINGS="$(strings "$RUNTIME")"
for class in TagLibLibrary SongoPlayerHarness; do
    grep -q "$class" <<< "$RUNTIME_STRINGS" \
        || { echo "!! $RUNTIME has no $class, is it a current Songodot SBC build?" >&2; exit 1; }
done

PCK="$PORT_DIR/gamedata/$PCK_NAME"
mkdir -p "$(dirname "$PCK")"
echo ">> Exporting preset '$PRESET' -> songo5/gamedata/$PCK_NAME"
STARTED="$(mktemp)"
trap 'rm -f "$STARTED"' EXIT
"$GODOT" --headless --path "$PROJECT_DIR" --export-pack "$PRESET" "$PCK"
if [ ! "$PCK" -nt "$STARTED" ]; then
    echo "!! Export didn't produce $PCK" >&2
    exit 1
fi

echo ">> Copying the runtime -> songo5/runtime/$RUNTIME_NAME"
cp -f "$RUNTIME" "$PORT_DIR/runtime/$RUNTIME_NAME"
chmod +x "$PORT_DIR/runtime/$RUNTIME_NAME"

echo ">> Copying the music engine and daemon -> songo5/runtime/"
cp -f "$ENGINE_LIB" "$PORT_DIR/runtime/libsongo_engine.linux.arm64.so"
cp -f "$DAEMON" "$PORT_DIR/runtime/songo_bgplayer.linux.arm64"
chmod +x "$PORT_DIR/runtime/songo_bgplayer.linux.arm64"

echo ">> Zipping Songo5.sh and songo5/ -> $OUT"
mkdir -p "$(dirname "$OUT")"
rm -f "$OUT"
# No zip on every machine, so Python's zipfile, keeping Unix permissions
# (the runtime and scripts must stay executable). Device-side files (log.txt,
# conf/) are left out in case a port directory was copied back off a device.
python3 - "$SCRIPT_DIR" "$OUT" <<'EOF'
import os, stat, sys, zipfile

base, out = sys.argv[1], sys.argv[2]
skip = {"songo5/log.txt", "songo5/conf"}

def add(zf, rel):
    path = os.path.join(base, rel)
    st = os.stat(path)
    if os.path.isdir(path):
        info = zipfile.ZipInfo(rel + "/")
        info.external_attr = (stat.S_IFDIR | 0o755) << 16
        zf.writestr(info, b"")
        for name in sorted(os.listdir(path)):
            child = rel + "/" + name
            # Git metadata, eg: the chai_retrofit submodule's .git file
            if child not in skip and name != ".git":
                add(zf, child)
    else:
        info = zipfile.ZipInfo.from_file(path, rel)
        info.external_attr = (stat.S_IFREG | stat.S_IMODE(st.st_mode)) << 16
        info.compress_type = zipfile.ZIP_DEFLATED
        with open(path, "rb") as f:
            zf.writestr(info, f.read(), compresslevel=9)

with zipfile.ZipFile(out, "w") as zf:
    add(zf, "Songo5.sh")
    add(zf, "songo5")
EOF

echo ">> Done: $OUT ($(du -h "$OUT" | cut -f1))"
