# Roadmap

Status:

- `[x]`: completed.
- `initial`: usable first implementation.
- `partial`: incomplete or limited implementation.
- `planned`: not implemented.
- `deferred`: intentionally postponed.

`b1nix` is a primary target of this Desktop Environment: each subsystem is built to run standalone without systemd dependencies (supporting seatd, runit, and native b1nix userspace).

## M0: Core Foundation and Session Management

- [x] Implement compiled C++20 `b1air-daemon` multi-call binary with direct syscall and IPC dispatch.
- [x] Implement direct Sway IPC UNIX domain socket client (`sway_ipc.cpp`) for sub-millisecond workspace tracking.
- [x] Implement SQLite3 FocusTime analytics engine (`focustime_db.cpp`) with prepared statements.
- [x] Implement POSIX & PAM User Manager (`user_manager.cpp`) for SDDM avatar and display name synchronization.
- [x] Implement dynamic `.desktop` application scanner and autostart picker.
- [x] Implement Sway scratchpad window minimization system (`b1air-daemon window {minimize|restore|list|open}`).
- [x] Implement init-agnostic session supervisor with power fallbacks for `b1nix` (runit, seatd, elogind, systemd).
- [x] Implement FreeDesktop session suite (`b1air.desktop`, `b1air-session`, `b1air-portals.conf`).
- [x] Implement Quickshell Settings App with 15+ configuration pages.
- [x] Implement Quickshell Control Center, Spotlight Launcher, Lock Screen, and SDDM Greeter.
- [x] Implement Quickshell Polkit agent dialog, Desktop Notification toasts, and OSD volume/mic overlays.
- [x] Implement Quickshell Visual `Alt + Tab` Window Switcher and Screen Color Picker (`Super+Shift+C`).
- [x] Implement native Emoji Picker popup (`Super+.`) and Caffeine stay-awake mode.
- [x] Implement desktop audio feedback service (`SoundEffects.qml`) and Waybar indicators.

## M1: Productivity, Clipboard Intelligence, and Data Workflow

- [ ] Add QuickLook instant file preview overlay for images, PDF, Markdown, code, and archives on `Space`.
- [ ] Add Screen OCR text grabber (`Super+Shift+O`) via `slurp`, `grim`, and `tesseract`.
- [ ] Add Drag & Drop shelf (floating file stash) for batch file staging and transfer.
- [ ] Add QR code generator and screen scanner (`Super+Shift+Q`) via `qrencode` and `zbarimg`.
- [ ] Add Smart Spotlight inline converters for currencies, units, and world timezones.
- [ ] Add pinned snippets and permanent templates tab in Clipboard Manager (`Super+V`).

## M2: Advanced Window Management and Screen Assistants

- [ ] Add FancyZones visual snapping grid assistant (`Super+Z`) for 1/3, 2/3, 2x2, and Ultrawide layouts.
- [ ] Add universal Picture-in-Picture (PiP) pinned mini-view mode (`Super+P`).
- [ ] Add cursor Shake-to-Find pulse locator for large 4K and multi-monitor setups.
- [ ] Add Screen Ruler and Pixel Inspector (`Super+Shift+M`) for UI design measurements.
- [ ] Add smooth hardware-accelerated Screen Magnifier (`Super+Alt++` / `Super+Alt+-`).
- [ ] Add Force Quit target crosshair (`Super+Escape`) for terminating unresponsive processes.

## M3: Audio Subsystem, Recording, and Multimedia Ecosystem

- [ ] Add per-application volume sliders and stream mixer in Control Center via PipeWire / WirePlumber.
- [ ] Add AI microphone noise suppression toggle in Control Center via RNNoise / PipeWire filter-chain.
- [ ] Add fast audio output switcher shortcut (`Super+Shift+A`) with graphical OSD confirmation.
- [ ] Add Screen-to-GIF recording tool with automatic optimization and clipboard copy.
- [ ] Add quick voice dictation and audio memo (`Super+Shift+V`) via local `whisper.cpp`.

## M4: Privacy, Security, and System Health Maintenance

- [ ] Add live Privacy Dots in Waybar for active microphone and camera access telemetry.
- [ ] Add Disk Sweeper and cache cleaner module in Settings for pacman, orphan packages, and thumbnails.
- [ ] Add automatic Btrfs and Timeshift pre-update restore point snapshot integration.
- [ ] Add Encrypted Vaults GUI manager for mounting password-protected folders.

## M5: Device Ecosystem, Cross-Platform Synchronization, and Remote Desktop

- [ ] Add Phone Link integration (KDE Connect / b1Connect) for battery, SMS, clipboard, and ring-my-phone.
- [ ] Add LocalSend / QuickDrop wireless peer-to-peer file transfer in local Wi-Fi networks.
- [x] Add native WayVNC Remote Desktop control in `b1air-daemon` (`b1air-daemon remote {start|stop|status|toggle}`) with TLS and password auth.
- [ ] Add Remote Desktop quick-toggle tile in Control Center (`Super+C`) with active client connection count badge.
- [x] Add Remote Desktop & Screen Sharing section in Settings App (`Super+Shift+S`) with port configuration, password management, and prompt-free permissions.
- [ ] Add Waybar active remote session indicator badge with instant 1-click disconnect for privacy protection.
- [x] Add headless sidecar display generator (`b1air-daemon sidecar create`) for using iPad / Android tablets as low-latency wireless secondary monitors via WayVNC.
- [x] Add direct compositor input injection via `wlr-virtual-pointer-v1`, `uinput`, and `virtual-keyboard-v1` to eliminate portal permission prompts.

