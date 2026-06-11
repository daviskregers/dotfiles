#!/bin/bash
# Only shows battery in i3status if a battery is present

CONFIG_DIR="${HOME}/.config/i3status"
CONFIG_FILE="${CONFIG_DIR}/config"
TEMP_CONFIG="${CONFIG_DIR}/config.tmp"

if ls /sys/class/power_supply/BAT* >/dev/null 2>&1; then
    i3status -c "${CONFIG_FILE}"
else
    grep -v '^order += "battery all"$' "${CONFIG_FILE}" > "${TEMP_CONFIG}"
    i3status -c "${TEMP_CONFIG}"
    rm -f "${TEMP_CONFIG}"
fi
