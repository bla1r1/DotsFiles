#!/usr/bin/env bash
# =============================================================================
# user-manager.sh — User Profile, Avatar, Shell & Password Management
# =============================================================================
set -euo pipefail

CURRENT_USER="${SUDO_USER:-$USER}"

if command -v getent >/dev/null 2>&1; then
    USER_ENTRY="$(getent passwd "$CURRENT_USER" || true)"
else
    USER_ENTRY="$(grep "^$CURRENT_USER:" /etc/passwd || true)"
fi

USER_HOME="${HOME:-/home/$CURRENT_USER}"
USER_SHELL="${SHELL:-/bin/bash}"
USER_GECOS=""
USER_UID="$(id -u "$CURRENT_USER" 2>/dev/null || echo 1000)"

if [[ -n "$USER_ENTRY" ]]; then
    USER_HOME="$(echo "$USER_ENTRY" | cut -d: -f6)"
    USER_SHELL="$(echo "$USER_ENTRY" | cut -d: -f7)"
    USER_GECOS="$(echo "$USER_ENTRY" | cut -d: -f5 | cut -d, -f1)"
fi

AVATAR_PATH=""
if [[ -f "$USER_HOME/.face.icon" ]]; then
    AVATAR_PATH="$USER_HOME/.face.icon"
elif [[ -f "$USER_HOME/.face" ]]; then
    AVATAR_PATH="$USER_HOME/.face"
elif [[ -f "/var/lib/AccountsService/icons/$CURRENT_USER" ]]; then
    AVATAR_PATH="/var/lib/AccountsService/icons/$CURRENT_USER"
fi

get_info() {
    local groups_str
    groups_str="$(groups "$CURRENT_USER" 2>/dev/null | cut -d: -f2 | sed 's/^ *//' || echo "")"

    jq -n \
        --arg username "$CURRENT_USER" \
        --arg name "${USER_GECOS:-$CURRENT_USER}" \
        --arg uid "$USER_UID" \
        --arg home "$USER_HOME" \
        --arg shell "$USER_SHELL" \
        --arg avatar "$AVATAR_PATH" \
        --arg groups "$groups_str" \
        '{
            username: $username,
            name: $name,
            uid: $uid,
            home: $home,
            shell: $shell,
            avatar: $avatar,
            groups: $groups
        }'
}

set_avatar() {
    local img="${1:-}"
    if [[ -z "$img" || ! -f "$img" ]]; then
        echo "Error: Image file not found: $img" >&2
        return 1
    fi

    # Convert/copy to ~/.face and ~/.face.icon
    cp "$img" "$USER_HOME/.face.icon"
    cp "$img" "$USER_HOME/.face"
    chmod 644 "$USER_HOME/.face.icon" "$USER_HOME/.face"

    # Also update SDDM user icons directory if writable or via AccountsService
    local acc_dir="/var/lib/AccountsService/icons"
    if [[ -d "$acc_dir" && -w "$acc_dir" ]]; then
        cp "$img" "$acc_dir/$CURRENT_USER"
        chmod 644 "$acc_dir/$CURRENT_USER"
    fi

    echo "Avatar updated successfully."
}

set_name() {
    local new_name="${1:-}"
    if [[ -z "$new_name" ]]; then
        echo "Error: Name cannot be empty" >&2
        return 1
    fi

    if command -v chfn >/dev/null 2>&1; then
        chfn -f "$new_name" "$CURRENT_USER" >/dev/null 2>&1 || sudo chfn -f "$new_name" "$CURRENT_USER" 2>/dev/null || true
    fi
    echo "Display name updated to: $new_name"
}

set_shell() {
    local new_shell="${1:-}"
    if [[ -z "$new_shell" || ! -x "$new_shell" ]]; then
        echo "Error: Invalid shell executable: $new_shell" >&2
        return 1
    fi

    chsh -s "$new_shell" "$CURRENT_USER" >/dev/null 2>&1 || sudo chsh -s "$new_shell" "$CURRENT_USER" 2>/dev/null || true
    echo "Shell changed to: $new_shell"
}

change_password() {
    # Launch interactive terminal to change password securely
    if command -v kitty >/dev/null 2>&1; then
        kitty --title "Change Password - b1air" -e sh -c "echo '=== Change Password for $CURRENT_USER ==='; passwd; echo 'Press any key to close...'; read -n 1" &
    elif command -v foot >/dev/null 2>&1; then
        foot -T "Change Password - b1air" sh -c "echo '=== Change Password for $CURRENT_USER ==='; passwd; echo 'Press any key to close...'; read -n 1" &
    else
        passwd &
    fi
}

case "${1:-get}" in
    get)               get_info ;;
    set-avatar)        shift; set_avatar "$@" ;;
    set-name)          shift; set_name "$@" ;;
    set-shell)         shift; set_shell "$@" ;;
    change-password)   change_password ;;
    *) echo "Usage: $0 {get|set-avatar <path>|set-name <name>|set-shell <path>|change-password}" >&2; exit 1 ;;
esac
