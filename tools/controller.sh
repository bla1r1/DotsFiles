#!/usr/bin/env bash
# =============================================================================
# b1air OS — Terminal Quick Controller for macOS
# Single-key triggers for testing all desktop windows in real-time
# =============================================================================
set -e

SSH_SCRIPT="$HOME/vm-arch/ssh.sh"

call_ipc() {
    "$SSH_SCRIPT" "export XDG_RUNTIME_DIR=/run/user/1000 WAYLAND_DISPLAY=wayland-1; $1" >/dev/null 2>&1 &
}

clear
echo "=================================================="
echo "⚡️ b1air OS — Terminal Controller (macOS)"
echo "=================================================="
echo "Press single key to trigger on TigerVNC screen:"
echo ""
echo "  [s] ⚙️  Settings App"
echo "  [l] 🚀 Spotlight Launcher"
echo "  [c] 🎛️  Control Center"
echo "  [v] 📋 Clipboard Manager"
echo "  [f] ⏱️  FocusTime Analytics"
echo "  [m] 🎵 Media Player"
echo "  [w] 🌐 Wi-Fi & Network"
echo "  [t] 🐱 Launch Kitty Terminal"
echo "  [n] 🔔 Test Notification Toast"
echo "  [z] 📐 FancyZones Grid"
echo "  [u] 📏 Screen Ruler"
echo "  [d] 📁 DropShelf Stash"
echo "  [r] 🛡️  Toggle WayVNC Server"
echo "  [x] ❌ Dismiss / Close All Popups"
echo "  [q] 🚪 Quit Controller"
echo "=================================================="
echo ""

while true; do
    read -rsn1 key
    case "$key" in
        s) echo "-> Toggling Settings App..."; call_ipc "quickshell ipc call main toggleSettings" ;;
        l) echo "-> Toggling Spotlight Launcher..."; call_ipc "quickshell ipc call main toggleLauncher" ;;
        c) echo "-> Toggling Control Center..."; call_ipc "quickshell ipc call main toggleControl" ;;
        v) echo "-> Toggling Clipboard Manager..."; call_ipc "quickshell ipc call main toggleClipboard" ;;
        f) echo "-> Toggling FocusTime Analytics..."; call_ipc "quickshell ipc call main toggleFocusTime" ;;
        m) echo "-> Toggling Media Player..."; call_ipc "quickshell ipc call main toggleMusic" ;;
        w) echo "-> Toggling Network Dialog..."; call_ipc "quickshell ipc call main toggleNetwork" ;;
        z) echo "-> Toggling FancyZones..."; call_ipc "quickshell ipc call main toggleZones" ;;
        u) echo "-> Toggling Screen Ruler..."; call_ipc "quickshell ipc call main toggleRuler" ;;
        d) echo "-> Toggling DropShelf..."; call_ipc "quickshell ipc call main toggleShelf" ;;
        t) echo "-> Launching Kitty..."; call_ipc "swaymsg exec kitty" ;;
        n) echo "-> Sending Test Toast..."; call_ipc "notify-send 'b1air OS' 'Interactive test toast from macOS controller!'" ;;
        r) echo "-> Toggling WayVNC Server..."; call_ipc "b1air-daemon remote toggle" ;;
        x) echo "-> Closing Popups..."; call_ipc "quickshell ipc call main close" ;;
        q) echo "Bye!"; exit 0 ;;
        *) ;;
    esac
done
