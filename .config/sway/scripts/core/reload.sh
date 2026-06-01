#!/usr/bin/env bash
qs -p ~/.config/sway/scripts/quickshell/Main.qml ipc call main forceReload
qs -p ~/.config/sway/scripts/quickshell/TopBar.qml ipc call topbar forceReload
