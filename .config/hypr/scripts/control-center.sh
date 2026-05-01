#!/bin/bash

# ── Отримуємо поточні значення ──────────────────────────────
VOL=$(pamixer --get-volume 2>/dev/null || echo "0")
MUTED=$(pamixer --get-mute 2>/dev/null || echo "false")

if command -v brightnessctl &>/dev/null; then
    BRIGHT=$(brightnessctl get)
    BRIGHT_MAX=$(brightnessctl max)
    BRIGHT_PCT=$(( BRIGHT * 100 / BRIGHT_MAX ))
else
    BRIGHT_PCT="N/A"
fi

SSID=$(nmcli -t -f active,ssid dev wifi 2>/dev/null | grep '^yes' | cut -d: -f2)
[ -z "$SSID" ] && SSID="Disconnected"

# ── Іконки гучності ─────────────────────────────────────────
if [ "$MUTED" = "true" ]; then
    VOL_LABEL="󰝟  Volume: Muted"
elif [ "$VOL" -lt 33 ]; then
    VOL_LABEL="󰕿  Volume: $VOL%"
elif [ "$VOL" -lt 66 ]; then
    VOL_LABEL="󰖀  Volume: $VOL%"
else
    VOL_LABEL="󰕾  Volume: $VOL%"
fi

BRIGHT_LABEL="󰃞  Brightness: $BRIGHT_PCT%"
NET_LABEL="󰤨  Network: $SSID"

# ── Rofi меню ──────────────────────────────────────────────
CHOICE=$(printf '%s\n' \
    "$VOL_LABEL" \
    "󰝝  Volume +" \
    "󰝞  Volume -" \
    "󰝟  Toggle Mute" \
    "---" \
    "$BRIGHT_LABEL" \
    "󰃠  Brightness +" \
    "󰃟  Brightness -" \
    "---" \
    "$NET_LABEL" \
    "󰒓  Network Settings" \
    | rofi -dmenu \
        -p "  Control Center" \
        -theme ~/.config/rofi/control-center.rasi \
        -no-custom \
        -format s)

# ── Обробка вибору ─────────────────────────────────────────
case "$CHOICE" in
    "󰝝  Volume +")       pamixer --increase 5 ;;
    "󰝞  Volume -")       pamixer --decrease 5 ;;
    "󰝟  Toggle Mute")    pamixer --toggle-mute ;;
    "󰃠  Brightness +")   brightnessctl set +10% ;;
    "󰃟  Brightness -")   brightnessctl set 10%- ;;
    "󰒓  Network Settings") kitty -e nmtui & ;;
esac
