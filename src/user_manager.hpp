#pragma once
#include <string>
#include <vector>

namespace b1air {

struct UserProfile {
    std::string username;
    std::string name;
    std::string uid;
    std::string home;
    std::string shell;
    std::string avatar;
    std::string groups;
};

class UserManager {
public:
    static UserProfile get_current_user_profile();
    static std::string get_user_info_json();
    static bool set_avatar(const std::string& image_path);
    static bool set_name(const std::string& new_name);
    static bool set_shell(const std::string& new_shell);
    static bool change_password();
};

} // namespace b1air
