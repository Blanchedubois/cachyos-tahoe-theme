# CachyOS Tahoe Theme: implementation plan

A KDE Plasma 6 theme for CachyOS that keeps the macOS Tahoe glass experience
(translucent top bar, glass dock, frosted popups) while replacing every app
icon, action icon, and panel icon with a single heavy, rounded glyph language,
and unifying corner rounding across windows, widgets, and menus.

Status legend: `[ ]` not started, `[~]` in progress, `[x]` done, `[?]` needs a
decision.

## 1. Decisions already made

| Topic | Decision |
|---|---|
| Base theme | MacTahoe-kde dark (vinceliuice) for colours, Plasma style, panel and dock |
| Window decoration | Darkly's native decoration: no outline, no side borders, large shadow, line glyphs for close, minimise, maximise on the left. The Aurorae hybrid was retired after it double-drew the frame; see docs/IMPACT.md Phase A |
| Application style | Darkly, single corner radius, opaque menus and bars |
| Window clipping | KDE Rounded Corners effect so client-drawn windows match |
| Glyph source | Material Symbols Rounded, weight 700, as primary. Phosphor Bold where a stroke-style glyph fits better. No SF Symbols: Apple's licence forbids redistribution. |
| Brand apps | Keep the brand mark, place it on the Tahoe squircle with the glass treatment and a brand-derived colour |
| Steam | Untouched. Steam and Steam-launched games fall through to their own icons |
| Background colours | Category palette: one hue per category, tonal shifts within it |
| Repo | github.com/Blanchedubois/cachyos-tahoe-theme |

## 2. Design tokens

Everything downstream reads from `tokens/`. Change a token, re-run the
generators, and the whole theme moves together.

### 2.1 Rounding scale

The current state is 14 px windows and 8 px widgets. The user asked for "a
decent amount of rounding but not too much", so the proposal steps down one
notch at the window level and keeps the ratio.

| Element | Radius | Where it is set |
|---|---|---|
| Window frame | 12 px | Aurorae decoration SVG, Rounded Corners `Size` |
| Panel popups, Kickoff, tray | 12 px | MacTahoe Plasma style `dialogs/background.svg` |
| App icons | squircle, Apple superellipse | icon generator |
| Buttons, inputs, frames, menus | 8 px | Darkly `CornerRadius` |
| Menu items, list highlights | 6 px | Darkly (follows CornerRadius; override in Phase 4 if it looks heavy) |
| Tooltips | 8 px | Plasma style |

`[?]` Confirm 12 px windows. Leaving it at 14 is a one-line change.

### 2.2 Outline and glass

| Token | Value |
|---|---|
| Frame | Kept light, per review: a 12 px rounded window with Darkly's titlebar as shipped and one faint 1 px light hairline just outside the edge, drawn by the Rounded Corners effect. No decoration border, no band, no inset. The border and inset experiments are recorded in docs/IMPACT.md Phase E and rejected as looking heavy |
| Titlebar fill | follows colour scheme window background |
| Glass surfaces | top panel, dock, popups: MacTahoe blur, tint `#1c1c1e` at 72 percent |
| Highlight band | 1 px `#ffffff` at 10 percent along the top inside edge of glass surfaces |

### 2.3 Glyph weight

| Set | Weight | Size grid |
|---|---|---|
| Material Symbols Rounded | wght 700, fill 1 for app glyphs, fill 0 for actions | 24 px optical |
| Phosphor Bold | bold | 256 unit grid, scaled to 24 |

Both are rendered white on dark and recoloured by KDE's stylesheet classes
where the icon is symbolic.

### 2.4 Category palette

Hues follow macOS conventions so the dock reads the way users expect.
Each category has a base and a lighter top stop for the gradient.

