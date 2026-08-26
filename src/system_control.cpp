#include "system_control.hpp"
#include "sway_ipc.hpp"

#include <iostream>
#include <fstream>
#include <cstdlib>
#include <unistd.h>
#include <sys/stat.h>
#include <chrono>
#include <iomanip>
#include <sstream>
#include <algorithm>
#include <array>
#include <memory>
#include <random>
#include <vector>
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
bool SystemControl::lock_session() {
    const char* home = std::getenv("HOME");
    std::string lock_cmd = std::string(home ? home : "") + "/.config/sway/scripts/session/swaylock.sh &";
    return (std::system(lock_cmd.c_str()) == 0);
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

// ── Wi-Fi Status ─────────────────────────────────────────────────────────────
std::string SystemControl::get_wifi_status_json() {
    std::string radio = exec_cmd("nmcli -t -f WIFI general 2>/dev/null | head -n1");
    if (radio != "enabled") {
        return "{\"text\":\"󰤮\",\"class\":\"off\"}";
    }

    std::string line = exec_cmd("nmcli -t -f IN-USE,SIGNAL device wifi list 2>/dev/null | grep '^\\*' | head -n1");
    if (line.empty()) {
        return "{\"text\":\"󰤯\",\"class\":\"disconnected\"}";
    }

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

} // namespace b1air
