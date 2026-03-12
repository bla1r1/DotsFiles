#!/usr/bin/env bash
set -euo pipefail

WALLPAPER_DIR="${WALLPAPER_DIR:-$HOME/.wallpaper}"
CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}"
CURRENT_WALL="$CACHE_DIR/current_wallpaper.jpg"
BLUR_WALL="$CACHE_DIR/current_wallpaper.blur"

notify() {
    if command -v notify-send >/dev/null 2>&1; then
        notify-send -a "Wallpaper" "$1" "${2:-}"
    else
        printf '%s %s\n' "$1" "${2:-}"
    fi
}

apply_wallpaper() {
    local img="$1"
    local resolved_img="$img"

    if [[ ! -f "$img" ]]; then
        notify "Wallpaper error" "File not found: $img"
        return 1
    fi

    if command -v realpath >/dev/null 2>&1; then
        resolved_img="$(realpath "$img")"
    fi

    mkdir -p "$CACHE_DIR"
    cp "$resolved_img" "$CURRENT_WALL"

    if command -v wal >/dev/null 2>&1; then
        wal -q -i "$resolved_img"
    fi

    if command -v hyprctl >/dev/null 2>&1; then
        hyprctl hyprpaper preload "$resolved_img" >/dev/null 2>&1 || true
        hyprctl hyprpaper wallpaper ",$resolved_img" >/dev/null 2>&1 || true
        hyprctl hyprpaper unload unused >/dev/null 2>&1 || true
    else
        notify "Wallpaper warning" "hyprctl is not available, hyprpaper step skipped"
    fi

    if command -v convert >/dev/null 2>&1; then
        convert -strip -scale 10% -blur 0x3 -resize 100% "$CURRENT_WALL" "$BLUR_WALL" || true
    fi

    [[ -x "$HOME/.config/hypr/scripts/create_sddm_config.sh" ]] && "$HOME/.config/hypr/scripts/create_sddm_config.sh" >/dev/null 2>&1 &
    [[ -x "$HOME/.config/hypr/scripts/create_module_clock_colors.sh" ]] && "$HOME/.config/hypr/scripts/create_module_clock_colors.sh" >/dev/null 2>&1 &
    [[ -x "$HOME/.config/hypr/scripts/create_jgmenu_config.sh" ]] && "$HOME/.config/hypr/scripts/create_jgmenu_config.sh" >/dev/null 2>&1 &
    [[ -x "$HOME/.config/hypr/scripts/create_polybar_colors.sh" ]] && "$HOME/.config/hypr/scripts/create_polybar_colors.sh" >/dev/null 2>&1 &

    if command -v waybar >/dev/null 2>&1; then
        killall waybar >/dev/null 2>&1 || true
        sleep 0.3
        waybar >/dev/null 2>&1 &
    fi

    notify "Wallpaper updated" "$(basename "$resolved_img")"
}

pick_random() {
    local dir="${1:-$WALLPAPER_DIR}"
    if [[ ! -d "$dir" ]]; then
        notify "Wallpaper error" "Directory not found: $dir"
        return 1
    fi

    local selected
    selected="$(find "$dir" -type f \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.webp' \) | shuf -n 1)"
    if [[ -z "${selected:-}" ]]; then
        notify "Wallpaper error" "No image files in: $dir"
        return 1
    fi
    apply_wallpaper "$selected"
}

usage() {
    cat <<'EOF'
Usage:
  wallpaper.sh set <image_path>
  wallpaper.sh random [directory]
  wallpaper.sh select [directory]
  wallpaper.sh restore
EOF
}

case "${1:-}" in
    set)
        [[ -n "${2:-}" ]] || { usage; exit 1; }
        apply_wallpaper "$2"
        ;;
    random)
        pick_random "${2:-$WALLPAPER_DIR}"
        ;;
    select)
        pick_random "${2:-$WALLPAPER_DIR}"
        ;;
    restore)
        [[ -f "$CURRENT_WALL" ]] || { notify "Wallpaper error" "No cached wallpaper to restore"; exit 1; }
        apply_wallpaper "$CURRENT_WALL"
        ;;
    "")
        pick_random "$WALLPAPER_DIR"
        ;;
    *)
        usage
        exit 1
        ;;
esac
