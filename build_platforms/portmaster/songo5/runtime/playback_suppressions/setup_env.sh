#!/bin/bash

# Sourced by Songo5.sh (needs GAMEDIR and SONGO_CFW_NAME), exports the scripts
# Godot runs when music starts (set) and stops (remove). Falls back to the
# default strategy when the CFW has no folder of its own. Sourced after
# background_play/setup_env.sh, which sets SONGO_PLAYER_PID.

SET_PLAYBACK_SUPPRESSIONS_PATH=""
REMOVE_PLAYBACK_SUPPRESSIONS_PATH=""

PLAYBACK_SUPPRESSIONS_DIR="${GAMEDIR}/runtime/playback_suppressions/${SONGO_CFW_NAME}"
if [ ! -e "${PLAYBACK_SUPPRESSIONS_DIR}/set" ] || [ ! -e "${PLAYBACK_SUPPRESSIONS_DIR}/remove" ]; then
	PLAYBACK_SUPPRESSIONS_DIR="${GAMEDIR}/runtime/playback_suppressions/default"
fi

if [ -e "${PLAYBACK_SUPPRESSIONS_DIR}/set" ] && [ -e "${PLAYBACK_SUPPRESSIONS_DIR}/remove" ]; then
	if [ -n "$SONGO_PLAYER_PID" ] && [ -r "/proc/${SONGO_PLAYER_PID}/environ" ]; then
		# Music left playing by "Quit with Music" still has the suppressions on,
		# so setup.sh would save the suppressed values as the user's. The player
		# was started by the Songo that saved the real ones and still has them
		# (its exit hook runs remove with them), so take them from it instead.
		while IFS= read -r -d '' VAR; do
			case "$VAR" in
				USERS_ORIGINAL_*=*) export "$VAR" ;;
			esac
		done < "/proc/${SONGO_PLAYER_PID}/environ"
	elif [ -e "${PLAYBACK_SUPPRESSIONS_DIR}/setup.sh" ]; then
		# Optional per-CFW setup, eg: saving the user's settings for remove to restore
		source "${PLAYBACK_SUPPRESSIONS_DIR}/setup.sh"
	fi

	SET_PLAYBACK_SUPPRESSIONS_PATH="${PLAYBACK_SUPPRESSIONS_DIR}/set"
	REMOVE_PLAYBACK_SUPPRESSIONS_PATH="${PLAYBACK_SUPPRESSIONS_DIR}/remove"
fi

export SET_PLAYBACK_SUPPRESSIONS_PATH
export REMOVE_PLAYBACK_SUPPRESSIONS_PATH
