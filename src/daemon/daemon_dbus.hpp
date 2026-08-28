#pragma once

#include <systemd/sd-bus.h>
#include <string>

namespace b1air {

class DaemonDBus {
public:
    static int init_server(sd_bus **bus_out);
    static int run_service();
    static bool is_running();
    static bool call_lock();
    static bool call_reload();
    static bool call_volume_up(int step = 5);
    static bool call_volume_down(int step = 5);
    static bool call_volume_mute();
    static bool call_brightness_up(int step = 5);
    static bool call_brightness_down(int step = 5);
    static bool call_brightness_set(int pct);
    static bool call_game_mode(bool enabled);
    static bool call_capture(const std::string& mode);
    static bool call_power(const std::string& action);
    static std::string call_get_stats(const std::string& date);
};

} // namespace b1air
