#!/bin/bash

# Sourced by playback_suppressions/setup_env.sh before Godot starts. Saves the
# user's fake suspend setting so remove can restore it after set changes it.
# Empty when never set, which rocknix-fake-suspend treats as enabled.
# 001-functions is only loaded in a subshell to keep ROCKNIX's environment out of ours.

USERS_ORIGINAL_FAKE_SUSPEND="$(. /etc/profile.d/001-functions && get_setting system.suspend.enable)"

export USERS_ORIGINAL_FAKE_SUSPEND
