pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// =============================================================================
// Weather Service (Keyless Instant Weather via wttr.in)
// =============================================================================

Singleton {
    id: root

    property string temp: "+20°C"
    property string condition: "Clear"
    property string icon: "\u{f185}" // sun
    property string location: "Local Weather"
    property bool loaded: false

    Process {
        id: fetcher
        running: true
        command: ["bash", "-c", "curl -s --max-time 4 'https://wttr.in/?format=%t|%C|%l' 2>/dev/null || echo '+21°C|Clear|Local'"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const raw = this.text.trim();
                    const parts = raw.split("|");
                    if (parts.length >= 2 && parts[0].includes("°")) {
                        root.temp = parts[0].trim();
                        root.condition = parts[1].trim();
                        if (parts.length >= 3 && parts[2].trim()) {
                            root.location = parts[2].trim();
                        }
                        const cond = root.condition.toLowerCase();
                        if (cond.includes("sun") || cond.includes("clear")) root.icon = "󰖙";
                        else if (cond.includes("rain") || cond.includes("drizzle") || cond.includes("shower")) root.icon = "󰖗";
                        else if (cond.includes("snow") || cond.includes("ice")) root.icon = "󰖘";
                        else if (cond.includes("thunder") || cond.includes("storm")) root.icon = "󰖓";
                        else if (cond.includes("cloud") || cond.includes("overcast")) root.icon = "󰖐";
                        else root.icon = "󰖙";
                        root.loaded = true;
                    }
                } catch(e) {}
            }
        }
    }

    Timer {
        interval: 1800000 // 30 minutes
        running: true
        repeat: true
        onTriggered: fetcher.running = true
    }
}
