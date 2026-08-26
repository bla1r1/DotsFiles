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

    property bool dnd: false
    property int toastTimeoutMs: 5000
    readonly property int unreadCount: history.count

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

        // Add to history
        root.history.insert(0, item);
        if (root.history.count > 50) root.history.remove(50);

        // Show toast popup only if DND is off
        if (!root.dnd) {
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
        root.dnd = !root.dnd;
    }
}
