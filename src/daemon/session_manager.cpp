#include "session_manager.hpp"
#include "settings_manager.hpp"
#include "system_control.hpp"
#include "sway_ipc.hpp"
#include "focustime_db.hpp"
#include "daemon_dbus.hpp"

#include <iostream>
#include <thread>
#include <vector>
#include <csignal>
#include <cstdlib>
#include <unistd.h>
#include <sys/stat.h>
#include <cstring>

namespace b1air {

static volatile sig_atomic_t g_session_running = 1;

static void session_sig_handler(int) {
    g_session_running = 0;
}

// ── Spawn helper that runs command in background detached ────────────────────
static void spawn_detached(const std::string& cmd) {
    std::string full = cmd + " >/dev/null 2>&1 &";
    std::system(full.c_str());
}

static bool is_process_running(const std::string& pattern) {
    std::string check = "pgrep -f \"" + pattern + "\" >/dev/null 2>&1";
    return (std::system(check.c_str()) == 0);
}

// ── Focus Tracker Thread ─────────────────────────────────────────────────────
static void focus_tracker_thread() {
    SwayIPC ipc;
    if (!ipc.connect()) return;

    FocusTimeDB db;
    if (!db.open()) return;

    std::string current_app = "Desktop";
    std::string current_title = "";
    bool current_locked = false;
    auto last_switch_time = std::chrono::system_clock::now();

    auto flush_interval = [&](const std::string& new_app, const std::string& new_title, bool new_locked) {
        auto now = std::chrono::system_clock::now();
        int64_t start_ts = std::chrono::duration_cast<std::chrono::seconds>(last_switch_time.time_since_epoch()).count();
        int64_t end_ts = std::chrono::duration_cast<std::chrono::seconds>(now.time_since_epoch()).count();

        if (end_ts - start_ts >= 1 && !current_app.empty()) {
            db.log_interval(start_ts, end_ts, current_app, current_title, current_locked);
        }

        current_app = new_app;
        current_title = new_title;
        current_locked = new_locked;
        last_switch_time = now;
    };

    ipc.subscribe_events({"window", "workspace"}, [&](const std::string&, const std::string&) {
        if (!g_session_running) return;
        bool is_locked = (access("/tmp/swaylock.lock", F_OK) == 0);
        WindowInfo win = ipc.get_focused_window();
        std::string new_app = is_locked ? "Screen Locked" : (win.app_class.empty() ? "Desktop" : win.app_class);
        std::string new_title = is_locked ? "Locked" : win.title;

        // Native zero-overhead autotiling (replaces external autotiling python daemon)
        if (!is_locked && !win.floating && !win.fullscreen && win.width > 0 && win.height > 0) {
            SwayIPC split_ipc;
            if (split_ipc.connect()) {
                if (win.width > win.height) {
                    split_ipc.send_command(0, "split h");
                } else {
                    split_ipc.send_command(0, "split v");
                }
            }
        }

        if (new_app != current_app || is_locked != current_locked) {
            flush_interval(new_app, new_title, is_locked);
        }
    });

    flush_interval("", "", false);
}

int SessionManager::run_session() {
    std::signal(SIGINT, session_sig_handler);
    std::signal(SIGTERM, session_sig_handler);

    std::cout << "[b1air-session] Initializing native b1air Desktop Session Manager...\n";

    // 0. Auto-discover Wayland Display if unset
    const char* wdisp = std::getenv("WAYLAND_DISPLAY");
    if (!wdisp || strlen(wdisp) == 0) {
        const char* rundir = std::getenv("XDG_RUNTIME_DIR");
        if (rundir) {
            for (int i = 0; i < 5; ++i) {
                std::string sock = std::string(rundir) + "/wayland-" + std::to_string(i);
                if (access(sock.c_str(), F_OK) == 0) {
                    setenv("WAYLAND_DISPLAY", ("wayland-" + std::to_string(i)).c_str(), 1);
                    break;
                }
            }
        }
    }

    // 1. Export Wayland & Qt Environment
    setenv("XDG_CURRENT_DESKTOP", "sway", 1);
    setenv("XDG_SESSION_TYPE", "wayland", 1);
    setenv("QT_QPA_PLATFORM", "wayland;xcb", 1);
    setenv("QSG_RHI_BACKEND", "opengl", 1);
    setenv("QSG_RENDER_LOOP", "basic", 1);
    setenv("QT_WAYLAND_DISABLE_WINDOWDECORATION", "1", 1);
    setenv("QT_AUTO_SCREEN_SCALE_FACTOR", "0", 1);
    setenv("MOZ_ENABLE_WAYLAND", "1", 1);

    // 2. DBus Activation Environment
    std::system("dbus-update-activation-environment --systemd WAYLAND_DISPLAY XDG_CURRENT_DESKTOP XDG_SESSION_TYPE >/dev/null 2>&1 || true");

    // 3. GNOME / GTK Theme GSettings
    std::system("gsettings set org.gnome.desktop.interface color-scheme prefer-dark >/dev/null 2>&1 || true");
    std::system("gsettings set org.gnome.desktop.interface gtk-theme Tokyonight-Dark >/dev/null 2>&1 || true");
    std::system("gsettings set org.gnome.desktop.interface icon-theme Papirus-Dark >/dev/null 2>&1 || true");

    // 4. Load Desktop Settings
    DesktopSettings settings = SettingsManager::load();
    SettingsManager::apply_to_sway(settings);

    // 5. Restore Wallpaper
    SystemControl::wallpaper_restore();

    // 6. Spawn Background Threads (Focus tracker, Gamepad inhibitor, Settings inotify watcher)
    std::thread focus_th(focus_tracker_thread);
    focus_th.detach();

    std::thread gamepad_th([&]() {
        while (g_session_running) {
            SystemControl::run_gamepad_inhibit();
            std::this_thread::sleep_for(std::chrono::seconds(2));
        }
    });
    gamepad_th.detach();

    int running_flag = 1;
    std::thread settings_th([&]() {
        SettingsManager::watch_and_apply(&running_flag);
    });
    settings_th.detach();

    // 7. Launch Polkit Agent
    if (!is_process_running("b1air-daemon polkit") && !is_process_running("polkit-gnome")) {
        spawn_detached("b1air-daemon polkit-agent");
    }

    // 9. Launch Swayidle
    if (!is_process_running("swayidle")) {
        std::string idle_cmd = "swayidle -w "
            "lock 'b1air-daemon lock' "
            "timeout " + std::to_string(settings.dimTimeout) + " 'b1air-daemon ddc dim' resume 'b1air-daemon ddc undim' "
            "timeout " + std::to_string(settings.lockTimeout) + " 'loginctl lock-session' resume 'b1air-daemon ddc undim' "
            "timeout " + std::to_string(settings.dpmsTimeout) + " 'swaymsg \"output * dpms off\"' resume 'swaymsg \"output * dpms on\"; b1air-daemon ddc undim' "
            "timeout " + std::to_string(settings.suspendTimeout) + " 'systemctl suspend' resume 'swaymsg \"output * dpms on\"; b1air-daemon ddc undim' "
            "before-sleep 'loginctl lock-session'";
        spawn_detached(idle_cmd);
    }

    // 10. Launch Waybar
    if (!is_process_running("waybar")) {
        spawn_detached("waybar");
    }

    // 11. Launch Native Desktop Shell
    const char* home = std::getenv("HOME");
    if (!is_process_running("quickshell")) {
        std::string qs_main = std::string(home ? home : "") + "/.config/quickshell/Main.qml";
        if (access(qs_main.c_str(), R_OK) == 0) {
            spawn_detached("quickshell -p " + qs_main);
        }
    }

    // 12. Auto-tune compositor effects for software rasterizer / VM (KDE Plasma approach)
    FILE* fp = popen("glxinfo 2>/dev/null | grep -iE 'llvmpipe|softpipe|swrast' || true", "r");
    if (fp) {
        char buf[128];
        if (fgets(buf, sizeof(buf), fp) != nullptr && strlen(buf) > 0) {
            std::system("swaymsg 'blur disable; shadows disable; default_dim_inactive 0.0' >/dev/null 2>&1 || true");
        }
        pclose(fp);
    }

    // 12. Autostart Applications from settings.json
    for (const auto& app : settings.autostartApps) {
        if (app == "telegram" && !is_process_running("telegram-desktop")) {
            spawn_detached("telegram-desktop -startintray");
        } else if (app == "discord" && !is_process_running("discord") && !is_process_running("vesktop")) {
            spawn_detached("vesktop --start-minimized || discord --start-minimized");
        } else if (app == "spotify" && !is_process_running("spotify")) {
            spawn_detached("spotify --minimized");
        } else if (app == "steam" && !is_process_running("steam")) {
            spawn_detached("steam -silent");
        }
    }

    for (const auto& custom_cmd : settings.autostartCustom) {
        if (!custom_cmd.empty()) {
            spawn_detached(custom_cmd);
        }
    }

    std::cout << "[b1air-session] All desktop services, UI, and background workers initialized.\n";

    sd_bus *dbus = nullptr;
    DaemonDBus::init_server(&dbus);

    // Main session loop processing D-Bus messages with kernel epoll (0% CPU)
    while (g_session_running) {
        if (dbus) {
            int r = sd_bus_process(dbus, nullptr);
            if (r < 0) {
                std::this_thread::sleep_for(std::chrono::milliseconds(100));
                continue;
            }
            if (r > 0) continue;
            sd_bus_wait(dbus, (uint64_t) 1000000);
        } else {
            std::this_thread::sleep_for(std::chrono::seconds(1));
        }
    }

    if (dbus) sd_bus_unref(dbus);

    running_flag = 0;
    std::cout << "[b1air-session] Session terminating gracefully.\n";
    return 0;
}

} // namespace b1air
