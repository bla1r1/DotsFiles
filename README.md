# 🌌 b1air Desktop Environment

<div align="center">

![b1air Desktop Environment](https://raw.githubusercontent.com/bla1r1/DotsFiles/main/.wallpapers/tokyo-night.jpg)

**Next-Generation Wayland Desktop Environment for Arch Linux**  
*Powered by SwayFX, Quickshell (Qt6/QML), C++20 Core Daemon Suite, and Tokyo Night Aesthetics.*

[![Platform: Arch Linux](https://img.shields.io/badge/Distro-Arch_Linux-1793d1?style=for-the-badge&logo=archlinux&logoColor=white)](https://archlinux.org)
[![Compositor: SwayFX](https://img.shields.io/badge/Compositor-SwayFX_0.6-005577?style=for-the-badge&logo=wayland&logoColor=white)](https://github.com/WillPower3309/swayfx)
[![UI: Quickshell](https://img.shields.io/badge/UI-Quickshell_Qt6-41cd52?style=for-the-badge&logo=qt&logoColor=white)](https://quickshell.outfoxxed.me)
[![Core: C++20](https://img.shields.io/badge/Core-C++20_Daemon-00599c?style=for-the-badge&logo=c%2B%2B&logoColor=white)](https://isocpp.org)
[![Theme: Tokyo Night](https://img.shields.io/badge/Theme-Tokyo_Night-7aa2f7?style=for-the-badge)](https://github.com/folke/tokyonight.nvim)

</div>

---

## ⚡ Highlights & Key Features

### 💎 Aesthetics & Compositor Experience
- **SwayFX Compositor**: Native GPU-accelerated rounded corners (`corner_radius 10`), backdrop blur, shadows, and smooth layer effects with zero rendering errors.
- **Tokyo Night Palette**: Consistent `#1a1b26` background, `#7aa2f7` sapphire accents, `#bb9af7` lavender glyphs, `#7dcfff` cyan highlights, and `#f7768e` danger tones applied across windows, bars, menus, terminals, and display manager.
- **SDDM `b1air` Greeter**: Modern Qt6 SDDM theme featuring smooth glassmorphism, user avatar synchronization, layout selector, and virtual keyboard.

### 🚀 C++20 `b1air-daemon` Desktop Suite
Unlike traditional shell-heavy setups with fork overhead, **b1air** features a compiled **C++20 multi-call daemon binary** (`src/`) interacting directly with system APIs:
- **Direct Sway IPC Client (`sway_ipc.cpp`)**: Subscribes directly to Wayland compositor event sockets via UNIX domain sockets for sub-millisecond window/workspace tracking.
- **FocusTime SQLite Engine (`focustime_db.cpp`)**: High-performance time-tracking database with prepared SQLite statements and sub-millisecond JSON analytics output.
- **POSIX & PAM User Manager (`user_manager.cpp`)**: Native avatar synchronizer (`~/.face.icon` and AccountsService), GECOS display name updates, shell switcher, and secure PAM password launcher.
- **Zero-Overhead Game Mode (`system_control.cpp`)**: One-command compositor effect bypass, CPU governor switching, and low-latency PipeWire quantum adjustment.
- **Session Controller**: Native D-Bus and logind integration for lock, logout, suspend, reboot, and poweroff.

### 🎛️ Quickshell Qt6 Desktop Shell
- **Spotlight Launcher (`Super+Space` / `Super+D`)**: Fast app search, clipboard history, quick actions, and instant inline math calculation.
- **Control Center (`Super+C`)**: Quick toggles for WiFi, Bluetooth, Volume, Brightness, Game Mode, DND, and Screenshot tools.
- **Settings App (`Super+I`)**: Full graphical control center for wallpapers, themes, monitors, sound, user profiles, focus time analytics, and desktop behaviors.
- **Unified Lockscreen (`Lock.qml`)**: Matches the SDDM `b1air` login screen with instant unlock and battery/network indicators.

---

## 🚀 Quick Start & Installation

### 1. Automated One-Liner (Recommended)
Run the bootstrap script on a fresh or existing Arch Linux installation:

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/bla1r1/DotsFiles/main/bootstrap.sh)
```

### 2. Manual Git Clone

```bash
git clone https://github.com/bla1r1/DotsFiles.git ~/DotsFiles
cd ~/DotsFiles
bash install.sh
```

### 3. Interactive Graphical Installer
For a step-by-step installation menu:

```bash
git clone https://github.com/bla1r1/DotsFiles.git ~/DotsFiles
cd ~/DotsFiles
bash install-ui.sh
```

### 4. Installation Flags
You can customize the installation process with command-line options:

```bash
# Skip AUR packages and use standard packages
bash install.sh --no-aur

# Skip package manager and only deploy dotfiles & compile daemon
bash install.sh --skip-packages

# Preview changes without modifying the system
bash install.sh --dry-run
```

---

## ⌨️ Default Keybindings & Shortcuts

| Shortcut | Action | Component |
| :--- | :--- | :--- |
| `Super + Return` | Open Kitty Terminal | Kitty (Tokyo Night) |
| `Super + Space` / `Super + D` | Open Spotlight Search & Launcher | Quickshell Spotlight |
| `Super + I` | Open System Settings App | Quickshell Settings |
| `Super + C` | Open Control Center | Quickshell Control |
| `Super + V` | Open Clipboard Manager | Quickshell Clipboard |
| `Super + N` | Open Network / WiFi Manager | Quickshell Network |
| `Super + M` | Open Display & Monitor Manager | Quickshell Monitors |
| `Super + Shift + T` | Open Focus & Screen Time Analytics | Quickshell FocusTime |
| `Super + Shift + G` | Toggle Zero-Overhead Game Mode | `b1air-daemon` |
| `Print` | Interactive Screenshot Area Selection | `grim` + `slurp` |
| `Super + Print` | Full Screen Screenshot | `b1air-daemon` |
| `Super + Shift + Print` | Active Window Screenshot | `b1air-daemon` |
| `Ctrl + Alt + L` | Lock Screen | `b1air` Lockscreen |
| `Super + Shift + E` | Open Power & Session Menu | Quickshell Session |
| `Super + Shift + Q` | Close Focused Window | SwayFX |
| `Super + Shift + Space` | Toggle Floating Window Mode | SwayFX |

---

## 🛠️ CLI Reference: `b1air-daemon`

`b1air-daemon` is available in `~/.local/bin/b1air-daemon` and provides fast system control:

```bash
# Run the Sway focus tracking service in background
b1air-daemon focus &

# Get FocusTime screen analytics in JSON format
b1air-daemon stats
b1air-daemon stats 2026-08-26

# User profile management (instant QML integration)
b1air-daemon user get
b1air-daemon user set-name "Your Name"
b1air-daemon user set-avatar ~/Pictures/avatar.png
b1air-daemon user set-shell /usr/bin/fish
b1air-daemon user change-password

# Gaming mode performance optimization
b1air-daemon game-mode on
b1air-daemon game-mode off
b1air-daemon game-mode toggle
b1air-daemon game-mode status

# Session and power control
b1air-daemon power lock
b1air-daemon power logout
b1air-daemon power suspend
b1air-daemon power reboot
b1air-daemon power shutdown

# Screenshots
b1air-daemon screenshot full
b1air-daemon screenshot area
b1air-daemon screenshot window
```

---

## 📁 Repository Structure

```
DotsFiles/
├── .config/
│   ├── fish/                  # Fish shell configs & Tokyo Night prompts
│   ├── kitty/                 # Kitty terminal emulator config & font settings
│   ├── quickshell/            # Quickshell Qt6 desktop suite (Settings, Spotlight, Bar, OSD)
│   ├── sway/                  # SwayFX compositor configuration & keybindings
│   └── waybar/                # Waybar status bar layouts & stylesheets
├── src/                       # Native C++20 b1air-daemon desktop suite
│   ├── main.cpp               # CLI dispatcher and daemon loop
│   ├── sway_ipc.cpp           # Direct Sway IPC UNIX socket client
│   ├── focustime_db.cpp       # SQLite3 FocusTime analytics engine
│   ├── user_manager.cpp       # POSIX user & SDDM avatar synchronizer
│   ├── system_control.cpp     # GameMode, Power, and Screenshot controllers
│   └── Makefile               # C++20 build pipeline
├── usr/share/sddm/themes/     # SDDM b1air Qt6 greeter theme
├── bootstrap.sh               # Remote one-liner curl installer
├── install.sh                 # Main Arch Linux deployment script
└── install-ui.sh              # Interactive Whiptail installer UI
```

## 🗺 Master Roadmap & Evolution

Detailed architectural roadmap and planned feature epics (M1–M6) are documented in:
- 📖 **[`docs/ROADMAP.md`](docs/ROADMAP.md)** — Productivity tools, window management, audio mixers, privacy controls, device sync, and smart desktop widgets.

---

## 📄 License & Credits

- Created with ❤️ by [bla1r1](https://github.com/bla1r1) & pair-programmed with Google DeepMind Antigravity.
- Built for the Arch Linux and Wayland communities.
- Distributed under the [MIT License](LICENSE).
