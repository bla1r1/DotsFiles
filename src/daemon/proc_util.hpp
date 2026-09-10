#pragma once

// Small helpers that had been copy-pasted between translation units.
//
// `escape_json` existed verbatim in focustime_db.cpp and user_manager.cpp, and
// `spawn_detached` in daemon_dbus.cpp had a near-identical twin in
// system_control.cpp called run_argv_detached — the same fork/setsid/dup2/execvp
// body differing only in one optional argument. Both were `static`, so nothing
// complained; they simply drifted apart in private.
//
// Header-only and inline on purpose: no build file needs to learn about a new
// source, which is one less place for the copies to come back.

#include <fcntl.h>
#include <sys/stat.h>
#include <cerrno>
#include <unistd.h>
#include <sys/wait.h>

#include <iomanip>
#include <sstream>
#include <string>
#include <vector>

namespace b1air {
namespace util {

/**
 * Escape a string for embedding in a JSON document.
 *
 * The copies this replaces handled the seven named escapes and passed
 * everything else through — including the C0 control characters below 0x20,
 * which JSON requires to be escaped. A window title carrying one of those
 * produced a document that would not parse, and window titles are exactly what
 * these functions serialise.
 */
inline std::string escape_json(const std::string& s) {
    std::ostringstream o;
    for (unsigned char c : s) {
        switch (c) {
        case '"':  o << "\\\""; break;
        case '\\': o << "\\\\"; break;
        case '\b': o << "\\b";  break;
        case '\f': o << "\\f";  break;
        case '\n': o << "\\n";  break;
        case '\r': o << "\\r";  break;
        case '\t': o << "\\t";  break;
        default:
            if (c < 0x20) {
                o << "\\u" << std::hex << std::setw(4) << std::setfill('0')
                  << static_cast<int>(c) << std::dec;
            } else {
                o << static_cast<char>(c);
            }
        }
    }
    return o.str();
}

/**
 * Run a command without a shell, fully detached from this process.
 *
 * No shell means no quoting rules to get wrong: arguments arrive at the child
 * exactly as given, whatever is in them.
 *
 * Returns whether the fork succeeded — the child is not waited on, so this says
 * nothing about whether the command itself worked.
 */
inline bool spawn_detached(const std::vector<std::string>& args,
                           const char* wayland_display = nullptr) {
    if (args.empty()) return false;

    pid_t pid = fork();
    if (pid < 0) return false;

    if (pid == 0) {
        (void)setsid();
        const int null_fd = open("/dev/null", O_RDWR | O_CLOEXEC);
        if (null_fd >= 0) {
            dup2(null_fd, STDIN_FILENO);
            dup2(null_fd, STDOUT_FILENO);
            dup2(null_fd, STDERR_FILENO);
            if (null_fd > STDERR_FILENO) close(null_fd);
        }
        if (wayland_display) setenv("WAYLAND_DISPLAY", wayland_display, 1);

        std::vector<char*> argv;
        argv.reserve(args.size() + 1);
        for (const auto& arg : args) argv.push_back(const_cast<char*>(arg.c_str()));
        argv.push_back(nullptr);

        execvp(argv[0], argv.data());
        _exit(127);
    }

    // Reaped by the double-fork-free route: the child setsid()s and this
    // process does not wait, so init adopts it once this process exits. Callers
    // that need the exit status should not be using a detached spawn.
    return true;
}

/**
 * Create a directory and every parent it needs.
 *
 * mkdir(2) makes one level. The screenshot path went through a single
 * mkdir("$HOME/Pictures/Screenshots"), which fails with ENOENT on any machine
 * where ~/Pictures does not exist yet — a fresh install, before anything has
 * created the XDG user directories — so the capture was written nowhere and
 * the only sign was a non-zero exit nobody sees. A configured folder nested
 * more than one level deep failed the same way.
 *
 * Returns whether the directory exists afterwards.
 */
inline bool mkdir_p(const std::string& path, mode_t mode = 0755) {
    if (path.empty()) return false;

    std::string built;
    size_t i = 0;
    if (path[0] == '/') { built = "/"; i = 1; }

    while (i <= path.size()) {
        const size_t slash = path.find('/', i);
        const std::string part = path.substr(i, slash == std::string::npos ? std::string::npos : slash - i);
        if (!part.empty()) {
            if (built.size() > 1 || (built.size() == 1 && built[0] != '/')) built += "/";
            built += part;
            if (mkdir(built.c_str(), mode) != 0 && errno != EEXIST) return false;
        }
        if (slash == std::string::npos) break;
        i = slash + 1;
    }

    struct stat st{};
    return stat(path.c_str(), &st) == 0 && S_ISDIR(st.st_mode);
}

} // namespace util
} // namespace b1air
