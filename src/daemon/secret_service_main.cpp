#include "secret_store.hpp"
#include <iostream>
#include <iterator>
#include <sys/resource.h>
#include <sys/mman.h>
#ifdef __linux__
#include <sys/prctl.h>
#endif

int main(int argc, char** argv) {
    if (argc < 3) return 2;
    struct rlimit core_limit{0, 0};
    setrlimit(RLIMIT_CORE, &core_limit);
#ifdef __linux__
    prctl(PR_SET_DUMPABLE, 0);
#endif
    mlockall(MCL_CURRENT | MCL_FUTURE);
    b1air::SecretStore store;
    const std::string name = argv[2];
    if (std::string(argv[1]) == "get") {
        std::string value;
        if (!store.get(name, value)) return 1;
        std::cout << value;
        return 0;
    }
    if (std::string(argv[1]) == "set") {
        std::string value((std::istreambuf_iterator<char>(std::cin)), std::istreambuf_iterator<char>());
        return store.set(name, value) ? 0 : 1;
    }
    if (std::string(argv[1]) == "remove") return store.remove(name) ? 0 : 1;
    return 2;
}
