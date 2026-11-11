#!/bin/bash

# Sourced by Songo5.sh (needs GAMEDIR and SONGO_CFW_NAME), exports the control
# variables Godot reads. A CFW folder's setup.sh overrides the defaults.
# Each SONGO_CTRL_* var sets the default binding for that control on first boot
# and on "Reset to Defaults", using Godot names (JOY_BUTTON_A, KEY_ENTER, ...).
# Left empty, Songo uses its built-in default.

SONGO_CTRL_ACCEPT=""
SONGO_CTRL_BACK=""
SONGO_CTRL_SHUFFLE=""
SONGO_CTRL_QUICK_MENU=""
SONGO_CTRL_L1=""
SONGO_CTRL_R1=""
SONGO_CTRL_L2=""
SONGO_CTRL_R2=""
SONGO_CTRL_START=""
SONGO_CTRL_SELECT=""

if [ -e "${GAMEDIR}/runtime/controls/${SONGO_CFW_NAME}/setup.sh" ]; then
	source "${GAMEDIR}/runtime/controls/${SONGO_CFW_NAME}/setup.sh"
fi

export SONGO_CTRL_ACCEPT SONGO_CTRL_BACK SONGO_CTRL_SHUFFLE SONGO_CTRL_QUICK_MENU
export SONGO_CTRL_L1 SONGO_CTRL_R1 SONGO_CTRL_L2 SONGO_CTRL_R2
export SONGO_CTRL_START SONGO_CTRL_SELECT
