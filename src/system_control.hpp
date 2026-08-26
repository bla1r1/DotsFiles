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

    // Waybar & Layout helpers
    static std::string get_layout_shorthand();
    static bool toggle_fullscreen();
    static std::string get_wifi_status_json();
    static std::string get_media_status_json();

    // Volume & Microphone controls
    static int get_volume();
    static bool volume_up(int step = 5);
    static bool volume_down(int step = 5);
    static bool volume_toggle_mute();
    static std::string get_mic_status();
    static bool mic_toggle();

    // Screen Brightness controls
    static bool brightness_available();
    static int brightness_get();
    static bool brightness_up(int step = 5);
    static bool brightness_down(int step = 5);
    static bool brightness_set(int pct);
};

} // namespace b1air
