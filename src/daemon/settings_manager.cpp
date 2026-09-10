#include "settings_manager.hpp"
#include "sway_ipc.hpp"

#include <iostream>
#include <fstream>
#include <sstream>
#include <cstdlib>
#include <unistd.h>
#include <sys/stat.h>
#if defined(__linux__)
#include <sys/inotify.h>
#endif
#include <poll.h>
#include <algorithm>
#include <cstring>
#include <cctype>
#include <thread>

namespace b1air {

std::string SettingsManager::get_settings_filepath() {
    const char* env_path = std::getenv("SWAY_SETTINGS_FILE");
    if (env_path && *env_path) return env_path;

    const char* home = std::getenv("HOME");
    return std::string(home ? home : "/tmp") + "/.config/sway/settings.json";
}

// ── Ultra-fast string-based JSON extractor helpers (zero regex overhead) ────
static std::string read_file_contents(const std::string& path) {
    std::ifstream in(path);
    if (!in) return "";
    std::stringstream buffer;
    buffer << in.rdbuf();
    return buffer.str();
}

static std::string find_json_string(const std::string& json, const std::string& key, const std::string& fallback) {
    std::string needle = "\"" + key + "\"";
    size_t pos = json.find(needle);
    if (pos == std::string::npos) return fallback;
    size_t colon = json.find(':', pos + needle.size());
    if (colon == std::string::npos) return fallback;
    size_t quote1 = json.find('"', colon + 1);
    if (quote1 == std::string::npos) return fallback;
    size_t quote2 = json.find('"', quote1 + 1);
    if (quote2 == std::string::npos) return fallback;
    return json.substr(quote1 + 1, quote2 - quote1 - 1);
}

static int find_json_int(const std::string& json, const std::string& key, int fallback) {
    std::string needle = "\"" + key + "\"";
    size_t pos = json.find(needle);
    if (pos == std::string::npos) return fallback;
    size_t colon = json.find(':', pos + needle.size());
    if (colon == std::string::npos) return fallback;
    size_t start = json.find_first_of("0123456789-", colon + 1);
    if (start == std::string::npos) return fallback;
    size_t end = json.find_first_not_of("0123456789", start + (json[start] == '-' ? 1 : 0));
    std::string num = (end == std::string::npos) ? json.substr(start) : json.substr(start, end - start);
    try { return std::stoi(num); } catch (...) { return fallback; }
}

static bool find_json_bool(const std::string& json, const std::string& key, bool fallback) {
    std::string needle = "\"" + key + "\"";
    size_t pos = json.find(needle);
    if (pos == std::string::npos) return fallback;
    size_t colon = json.find(':', pos + needle.size());
    if (colon == std::string::npos) return fallback;
    size_t t = json.find("true", colon + 1);
    size_t f = json.find("false", colon + 1);
    size_t comma = json.find_first_of(",}\n\r", colon + 1);
    if (t != std::string::npos && (comma == std::string::npos || t < comma)) return true;
    if (f != std::string::npos && (comma == std::string::npos || f < comma)) return false;
    return fallback;
}

static std::vector<std::string> find_json_string_array(const std::string& json, const std::string& key) {
    std::vector<std::string> res;
    std::string needle = "\"" + key + "\"";
    size_t pos = json.find(needle);
    if (pos == std::string::npos) return res;
    size_t arr_start = json.find('[', pos + needle.size());
    if (arr_start == std::string::npos) return res;
    size_t arr_end = json.find(']', arr_start);
    if (arr_end == std::string::npos) return res;

    size_t cur = arr_start + 1;
    while (cur < arr_end) {
        size_t q1 = json.find('"', cur);
        if (q1 == std::string::npos || q1 >= arr_end) break;
        size_t q2 = json.find('"', q1 + 1);
        if (q2 == std::string::npos || q2 > arr_end) break;
        res.push_back(json.substr(q1 + 1, q2 - q1 - 1));
        cur = q2 + 1;
    }
    return res;
}

static bool valid_sway_token(const std::string& value, size_t max_len = 256) {
    if (value.empty() || value.size() > max_len) return false;
    for (unsigned char c : value) {
        if (!(std::isalnum(c) || c == '_' || c == '-' || c == ',' || c == ':' || c == '+')) return false;
    }
    return true;
}

static std::string json_quote(const std::string& value) {
    std::string out = "\"";
    for (unsigned char c : value) {
        if (c == '\\') out += "\\\\";
        else if (c == '\"') out += "\\\"";
        else if (c == '\n') out += "\\n";
        else if (c == '\r') out += "\\r";
        else if (c == '\t') out += "\\t";
        else if (c < 0x20) return "";
        else out += static_cast<char>(c);
    }
    out += '"';
    return out;
}

DesktopSettings SettingsManager::load(const std::string& path_arg) {
    std::string path = path_arg.empty() ? get_settings_filepath() : path_arg;
    DesktopSettings s;

    std::string content = read_file_contents(path);
    if (content.empty()) {
        // Create default settings.json
        save(s, path);
        return s;
    }

    s.language = find_json_string(content, "language", s.language);
    s.kbOptions = find_json_string(content, "kbOptions", s.kbOptions);

    s.gapsInner = find_json_int(content, "gapsInner", s.gapsInner);
    s.gapsOuter = find_json_int(content, "gapsOuter", s.gapsOuter);
    s.borderWidth = find_json_int(content, "borderWidth", s.borderWidth);
    s.smartBorders = find_json_bool(content, "smartBorders", s.smartBorders);
    s.smartGaps = find_json_bool(content, "smartGaps", s.smartGaps);

    s.workspaceCount = find_json_int(content, "workspaceCount", s.workspaceCount);
    s.guideShortcut = find_json_bool(content, "guideShortcut", s.guideShortcut);
    s.topbarHelpIcon = find_json_bool(content, "topbarHelpIcon", s.topbarHelpIcon);
    s.barPosition = find_json_string(content, "barPosition", s.barPosition);
    s.barShowWeather = find_json_bool(content, "barShowWeather", s.barShowWeather);
    s.barShowMedia = find_json_bool(content, "barShowMedia", s.barShowMedia);
    s.barShowTray = find_json_bool(content, "barShowTray", s.barShowTray);
    s.barClock24h = find_json_bool(content, "barClock24h", s.barClock24h);

    s.dimTimeout = find_json_int(content, "dimTimeout", s.dimTimeout);
    s.lockTimeout = find_json_int(content, "lockTimeout", s.lockTimeout);
    s.dpmsTimeout = find_json_int(content, "dpmsTimeout", s.dpmsTimeout);
    s.suspendTimeout = find_json_int(content, "suspendTimeout", s.suspendTimeout);

    // Keep numeric settings within compositor/systemd-safe bounds before they
    // are interpolated into the trusted idle command below.
    s.gapsInner = std::clamp(s.gapsInner, 0, 100);
    s.gapsOuter = std::clamp(s.gapsOuter, 0, 100);
    s.borderWidth = std::clamp(s.borderWidth, 0, 20);
    s.workspaceCount = std::clamp(s.workspaceCount, 1, 100);
    s.dimTimeout = std::clamp(s.dimTimeout, 0, 86400);
    s.lockTimeout = std::clamp(s.lockTimeout, 0, 86400);
    s.dpmsTimeout = std::clamp(s.dpmsTimeout, 0, 86400);
    s.suspendTimeout = std::clamp(s.suspendTimeout, 0, 86400);

    s.autostartApps = find_json_string_array(content, "autostartApps");

    return s;
}

bool SettingsManager::save(const DesktopSettings& s, const std::string& path_arg) {
    std::string path = path_arg.empty() ? get_settings_filepath() : path_arg;

    size_t last_slash = path.rfind('/');
    if (last_slash != std::string::npos) {
        std::string dir = path.substr(0, last_slash);
        mkdir(dir.c_str(), 0755);
    }

    std::ofstream out(path);
    if (!out) return false;

    out << "{\n"
        << "  \"language\": " << json_quote(s.language) << ",\n"
        << "  \"kbOptions\": " << json_quote(s.kbOptions) << ",\n"
        << "  \"gapsInner\": " << s.gapsInner << ",\n"
        << "  \"gapsOuter\": " << s.gapsOuter << ",\n"
        << "  \"borderWidth\": " << s.borderWidth << ",\n"
        << "  \"smartBorders\": " << (s.smartBorders ? "true" : "false") << ",\n"
        << "  \"smartGaps\": " << (s.smartGaps ? "true" : "false") << ",\n"
        << "  \"workspaceCount\": " << s.workspaceCount << ",\n"
        << "  \"guideShortcut\": " << (s.guideShortcut ? "true" : "false") << ",\n"
        << "  \"topbarHelpIcon\": " << (s.topbarHelpIcon ? "true" : "false") << ",\n"
        << "  \"barPosition\": " << json_quote(s.barPosition) << ",\n"
        << "  \"barShowWeather\": " << (s.barShowWeather ? "true" : "false") << ",\n"
        << "  \"barShowMedia\": " << (s.barShowMedia ? "true" : "false") << ",\n"
        << "  \"barShowTray\": " << (s.barShowTray ? "true" : "false") << ",\n"
        << "  \"barClock24h\": " << (s.barClock24h ? "true" : "false") << ",\n"
        << "  \"dimTimeout\": " << s.dimTimeout << ",\n"
        << "  \"lockTimeout\": " << s.lockTimeout << ",\n"
        << "  \"dpmsTimeout\": " << s.dpmsTimeout << ",\n"
        << "  \"suspendTimeout\": " << s.suspendTimeout << ",\n"
        << "  \"autostartApps\": [";

    for (size_t i = 0; i < s.autostartApps.size(); ++i) {
        out << json_quote(s.autostartApps[i]) << (i + 1 < s.autostartApps.size() ? ", " : "");
    }

    out << "]\n}\n";
    out.close();
    return true;
}

// ── Apply Settings directly to Sway IPC & configs ─────────────────────────────
static void update_input_conf_file(const std::string& layout, const std::string& options) {
    if (!valid_sway_token(layout, 64) || !valid_sway_token(options, 256)) return;
    const char* home = std::getenv("HOME");
    std::string input_conf = std::string(home ? home : "") + "/.config/sway/conf.d/input.conf";

    std::ifstream in(input_conf);
    if (!in) return;

    std::string line;
    std::stringstream out;
    while (std::getline(in, line)) {
        if (line.find("xkb_layout") != std::string::npos) {
            out << "    xkb_layout  " << layout << "\n";
        } else if (line.find("xkb_options") != std::string::npos) {
            out << "    xkb_options " << options << "\n";
        } else {
            out << line << "\n";
        }
    }
    in.close();

    std::ofstream ofs(input_conf);
    if (ofs) {
        ofs << out.str();
    }
}

bool SettingsManager::apply_to_sway(const DesktopSettings& s) {
    SwayIPC ipc;
    if (ipc.connect()) {
        ipc.send_command(0, "gaps inner all set " + std::to_string(s.gapsInner));
        ipc.send_command(0, "gaps outer all set " + std::to_string(s.gapsOuter));
        ipc.send_command(0, "default_border pixel " + std::to_string(s.borderWidth));
        ipc.send_command(0, std::string("smart_borders ") + (s.smartBorders ? "on" : "off"));
        ipc.send_command(0, std::string("smart_gaps ") + (s.smartGaps ? "on" : "off"));

        for (const auto& [mon, ws] : s.monitorWorkspaces) {
            ipc.send_command(0, "workspace " + ws + " output " + mon);
        }
    }

    update_input_conf_file(s.language, s.kbOptions);

    // The native Quickshell bar observes settings through the shell reload;
    // there is no legacy Waybar process to signal.
    return true;
}

bool SettingsManager::apply_from_file(const std::string& path) {
    DesktopSettings s = load(path);
    return apply_to_sway(s);
}

std::string SettingsManager::get_json_string(const std::string& key) {
    std::string path = get_settings_filepath();
    std::string content = read_file_contents(path);
    return find_json_string(content, key, "");
}

bool SettingsManager::get_json_bool(const std::string& key, bool def) {
    return find_json_bool(read_file_contents(get_settings_filepath()), key, def);
}

int SettingsManager::get_json_int(const std::string& key, int def) {
    return find_json_int(read_file_contents(get_settings_filepath()), key, def);
}

bool SettingsManager::set_json_value(const std::string& key, const std::string& val) {
    if (key.empty() || key.size() > 128 || key.find('"') != std::string::npos) return false;
    const std::string quoted_val = json_quote(val);
    if (quoted_val.empty()) return false;
    std::string path = get_settings_filepath();
    std::string content = read_file_contents(path);
    if (content.empty()) content = "{}";

    std::string needle = "\"" + key + "\"";
    size_t pos = content.find(needle);
    if (pos != std::string::npos) {
        size_t colon = content.find(':', pos + needle.size());
        if (colon != std::string::npos) {
            size_t comma = content.find_first_of(",}", colon + 1);
            if (comma != std::string::npos) {
                std::string new_val = " " + quoted_val;
                content.replace(colon + 1, comma - (colon + 1), new_val);
            }
        }
    } else {
        // Insert before last closing brace
        size_t last_brace = content.rfind('}');
        if (last_brace != std::string::npos) {
            std::string entry = (last_brace > 1 && content[last_brace - 1] != '{' ? ",\n  \"" : "  \"") + key + "\": " + quoted_val + "\n";
            content.insert(last_brace, entry);
        }
    }

    std::ofstream ofs(path);
    if (ofs) {
        ofs << content;
        return true;
    }
    return false;
}

// ── Native inotify watcher ───────────────────────────────────────────────────
int SettingsManager::watch_and_apply(volatile int* running_flag) {
    std::string settings_file = get_settings_filepath();
    apply_from_file(settings_file);

#if defined(__linux__)
    size_t slash = settings_file.rfind('/');
    std::string dir_path = (slash != std::string::npos) ? settings_file.substr(0, slash) : ".";
    std::string file_name = (slash != std::string::npos) ? settings_file.substr(slash + 1) : settings_file;

    int fd = inotify_init1(IN_NONBLOCK | IN_CLOEXEC);
    if (fd < 0) {
        std::cerr << "[b1air-settings] inotify_init1 failed\n";
        return 1;
    }

    int wd = inotify_add_watch(fd, dir_path.c_str(), IN_CLOSE_WRITE | IN_MOVED_TO | IN_CREATE);
    if (wd < 0) {
        std::cerr << "[b1air-settings] Failed to watch directory: " << dir_path << "\n";
        close(fd);
        return 1;
    }

    std::cout << "[b1air-settings] Live inotify watcher started for " << settings_file << "\n";

    struct pollfd pfd;
    pfd.fd = fd;
    pfd.events = POLLIN;

    char buf[4096] __attribute__((aligned(__alignof__(struct inotify_event))));

    while (running_flag && *running_flag) {
        int ret = poll(&pfd, 1, 500); // 500ms timeout
        if (ret > 0 && (pfd.revents & POLLIN)) {
            ssize_t len = read(fd, buf, sizeof(buf));
            if (len > 0) {
                const struct inotify_event* event;
                for (char* ptr = buf; ptr < buf + len; ptr += sizeof(struct inotify_event) + event->len) {
                    event = (const struct inotify_event*)ptr;
                    if (event->len > 0 && std::string(event->name) == file_name) {
                        std::cout << "[b1air-settings] Detected change in " << file_name << ", applying settings instantly...\n";
                        apply_from_file(settings_file);
                    }
                }
            }
        }
    }

    inotify_rm_watch(fd, wd);
    close(fd);
#else
    while (running_flag && *running_flag) {
        std::this_thread::sleep_for(std::chrono::seconds(2));
    }
#endif
    return 0;
}

} // namespace b1air
