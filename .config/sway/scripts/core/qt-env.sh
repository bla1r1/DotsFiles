#!/usr/bin/env bash

# Shared Qt/Quickshell runtime defaults for Wayland.
# Keep Qt Quick on the GPU path unless the user overrides these env vars.
export QT_QPA_PLATFORM="${QT_QPA_PLATFORM:-wayland}"
export QSG_RHI_BACKEND="${QSG_RHI_BACKEND:-opengl}"
export QSG_RENDER_LOOP="${QSG_RENDER_LOOP:-threaded}"
export QT_WAYLAND_DISABLE_WINDOWDECORATION="${QT_WAYLAND_DISABLE_WINDOWDECORATION:-1}"
export QT_AUTO_SCREEN_SCALE_FACTOR="${QT_AUTO_SCREEN_SCALE_FACTOR:-0}"
