#pragma once
#include <string>
#include <vector>

namespace b1air {

class SystemControl {
public:
    // Game Mode controls
    static bool enable_game_mode();
    static bool disable_game_mode();
    static bool toggle_game_mode();
    static std::string get_game_mode_status_json();

    // Power & Session management
    static bool lock_session(const std::string& mode = "auto"); // "auto", "quickshell", "swaylock"
    static bool run_swaylock();
    static bool run_quickshell_lock();
    static bool logout_session();
    static bool suspend_system();
    static bool reboot_system();
    static bool shutdown_system();

    // Multi-Monitor Layout Manager
    static bool monitors_restore();
    static bool monitors_apply(const std::string& layout_json);
    static bool monitors_save(const std::string& layout_json);

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

    // DDC/CI External Monitor Controls
    static std::string ddc_list_json(bool force_detect = false);
    static bool ddc_set(const std::string& id, int percent);
    static bool ddc_adjust_all(int step);
    static std::string ddc_get_waybar_json();
    static bool ddc_refresh();
    static bool ddc_dim();
    static bool ddc_undim();

    // Weather Forecast & Live Status
    static std::string weather_get_json(bool force = false);
    static std::string weather_get_current_info(const std::string& field = "current");

    // Equalizer & EasyEffects Controls
    static std::string eq_get_state_json();
    static bool eq_set_band(int band_idx, int val);
    static bool eq_set_preset(const std::string& preset);
    static bool eq_set_all(const std::vector<int>& bands);
    static bool eq_apply();

    // Media Cover Art & Palette Extraction
    static std::string media_get_info_json();

    // Diary & Notes
    static bool diary_open();

    // Calendar Schedule
    static std::string schedule_get_json();

    // Dotfiles Git & Maintenance
    static std::string dotfiles_status_json();
    static bool dotfiles_sync();
    static bool dotfiles_sys();

    // Advanced Screen Capture, Recording & QR Scanner
    static bool capture(const std::string& mode = "full", const std::string& geom = "", bool edit = false);
    static bool record_toggle(const std::string& geom = "", double desk_vol = 1.0, double mic_vol = 1.0, bool desk_mute = false, bool mic_mute = false, const std::string& mic_dev = "");
    static bool record_stop();
    static std::string scan_qr(const std::string& geom);

    // Keyboard Backlight controls
    static bool kbd_backlight_available();
    static int kbd_backlight_get();
    static bool kbd_backlight_inc(int step = 10);
    static bool kbd_backlight_dec(int step = 10);
    static bool kbd_backlight_set(int val);
    static bool kbd_backlight_off();

    // Wallpaper management
    static bool wallpaper_set(const std::string& filepath, const std::string& mode = "set");
    static bool wallpaper_random(const std::string& dir = "");
    static bool wallpaper_restore();

    // Night Light & Day/Night Ambiance
    static bool night_light_on(int temp = 4000);
    static bool night_light_off();
    static bool night_light_toggle();
    static bool night_light_auto();

    // System Updates & Waybar JSON
    static std::string get_updates_json(bool force = false);
    static bool launch_system_upgrade();

    // Terminal Themes
    static std::vector<std::string> term_theme_list();
    static bool term_theme_set(const std::string& theme);

    // Gamepad Idle Inhibitor
    static int run_gamepad_inhibit();

    // Desktop Reload
    static bool reload_desktop();
};

} // namespace b1air
