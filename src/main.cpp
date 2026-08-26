#include "sway_ipc.hpp"
#include "focustime_db.hpp"
#include "user_manager.hpp"
#include "system_control.hpp"
#include "settings_manager.hpp"
#include "session_manager.hpp"

#include <iostream>
#include <string>
#include <vector>
#include <chrono>
#include <thread>
#include <csignal>
#include <cstdlib>
#include <unistd.h>

using namespace b1air;

static volatile sig_atomic_t g_running = 1;

static void handle_signal(int) {
    g_running = 0;
}

static void print_usage(const char* prog) {
    std::cout << "b1air-daemon — Native C++20 Desktop Suite & Session Manager\n\n"
              << "Usage: " << prog << " <command> [options...]\n\n"
              << "Core Desktop & Session Management:\n"
              << "  session                            Start full b1air desktop session (replaces all startup scripts)\n"
              << "  settings [apply|watch]             Manage & live-apply desktop configuration from settings.json\n"
              << "  focus                              Run event-driven Sway window focus tracker daemon\n"
              << "  stats [YYYY-MM-DD]                 Get FocusTime statistics as formatted JSON\n"
              << "  user get                           Get user profile details as formatted JSON\n"
              << "  user set-avatar <path>             Update user profile avatar and sync with SDDM\n"
              << "  user set-name <name>               Update user display / full name\n"
              << "  user set-shell <path>              Update user login shell\n"
              << "  user change-password               Launch secure interactive password prompt\n\n"
              << "Compositor & Waybar Helpers:\n"
              << "  layout                             Get active keyboard layout shorthand (US, UA, DE...)\n"
              << "  fullscreen-toggle                  Toggle fullscreen & auto-center floating window\n"
              << "  wifi-status                        Get Waybar-formatted Wi-Fi JSON\n"
              << "  media-status                       Get Waybar-formatted Media Player JSON\n"
              << "  updates [check|up]                 Get package updates JSON or launch system upgrade\n\n"
              << "Controls & Hardware:\n"
              << "  volume {get|up [N]|down [N]|mute}  Control audio sink volume & mute\n"
              << "  mic {get|toggle|mute}              Control microphone mute status\n"
              << "  brightness {available|get|up [N]|down [N]|set <pct>}\n"
              << "                                     Control screen backlight brightness\n"
              << "  ddc {dim|undim}                    Universal display dim/undim (backlight + DDC/CI)\n"
              << "  kbd-backlight {available|get|up [N]|down [N]|set <pct>|off}\n"
              << "                                     Control keyboard backlight\n"
              << "  wallpaper {set <file>|random [dir]|restore}\n"
              << "                                     Manage and apply desktop & SDDM wallpaper\n"
              << "  night-light {on [temp]|off|toggle|auto}\n"
              << "                                     Control color temperature & blue light filter\n"
              << "  term-theme {list|set <theme>}      List or switch Kitty terminal color palettes\n"
              << "  gamepad-inhibit                    Run daemon to inhibit idle when gamepads are active\n"
              << "  game-mode {on|off|toggle|status}   Control zero-overhead gaming optimizations\n"
              << "  power {lock|logout|suspend|reboot|shutdown}\n"
              << "                                     Execute session power state transitions\n"
              << "  screenshot [full|area|window]      Capture screen, copy to clipboard & save\n"
              << "  reload                             Reload compositor, Quickshell and Waybar\n"
              << "  lock                               Lock session with b1air theme\n"
              << "  version                            Print version information\n"
              << "  help                               Show this help message\n";
}

