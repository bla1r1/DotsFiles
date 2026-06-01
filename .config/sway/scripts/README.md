# Sway Scripts

- `core/` - Quickshell manager, UI event bus, settings watcher, wallpaper restore, reload hooks.
- `controls/` - audio, mic, brightness, keyboard backlight, DDC monitor dimming.
- `session/` - lock and idle handling.
- `launchers/` - Rofi helpers.
- `tools/` - screenshots, monitor layout, game mode, joystick inhibit.
- `quickshell/` - QML popups and their module-local helpers.
- `lib/` - shared shell helpers.

`core/qs_bus.sh` provides lightweight UI event channels:
`main` for widget commands, `widget` for active widget state, `recording` for recorder state, and `update` for update indicator state.
