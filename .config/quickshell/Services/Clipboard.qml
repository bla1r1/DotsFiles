pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// =============================================================================
// Clipboard Service
//
// Monitors Wayland clipboard (wl-paste) and provides searchable history with
// pinning, formatting detection (text, url, hex color, code), and 1-click restore.
// Replaces external tools (copyq, cliphist, rofi_clipboard).
// =============================================================================

Singleton {
    id: root

    readonly property ListModel items: ListModel {}
    readonly property string cacheFile: Quickshell.env("HOME") + "/.cache/qs_clipboard.json"
    property string lastText: ""

    // 1. Initial Load & Persistence
    Process {
        id: loadProcess
        running: true
        command: ["bash", "-c", "cat ~/.cache/qs_clipboard.json 2>/dev/null || echo '[]'"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const raw = this.text ? this.text.trim() : "[]";
                    const list = JSON.parse(raw);
                    if (Array.isArray(list)) {
                        for (let i = 0; i < list.length; i++) {
                            root.items.append(list[i]);
                        }
                    }
                } catch (e) {
                    console.log("Clipboard cache load error:", e);
                }
            }
        }
    }

    // 2. Continuous Clipboard Monitor Process
    Process {
        id: watcher
        running: true
        command: ["bash", "-c", "wl-paste --watch bash -c 'wl-paste --no-newline 2>/dev/null'"]
        stdout: StdioCollector {
            onStreamFinished: {
                if (this.text) {
                    root._handleNewClip(this.text);
                }
            }
        }
    }

    // Backup polling timer (every 1s) to catch any clips if watcher process exits
    Timer {
        interval: 1000
        repeat: true
        running: true
        onTriggered: pollClip.running = true
    }

    Process {
        id: pollClip
        running: false
        command: ["bash", "-c", "wl-paste --no-newline 2>/dev/null || true"]
        stdout: StdioCollector {
            onStreamFinished: {
                if (this.text) {
                    root._handleNewClip(this.text);
                }
            }
        }
    }

    function _detectType(text) {
        if (!text) return "text";
        const t = text.trim();
        if (/^https?:\/\/[^\s]+$/i.test(t)) return "link";
        if (/^#([0-9a-fA-F]{3}|[0-9a-fA-F]{6}|[0-9a-fA-F]{8})$/.test(t)) return "color";
        if (/^(\{|\}|\[|\]|function|class|const|let|var|def|import|export|if|for|while|select|curl|git|docker)/m.test(t) || t.includes("\n")) return "code";
        return "text";
    }

    function _handleNewClip(text) {
        if (!text || text.trim() === "" || text === root.lastText) return;
        root.lastText = text;

        const trimmed = text.trim();
        // Check if already exists in history
        for (let i = 0; i < root.items.count; i++) {
            const cur = root.items.get(i);
            if (cur.text === text) {
                // If it's already top, skip
                if (i === 0) return;
                // Move to top
                const pinned = cur.pinned;
                root.items.remove(i);
                root.items.insert(0, {
                    id: Date.now().toString(),
                    text: text,
                    preview: trimmed.slice(0, 200),
                    type: root._detectType(text),
                    time: new Date().toLocaleTimeString(Qt.locale(), "hh:mm"),
                    pinned: pinned
                });
                root._save();
                return;
            }
        }

        // Insert new clip at index 0
        root.items.insert(0, {
            id: Date.now().toString(),
            text: text,
            preview: trimmed.slice(0, 200),
            type: root._detectType(text),
            time: new Date().toLocaleTimeString(Qt.locale(), "hh:mm"),
            pinned: false
        });

        // Limit to 60 items
        while (root.items.count > 60) {
            let removed = false;
            for (let j = root.items.count - 1; j >= 0; j--) {
                if (!root.items.get(j).pinned) {
                    root.items.remove(j);
                    removed = true;
                    break;
                }
            }
            if (!removed) break;
        }

        root._save();
    }

    function copyToClipboard(text) {
        if (!text) return;
        root.lastText = text;
        Quickshell.execDetached(["bash", "-c", "printf '%s' " + JSON.stringify(text) + " | wl-copy"]);
    }

    function togglePin(index) {
        if (index >= 0 && index < root.items.count) {
            const item = root.items.get(index);
            item.pinned = !item.pinned;
            root._save();
        }
    }

    function deleteItem(index) {
        if (index >= 0 && index < root.items.count) {
            root.items.remove(index);
            root._save();
        }
    }

    function clearHistory() {
        // Keep pinned
        for (let i = root.items.count - 1; i >= 0; i--) {
            if (!root.items.get(i).pinned) {
                root.items.remove(i);
            }
        }
        root._save();
    }

    function _save() {
        const arr = [];
        for (let i = 0; i < root.items.count; i++) {
            const it = root.items.get(i);
            arr.push({
                id: it.id,
                text: it.text,
                preview: it.preview,
                type: it.type,
                time: it.time,
                pinned: it.pinned
            });
        }
        const json = JSON.stringify(arr);
        Quickshell.execDetached(["bash", "-c", "mkdir -p ~/.cache && printf '%s' " + JSON.stringify(json) + " > ~/.cache/qs_clipboard.json"]);
    }
}
