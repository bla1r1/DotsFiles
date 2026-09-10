// =============================================================================
// b1air-settings — launcher for the shell's settings window.
//
// This used to build its own QQmlApplicationEngine and load
// shell/qml/SettingsWindow.qml directly. That could never work: the settings
// UI imports Quickshell (and Services, which needs Quickshell.Io), and
// Quickshell's qmldir declares
//
//     linktarget quickshell-coreplugin
//     optional plugin quickshell-coreplugin
//
// meaning the plugin is expected to be linked into the host binary. The
// `quickshell` binary links it; a plain Qt application does not. So every
// launch died with
//
//     module "Quickshell" plugin "quickshell-coreplugin" not found
//     Error: Failed to load SettingsWindow.qml
//
// while the Launchpad entry, the b1air-settings.desktop file and the mimeapps
// default all pointed here. The same window opens correctly from the shell
// (Mod+Shift+S is `b1air-shell toggle settings`), so this now forwards there
// instead of re-implementing a host it cannot be.
// =============================================================================

#include <cstring>
#include <iostream>
#include <unistd.h>

int main(int argc, char* argv[]) {
    // b1air-settings [page] → b1air-shell open settings <page>
    //                       → b1air-shell toggle settings   (no page given)
    if (argc > 1 && std::strlen(argv[1]) > 0) {
        execlp("b1air-shell", "b1air-shell", "open", "settings", argv[1], (char*)nullptr);
    } else {
        execlp("b1air-shell", "b1air-shell", "toggle", "settings", (char*)nullptr);
    }

    // execlp only returns on failure.
    std::cerr << "[b1air-settings] Error: could not run b1air-shell — "
                 "is the b1air session running and ~/.local/bin on PATH?\n";
    return 1;
}
