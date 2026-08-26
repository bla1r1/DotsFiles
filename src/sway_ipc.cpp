#include "sway_ipc.hpp"

#include <iostream>
#include <vector>
#include <cstring>
#include <cstdlib>
#include <unistd.h>
#include <sys/socket.h>
#include <sys/un.h>
#include <dirent.h>

namespace b1air {

static const char* I3_MAGIC = "i3-ipc";
static const size_t I3_MAGIC_LEN = 6;
static const size_t I3_HEADER_LEN = 14;

SwayIPC::SwayIPC() {
    socket_path_ = find_socket_path();
}

SwayIPC::~SwayIPC() {
    disconnect();
}

std::string SwayIPC::find_socket_path() {
    const char* env = std::getenv("SWAYSOCK");
    if (env && env[0] != '\0') {
        return std::string(env);
    }
    const char* i3_env = std::getenv("I3SOCK");
    if (i3_env && i3_env[0] != '\0') {
        return std::string(i3_env);
    }

    // Fallback: look in /run/user/<UID>/sway-ipc.*.sock
    uid_t uid = getuid();
    std::string user_run = "/run/user/" + std::to_string(uid);
    DIR* dir = opendir(user_run.c_str());
    if (dir) {
        struct dirent* entry;
        while ((entry = readdir(dir)) != nullptr) {
            if (std::strncmp(entry->d_name, "sway-ipc.", 9) == 0) {
                std::string res = user_run + "/" + entry->d_name;
                closedir(dir);
                return res;
            }
        }
        closedir(dir);
    }

    return "";
}

bool SwayIPC::connect() {
    if (fd_ >= 0) return true;
    if (socket_path_.empty()) {
        socket_path_ = find_socket_path();
        if (socket_path_.empty()) return false;
    }

    fd_ = ::socket(AF_UNIX, SOCK_STREAM, 0);
    if (fd_ < 0) return false;

    struct sockaddr_un addr;
    std::memset(&addr, 0, sizeof(addr));
    addr.sun_family = AF_UNIX;
    std::strncpy(addr.sun_path, socket_path_.c_str(), sizeof(addr.sun_path) - 1);

    if (::connect(fd_, (struct sockaddr*)&addr, sizeof(addr)) < 0) {
        ::close(fd_);
        fd_ = -1;
        return false;
    }

    return true;
}

void SwayIPC::disconnect() {
    if (fd_ >= 0) {
        ::close(fd_);
        fd_ = -1;
    }
}

bool SwayIPC::send_message(uint32_t type, const std::string& payload) {
    if (fd_ < 0 && !connect()) {
        return false;
    }

    uint32_t len = static_cast<uint32_t>(payload.size());
    std::vector<uint8_t> buffer(I3_HEADER_LEN + len);

    std::memcpy(buffer.data(), I3_MAGIC, I3_MAGIC_LEN);
    std::memcpy(buffer.data() + 6, &len, sizeof(len));
    std::memcpy(buffer.data() + 10, &type, sizeof(type));
    if (len > 0) {
        std::memcpy(buffer.data() + I3_HEADER_LEN, payload.data(), len);
    }

    size_t total = 0;
    while (total < buffer.size()) {
        ssize_t n = ::write(fd_, buffer.data() + total, buffer.size() - total);
        if (n <= 0) {
            disconnect();
            return false;
        }
        total += n;
    }

    return true;
}

bool SwayIPC::read_message(uint32_t& out_type, std::string& out_payload) {
    if (fd_ < 0) {
        return false;
    }

    uint8_t header[I3_HEADER_LEN];
    size_t total = 0;
    while (total < I3_HEADER_LEN) {
        ssize_t n = ::read(fd_, header + total, I3_HEADER_LEN - total);
        if (n <= 0) {
            disconnect();
            return false;
        }
        total += n;
    }

    if (std::memcmp(header, I3_MAGIC, I3_MAGIC_LEN) != 0) {
        disconnect();
        return false;
    }

    uint32_t len = 0;
    std::memcpy(&len, header + 6, sizeof(len));
    std::memcpy(&out_type, header + 10, sizeof(out_type));

    out_payload.resize(len);
    total = 0;
    while (total < len) {
        ssize_t n = ::read(fd_, &out_payload[total], len - total);
        if (n <= 0) {
            disconnect();
            return false;
        }
        total += n;
    }

    return true;
}

std::string SwayIPC::send_command(uint32_t type, const std::string& payload) {
    if (!send_message(type, payload)) {
        return "";
    }
    uint32_t resp_type = 0;
    std::string response;
    if (!read_message(resp_type, response)) {
        return "";
    }
    return response;
}

std::string SwayIPC::get_tree() {
    return send_command(4); // 4 = GET_TREE
}

std::string SwayIPC::get_inputs() {
    return send_command(100); // 100 = GET_INPUTS
}

std::string SwayIPC::get_outputs() {
    return send_command(3); // 3 = GET_OUTPUTS
}

// Quick helper to search for focused window in tree JSON
static bool parse_focused_node(const std::string& json, WindowInfo& out) {
    // Find `"focused":true` or `"focused": true`
    size_t f_pos = json.find("\"focused\":true");
    if (f_pos == std::string::npos) {
        f_pos = json.find("\"focused\": true");
    }
    if (f_pos == std::string::npos) {
        return false;
    }

    // Find enclosing node start
    size_t node_start = json.rfind('{', f_pos);
    size_t node_end = json.find('}', f_pos);
    if (node_start == std::string::npos || node_end == std::string::npos) {
        return false;
    }

    std::string chunk = json.substr(node_start, (node_end - node_start) + 300);

    auto extract_field = [](const std::string& s, const std::string& key) -> std::string {
        size_t kp = s.find("\"" + key + "\":");
        if (kp == std::string::npos) return "";
        size_t val_start = s.find_first_not_of(" \t\n\r", kp + key.size() + 3);
        if (val_start == std::string::npos) return "";
        if (s[val_start] == 'n') return ""; // null
        if (s[val_start] == '"') {
            size_t val_end = s.find('"', val_start + 1);
            if (val_end != std::string::npos) {
                return s.substr(val_start + 1, val_end - val_start - 1);
            }
        }
        return "";
    };

    std::string app_id = extract_field(chunk, "app_id");
    std::string name = extract_field(chunk, "name");
    
    // Check if XWayland class exists
    if (app_id.empty()) {
        size_t wp = chunk.find("\"window_properties\":");
        if (wp != std::string::npos) {
            std::string wp_chunk = chunk.substr(wp, 150);
            app_id = extract_field(wp_chunk, "class");
        }
    }

    // Fullscreen check
    size_t fs_pos = chunk.find("\"fullscreen_mode\":");
    if (fs_pos != std::string::npos) {
        size_t num_start = chunk.find_first_of("0123456789", fs_pos + 18);
        if (num_start != std::string::npos && chunk[num_start] > '0') {
            out.fullscreen = true;
        }
    }

    // Floating check
    if (chunk.find("\"floating\":\"auto_on\"") != std::string::npos ||
        chunk.find("\"floating\": \"auto_on\"") != std::string::npos ||
        chunk.find("\"floating\":\"user_on\"") != std::string::npos ||
        chunk.find("\"floating\": \"user_on\"") != std::string::npos) {
        out.floating = true;
    }

    // Rect dimensions for native autotiling
    size_t rect_pos = chunk.find("\"rect\":");
    if (rect_pos != std::string::npos) {
        size_t w_pos = chunk.find("\"width\":", rect_pos);
        if (w_pos != std::string::npos && w_pos < rect_pos + 120) {
            size_t w_start = chunk.find_first_of("0123456789", w_pos + 8);
            if (w_start != std::string::npos) {
                out.width = std::atoi(&chunk[w_start]);
            }
        }
        size_t h_pos = chunk.find("\"height\":", rect_pos);
        if (h_pos != std::string::npos && h_pos < rect_pos + 120) {
            size_t h_start = chunk.find_first_of("0123456789", h_pos + 9);
            if (h_start != std::string::npos) {
                out.height = std::atoi(&chunk[h_start]);
            }
        }
    }

    if (!app_id.empty() || !name.empty()) {
        out.app_class = app_id.empty() ? name : app_id;
        out.title = name;
        out.focused = true;
        return true;
    }

    return false;
}

WindowInfo SwayIPC::get_focused_window() {
    WindowInfo info;
    std::string tree = get_tree();
    if (!tree.empty()) {
        parse_focused_node(tree, info);
    }
    return info;
}

bool SwayIPC::toggle_fullscreen() {
    WindowInfo win = get_focused_window();
    if (win.fullscreen) {
        send_command(0, "fullscreen disable");
        if (win.floating) {
            send_command(0, "resize set width 1280 px height 720 px; move position center");
        }
    } else {
        send_command(0, "fullscreen enable");
    }
    return true;
}

bool SwayIPC::subscribe_events(const std::vector<std::string>& events, EventCallback callback) {
    if (fd_ < 0 && !connect()) {
        return false;
    }

    // Format JSON array: ["window", "workspace"]
    std::string payload = "[";
    for (size_t i = 0; i < events.size(); ++i) {
        payload += "\"" + events[i] + "\"";
        if (i + 1 < events.size()) payload += ",";
    }
    payload += "]";

    if (!send_message(2, payload)) { // 2 = SUBSCRIBE
        return false;
    }

    uint32_t resp_type = 0;
    std::string response;
    if (!read_message(resp_type, response)) {
        return false;
    }

    // Read loop
    while (true) {
        uint32_t evt_type = 0;
        std::string evt_payload;
        if (!read_message(evt_type, evt_payload)) {
            break;
        }

        // Mask out the highest bit indicating an event
        uint32_t pure_type = evt_type & 0x7FFFFFFF;
        std::string type_name = "unknown";
        if (pure_type == 0) type_name = "workspace";
        else if (pure_type == 3) type_name = "window";
        else if (pure_type == 4) type_name = "barconfig_update";
        else if (pure_type == 5) type_name = "mode";
        else if (pure_type == 6) type_name = "shutdown";
        else if (pure_type == 7) type_name = "tick";

        callback(type_name, evt_payload);
    }

    return true;
}

} // namespace b1air