| Category | Base | Top stop | Examples |
|---|---|---|---|
| System and settings | `#5a5f66` graphite | `#80868e` | System Settings, Info Center, Kernel Manager, Btrfs Assistant |
| Files | `#2f7cf6` blue | `#5b9bff` | Dolphin, Filelight, Ark |
| Terminal and dev tools | `#1f2937` ink | `#374151` | Konsole, Alacritty, btop, Kate, KWrite, CMake, Qt tools |
| Media | `#ff6b35` orange | `#ff8f5c` | mpv, VLC, Haruna, SMPlayer, Gwenview, OBS |
| Communication | `#34c759` green | `#5fd97a` | KDE Connect, Telegram, Discord (brand on green shell) |
| Internet | `#0a84ff` sky | `#4da3ff` | Firefox, Brave, Chromium (brand marks kept) |
| Games and compatibility | `#c13b3b` red | `#e05a5a` | Lutris, Heroic, Faugus, Wine tools, Protontricks |
| Utilities | `#8e8e93` silver | `#aeaeb2` | KCalc, Spectacle, Emoji Selector, scrcpy, Micro, Vim |
| Hardware and printing | `#6e5acb` violet | `#8f7ee0` | NVIDIA Settings, HP tools, Printing, lstopo |
| Security and storage | `#b58900` amber | `#d4a827` | KWalletManager, Partition Manager, Limine snapper |
| CachyOS branded | `#1aa3c6` teal | `#45bfe0` | CachyOS Hello, Package Installer, Cachy-Update, SchedExt |

Full table with per-app assignments lives in `tokens/apps.json`.

## 3. Icon system

### 3.1 App icons: the generator

`scripts/gen-app-icons.py` reads `tokens/apps.json` and emits an icon theme
`icons/Tahoe-Material/` with `apps/scalable/*.svg` plus rasterised
`16, 22, 24, 32, 48, 64, 128, 256` PNGs.

Composition, bottom to top:

1. **Squircle**. Apple's superellipse at Tahoe proportions, 1024 unit grid,
   corner continuity n = 5. Same path for every icon.
2. **Base gradient**. Category top stop at the top to base at the bottom,
   vertical, with a slight hue rotation toward warm at the bottom so it reads
   as lit from above.
3. **Glass body**. Inner highlight band across the upper third, white at 18
   percent fading to 0, blurred 24 units. A soft inner shadow along the lower
   edge, black at 22 percent, blurred 30 units. This is the liquid-glass read:
   thick, lit, slightly refractive.
4. **Rim**. 1 unit inset stroke, white at 14 percent on top fading to black at
   18 percent at the bottom, so the edge catches light.
5. **Glyph**. Material Symbols Rounded wght 700 fill 1, white, sized to 56
   percent of the squircle width, centred, with a 2 unit drop shadow at 25
   percent. For brand apps the brand mark replaces the glyph at 60 percent and
   keeps its own colours; the shell colour is sampled from the mark's dominant
   hue and desaturated 20 percent.
6. **Specular**. A small elliptical highlight top-left, white at 12 percent,
   blurred. Subtle; off for glyph-heavy icons if it fights the mark.

Output is a plain SVG using only gradients, filters and paths, so it renders
identically in rsvg, Qt, and browsers.

### 3.2 Action and status icons

`scripts/gen-action-icons.py` maps freedesktop and Breeze action names to
Material or Phosphor glyphs via `tokens/actions.json`, then writes symbolic
SVGs into `actions/16, 22, 24, 32` and `status/`, `places/`, `devices/`,
`emblems/` as needed. Each SVG carries KDE's stylesheet block so it recolours
with the colour scheme:

```
<style id="current-color-scheme">.ColorScheme-Text { color:#e0e0e0; }</style>
<path class="ColorScheme-Text" fill="currentColor" d="..."/>
```

The theme inherits `MacTahoe-dark, breeze` so anything unmapped still resolves.

Coverage targets, in priority order:

1. Panel and tray: network, volume, bluetooth, battery, clipboard, updates,
   notifications, display, keyboard layout, media player, show desktop.
2. Titlebar and toolbar actions: back, forward, up, home, view modes, split,
   search, menu, settings, new tab, close, split view, zoom.
3. Menus: file, edit, view, go, tools, settings, help, and the common verbs
   inside them (open, save, copy, paste, cut, undo, redo, find, print).
4. Places and devices: home, desktop, documents, downloads, music, pictures,
   videos, trash, network, removable drive, disk.
5. Dialogs: ok, cancel, apply, warning, error, info, question.

### 3.3 Mapping conventions

Material names first. Phosphor only when Material lacks the shape or draws it
too soft. A few examples so the table reads consistently:

