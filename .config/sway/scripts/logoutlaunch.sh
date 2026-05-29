#!/usr/bin/env bash
set -euo pipefail

layout="${1:-2}"

# set variables
wLayout="$HOME/.config/wlogout/layout_$layout"
wlTmplt="$HOME/.config/wlogout/style_$layout.css"

# set font size
fntSize="$(gsettings get org.gnome.desktop.interface font-name 2>/dev/null | sed "s/'//g" | awk '{print $NF}')"
export fntSize=$(( ${fntSize:-10} * 2 ))

# set scaling as per monitor res
res="$(awk -Fx 'NF > 1 { print $2; exit }' /sys/class/drm/*/modes 2>/dev/null || true)"
res="${res:-1080}"
case "$layout" in
    1)  wlColms=1
        export mgn=$(( res * 10 / 100 ))
        export hvr=$(( res * 5 / 100 )) ;;
    2)  wlColms=5
        export mgn=$(( res * 8 / 100 ))
        export mgn2=$(( res * 65 / 100 ))
        export hvr=$(( res * 3 / 100 ))
        export hvr2=$(( res * 60 / 100 )) ;;
    *)  echo "Error: invalid parameter passed..."
        exit 1 ;;
esac

# eval config files
wlStyle="$(envsubst < "$wlTmplt")"

# launch wlogout
wlogout -b "$wlColms" -c 0 -r 0 --layout "$wLayout" --css <(printf '%s\n' "$wlStyle") --protocol layer-shell
