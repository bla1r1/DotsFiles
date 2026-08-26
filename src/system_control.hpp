#pragma once
#include <string>

namespace b1air {

class SystemControl {
public:
    // Game Mode controls
    static bool enable_game_mode();
    static bool disable_game_mode();
    static bool toggle_game_mode();
    static std::string get_game_mode_status_json();

    // Power & Session management
    static bool lock_session();
    static bool logout_session();
    static bool suspend_system();
    static bool reboot_system();
    static bool shutdown_system();

    // Screenshot helper
    static bool capture_screenshot(const std::string& mode = "full"); // "full", "area", "window"
};

} // namespace b1air
