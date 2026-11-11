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

# Detect CFW, used to pick the runtime strategies below
source "${GAMEDIR}/runtime/set_cfw_strategy.sh"

# Setup volume indicator
source "${GAMEDIR}/runtime/volume-indicator/setup_env.sh"

# Set up brightness commands
source "${GAMEDIR}/runtime/brightness/setup_env.sh"

# Set up battery commands
source "${GAMEDIR}/runtime/battery/setup_env.sh"

# Find a music player left playing by "Quit with Music" for Songo to pick back
# up, and set up the next one. Before the playback suppressions setup, which
# takes the user's settings from that player rather than saving suppressed ones
source "${GAMEDIR}/runtime/background_play/setup_env.sh"

# Set up playback suppressions
source "${GAMEDIR}/runtime/playback_suppressions/setup_env.sh"

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

if [[ "$SONGO_CFW_NAME" != "NONE" ]]; then
	# Teardown volume indicator
	sh "${GAMEDIR}/runtime/volume-indicator/teardown_vol_indicator" "${SONGO_CFW_NAME}"
fi

# Undo playback suppressions in case Songo exited while music was playing.
# Skipped after "Quit with Music": the music player is still playing and
# removes them itself (the exit hook Songo left it) when it stops. Otherwise
# it quits right behind Songo, so it gets a moment to go first.
for _ in $(seq 10); do
	[ -z "$(songo_player_pid)" ] && break
	sleep 0.1
done
if [ -n "$REMOVE_PLAYBACK_SUPPRESSIONS_PATH" ] && [ -z "$(songo_player_pid)" ]; then
	"$REMOVE_PLAYBACK_SUPPRESSIONS_PATH"
fi

# Fix brightness if app crashed when at 0
CURRENT_BRIGHTNESS="$(bash "$SONGO_GET_BRIGHTNESS_PATH" 2>/dev/null)"
if [ "$CURRENT_BRIGHTNESS" = "0" ]; then
	echo "Backlight left at 0, restoring to half brightness"
	sh -c "$SONGO_SET_BRIGHTNESS_PATH 128"
fi

pm_finish
