#!/usr/bin/env bash
set -euo pipefail

WALLPAPER_DIR="${WALLPAPER_DIR:-$HOME/.wallpapers}"
CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}"
CURRENT_WALL="$CACHE_DIR/current_wallpaper.jpg"
SDDM_WALL="/var/cache/wallpaper/current.jpg"

# ── Notification (errors only) ────────────────────────────────────────────────
notify_error() {
    if command -v notify-send >/dev/null 2>&1; then
        notify-send -a "Wallpaper" "$1" "${2:-}"
    else
        printf 'ERROR: %s %s\n' "$1" "${2:-}" >&2
    fi
}

# ── Apply wallpaper ───────────────────────────────────────────────────────────
apply_wallpaper() {
    local img="$1"
    local resolved_img="$img"

    if [[ ! -f "$img" ]]; then
        notify_error "File not found" "$img"
        return 1
    fi

    if command -v realpath >/dev/null 2>&1; then
        resolved_img="$(realpath "$img")"
    fi

    # Cache current wallpaper (skip if already is the cache file)
    mkdir -p "$CACHE_DIR"
    if [[ "$resolved_img" != "$CURRENT_WALL" ]]; then
        cp "$resolved_img" "$CURRENT_WALL"
    fi

    # Pywal — generate color scheme (optional)
    if command -v wal >/dev/null 2>&1; then
        wal -q -i "$resolved_img"
    fi

    # Restart swaybg with new wallpaper
    pkill -x swaybg 2>/dev/null || true
    sleep 0.1
    swaybg -m fill -i "$resolved_img" &

    # Sync to SDDM
    if [[ -d /var/cache/wallpaper ]]; then
        cp "$CURRENT_WALL" "$SDDM_WALL" 2>/dev/null \
            || notify_error "SDDM" "Could not copy to /var/cache/wallpaper (check group membership)"
    else
        notify_error "SDDM" "/var/cache/wallpaper not found — run install script first"
    fi

    # Restart waybar (if dynamic theming is used)
    if command -v waybar >/dev/null 2>&1; then
        pkill -x waybar 2>/dev/null || true
        sleep 0.3
        waybar &>/dev/null &
    fi
}

# ── Pick random wallpaper ─────────────────────────────────────────────────────
pick_random() {
    local dir="${1:-$WALLPAPER_DIR}"

    if [[ ! -d "$dir" ]]; then
        notify_error "Directory not found" "$dir"
        return 1
    fi

    local selected
    selected="$(find "$dir" -type f \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.webp' \) | shuf -n 1)"

    if [[ -z "${selected:-}" ]]; then
        notify_error "No images found in" "$dir"
        return 1
    fi

    apply_wallpaper "$selected"
}

# ── Interactive picker via wofi/rofi ──────────────────────────────────────────
pick_interactive() {
    local dir="${1:-$WALLPAPER_DIR}"

    if ! command -v wofi >/dev/null 2>&1 && ! command -v rofi >/dev/null 2>&1; then
        notify_error "wofi or rofi required for interactive selection"
        return 1
    fi

    local selected
    if command -v wofi >/dev/null 2>&1; then
        selected="$(find "$dir" -type f \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.webp' \) \
            | wofi --dmenu --prompt "Select wallpaper")"
    else
        selected="$(find "$dir" -type f \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.webp' \) \
            | rofi -dmenu -p "Select wallpaper")"
    fi

    [[ -n "${selected:-}" ]] && apply_wallpaper "$selected"
}

# ── Usage ─────────────────────────────────────────────────────────────────────
usage() {
    cat <<'USAGE'
Usage:
  wallpaper.sh set <file>        — apply a specific wallpaper
  wallpaper.sh random [dir]      — pick a random wallpaper
  wallpaper.sh select [dir]      — interactive pick via wofi/rofi
  wallpaper.sh restore           — restore last wallpaper from cache
USAGE
}

# ── Entry point ───────────────────────────────────────────────────────────────
case "${1:-}" in
    set)
        [[ -n "${2:-}" ]] || { usage; exit 1; }
        apply_wallpaper "$2"
        ;;
    random)
        pick_random "${2:-$WALLPAPER_DIR}"
        ;;
    select)
        pick_interactive "${2:-$WALLPAPER_DIR}"
        ;;
    restore)
        [[ -f "$CURRENT_WALL" ]] || { notify_error "No cached wallpaper to restore"; exit 1; }
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
