#include "secret_store.hpp"
#include "runtime.hpp"

#include <openssl/evp.h>
#include <openssl/rand.h>
#include <fcntl.h>
#include <sys/mman.h>
#include <sys/stat.h>
#include <unistd.h>
#include <cerrno>
#include <cstring>
#include <limits>
#include <vector>

namespace b1air {
namespace {

class LockedBytes {
public:
    explicit LockedBytes(size_t size) : m_data(size) {
        if (!m_data.empty()) {
            m_locked = mlock(m_data.data(), m_data.size()) == 0;
#ifdef MADV_DONTDUMP
            madvise(m_data.data(), m_data.size(), MADV_DONTDUMP);
#endif
        }
    }
    ~LockedBytes() {
        if (!m_data.empty()) {
            OPENSSL_cleanse(m_data.data(), m_data.size());
            if (m_locked) munlock(m_data.data(), m_data.size());
        }
    }
    unsigned char* data() { return m_data.data(); }
    const unsigned char* data() const { return m_data.data(); }
    size_t size() const { return m_data.size(); }
private:
    std::vector<unsigned char> m_data;
    bool m_locked = false;
};

bool valid_name(const std::string& name) {
    if (name.empty() || name.size() > 96) return false;
    for (char c : name) {
        if (!((c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z') ||
              (c >= '0' && c <= '9') || c == '_' || c == '-' || c == '.')) return false;
    }
    return name != "." && name != "..";
}

bool write_all(int fd, const unsigned char* data, size_t size) {
    size_t offset = 0;
    while (offset < size) {
        ssize_t n = ::write(fd, data + offset, size - offset);
        if (n <= 0) return false;
        offset += static_cast<size_t>(n);
    }
    return true;
}

void mkdir_private(const std::string& path) {
    std::string current;
    for (char c : path) {
        current += c;
        if (c == '/' && current.size() > 1) mkdir(current.c_str(), 0700);
    }
    mkdir(path.c_str(), 0700);
}

} // namespace

SecretStore::SecretStore()
    : m_root((std::getenv("XDG_STATE_HOME") && *std::getenv("XDG_STATE_HOME"))
                 ? std::string(std::getenv("XDG_STATE_HOME")) + "/b1air/secrets"
                 : std::string(std::getenv("HOME") ? std::getenv("HOME") : "/tmp") + "/.local/state/b1air/secrets"),
      m_keyPath(m_root + "/master.key") {
    const std::string parent = m_root.substr(0, m_root.rfind("/secrets"));
    mkdir_private(parent);
    chmod(parent.c_str(), 0700);
    mkdir_private(m_root);
    chmod(m_root.c_str(), 0700);
}

std::string SecretStore::path_for(const std::string& name) const {
    return valid_name(name) ? m_root + "/" + name + ".enc" : "";
}

bool SecretStore::load_key(unsigned char key[32]) const {
    int fd = open(m_keyPath.c_str(), O_RDONLY | O_CLOEXEC | O_NOFOLLOW);
    if (fd < 0 && errno == ENOENT) {
        fd = open(m_keyPath.c_str(), O_WRONLY | O_CREAT | O_EXCL | O_CLOEXEC | O_NOFOLLOW, 0600);
        if (fd < 0) return false;
        if (RAND_bytes(key, 32) != 1 || !write_all(fd, key, 32)) { close(fd); unlink(m_keyPath.c_str()); return false; }
        fchmod(fd, 0600);
        fsync(fd);
        close(fd);
        return true;
    }
    if (fd < 0) return false;
    ssize_t got = 0;
    while (got < 32) {
        ssize_t n = read(fd, key + got, 32 - got);
        if (n <= 0) { close(fd); return false; }
        got += n;
    }
    close(fd);
    return true;
}

bool SecretStore::set(const std::string& name, const std::string& value) const {
    const std::string path = path_for(name);
    if (path.empty() || value.size() > 1024 * 1024) return false;
    LockedBytes key(32), plaintext(value.size()), nonce(12), tag(16), ciphertext(value.size());
    if (!load_key(key.data()) || RAND_bytes(nonce.data(), nonce.size()) != 1) return false;
    if (!value.empty()) std::memcpy(plaintext.data(), value.data(), value.size());

    EVP_CIPHER_CTX* ctx = EVP_CIPHER_CTX_new();
    int outLen = 0, finalLen = 0;
    bool ok = ctx && EVP_EncryptInit_ex(ctx, EVP_aes_256_gcm(), nullptr, nullptr, nullptr) == 1 &&
              EVP_CIPHER_CTX_ctrl(ctx, EVP_CTRL_GCM_SET_IVLEN, nonce.size(), nullptr) == 1 &&
              EVP_EncryptInit_ex(ctx, nullptr, nullptr, key.data(), nonce.data()) == 1 &&
              EVP_EncryptUpdate(ctx, ciphertext.data(), &outLen, plaintext.data(), plaintext.size()) == 1 &&
              EVP_EncryptFinal_ex(ctx, ciphertext.data() + outLen, &finalLen) == 1 &&
              EVP_CIPHER_CTX_ctrl(ctx, EVP_CTRL_GCM_GET_TAG, tag.size(), tag.data()) == 1;
    if (ctx) EVP_CIPHER_CTX_free(ctx);
    if (!ok) return false;

    std::string tmp = path + ".tmp-" + std::to_string(getpid());
    int fd = open(tmp.c_str(), O_WRONLY | O_CREAT | O_TRUNC | O_CLOEXEC | O_NOFOLLOW, 0600);
    if (fd < 0) return false;
    const unsigned char magic[] = {'B','1','S','1'};
    ok = write_all(fd, magic, sizeof(magic)) && write_all(fd, nonce.data(), nonce.size()) &&
         write_all(fd, tag.data(), tag.size()) && write_all(fd, ciphertext.data(), ciphertext.size());
    fchmod(fd, 0600); fsync(fd); close(fd);
    if (!ok || rename(tmp.c_str(), path.c_str()) != 0) { unlink(tmp.c_str()); return false; }
    return true;
}

bool SecretStore::get(const std::string& name, std::string& value) const {
    const std::string path = path_for(name);
    if (path.empty()) return false;
    // Do not use ifstream here: a compromised state directory must not be able
    // to redirect a read through a symlink after path_for() has returned.
    const int fd = open(path.c_str(), O_RDONLY | O_CLOEXEC | O_NOFOLLOW);
    if (fd < 0) return false;
    struct stat st{};
    if (fstat(fd, &st) != 0 || !S_ISREG(st.st_mode) || st.st_size < 32 || st.st_size > 1024 * 1024 + 32) {
        close(fd);
        return false;
    }
    std::vector<unsigned char> blob(static_cast<size_t>(st.st_size));
    size_t offset = 0;
    while (offset < blob.size()) {
        const ssize_t n = read(fd, blob.data() + offset, blob.size() - offset);
        if (n <= 0) { close(fd); return false; }
        offset += static_cast<size_t>(n);
    }
    close(fd);
    if (blob.size() < 32 || std::memcmp(blob.data(), "B1S1", 4) != 0) return false;
    LockedBytes key(32), nonce(12), tag(16), plaintext(blob.size() - 32);
    if (!load_key(key.data())) return false;
    std::memcpy(nonce.data(), blob.data() + 4, nonce.size());
    std::memcpy(tag.data(), blob.data() + 16, tag.size());
    EVP_CIPHER_CTX* ctx = EVP_CIPHER_CTX_new();
    int outLen = 0, finalLen = 0;
    bool ok = ctx && EVP_DecryptInit_ex(ctx, EVP_aes_256_gcm(), nullptr, nullptr, nullptr) == 1 &&
              EVP_CIPHER_CTX_ctrl(ctx, EVP_CTRL_GCM_SET_IVLEN, nonce.size(), nullptr) == 1 &&
              EVP_DecryptInit_ex(ctx, nullptr, nullptr, key.data(), nonce.data()) == 1 &&
              EVP_DecryptUpdate(ctx, plaintext.data(), &outLen, blob.data() + 32, blob.size() - 32) == 1 &&
              EVP_CIPHER_CTX_ctrl(ctx, EVP_CTRL_GCM_SET_TAG, tag.size(), tag.data()) == 1 &&
              EVP_DecryptFinal_ex(ctx, plaintext.data() + outLen, &finalLen) == 1;
    if (ctx) EVP_CIPHER_CTX_free(ctx);
    if (!ok) return false;
    value.assign(reinterpret_cast<const char*>(plaintext.data()), static_cast<size_t>(outLen + finalLen));
    return true;
}

bool SecretStore::remove(const std::string& name) const {
    const std::string path = path_for(name);
    return !path.empty() && unlink(path.c_str()) == 0;
}

}
