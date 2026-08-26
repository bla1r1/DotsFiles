#include "sway_ipc.hpp"
#include <sys/socket.h>
#include <sys/un.h>
#include <unistd.h>
#include <cstdlib>
#include <cstring>
#include <iostream>
#include <sstream>

namespace b1air {

static const char I3_MAGIC[] = "i3-ipc";
static const size_t I3_MAGIC_LEN = 6;
static const size_t I3_HEADER_LEN = 14; // 6 (magic) + 4 (length) + 4 (type)

SwayIPC::SwayIPC() {
    socket_path_ = find_socket_path();
}

SwayIPC::~SwayIPC() {
    disconnect();
}

std::string SwayIPC::find_socket_path() {
    const char* swaysock = std::getenv("SWAYSOCK");
    if (swaysock && swaysock[0] != '\0') {
        return std::string(swaysock);
    }
    const char* i3sock = std::getenv("I3SOCK");
    if (i3sock && i3sock[0] != '\0') {
        return std::string(i3sock);
    }
    return "";
}

bool SwayIPC::connect() {
    if (socket_path_.empty()) {
        socket_path_ = find_socket_path();
    }
    if (socket_path_.empty()) {
        return false;
    }

    fd_ = socket(AF_UNIX, SOCK_STREAM, 0);
    if (fd_ < 0) {
        return false;
    }

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

// Quick helper to search for focused window in tree or container JSON
static bool parse_focused_node(const std::string& json, WindowInfo& out) {
    // Find `"focused":true` or `"focused": true`
    size_t f_pos = json.find("\"focused\":true");
    if (f_pos == std::string::npos) {
        f_pos = json.find("\"focused\": true");
    }
    if (f_pos == std::string::npos) {
        return false;
    }

    // Find the enclosing node start by finding previous '{' or "id"
    size_t node_start = json.rfind('{', f_pos);
    size_t node_end = json.find('}', f_pos);
    if (node_start == std::string::npos || node_end == std::string::npos) {
        return false;
    }

    std::string chunk = json.substr(node_start, (node_end - node_start) + 200);

    // Extract app_id
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

    if (!app_id.empty() || !name.empty()) {
        out.app_class = app_id.empty() ? name : app_id;
        out.title = name;
        out.focused = true;
        return true;
    }

    return false;
}

WindowInfo SwayIPC::get_focused_window() {
    WindowInfo win;
    std::string tree = get_tree();
    if (!tree.empty()) {
        parse_focused_node(tree, win);
    }
    return win;
}

bool SwayIPC::subscribe_events(const std::vector<std::string>& events, EventCallback callback) {
    if (!connect()) {
        return false;
    }

    std::string payload = "[";
    for (size_t i = 0; i < events.size(); ++i) {
        payload += "\"" + events[i] + "\"";
        if (i + 1 < events.size()) payload += ",";
    }
    payload += "]";

    // Send SUBSCRIBE (type 2)
    if (!send_message(2, payload)) {
        return false;
    }

    uint32_t reply_type = 0;
    std::string reply;
    if (!read_message(reply_type, reply)) {
        return false;
    }

    // Event loop
    while (true) {
        uint32_t evt_type = 0;
        std::string evt_payload;
        if (!read_message(evt_type, evt_payload)) {
            break;
        }

        // IPC event types have the highest bit set (0x80000000)
        uint32_t clean_type = evt_type & 0x7FFFFFFF;
        std::string evt_name = (clean_type == 0) ? "workspace" : ((clean_type == 3) ? "window" : "event");
        if (callback) {
            callback(evt_name, evt_payload);
        }
    }

    return true;
}

} // namespace b1air
