# Sway Scripts

- `core/` - Quickshell startup, settings watcher, wallpaper restore, reload hooks.
- `controls/` - audio, mic, brightness, keyboard backlight, DDC monitor dimming.
- `session/` - lock and idle handling.
- `launchers/` - Rofi helpers.
- `tools/` - screenshots, monitor layout, game mode, joystick inhibit.
- `quickshell/` - QML popups and their module-local helpers.
- `lib/` - shared shell helpers.

Quickshell panels are controlled through direct `qs ... ipc call main ...` commands.
