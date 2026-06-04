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
}
