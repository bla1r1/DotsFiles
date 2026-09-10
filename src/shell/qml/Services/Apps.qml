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

    /**
     * The icon for a window, from its app_id.
     *
     * Surfaces that show live windows — the Alt+Tab switcher, the top bar's
     * running-apps island — used the app_id directly as an icon name:
     * `image://icon/b1air-files`. That works only when an application's app_id
     * happens to also be an icon name, which is true for firefox and konsole
     * and false for every app in this suite, so our own windows all drew the
     * "icon not found" placeholder. A Wayland app_id is by convention the base
     * name of the application's desktop entry, and the entry is what knows the
     * icon, so look it up there.
     *
     * Returns an absolute path or an icon name; "" when nothing matches, so a
     * caller can fall back to the old behaviour for anything not installed as
     * a desktop entry.
     */
    function iconFor(appId) {
        const id = String(appId || "").toLowerCase();
        if (id === "")
            return "";

        for (const a of root.list) {
            const base = String(a.desktopFile || "").replace(/\.desktop$/i, "").toLowerCase();
            if (base === id)
                return a.iconPath || a.icon || "";
        }

        // Reverse-DNS entries (org.kde.dolphin.desktop) against a plain class
        // (dolphin), and the other way round.
        for (const a of root.list) {
            const base = String(a.desktopFile || "").replace(/\.desktop$/i, "").toLowerCase();
            if (base.endsWith("." + id) || id.endsWith("." + base))
                return a.iconPath || a.icon || "";
        }
        return "";
    }

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
