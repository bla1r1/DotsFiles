import QtQuick
import Quickshell
import Quickshell.Io
import "WindowRegistry.js" as LayoutMath 

Item {
    id: root
    visible: false

    property real currentWidth: 1920.0
    property real uiScale: 1.0

    property real baseScale: LayoutMath.getScale(currentWidth, uiScale)
    
    function s(val) { 
        return LayoutMath.s(val, baseScale); 
    }

    Process {
        id: scaleReader
        command: ["bash", "-c", "jq -c . ~/.config/sway/settings.json 2>/dev/null || echo '{}'"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    let text = this.text ? this.text.trim() : "{}";
                    let start = text.indexOf("{");
                    let end = text.lastIndexOf("}");
                    if (start >= 0 && end >= start) text = text.slice(start, end + 1);
                    else text = "{}";

                    if (text.length > 0 && text !== "{}") {
                        let parsed = JSON.parse(text);
                        if (parsed.uiScale !== undefined && root.uiScale !== parsed.uiScale) {
                            root.uiScale = parsed.uiScale;
                        }
                    }
                } catch (e) {}
            }
        }
    }

    // EVENT-DRIVEN WATCHER
    Process {
        id: scaleWatcher
        // -qq keeps it completely silent. It waits for the file to exist, listens for a write, and then exits.
        command: ["bash", "-c", "while [ ! -f ~/.config/sway/settings.json ]; do sleep 1; done; inotifywait -qq -e modify,close_write ~/.config/sway/settings.json"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                // 1. Read the new data
                scaleReader.running = false;
                scaleReader.running = true;
                // 2. Restart the watcher for the next event
                scaleWatcher.running = false;
                scaleWatcher.running = true;
            }
        }
    }
}
