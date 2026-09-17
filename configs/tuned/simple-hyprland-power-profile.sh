#!/usr/bin/env bash
# Use TuneD's PPD compatibility layer: performance on AC, balanced on battery.
set -Eeuo pipefail

power_supply_root=${POWER_SUPPLY_ROOT:-/sys/class/power_supply}
busctl_bin=${POWER_PROFILE_BUSCTL:-/usr/bin/busctl}

has_battery=false
on_external_power=false
for supply in "$power_supply_root"/*; do
    [[ -r "$supply/type" ]] || continue
    if [[ -r "$supply/scope" && $(<"$supply/scope") == Device ]]; then
        continue
    fi
    supply_type=$(<"$supply/type")
    if [[ $supply_type == Battery ]]; then
        has_battery=true
    elif [[ -r "$supply/online" && $(<"$supply/online") == 1 ]]; then
        on_external_power=true
    fi
done

profile=performance
[[ $has_battery == true && $on_external_power == false ]] && profile=balanced

"$busctl_bin" --system set-property \
    org.freedesktop.UPower.PowerProfiles \
    /org/freedesktop/UPower/PowerProfiles \
    org.freedesktop.UPower.PowerProfiles \
    ActiveProfile s "$profile"
