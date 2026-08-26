#include "system_control.hpp"
#include "sway_ipc.hpp"

#include <iostream>
#include <fstream>
#include <cstdlib>
#include <unistd.h>
#include <sys/stat.h>
#include <fcntl.h>
#include <chrono>
#include <iomanip>
#include <sstream>
#include <algorithm>
#include <array>
#include <memory>
#include <random>
#include <vector>
#include <thread>
#include <cstring>
#include <dirent.h>

namespace b1air {

static const char* STATE_FILE = "/tmp/sway-game-mode.state";

static bool is_game_mode_active() {
    return (access(STATE_FILE, F_OK) == 0);
}

// ── Helper to execute command and capture single line stdout ────────────────
static std::string exec_cmd(const std::string& cmd) {
    std::array<char, 256> buffer;
    std::string result;
    FILE* pipe = popen(cmd.c_str(), "r");
    if (!pipe) return "";
    while (fgets(buffer.data(), buffer.size(), pipe) != nullptr) {
        result += buffer.data();
    }
    pclose(pipe);
    // Trim trailing newline
    while (!result.empty() && (result.back() == '\n' || result.back() == '\r')) {
        result.pop_back();
    }
    return result;
}

static std::string exec_cmd_full(const std::string& cmd) {
    std::array<char, 4096> buffer;
    std::string result;
    FILE* pipe = popen(cmd.c_str(), "r");
    if (!pipe) return "";
    while (fgets(buffer.data(), buffer.size(), pipe) != nullptr) {
        result += buffer.data();
    }
    pclose(pipe);
    return result;
}

static std::string json_escape(const std::string& s) {
    std::string out;
    out.reserve(s.size());
    for (char c : s) {
        if (c == '"') out += "\\\"";
        else if (c == '\\') out += "\\\\";
        else if (c == '\b') out += "\\b";
        else if (c == '\f') out += "\\f";
        else if (c == '\n') out += "\\n";
        else if (c == '\r') out += "\\r";
        else if (c == '\t') out += "\\t";
        else out += c;
    }
    return out;
}

static std::string read_file_string(const std::string& path) {
    std::ifstream in(path);
    if (!in) return "";
    std::stringstream buffer;
    buffer << in.rdbuf();
    return buffer.str();
}

// ── Game Mode ────────────────────────────────────────────────────────────────
bool SystemControl::enable_game_mode() {
    SwayIPC ipc;
    if (ipc.connect()) {
        ipc.send_command(0, "blur disable; shadows disable; corner_radius 0; default_border pixel 0; output * adaptive_sync on");
    }

    std::system("powerprofilesctl set performance 2>/dev/null || true");
    std::system("pw-metadata -n settings 0 clock.force-quantum 256 2>/dev/null || true");
    std::system("killall -SIGUSR1 waybar 2>/dev/null || true");
    std::system("makoctl mode -a dnd 2>/dev/null || true");

    std::ofstream out(STATE_FILE);
    out << "1\n";
    out.close();

    std::system("notify-send -a 'Game Mode' -i 'input-gaming' 'Game Mode Enabled' 'Compositor effects disabled • Performance active' 2>/dev/null || true");
    return true;
}

bool SystemControl::disable_game_mode() {
    SwayIPC ipc;
    if (ipc.connect()) {
        ipc.send_command(0, "blur enable; shadows enable; corner_radius 10; default_border pixel 2; output * adaptive_sync off");
    }

    std::system("powerprofilesctl set balanced 2>/dev/null || true");
    std::system("pw-metadata -n settings 0 clock.force-quantum 0 2>/dev/null || true");
    std::system("killall -SIGUSR1 waybar 2>/dev/null || true");
    std::system("makoctl mode -r dnd 2>/dev/null || true");

    unlink(STATE_FILE);

    std::system("notify-send -a 'Game Mode' -i 'input-gaming' 'Game Mode Disabled' 'Standard desktop profile restored' 2>/dev/null || true");
    return true;
}

bool SystemControl::toggle_game_mode() {
    if (is_game_mode_active()) {
        return disable_game_mode();
    } else {
        return enable_game_mode();
    }
}

std::string SystemControl::get_game_mode_status_json() {
    return is_game_mode_active() ? "{\"enabled\":true}" : "{\"enabled\":false}";
}

// ── Session Control ──────────────────────────────────────────────────────────
bool SystemControl::run_quickshell_lock() {
    const char* home = std::getenv("HOME");
    std::string qs_lock = std::string(home ? home : "") + "/.config/quickshell/Lock.qml";
    if (access(qs_lock.c_str(), R_OK) != 0) {
        return false;
    }
    ddc_dim();
    std::string cmd = "quickshell -p '" + qs_lock + "'";
    int ret = std::system(cmd.c_str());
    ddc_undim();
    return (ret == 0);
}

bool SystemControl::run_swaylock() {
    if (std::system("pgrep -x swaylock >/dev/null 2>&1") == 0) return true;

    std::string help_text = exec_cmd_full("swaylock --help 2>&1");
    auto supports = [&](const std::string& flag) {
        return help_text.find(flag) != std::string::npos;
    };

    const char* home = std::getenv("HOME");
    std::string home_str = home ? home : "";
    std::string user_wp = home_str + "/.config/sway/wallpaper.jpg";
    std::string cache_wp = home_str + "/.cache/current_wallpaper.jpg";

    std::string cmd = "swaylock --ignore-empty-password --color '1a1b26' --font 'JetBrainsMono Nerd Font'";

    if (access("/var/cache/wallpaper/current.jpg", R_OK) == 0) {
        cmd += " --image '/var/cache/wallpaper/current.jpg' --scaling fill";
    } else if (access(cache_wp.c_str(), R_OK) == 0) {
        cmd += " --image '" + cache_wp + "' --scaling fill";
    } else if (access(user_wp.c_str(), R_OK) == 0) {
        cmd += " --image '" + user_wp + "' --scaling fill";
    }

    if (supports("--indicator-idle-visible")) cmd += " --indicator-idle-visible";
    if (supports("--indicator-radius")) cmd += " --indicator-radius 85";
    if (supports("--indicator-thickness")) cmd += " --indicator-thickness 6";
    if (supports("--ring-color")) cmd += " --ring-color '7aa2f7'";
    if (supports("--inside-color")) cmd += " --inside-color '16161ecc'";
    if (supports("--line-color")) cmd += " --line-color '00000000'";
    if (supports("--separator-color")) cmd += " --separator-color '00000000'";
    if (supports("--key-hl-color")) cmd += " --key-hl-color '7aa2f7'";
    if (supports("--bs-hl-color")) cmd += " --bs-hl-color 'f7768e'";
    if (supports("--text-color")) cmd += " --text-color 'c0caf5'";
    if (supports("--text-clear-color")) cmd += " --text-clear-color 'e0af68'";
    if (supports("--ring-ver-color")) cmd += " --ring-ver-color '9ece6a'";
    if (supports("--inside-ver-color")) cmd += " --inside-ver-color '16161ecc'";
    if (supports("--text-ver-color")) cmd += " --text-ver-color '9ece6a'";
    if (supports("--ring-wrong-color")) cmd += " --ring-wrong-color 'f7768e'";
    if (supports("--inside-wrong-color")) cmd += " --inside-wrong-color '16161ecc'";
    if (supports("--text-wrong-color")) cmd += " --text-wrong-color 'f7768e'";
    if (supports("--show-keyboard-layout")) cmd += " --show-keyboard-layout";
    if (supports("--layout-bg-color")) cmd += " --layout-bg-color '16161ecc'";
    if (supports("--layout-border-color")) cmd += " --layout-border-color '7aa2f7'";
    if (supports("--layout-text-color")) cmd += " --layout-text-color 'c0caf5'";

    if (supports("--screenshots")) cmd += " --screenshots";
    if (supports("--clock")) {
        cmd += " --clock";
        if (supports("--timestr")) cmd += " --timestr '%H:%M'";
        if (supports("--datestr")) cmd += " --datestr '%A, %B %d, %Y'";
    }
    if (supports("--effect-blur")) cmd += " --effect-blur 10x4";
    if (supports("--effect-dim")) cmd += " --effect-dim 0.20";
    if (supports("--effect-vignette")) cmd += " --effect-vignette 0.25:0.25";
    if (supports("--grace")) cmd += " --grace 1";
    if (supports("--fade-in")) cmd += " --fade-in 0.2";

    ddc_dim();
    int ret = std::system(cmd.c_str());
    ddc_undim();
    return (ret == 0);
}

bool SystemControl::lock_session(const std::string& mode) {
    if (mode == "swaylock") {
        return run_swaylock();
    }
    if (mode == "quickshell") {
        if (run_quickshell_lock()) return true;
        return run_swaylock();
    }
    if (run_quickshell_lock()) return true;
    return run_swaylock();
}

bool SystemControl::logout_session() {
    SwayIPC ipc;
    if (ipc.connect()) {
        ipc.send_command(0, "exit");
        return true;
    }
    return (std::system("swaymsg exit 2>/dev/null || loginctl terminate-session self") == 0);
}

bool SystemControl::suspend_system() {
    lock_session();
    return (std::system("systemctl suspend 2>/dev/null || loginctl suspend") == 0);
}

bool SystemControl::reboot_system() {
    return (std::system("systemctl reboot 2>/dev/null || loginctl reboot") == 0);
}

bool SystemControl::shutdown_system() {
    return (std::system("systemctl poweroff 2>/dev/null || loginctl poweroff") == 0);
}

// ── Multi-Monitor Layout Manager ─────────────────────────────────────────────
static std::string get_monitors_state_file() {
    const char* home = std::getenv("HOME");
    std::string state_dir = std::string(home ? home : "/tmp") + "/.config/sway/state";
    mkdir(state_dir.c_str(), 0755);
    return state_dir + "/monitors-layout.json";
}

bool SystemControl::monitors_save(const std::string& layout_json) {
    std::string path = get_monitors_state_file();
    std::ofstream out(path);
    if (!out) return false;
    out << layout_json << "\n";
    out.close();
    return true;
}

bool SystemControl::monitors_apply(const std::string& layout_json) {
    if (layout_json.empty() || layout_json == "[]") return false;

    SwayIPC ipc;
    if (!ipc.connect()) return false;

    size_t cur = 0;
    while ((cur = layout_json.find('{', cur)) != std::string::npos) {
        size_t end = layout_json.find('}', cur);
        if (end == std::string::npos) break;
        std::string chunk = layout_json.substr(cur, end - cur + 1);

        auto get_str = [&](const std::string& key) -> std::string {
            size_t p = chunk.find("\"" + key + "\"");
            if (p == std::string::npos) return "";
            size_t c = chunk.find(':', p + key.size() + 2);
            if (c == std::string::npos) return "";
            size_t q1 = chunk.find('"', c + 1);
            if (q1 == std::string::npos) return "";
            size_t q2 = chunk.find('"', q1 + 1);
            if (q2 == std::string::npos) return "";
            return chunk.substr(q1 + 1, q2 - q1 - 1);
        };

        auto get_num = [&](const std::string& key, double def) -> double {
            size_t p = chunk.find("\"" + key + "\"");
            if (p == std::string::npos) return def;
            size_t c = chunk.find(':', p + key.size() + 2);
            if (c == std::string::npos) return def;
            size_t s = chunk.find_first_of("0123456789-.", c + 1);
            if (s == std::string::npos) return def;
            size_t e = chunk.find_first_not_of("0123456789-.", s);
            std::string sub = (e == std::string::npos) ? chunk.substr(s) : chunk.substr(s, e - s);
            try { return std::stod(sub); } catch (...) { return def; }
        };

        std::string name = get_str("name");
        int resW = static_cast<int>(get_num("resW", 1920));
        int resH = static_cast<int>(get_num("resH", 1080));
        double rate = get_num("rate", 60);
        double scale = get_num("sysScale", 1.0);
        int x = static_cast<int>(get_num("x", 0));
        int y = static_cast<int>(get_num("y", 0));
        std::string transform = get_str("transform");

        if (!name.empty() && resW > 0 && resH > 0) {
            std::string mode_str = std::to_string(resW) + "x" + std::to_string(resH);
            if (rate > 0) {
                std::stringstream rss;
                rss << rate;
                mode_str += "@" + rss.str() + "Hz";
            }
            std::stringstream scss;
            scss << std::fixed << std::setprecision(2) << scale;

            std::string cmd = "output \"" + name + "\" mode \"" + mode_str + "\" position " + std::to_string(x) + " " + std::to_string(y) + " scale " + scss.str();
            ipc.send_command(0, cmd);

            if (!transform.empty() && transform != "normal") {
                ipc.send_command(0, "output \"" + name + "\" transform " + transform);
            }
        }

        cur = end + 1;
    }

    monitors_save(layout_json);
    return true;
}

bool SystemControl::monitors_restore() {
    SwayIPC ipc;
    if (!ipc.connect()) return false;

    std::string outputs_json = ipc.get_outputs();
    if (outputs_json.empty() || outputs_json == "[]") return false;

    std::string state_path = get_monitors_state_file();
    std::string saved_json = read_file_string(state_path);

    if (!saved_json.empty() && saved_json != "[]") {
        bool has_match = false;
        size_t cur = 0;
        while ((cur = outputs_json.find("\"name\":\"", cur)) != std::string::npos) {
            size_t end = outputs_json.find('"', cur + 8);
            if (end != std::string::npos) {
                std::string name = outputs_json.substr(cur + 8, end - (cur + 8));
                if (saved_json.find("\"name\":\"" + name + "\"") != std::string::npos) {
                    has_match = true;
                    break;
                }
            }
            cur += 8;
        }

        if (has_match) {
            return monitors_apply(saved_json);
        }
    }

    int x = 0;
    int ws = 1;
    size_t cur = 0;
    while ((cur = outputs_json.find('{', cur)) != std::string::npos) {
        size_t end = outputs_json.find('}', cur);
        if (end == std::string::npos) break;
        std::string chunk = outputs_json.substr(cur, end - cur + 1);

        size_t np = chunk.find("\"name\":\"");
        if (np != std::string::npos) {
            size_t ne = chunk.find('"', np + 8);
            if (ne != std::string::npos) {
                std::string name = chunk.substr(np + 8, ne - (np + 8));
                int width = 1920;
                double scale = 1.0;

                size_t wp = chunk.find("\"width\":");
                if (wp != std::string::npos) {
                    try { width = std::stoi(chunk.substr(wp + 8)); } catch (...) {}
                }
                size_t sp = chunk.find("\"scale\":");
                if (sp != std::string::npos) {
                    try { scale = std::stod(chunk.substr(sp + 8)); } catch (...) {}
                }
                if (scale <= 0) scale = 1.0;

                std::stringstream scss;
                scss << std::fixed << std::setprecision(2) << scale;
                std::string cmd = "output \"" + name + "\" position " + std::to_string(x) + " 0 scale " + scss.str();
                ipc.send_command(0, cmd);
                ipc.send_command(0, "workspace number " + std::to_string(ws) + " output \"" + name + "\"");

                x += static_cast<int>(width / scale);
                ws++;
            }
        }
        cur = end + 1;
    }

    return true;
}

// ── Screenshots ──────────────────────────────────────────────────────────────
bool SystemControl::capture_screenshot(const std::string& mode) {
    const char* home = std::getenv("HOME");
    std::string target_dir = std::string(home ? home : "/tmp") + "/Pictures/Screenshots";
    mkdir(target_dir.c_str(), 0755);

    auto now = std::chrono::system_clock::now();
    auto in_time_t = std::chrono::system_clock::to_time_t(now);
    std::stringstream ss;
    ss << std::put_time(std::localtime(&in_time_t), "%Y-%m-%d_%H-%M-%S");
    std::string timestamp = ss.str();
    std::string filepath = target_dir + "/screenshot_" + timestamp + ".png";

    std::string cmd;
    if (mode == "area") {
        cmd = "grim -g \"$(slurp)\" " + filepath + " && wl-copy < " + filepath;
    } else if (mode == "window") {
        cmd = "grim -g \"$(swaymsg -t get_tree | jq -j '.. | select(.focused?) | .rect | \"\\(.x),\\(.y) \\(.width)x\\(.height)\"')\" " + filepath + " && wl-copy < " + filepath;
    } else {
        cmd = "grim " + filepath + " && wl-copy < " + filepath;
    }

    cmd += " && notify-send -a 'Screenshot' -i '" + filepath + "' 'Screenshot Saved' '" + filepath + "'";
    return (std::system(cmd.c_str()) == 0);
}

// ── Fullscreen Toggle ────────────────────────────────────────────────────────
bool SystemControl::toggle_fullscreen() {
    SwayIPC ipc;
    if (!ipc.connect()) return false;
    return ipc.toggle_fullscreen();
}

// ── Waybar Layout Shorthand ──────────────────────────────────────────────────
std::string SystemControl::get_layout_shorthand() {
    SwayIPC ipc;
    if (!ipc.connect()) return "US";

    std::string inputs = ipc.get_inputs();
    if (inputs.empty()) return "US";

    size_t pos = inputs.find("\"xkb_active_layout_name\":");
    if (pos == std::string::npos) return "US";

    size_t start = inputs.find('"', pos + 25);
    if (start == std::string::npos) return "US";
    size_t end = inputs.find('"', start + 1);
    if (end == std::string::npos) return "US";

    std::string layout = inputs.substr(start + 1, end - start - 1);
    std::string lower = layout;
    std::transform(lower.begin(), lower.end(), lower.begin(), ::tolower);

    if (lower.find("ukrainian") != std::string::npos || lower.find("українська") != std::string::npos || lower == "ua" || lower == "uk") return "UA";
    if (lower.find("german") != std::string::npos || lower.find("deutsch") != std::string::npos || lower == "de") return "DE";
    if (lower.find("french") != std::string::npos || lower.find("français") != std::string::npos || lower == "fr") return "FR";
    if (lower.find("spanish") != std::string::npos || lower.find("español") != std::string::npos || lower == "es") return "ES";
    if (lower.find("polish") != std::string::npos || lower.find("polski") != std::string::npos || lower == "pl") return "PL";
    if (lower.find("italian") != std::string::npos || lower.find("italiano") != std::string::npos || lower == "it") return "IT";
    if (lower.find("russian") != std::string::npos || lower.find("русский") != std::string::npos || lower == "ru") return "RU";
    if (lower.find("english") != std::string::npos || lower == "us" || lower == "en") return "US";

    if (layout.size() >= 2 && layout.size() <= 3) {
        std::string upper = layout;
        std::transform(upper.begin(), upper.end(), upper.begin(), ::toupper);
        return upper;
    }

    return "US";
}

// ── Wi-Fi & Network Status ───────────────────────────────────────────────────
std::string SystemControl::get_wifi_status_json() {
    std::string radio = exec_cmd("nmcli -t -f WIFI general 2>/dev/null | head -n1");
    if (radio == "enabled") {
        std::string line = exec_cmd("nmcli -t -f IN-USE,SIGNAL device wifi list 2>/dev/null | grep '^\\*' | head -n1");
        if (!line.empty()) {
            size_t colon = line.find(':');
            std::string sig_str = (colon != std::string::npos) ? line.substr(colon + 1) : "0";
            int signal = 0;
            try { signal = std::stoi(sig_str); } catch (...) { signal = 0; }

            std::string icon = "󰤯";
            if (signal >= 80) icon = "󰤨";
            else if (signal >= 60) icon = "󰤥";
            else if (signal >= 40) icon = "󰤢";
            else if (signal >= 20) icon = "󰤟";

            return "{\"text\":\"" + icon + "  " + std::to_string(signal) + "%\",\"class\":\"connected\"}";
        }
    }

    // Check for active wired Ethernet (common in Virtual Machines)
    std::string wired = exec_cmd("nmcli -t -f TYPE,STATE device 2>/dev/null | grep -E '^ethernet:connected'");
    if (!wired.empty()) {
        return "{\"text\":\"󰈀 Wired\",\"class\":\"connected\"}";
    }

    if (radio != "enabled") {
        return "{\"text\":\"󰤮\",\"class\":\"off\"}";
    }

    return "{\"text\":\"󰤯\",\"class\":\"disconnected\"}";
}

// ── Media Player Status ──────────────────────────────────────────────────────
std::string SystemControl::get_media_status_json() {
    std::string output = exec_cmd("playerctl metadata --format '{{status}}\x1f{{artist}}\x1f{{title}}\x1f{{playerName}}' 2>/dev/null");
    if (output.empty()) {
        return "{\"text\":\"\",\"class\":\"hidden\",\"tooltip\":\"No active player\"}";
    }

    std::stringstream ss(output);
    std::string status, artist, title, player;
    std::getline(ss, status, '\x1f');
    std::getline(ss, artist, '\x1f');
    std::getline(ss, title, '\x1f');
    std::getline(ss, player, '\x1f');

    if (status != "Playing" && status != "Paused") {
        return "{\"text\":\"\",\"class\":\"hidden\",\"tooltip\":\"No active player\"}";
    }

    std::string label = title.empty() ? "Media" : title;
    if (!artist.empty()) label = artist + " - " + label;

    // Escape JSON string
    std::string safe_label;
    for (char c : label) {
        if (c == '"' || c == '\\') safe_label += '\\';
        else safe_label += c;
    }

    std::string cls = (status == "Playing") ? "playing" : "paused";
    return "{\"text\":\"" + safe_label + "\",\"class\":\"" + cls + "\",\"tooltip\":\"" + safe_label + "\"}";
}

// ── Volume & Microphone ──────────────────────────────────────────────────────
int SystemControl::get_volume() {
    std::string v = exec_cmd("pamixer --get-volume 2>/dev/null");
    try { return std::stoi(v); } catch (...) { return 0; }
}

bool SystemControl::volume_up(int step) {
    std::system(("pamixer -i " + std::to_string(step) + " 2>/dev/null").c_str());
    int vol = get_volume();
    std::string icon = (vol > 60) ? "audio-volume-high" : ((vol > 30) ? "audio-volume-medium" : "audio-volume-low");
    std::system(("notify-send -h string:x-canonical-private-synchronous:sys-notify -u low -i " + icon + " 'Volume: " + std::to_string(vol) + "%' 2>/dev/null || true").c_str());
    return true;
}

bool SystemControl::volume_down(int step) {
    std::system(("pamixer -d " + std::to_string(step) + " 2>/dev/null").c_str());
    int vol = get_volume();
    std::string icon = (vol > 60) ? "audio-volume-high" : ((vol > 30) ? "audio-volume-medium" : "audio-volume-low");
    std::system(("notify-send -h string:x-canonical-private-synchronous:sys-notify -u low -i " + icon + " 'Volume: " + std::to_string(vol) + "%' 2>/dev/null || true").c_str());
    return true;
}

bool SystemControl::volume_toggle_mute() {
    std::system("pamixer -t 2>/dev/null");
    std::string mute = exec_cmd("pamixer --get-mute 2>/dev/null");
    if (mute == "true") {
        std::system("notify-send -h string:x-canonical-private-synchronous:sys-notify -u low -i audio-volume-muted 'Volume Muted' 2>/dev/null || true");
    } else {
        int vol = get_volume();
        std::system(("notify-send -h string:x-canonical-private-synchronous:sys-notify -u low -i audio-volume-high 'Volume: " + std::to_string(vol) + "%' 2>/dev/null || true").c_str());
    }
    return true;
}

std::string SystemControl::get_mic_status() {
    std::string mute = exec_cmd("pamixer --default-source --get-mute 2>/dev/null");
    return (mute == "true") ? "muted" : "unmuted";
}

bool SystemControl::mic_toggle() {
    std::system("pamixer --default-source -t 2>/dev/null || wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle 2>/dev/null");
    std::string status = get_mic_status();
    if (status == "muted") {
        std::system("notify-send -h string:x-canonical-private-synchronous:sys-notify -u low -i microphone-sensitivity-muted 'Microphone Muted' 2>/dev/null || true");
    } else {
        std::system("notify-send -h string:x-canonical-private-synchronous:sys-notify -u low -i microphone-sensitivity-high 'Microphone Unmuted' 2>/dev/null || true");
    }
    return true;
}

// ── Screen Brightness ────────────────────────────────────────────────────────
bool SystemControl::brightness_available() {
    DIR* dir = opendir("/sys/class/backlight");
    if (!dir) return false;
    struct dirent* entry;
    bool found = false;
    while ((entry = readdir(dir)) != nullptr) {
        if (entry->d_name[0] != '.') {
            found = true;
            break;
        }
    }
    closedir(dir);
    return found;
}

int SystemControl::brightness_get() {
    std::string val = exec_cmd("brightnessctl -c backlight -m 2>/dev/null | awk -F, 'NR == 1 { gsub(\"%\", \"\", $4); print $4 }'");
    try { return std::stoi(val); } catch (...) { return 100; }
}

bool SystemControl::brightness_up(int step) {
    std::system(("brightnessctl -c backlight -e4 -n2 set " + std::to_string(step) + "%+ >/dev/null 2>&1 || true").c_str());
    int b = brightness_get();
    std::system(("notify-send -h string:x-canonical-private-synchronous:sys-notify -u low -i display-brightness 'Brightness: " + std::to_string(b) + "%' 2>/dev/null || true").c_str());
    return true;
}

bool SystemControl::brightness_down(int step) {
    std::system(("brightnessctl -c backlight -e4 -n2 set " + std::to_string(step) + "%- >/dev/null 2>&1 || true").c_str());
    int b = brightness_get();
    std::system(("notify-send -h string:x-canonical-private-synchronous:sys-notify -u low -i display-brightness 'Brightness: " + std::to_string(b) + "%' 2>/dev/null || true").c_str());
    return true;
}

bool SystemControl::brightness_set(int pct) {
    std::system(("brightnessctl -c backlight -e4 -n2 set " + std::to_string(pct) + "% >/dev/null 2>&1 || true").c_str());
    return true;
}

// ── DDC/CI External Monitor Controls ─────────────────────────────────────────
struct DdcDisplay {
    std::string id;
    std::string name;
};

static std::string get_sway_cache_dir() {
    const char* home = std::getenv("HOME");
    std::string dir = std::string(home ? home : "/tmp") + "/.cache/sway";
    mkdir(dir.c_str(), 0755);
    mkdir((dir + "/monitor-brightness-values").c_str(), 0755);
    return dir;
}

static std::vector<DdcDisplay> detect_ddc_displays(bool force = false) {
    std::string cache_dir = get_sway_cache_dir();
    std::string disp_cache = cache_dir + "/monitor-brightness-displays";
    std::vector<DdcDisplay> displays;

    bool cache_fresh = false;
    struct stat st;
    if (!force && stat(disp_cache.c_str(), &st) == 0) {
        auto now = std::chrono::system_clock::now();
        auto now_sec = std::chrono::duration_cast<std::chrono::seconds>(now.time_since_epoch()).count();
        int ttl = (st.st_size > 0) ? 45 : 10;
        if (now_sec - st.st_mtime < ttl) {
            cache_fresh = true;
        }
    }

    if (cache_fresh) {
        std::ifstream in(disp_cache);
        std::string line;
        while (std::getline(in, line)) {
            size_t tab = line.find('\t');
            if (tab != std::string::npos) {
                DdcDisplay d;
                d.id = line.substr(0, tab);
                d.name = line.substr(tab + 1);
                displays.push_back(d);
            }
        }
        if (!displays.empty() || st.st_size == 0) {
            return displays;
        }
    }

    std::string raw = exec_cmd_full("timeout 2s ddcutil detect --brief 2>/dev/null");
    std::istringstream stream(raw);
    std::string line, cur_display, cur_bus, cur_model;

    auto emit = [&]() {
        if (!cur_display.empty()) {
            DdcDisplay d;
            d.id = !cur_bus.empty() ? ("bus:" + cur_bus) : ("display:" + cur_display);
            d.name = !cur_model.empty() ? cur_model : ("Display " + cur_display);
            displays.push_back(d);
        }
        cur_display = "";
        cur_bus = "";
        cur_model = "";
    };

    while (std::getline(stream, line)) {
        while (!line.empty() && (line.back() == '\r' || line.back() == '\n' || line.back() == ' ')) line.pop_back();
        if (line.rfind("Display ", 0) == 0) {
            emit();
            cur_display = line.substr(8);
        } else if (line.find("I2C bus:") != std::string::npos) {
            size_t p = line.find("/dev/i2c-");
            if (p != std::string::npos) {
                size_t start = p + 9;
                size_t end = line.find_first_not_of("0123456789", start);
                cur_bus = (end == std::string::npos) ? line.substr(start) : line.substr(start, end - start);
            }
        } else if (line.find("Monitor:") != std::string::npos) {
            size_t p = line.find("Monitor:");
            size_t start = line.find_first_not_of(" \t", p + 8);
            if (start != std::string::npos) {
                cur_model = line.substr(start);
            }
        } else if (line.empty()) {
            emit();
        }
    }
    emit();

    std::ofstream out(disp_cache);
    for (const auto& d : displays) {
        out << d.id << "\t" << d.name << "\n";
    }
    out.close();

    return displays;
}

static int get_ddc_brightness_single(const std::string& id) {
    std::string cache_dir = get_sway_cache_dir();
    std::string safe_id = id;
    std::replace(safe_id.begin(), safe_id.end(), ':', '_');
    std::replace(safe_id.begin(), safe_id.end(), '/', '_');
    std::string val_cache = cache_dir + "/monitor-brightness-values/" + safe_id;

    std::string arg = (id.rfind("bus:", 0) == 0) ? ("--bus " + id.substr(4)) :
                      ((id.rfind("display:", 0) == 0) ? ("--display " + id.substr(8)) : ("--display " + id));

    std::string out = exec_cmd("timeout 2s ddcutil getvcp 10 " + arg + " --noverify 2>/dev/null | sed -n 's/.*current value = *\\([0-9]\\+\\).*/\\1/p'");
    if (!out.empty()) {
        try {
            int v = std::stoi(out);
            std::ofstream val_out(val_cache);
            val_out << v << "\n";
            val_out.close();
            return v;
        } catch (...) {}
    }

    std::ifstream in(val_cache);
    if (in) {
        int v = 50;
        in >> v;
        return v;
    }
    return 50;
}

std::string SystemControl::ddc_list_json(bool force_detect) {
    auto displays = detect_ddc_displays(force_detect);
    std::string json = "[";
    for (size_t i = 0; i < displays.size(); ++i) {
        int b = get_ddc_brightness_single(displays[i].id);
        json += "{\"id\":\"" + json_escape(displays[i].id) + "\",\"name\":\"" + json_escape(displays[i].name) + "\",\"type\":\"ddc\",\"brightness\":" + std::to_string(b) + "}";
        if (i + 1 < displays.size()) json += ",";
    }
    json += "]";
    return json;
}

bool SystemControl::ddc_set(const std::string& id, int percent) {
    percent = std::clamp(percent, 1, 100);
    std::string cache_dir = get_sway_cache_dir();
    std::string safe_id = id;
    std::replace(safe_id.begin(), safe_id.end(), ':', '_');
    std::replace(safe_id.begin(), safe_id.end(), '/', '_');
    std::string val_cache = cache_dir + "/monitor-brightness-values/" + safe_id;

    std::ofstream val_out(val_cache);
    val_out << percent << "\n";
    val_out.close();

    std::string arg = (id.rfind("bus:", 0) == 0) ? ("--bus " + id.substr(4)) :
                      ((id.rfind("display:", 0) == 0) ? ("--display " + id.substr(8)) : ("--display " + id));

    std::system(("timeout 2s ddcutil setvcp 10 " + std::to_string(percent) + " " + arg + " --noverify >/dev/null 2>&1 &").c_str());
    std::system("pkill -RTMIN+3 waybar 2>/dev/null || true");
    return true;
}

bool SystemControl::ddc_adjust_all(int step) {
    auto displays = detect_ddc_displays(false);
    for (const auto& d : displays) {
        int cur = get_ddc_brightness_single(d.id);
        int next = std::clamp(cur + step, 1, 100);
        ddc_set(d.id, next);
    }
    return true;
}

std::string SystemControl::ddc_get_waybar_json() {
    auto displays = detect_ddc_displays(false);
    if (displays.empty()) {
        return "{\"text\":\"\",\"tooltip\":\"No DDC brightness controls found\",\"class\":\"empty\"}";
    }

    int sum = 0;
    std::string tooltip;
    for (size_t i = 0; i < displays.size(); ++i) {
        int b = get_ddc_brightness_single(displays[i].id);
        sum += b;
        tooltip += displays[i].name + "  " + std::to_string(b) + "%";
        if (i + 1 < displays.size()) tooltip += "\\n";
    }
    int avg = sum / static_cast<int>(displays.size());
    return "{\"text\":\"󰃠  " + std::to_string(avg) + "%\",\"tooltip\":\"" + tooltip + "\",\"class\":\"active\"}";
}

bool SystemControl::ddc_refresh() {
    detect_ddc_displays(true);
    return true;
}

bool SystemControl::ddc_dim() {
    std::string cur = std::to_string(brightness_get());
    std::ofstream out("/tmp/b1air_brightness.saved");
    out << cur << "\n";
    out.close();

    std::system("brightnessctl -c backlight set 10% >/dev/null 2>&1 || true");
    std::system("ddcutil setvcp 10 10 --noverify >/dev/null 2>&1 || true");
    return true;
}

bool SystemControl::ddc_undim() {
    std::string saved = "100";
    std::ifstream in("/tmp/b1air_brightness.saved");
    if (in) {
        in >> saved;
        in.close();
    }
    std::system(("brightnessctl -c backlight set " + saved + "% >/dev/null 2>&1 || true").c_str());
    std::system("ddcutil setvcp 10 100 --noverify >/dev/null 2>&1 || true");
    unlink("/tmp/b1air_brightness.saved");
    return true;
}

// ── Weather Forecast & Live Status ───────────────────────────────────────────
static std::string get_dummy_weather_json() {
    auto now = std::chrono::system_clock::now();
    std::string json = "{\"forecast\":[";
    for (int i = 0; i < 5; ++i) {
        auto day_point = now + std::chrono::hours(24 * i);
        auto t = std::chrono::system_clock::to_time_t(day_point);
        struct tm* tm = std::localtime(&t);
        char day_short[16], day_full[32], date_str[32];
        std::strftime(day_short, sizeof(day_short), "%a", tm);
        std::strftime(day_full, sizeof(day_full), "%A", tm);
        std::strftime(date_str, sizeof(date_str), "%d %b", tm);

        json += "{\"id\":\"" + std::to_string(i) + "\",\"day\":\"" + day_short + "\",\"day_full\":\"" + day_full + "\",\"date\":\"" + date_str + "\",\"max\":\"0.0\",\"min\":\"0.0\",\"feels_like\":\"0.0\",\"wind\":\"0\",\"humidity\":\"0\",\"pop\":\"0\",\"icon\":\"\",\"hex\":\"#cdd6f4\",\"desc\":\"No API Key\",\"hourly\":[{\"time\":\"00:00\",\"temp\":\"0.0\",\"icon\":\"\",\"hex\":\"#cdd6f4\"}]}";
        if (i + 1 < 5) json += ",";
    }
    json += "]}";
    return json;
}

std::string SystemControl::weather_get_json(bool force) {
    const char* home = std::getenv("HOME");
    std::string home_str = home ? home : "/tmp";
    std::string cache_dir = home_str + "/.cache/quickshell/weather";
    mkdir(cache_dir.c_str(), 0755);
    std::string json_file = cache_dir + "/weather.json";

    struct stat st;
    if (!force && stat(json_file.c_str(), &st) == 0) {
        auto now = std::chrono::system_clock::now();
        auto now_sec = std::chrono::duration_cast<std::chrono::seconds>(now.time_since_epoch()).count();
        if (now_sec - st.st_mtime < 900 && st.st_size > 50) {
            std::string cached = read_file_string(json_file);
            if (!cached.empty()) return cached;
        }
    }

    std::string env_file = home_str + "/.config/quickshell/calendar/.env";
    std::string api_key = std::getenv("OPENWEATHER_KEY") ? std::getenv("OPENWEATHER_KEY") : "";
    std::string city_id = std::getenv("OPENWEATHER_CITY_ID") ? std::getenv("OPENWEATHER_CITY_ID") : "";
    std::string unit = std::getenv("OPENWEATHER_UNIT") ? std::getenv("OPENWEATHER_UNIT") : "metric";

    std::ifstream env_in(env_file);
    if (env_in) {
        std::string line;
        while (std::getline(env_in, line)) {
            if (line.empty() || line[0] == '#') continue;
            size_t eq = line.find('=');
            if (eq != std::string::npos) {
                std::string k = line.substr(0, eq);
                std::string v = line.substr(eq + 1);
                k.erase(std::remove_if(k.begin(), k.end(), ::isspace), k.end());
                while (!v.empty() && (v.back() == '\r' || v.back() == '\n' || v.back() == '"' || v.back() == '\'')) v.pop_back();
                while (!v.empty() && (v.front() == '"' || v.front() == '\'')) v.erase(v.begin());
                if (k == "OPENWEATHER_KEY") api_key = v;
                else if (k == "OPENWEATHER_CITY_ID") city_id = v;
                else if (k == "OPENWEATHER_UNIT") unit = v;
            }
        }
    }

    if (api_key.empty() || api_key == "Skipped" || api_key == "OPENWEATHER_KEY" || city_id.empty()) {
        std::string dummy = get_dummy_weather_json();
        std::ofstream out(json_file);
        out << dummy << "\n";
        out.close();
        return dummy;
    }

    std::string url = "http://api.openweathermap.org/data/2.5/forecast?APPID=" + api_key + "&id=" + city_id + "&units=" + unit;
    std::string raw = exec_cmd_full("curl -fsS --max-time 8 '" + url + "' 2>/dev/null");

    if (raw.empty() || raw.find("\"cod\":\"200\"") == std::string::npos) {
        std::string cached = read_file_string(json_file);
        if (!cached.empty()) return cached;
        return get_dummy_weather_json();
    }

    std::string transform_cmd = "jq -c '"
        "def weather_icon($code): if ($code == \"50d\" or $code == \"50n\") then \"\" elif $code == \"01d\" then \"\" elif $code == \"01n\" then \"\" elif ($code | test(\"^(02|03|04)[dn]$\")) then \"\" elif ($code | test(\"^(09|10)[dn]$\")) then \"\" elif ($code == \"11d\" or $code == \"11n\") then \"\" elif ($code == \"13d\" or $code == \"13n\") then \"\" else \"\" end; "
        "def weather_hex($code): if ($code == \"50d\" or $code == \"50n\") then \"#84afdb\" elif $code == \"01d\" then \"#f9e2af\" elif $code == \"01n\" then \"#cba6f7\" elif ($code | test(\"^(02|03|04)[dn]$\")) then \"#bac2de\" elif ($code | test(\"^(09|10)[dn]$\")) then \"#74c7ec\" elif $code == \"11d\" then \"#f9e2af\" elif ($code == \"13d\" or $code == \"13n\") then \"#cdd6f4\" else \"#cdd6f4\" end; "
        "def one_decimal: ((. * 10 | round) / 10 | tostring); "
        "def titlecase: split(\" \") | map(if length > 0 then (.[0:1] | ascii_upcase) + .[1:] else . end) | join(\" \"); "
        "def day_forecast($idx; $items): ($items[(($items | length) / 2 | floor)].weather[0].icon // \"04d\") as $code | { id: ($idx | tostring), day: ($items[0].dt | strftime(\"%a\")), day_full: ($items[0].dt | strftime(\"%A\")), date: ($items[0].dt | strftime(\"%d %b\")), max: ([$items[].main.temp_max] | max | one_decimal), min: ([$items[].main.temp_min] | min | one_decimal), feels_like: ([$items[].main.feels_like] | max | one_decimal), wind: ([$items[].wind.speed] | max | round | tostring), humidity: (([$items[].main.humidity] | add / length) | round | tostring), pop: (([$items[].pop] | max // 0) * 100 | floor | tostring), icon: weather_icon($code), hex: weather_hex($code), desc: (($items[(($items | length) / 2 | floor)].weather[0].description // \"Unknown\") | titlecase), hourly: [ $items[] | (.weather[0].icon // \"04d\") as $hour_code | { time: (.dt | strftime(\"%H:%M\")), temp: (.main.temp | one_decimal), icon: weather_icon($hour_code), hex: weather_hex($hour_code) } ] }; "
        ".list as $items | ($items | map(.dt_txt[0:10]) | unique | .[:5]) as $dates | { forecast: [ range(0; ($dates | length)) as $idx | $dates[$idx] as $date | day_forecast($idx; [$items[] | select(.dt_txt | startswith($date))]) ] }' << 'EOF'\n" + raw + "\nEOF";

    std::string formatted = exec_cmd_full(transform_cmd);
    if (formatted.find("\"forecast\":") != std::string::npos) {
        std::ofstream out(json_file);
        out << formatted << "\n";
        out.close();
        return formatted;
    }

    return get_dummy_weather_json();
}

std::string SystemControl::weather_get_current_info(const std::string& field) {
    std::string json = weather_get_json(false);

    auto now = std::chrono::system_clock::now();
    auto in_time_t = std::chrono::system_clock::to_time_t(now);
    struct tm* tm = std::localtime(&in_time_t);
    char buf[16];
    std::strftime(buf, sizeof(buf), "%H:%M", tm);
    std::string curr_time = buf;

    std::string cmd = "jq -r --arg ct \"" + curr_time + "\" '((.forecast[0].hourly | map(select(.time <= $ct)) | last) // .forecast[0].hourly[0]) | ";
    if (field == "icon" || field == "--current-icon") cmd += ".icon' << 'EOF'\n" + json + "\nEOF";
    else if (field == "temp" || field == "--current-temp") cmd += "(.temp + \"°C\")' << 'EOF'\n" + json + "\nEOF";
    else if (field == "hex" || field == "--current-hex") cmd += ".hex' << 'EOF'\n" + json + "\nEOF";
    else {
        cmd += "(.icon + \"\\n\" + .temp + \"°C\")' << 'EOF'\n" + json + "\nEOF";
    }

    return exec_cmd_full(cmd);
}

// ── Keyboard Backlight ───────────────────────────────────────────────────────
static std::string detect_kbd_device() {
    std::string dev = exec_cmd("brightnessctl -l 2>/dev/null | grep -o \"[^\']*kbd_backlight[^\']*\" | head -n1");
    return dev;
}

bool SystemControl::kbd_backlight_available() {
    std::string dev = detect_kbd_device();
    return !dev.empty();
}

int SystemControl::kbd_backlight_get() {
    std::string dev = detect_kbd_device();
    if (dev.empty()) return 0;
    std::string val = exec_cmd("brightnessctl -d '" + dev + "' -m 2>/dev/null | awk -F, 'NR == 1 { gsub(\"%\", \"\", $4); print $4 }'");
    try { return std::stoi(val); } catch (...) { return 0; }
}

bool SystemControl::kbd_backlight_inc(int step) {
    std::string dev = detect_kbd_device();
    if (dev.empty()) return false;
    std::system(("brightnessctl -d '" + dev + "' set " + std::to_string(step) + "%+ >/dev/null 2>&1 || true").c_str());
    int val = kbd_backlight_get();
    std::system(("notify-send -h string:x-canonical-private-synchronous:sys-notify-kbd -u low -i input-keyboard 'Keyboard Backlight: " + std::to_string(val) + "%' 2>/dev/null || true").c_str());
    std::system("pkill -RTMIN+2 waybar 2>/dev/null || true");
    return true;
}

bool SystemControl::kbd_backlight_dec(int step) {
    std::string dev = detect_kbd_device();
    if (dev.empty()) return false;
    std::system(("brightnessctl -d '" + dev + "' set " + std::to_string(step) + "%- >/dev/null 2>&1 || true").c_str());
    int val = kbd_backlight_get();
    std::system(("notify-send -h string:x-canonical-private-synchronous:sys-notify-kbd -u low -i input-keyboard 'Keyboard Backlight: " + std::to_string(val) + "%' 2>/dev/null || true").c_str());
    std::system("pkill -RTMIN+2 waybar 2>/dev/null || true");
    return true;
}

bool SystemControl::kbd_backlight_set(int val) {
    std::string dev = detect_kbd_device();
    if (dev.empty()) return false;
    std::system(("brightnessctl -d '" + dev + "' set " + std::to_string(val) + "% >/dev/null 2>&1 || true").c_str());
    std::system("pkill -RTMIN+2 waybar 2>/dev/null || true");
    return true;
}

bool SystemControl::kbd_backlight_off() {
    std::string dev = detect_kbd_device();
    if (dev.empty()) return false;
    std::system(("brightnessctl -d '" + dev + "' set 0 >/dev/null 2>&1 || true").c_str());
    std::system("notify-send -h string:x-canonical-private-synchronous:sys-notify-kbd -u low -i input-keyboard 'Keyboard Backlight: OFF' 2>/dev/null || true");
    std::system("pkill -RTMIN+2 waybar 2>/dev/null || true");
    return true;
}

// ── Wallpaper ────────────────────────────────────────────────────────────────
bool SystemControl::wallpaper_set(const std::string& filepath, const std::string& /*mode*/) {
    if (access(filepath.c_str(), R_OK) != 0) return false;

    const char* home = std::getenv("HOME");
    std::string cache_file = std::string(home ? home : "/tmp") + "/.cache/current_wallpaper.jpg";

    // Copy to user cache
    std::system(("cp -f '" + filepath + "' '" + cache_file + "' 2>/dev/null || true").c_str());
    // Copy to SDDM cache if writable
    std::system(("cp -f '" + filepath + "' /var/cache/wallpaper/current.jpg 2>/dev/null || true").c_str());

    // Apply to Sway
    SwayIPC ipc;
    if (ipc.connect()) {
        ipc.send_command(0, "output * bg '" + filepath + "' fill");
    } else {
        std::system("pkill -x swaybg 2>/dev/null || true");
        std::system(("swaybg -m fill -i '" + filepath + "' >/dev/null 2>&1 &").c_str());
    }

    return true;
}

bool SystemControl::wallpaper_random(const std::string& dir_arg) {
    const char* home = std::getenv("HOME");
    std::string target_dir = dir_arg.empty() ? (std::string(home ? home : "") + "/.wallpapers") : dir_arg;

    DIR* dir = opendir(target_dir.c_str());
    if (!dir) return false;

    std::vector<std::string> images;
    struct dirent* entry;
    while ((entry = readdir(dir)) != nullptr) {
        if (entry->d_name[0] == '.') continue;
        std::string name = entry->d_name;
        std::string lower = name;
        std::transform(lower.begin(), lower.end(), lower.begin(), ::tolower);
        if (lower.ends_with(".jpg") || lower.ends_with(".jpeg") || lower.ends_with(".png") || lower.ends_with(".webp")) {
            images.push_back(target_dir + "/" + name);
        }
    }
    closedir(dir);

    if (images.empty()) return false;

    std::random_device rd;
    std::mt19937 g(rd());
    std::uniform_int_distribution<size_t> dist(0, images.size() - 1);
    return wallpaper_set(images[dist(g)]);
}

bool SystemControl::wallpaper_restore() {
    const char* home = std::getenv("HOME");
    std::string cache_file = std::string(home ? home : "/tmp") + "/.cache/current_wallpaper.jpg";
    if (access(cache_file.c_str(), R_OK) == 0) {
        return wallpaper_set(cache_file, "restore");
    }
    return wallpaper_random();
}

// ── Night Light ──────────────────────────────────────────────────────────────
bool SystemControl::night_light_on(int temp) {
    std::system("pkill wlsunset 2>/dev/null || true");
    std::system(("wlsunset -t " + std::to_string(temp) + " >/dev/null 2>&1 &").c_str());
    std::system("notify-send -a 'Night Light' -i 'weather-clear-night' 'Night Light Enabled' 'Warm color temperature active' 2>/dev/null || true");
    return true;
}

bool SystemControl::night_light_off() {
    std::system("pkill wlsunset 2>/dev/null || true");
    std::system("notify-send -a 'Night Light' -i 'weather-clear' 'Night Light Disabled' 'Standard display colors restored' 2>/dev/null || true");
    return true;
}

bool SystemControl::night_light_toggle() {
    std::string check = exec_cmd("pgrep wlsunset");
    if (!check.empty()) {
        return night_light_off();
    } else {
        return night_light_on(4000);
    }
}

bool SystemControl::night_light_auto() {
    auto now = std::chrono::system_clock::now();
    auto in_time_t = std::chrono::system_clock::to_time_t(now);
    struct tm* tm = std::localtime(&in_time_t);
    int hour = tm->tm_hour;

    if (hour >= 20 || hour < 7) {
        return night_light_on(4000);
    } else {
        return night_light_off();
    }
}

// ── System Updates ───────────────────────────────────────────────────────────
std::string SystemControl::get_updates_json(bool /*force*/) {
    int arch_updates = 0;
    int aur_updates = 0;

    std::string arch_str = exec_cmd("checkupdates 2>/dev/null | wc -l");
    try { arch_updates = std::stoi(arch_str); } catch (...) { arch_updates = 0; }

    std::string aur_str = exec_cmd("yay -Qua 2>/dev/null | wc -l");
    try { aur_updates = std::stoi(aur_str); } catch (...) { aur_updates = 0; }

    int total = arch_updates + aur_updates;
    if (total == 0) {
        return "{\"text\":\"0\",\"alt\":\"0\",\"tooltip\":\"Packages are up to date\",\"class\":\"green\"}";
    }

    std::string cls = (total > 50) ? "red" : ((total > 0) ? "yellow" : "green");
    std::string tooltip = std::to_string(arch_updates) + " System | " + std::to_string(aur_updates) + " AUR";
    return "{\"text\":\"" + std::to_string(total) + "\",\"alt\":\"" + std::to_string(total) + "\",\"tooltip\":\"" + tooltip + "\",\"class\":\"" + cls + "\"}";
}

bool SystemControl::launch_system_upgrade() {
    return (std::system("kitty --title systemupdate bash -c 'yay -Syu; echo \"\nPress Enter to close...\"; read -r _' &") == 0);
}

// ── Terminal Themes ──────────────────────────────────────────────────────────
std::vector<std::string> SystemControl::term_theme_list() {
    std::vector<std::string> res;
    const char* home = std::getenv("HOME");
    std::string themes_dir = std::string(home ? home : "") + "/.config/kitty/themes";

    DIR* dir = opendir(themes_dir.c_str());
    if (!dir) return res;

    struct dirent* entry;
    while ((entry = readdir(dir)) != nullptr) {
        std::string name = entry->d_name;
        if (name.ends_with(".conf")) {
            res.push_back(name.substr(0, name.size() - 5));
        }
    }
    closedir(dir);
    return res;
}

bool SystemControl::term_theme_set(const std::string& theme) {
    const char* home = std::getenv("HOME");
    std::string conf_file = std::string(home ? home : "") + "/.config/kitty/kitty.conf";
    std::string theme_file = std::string(home ? home : "") + "/.config/kitty/themes/" + theme + ".conf";

    if (access(theme_file.c_str(), R_OK) != 0) {
        std::cerr << "Theme file not found: " << theme_file << "\n";
        return false;
    }

    std::string cmd = "sed -i -E 's|^include themes/.*|include themes/" + theme + ".conf|' '" + conf_file + "'";
    std::system(cmd.c_str());
    std::system("killall -SIGUSR1 kitty 2>/dev/null || true");
    std::cout << "✓ Kitty theme updated to '" << theme << "'\n";
    return true;
}

// ── Gamepad Idle Inhibitor ───────────────────────────────────────────────────
int SystemControl::run_gamepad_inhibit() {
    std::cout << "[b1air-gamepad] Monitoring joystick activity (/dev/input/js*)...\n";
    while (true) {
        DIR* dir = opendir("/dev/input");
        if (dir) {
            struct dirent* entry;
            while ((entry = readdir(dir)) != nullptr) {
                if (std::strncmp(entry->d_name, "js", 2) == 0) {
                    std::string js_path = std::string("/dev/input/") + entry->d_name;
                    int fd = open(js_path.c_str(), O_RDONLY | O_NONBLOCK);
                    if (fd >= 0) {
                        char buf[64];
                        ssize_t n = read(fd, buf, sizeof(buf));
                        close(fd);
                        if (n > 0) {
                            std::system("systemd-inhibit --what=idle --who='b1air-gamepad' --why='Gamepad Active' sleep 120 >/dev/null 2>&1 &");
                        }
                    }
                }
            }
            closedir(dir);
        }
        std::this_thread::sleep_for(std::chrono::seconds(2));
    }
    return 0;
}

// ── Desktop Reload ───────────────────────────────────────────────────────────
bool SystemControl::reload_desktop() {
    SwayIPC ipc;
    if (ipc.connect()) {
        ipc.send_command(0, "reload");
    } else {
        std::system("swaymsg reload 2>/dev/null || true");
    }

    std::system("qs -p ~/.config/quickshell/Main.qml ipc call main forceReload 2>/dev/null || true");
    std::system("killall -SIGUSR2 waybar 2>/dev/null || true");
    return true;
}

// ── Equalizer Controls ───────────────────────────────────────────────────────
static const char* EQ_STATE_FILE = "/tmp/eq_state.json";

static void ensure_default_eq_state() {
    if (access(EQ_STATE_FILE, F_OK) != 0) {
        std::ofstream out(EQ_STATE_FILE);
        out << "{\"b1\": 0, \"b2\": 0, \"b3\": 0, \"b4\": 0, \"b5\": 0, \"b6\": 0, \"b7\": 0, \"b8\": 0, \"b9\": 0, \"b10\": 0, \"preset\": \"Flat\", \"pending\": false}\n";
        out.close();
    }
}

std::string SystemControl::eq_get_state_json() {
    ensure_default_eq_state();
    std::string s = read_file_string(EQ_STATE_FILE);
    return s.empty() ? "{\"b1\":0,\"b2\":0,\"b3\":0,\"b4\":0,\"b5\":0,\"b6\":0,\"b7\":0,\"b8\":0,\"b9\":0,\"b10\":0,\"preset\":\"Flat\",\"pending\":false}" : s;
}

bool SystemControl::eq_apply() {
    ensure_default_eq_state();
    std::string cur_state = eq_get_state_json();

    // Extract b1..b10
    std::vector<double> gains(10, 0.0);
    for (int i = 1; i <= 10; ++i) {
        std::string key = "\"b" + std::to_string(i) + "\"";
        size_t p = cur_state.find(key);
        if (p != std::string::npos) {
            size_t colon = cur_state.find(':', p + key.size());
            if (colon != std::string::npos) {
                size_t s = cur_state.find_first_of("0123456789-.", colon + 1);
                if (s != std::string::npos) {
                    size_t e = cur_state.find_first_not_of("0123456789-.", s);
                    std::string val = (e == std::string::npos) ? cur_state.substr(s) : cur_state.substr(s, e - s);
                    try { gains[i - 1] = std::stod(val); } catch (...) {}
                }
            }
        }
    }

    // Set pending = false in EQ_STATE_FILE
    size_t pending_pos = cur_state.find("\"pending\":");
    if (pending_pos != std::string::npos) {
        size_t true_pos = cur_state.find("true", pending_pos);
        if (true_pos != std::string::npos && true_pos - pending_pos < 20) {
            cur_state.replace(true_pos, 4, "false");
            std::ofstream out(EQ_STATE_FILE);
            out << cur_state << "\n";
            out.close();
        }
    }

    const char* home = std::getenv("HOME");
    std::string home_str = home ? home : "/tmp";
    mkdir((home_str + "/.config").c_str(), 0755);
    mkdir((home_str + "/.config/easyeffects").c_str(), 0755);
    std::string preset_dir = home_str + "/.config/easyeffects/output";
    mkdir(preset_dir.c_str(), 0755);
    std::string preset_file = preset_dir + "/live_eq.json";

    // 32 bands generation
    const int freqs[32] = {32, 40, 50, 63, 80, 100, 125, 160, 200, 250, 315, 400, 500, 630, 800, 1000, 1250, 1600, 2000, 2500, 3150, 4000, 5000, 6300, 8000, 10000, 12500, 16000, 20000, 22000, 24000, 24000};
    const int slider_map[10] = {0, 3, 6, 9, 12, 15, 18, 21, 24, 27};

    std::stringstream bands_json;
    for (int i = 0; i < 32; ++i) {
        double gain = 0.0;
        for (int s = 0; s < 10; ++s) {
            if (i == slider_map[s]) {
                gain = gains[s];
                break;
            }
        }
        bands_json << "        \"band" << i << "\": {\"frequency\": " << freqs[i] << ".0, \"gain\": " << std::fixed << std::setprecision(1) << gain
                   << ", \"mode\": \"Bell\", \"mute\": false, \"q\": 1.0, \"solo\": false, \"width\": 1.0, \"slope\": \"x1\"}"
                   << (i + 1 < 32 ? ",\n" : "\n");
    }

    std::string bands_str = bands_json.str();
    std::string preset_content = "{\n  \"output\": {\n    \"blocklist\": [],\n    \"plugins_order\": [\"equalizer\"],\n    \"equalizer\": {\n      \"bypass\": false,\n      \"input-gain\": 0.0,\n      \"output-gain\": 0.0,\n      \"left\": {\n" + bands_str + "      },\n      \"right\": {\n" + bands_str + "      },\n      \"mode\": \"IIR\",\n      \"num-bands\": 32,\n      \"split-channels\": false\n    }\n  }\n}\n";

    std::ofstream out(preset_file);
    if (out) {
        out << preset_content;
        out.close();
        std::system("easyeffects -l live_eq >/dev/null 2>&1 &");
        return true;
    }
    return false;
}

bool SystemControl::eq_set_band(int band_idx, int val) {
    if (band_idx < 1 || band_idx > 10) return false;
    ensure_default_eq_state();
    std::string cur = eq_get_state_json();

    // Parse and update b1..b10
    std::vector<int> b(10, 0);
    for (int i = 1; i <= 10; ++i) {
        std::string key = "\"b" + std::to_string(i) + "\"";
        size_t p = cur.find(key);
        if (p != std::string::npos) {
            size_t colon = cur.find(':', p + key.size());
            if (colon != std::string::npos) {
                size_t s = cur.find_first_of("0123456789-", colon + 1);
                if (s != std::string::npos) {
                    try { b[i - 1] = std::stoi(cur.substr(s)); } catch (...) {}
                }
            }
        }
    }
    b[band_idx - 1] = val;

    std::stringstream out;
    out << "{\"b1\": " << b[0] << ", \"b2\": " << b[1] << ", \"b3\": " << b[2] << ", \"b4\": " << b[3] << ", \"b5\": " << b[4]
        << ", \"b6\": " << b[5] << ", \"b7\": " << b[6] << ", \"b8\": " << b[7] << ", \"b9\": " << b[8] << ", \"b10\": " << b[9]
        << ", \"preset\": \"Custom\", \"pending\": true}\n";

    std::ofstream ofs(EQ_STATE_FILE);
    if (ofs) {
        ofs << out.str();
        return true;
    }
    return false;
}

bool SystemControl::eq_set_preset(const std::string& preset) {
    std::vector<int> b = {0,0,0,0,0,0,0,0,0,0};
    if (preset == "Flat") b = {0, 0, 0, 0, 0, 0, 0, 0, 0, 0};
    else if (preset == "Bass") b = {5, 7, 5, 2, 1, 0, 0, 0, 1, 2};
    else if (preset == "Treble") b = {-2, -1, 0, 1, 2, 3, 4, 5, 6, 6};
    else if (preset == "Vocal") b = {-2, -1, 1, 3, 5, 5, 4, 2, 1, 0};
    else if (preset == "Pop") b = {2, 4, 2, 0, 1, 2, 4, 2, 1, 2};
    else if (preset == "Rock") b = {5, 4, 2, -1, -2, -1, 2, 4, 5, 6};
    else if (preset == "Jazz") b = {3, 3, 1, 1, 1, 1, 2, 1, 2, 3};
    else if (preset == "Classic") b = {0, 1, 2, 2, 2, 2, 1, 2, 3, 4};
    else b = {0, 0, 0, 0, 0, 0, 0, 0, 0, 0};

    std::stringstream out;
    out << "{\"b1\": " << b[0] << ", \"b2\": " << b[1] << ", \"b3\": " << b[2] << ", \"b4\": " << b[3] << ", \"b5\": " << b[4]
        << ", \"b6\": " << b[5] << ", \"b7\": " << b[6] << ", \"b8\": " << b[7] << ", \"b9\": " << b[8] << ", \"b10\": " << b[9]
        << ", \"preset\": \"" << preset << "\", \"pending\": false}\n";

    std::ofstream ofs(EQ_STATE_FILE);
    if (ofs) {
        ofs << out.str();
        ofs.close();
    }
    return eq_apply();
}

bool SystemControl::eq_set_all(const std::vector<int>& bands) {
    if (bands.size() < 10) return false;
    std::stringstream out;
    out << "{\"b1\": " << bands[0] << ", \"b2\": " << bands[1] << ", \"b3\": " << bands[2] << ", \"b4\": " << bands[3] << ", \"b5\": " << bands[4]
        << ", \"b6\": " << bands[5] << ", \"b7\": " << bands[6] << ", \"b8\": " << bands[7] << ", \"b9\": " << bands[8] << ", \"b10\": " << bands[9]
        << ", \"preset\": \"Custom\", \"pending\": false}\n";

    std::ofstream ofs(EQ_STATE_FILE);
    if (ofs) {
        ofs << out.str();
        ofs.close();
    }
    return eq_apply();
}

// ── Media Info & Cover Art Processing ────────────────────────────────────────
std::string SystemControl::media_get_info_json() {
    const char* home = std::getenv("HOME");
    std::string home_str = home ? home : "/tmp";
    std::string tmp_dir = home_str + "/.cache/sway/music";
    mkdir(tmp_dir.c_str(), 0755);

    std::string metadata = exec_cmd("playerctl metadata --format '{{status}}\x1f{{mpris:artUrl}}\x1f{{xesam:title}}\x1f{{xesam:artist}}\x1f{{mpris:length}}\x1f{{position}}\x1f{{playerName}}' 2>/dev/null");

    std::string placeholder = tmp_dir + "/placeholder_blank.png";
    if (access(placeholder.c_str(), R_OK) != 0) {
        std::system(("convert -size 500x500 xc:'#313244' '" + placeholder + "' 2>/dev/null || true").c_str());
    }

    std::string default_grad = "linear-gradient(45deg, #cba6f7, #89b4fa, #f38ba8, #cba6f7)";
    std::string default_text = "#cdd6f4";

    if (metadata.empty()) {
        return "{\"title\":\"Not Playing\",\"artist\":\"\",\"status\":\"Stopped\",\"length\":1,\"position\":0,\"lengthStr\":\"00:01\",\"positionStr\":\"00:00\",\"timeStr\":\"00:00 / 00:01\",\"percent\":0,\"source\":\"Offline\",\"playerName\":\"\",\"blur\":\"" + placeholder + "\",\"grad\":\"" + default_grad + "\",\"textColor\":\"" + default_text + "\",\"deviceIcon\":\"󰓃\",\"deviceName\":\"Speaker\",\"artUrl\":\"" + placeholder + "\"}";
    }

    std::stringstream ss(metadata);
    std::string status, raw_url, title, artist, len_str, pos_str, player_name;
    std::getline(ss, status, '\x1f');
    std::getline(ss, raw_url, '\x1f');
    std::getline(ss, title, '\x1f');
    std::getline(ss, artist, '\x1f');
    std::getline(ss, len_str, '\x1f');
    std::getline(ss, pos_str, '\x1f');
    std::getline(ss, player_name, '\x1f');

    if (status != "Playing" && status != "Paused") status = "Stopped";
    if (title.empty()) title = "Media";

    int64_t len_micro = 1000000;
    int64_t pos_micro = 0;
    try { if (!len_str.empty()) len_micro = std::stoll(len_str); } catch (...) {}
    try { if (!pos_str.empty()) pos_micro = std::stoll(pos_str); } catch (...) {}
    int len_sec = static_cast<int>(len_micro / 1000000);
    if (len_sec <= 0) len_sec = 1;
    int pos_sec = static_cast<int>(pos_micro / 1000000);
    if (pos_sec < 0) pos_sec = 0;
    if (pos_sec > len_sec) pos_sec = len_sec;
    int percent = (pos_sec * 100) / len_sec;

    char l_buf[16], p_buf[16];
    std::snprintf(l_buf, sizeof(l_buf), "%02d:%02d", len_sec / 60, len_sec % 60);
    std::snprintf(p_buf, sizeof(p_buf), "%02d:%02d", pos_sec / 60, pos_sec % 60);
    std::string length_str = l_buf;
    std::string position_str = p_buf;
    std::string time_str = position_str + " / " + length_str;

    // Detect device name
    std::string sink = exec_cmd("pactl get-default-sink 2>/dev/null");
    std::string dev_icon = "󰓃";
    std::string dev_name = "Speaker";
    if (sink.find("bluez") != std::string::npos) {
        dev_icon = "󰂯";
        dev_name = "Bluetooth";
    } else if (sink.find("usb") != std::string::npos) {
        dev_name = "USB Audio";
    } else if (sink.find("pci") != std::string::npos) {
        dev_name = "System";
    }

    // Cover art hashing and async processing
    std::hash<std::string> hasher;
    std::string track_key = title + "-" + artist;
    std::string hash_str = std::to_string(hasher(track_key));
    std::string final_art = tmp_dir + "/" + hash_str + "_art.jpg";
    std::string blur_path = tmp_dir + "/" + hash_str + "_blur.png";
    std::string color_path = tmp_dir + "/" + hash_str + "_grad.txt";
    std::string text_path = tmp_dir + "/" + hash_str + "_text.txt";

    std::string display_art = placeholder;
    std::string display_blur = placeholder;
    std::string display_grad = default_grad;
    std::string display_text = default_text;

    if (access(final_art.c_str(), R_OK) == 0) {
        display_art = final_art;
        if (access(blur_path.c_str(), R_OK) == 0) display_blur = blur_path;
        std::string g = read_file_string(color_path);
        if (!g.empty()) {
            while (!g.empty() && (g.back() == '\n' || g.back() == '\r')) g.pop_back();
            display_grad = g;
        }
        std::string txt = read_file_string(text_path);
        if (!txt.empty()) {
            while (!txt.empty() && (txt.back() == '\n' || txt.back() == '\r')) txt.pop_back();
            display_text = txt;
        }
    } else if (!raw_url.empty()) {
        // Spawn async processor
        std::thread([=]() {
            if (raw_url.rfind("http", 0) == 0) {
                std::system(("curl -s -L --max-time 10 -o '" + final_art + "' '" + raw_url + "' || cp '" + placeholder + "' '" + final_art + "'").c_str());
            } else {
                std::string clean = (raw_url.rfind("file://", 0) == 0) ? raw_url.substr(7) : raw_url;
                std::system(("cp '" + clean + "' '" + final_art + "' 2>/dev/null || cp '" + placeholder + "' '" + final_art + "'").c_str());
            }
            std::system(("convert '" + final_art + "' -blur 0x20 -brightness-contrast -30x-10 '" + blur_path + "' 2>/dev/null || cp '" + final_art + "' '" + blur_path + "'").c_str());
            std::string colors = exec_cmd("convert '" + final_art + "' -resize 50x50 -alpha off +dither -quantize RGB -colors 3 -depth 8 -format '%c' histogram:info: 2>/dev/null | grep -E -o '#[0-9A-Fa-f]{6}' | head -n 3 | tr '\\n' ' '");
            std::stringstream css(colors);
            std::string c1, c2, c3;
            css >> c1 >> c2 >> c3;
            if (c1.empty()) c1 = "#cba6f7";
            if (c2.empty()) c2 = c1;
            if (c3.empty()) c3 = c1;
            std::ofstream gout(color_path);
            gout << "linear-gradient(45deg, " << c1 << ", " << c2 << ", " << c3 << ", " << c1 << ")\n";
            gout.close();
            std::ofstream tout(text_path);
            tout << "#cdd6f4\n";
            tout.close();
        }).detach();
    }

    return "{\"title\":\"" + json_escape(title) + "\",\"artist\":\"" + json_escape(artist) + "\",\"status\":\"" + status + "\",\"length\":" + std::to_string(len_sec) + ",\"position\":" + std::to_string(pos_sec) + ",\"lengthStr\":\"" + length_str + "\",\"positionStr\":\"" + position_str + "\",\"timeStr\":\"" + time_str + "\",\"percent\":" + std::to_string(percent) + ",\"source\":\"" + json_escape(player_name) + "\",\"playerName\":\"" + json_escape(player_name) + "\",\"blur\":\"" + json_escape(display_blur) + "\",\"grad\":\"" + json_escape(display_grad) + "\",\"textColor\":\"" + json_escape(display_text) + "\",\"deviceIcon\":\"" + dev_icon + "\",\"deviceName\":\"" + json_escape(dev_name) + "\",\"artUrl\":\"" + json_escape(display_art) + "\"}";
}

// ── Diary & Obsidian Notes ───────────────────────────────────────────────────
bool SystemControl::diary_open() {
    const char* home = std::getenv("HOME");
    std::string vault_dir = std::string(home ? home : "/tmp") + "/Life/Obsidian";

    auto now = std::chrono::system_clock::now();
    auto in_time_t = std::chrono::system_clock::to_time_t(now);
    struct tm* tm = std::localtime(&in_time_t);
    char year[16], day[16], month[16];
    std::strftime(year, sizeof(year), "%Y", tm);
    std::strftime(day, sizeof(day), "%d", tm);
    std::strftime(month, sizeof(month), "%m", tm);

    std::string filename = std::string(day) + "." + month;
    std::string diary_year_dir = vault_dir + "/Diary/" + year;
    mkdir(vault_dir.c_str(), 0755);
    mkdir((vault_dir + "/Diary").c_str(), 0755);
    mkdir(diary_year_dir.c_str(), 0755);

    std::string note_file = diary_year_dir + "/" + filename + ".md";
    if (access(note_file.c_str(), F_OK) != 0) {
        std::ofstream out(note_file);
        out << "#diary\n\n";
        out.close();
    }

    std::string contents_file = vault_dir + "/Diary/Contents.md";
    std::string contents = read_file_string(contents_file);
    std::string link_entry = "[[" + filename + "]]";

    if (contents.empty()) {
        std::ofstream out(contents_file);
        out << "## " << year << "\n- " << link_entry << "\n";
        out.close();
    } else if (contents.find(link_entry) == std::string::npos) {
        std::string year_header = "## " + std::string(year);
        size_t ypos = contents.find(year_header);
        if (ypos != std::string::npos) {
            size_t next_line = contents.find('\n', ypos);
            if (next_line != std::string::npos) {
                contents.insert(next_line + 1, "- " + link_entry + "\n");
            } else {
                contents += "\n- " + link_entry + "\n";
            }
        } else {
            contents += "\n## " + std::string(year) + "\n- " + link_entry + "\n";
        }
        std::ofstream out(contents_file);
        out << contents;
        out.close();
    }

    std::string uri = "obsidian://open?vault=Obsidian&file=Diary/" + std::string(year) + "/" + filename;
    std::string cmd = "xdg-open '" + uri + "' >/dev/null 2>&1 &";
    return (std::system(cmd.c_str()) == 0);
}

// ── Calendar Schedule ────────────────────────────────────────────────────────
std::string SystemControl::schedule_get_json() {
    const char* home = std::getenv("HOME");
    std::string cache_dir = std::string(home ? home : "/tmp") + "/.cache/quickshell/schedule";
    mkdir(cache_dir.c_str(), 0755);
    std::string cache_file = cache_dir + "/schedule.json";

    if (access(cache_file.c_str(), R_OK) == 0) {
        std::string content = read_file_string(cache_file);
        if (!content.empty()) return content;
    }

    std::string fallback = "{ \"header\": \"No Classes Scheduled\", \"lessons\": [], \"link\": \"\" }";
    std::ofstream out(cache_file);
    if (out) {
        out << fallback << "\n";
        out.close();
    }
    return fallback;
}

// ── Dotfiles Git Sync & Diff ─────────────────────────────────────────────────
static std::string find_dotfiles_repo() {
    const char* home = std::getenv("HOME");
    std::string home_str = home ? home : "";
    std::vector<std::string> candidates = {
        home_str + "/Documents/GitHub/DotsFiles",
        home_str + "/GitHub/DotsFiles",
        home_str + "/DotsFiles",
        home_str + "/.local/src/dotfiles"
    };
    for (const auto& c : candidates) {
        if (access((c + "/.git").c_str(), F_OK) == 0) {
            return c;
        }
    }
    return "";
}

std::string SystemControl::dotfiles_status_json() {
    std::string repo = find_dotfiles_repo();
    if (repo.empty()) {
        return "{\"ok\":false,\"error\":\"repo_not_found\"}";
    }

    std::system(("git -C '" + repo + "' fetch --quiet origin >/dev/null 2>&1 &").c_str());

    std::string branch = exec_cmd("git -C '" + repo + "' rev-parse --abbrev-ref HEAD 2>/dev/null");
    if (branch.empty()) branch = "main";
    std::string local_hash = exec_cmd("git -C '" + repo + "' rev-parse --short HEAD 2>/dev/null");
    std::string remote_ref = exec_cmd("git -C '" + repo + "' rev-parse --abbrev-ref --symbolic-full-name '@{upstream}' 2>/dev/null");
    if (remote_ref.empty()) remote_ref = "origin/main";
    std::string remote_hash = exec_cmd("git -C '" + repo + "' rev-parse --short '" + remote_ref + "' 2>/dev/null");

    bool update_available = (!remote_hash.empty() && local_hash != remote_hash);

    return "{\"ok\":true,\"repo_dir\":\"" + json_escape(repo) + "\",\"branch\":\"" + json_escape(branch) + "\",\"local_hash\":\"" + local_hash + "\",\"remote_hash\":\"" + remote_hash + "\",\"remote_ref\":\"" + json_escape(remote_ref) + "\",\"update_available\":" + (update_available ? "true" : "false") + "}";
}

bool SystemControl::dotfiles_sync() {
    std::string repo = find_dotfiles_repo();
    if (repo.empty()) return false;
    std::string cmd = "kitty --title dotfiles-update sh -lc 'git -C " + repo + " pull --ff-only && bash " + repo + "/update-dotfiles.sh --repo-dir " + repo + "; echo \"\\nPress Enter to close...\"; read -r _' &";
    return (std::system(cmd.c_str()) == 0);
}

bool SystemControl::dotfiles_sys() {
    std::string cmd = "kitty --title system-update sh -lc 'if command -v yay >/dev/null 2>&1; then yay -Syu; elif command -v paru >/dev/null 2>&1; then paru -Syu; else sudo pacman -Syu; fi; echo \"\\nPress Enter to close...\"; read -r _' &";
    return (std::system(cmd.c_str()) == 0);
}

// ── Screen Capture, Recording & QR Scanner ───────────────────────────────────
bool SystemControl::capture(const std::string& mode, const std::string& geom, bool edit) {
    const char* home = std::getenv("HOME");
    std::string target_dir = std::string(home ? home : "/tmp") + "/Pictures/Screenshots";
    mkdir(target_dir.c_str(), 0755);

    auto now = std::chrono::system_clock::now();
    auto in_time_t = std::chrono::system_clock::to_time_t(now);
    std::stringstream ss;
    ss << std::put_time(std::localtime(&in_time_t), "%Y-%m-%d_%H-%M-%S");
    std::string timestamp = ss.str();
    std::string filepath = target_dir + "/Screenshot_" + timestamp + ".png";

    std::string grim_cmd = "grim ";
    if (!geom.empty()) {
        grim_cmd += "-g \"" + geom + "\" ";
    } else if (mode == "area") {
        grim_cmd += "-g \"$(slurp)\" ";
    } else if (mode == "window") {
        grim_cmd += "-g \"$(swaymsg -t get_tree | jq -j '.. | select(.focused?) | .rect | \"\\(.x),\\(.y) \\(.width)x\\(.height)\"')\" ";
    }

    std::string cmd;
    if (edit) {
        cmd = grim_cmd + "- | GSK_RENDERER=gl satty --filename - --output-filename '" + filepath + "' --init-tool brush --copy-command wl-copy";
    } else {
        cmd = grim_cmd + "'" + filepath + "' && wl-copy < '" + filepath + "'";
    }

    cmd += " && notify-send -a 'Screenshot' -i '" + filepath + "' 'Screenshot Saved' '" + filepath + "'";
    return (std::system(cmd.c_str()) == 0);
}

bool SystemControl::record_stop() {
    const char* home = std::getenv("HOME");
    std::string cache_dir = std::string(home ? home : "/tmp") + "/.cache/qs_recording_state";
    std::string pid_file = cache_dir + "/rec_pid";

    if (access(pid_file.c_str(), R_OK) == 0) {
        std::string pid_str = read_file_string(pid_file);
        while (!pid_str.empty() && (pid_str.back() == '\n' || pid_str.back() == '\r')) pid_str.pop_back();

        if (!pid_str.empty() && pid_str != "0") {
            std::system(("kill -SIGINT " + pid_str + " 2>/dev/null || true").c_str());
            std::this_thread::sleep_for(std::chrono::milliseconds(500));
            std::system(("kill -9 " + pid_str + " 2>/dev/null || true").c_str());
        }

        std::string pw_modules = cache_dir + "/pw_modules";
        std::ifstream in(pw_modules);
        if (in) {
            std::string mod_id;
            while (std::getline(in, mod_id)) {
                if (!mod_id.empty()) {
                    std::system(("pactl unload-module " + mod_id + " 2>/dev/null || true").c_str());
                }
            }
            in.close();
            unlink(pw_modules.c_str());
        }

        unlink(pid_file.c_str());
        std::string final_file = read_file_string(cache_dir + "/final_file");
        unlink((cache_dir + "/final_file").c_str());
        unlink((cache_dir + "/processing.lock").c_str());

        std::system(("notify-send -a 'Screen Recorder' -i '" + final_file + "' '⏺ Recording Saved' '" + final_file + "' 2>/dev/null || true").c_str());
        return true;
    }
    return false;
}

bool SystemControl::record_toggle(const std::string& geom, double desk_vol, double mic_vol, bool desk_mute, bool mic_mute, const std::string& mic_dev) {
    const char* home = std::getenv("HOME");
    std::string cache_dir = std::string(home ? home : "/tmp") + "/.cache/qs_recording_state";
    mkdir(cache_dir.c_str(), 0755);
    std::string pid_file = cache_dir + "/rec_pid";

    if (access(pid_file.c_str(), R_OK) == 0) {
        return record_stop();
    }

    std::string record_dir = std::string(home ? home : "/tmp") + "/Videos/Recordings";
    mkdir(record_dir.c_str(), 0755);

    auto now = std::chrono::system_clock::now();
    auto in_time_t = std::chrono::system_clock::to_time_t(now);
    std::stringstream ss;
    ss << std::put_time(std::localtime(&in_time_t), "%Y-%m-%d-%H%M%S");
    std::string vid_file = record_dir + "/Recording_" + ss.str() + ".mp4";

    std::ofstream pw_out(cache_dir + "/pw_modules");
    std::string audio_mix;

    if (!desk_mute) {
        std::string desk_sink = exec_cmd("pactl get-default-sink 2>/dev/null");
        if (!desk_sink.empty()) {
            std::string sink_id = exec_cmd("pactl load-module module-null-sink sink_name=qs_virt_desk 2>/dev/null");
            std::string loop_id = exec_cmd("pactl load-module module-loopback source=" + desk_sink + ".monitor sink=qs_virt_desk 2>/dev/null");
            int vol_int = static_cast<int>(desk_vol * 65536);
            std::system(("pactl set-sink-volume qs_virt_desk " + std::to_string(vol_int) + " 2>/dev/null || true").c_str());
            if (pw_out) pw_out << sink_id << "\n" << loop_id << "\n";
            audio_mix += "qs_virt_desk.monitor|";
        }
    }

    if (!mic_mute) {
        std::string source = (!mic_dev.empty() && mic_dev != "null") ? mic_dev : exec_cmd("pactl get-default-source 2>/dev/null");
        if (!source.empty()) {
            std::string sink_id = exec_cmd("pactl load-module module-null-sink sink_name=qs_virt_mic 2>/dev/null");
            std::string loop_id = exec_cmd("pactl load-module module-loopback source=" + source + " sink=qs_virt_mic 2>/dev/null");
            int vol_int = static_cast<int>(mic_vol * 65536);
            std::system(("pactl set-sink-volume qs_virt_mic " + std::to_string(vol_int) + " 2>/dev/null || true").c_str());
            if (pw_out) pw_out << sink_id << "\n" << loop_id << "\n";
            audio_mix += "qs_virt_mic.monitor|";
        }
    }
    if (pw_out) pw_out.close();

    if (!audio_mix.empty() && audio_mix.back() == '|') audio_mix.pop_back();

    std::string gsr_cmd = "gpu-screen-recorder -w portal -c mp4 -f 60 ";
    if (!audio_mix.empty()) gsr_cmd += "-a '" + audio_mix + "' ";
    if (!geom.empty()) gsr_cmd += "-g '" + geom + "' ";
    gsr_cmd += "-o '" + vid_file + "' >/dev/null 2>&1 & echo $!";

    std::string pid = exec_cmd(gsr_cmd);
    std::ofstream pid_out(pid_file);
    pid_out << pid << "\n";
    pid_out.close();

    std::ofstream fin_out(cache_dir + "/final_file");
    fin_out << vid_file << "\n";
    fin_out.close();

    std::system("notify-send -a 'Screen Recorder' '⏺ Recording Started' 'Recording in progress...' 2>/dev/null || true");
    return true;
}

std::string SystemControl::scan_qr(const std::string& geom) {
    std::string tmp_img = "/dev/shm/qs_qr_temp_" + std::to_string(getpid()) + ".png";
    std::string grim_cmd = geom.empty() ? ("grim '" + tmp_img + "'") : ("grim -g \"" + geom + "\" '" + tmp_img + "'");
    std::system(grim_cmd.c_str());

    std::string xml = exec_cmd_full("zbarimg --xml -q '" + tmp_img + "' 2>/dev/null");
    unlink(tmp_img.c_str());

    std::string res_file = "/tmp/qs_qr_result";
    if (xml.empty()) {
        std::ofstream out(res_file);
        out << "0,0,0,0|||NOT_FOUND\n";
        out.close();
        return "0,0,0,0|||NOT_FOUND";
    }

    // Parse XML: extract <symbol> <data> and <polygon points="...">
    size_t sym_pos = xml.find("<symbol");
    if (sym_pos == std::string::npos) {
        std::ofstream out(res_file);
        out << "0,0,0,0|||NOT_FOUND\n";
        out.close();
        return "0,0,0,0|||NOT_FOUND";
    }

    std::string data_text;
    size_t data_pos = xml.find("<data", sym_pos);
    if (data_pos != std::string::npos) {
        size_t tag_end = xml.find('>', data_pos);
        size_t close_tag = xml.find("</data>", tag_end);
        if (tag_end != std::string::npos && close_tag != std::string::npos) {
            data_text = xml.substr(tag_end + 1, close_tag - (tag_end + 1));
        }
    }

    int min_x = 99999, min_y = 99999, max_x = 0, max_y = 0;
    size_t poly_pos = xml.find("points=\"", sym_pos);
    if (poly_pos != std::string::npos) {
        size_t q_end = xml.find('"', poly_pos + 8);
        if (q_end != std::string::npos) {
            std::string pts_str = xml.substr(poly_pos + 8, q_end - (poly_pos + 8));
            std::stringstream pss(pts_str);
            std::string pair;
            while (pss >> pair) {
                size_t comma = pair.find(',');
                if (comma != std::string::npos) {
                    try {
                        int x = std::stoi(pair.substr(0, comma));
                        int y = std::stoi(pair.substr(comma + 1));
                        min_x = std::min(min_x, x);
                        min_y = std::min(min_y, y);
                        max_x = std::max(max_x, x);
                        max_y = std::max(max_y, y);
                    } catch (...) {}
                }
            }
        }
    }

    if (min_x == 99999) { min_x = 0; min_y = 0; max_x = 0; max_y = 0; }
    int w = max_x - min_x;
    int h = max_y - min_y;

    // Clean data text
    std::string clean_data;
    for (char c : data_text) {
        if (c == '\n') clean_data += "\\n";
        else if (c != '\r') clean_data += c;
    }

    std::string result = std::to_string(min_x) + "," + std::to_string(min_y) + "," + std::to_string(w) + "," + std::to_string(h) + "|||" + clean_data;
    std::ofstream out(res_file);
    out << result << "\n";
    out.close();
    return result;
}

} // namespace b1air
