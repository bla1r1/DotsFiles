#!/usr/bin/env bash
set -euo pipefail

TMP_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/sway/music"
if ! mkdir -p "$TMP_DIR" 2>/dev/null; then
    TMP_DIR="${TMPDIR:-/tmp}/sway-music-${UID:-$(id -u)}"
    mkdir -p "$TMP_DIR"
fi

PLACEHOLDER="$TMP_DIR/placeholder_blank.png"
STATE_FILE="$TMP_DIR/last_position"
FIELD_SEP=$'\x1f'

json_escape() {
    local value="$1"
    value=${value//\\/\\\\}
    value=${value//\"/\\\"}
    value=${value//$'\n'/\\n}
    value=${value//$'\r'/}
    value=${value//$'\t'/\\t}
    printf '%s' "$value"
}

emit_json() {
    local title="$1" artist="$2" status="$3" len="$4" pos="$5" len_str="$6" pos_str="$7"
    local time_str="$8" percent="$9" source="${10}" pname="${11}" blur="${12}" grad="${13}"
    local txt_color="${14}" dev_icon="${15}" dev_name="${16}" art="${17}"

    printf '{"title":"%s","artist":"%s","status":"%s","length":%s,"position":%s,"lengthStr":"%s","positionStr":"%s","timeStr":"%s","percent":%s,"source":"%s","playerName":"%s","blur":"%s","grad":"%s","textColor":"%s","deviceIcon":"%s","deviceName":"%s","artUrl":"%s"}\n' \
        "$(json_escape "$title")" \
        "$(json_escape "$artist")" \
        "$(json_escape "$status")" \
        "$len" \
        "$pos" \
        "$(json_escape "$len_str")" \
        "$(json_escape "$pos_str")" \
        "$(json_escape "$time_str")" \
        "$percent" \
        "$(json_escape "$source")" \
        "$(json_escape "$pname")" \
        "$(json_escape "$blur")" \
        "$(json_escape "$grad")" \
        "$(json_escape "$txt_color")" \
        "$(json_escape "$dev_icon")" \
        "$(json_escape "$dev_name")" \
        "$(json_escape "$art")"
}

format_time() {
    local seconds="${1:-0}"
    [[ "$seconds" =~ ^[0-9]+$ ]] || seconds=0
    printf '%02d:%02d' $((seconds / 60)) $((seconds % 60))
}

ensure_placeholder() {
    [[ -s "$PLACEHOLDER" ]] && return 0
    if command -v convert >/dev/null 2>&1; then
        convert -size 500x500 xc:"#313244" "$PLACEHOLDER" 2>/dev/null || :
    fi
}

track_hash() {
    local value="$1"
    if command -v md5sum >/dev/null 2>&1; then
        printf '%s' "$value" | md5sum | awk '{print $1}'
    else
        printf '%s' "$value" | cksum | awk '{print $1}'
    fi
}

prepare_art_async() {
    local raw_url="$1" final_art="$2" blur_path="$3" color_path="$4" text_path="$5" lock_file="$6"

    [[ -n "$raw_url" && ! -e "$lock_file" ]] || return 0
    : > "$lock_file"

    (
        if [[ "$raw_url" == http* ]]; then
            curl -s -L --max-time 10 -o "$final_art" "$raw_url" || cp "$PLACEHOLDER" "$final_art"
        else
            local clean_path="${raw_url#file://}"
            if [[ -f "$clean_path" ]]; then
                cp "$clean_path" "$final_art"
            else
                cp "$PLACEHOLDER" "$final_art"
            fi
        fi

        [[ -s "$final_art" ]] || cp "$PLACEHOLDER" "$final_art"

        if command -v convert >/dev/null 2>&1; then
            local is_placeholder colors c1 c2 c3 opp_raw
            is_placeholder="$(convert "$final_art" -format "%[hex:u.p{0,0}]" info: 2>/dev/null | cut -c1-6 || true)"

            if [[ "$is_placeholder" == "313244" || -z "$is_placeholder" ]]; then
                cp "$final_art" "$blur_path"
            else
                convert "$final_art" -blur 0x20 -brightness-contrast -30x-10 "$blur_path" 2>/dev/null || cp "$final_art" "$blur_path"
                colors="$(convert "$final_art" -resize 50x50 -alpha off +dither -quantize RGB -colors 3 -depth 8 -format "%c" histogram:info: 2>/dev/null \
                    | grep -E -o '#[0-9A-Fa-f]{6}' | head -n 3 | tr '\n' ' ' || true)"
                read -r c1 c2 c3 _ <<< "$colors"
                c1="${c1:-#cba6f7}"
                c2="${c2:-$c1}"
                c3="${c3:-$c1}"
                printf 'linear-gradient(45deg, %s, %s, %s, %s)\n' "$c1" "$c2" "$c3" "$c1" > "$color_path"

                opp_raw="$(convert xc:"$c1" -alpha off -negate -depth 8 -format "%[hex:u]" info: 2>/dev/null \
                    | grep -E -o '[0-9A-Fa-f]{6}' | head -n 1 || true)"
                if [[ -n "$opp_raw" ]]; then
                    printf '#%s\n' "$opp_raw" > "$text_path"
                else
                    printf '%s\n' "$default_text" > "$text_path"
                fi
            fi
        else
            cp "$final_art" "$blur_path"
        fi

        rm -f "$lock_file"
        find "$TMP_DIR" -maxdepth 1 -type f | sort | head -n -80 | xargs -r rm -f 2>/dev/null || true
    ) >/dev/null 2>&1 &
}

device_info() {
    local sink_name readable_name
    sink_name="$(pactl get-default-sink 2>/dev/null || true)"

    dev_icon="󰓃"
    dev_name="Speaker"
    if [[ "$sink_name" == *"bluez"* ]]; then
        dev_icon="󰂯"
        readable_name="$(pactl list sinks 2>/dev/null | awk -v sink="$sink_name" '
            $0 ~ "Name: " sink { found = 1 }
            found && /Description:/ {
                sub(/^[[:space:]]*Description:[[:space:]]*/, "")
                print
                exit
            }
        ')"
        dev_name="${readable_name:-Bluetooth}"
    elif [[ "$sink_name" == *"usb"* ]]; then
        dev_name="USB Audio"
    elif [[ "$sink_name" == *"pci"* ]]; then
        dev_name="System"
    fi
}

ensure_placeholder

default_grad="linear-gradient(45deg, #cba6f7, #89b4fa, #f38ba8, #cba6f7)"
default_text="#cdd6f4"

if ! command -v playerctl >/dev/null 2>&1; then
    len=1
    pos=0
    emit_json "Not Playing" "" "Stopped" "$len" "$pos" "00:01" "00:00" "00:00 / 00:01" 0 "Offline" "" "$PLACEHOLDER" "$default_grad" "$default_text" "󰓃" "Speaker" "$PLACEHOLDER"
    exit 0
fi

metadata="$(
    playerctl metadata --format "{{status}}${FIELD_SEP}{{mpris:artUrl}}${FIELD_SEP}{{xesam:title}}${FIELD_SEP}{{xesam:artist}}${FIELD_SEP}{{mpris:length}}${FIELD_SEP}{{position}}${FIELD_SEP}{{playerName}}" 2>/dev/null || true
)"

if [[ -z "$metadata" ]]; then
    if [[ -r "$STATE_FILE" ]]; then
        IFS='|' read -r pos len < "$STATE_FILE"
    else
        pos=0
        len=1
    fi
    [[ "$pos" =~ ^[0-9]+$ ]] || pos=0
    [[ "$len" =~ ^[0-9]+$ && "$len" -gt 0 ]] || len=1
    percent=$((pos * 100 / len))
    pos_str="$(format_time "$pos")"
    len_str="$(format_time "$len")"
    emit_json "Not Playing" "" "Stopped" "$len" "$pos" "$len_str" "$pos_str" "$pos_str / $len_str" "$percent" "Offline" "" "$PLACEHOLDER" "$default_grad" "$default_text" "󰓃" "Speaker" "$PLACEHOLDER"
    exit 0
fi

IFS="$FIELD_SEP" read -r status raw_url title artist len_micro pos_micro player_raw <<< "$metadata"

if [[ "$status" != "Playing" && "$status" != "Paused" ]]; then
    status="Stopped"
fi

title="${title:-Media}"
artist="${artist:-}"
len_micro="${len_micro:-0}"
pos_micro="${pos_micro:-0}"
[[ "$len_micro" =~ ^[0-9]+$ && "$len_micro" -gt 0 ]] || len_micro=1000000
[[ "$pos_micro" =~ ^[0-9]+$ ]] || pos_micro=0

len=$((len_micro / 1000000))
(( len > 0 )) || len=1

if [[ "$status" == "Playing" ]]; then
    pos=$((pos_micro / 1000000))
    printf '%s|%s\n' "$pos" "$len" > "$STATE_FILE"
elif [[ -r "$STATE_FILE" ]]; then
    IFS='|' read -r saved_pos saved_len < "$STATE_FILE"
    if [[ "$saved_len" == "$len" && "$saved_pos" =~ ^[0-9]+$ ]]; then
        pos="$saved_pos"
    else
        pos=$((pos_micro / 1000000))
    fi
else
    pos=$((pos_micro / 1000000))
fi

(( pos < 0 )) && pos=0
(( pos > len )) && pos="$len"
percent=$((pos * 100 / len))
pos_str="$(format_time "$pos")"
len_str="$(format_time "$len")"
time_str="$pos_str / $len_str"

hash="$(track_hash "${title:-unknown}-${artist:-unknown}")"
final_art="$TMP_DIR/${hash}_art.jpg"
blur_path="$TMP_DIR/${hash}_blur.png"
color_path="$TMP_DIR/${hash}_grad.txt"
text_path="$TMP_DIR/${hash}_text.txt"
lock_file="$TMP_DIR/${hash}.lock"

display_art="$PLACEHOLDER"
display_blur="$PLACEHOLDER"
display_grad="$default_grad"
display_text="$default_text"

if [[ -s "$final_art" ]]; then
    display_art="$final_art"
    [[ -s "$blur_path" ]] && display_blur="$blur_path"
    [[ -s "$color_path" ]] && display_grad="$(sed -n '1p' "$color_path")"
    [[ -s "$text_path" ]] && display_text="$(sed -n '1p' "$text_path")"
else
    prepare_art_async "$raw_url" "$final_art" "$blur_path" "$color_path" "$text_path" "$lock_file"
fi

player_nice="${player_raw:-Offline}"
player_nice="${player_nice^}"
device_info

emit_json "$title" "$artist" "$status" "$len" "$pos" "$len_str" "$pos_str" "$time_str" "$percent" "$player_nice" "${player_raw:-}" "$display_blur" "$display_grad" "$display_text" "$dev_icon" "$dev_name" "$display_art"
