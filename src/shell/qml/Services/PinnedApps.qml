pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    property var pinnedList: [
        { id: "b1air-files", name: "Files", icon: "󰉋", cmd: "b1air-files" },
        { id: "b1air-night", name: "Night Light", icon: "󱡁", cmd: "b1air-daemon night-light toggle" },
        { id: "b1air-term", name: "Terminal", icon: "󰞷", cmd: "b1air-term" },
        { id: "b1air-notes", name: "Notes", icon: "󰈙", cmd: "b1air-notes" },
        { id: "b1air-git", name: "Git", icon: "󰊢", cmd: "b1air-git" },
        { id: "b1air-control", name: "Control Center", icon: "󱥂", cmd: "toggle:control:" }
    ]

    function isPinned(appIdOrName) {
        let key = (appIdOrName || "").toLowerCase();
        for (let item of root.pinnedList) {
            if (item.id.toLowerCase() === key || item.name.toLowerCase() === key || (item.cmd && item.cmd.toLowerCase().includes(key))) {
                return true;
            }
        }
        return false;
    }

    function togglePin(app) {
        let key = (app.name || app.id || "").toLowerCase();
        let idx = -1;
        for (let i = 0; i < root.pinnedList.length; i++) {
            if (root.pinnedList[i].id.toLowerCase() === key || root.pinnedList[i].name.toLowerCase() === key) {
                idx = i;
                break;
            }
        }
        let copy = Array.from(root.pinnedList);
        if (idx !== -1) {
            copy.splice(idx, 1);
        } else {
            copy.push({
                id: app.name || "app",
                name: app.name || "App",
                icon: app.icon || "󰀻",
                cmd: app.cmd || ""
            });
        }
        root.pinnedList = copy;
        save();
    }

    function save() {
        let jsonStr = JSON.stringify(root.pinnedList);
        saveProc.command = ["bash", "-c", "mkdir -p ~/.config/b1air && cat << 'EOF' > ~/.config/b1air/pinned_apps.json\n" + jsonStr + "\nEOF"];
        saveProc.running = true;
    }

    Process {
        id: loadProc
        running: true
        command: ["bash", "-c", "cat ~/.config/b1air/pinned_apps.json 2>/dev/null || echo ''"]
        stdout: StdioCollector {
            onStreamFinished: {
                let t = this.text.trim();
                if (t && t.startsWith("[")) {
                    try {
                        let parsed = JSON.parse(t);
                        if (Array.isArray(parsed) && parsed.length > 0) {
                            root.pinnedList = parsed;
                        }
                    } catch(e) {}
                }
            }
        }
    }

    Process {
        id: saveProc
        running: false
    }
}
