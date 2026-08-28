#include "daemon_dbus.hpp"
#include "system_control.hpp"
#include "focustime_db.hpp"
#include <iostream>
#include <cstring>
#include <cstdlib>

namespace b1air {

static int method_lock(sd_bus_message *m, void *userdata, sd_bus_error *ret_error) {
    (void)userdata; (void)ret_error;
    SystemControl::lock_session();
    return sd_bus_reply_method_return(m, "");
}

static int method_reload(sd_bus_message *m, void *userdata, sd_bus_error *ret_error) {
    (void)userdata; (void)ret_error;
    std::system("swaymsg reload; b1air-shell forceReload >/dev/null 2>&1 || true");
    return sd_bus_reply_method_return(m, "");
}

static int method_volume_up(sd_bus_message *m, void *userdata, sd_bus_error *ret_error) {
    (void)userdata; (void)ret_error;
    int step = 5;
    sd_bus_message_read(m, "i", &step);
    SystemControl::volume_up(step);
    return sd_bus_reply_method_return(m, "");
}

static int method_volume_down(sd_bus_message *m, void *userdata, sd_bus_error *ret_error) {
    (void)userdata; (void)ret_error;
    int step = 5;
    sd_bus_message_read(m, "i", &step);
    SystemControl::volume_down(step);
    return sd_bus_reply_method_return(m, "");
}

static int method_volume_mute(sd_bus_message *m, void *userdata, sd_bus_error *ret_error) {
    (void)userdata; (void)ret_error;
    SystemControl::volume_toggle_mute();
    return sd_bus_reply_method_return(m, "");
}

static int method_brightness_up(sd_bus_message *m, void *userdata, sd_bus_error *ret_error) {
    (void)userdata; (void)ret_error;
    int step = 5;
    sd_bus_message_read(m, "i", &step);
    SystemControl::brightness_up(step);
    return sd_bus_reply_method_return(m, "");
}

static int method_brightness_down(sd_bus_message *m, void *userdata, sd_bus_error *ret_error) {
    (void)userdata; (void)ret_error;
    int step = 5;
    sd_bus_message_read(m, "i", &step);
    SystemControl::brightness_down(step);
    return sd_bus_reply_method_return(m, "");
}

static int method_brightness_set(sd_bus_message *m, void *userdata, sd_bus_error *ret_error) {
    (void)userdata; (void)ret_error;
    int pct = 50;
    sd_bus_message_read(m, "i", &pct);
    SystemControl::brightness_set(pct);
    return sd_bus_reply_method_return(m, "");
}

static int method_gamemode(sd_bus_message *m, void *userdata, sd_bus_error *ret_error) {
    (void)userdata; (void)ret_error;
    int enabled = 0;
    sd_bus_message_read(m, "b", &enabled);
    if (enabled) SystemControl::enable_game_mode();
    else SystemControl::disable_game_mode();
    return sd_bus_reply_method_return(m, "");
}

static int method_capture(sd_bus_message *m, void *userdata, sd_bus_error *ret_error) {
    (void)userdata; (void)ret_error;
    const char *mode = "full";
    sd_bus_message_read(m, "s", &mode);
    SystemControl::capture_screenshot(mode ? mode : "full");
    return sd_bus_reply_method_return(m, "");
}

static int method_power(sd_bus_message *m, void *userdata, sd_bus_error *ret_error) {
    (void)userdata; (void)ret_error;
    const char *action = "lock";
    sd_bus_message_read(m, "s", &action);
    std::string act = action ? action : "lock";
    if (act == "lock") SystemControl::lock_session();
    else if (act == "logout") SystemControl::logout_session();
    else if (act == "suspend") SystemControl::suspend_system();
    else if (act == "reboot") SystemControl::reboot_system();
    else if (act == "shutdown") SystemControl::shutdown_system();
    return sd_bus_reply_method_return(m, "");
}

static int method_get_stats(sd_bus_message *m, void *userdata, sd_bus_error *ret_error) {
    (void)userdata; (void)ret_error;
    const char *date = "";
    sd_bus_message_read(m, "s", &date);
    FocusTimeDB db;
    std::string res = "{}";
    if (db.open()) {
        res = db.get_stats_json(date ? date : "");
    }
    return sd_bus_reply_method_return(m, "s", res.c_str());
}

static const sd_bus_vtable daemon_vtable[] = {
    SD_BUS_VTABLE_START(0),
    SD_BUS_METHOD("Lock", "", "", method_lock, SD_BUS_VTABLE_UNPRIVILEGED),
    SD_BUS_METHOD("Reload", "", "", method_reload, SD_BUS_VTABLE_UNPRIVILEGED),
    SD_BUS_METHOD("VolumeUp", "i", "", method_volume_up, SD_BUS_VTABLE_UNPRIVILEGED),
    SD_BUS_METHOD("VolumeDown", "i", "", method_volume_down, SD_BUS_VTABLE_UNPRIVILEGED),
    SD_BUS_METHOD("ToggleMute", "", "", method_volume_mute, SD_BUS_VTABLE_UNPRIVILEGED),
    SD_BUS_METHOD("BrightnessUp", "i", "", method_brightness_up, SD_BUS_VTABLE_UNPRIVILEGED),
    SD_BUS_METHOD("BrightnessDown", "i", "", method_brightness_down, SD_BUS_VTABLE_UNPRIVILEGED),
    SD_BUS_METHOD("BrightnessSet", "i", "", method_brightness_set, SD_BUS_VTABLE_UNPRIVILEGED),
    SD_BUS_METHOD("SetGameMode", "b", "", method_gamemode, SD_BUS_VTABLE_UNPRIVILEGED),
    SD_BUS_METHOD("Capture", "s", "", method_capture, SD_BUS_VTABLE_UNPRIVILEGED),
    SD_BUS_METHOD("Power", "s", "", method_power, SD_BUS_VTABLE_UNPRIVILEGED),
    SD_BUS_METHOD("GetStats", "s", "s", method_get_stats, SD_BUS_VTABLE_UNPRIVILEGED),
    SD_BUS_SIGNAL("VolumeChanged", "ib", 0),
    SD_BUS_SIGNAL("BrightnessChanged", "i", 0),
    SD_BUS_SIGNAL("WallpaperChanged", "s", 0),
    SD_BUS_VTABLE_END
};

static std::string get_qs_prefix() {
    std::string prefix = "";
    const char *wdisp = std::getenv("WAYLAND_DISPLAY");
    if (!wdisp || strlen(wdisp) == 0) {
        const char *rundir = std::getenv("XDG_RUNTIME_DIR");
        if (rundir) {
            for (int i = 0; i < 5; ++i) {
                std::string sock = std::string(rundir) + "/wayland-" + std::to_string(i);
                if (access(sock.c_str(), F_OK) == 0) {
                    prefix = "WAYLAND_DISPLAY=wayland-" + std::to_string(i) + " ";
                    break;
                }
            }
        }
        if (prefix.empty()) prefix = "WAYLAND_DISPLAY=wayland-1 ";
    }
    return prefix;
}

static std::string get_qs_cmd(const std::string& subcmd) {
    const char *home = std::getenv("HOME");
    std::string home_str = home ? home : "/home/dev";
    return get_qs_prefix() + "quickshell -p " + home_str + "/.config/quickshell/Main.qml ipc call main " + subcmd + " >/dev/null 2>&1 &";
}

static int method_shell_toggle(sd_bus_message *m, void *userdata, sd_bus_error *ret_error) {
    (void)userdata; (void)ret_error;
    const char *panel = "launcher";
    sd_bus_message_read(m, "s", &panel);
    std::string p = (panel && strlen(panel) > 0) ? panel : "launcher";
    std::string cmd = get_qs_cmd("toggle " + p + " ''");
    std::system(cmd.c_str());
    return sd_bus_reply_method_return(m, "");
}

static int method_shell_open(sd_bus_message *m, void *userdata, sd_bus_error *ret_error) {
    (void)userdata; (void)ret_error;
    const char *panel = "launcher";
    const char *arg = "";
    sd_bus_message_read(m, "ss", &panel, &arg);
    std::string p = (panel && strlen(panel) > 0) ? panel : "launcher";
    std::string a = arg ? arg : "";
    std::string cmd = get_qs_cmd("open " + p + " '" + a + "'");
    std::system(cmd.c_str());
    return sd_bus_reply_method_return(m, "");
}

static int method_shell_close(sd_bus_message *m, void *userdata, sd_bus_error *ret_error) {
    (void)userdata; (void)ret_error;
    std::string cmd = get_qs_cmd("close");
    std::system(cmd.c_str());
    return sd_bus_reply_method_return(m, "");
}

static int method_shell_reload(sd_bus_message *m, void *userdata, sd_bus_error *ret_error) {
    (void)userdata; (void)ret_error;
    std::string cmd = get_qs_cmd("forceReload");
    std::system(cmd.c_str());
    return sd_bus_reply_method_return(m, "");
}

static const sd_bus_vtable shell_vtable[] = {
    SD_BUS_VTABLE_START(0),
    SD_BUS_METHOD("Toggle", "s", "", method_shell_toggle, SD_BUS_VTABLE_UNPRIVILEGED),
    SD_BUS_METHOD("Open", "ss", "", method_shell_open, SD_BUS_VTABLE_UNPRIVILEGED),
    SD_BUS_METHOD("Close", "s", "", method_shell_close, SD_BUS_VTABLE_UNPRIVILEGED),
    SD_BUS_METHOD("ForceReload", "", "", method_shell_reload, SD_BUS_VTABLE_UNPRIVILEGED),
    SD_BUS_SIGNAL("PanelStateChanged", "sb", 0),
    SD_BUS_VTABLE_END
};

int DaemonDBus::init_server(sd_bus **bus_out) {
    sd_bus *bus = nullptr;
    int r = sd_bus_open_user(&bus);
    if (r < 0) {
        std::cerr << "[b1air-daemon] Warning: Failed to connect to user D-Bus: " << strerror(-r) << "\n";
        return r;
    }

    r = sd_bus_add_object_vtable(bus, nullptr, "/org/b1air/Daemon", "org.b1air.Daemon", daemon_vtable, nullptr);
    if (r < 0) {
        std::cerr << "[b1air-daemon] Warning: Failed to register Daemon D-Bus vtable: " << strerror(-r) << "\n";
    }

    r = sd_bus_add_object_vtable(bus, nullptr, "/org/b1air/Shell", "org.b1air.Shell", shell_vtable, nullptr);
    if (r < 0) {
        std::cerr << "[b1air-daemon] Warning: Failed to register Shell D-Bus vtable: " << strerror(-r) << "\n";
    }

    sd_bus_request_name(bus, "org.b1air.Daemon", 0);
    sd_bus_request_name(bus, "org.b1air.Shell", 0);

    std::cout << "[b1air-daemon] Registered D-Bus services 'org.b1air.Daemon' and 'org.b1air.Shell'\n";
    *bus_out = bus;
    return 0;
}

int DaemonDBus::run_service() {
    sd_bus *bus = nullptr;
    int r = init_server(&bus);
    if (r < 0) return 1;

    std::cout << "[b1air-dbus] D-Bus service loop active. Listening on org.b1air.Daemon and org.b1air.Shell...\n";
    while (true) {
        r = sd_bus_process(bus, nullptr);
        if (r < 0) {
            std::cerr << "[b1air-dbus] Error processing D-Bus: " << strerror(-r) << "\n";
            break;
        }
        if (r > 0) continue;
        sd_bus_wait(bus, (uint64_t) -1);
    }
    sd_bus_unref(bus);
    return 0;
}

bool DaemonDBus::is_running() {
    sd_bus *bus = nullptr;
    if (sd_bus_open_user(&bus) < 0) return false;
    int has_owner = sd_bus_get_name_creds(bus, "org.b1air.Daemon", 0, nullptr) >= 0;
    sd_bus_unref(bus);
    return has_owner;
}

bool DaemonDBus::call_lock() {
    sd_bus *bus = nullptr;
    if (sd_bus_open_user(&bus) < 0) return false;
    int r = sd_bus_call_method(bus, "org.b1air.Daemon", "/org/b1air/Daemon", "org.b1air.Daemon", "Lock", nullptr, nullptr, "");
    sd_bus_unref(bus);
    return r >= 0;
}

bool DaemonDBus::call_reload() {
    sd_bus *bus = nullptr;
    if (sd_bus_open_user(&bus) < 0) return false;
    int r = sd_bus_call_method(bus, "org.b1air.Daemon", "/org/b1air/Daemon", "org.b1air.Daemon", "Reload", nullptr, nullptr, "");
    sd_bus_unref(bus);
    return r >= 0;
}

bool DaemonDBus::call_volume_up(int step) {
    sd_bus *bus = nullptr;
    if (sd_bus_open_user(&bus) < 0) return false;
    int r = sd_bus_call_method(bus, "org.b1air.Daemon", "/org/b1air/Daemon", "org.b1air.Daemon", "VolumeUp", nullptr, nullptr, "i", step);
    sd_bus_unref(bus);
    return r >= 0;
}

bool DaemonDBus::call_volume_down(int step) {
    sd_bus *bus = nullptr;
    if (sd_bus_open_user(&bus) < 0) return false;
    int r = sd_bus_call_method(bus, "org.b1air.Daemon", "/org/b1air/Daemon", "org.b1air.Daemon", "VolumeDown", nullptr, nullptr, "i", step);
    sd_bus_unref(bus);
    return r >= 0;
}

bool DaemonDBus::call_volume_mute() {
    sd_bus *bus = nullptr;
    if (sd_bus_open_user(&bus) < 0) return false;
    int r = sd_bus_call_method(bus, "org.b1air.Daemon", "/org/b1air/Daemon", "org.b1air.Daemon", "ToggleMute", nullptr, nullptr, "");
    sd_bus_unref(bus);
    return r >= 0;
}

bool DaemonDBus::call_brightness_up(int step) {
    sd_bus *bus = nullptr;
    if (sd_bus_open_user(&bus) < 0) return false;
    int r = sd_bus_call_method(bus, "org.b1air.Daemon", "/org/b1air/Daemon", "org.b1air.Daemon", "BrightnessUp", nullptr, nullptr, "i", step);
    sd_bus_unref(bus);
    return r >= 0;
}

bool DaemonDBus::call_brightness_down(int step) {
    sd_bus *bus = nullptr;
    if (sd_bus_open_user(&bus) < 0) return false;
    int r = sd_bus_call_method(bus, "org.b1air.Daemon", "/org/b1air/Daemon", "org.b1air.Daemon", "BrightnessDown", nullptr, nullptr, "i", step);
    sd_bus_unref(bus);
    return r >= 0;
}

bool DaemonDBus::call_brightness_set(int pct) {
    sd_bus *bus = nullptr;
    if (sd_bus_open_user(&bus) < 0) return false;
    int r = sd_bus_call_method(bus, "org.b1air.Daemon", "/org/b1air/Daemon", "org.b1air.Daemon", "BrightnessSet", nullptr, nullptr, "i", pct);
    sd_bus_unref(bus);
    return r >= 0;
}

bool DaemonDBus::call_game_mode(bool enabled) {
    sd_bus *bus = nullptr;
    if (sd_bus_open_user(&bus) < 0) return false;
    int r = sd_bus_call_method(bus, "org.b1air.Daemon", "/org/b1air/Daemon", "org.b1air.Daemon", "SetGameMode", nullptr, nullptr, "b", enabled ? 1 : 0);
    sd_bus_unref(bus);
    return r >= 0;
}

bool DaemonDBus::call_capture(const std::string& mode) {
    sd_bus *bus = nullptr;
    if (sd_bus_open_user(&bus) < 0) return false;
    int r = sd_bus_call_method(bus, "org.b1air.Daemon", "/org/b1air/Daemon", "org.b1air.Daemon", "Capture", nullptr, nullptr, "s", mode.c_str());
    sd_bus_unref(bus);
    return r >= 0;
}

bool DaemonDBus::call_power(const std::string& action) {
    sd_bus *bus = nullptr;
    if (sd_bus_open_user(&bus) < 0) return false;
    int r = sd_bus_call_method(bus, "org.b1air.Daemon", "/org/b1air/Daemon", "org.b1air.Daemon", "Power", nullptr, nullptr, "s", action.c_str());
    sd_bus_unref(bus);
    return r >= 0;
}

std::string DaemonDBus::call_get_stats(const std::string& date) {
    sd_bus *bus = nullptr;
    if (sd_bus_open_user(&bus) < 0) return "{}";
    sd_bus_message *reply = nullptr;
    sd_bus_error err = SD_BUS_ERROR_NULL;
    int r = sd_bus_call_method(bus, "org.b1air.Daemon", "/org/b1air/Daemon", "org.b1air.Daemon", "GetStats", &err, &reply, "s", date.c_str());
    std::string result = "{}";
    if (r >= 0 && reply) {
        const char *s = nullptr;
        if (sd_bus_message_read(reply, "s", &s) >= 0 && s) {
            result = s;
        }
        sd_bus_message_unref(reply);
    }
    sd_bus_error_free(&err);
    sd_bus_unref(bus);
    return result;
}

} // namespace b1air