| Freedesktop name | Glyph | Set |
|---|---|---|
| `go-previous` | `arrow_back` | Material |
| `edit-copy` | `content_copy` | Material |
| `view-list-details` | `view_list` | Material |
| `utilities-terminal` | `terminal` | Material |
| `network-wireless` | `wifi` | Material |
| `audio-volume-high` | `volume_up` | Material |
| `preferences-system` | `settings` | Material |
| `application-menu` | `dots-three-outline` | Phosphor |

## 4. Panel and chrome cleanup

Phased so each step can be checked on screen before the next.

### 4.1 Top panel

Current widgets, in order: Kickoff, global app menu, spacer, margins
separator, system tray, margins separator, digital clock, show desktop.

| Step | Change | Check |
|---|---|---|
| P1 | Height 32 px, floating off so it hugs the top edge like macOS | panel sits flush, no gap |
| P2 | Kickoff icon: CachyOS mark at 22 px, no label | mark is centred vertically |
| P3 | App menu: Darkly menubar padding 10 px horizontal, 0 vertical | items do not look stacked |
| P4 | Remove the second margins separator; tray and clock share one margin | no double gap before the clock |
| P5 | Tray icon spacing 6 px, icons from the new symbolic set at 22 px | all tray glyphs same weight |
| P6 | Clock: Noto Sans Semibold 13, 24 hour, no date on panel | no clipping at 32 px |
| P7 | Remove show desktop; its role moves to a hot corner | nothing dangling on the right |

### 4.2 Dock

Keep MacTahoe's glass dock as is. Only the icons change, which happens for free
once the icon theme is active.

### 4.3 Windows

| Step | Change |
|---|---|
| W1 | Regenerate `MacTahoe-Graphite-Dark/decoration.svg` at the token radius |
| W2 | Rounded Corners `Size` and `InactiveCornerRadius` to the same radius |
| W3 | Titlebar height 32 px total, buttons 14 px with 8 px spacing |
| W4 | Darkly radius to the widget token, menu item radius to the item token |
| W5 | Plasma style popups to the popup token |

## 5. Other design changes to workshop

These are proposals, not commitments. Each needs a yes before it is built.

| Idea | Why | Cost |
|---|---|---|
| `[?]` UI font to Inter | Closer to SF Pro metrics than Noto Sans, better at 13 px | one package, one kdeglobals change |
| `[?]` Accent colour `#0a84ff` system-wide | Ties highlights to the Internet hue and Tahoe's blue | one setting |
| `[?]` Konsole profile with the ink palette | Terminal matches its icon | one profile file |
| `[?]` Firefox userChrome for the tab bar | Firefox is the odd one out visually | small CSS file, needs a pref toggle |
| `[?]` SDDM and lock screen from MacTahoe with the new wallpaper | Login matches the desktop | ships with MacTahoe, needs root to install |
| `[?]` Hot corner top-left for Overview | Replaces show desktop, matches macOS Mission Control muscle memory | one KWin setting |
| `[?]` Kickoff replaced by a compact launcher | Kickoff's two-pane layout is the least Tahoe-like part of the shell | third-party widget, risk of breakage |

## 6. Phases

### Phase 0: repo and tokens `[x]`

- [x] Repo scaffold, current decoration, Darkly, Rounded Corners config captured
- [x] `tokens/palette.json`, `tokens/radius.json`, `tokens/apps.json`
- [x] `install.sh` that applies everything per-user without root
- [x] First push

### Phase 1: app icon generator `[x]` awaiting review

- [x] `scripts/fetch-glyphs.py` pulls Material and Phosphor SVGs by name into `glyphs/`
- [x] `scripts/gen-app-icons.py` with the composition in 3.1
- [x] Icons for all visible desktop entries except Steam: 67 unique icons
- [x] Contact sheet `docs/contact-sheet.png` for review
- [x] Desktop entry overrides for Avahi (shared `network-wired` icon) and HP tools (absolute icon paths)
- Acceptance: every dock and Kickoff icon is on a squircle, glass read is visible at 48 px, brand marks are recognisable, Steam unchanged
- Review notes: Claude's brand mark has generous built-in padding so it reads smaller than its neighbours; a per-app `scale` override is the fix if it bothers you

### Phase 2: action and status icons `[x]` awaiting review

