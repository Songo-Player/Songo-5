# Shared by the default battery scripts. Prints the battery's power_supply dir.
find_battery_dir() {
    for DIR in \
        /sys/class/power_supply/cw221X-bat \
        /sys/class/power_supply/axp2202-battery \
        /sys/class/power_supply/battery; do
        [ -d "$DIR" ] && { echo "$DIR"; return 0; }
    done

    # Anything else the kernel reports as a battery
    for DIR in /sys/class/power_supply/*; do
        [ "$(cat "$DIR/type" 2>/dev/null)" = "Battery" ] && { echo "$DIR"; return 0; }
    done

    return 1
}

# Prints $1 if it's a 0-100 integer (clamped), fails otherwise
print_percent() {
    case "$1" in
        ''|*[!0-9]*) return 1 ;;
    esac
    if [ "$1" -gt 100 ]; then echo 100; else echo "$1"; fi
}

# Kernel battery status to 1 (Charging) or 0 (Discharging, Not charging,
# Full, Unknown, or anything unreadable)
print_charging() {
    case "$1" in
        Charging) echo 1 ;;
        *) echo 0 ;;
    esac
}
