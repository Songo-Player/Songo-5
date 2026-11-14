#!/bin/bash
# PORTMASTER: songo5.zip, Songo5.sh

# PortMaster preamble
XDG_DATA_HOME=${XDG_DATA_HOME:-$HOME/.local/share}
if [ -d "/opt/system/Tools/PortMaster/" ]; then
  controlfolder="/opt/system/Tools/PortMaster"
elif [ -d "/opt/tools/PortMaster/" ]; then
  controlfolder="/opt/tools/PortMaster"
elif [ -d "$XDG_DATA_HOME/PortMaster/" ]; then
  controlfolder="$XDG_DATA_HOME/PortMaster"
else
  controlfolder="/roms/ports/PortMaster"
fi
source $controlfolder/control.txt
[ -f "${controlfolder}/mod_${CFW_NAME}.txt" ] && source "${controlfolder}/mod_${CFW_NAME}.txt"
get_controls

# Adjust these to your paths and desired godot version
GAMEDIR=/$directory/ports/songo5

runtime="sbc_4_3_rcv12"
pck_filename="Songo5.pck"
gptk_filename="songo5.gptk"

# Logging
> "$GAMEDIR/log.txt" && exec > >(tee "$GAMEDIR/log.txt") 2>&1

# Check for ROCKNIX running with libMali driver.
if [[ "$CFW_NAME" = "ROCKNIX" ]]; then
	GODOT_OPTS=${GODOT_OPTS//-f/}
    if ! glxinfo | grep "OpenGL version string"; then
    pm_message "This Port does not support the libMali graphics driver. Switch to Panfrost to continue."
    sleep 5
    exit 1
    fi
fi

echo "LOOKING FOR CFW_NAME ${CFW_NAME}"
export CFW_NAME
echo "LOOKING FOR DEVICE ID ${DEVICE_NAME}"
export DEVICE_NAME

# Create directory for save files
CONFDIR="$GAMEDIR/conf/"
$ESUDO mkdir -p "${CONFDIR}"

# Detect CFW, used to pick the controls strategy below
source "${GAMEDIR}/runtime/set_cfw_strategy.sh"

# CHAI: makes sure "chai" is a command, the CFW's own or the retrofit for it.
# Godot (DeviceOS) uses it for brightness, battery and idle suppression.
if [ -f "${GAMEDIR}/chai_retrofit/chai_entry.sh" ]; then
	source "${GAMEDIR}/chai_retrofit/chai_entry.sh"
fi

# Volume indicator: chai runs the subscriber on every volume change, and it
# passes the volume to Godot's listener
SONGO_VOL_SUBSCRIBER="${GAMEDIR}/runtime/chai_volume_subscriber.sh"
USE_SONGO_VOL_TCP_SERVER="0"
if chai add-volume-subscriber "$SONGO_VOL_SUBSCRIBER" 2>/dev/null; then
	USE_SONGO_VOL_TCP_SERVER="1"
fi
export USE_SONGO_VOL_TCP_SERVER

# Screen fades need a brightness chai can read back, otherwise Songo fades an
# overlay instead
case "$(chai get-brightness 2>/dev/null)" in
	'' | *[!0-9]*) NO_BRIGHT_FADE_AVAILABLE="1" ;;
	*) NO_BRIGHT_FADE_AVAILABLE="0" ;;
esac
export NO_BRIGHT_FADE_AVAILABLE

# Find a music player left playing by "Quit with Music" for Songo to pick back
# up, and set up the next one
source "${GAMEDIR}/runtime/background_play/setup_env.sh"

# Set up controls
source "${GAMEDIR}/runtime/controls/setup_env.sh"

cd $GAMEDIR


# Set the XDG environment variables for config & savefiles
export XDG_DATA_HOME="$CONFDIR"
export SDL_GAMECONTROLLERCONFIG="$sdl_controllerconfig"

echo "XDG_DATA_HOME"
echo $XDG_DATA_HOME

# This is only used with Vulkan on KMSDRM 
export SONGODOT_KMSDRM_ROTATION="270"


$GPTOKEYB "$GAMEDIR/runtime/$runtime" -c "$GAMEDIR/$gptk_filename" &
# TrimUI Smart Pro / Smart Pro S only. The kernel names the board in
# /proc/cpuinfo (TG5040 Smart Pro, TG5050 Smart Pro S, TG3040 Brick), and
# PortMaster's DEVICE_NAME is checked too as it differs per CFW
case "$(echo "$DEVICE_NAME" | tr '[:upper:]' '[:lower:]')" in
	*"smart pro"*|*smart-pro*|tui-spoon) IS_TSP=1 ;;
esac
grep -qE 'TG5040|TG5050' /proc/cpuinfo 2>/dev/null && IS_TSP=1
if [ -n "$IS_TSP" ]; then
	sleep 0.6 # For TSP only, do not move/modify this line.
fi
pm_platform_helper "$GAMEDIR/runtime/$runtime"



# The RG Vita runs on Vulkan, where Forward+ takes ~11s to start and Mobile
# ~3.5s. muOS names it RG-VITA-PRO, Knulli rg-vita-pro (knulli.board), older
# PortMaster falls back to the devicetree model RG VITA. Everything else runs
# Compatibility on GLES3, which the sbc runtime's "opengl3" driver creates.
# Its "opengl3_es" sets up no GL context and segfaults
case "$(echo "$DEVICE_NAME" | tr '[:upper:]' '[:lower:]')" in
	*vita*) GODOT_OPTS="$GODOT_OPTS --rendering-method mobile" ;;
	*) GODOT_OPTS="$GODOT_OPTS --rendering-method gl_compatibility --rendering-driver opengl3" ;;
esac
 "$GAMEDIR/runtime/$runtime" $GODOT_OPTS --main-pack "gamedata/Songo5.pck" 

# Cleanup

chai remove-volume-subscriber "$SONGO_VOL_SUBSCRIBER" 2>/dev/null

# Undo the retrofit's setup (volume wrappers and listeners). Nothing to undo
# with native chai.
if command -v chai_retrofit_teardown >/dev/null 2>&1; then
	chai_retrofit_teardown
fi

# Turn idle suppression off in case Songo exited while music was playing.
# Skipped after "Quit with Music": the music player is still playing and turns
# it off itself (the exit hook Songo left it) when it stops. Otherwise it
# quits right behind Songo, so it gets a moment to go first.
for _ in $(seq 10); do
	[ -z "$(songo_player_pid)" ] && break
	sleep 0.1
done
if [ -z "$(songo_player_pid)" ]; then
	chai set-idle-suppression 0 2>/dev/null
fi

# Fix brightness if app crashed when at 0
if [ "$(chai get-brightness 2>/dev/null)" = "0" ]; then
	if command -v syncsettings.elf >/dev/null 2>&1; then
		# NextUI: restore the user's saved brightness
		echo "Backlight left at 0, restoring NextUI's brightness"
		syncsettings.elf
	else
		echo "Backlight left at 0, restoring to half brightness"
		chai set-brightness 128 2>/dev/null
	fi
fi

pm_finish
