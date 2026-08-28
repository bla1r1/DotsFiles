pragma Singleton

import QtQuick
import "../WindowRegistry.js" as LayoutMath

// =============================================================================
// THE reference file for the whole shell UI.
//
// Colour, type, shape, motion and scale — one place, one import.
// Provides both semantic design-system tokens and the rich Catppuccin /
// Material You palette for vibrant, modern rice aesthetics.
// =============================================================================

QtObject {
    id: root

    component FontScale: QtObject {
        readonly property int caption: 11   // metadata, units, timestamps
        readonly property int body: 13      // standard UI working size
        readonly property int subhead: 15   // card titles, device names
        readonly property int title: 18     // section / page titles
        readonly property int display: 24   // popup headlines, hero numbers

        readonly property string sans: "Fira Sans"
        readonly property string mono: "JetBrainsMono Nerd Font"
        // The "Mono" cut, deliberately: in the plain Nerd Font the icon glyphs
        // are drawn inside a double-width advance with the ink hugging the left
        // of it, so centring the text box leaves every glyph sitting left of
        // centre. NFM gives each icon a single cell, and the box centre is the
        // glyph centre.
        readonly property string icon: "JetBrainsMono Nerd Font Mono"
    }

    component WeightScale: QtObject {
        readonly property int regular: Font.Normal     // 400
        readonly property int medium: Font.Medium      // 500
        readonly property int semibold: Font.DemiBold  // 600
        readonly property int bold: Font.Bold          // 700
    }

    component RadiusScale: QtObject {
        readonly property int ctl: 10     // buttons, fields, list rows, sliders
        readonly property int card: 14    // cards, quick-tiles
        readonly property int panel: 20   // popup panels, main windows
        readonly property int pill: 999   // toggles, chips, status pills
    }

    component SpaceScale: QtObject {
        readonly property int xs: 4
        readonly property int sm: 8
        readonly property int md: 12
        readonly property int lg: 16
        readonly property int xl: 24
        readonly property int xxl: 32
    }

    // Fixed heights that repeat across the shell. Before this scale the same
    // control was Design.s(34), s(36) and s(38) in three files, so nothing in a
    // row lined up with anything else in it.
    component SizeScale: QtObject {
        readonly property int iconBtn: 28   // round header / media button
        readonly property int knob: 36      // circular toggle inside a tile
        readonly property int row: 38       // one-line list row, square button
        readonly property int ctl: 38       // slider, field, capsule control
        readonly property int rowTall: 44   // two-line list row
        readonly property int action: 36    // bottom action button
        readonly property int art: 48       // album art
        readonly property int tile: 56      // quick tile
        readonly property int media: 76     // media card
    }

    component DurationScale: QtObject {
        readonly property int fast: 150   // pointer response: hover, press
        readonly property int base: 250   // state change: toggle, selection
        readonly property int slow: 400   // window enter / exit
    }

    component OpacityScale: QtObject {
        readonly property real disabled: 0.38
        readonly property real muted: 0.62
        readonly property real full: 1.0
    }

    component ShadowSpec: QtObject {
        readonly property color tone: "#000000"
        readonly property real blur: 0.6
        readonly property real blurStrong: 1.0
        readonly property real opacity: 0.5
    }

    // =========================================================================
    // SCALE
    // =========================================================================
    property real screenWidth: 1920
    property real uiScale: 1.0

    readonly property real scale: LayoutMath.getScale(screenWidth, uiScale)

    function s(val) {
        return LayoutMath.s(val, root.scale);
    }

    // =========================================================================
    // COLOUR & PALETTE
    // =========================================================================
    // Dynamic values arrive from matugen or fallback to Catppuccin Mocha.

    // ── Surfaces ─────────────────────────────────────────────────────────────
    readonly property color ground: _p.ground     // backdrop ground
    readonly property color sunken: _p.lowest     // recessed tracks, input fields
    readonly property color surface: _p.low       // popup / panel base
    readonly property color raised: _p.mid        // cards, tiles
    readonly property color hover: _p.high        // hover highlight, active surface
    readonly property color active: _p.highest    // pressed / selected item

    // ── Text & Content ───────────────────────────────────────────────────────
    readonly property color text: _p.text
    readonly property color textDim: _p.textDim
    readonly property color textFaint: _p.outline

    // ── Lines & Borders ──────────────────────────────────────────────────────
    readonly property color line: _p.outlineVariant

    // ── Primary Accent ───────────────────────────────────────────────────────
    readonly property color accent: _p.primary
    readonly property color accentText: _p.primaryText
    readonly property color accentSoft: _p.primaryBox
    readonly property color accentAlt: _p.tertiary

    // ── Rich Semantic Palette ────────────────────────────────────────────────
    readonly property color blue: _p.blue
    readonly property color sapphire: _p.sapphire
    readonly property color mauve: _p.mauve
    readonly property color pink: _p.pink
    readonly property color peach: _p.peach
    readonly property color yellow: _p.yellow
    readonly property color green: _p.green
    readonly property color teal: _p.teal
    readonly property color cyan: _p.teal
    readonly property color red: _p.red
    readonly property color maroon: _p.maroon
    readonly property color lavender: _p.lavender

    // ── Status Colours ───────────────────────────────────────────────────────
    readonly property color ok: _p.green
    readonly property color warn: _p.peach
    readonly property color danger: _p.red
    readonly property color dangerText: _p.errorText

    // Tint helper
    function tint(c, alpha) {
        if (!c) return Qt.rgba(0, 0, 0, alpha !== undefined ? alpha : 1.0);
        if (typeof c === "object" && c.r !== undefined) {
            return Qt.rgba(c.r, c.g, c.b, alpha !== undefined ? alpha : 1.0);
        }
        let s = String(c).trim();
        if (s.startsWith("#") && s.length >= 7) {
            let r = parseInt(s.substring(1, 3), 16) / 255.0;
            let g = parseInt(s.substring(3, 5), 16) / 255.0;
            let b = parseInt(s.substring(5, 7), 16) / 255.0;
            return Qt.rgba(r, g, b, alpha !== undefined ? alpha : 1.0);
        }
        return Qt.rgba(0.5, 0.5, 0.5, alpha !== undefined ? alpha : 1.0);
    }

    // Readable text on an arbitrary fill.
    function contrastOn(c) {
        let r = 0.5, g = 0.5, b = 0.5;
        if (typeof c === "object" && c.r !== undefined) {
            r = c.r; g = c.g; b = c.b;
        } else if (String(c).startsWith("#") && String(c).length >= 7) {
            let s = String(c).trim();
            r = parseInt(s.substring(1, 3), 16) / 255.0;
            g = parseInt(s.substring(3, 5), 16) / 255.0;
            b = parseInt(s.substring(5, 7), 16) / 255.0;
        }
        return (0.299 * r + 0.587 * g + 0.114 * b) > 0.55 ? _p.ground : _p.text;
    }

    // ── Glassmorphic & Translucency Tokens ────────────────────────────────────
    readonly property color glassBg: tint(surface, 0.88)
    readonly property color glassCard: tint(raised, 0.65)
    readonly property color glassTile: tint(raised, 0.55)
    readonly property color glassBorder: tint(text, 0.12)
    readonly property color glassHover: tint(text, 0.08)
    readonly property color glassActive: tint(accent, 0.20)

    readonly property color veil: tint(text, 0.05)
    readonly property color veilStrong: tint(text, 0.10)
    readonly property color veilBold: tint(text, 0.16)

    // =========================================================================
    // TYPE & SHAPE
    // =========================================================================
    readonly property FontScale font: FontScale {}
    readonly property WeightScale weight: WeightScale {}
    readonly property RadiusScale radius: RadiusScale {}
    readonly property SpaceScale space: SpaceScale {}
    readonly property SizeScale size: SizeScale {}
    readonly property DurationScale duration: DurationScale {}
    readonly property OpacityScale opacity: OpacityScale {}
    readonly property ShadowSpec shadow: ShadowSpec {}

    readonly property int border: 1
    readonly property int easing: Easing.OutCubic
    readonly property int blurMax: 64

    // =========================================================================
    // LOADING & PALETTE PARSER
    // =========================================================================
    readonly property bool loaded: _p.loaded

    function reload() {
        paletteReader.running = false;
        paletteReader.running = true;
    }

    property QtObject _p: QtObject {
        property bool loaded: false

        property color ground: "#1e1e2e"
        property color lowest: "#11111b"
        property color low: "#181825"
        property color mid: "#313244"
        property color high: "#45475a"
        property color highest: "#585b70"

        property color text: "#cdd6f4"
        property color textDim: "#a6adc8"
        property color outline: "#6c7086"
        property color outlineVariant: "#45475a"

        property color primary: "#89b4fa"
        property color primaryText: "#11111b"
        property color primaryBox: "#45475a"
        property color tertiary: "#cba6f7"

        property color error: "#f38ba8"
        property color errorText: "#11111b"

        property color blue: "#89b4fa"
        property color sapphire: "#74c7ec"
        property color mauve: "#cba6f7"
        property color pink: "#f5c2e7"
        property color peach: "#fab387"
        property color yellow: "#f9e2af"
        property color green: "#a6e3a1"
        property color teal: "#94e2d5"
        property color red: "#f38ba8"
        property color maroon: "#eba0ac"
        property color lavender: "#b4befe"
    }

    function _applyPalette(txt) {
        const c = _parse(txt);
        if (!c)
            return;

        const set = (key, ...names) => {
            for (const n of names) {
                if (c[n]) {
                    root._p[key] = c[n];
                    return;
                }
            }
        };

        set("ground", "ground", "crust");
        set("lowest", "sunken", "base");
        set("low", "surface", "mantle");
        set("mid", "raised", "surface0");
        set("high", "hover", "surface1");
        set("highest", "active", "surface2");

        set("text", "text");
        set("textDim", "textDim", "subtext0");
        set("outline", "textFaint", "overlay0");
        set("outlineVariant", "line", "surface1");

        set("primary", "accent", "blue");
        set("primaryText", "accentText", "onAccent");
        set("primaryBox", "accentSoft", "sapphire");
        set("tertiary", "accentAlt", "mauve");

        set("error", "danger", "red");
        set("errorText", "dangerText", "onDanger");

        set("blue", "blue");
        set("sapphire", "sapphire");
        set("mauve", "mauve");
        set("pink", "pink");
        set("peach", "peach");
        set("yellow", "yellow");
        set("green", "green");
        set("teal", "teal");
        set("red", "red");
        set("maroon", "maroon");
        set("lavender", "lavender");

        root._p.loaded = true;
    }

    // Legacy aliases
    readonly property color base: surface
    readonly property color mantle: sunken
    readonly property color crust: ground
    readonly property color subtext0: textDim
    readonly property color subtext1: textDim
    readonly property color surface0: raised
    readonly property color surface1: hover
    readonly property color surface2: active
    readonly property color overlay0: textFaint
    readonly property color overlay1: textFaint
    readonly property color overlay2: textFaint
}
