pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Services.Notifications

// =============================================================================
// Desktop Notifications Service
//
// Native Freedesktop notification daemon (org.freedesktop.Notifications).
// Replaces external daemons (swaync, dunst, mako).
// =============================================================================

Singleton {
    id: root

    // Notification Server instance
    NotificationServer {
        id: server

        bodySupported: true
        actionsSupported: true
        imageSupported: true
        persistenceSupported: true

        onNotification: notif => {
            root._handleIncoming(notif);
        }
    }

    // Active notifications model (for live OSD toasts)
    readonly property ListModel activeToasts: ListModel {}

    // Notification History model (for Control Center history panel)
    readonly property ListModel history: ListModel {}

    // Do Not Disturb.
    //
    // `dnd` used to be a plain runtime bool: toggling it never touched
    // Settings.notificationsDnd, and nothing ever read that key back, so the
    // switch forgot itself on every shell restart while the setting sat in the
    // file doing nothing.
    //
    // Game Mode's "Do Not Disturb (DND) — mute all popups and toast
    // notifications while in game" was inert for the same reason: the switch
    // stored a value and no notification path consulted it.
    property bool manualDnd: false

    readonly property bool dnd: root.manualDnd
        || (Settings.gameModeEnabled === true && Settings.gameModeDND === true)
        // "Auto-Silence Notifications in Focus Mode" on the Screen Time page,
        // which had the same shape as the two above: a switch, a stored value
        // and no reader. Services/Focus decides when it applies — during a
        // work interval and not during a break, or the notification saying the
        // break is over would be the one thing suppressed.
        || Focus.wantsDnd
    property int toastTimeoutMs: 5000
    readonly property int unreadCount: history.count

    // Dynamically tracked applications that have sent notifications
    property var trackedApps: []

    function _recordApp(name, icon) {
        if (!name) return;
        let found = false;
        let list = (root.trackedApps || []).slice();
        for (let app of list) {
            if (app.name.toLowerCase() === name.toLowerCase()) {
                found = true;
                if (!app.icon && icon) app.icon = icon;
                break;
            }
        }
        if (!found) {
            list.push({ name: name, icon: icon || "dialog-information" });
            root.trackedApps = list;
        }
    }

    function isAppMuted(appName) {
        if (!appName) return false;
        let rules = Settings.notificationRules || {};
        let key = appName.toLowerCase().trim();
        return rules[key] === false;
    }

    function _handleIncoming(notif) {
        const item = {
            id: notif.id,
            appName: notif.appName || "System",
            summary: notif.summary || "",
            body: notif.body || "",
            icon: notif.icon || "",
            urgency: notif.urgency,
            time: new Date().toLocaleTimeString(Qt.locale(), "hh:mm"),
            obj: notif
        };

        // Record app to trackedApps list
        root._recordApp(item.appName, item.icon);

        // Add to history
        root.history.insert(0, item);
        if (root.history.count > 50) root.history.remove(50);

        // Show toast popup only if DND is off and app is not muted
        if (!root.dnd && !root.isAppMuted(item.appName)) {
            root.activeToasts.append(item);
        }
    }

    function dismissToast(index) {
        if (index >= 0 && index < root.activeToasts.count) {
            const item = root.activeToasts.get(index);
            if (item && item.obj && typeof item.obj.dismiss === "function") {
                item.obj.dismiss();
            }
            root.activeToasts.remove(index);
        }
    }

    function dismissToastById(id) {
        for (let i = 0; i < root.activeToasts.count; i++) {
            if (root.activeToasts.get(i).id === id) {
                root.dismissToast(i);
                break;
            }
        }
    }

    function dismissHistoryItem(index) {
        if (index >= 0 && index < root.history.count) {
            root.history.remove(index);
        }
    }

    function clearAllHistory() {
        root.history.clear();
        root.activeToasts.clear();
    }

    function toggleDnd() {
        root.manualDnd = !root.manualDnd;
        Settings.set("notificationsDnd", root.manualDnd);
    }

    // Restored once Settings has actually read the file; reading it earlier
    // gets the schema default rather than the saved choice.
    Connections {
        target: Settings
        function onLoadedChanged() {
            if (Settings.loaded)
                root.manualDnd = Settings.notificationsDnd === true;
        }
    }

    Component.onCompleted: {
        if (Settings.loaded)
            root.manualDnd = Settings.notificationsDnd === true;
    }
}