// ── Focus Tracker Daemon ─────────────────────────────────────────────────────
static int run_focus_tracker() {
    std::signal(SIGINT, handle_signal);
    std::signal(SIGTERM, handle_signal);

    SwayIPC ipc;
    if (!ipc.connect()) {
        std::cerr << "[b1air-focus] Error: Failed to connect to Sway IPC socket ($SWAYSOCK).\n";
        return 1;
    }

    FocusTimeDB db;
    if (!db.open()) {
        std::cerr << "[b1air-focus] Error: Failed to initialize SQLite database.\n";
        return 1;
    }

    std::cout << "[b1air-focus] Daemon started. Tracking active windows via Sway IPC...\n";

    std::string current_app = "Unknown";
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

    // Initial state
    WindowInfo init_win = ipc.get_focused_window();
    if (!init_win.app_class.empty()) {
        current_app = init_win.app_class;
        current_title = init_win.title;
    }

    // Subscribe to window and workspace events
    ipc.subscribe_events({"window", "workspace"}, [&](const std::string& /*evt_type*/, const std::string& /*payload*/) {
        if (!g_running) return;

        // Check lock state
        bool is_locked = (access("/tmp/swaylock.lock", F_OK) == 0);

        WindowInfo win = ipc.get_focused_window();
        std::string new_app = is_locked ? "Screen Locked" : (win.app_class.empty() ? "Desktop" : win.app_class);
        std::string new_title = is_locked ? "Locked" : win.title;

        if (new_app != current_app || is_locked != current_locked) {
            flush_interval(new_app, new_title, is_locked);
        }
    });

    // Final flush on exit
    flush_interval("", "", false);
    std::cout << "[b1air-focus] Daemon stopped gracefully.\n";
    return 0;
}

