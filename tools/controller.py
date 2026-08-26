#!/usr/bin/env python3
"""
b1air Desktop Environment — Remote Controller & Window Deck
A lightweight, zero-dependency developer dashboard to test, toggle, and trigger
all Wayland & Quickshell windows directly from macOS.

Usage:
    ./tools/controller.py [port]
"""

import http.server
import json
import os
import subprocess
import sys
import urllib.parse
import webbrowser

PORT = int(sys.argv[1]) if len(sys.argv) > 1 else 8765
SSH_SCRIPT = os.path.expanduser("~/vm-arch/ssh.sh")

ACTIONS = {
    # Quickshell Windows
    "settings":     "quickshell ipc call main toggleSettings",
    "launcher":     "quickshell ipc call main toggleLauncher",
    "control":      "quickshell ipc call main toggleControl",
    "clipboard":    "quickshell ipc call main toggleClipboard",
    "focustime":    "quickshell ipc call main toggleFocusTime",
    "calendar":     "quickshell ipc call main toggleCalendar",
    "music":        "quickshell ipc call main toggleMusic",
    "network":      "quickshell ipc call main toggleNetwork",
    "keyboard":     "quickshell ipc call main toggleKeyboard",
    "emoji":        "quickshell ipc call main toggleEmoji",
    "switcher":     "quickshell ipc call main toggleSwitcher",
    "session":      "quickshell ipc call main toggleSession",
    "reload_shell": "quickshell ipc call main forceReload",
    "close_all":    "quickshell ipc call main close",

    # Notifications & Tests
    "notify_test":  "notify-send -u normal 'B1air OS' 'This is a test desktop notification toast!'",
    "notify_warn":  "notify-send -u critical 'Warning' 'Battery or temperature alert test'",

    # Hardware & System
    "gamemode":     "b1air-daemon game-mode toggle",
    "remote_vnc":   "b1air-daemon remote toggle",
    "sidecar":      "b1air-daemon sidecar create 1920 1080",
    "sidecar_rm":   "b1air-daemon sidecar remove",
    "lock":         "b1air-daemon power lock",
    "kitty":        "swaymsg exec kitty",
    "thunar":       "swaymsg exec thunar",
}

