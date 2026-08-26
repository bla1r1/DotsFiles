#include "user_manager.hpp"
#include <pwd.h>
#include <grp.h>
#include <unistd.h>
#include <sys/stat.h>
#include <sys/types.h>
#include <cstdlib>
#include <iostream>
#include <sstream>
#include <fstream>
#include <vector>

namespace b1air {

static std::string escape_json(const std::string& s) {
    std::ostringstream o;
    for (char c : s) {
        if (c == '"') o << "\\\"";
        else if (c == '\\') o << "\\\\";
        else if (c == '\b') o << "\\b";
        else if (c == '\f') o << "\\f";
        else if (c == '\n') o << "\\n";
        else if (c == '\r') o << "\\r";
        else if (c == '\t') o << "\\t";
        else o << c;
    }
    return o.str();
}

UserProfile UserManager::get_current_user_profile() {
    UserProfile p;

    uid_t uid = getuid();
    struct passwd* pw = getpwuid(uid);

    const char* user_env = std::getenv("USER");
    p.username = pw ? pw->pw_name : (user_env ? user_env : "user");
    p.uid = std::to_string(uid);
    p.home = pw ? pw->pw_dir : (std::getenv("HOME") ? std::getenv("HOME") : "/home/" + p.username);
    p.shell = pw ? pw->pw_shell : (std::getenv("SHELL") ? std::getenv("SHELL") : "/bin/bash");

    // Parse GECOS for display name
    if (pw && pw->pw_gecos && pw->pw_gecos[0] != '\0') {
        std::string gecos = pw->pw_gecos;
        size_t comma = gecos.find(',');
        p.name = (comma != std::string::npos) ? gecos.substr(0, comma) : gecos;
    }
    if (p.name.empty()) {
        p.name = p.username;
    }

    // Avatar path discovery
    std::string icon1 = p.home + "/.face.icon";
    std::string icon2 = p.home + "/.face";
    std::string icon3 = "/var/lib/AccountsService/icons/" + p.username;

    struct stat st;
    if (stat(icon1.c_str(), &st) == 0) {
        p.avatar = icon1;
    } else if (stat(icon2.c_str(), &st) == 0) {
        p.avatar = icon2;
    } else if (stat(icon3.c_str(), &st) == 0) {
        p.avatar = icon3;
    }

    // User groups
    int ngroups = 64;
#if defined(__APPLE__)
    std::vector<int> groups(ngroups);
    if (getgrouplist(p.username.c_str(), static_cast<int>(pw ? pw->pw_gid : 1000), groups.data(), &ngroups) >= 0) {
        std::ostringstream gs;
        for (int i = 0; i < ngroups; ++i) {
            struct group* gr = getgrgid(static_cast<gid_t>(groups[i]));
            if (gr) {
                if (i > 0) gs << ", ";
                gs << gr->gr_name;
            }
        }
        p.groups = gs.str();
    }
#else
    std::vector<gid_t> groups(ngroups);
    if (getgrouplist(p.username.c_str(), pw ? pw->pw_gid : 1000, groups.data(), &ngroups) >= 0) {
        std::ostringstream gs;
        for (int i = 0; i < ngroups; ++i) {
            struct group* gr = getgrgid(groups[i]);
            if (gr) {
                if (i > 0) gs << ", ";
                gs << gr->gr_name;
            }
        }
        p.groups = gs.str();
    }
#endif

    return p;
}

std::string UserManager::get_user_info_json() {
    UserProfile p = get_current_user_profile();

    std::ostringstream ss;
    ss << "{\n";
    ss << "  \"username\": \"" << escape_json(p.username) << "\",\n";
    ss << "  \"name\": \"" << escape_json(p.name) << "\",\n";
    ss << "  \"uid\": \"" << escape_json(p.uid) << "\",\n";
    ss << "  \"home\": \"" << escape_json(p.home) << "\",\n";
    ss << "  \"shell\": \"" << escape_json(p.shell) << "\",\n";
    ss << "  \"avatar\": \"" << escape_json(p.avatar) << "\",\n";
    ss << "  \"groups\": \"" << escape_json(p.groups) << "\"\n";
    ss << "}\n";

    return ss.str();
}

static bool copy_file(const std::string& src, const std::string& dst) {
    std::ifstream in(src, std::ios::binary);
    if (!in.is_open()) return false;
    std::ofstream out(dst, std::ios::binary | std::ios::trunc);
    if (!out.is_open()) return false;
    out << in.rdbuf();
    chmod(dst.c_str(), 0644);
    return true;
}

bool UserManager::set_avatar(const std::string& image_path) {
    UserProfile p = get_current_user_profile();
    if (image_path.empty()) return false;

    struct stat st;
    if (stat(image_path.c_str(), &st) != 0) return false;

    bool ok1 = copy_file(image_path, p.home + "/.face.icon");
    bool ok2 = copy_file(image_path, p.home + "/.face");

    // Also copy to AccountsService if writable
    std::string acc = "/var/lib/AccountsService/icons/" + p.username;
    copy_file(image_path, acc);

    return ok1 || ok2;
}

bool UserManager::set_name(const std::string& new_name) {
    if (new_name.empty()) return false;
    UserProfile p = get_current_user_profile();

    std::string cmd = "chfn -f '" + new_name + "' '" + p.username + "' 2>/dev/null || sudo chfn -f '" + new_name + "' '" + p.username + "' 2>/dev/null";
    return (std::system(cmd.c_str()) == 0);
}

bool UserManager::set_shell(const std::string& new_shell) {
    if (new_shell.empty()) return false;
    struct stat st;
    if (stat(new_shell.c_str(), &st) != 0 || !(st.st_mode & S_IXUSR)) {
        return false;
    }
    UserProfile p = get_current_user_profile();

    std::string cmd = "chsh -s '" + new_shell + "' '" + p.username + "' 2>/dev/null || sudo chsh -s '" + new_shell + "' '" + p.username + "' 2>/dev/null";
    return (std::system(cmd.c_str()) == 0);
}

bool UserManager::change_password() {
    UserProfile p = get_current_user_profile();

    // Check installed terminal emulators
    std::string cmd;
    if (std::system("command -v kitty >/dev/null 2>&1") == 0) {
        cmd = "kitty --title \"Change Password - b1air\" -e sh -c \"echo '=== Change Password for " + p.username + " ==='; passwd; echo 'Press any key to close...'; read -n 1\" &";
    } else if (std::system("command -v foot >/dev/null 2>&1") == 0) {
        cmd = "foot -T \"Change Password - b1air\" sh -c \"echo '=== Change Password for " + p.username + " ==='; passwd; echo 'Press any key to close...'; read -n 1\" &";
    } else {
        cmd = "passwd &";
    }

    return (std::system(cmd.c_str()) == 0);
}

} // namespace b1air
