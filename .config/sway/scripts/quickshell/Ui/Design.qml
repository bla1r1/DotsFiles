pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import "../WindowRegistry.js" as LayoutMath

// =============================================================================
// THE reference file for the whole shell UI.
//
// Colour, type, shape, motion and scale — one place, one import. If a value
// controls how the UI looks, it lives here or it is a bug.
//
// Nothing here is invented: every scale value is the most-used value of its
// kind in the popups as they stood, extracted from 808 `duration`, 435
// `pixelSize` and 333 `radius` literals. Most migrated code lands on the scale
// without retuning.
//
// Replaces the per-popup `MatugenColors {}` + `Scaler {}` pair. That pattern
// gave every popup its own copy and its own Process reading the same two files
// — eleven readers for one palette, free to drift apart.
//
//   import "../Ui"
//   Rectangle {
//       color: Design.raised
//       radius: Design.s(Design.radius.card)
//   }
//
// See docs/design-system.md for the rule that keeps this the only source of truth.
// =============================================================================

Singleton {
    id: root

    // Groups are inline components rather than bare QtObject so they carry a
    // real type. Declared as QtObject their members were invisible to every
    // checker, and `Design.font.captionn` would read as undefined at runtime
    // without a word.

    component FontScale: QtObject {
        readonly property int caption: 11   // metadata, units, timestamps
        readonly property int body: 13      // the working size
        readonly property int subhead: 16   // card titles, device names
        readonly property int title: 20     // page titles
        readonly property int display: 28   // popup headline

        readonly property string sans: "Fira Sans"
        readonly property string mono: "JetBrainsMono Nerd Font"
        readonly property string icon: "JetBrainsMono Nerd Font"
    }

    // `bold` is the ceiling on purpose: the popups reached for Font.Black 51
    // times, but JetBrains Mono stops at ExtraBold — there is no 900 in the
    // family, so Qt was substituting or synthesising every time.
    component WeightScale: QtObject {
        readonly property int regular: Font.Normal     // 400 — body
        readonly property int medium: Font.Medium      // 500 — emphasis in body
        readonly property int semibold: Font.DemiBold  // 600 — headings
        readonly property int bold: Font.Bold          // 700 — heaviest real weight
    }

    // 10 radii collapse to 3. `pill` is not a step, it means round.
    component RadiusScale: QtObject {
        readonly property int ctl: 8      // button, field, list row
        readonly property int card: 12    // card on a panel
        readonly property int panel: 18   // the popup window itself
        readonly property int pill: 999   // toggles, chips
    }

    component SpaceScale: QtObject {
        readonly property int xs: 4
        readonly property int sm: 8
        readonly property int md: 12
        readonly property int lg: 16
        readonly property int xl: 24
        readonly property int xxl: 32
    }

    // 72 durations collapse to 3. These never scale with screen size:
    // 250ms is 250ms on any monitor.
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

    // MultiEffect params drifted the same way durations did: shadowBlur across
    // 0.5 / 0.6 / 1.0 / 1.2, shadowOpacity across six values.
    component ShadowSpec: QtObject {
        readonly property color tone: "#000000"  // a shadow is black in any theme
        readonly property real blur: 0.6
        readonly property real blurStrong: 1.0
        readonly property real opacity: 0.5
    }

    // =========================================================================
    // SCALE
    // =========================================================================
    // ponytail: one global scale. Main.qml is a single window on a single
    // active screen, so per-screen scale would buy nothing today. If mixed-DPI
    // multi-monitor ever matters, this becomes a property on PopupShell and
    // components take it from their parent.

    // Both are pushed in by PopupShell. Design is the token layer: it must not
    // depend on Services, or the dependency runs backwards — the thing that
    // defines how the UI looks would need to know where settings are stored.
    property real screenWidth: 1920
    property real uiScale: 1.0

    readonly property real scale: LayoutMath.getScale(screenWidth, uiScale)

    function s(val) {
        return LayoutMath.s(val, root.scale);
    }

    // =========================================================================
    // COLOUR — by role, not by hue
    // =========================================================================
    // `mauve` makes every popup pick a colour by taste. `accentAlt` means the
    // choice was made once. Values arrive from matugen; fallbacks below are
    // Catppuccin Mocha, used until /tmp/qs_colors.json exists.
    //
    // Colours sit at the top level because they are by far the most-referenced
    // thing here — `Design.accent`, not `Design.color.accent`.

    // ── Surfaces, dark → light ───────────────────────────────────────────────
    readonly property color ground: _p.ground     // window ground
    readonly property color sunken: _p.lowest     // recessed: tracks, headers
    readonly property color surface: _p.low       // popup / panel body
    readonly property color raised: _p.mid        // card on a panel
    readonly property color hover: _p.high        // pointer-over, control fill
    readonly property color active: _p.highest    // pressed, selected row

    // ── Text ─────────────────────────────────────────────────────────────────
    readonly property color text: _p.text
    readonly property color textDim: _p.textDim
    readonly property color textFaint: _p.outline

    // ── Lines ────────────────────────────────────────────────────────────────
    readonly property color line: _p.outlineVariant

    // ── Accent ───────────────────────────────────────────────────────────────
    // One accent. `accentAlt` is a second simultaneous selection level, not
    // variety. If an element wants a colour "to look nice", it gets `accent`.
    readonly property color accent: _p.primary
    readonly property color onAccent: _p.onPrimary      // text ON an accent fill
    readonly property color accentSoft: _p.primaryBox   // tinted accent surface
    readonly property color accentAlt: _p.tertiary

    // ── State — status, never decoration ─────────────────────────────────────
    // `ok` and `warn` are deliberately NOT derived from the wallpaper: on red
    // wallpaper "connected" would go red and "charging" orange. `danger`
    // follows matugen because Material You's error role already reads as alarm.
    readonly property color ok: "#a6e3a1"
    readonly property color warn: "#fab387"
    readonly property color danger: _p.error
    readonly property color onDanger: _p.onError

    // Tinted status surface — the "NEW UPDATE AVAILABLE" badge pattern, which
    // every popup currently rebuilds by hand with Qt.rgba(c.r, c.g, c.b, 0.1).
    function tint(c, alpha) {
        return Qt.rgba(c.r, c.g, c.b, alpha);
    }

    // ── Veil — translucent layer over glass ──────────────────────────────────
    // Popups wrote this as literal white with seven different alphas
    // (#05ffffff … #33ffffff) for one idea. Literal white also inverts on a
    // light matugen palette; tinting with `text` follows the theme.
    //
    // Three steps, by how present the layer is — usable as fill or as hairline:
    //   veil       resting surface: a card at rest, a slider well
    //   veilStrong engaged surface: hover fill, hairline on glass
    //   veilBold   asserted: a toggled-on fill, a divider
    readonly property color veil: tint(text, 0.05)
    readonly property color veilStrong: tint(text, 0.10)
    readonly property color veilBold: tint(text, 0.16)

    // =========================================================================
    // TYPE
    // =========================================================================
    // 16 sizes collapse to 5. Sizes are UNSCALED — wrap in s() at use.
    //
    // Families are tokens for a reason: the popups asked for "Iosevka Nerd
    // Font" 120 times and "JetBrains Mono" 310 times, and the installer ships
    // neither name — ttf-jetbrains-mono-nerd provides "JetBrainsMono Nerd
    // Font". Both were resolving through fontconfig fallback. One installed
    // family covers mono text and nerd icons alike, so Iosevka is gone.

    readonly property FontScale font: FontScale {}

    // Four weights, and `bold` is the ceiling on purpose: the popups reached for
    // Font.Black 51 times, but JetBrains Mono stops at ExtraBold — there is no
    // 900 in the family, so Qt was substituting or synthesising every time.
    // Verify with: fc-list "JetBrainsMono Nerd Font" | sed 's/.*://'
    readonly property WeightScale weight: WeightScale {}

    // =========================================================================
    // SHAPE
    // =========================================================================
    // 10 radii collapse to 3. `pill` is not a step on the scale, it means round.

    readonly property RadiusScale radius: RadiusScale {}

    readonly property SpaceScale space: SpaceScale {}

    readonly property int border: 1

    // =========================================================================
    // MOTION
    // =========================================================================
    // 72 durations collapse to 3. Durations never scale with screen size:
    // 250ms is 250ms on any monitor.

    readonly property DurationScale duration: DurationScale {}

    // One curve. Reach for another only with a reason.
    // NOTE: this is `Easing.OutCubic`, not `Qt.OutCubic` — the latter is
    // undefined and silently degrades the animation to Linear, which is what
    // four animations in UpdaterPopup were doing.
    readonly property int easing: Easing.OutCubic

    readonly property OpacityScale opacity: OpacityScale {}

    // ── Depth ────────────────────────────────────────────────────────────────
    // MultiEffect params drifted the same way durations did: shadowBlur across
    // 0.5 / 0.6 / 1.0 / 1.2, shadowOpacity across six values, blurMax 32 vs 80.
    // Tokens rather than a wrapper component — MultiEffect is already
    // declarative, and wrapping it would only add indirection.
    //
    //   MultiEffect {
    //       shadowEnabled: true
    //       shadowColor: Design.shadow.tone
    //       shadowBlur: Design.shadow.blur
    //       shadowOpacity: Design.shadow.opacity
    //   }
    readonly property ShadowSpec shadow: ShadowSpec {}

    // Blur budget for `layer.effect: MultiEffect { blurEnabled: true }`.
    readonly property int blurMax: 64

    // =========================================================================
    // LOADING
    // =========================================================================

    readonly property bool loaded: _p.loaded

    function reload() {
        paletteReader.running = false;
        paletteReader.running = true;
    }

    // Parsed palette. Kept as a child object so every role above stays a
    // binding — assigning here repaints the whole shell in one pass.
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
        property color onPrimary: "#11111b"
        property color primaryBox: "#45475a"
        property color tertiary: "#cba6f7"

        property color error: "#f38ba8"
        property color onError: "#11111b"
    }

    function _applyPalette(txt) {
        const c = _parse(txt);
        if (!c)
            return;

        // `role, legacy` — the matugen template emits both during migration.
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
        set("onPrimary", "onAccent");
        set("primaryBox", "accentSoft", "sapphire");
        set("tertiary", "accentAlt", "mauve");

        set("error", "danger", "red");
        set("onError", "onDanger");

        root._p.loaded = true;
    }

    function _parse(txt) {
        txt = (txt || "").trim();
        const start = txt.indexOf("{");
        const end = txt.lastIndexOf("}");
        if (start < 0 || end < start)
            return null;
        try {
            return JSON.parse(txt.slice(start, end + 1));
        } catch (e) {
            // Malformed input: keep the last good values rather than go blank.
            console.warn("Design: cannot parse —", e);
            return null;
        }
    }

    // ponytail: Process+cat, the same call the old MatugenColors and Scaler
    // used — proven on this setup. Quickshell's FileView with watchChanges
    // would drop the fork and make reloads automatic; swap it in once the
    // singletons are confirmed working on the real box.
    property Process paletteReader: Process {
        command: ["cat", "/tmp/qs_colors.json"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: root._applyPalette(this.text)
        }
    }


    // =========================================================================
    // LEGACY NAMES — delete once no popup references them
    // =========================================================================
    // Lets a popup switch to `Design.` before its colours are renamed, so the
    // two changes stay separate commits.
    //
    // Several were always aliases anyway: the matugen template maps blue and
    // mauve both to primary, green and teal both to secondary, and all three
    // overlays to inverse_surface. 22 names, ~15 real colours.
    //
    //   grep -rn "Design\.\(base\|mantle\|crust\|surface[012]\|overlay[012]\)" --include='*.qml' .

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
    readonly property color blue: accent
    readonly property color mauve: accentAlt
    readonly property color sapphire: accentSoft
    readonly property color pink: accentAlt
    readonly property color peach: warn
    readonly property color yellow: warn
    readonly property color green: ok
    readonly property color teal: ok
    readonly property color red: danger
    readonly property color maroon: danger
}
