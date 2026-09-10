pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// =============================================================================
// The installed-application list, fetched once.
//
// Launchpad and SpotlightLauncher each ran their own `b1air-daemon apps all`
// and each parsed the reply themselves — the same twenty lines twice, and two
// subprocesses scanning the same desktop files. They differed only in how they
// presented the result: Launchpad resolves an icon path and maps the category,
// Spotlight uses a glyph and files everything under "Applications".
//
// So the fetch lives here and the raw entries are handed out unchanged; each
// launcher keeps its own presentation. Loading is lazy — a QML singleton is not
// created until something refers to it — so nothing is scanned until a launcher
// is actually opened.
// =============================================================================

Singleton {
    id: root

    /** Raw entries as the daemon reports them: name, comment, icon, iconPath, exec, category. */
    property var list: []

    readonly property bool loaded: root._loaded
    property bool _loaded: false

    /** Re-scan. Cheap to call: one process, and only when asked. */
    function reload() {
        appLoader.running = false;
        appLoader.running = true;
    }

    Process {
        id: appLoader
        running: true
        command: ["b1air-daemon", "apps", "all"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const items = JSON.parse(this.text);
                    root.list = Array.isArray(items) ? items : [];
                } catch (e) {
                    // A daemon that is not up yet, or a truncated reply. Keep
                    // whatever was listed before rather than blanking the
                    // launcher the user is looking at.
                    if (!root._loaded)
                        root.list = [];
                }
                root._loaded = true;
            }
        }
    }
}