HTML_TEMPLATE = """<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>b1air OS — Remote Control Deck</title>
    <style>
        :root {
            --bg: #1a1b26;
            --bg-card: #24283b;
            --bg-hover: #2f3549;
            --border: #414868;
            --fg: #c0caf5;
            --fg-dim: #7aa2f7;
            --blue: #7aa2f7;
            --cyan: #7dcfff;
            --purple: #bb9af7;
            --green: #73daca;
            --yellow: #e0af68;
            --red: #f7768e;
            --teal: #1abc9c;
        }
        * { box-sizing: border-box; margin: 0; padding: 0; font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif; }
        body { background: var(--bg); color: var(--fg); padding: 24px; min-height: 100vh; }
        header { display: flex; justify-content: space-between; align-items: center; margin-bottom: 24px; padding-bottom: 16px; border-bottom: 1px solid var(--border); }
        h1 { font-size: 20px; font-weight: 700; color: var(--cyan); display: flex; align-items: center; gap: 8px; }
        .badge { background: rgba(115, 218, 202, 0.15); color: var(--green); padding: 4px 10px; border-radius: 999px; font-size: 12px; font-weight: 600; }
        .grid { display: grid; grid-template-columns: repeat(auto-fit, minmax(280px, 1fr)); gap: 20px; }
        .card { background: var(--bg-card); border: 1px solid var(--border); border-radius: 12px; padding: 18px; }
        .card-title { font-size: 14px; font-weight: 600; text-transform: uppercase; letter-spacing: 0.5px; margin-bottom: 14px; color: var(--fg-dim); }
        .btn-col { display: flex; flex-direction: column; gap: 10px; }
        button {
            display: flex; align-items: center; justify-content: space-between;
            background: #1f2335; color: var(--fg); border: 1px solid var(--border);
            padding: 12px 16px; border-radius: 8px; font-size: 14px; font-weight: 500;
            cursor: pointer; transition: all 0.15s ease;
        }
        button:hover { background: var(--bg-hover); border-color: var(--blue); transform: translateY(-1px); }
        button:active { transform: translateY(1px); }
        .btn-desc { font-size: 11px; opacity: 0.6; }
        .btn-accent-blue { border-left: 4px solid var(--blue); }
        .btn-accent-purple { border-left: 4px solid var(--purple); }
        .btn-accent-green { border-left: 4px solid var(--green); }
        .btn-accent-yellow { border-left: 4px solid var(--yellow); }
        .btn-accent-red { border-left: 4px solid var(--red); }
        .btn-accent-teal { border-left: 4px solid var(--teal); }
        #toast {
            position: fixed; bottom: 20px; right: 20px; background: #2ac3de; color: #1a1b26;
            padding: 10px 18px; border-radius: 8px; font-weight: 600; font-size: 13px;
            opacity: 0; transition: opacity 0.2s ease; pointer-events: none;
        }
        #toast.show { opacity: 1; }
    </style>
</head>
<body>
    <header>
        <h1>⚡️ b1air OS — Remote Control Deck</h1>
        <span class="badge" id="status-badge">● VM Connected</span>
    </header>

    <div class="grid">
        <!-- Core Shell Windows -->
        <div class="card">
            <div class="card-title">🖥️ Shell Windows & Popups</div>
            <div class="btn-col">
                <button class="btn-accent-purple" onclick="trigger('settings')">
                    <span>⚙️ Settings App</span>
                    <span class="btn-desc">Super + Shift + S</span>
                </button>
                <button class="btn-accent-blue" onclick="trigger('launcher')">
                    <span>🚀 Spotlight Launcher</span>
                    <span class="btn-desc">Super + Space</span>
                </button>
                <button class="btn-accent-blue" onclick="trigger('control')">
                    <span>🎛️ Control Center</span>
                    <span class="btn-desc">Super + C</span>
                </button>
                <button class="btn-accent-yellow" onclick="trigger('clipboard')">
                    <span>📋 Clipboard Manager</span>
                    <span class="btn-desc">Super + V</span>
                </button>
                <button class="btn-accent-teal" onclick="trigger('focustime')">
                    <span>⏱️ FocusTime Analytics</span>
                    <span class="btn-desc">Activity DB</span>
                </button>
                <button class="btn-accent-purple" onclick="trigger('calendar')">
                    <span>📅 Calendar Popup</span>
                    <span class="btn-desc">Schedule</span>
                </button>
                <button class="btn-accent-green" onclick="trigger('music')">
                    <span>🎵 Media Player</span>
                    <span class="btn-desc">MPRIS / Spotify</span>
                </button>
                <button class="btn-accent-blue" onclick="trigger('switcher')">
                    <span>🔀 Alt+Tab Switcher</span>
                    <span class="btn-desc">Windows</span>
                </button>
            </div>
        </div>

        <!-- System & Hardware -->
        <div class="card">
            <div class="card-title">⚙️ System & Peripherals</div>
            <div class="btn-col">
                <button class="btn-accent-blue" onclick="trigger('network')">
                    <span>🌐 Wi-Fi & Bluetooth</span>
                    <span class="btn-desc">Dialog</span>
                </button>
                <button class="btn-accent-yellow" onclick="trigger('keyboard')">
                    <span>⌨️ Keyboard Layout</span>
                    <span class="btn-desc">Picker</span>
                </button>
                <button class="btn-accent-purple" onclick="trigger('emoji')">
                    <span>😀 Emoji Picker</span>
                    <span class="btn-desc">Super + .</span>
                </button>
                <button class="btn-accent-green" onclick="trigger('gamemode')">
                    <span>🎮 Game Mode Toggle</span>
                    <span class="btn-desc">Performance</span>
                </button>
                <button class="btn-accent-blue" onclick="trigger('remote_vnc')">
                    <span>🛡️ WayVNC Server Toggle</span>
                    <span class="btn-desc">Port 5900</span>
                </button>
                <button class="btn-accent-teal" onclick="trigger('sidecar')">
                    <span>📱 Create Sidecar Screen</span>
                    <span class="btn-desc">1080p Virtual</span>
                </button>
                <button class="btn-accent-red" onclick="trigger('sidecar_rm')">
                    <span>🔌 Remove Sidecar Screen</span>
                    <span class="btn-desc">Unplug</span>
                </button>
            </div>
        </div>

        <!-- Apps & Power -->
        <div class="card">
            <div class="card-title">🚀 Applications & Session</div>
            <div class="btn-col">
                <button class="btn-accent-teal" onclick="trigger('kitty')">
                    <span>🐱 Launch Kitty Terminal</span>
                    <span class="btn-desc">Super + Return</span>
                </button>
                <button class="btn-accent-blue" onclick="trigger('thunar')">
                    <span>📁 Open File Manager</span>
                    <span class="btn-desc">Thunar</span>
                </button>
                <button class="btn-accent-yellow" onclick="trigger('notify_test')">
                    <span>🔔 Send Test Toast</span>
                    <span class="btn-desc">Normal Toast</span>
                </button>
                <button class="btn-accent-red" onclick="trigger('notify_warn')">
                    <span>⚠️ Send Critical Alert</span>
                    <span class="btn-desc">Critical Toast</span>
                </button>
                <button class="btn-accent-purple" onclick="trigger('reload_shell')">
                    <span>🔄 Reload Desktop Shell</span>
                    <span class="btn-desc">Live Refresh</span>
                </button>
                <button class="btn-accent-yellow" onclick="trigger('close_all')">
                    <span>❌ Close All Popups</span>
                    <span class="btn-desc">Dismiss</span>
                </button>
                <button class="btn-accent-red" onclick="trigger('lock')">
                    <span>🔒 Lock Screen</span>
                    <span class="btn-desc">b1air Lock</span>
                </button>
            </div>
        </div>
    </div>

    <div id="toast">Action triggered!</div>

    <script>
        function trigger(action) {
            const toast = document.getElementById('toast');
            toast.textContent = "Triggering " + action + "...";
            toast.classList.add('show');
            
            fetch('/api/call?action=' + action)
                .then(r => r.json())
                .then(res => {
                    toast.textContent = res.status === "ok" ? "✓ " + action + " executed!" : "Error: " + res.message;
                    setTimeout(() => toast.classList.remove('show'), 2000);
                })
                .catch(err => {
                    toast.textContent = "Request failed";
                    setTimeout(() => toast.classList.remove('show'), 2000);
                });
        }
    </script>
</body>
</html>
"""

