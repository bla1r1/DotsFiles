#include "session_manager.hpp"
#include "settings_manager.hpp"
#include "system_control.hpp"
#include "sway_ipc.hpp"
#include "focustime_db.hpp"
#include "daemon_dbus.hpp"
#include "runtime.hpp"

#include <iostream>
#include <thread>
#include <vector>
#include <csignal>
#include <cstdlib>
#include <unistd.h>
#include <sys/stat.h>
#include <cstring>
#include <cctype>
#include <sys/wait.h>
#include <fcntl.h>
#include <filesystem>
#include <array>

namespace b1air {

static volatile sig_atomic_t g_session_running = 1;

static void session_sig_handler(int) {
    g_session_running = 0;
}

// ── Spawn helper that runs command in background detached ────────────────────
static void spawn_shell_detached(const std::string& cmd) {
    if (cmd.empty() || cmd.size() > 4096) return;
    const pid_t pid = fork();
    if (pid < 0) return;
    if (pid == 0) {
        setsid();
        setenv("QT_QPA_PLATFORM", "wayland;xcb", 1);
        const int null_fd = open("/dev/null", O_RDWR | O_CLOEXEC);
        if (null_fd >= 0) {
            dup2(null_fd, STDIN_FILENO); dup2(null_fd, STDOUT_FILENO); dup2(null_fd, STDERR_FILENO);
            if (null_fd > STDERR_FILENO) close(null_fd);
        }
        execl("/bin/sh", "sh", "-c", cmd.c_str(), static_cast<char*>(nullptr));
        _exit(127);
    }
}

static void spawn_argv_detached(const std::vector<std::string>& args) {
    if (args.empty()) return;
    const pid_t pid = fork();
    if (pid < 0) return;
    if (pid == 0) {
        std::vector<char*> argv;
        for (const auto& arg : args) argv.push_back(const_cast<char*>(arg.c_str()));
        argv.push_back(nullptr);
        execvp(argv[0], argv.data());
        _exit(127);
    }
}

static bool run_status(const std::vector<std::string>& args) {
    if (args.empty()) return false;
    std::vector<char*> argv;
    for (const auto& arg : args) argv.push_back(const_cast<char*>(arg.c_str()));
    argv.push_back(nullptr);
    const pid_t pid = fork();
    if (pid < 0) return false;
    if (pid == 0) {
        const int null_fd = open("/dev/null", O_RDWR | O_CLOEXEC);
        if (null_fd >= 0) {
            dup2(null_fd, STDOUT_FILENO);
            dup2(null_fd, STDERR_FILENO);
            if (null_fd > STDERR_FILENO) close(null_fd);
        }
        execvp(argv[0], argv.data());
        _exit(127);
    }
    int status = 0;
    return waitpid(pid, &status, 0) == pid && WIFEXITED(status) && WEXITSTATUS(status) == 0;
}

static std::string run_capture(const std::vector<std::string>& args) {
    if (args.empty()) return {};
    int pipefd[2];
    if (pipe(pipefd) != 0) return {};
    const pid_t pid = fork();
    if (pid < 0) { close(pipefd[0]); close(pipefd[1]); return {}; }
    if (pid == 0) {
        dup2(pipefd[1], STDOUT_FILENO);
        close(pipefd[0]); close(pipefd[1]);
        std::vector<char*> argv;
        for (const auto& arg : args) argv.push_back(const_cast<char*>(arg.c_str()));
        argv.push_back(nullptr);
        execvp(argv[0], argv.data());
        _exit(127);
    }
    close(pipefd[1]);
    std::string output;
    std::array<char, 512> buffer{};
    ssize_t n;
    while ((n = read(pipefd[0], buffer.data(), buffer.size())) > 0) output.append(buffer.data(), static_cast<size_t>(n));
    close(pipefd[0]);
    int status = 0;
    waitpid(pid, &status, 0);
    return output;
}

static bool safe_custom_command(const std::string& cmd) {
    if (cmd.empty() || cmd.size() > 1024) return false;
    for (unsigned char c : cmd) {
        if (std::iscntrl(c) || c == ';' || c == '&' || c == '|' || c == '`' ||
            c == '$' || c == '<' || c == '>' || c == '\'' || c == '"' ||
            c == '(' || c == ')' || c == '{' || c == '}' || c == '\\') return false;
    }
    return true;
}

static bool is_process_running(const std::string& pattern) {
    return run_status({"pgrep", "-x", pattern}) || run_status({"pgrep", "-f", pattern});
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
        bool is_locked = (access(runtime_path("swaylock.lock").c_str(), F_OK) == 0);
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

    // A session started by a launcher/SSH helper may not inherit the variables
    // normally supplied by SDDM.  Without these, Qt/Quickshell cannot reach the
    // user's Wayland and D-Bus sessions, so every panel silently becomes a
    // no-op.  Derive only the standard per-user values; never import arbitrary
    // shell variables into the activation environment.
    if (!std::getenv("XDG_RUNTIME_DIR")) {
        setenv("XDG_RUNTIME_DIR", (std::string("/run/user/") + std::to_string(getuid())).c_str(), 1);
    }
    if (!std::getenv("DBUS_SESSION_BUS_ADDRESS")) {
        setenv("DBUS_SESSION_BUS_ADDRESS",
               (std::string("unix:path=") + std::getenv("XDG_RUNTIME_DIR")).append("/bus").c_str(), 1);
    }

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

    const char* swaysock = std::getenv("SWAYSOCK");
    if (!swaysock || strlen(swaysock) == 0) {
        std::error_code ec;
        const std::filesystem::path run_user = std::filesystem::path("/run/user") / std::to_string(getuid());
        std::filesystem::file_time_type newest{};
        std::string newest_socket;
        for (const auto& entry : std::filesystem::directory_iterator(run_user, ec)) {
            const std::string name = entry.path().filename().string();
            if (name.rfind("sway-ipc.", 0) != 0 || !name.ends_with(".sock")) continue;
            const auto mtime = entry.last_write_time(ec);
            if (newest_socket.empty() || mtime > newest) {
                newest = mtime;
                newest_socket = entry.path().string();
            }
        }
        if (!newest_socket.empty()) setenv("SWAYSOCK", newest_socket.c_str(), 1);
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
    // Do not publish the whole login environment to every user service.  It may
    // contain credentials inherited from a shell, editor, or development tool.
    // Only export variables required to activate the desktop session.
    run_status({"dbus-update-activation-environment", "--systemd",
                "DBUS_SESSION_BUS_ADDRESS", "XDG_RUNTIME_DIR", "PATH", "HOME",
                "USER", "LANG", "WAYLAND_DISPLAY", "SWAYSOCK",
                "XDG_CURRENT_DESKTOP", "XDG_SESSION_DESKTOP", "XDG_SESSION_TYPE",
                "QT_QPA_PLATFORM", "QT_QUICK_BACKEND", "QSG_RHI_BACKEND",
                "QSG_RENDER_LOOP", "MOZ_ENABLE_WAYLAND", "GDK_BACKEND",
                "WLR_RENDERER", "WLR_RENDERER_ALLOW_SOFTWARE", "WLR_NO_HARDWARE_CURSORS"});

    // 3. GNOME / GTK Theme GSettings
    run_status({"gsettings", "set", "org.gnome.desktop.interface", "color-scheme", "prefer-dark"});
    run_status({"gsettings", "set", "org.gnome.desktop.interface", "gtk-theme", "Tokyonight-Dark"});
    run_status({"gsettings", "set", "org.gnome.desktop.interface", "icon-theme", "Papirus-Dark"});

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
        spawn_argv_detached({"b1air-polkit-agent"});
    }

    // 9. Launch Swayidle
    if (!is_process_running("swayidle")) {
        std::string idle_cmd = "swayidle -w "
            "lock 'b1air-daemon lock' "
            "timeout " + std::to_string(settings.dimTimeout) + " 'b1air-daemon ddc dim' resume 'b1air-daemon ddc undim' "
            "timeout " + std::to_string(settings.lockTimeout) + " 'b1air-daemon power lock' resume 'b1air-daemon ddc undim' "
            "timeout " + std::to_string(settings.dpmsTimeout) + " 'swaymsg \"output * dpms off\"' resume 'swaymsg \"output * dpms on\"; b1air-daemon ddc undim' "
            "timeout " + std::to_string(settings.suspendTimeout) + " 'b1air-daemon power suspend' resume 'swaymsg \"output * dpms on\"; b1air-daemon ddc undim' "
            "before-sleep 'loginctl lock-session'";
            spawn_shell_detached(idle_cmd);
    }

    // 10. Launch Native Desktop Shell & TopBar (integrated Layer-Shell)
    if (!is_process_running("quickshell")) {
        const std::string qs_main = qml_entry("Main.qml");
        if (!qs_main.empty()) spawn_argv_detached({"quickshell", "-p", qs_main});
    }

    // 12. Auto-tune compositor effects for software rasterizer / VM (KDE Plasma approach)
    const std::string glx_info = run_capture({"glxinfo"});
    if (glx_info.find("llvmpipe") != std::string::npos ||
        glx_info.find("softpipe") != std::string::npos ||
        glx_info.find("swrast") != std::string::npos) {
        run_status({"swaymsg", "blur disable; shadows disable; default_dim_inactive 0.0"});
    }

    // 12. Autostart Applications from settings.json
    for (const auto& app : settings.autostartApps) {
        if (app == "telegram" && !is_process_running("telegram-desktop")) {
            spawn_argv_detached({"telegram-desktop", "-startintray"});
        } else if (app == "discord" && !is_process_running("discord") && !is_process_running("vesktop")) {
            if (access("/usr/bin/vesktop", X_OK) == 0) spawn_argv_detached({"vesktop", "--start-minimized"});
            else spawn_argv_detached({"discord", "--start-minimized"});
        } else if (app == "spotify" && !is_process_running("spotify")) {
            spawn_argv_detached({"spotify", "--minimized"});
        } else if (app == "steam" && !is_process_running("steam")) {
            spawn_argv_detached({"steam", "-silent"});
        }
    }

    for (const auto& custom_cmd : settings.autostartCustom) {
        // Custom autostart is intentionally shell-backed, but reject command
        // chaining and substitutions so a malformed settings file cannot turn
        // this into an arbitrary command injection primitive.
        if (safe_custom_command(custom_cmd)) {
            spawn_shell_detached(custom_cmd);
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
