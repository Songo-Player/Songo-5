#!/bin/bash

# Sourced by Songo5.sh (needs GAMEDIR and SONGO_CFW_NAME), starts the
# volume indicator and exports the variables Godot reads

# Setup volume indicator
USE_SONGO_VOL_TCP_SERVER="0"

if [[ "$SONGO_CFW_NAME" != "NONE" ]]; then
	USE_SONGO_VOL_TCP_SERVER="1"
	sh "${GAMEDIR}/runtime/volume-indicator/setup_vol_indicator" "${SONGO_CFW_NAME}"
fi
export USE_SONGO_VOL_TCP_SERVER