## M6: Desktop Widgets, Personalization, and Smart UI

- [ ] Add desktop Sticky Notes and scratchpad memos (`Super+Shift+N`) with Markdown formatting.
- [ ] Add desktop Glance Layer canvas widgets (`Super+G`) for clocks, weather, and circular hardware dials.
- [ ] Add visual GUI Keyboard Shortcuts editor in Settings for modifying keybindings without text editing.
- [ ] Add dynamic solar day/night auto-theming engine for sunrise/sunset wallpaper and palette switching.
- [ ] Add live rolling hardware sensor and temperature telemetry graph overlay.

## M7: Display, Multi-Monitor, and Color Calibration

- [ ] Add fractional scaling GUI control in Display Settings (1.25x, 1.5x, 1.75x) with subpixel sharpness.
- [ ] Add Display Profile automatic switching on dock/undock events for HDMI/Type-C displays.
- [ ] Add external monitor hardware brightness control via DDC/CI in Control Center slider.
- [ ] Add ICC/ICM color profile calibration importer in Display Settings.
- [ ] Add distinct per-workspace and per-monitor wallpaper assignment engine.
- [ ] Add virtual headless display creation for tablet sidecar streaming (Moonlight / Sunshine).

## M8: Advanced Input, Touchpad Gestures, and Keyboard Physics

- [ ] Add 1:1 smooth multi-touch touchpad gestures (3-finger workspace switch, 4-finger overview/pinch).
- [ ] Add mouse acceleration profile switcher (Flat raw sensor input vs Adaptive curve).
- [ ] Add per-device scroll direction configuration (Natural scrolling for touchpad, standard for mouse wheel).
- [ ] Add 1-click CapsLock re-mapping to Escape/Control in Keyboard Settings.
- [ ] Add responsive on-screen virtual touch keyboard (OSK) for touchscreen devices.

## M9: Developer, Terminal, and Power-User Workflow

- [ ] Add drop-down sliding Quake terminal (`F12` / `Super+~`) persistent across all workspaces.
- [ ] Add global file content search (Ripgrep integration in Spotlight via `find:` / `grep:` prefix).
- [ ] Add open network ports and listening process inspector in Settings with 1-click process kill.
- [ ] Add Git repository status telemetry widget in Waybar and Spotlight.
- [ ] Add Environment Variables (`PATH`, `EDITOR`, `XDG_*`) GUI editor in Settings.
- [ ] Add System Services manager (systemd/runit/b1nix) in Settings Maintenance.

## M10: Gaming, Graphics, and Low-Latency Performance

- [ ] Add Variable Refresh Rate (VRR / G-Sync / FreeSync) toggle per output in Display Settings.
- [ ] Add direct scanout compositor bypass for fullscreen games to achieve 0ms compositor overhead.
- [ ] Add in-game telemetry HUD overlay (`Super+Shift+F`) displaying FPS, frametimes, GPU/CPU load, and temps.
- [ ] Add connected gamepad controller battery level indicator in Waybar (DualSense, Xbox, 8BitDo).
- [ ] Add Wine and Proton bottle prefix manager in App Launcher for running Windows executables.

## M11: File Management, Storage Analytics, and Archive Suite

- [ ] Add batch file renamer utility (`Super+Shift+R`) with regex, numbering, and case transformation.
- [ ] Add interactive disk space sunburst / treemap visualizer in Settings.
- [ ] Add file checksum hash calculator and clipboard verifier (MD5, SHA256).
- [ ] Add native archive compression and extraction popup for `.zip`, `.tar.gz`, `.tar.zst`, and `.7z`.
- [ ] Add scheduled Trash auto-purge (>30 days) and 1-click deleted file restore.

## M12: Network, VPN, Firewall, and Security Hardening

- [ ] Add 1-click WireGuard and OpenVPN quick tiles in Control Center with ping and killswitch telemetry.
- [ ] Add automatic Captive Portal browser login popup detection for public Wi-Fi networks.
- [ ] Add 1-click Wi-Fi Hotspot sharing in Network Settings.
- [ ] Add graphical Firewall (UFW / nftables) status monitor and port management in Security Settings.
- [ ] Add USB Guard protection preventing unauthorized HID keyboard injection when locked.

## M13: Wellness, Ergonomics, and Accessibility

- [ ] Add 20-20-20 eye strain break reminder notification and subtle screen dim.
- [ ] Add accessibility color blindness shaders (Protanopia, Deuteranopia, Tritanopia) and Grayscale digital detox mode.
- [ ] Add high contrast and large text 130% accessibility scaling preset.
- [ ] Add typing mechanical keyboard sound feedback simulation toggle.

## M14: Notification Intelligence and Focus Ecosystem

- [ ] Add scheduled Do Not Disturb / Focus Hours automation (e.g. night hours or calendar meetings).
- [ ] Add granular per-application notification priority rules and channel filtering.
- [ ] Add 7-day searchable notification history archive.
- [ ] Add synchronized LRC song lyrics display in the expanded media player.