- [x] `tokens/actions.json`: 385 entries with aliases across actions, status, places, devices, emblems
- [x] `scripts/gen-action-icons.py`: symbolic SVGs with KDE's colour-scheme stylesheet, `FollowsColorScheme=true`
- [x] Theme `index.theme` with inheritance chain MacTahoe-dark, breeze-dark, breeze, hicolor
- [x] Verified: Dolphin toolbar and Places sidebar, tray (notifications, clipboard, volume, bluetooth, brightness, USB, keyboard, wifi) all on the heavy Material set
- Design call: every symbolic context uses the outlined cut, per review. Filled glyphs were tried first and read too heavy in the tray and sidebar
- Design call: no places context at all, per review. Folders, home, desktop, trash and network places stay MacTahoe's coloured Tahoe icons in both the sidebar and file views. Devices remain outlined
- Lesson: never ship one-word generic aliases such as `user` or `network`. KIconLoader tries shortened names inside the current theme before consulting parents, so `user-home` resolved to our `user` glyph instead of MacTahoe's home. Thirty such aliases were pruned
- App glyphs enlarged from 56 to 68 percent of the squircle, brand marks from 62 to 74, per review

### Phase 3: panel cleanup `[x]` awaiting review

| Step | Result |
|---|---|
| P1 | Height 32 px, floating off, panel hugs the top edge |
| P2 | Kickoff shows the CachyOS mark as a symbolic glyph, `assets/cachyos-mark.svg`, generated under the name `cachyos-launcher` and also aliased to `start-here-kde` |
| P3 | App menu padding is hard-coded in the applet QML. Left as is; revisit only if a patched applet is worth carrying |
| P4 | Second margins separator removed |
| P5 | Tray icons come from the symbolic set; spacing set to large so one item's hover highlight no longer bleeds into its neighbours |
| P6 | Clock: 24 hour, no date, Noto Sans Semibold 13 |
| P7 | Show desktop removed; Overview on the top-left hot corner instead |

Before and after: `docs/panel-before.png`, `docs/panel-after.png`.
- Acceptance: Dolphin toolbar, Konsole menus, tray, and System Settings sidebar all show the heavy rounded set, recolour with the scheme, nothing falls back to Breeze in those views

### Phase 3: panel cleanup `[ ]`

- [ ] P1 through P7 from 4.1, one screenshot each
- Acceptance: side-by-side before and after in `docs/`

### Phase 4: rounding unification `[~]`

- [x] W1, W2: 12 px on the Darkly decoration and the Rounded Corners effect, Aurorae retired
- [x] W3: Darkly titlebar, default button size, line glyphs
- [x] W4: Darkly widget radius 8 px
- [x] W5: Plasma popups checked on Kickoff. MacTahoe's dialog style rounds the free corners at about the 12 px token and squares the edge that touches the panel, which is Plasma's intended behaviour. No overlay style needed
- Impact analysis of all phases: `docs/IMPACT.md`
- Glyph weight is now a token, `tokens/glyphs.json`, set to 600 per review
- App icons use the watermark glass treatment; brand apps pass through from MacTahoe's Tahoe-style set
- Acceptance: Dolphin, System Settings, and the Claude app window measured at the same radius; menus and buttons at the widget radius

### Phase 5: workshop items `[~]`

- [x] Accent colour `#0a84ff` system-wide, applied by `install.sh`
- [x] Konsole profile "Tahoe" with the ink palette, `config/konsole/`, set as default
- [x] Overview on the top-left hot corner (landed in Phase 3)
- [ ] Inter font: needs `inter-font` from the repos, which is a root install. The installer prints a note when it is missing; set it under Fonts once installed
- [x] Firefox: `config/firefox/user.js` hands the titlebar to KWin so Darkly draws it, and `userChrome.css` flattens the tab strip, rounds tabs and the URL field at the widget radius, and uses the accent for focus. Installed into the default-release profile; the installer skips the step while Firefox runs
- [ ] SDDM and lock screen: root install, not started
- [ ] Kickoff replacement: not started; recommended against for now

## 7. Open questions

1. Window radius: 12 px as proposed, or keep the current 14 px?
2. Is the repo public? It will contain brand marks for Firefox, Discord and others, which is normal for icon themes but worth a conscious yes.
3. Should Flatpak apps be included if any are installed later? The generator can scan Flatpak export directories; off by default.
4. Any of the section 5 proposals you want folded into Phase 1 so they land early?
