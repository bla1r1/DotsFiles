.pragma library

function getScale(mw, userScale) {
    if (mw <= 0) return 1.0;
    let r = mw / 1920.0;
    let baseScale = 1.0;
    
    if (r <= 1.0) {
        baseScale = Math.max(0.35, Math.pow(r, 0.85));
    } else {
        baseScale = Math.pow(r, 0.5);
    }
    
    return baseScale * (userScale !== undefined ? userScale : 1.0);
}

function s(val, scale) {
    return Math.round(val * scale);
}

function getLayout(name, mx, my, mw, mh, userScale) {
    let scale = getScale(mw, userScale);

    let base = {
        // One surface with pages. The four entries it replaces stay below so an
        // existing binding still opens the right page rather than breaking.
        // Top-right, under the bar — a Control Center is a corner panel, not a
        // window. 380x560 against the old 1120x780: it holds tiles, and detail
        // opens in the popup that already exists for it.
        // 700, not 580: the tile grid, the two sliders, the weather card and
        // the media card add up to roughly 690px, so at 580 the last card was
        // always half-cut against the bottom edge. It still scrolls when a
        // screen cannot spare the height.
        "control":       { w: s(390, scale), h: s(700, scale), rx: mw - s(410, scale), ry: s(58, scale), comp: "control/ControlCenter.qml" },
        "notifications": { w: s(390, scale), h: s(700, scale), rx: mw - s(410, scale), ry: s(58, scale), comp: "control/ControlCenter.qml" },
        "wifi":          { w: s(390, scale), h: s(700, scale), rx: mw - s(410, scale), ry: s(58, scale), comp: "control/ControlCenter.qml" },
        "bluetooth": { w: s(390, scale), h: s(700, scale), rx: mw - s(410, scale), ry: s(58, scale), comp: "control/ControlCenter.qml" },
        "sound":     { w: s(390, scale), h: s(700, scale), rx: mw - s(410, scale), ry: s(58, scale), comp: "control/ControlCenter.qml" },
        "power":     { w: s(390, scale), h: s(700, scale), rx: mw - s(410, scale), ry: s(58, scale), comp: "control/ControlCenter.qml" },
        "battery":   { w: s(390, scale), h: s(700, scale), rx: mw - s(410, scale), ry: s(58, scale), comp: "control/ControlCenter.qml" },
        "volume":    { w: s(390, scale), h: s(700, scale), rx: mw - s(410, scale), ry: s(58, scale), comp: "control/ControlCenter.qml" },
        "network":   { w: s(390, scale), h: s(700, scale), rx: mw - s(410, scale), ry: s(58, scale), comp: "control/ControlCenter.qml" },
        "calendar":  { w: s(860, scale), h: s(480, scale), rx: Math.floor((mw/2)-(s(860, scale)/2)), ry: s(75, scale), comp: "calendar/CalendarPopup.qml" },
        // 760: the cover block, the transport row, the ten EQ bands and the preset
        // buttons need about 730px, and at 620 the preset row was sliced in half
        // against the bottom edge with nothing on screen offering to scroll.
        "music":     { w: s(700, scale), h: s(760, scale), rx: s(12, scale), ry: s(58, scale), comp: "music/MusicPopup.qml" },
        "audioFull":  { w: s(980, scale), h: s(720, scale), rx: Math.floor((mw/2)-(s(980, scale)/2)), ry: s(70, scale), comp: "settings/SettingsApp.qml" },
        "powerFull":  { w: s(980, scale), h: s(720, scale), rx: Math.floor((mw/2)-(s(980, scale)/2)), ry: s(70, scale), comp: "settings/SettingsApp.qml" },
        "netFull":    { w: s(980, scale), h: s(720, scale), rx: Math.floor((mw/2)-(s(980, scale)/2)), ry: s(70, scale), comp: "settings/SettingsApp.qml" },
        "appearance": { w: s(980, scale), h: s(720, scale), rx: Math.floor((mw/2)-(s(980, scale)/2)), ry: s(70, scale), comp: "settings/SettingsApp.qml" },
        "nightlight": { w: s(980, scale), h: s(720, scale), rx: Math.floor((mw/2)-(s(980, scale)/2)), ry: s(70, scale), comp: "settings/SettingsApp.qml" },
        "input":      { w: s(980, scale), h: s(720, scale), rx: Math.floor((mw/2)-(s(980, scale)/2)), ry: s(70, scale), comp: "settings/SettingsApp.qml" },
        "wallpaper":     { w: s(980, scale), h: s(720, scale), rx: Math.floor((mw/2)-(s(980, scale)/2)), ry: s(70, scale), comp: "settings/SettingsApp.qml" },
        "clipboard":     { w: s(620, scale), h: s(520, scale), rx: Math.floor((mw/2)-(s(620, scale)/2)), ry: Math.floor((mh/2)-(s(520, scale)/2)), comp: "clipboard/ClipboardPopup.qml" },
        "mediaFull":     { w: s(700, scale), h: s(760, scale), rx: s(12, scale), ry: s(58, scale), comp: "music/MusicPopup.qml" },
        "stewart":   { w: s(800, scale), h: s(600, scale), rx: Math.floor((mw/2)-(s(800, scale)/2)), ry: Math.floor((mh/2)-(s(600, scale)/2)), comp: "stewart/stewart.qml" },
        "monitors":  { w: s(980, scale), h: s(720, scale), rx: Math.floor((mw/2)-(s(980, scale)/2)), ry: s(70, scale), comp: "settings/SettingsApp.qml" },
        "focustime": { w: s(900, scale), h: s(720, scale), rx: Math.floor((mw/2)-(s(900, scale)/2)), ry: Math.floor((mh/2)-(s(720, scale)/2)), comp: "focustime/FocusTimePopup.qml" },
        "guide":     { w: s(980, scale), h: s(720, scale), rx: Math.floor((mw/2)-(s(980, scale)/2)), ry: s(70, scale), comp: "settings/SettingsApp.qml" },
        "pollkit":   { w: s(520, scale), h: s(400, scale), rx: Math.floor((mw/2)-(s(520, scale)/2)), ry: Math.floor((mh/2)-(s(400, scale)/2)), comp: "pollkit/UpdaterPopup.qml" },
        "session":   { w: s(680, scale), h: s(280, scale), rx: Math.floor((mw/2)-(s(680, scale)/2)), ry: Math.floor((mh/2)-(s(280, scale)/2)), comp: "session/SessionMenu.qml" },
        "keyboard":  { w: s(250, scale), h: s(170, scale), rx: mw - s(330, scale), ry: s(58, scale), comp: "keyboard/KeyboardPopup.qml" },
        "spotlight": { w: s(660, scale), h: s(460, scale), rx: Math.floor((mw/2)-(s(660, scale)/2)), ry: Math.floor((mh/2)-(s(460, scale)/2)), comp: "launcher/SpotlightLauncher.qml" },
        "launchpad": { w: s(820, scale), h: s(540, scale), rx: Math.floor((mw/2)-(s(820, scale)/2)), ry: Math.floor((mh/2)-(s(540, scale)/2)), comp: "launcher/Launchpad.qml" },
        "launcher":  { w: s(820, scale), h: s(540, scale), rx: Math.floor((mw/2)-(s(820, scale)/2)), ry: Math.floor((mh/2)-(s(540, scale)/2)), comp: "launcher/Launchpad.qml" },
        "menu":      { w: s(820, scale), h: s(540, scale), rx: Math.floor((mw/2)-(s(820, scale)/2)), ry: Math.floor((mh/2)-(s(540, scale)/2)), comp: "launcher/Launchpad.qml" },
        "emoji":     { w: s(480, scale), h: s(440, scale), rx: Math.floor((mw/2)-(s(480, scale)/2)), ry: Math.floor((mh/2)-(s(440, scale)/2)), comp: "emoji/EmojiPickerPopup.qml" },
        "settings":  { w: s(980, scale), h: s(720, scale), rx: Math.floor((mw/2)-(s(980, scale)/2)), ry: s(70, scale), comp: "settings/SettingsApp.qml" },
        "zones":     { w: s(760, scale), h: s(520, scale), rx: Math.floor((mw/2)-(s(760, scale)/2)), ry: Math.floor((mh/2)-(s(520, scale)/2)), comp: "zones/FancyZonesOverlay.qml" },
        "ruler":     { w: s(820, scale), h: s(580, scale), rx: Math.floor((mw/2)-(s(820, scale)/2)), ry: Math.floor((mh/2)-(s(580, scale)/2)), comp: "ruler/ScreenRulerOverlay.qml" },
        "shelf":     { w: s(640, scale), h: s(480, scale), rx: mw - s(660, scale), ry: mh - s(510, scale), comp: "shelf/DropShelf.qml" },
        "quicklook": { w: s(780, scale), h: s(560, scale), rx: Math.floor((mw/2)-(s(780, scale)/2)), ry: Math.floor((mh/2)-(s(560, scale)/2)), comp: "quicklook/QuickLookPopup.qml" },
        "switcher":  { w: s(760, scale), h: s(240, scale), rx: Math.floor((mw/2)-(s(760, scale)/2)), ry: Math.floor((mh/2)-(s(240, scale)/2)), comp: "switcher/WindowSwitcher.qml" },
        "hidden":    { w: 1, h: 1, rx: -5000 - mx, ry: -5000 - my, comp: "" } 
    };

    if (!base[name]) return null;
    
    let t = base[name];
    t.x = mx + t.rx;
    t.y = my + t.ry;
    
    return t;
}

function getPopupLayout(mw, userScale) {
    let scale = getScale(mw, userScale);
    return {
        w: s(350, scale),
        marginTop: s(70, scale),
        marginRight: s(20, scale),
        spacing: s(12, scale),
        radius: s(14, scale),
        padding: s(12, scale)
    };
}
