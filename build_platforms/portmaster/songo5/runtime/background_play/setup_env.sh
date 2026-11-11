#!/bin/bash

# Sourced by Songo5.sh before Godot starts, and before the playback
# suppressions setup.
#
# Music plays in songo_player_harness's daemon (addons/songo_player_harness),
# which Songo starts and controls. "Quit with Music" leaves it playing after
# Songo exits, with the playback suppressions on and Songo's exit hook to
# remove them when it stops. It's left running here so Songo can pick its
# queue back up on boot. The suppressions setup uses SONGO_PLAYER_PID to take
# the user's settings from it rather than saving the suppressed ones.
#
# Godot and the daemon both have the sound device open while Songo runs, so
# this needs a sound server (PipeWire or PulseAudio) to share it.

# Tells Godot background playback is available, enabling "Quit with Music"
SONGO_SBC_BG_PLAY="1"
# Where the daemon listens. Its lock file next to it holds its PID.
SONGO_PLAYER_SOCKET="/tmp/songo_player.sock"

# The daemon's PID if it's running, checked by name as a stale lock file's PID
# may belong to something else by now
songo_player_pid() {
	local pid
	pid="$(cat "${SONGO_PLAYER_SOCKET}.lock" 2>/dev/null)"
	if [ -n "$pid" ] && cat "/proc/${pid}/cmdline" 2>/dev/null | tr '\0' ' ' | grep -q songo_bgplayer; then
		echo "$pid"
	fi
}

SONGO_PLAYER_PID="$(songo_player_pid)"
if [ -n "$SONGO_PLAYER_PID" ]; then
	echo "Music player left playing (PID ${SONGO_PLAYER_PID}), Songo will pick it up"
fi

# ALSA's "default" isn't always routed through the sound server, while these
# are when they exist
SONGO_AUDIO_DEVICE=""
if command -v aplay >/dev/null 2>&1; then
	for DEVICE in pipewire pulse; do
		if aplay -L 2>/dev/null | grep -qx "$DEVICE"; then
			SONGO_AUDIO_DEVICE="$DEVICE"
			break
		fi
	done
fi
if ! pgrep -x pipewire >/dev/null 2>&1 && ! pgrep -x pulseaudio >/dev/null 2>&1; then
	echo "WARNING: No sound server running, music and Songo's sounds may not play together"
fi
echo "Music player ALSA device: ${SONGO_AUDIO_DEVICE:-default}"

export SONGO_SBC_BG_PLAY
export SONGO_PLAYER_SOCKET
export SONGO_AUDIO_DEVICE