// ── Main Entry Point ─────────────────────────────────────────────────────────
int main(int argc, char* argv[]) {
    if (argc < 2) {
        print_usage(argv[0]);
        return 1;
    }

    std::string cmd = argv[1];

    if (cmd == "session" || cmd == "start-session") {
        return SessionManager::run_session();
    } else if (cmd == "settings") {
        std::string sub = (argc >= 3) ? argv[2] : "apply";
        if (sub == "watch") {
            int running = 1;
            return SettingsManager::watch_and_apply(&running);
        } else {
            return SettingsManager::apply_from_file() ? 0 : 1;
        }
    } else if (cmd == "focus" || cmd == "focus-tracker") {
        return run_focus_tracker();
    } else if (cmd == "gamepad-inhibit" || cmd == "joystick-inhibit") {
        return SystemControl::run_gamepad_inhibit();
    } else if (cmd == "stats") {
        std::string date_arg = (argc >= 3) ? argv[2] : "";
        FocusTimeDB db;
        if (!db.open()) {
            std::cerr << "{\"error\":\"failed to open database\"}\n";
            return 1;
        }
        std::cout << db.get_stats_json(date_arg) << "\n";
        return 0;
    } else if (cmd == "user") {
        if (argc < 3) {
            std::cerr << "Usage: " << argv[0] << " user {get|set-avatar <path>|set-name <name>|set-shell <path>|change-password}\n";
            return 1;
        }
        std::string sub = argv[2];
        if (sub == "get") {
            std::cout << UserManager::get_user_info_json() << "\n";
            return 0;
        } else if (sub == "set-avatar") {
            if (argc < 4) {
                std::cerr << "Error: Missing image path\n";
                return 1;
            }
            return UserManager::set_avatar(argv[3]) ? 0 : 1;
        } else if (sub == "set-name") {
            if (argc < 4) {
                std::cerr << "Error: Missing name string\n";
                return 1;
            }
            return UserManager::set_name(argv[3]) ? 0 : 1;
        } else if (sub == "set-shell") {
            if (argc < 4) {
                std::cerr << "Error: Missing shell path\n";
                return 1;
            }
            return UserManager::set_shell(argv[3]) ? 0 : 1;
        } else if (sub == "change-password") {
            return UserManager::change_password() ? 0 : 1;
        } else {
            std::cerr << "Unknown user command: " << sub << "\n";
            return 1;
        }
    } else if (cmd == "layout" || cmd == "lang") {
        std::cout << SystemControl::get_layout_shorthand() << "\n";
        return 0;
    } else if (cmd == "fullscreen-toggle" || cmd == "fullscreen") {
        return SystemControl::toggle_fullscreen() ? 0 : 1;
    } else if (cmd == "wifi-status" || cmd == "wifi") {
        std::cout << SystemControl::get_wifi_status_json() << "\n";
        return 0;
    } else if (cmd == "media-status" || cmd == "media") {
        std::cout << SystemControl::get_media_status_json() << "\n";
        return 0;
    } else if (cmd == "updates") {
        std::string sub = (argc >= 3) ? argv[2] : "check";
        if (sub == "up" || sub == "upgrade") {
            return SystemControl::launch_system_upgrade() ? 0 : 1;
        } else {
            std::cout << SystemControl::get_updates_json() << "\n";
            return 0;
        }
    } else if (cmd == "volume") {
        std::string sub = (argc >= 3) ? argv[2] : "get";
        int step = (argc >= 4) ? std::atoi(argv[3]) : 5;
        if (sub == "get") {
            std::cout << SystemControl::get_volume() << "\n";
            return 0;
        } else if (sub == "up" || sub == "inc") {
            return SystemControl::volume_up(step) ? 0 : 1;
        } else if (sub == "down" || sub == "dec") {
            return SystemControl::volume_down(step) ? 0 : 1;
        } else if (sub == "mute" || sub == "toggle") {
            return SystemControl::volume_toggle_mute() ? 0 : 1;
        } else {
            std::cerr << "Usage: " << argv[0] << " volume {get|up [N]|down [N]|mute}\n";
            return 1;
        }
    } else if (cmd == "mic") {
        std::string sub = (argc >= 3) ? argv[2] : "toggle";
        if (sub == "get" || sub == "waybar") {
            std::string status = SystemControl::get_mic_status();
            std::cout << (status == "muted" ? "" : "") << "\n";
            return 0;
        } else if (sub == "toggle" || sub == "mute") {
            return SystemControl::mic_toggle() ? 0 : 1;
        } else {
            std::cerr << "Usage: " << argv[0] << " mic {get|toggle}\n";
            return 1;
        }
    } else if (cmd == "brightness" || cmd == "backlight") {
        std::string sub = (argc >= 3) ? argv[2] : "get";
        int step = (argc >= 4) ? std::atoi(argv[3]) : 5;
        if (sub == "available") {
            return SystemControl::brightness_available() ? 0 : 1;
        } else if (sub == "get") {
            std::cout << SystemControl::brightness_get() << "\n";
            return 0;
        } else if (sub == "up" || sub == "inc") {
            return SystemControl::brightness_up(step) ? 0 : 1;
        } else if (sub == "down" || sub == "dec") {
            return SystemControl::brightness_down(step) ? 0 : 1;
        } else if (sub == "set") {
            return SystemControl::brightness_set(step) ? 0 : 1;
        } else {
            std::cerr << "Usage: " << argv[0] << " brightness {available|get|up [N]|down [N]|set <pct>}\n";
            return 1;
        }
    } else if (cmd == "ddc") {
        std::string sub = (argc >= 3) ? argv[2] : "dim";
        if (sub == "dim") return SystemControl::ddc_dim() ? 0 : 1;
        if (sub == "undim") return SystemControl::ddc_undim() ? 0 : 1;
        std::cerr << "Usage: " << argv[0] << " ddc {dim|undim}\n";
        return 1;
    } else if (cmd == "kbd-backlight" || cmd == "kbd") {
        std::string sub = (argc >= 3) ? argv[2] : "get";
        int step = (argc >= 4) ? std::atoi(argv[3]) : 10;
        if (sub == "available" || sub == "--available") {
            return SystemControl::kbd_backlight_available() ? 0 : 1;
        } else if (sub == "get" || sub == "--get") {
            std::cout << SystemControl::kbd_backlight_get() << "\n";
            return 0;
        } else if (sub == "up" || sub == "inc" || sub == "--inc") {
            return SystemControl::kbd_backlight_inc(step) ? 0 : 1;
        } else if (sub == "down" || sub == "dec" || sub == "--dec") {
            return SystemControl::kbd_backlight_dec(step) ? 0 : 1;
        } else if (sub == "set" || sub == "--set") {
            int val = (argc >= 4) ? std::atoi(argv[3]) : 50;
            return SystemControl::kbd_backlight_set(val) ? 0 : 1;
        } else if (sub == "off" || sub == "--off") {
            return SystemControl::kbd_backlight_off() ? 0 : 1;
        } else {
            std::cerr << "Usage: " << argv[0] << " kbd-backlight {available|get|up [N]|down [N]|set <val>|off}\n";
            return 1;
        }
    } else if (cmd == "wallpaper") {
        std::string sub = (argc >= 3) ? argv[2] : "restore";
        if (sub == "set") {
            if (argc < 4) {
                std::cerr << "Usage: " << argv[0] << " wallpaper set <path>\n";
                return 1;
            }
            return SystemControl::wallpaper_set(argv[3]) ? 0 : 1;
        } else if (sub == "random") {
            std::string dir = (argc >= 4) ? argv[3] : "";
            return SystemControl::wallpaper_random(dir) ? 0 : 1;
        } else if (sub == "restore") {
            return SystemControl::wallpaper_restore() ? 0 : 1;
        } else {
            std::cerr << "Usage: " << argv[0] << " wallpaper {set <file>|random [dir]|restore}\n";
            return 1;
        }
    } else if (cmd == "night-light" || cmd == "nightlight") {
        std::string sub = (argc >= 3) ? argv[2] : "toggle";
        if (sub == "on") {
            int temp = (argc >= 4) ? std::atoi(argv[3]) : 4000;
            return SystemControl::night_light_on(temp) ? 0 : 1;
        } else if (sub == "off") {
            return SystemControl::night_light_off() ? 0 : 1;
        } else if (sub == "toggle") {
            return SystemControl::night_light_toggle() ? 0 : 1;
        } else if (sub == "auto") {
            return SystemControl::night_light_auto() ? 0 : 1;
        } else {
            std::cerr << "Usage: " << argv[0] << " night-light {on [temp]|off|toggle|auto}\n";
            return 1;
        }
    } else if (cmd == "term-theme") {
        std::string sub = (argc >= 3) ? argv[2] : "list";
        if (sub == "list") {
            auto themes = SystemControl::term_theme_list();
            for (const auto& t : themes) std::cout << t << "\n";
            return 0;
        } else if (sub == "set") {
            if (argc < 4) {
                std::cerr << "Usage: " << argv[0] << " term-theme set <theme-name>\n";
                return 1;
            }
            return SystemControl::term_theme_set(argv[3]) ? 0 : 1;
        } else {
            return SystemControl::term_theme_set(sub) ? 0 : 1;
        }
    } else if (cmd == "reload") {
        return SystemControl::reload_desktop() ? 0 : 1;
    } else if (cmd == "game-mode" || cmd == "gamemode") {
        std::string sub = (argc >= 3) ? argv[2] : "toggle";
        if (sub == "on" || sub == "enable") {
            return SystemControl::enable_game_mode() ? 0 : 1;
        } else if (sub == "off" || sub == "disable") {
            return SystemControl::disable_game_mode() ? 0 : 1;
        } else if (sub == "toggle") {
            return SystemControl::toggle_game_mode() ? 0 : 1;
        } else if (sub == "status") {
            std::cout << SystemControl::get_game_mode_status_json() << "\n";
            return 0;
        } else {
            std::cerr << "Usage: " << argv[0] << " game-mode {on|off|toggle|status}\n";
            return 1;
        }
    } else if (cmd == "power") {
        if (argc < 3) {
            std::cerr << "Usage: " << argv[0] << " power {lock|logout|suspend|reboot|shutdown}\n";
            return 1;
        }
        std::string sub = argv[2];
        if (sub == "lock") return SystemControl::lock_session() ? 0 : 1;
        if (sub == "logout") return SystemControl::logout_session() ? 0 : 1;
        if (sub == "suspend") return SystemControl::suspend_system() ? 0 : 1;
        if (sub == "reboot") return SystemControl::reboot_system() ? 0 : 1;
        if (sub == "shutdown" || sub == "poweroff") return SystemControl::shutdown_system() ? 0 : 1;
        std::cerr << "Unknown power command: " << sub << "\n";
        return 1;
    } else if (cmd == "screenshot") {
        std::string mode = (argc >= 3) ? argv[2] : "full";
        return SystemControl::capture_screenshot(mode) ? 0 : 1;
    } else if (cmd == "lock") {
        return SystemControl::lock_session() ? 0 : 1;
    } else if (cmd == "version" || cmd == "-v" || cmd == "--version") {
        std::cout << "b1air-daemon v2.5.0 (C++20, Session Manager, Inotify, Sway-IPC, Tokyo Night)\n";
        return 0;
    } else if (cmd == "help" || cmd == "-h" || cmd == "--help") {
        print_usage(argv[0]);
        return 0;
    } else {
        std::cerr << "Unknown command: " << cmd << "\n";
        print_usage(argv[0]);
        return 1;
    }
}
