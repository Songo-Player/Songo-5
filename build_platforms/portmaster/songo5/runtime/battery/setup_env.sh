#!/bin/bash

# Sourced by Songo5.sh (needs GAMEDIR and SONGO_CFW_NAME), exports the
# battery variables Godot reads

# Set up battery commands
SONGO_GET_BATTERY_PERCENT_PATH="${GAMEDIR}/runtime/battery/default/get_battery_percent"
SONGO_GET_CHARGING_PATH="${GAMEDIR}/runtime/battery/default/get_charging"

if [ -e "${GAMEDIR}/runtime/battery/${SONGO_CFW_NAME}/get_battery_percent" ]; then
	SONGO_GET_BATTERY_PERCENT_PATH="${GAMEDIR}/runtime/battery/${SONGO_CFW_NAME}/get_battery_percent"
fi

if [ -e "${GAMEDIR}/runtime/battery/${SONGO_CFW_NAME}/get_charging" ]; then
	SONGO_GET_CHARGING_PATH="${GAMEDIR}/runtime/battery/${SONGO_CFW_NAME}/get_charging"
fi

export SONGO_GET_BATTERY_PERCENT_PATH
export SONGO_GET_CHARGING_PATH
