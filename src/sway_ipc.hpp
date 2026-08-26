#pragma once
#include <string>
#include <vector>
#include <functional>
#include <cstdint>

namespace b1air {

struct WindowInfo {
    std::string app_class;
    std::string title;
    bool focused = false;
};

class SwayIPC {
public:
    SwayIPC();
    ~SwayIPC();

    bool connect();
    void disconnect();
    bool is_connected() const { return fd_ >= 0; }

    std::string send_command(uint32_t type, const std::string& payload = "");
    std::string get_tree();
    WindowInfo get_focused_window();

    // Event listener loop (subscribes to window and workspace events)
    using EventCallback = std::function<void(const std::string& event_type, const std::string& payload)>;
    bool subscribe_events(const std::vector<std::string>& events, EventCallback callback);

private:
    int fd_ = -1;
    std::string socket_path_;

    bool send_message(uint32_t type, const std::string& payload);
    bool read_message(uint32_t& out_type, std::string& out_payload);
    std::string find_socket_path();
};

} // namespace b1air
