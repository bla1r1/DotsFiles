#pragma once
#include <string>
#include <vector>
#include <map>

namespace b1air {

struct DesktopSettings {
    // Keyboard & input
    std::string language = "us";
    std::string kbOptions = "grp:alt_shift_toggle,caps:escape";

    // Windows & Compositor
    int gapsInner = 8;
    int gapsOuter = 4;
    int borderWidth = 2;
    bool smartBorders = true;
    bool smartGaps = false;

    // Waybar
    int workspaceCount = 8;
    bool guideShortcut = true;
    bool topbarHelpIcon = false;
    std::string barPosition = "top";
    bool barShowWeather = true;
    bool barShowMedia = true;
    bool barShowTray = true;
    bool barClock24h = true;

    // Idle & Power
    int dimTimeout = 300;
    int lockTimeout = 600;
    int dpmsTimeout = 900;
    int suspendTimeout = 1200;

    // Autostart
    std::vector<std::string> autostartApps;
    std::vector<std::string> autostartCustom;

    // Monitors
    std::map<std::string, std::string> monitorWorkspaces;
};

class SettingsManager {
public:
    static std::string get_settings_filepath();
    static DesktopSettings load(const std::string& path = "");
    static bool save(const DesktopSettings& s, const std::string& path = "");

    static bool apply_to_sway(const DesktopSettings& s);
    static bool apply_from_file(const std::string& path = "");

    static std::string get_json_string(const std::string& key);

    // The struct above covers what apply_to_sway needs. These read anything
    // else in the file by name, for the settings only one caller cares about.
    static bool get_json_bool(const std::string& key, bool def);
    static int  get_json_int(const std::string& key, int def);
    static bool set_json_value(const std::string& key, const std::string& val);

    static int watch_and_apply(volatile int* running_flag);
};

} // namespace b1air
