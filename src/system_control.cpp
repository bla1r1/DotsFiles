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

namespace b1air {

static const char* STATE_FILE = "/tmp/sway-game-mode.state";

static bool is_game_mode_active() {
    return (access(STATE_FILE, F_OK) == 0);
}

bool SystemControl::enable_game_mode() {
    SwayIPC ipc;
    if (ipc.connect()) {
        // Send batch IPC command to SwayFX in one packet
        ipc.send_command(0, "blur disable; shadows disable; corner_radius 0; default_border pixel 0; output * adaptive_sync on");
    }

    // Performance CPU power profile
    std::system("powerprofilesctl set performance 2>/dev/null || true");
    std::system("pw-metadata -n settings 0 clock.force-quantum 256 2>/dev/null || true");
    std::system("killall -SIGUSR1 waybar 2>/dev/null || true");
    std::system("makoctl mode -a dnd 2>/dev/null || true");

    // Touch state file
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

} // namespace b1air
