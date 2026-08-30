#pragma once

#include <string>

namespace b1air {

// Small private b1air secret store. Files are AES-256-GCM encrypted and all
// short-lived key/plaintext buffers are locked and wiped where the kernel allows it.
class SecretStore {
public:
    SecretStore();
    bool get(const std::string& name, std::string& value) const;
    bool set(const std::string& name, const std::string& value) const;
    bool remove(const std::string& name) const;

private:
    std::string m_root;
    std::string m_keyPath;
    std::string path_for(const std::string& name) const;
    bool load_key(unsigned char key[32]) const;
};

}