class DeckServer(http.server.BaseHTTPRequestHandler):
    def log_message(self, format, *args):
        pass  # Quiet logs

    def do_GET(self):
        parsed = urllib.parse.urlparse(self.path)
        if parsed.path == "/":
            self.send_response(200)
            self.send_header("Content-Type", "text/html; charset=utf-8")
            self.end_headers()
            self.wfile.write(HTML_TEMPLATE.encode("utf-8"))
            return

        if parsed.path == "/api/call":
            query = urllib.parse.parse_qs(parsed.query)
            action = query.get("action", [""])[0]

            if action in ACTIONS:
                remote_cmd = ACTIONS[action]
                full_ssh = [
                    SSH_SCRIPT,
                    f"export XDG_RUNTIME_DIR=/run/user/1000 WAYLAND_DISPLAY=wayland-1; {remote_cmd}"
                ]
                try:
                    res = subprocess.run(full_ssh, capture_output=True, text=True, timeout=5)
                    response = {"status": "ok", "action": action, "output": res.stdout.strip()}
                except Exception as e:
                    response = {"status": "error", "message": str(e)}
            else:
                response = {"status": "error", "message": "Unknown action"}

            self.send_response(200)
            self.send_header("Content-Type", "application/json")
            self.end_headers()
            self.wfile.write(json.dumps(response).encode("utf-8"))
            return

        self.send_response(404)
        self.end_headers()

def main():
    server = http.server.HTTPServer(("127.0.0.1", PORT), DeckServer)
    url = f"http://localhost:{PORT}"
    print(f"\n=======================================================")
    print(f"🚀 b1air OS Controller Deck running at: {url}")
    print(f"👉 Opening browser automatically...")
    print(f"Press Ctrl+C to stop.")
    print(f"=======================================================\n")
    try:
        webbrowser.open(url)
    except Exception:
        pass
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        print("\nController Deck stopped.")

if __name__ == "__main__":
    main()
