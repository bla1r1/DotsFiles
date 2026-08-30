#pragma once

#include <sys/stat.h>
#include <unistd.h>
#include <cstdlib>
#include <string>

namespace b1air {

inline std::string runtime_dir() {
    const char* configured = std::getenv("XDG_RUNTIME_DIR");
    std::string base = configured && *configured ? configured : ("/tmp/b1air-" + std::to_string(static_cast<unsigned long>(getuid())));
    std::string dir = base + "/b1air";
    mkdir(base.c_str(), 0700);
    chmod(base.c_str(), 0700);
    mkdir(dir.c_str(), 0700);
    chmod(dir.c_str(), 0700);
    return dir;
}

inline std::string runtime_path(const char* name) {
    return runtime_dir() + "/" + name;
}

} // namespace b1air
