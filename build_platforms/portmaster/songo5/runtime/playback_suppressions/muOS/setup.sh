#!/bin/bash

# Sourced by playback_suppressions/setup_env.sh before Godot starts. Saves the
# user's idle settings so remove can restore them after set zeroes them.
# func.sh is only loaded in subshells to keep muOS's environment out of ours.

USERS_ORIGINAL_IDLE_SLEEP="$(. /opt/muos/script/var/func.sh && GET_VAR "config" "settings/power/idle_sleep")"
USERS_ORIGINAL_IDLE_DISPLAY="$(. /opt/muos/script/var/func.sh && GET_VAR "config" "settings/power/idle_display")"

export USERS_ORIGINAL_IDLE_SLEEP
export USERS_ORIGINAL_IDLE_DISPLAY
