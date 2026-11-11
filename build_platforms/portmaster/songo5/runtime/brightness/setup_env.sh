#!/bin/bash

# Sourced by Songo5.sh (needs GAMEDIR and SONGO_CFW_NAME), exports the
# brightness variables Godot reads

# Set up brightness commands (Based on IncognitoMans approach)
export SYSFS_BL_BRIGHTNESS="$(find /sys/class/backlight/*/ -name brightness 2>/dev/null | head -n 1)"
export SYSFS_BL_COMMAND="$(find /sys/kernel/debug/dispdbg/ -name command 2>/dev/null | head -n 1)"

if [ -n "${SYSFS_BL_BRIGHTNESS}" ]; then
  echo "Backlight TYPE2 detected! setting path/type."
  export BL_TYPE="TYPE2"
  export SYSFS_BL_POWER="$(find /sys/class/backlight/*/ -name bl_power )"
  export SYSFS_BL_MAX="$(find /sys/class/backlight/*/ -name max_brightness 2>/dev/null | head -n 1)"
elif [ -n "${SYSFS_BL_COMMAND}" ]; then
  echo "Backlight TYPE1 detected! setting path/type."
  export BL_TYPE="TYPE1"
  export SYSFS_BL_NAME="$(find /sys/kernel/debug/dispdbg/ -name name 2>/dev/null | head -n 1)"
  export SYSFS_BL_PARAM="$(find /sys/kernel/debug/dispdbg/ -name param 2>/dev/null | head -n 1)"
  export SYSFS_BL_START="$(find /sys/kernel/debug/dispdbg/ -name start 2>/dev/null | head -n 1)"
  export BL_COMMAND="setbl"
  export BL_NAME="lcd0"
else
  echo "Backlight objects not found!"
  export BL_TYPE="UNKNOWN"
fi

DEFAULT_GET_BRIGHTNESS_PATH="${GAMEDIR}/runtime/brightness/default/get_brightness"
DEFAULT_SET_BRIGHTNESS_PATH="${GAMEDIR}/runtime/brightness/default/set_brightness"
SONGO_GET_BRIGHTNESS_PATH="$DEFAULT_GET_BRIGHTNESS_PATH"
SONGO_SET_BRIGHTNESS_PATH="$DEFAULT_SET_BRIGHTNESS_PATH"
NO_BRIGHT_FADE_AVAILABLE='0'

if [ -e "${GAMEDIR}/runtime/brightness/${SONGO_CFW_NAME}/get_brightness" ]; then
	SONGO_GET_BRIGHTNESS_PATH="${GAMEDIR}/runtime/brightness/${SONGO_CFW_NAME}/get_brightness"
fi

if [ -e "${GAMEDIR}/runtime/brightness/${SONGO_CFW_NAME}/set_brightness" ]; then
	SONGO_SET_BRIGHTNESS_PATH="${GAMEDIR}/runtime/brightness/${SONGO_CFW_NAME}/set_brightness"
fi

if [ "$BL_TYPE" = "UNKNOWN" ] && [ "$SONGO_SET_BRIGHTNESS_PATH" = "$DEFAULT_SET_BRIGHTNESS_PATH" ]; then
	NO_BRIGHT_FADE_AVAILABLE='1'
fi

export SONGO_GET_BRIGHTNESS_PATH
export SONGO_SET_BRIGHTNESS_PATH
export NO_BRIGHT_FADE_AVAILABLE
