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
| Window decoration | Klassy, built for Plasma 6 only from the AUR PKGBUILD (the Plasma 5 half stripped), config in `config/klassyrc`: Material glyphs, no button background or outline in any state, traffic-light icon colours muted at rest and full on hover, corner radius 0 so the Rounded Corners effect alone rounds and outlines the frame (see docs/IMPACT.md Phase F), no window outline, large shadow matched active and inactive, title centred. Darkly remains the application style |
| Application style | Kvantum with NoMansSkyJux, the widget style behind Mystical Blue: flat, near-square, compact. Darkly was the style until Phase 8 |
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
| Window frame | 20 px | Darkly `CornerRadius`, Rounded Corners `Size` |
| Panel popups, Kickoff, tray | 20 px | Tahoe-Material Plasma style overlay, `scripts/gen-plasma-style.py` |
| App icons | squircle, Apple superellipse | icon generator |
| Buttons, inputs, frames, menus | 8 px | Darkly `CornerRadius` |
| Menu items, list highlights | 6 px | Darkly (follows CornerRadius; override in Phase 4 if it looks heavy) |
| Tooltips | 8 px | Plasma style |

`[?]` Confirm 12 px windows. Leaving it at 14 is a one-line change.

### 2.2 Outline and glass

| Token | Value |
|---|---|
| Frame | 20 px rounding on every window through the Rounded Corners effect, matched by Klassy, plus one bright 1 px light hairline on the edge drawn by the effect so client-drawn windows get it too. No border or inset |
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
| P1 | MacTahoe's own bar, per review: 32 px, flush to the top edge, adaptive opacity. The floating and pill variants were tried and reverted. Popups attached to a flush bar square their top edge, which is Plasma's rule and accepted |
| P2 | Kickoff icon: CachyOS mark at 22 px, no label | mark is centred vertically |
| P3 | App menu: Darkly menubar padding 10 px horizontal, 0 vertical | items do not look stacked |
| P4 | Remove the second margins separator; tray and clock share one margin | no double gap before the clock |
| P5 | Tray icons come from the symbolic set; spacing medium |
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
| P1 | MacTahoe's own bar, per review: 32 px, flush to the top edge, adaptive opacity. The floating and pill variants were tried and reverted. Popups attached to a flush bar square their top edge, which is Plasma's rule and accepted |
| P2 | Kickoff shows the CachyOS mark as a symbolic glyph, `assets/cachyos-mark.svg`, generated under the name `cachyos-launcher` and also aliased to `start-here-kde` |
| P3 | App menu padding is hard-coded in the applet QML. Left as is; revisit only if a patched applet is worth carrying |
| P4 | Second margins separator removed |
| P5 | Tray icons come from the symbolic set; spacing medium |
| P6 | Clock: 24 hour, no date, Noto Sans Semibold 13. Calendar card is a compact month grid at 300 by 330 with the events pane and week numbers off; Kickoff's card is 540 by 440 instead of 671 by 517 |
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

### Phase 6: Plasma style overlay `[x]`

`plasma/Tahoe-Material/` is a full copy of MacTahoe-Dark (GPL-3) with three assets replaced. A fallback-only overlay was tried first and made both panels opaque, because the panel's translucent handling did not survive the fallback. The replaced assets:

- `dialogs/background`: MacTahoe's own card file with the tint changed from near-black at 65 percent to white at 16 percent, so cards read as the same light frosted glass as the dock
- `widgets/viewitem`: hover, selected and selected+hover highlights as 10 px rounded rectangles inset 3 px from the item edge, generated by `scripts/gen-highlights.py`. Covers the tray hover, Kickoff's sidebar and every Plasma list
- `widgets/tabbar` was also replaced for a while; the inset tab sat flush against the card edge in the calendar's Days and Months switch and was reverted to MacTahoe's own

Two earlier attempts were rejected: a card generated from scratch and a scheme-colour retint. Card internals remain Plasma's QML. Top panel is 30 px.

### Phase 7: widget-style reference survey `[x]`

Twelve well-known Plasma themes compared on button, tab and rounding quality, ranked by GitHub stars and recent activity because the KDE Store's rating pages do not render for fetching. Sheets: `docs/theme-survey.png` (twelve by GitHub stars) and `docs/theme-survey-2.png` (twenty-one more from the KDE Store's rating-sorted listings read in the browser, plus GitHub's most-starred). Reddit blocks fetching, so store scores stand in for community votes. Store leaders: Lightly 9.2 (application styles), Sweet 8.9 and Layan 8.7 (global themes), ROUNDED 8.9 and Sweet 8.9 (Plasma styles), Sweet and Layan 8.8 (Kvantum), MoeDark 7.6 and Klassy 7.5 (decorations). Recommendation for the widget reference: Klassy's application style (installed) for buttons, tabs and spacing, with Material icons; KvLibadwaita as the runner-up for its slider and input language.

### Phase 8: widget style from the Mystical Blue reference `[x]`

Mystical Blue (MIT, juxtopposed) is a Kvantum setup: its widget style is NoMansSkyJux, a modified No Man's Sky Kvantum theme (GPL-3, Patrik Wyde). Its language is flat and near-square: corner tiles of 4 to 6 px, so roughly 3 px of rounding on buttons, tabs, inputs and menus; tabs attached to their frame; toolbar icons 22 px with text beside them; thin 2 px sliders and 5 px transient scrollbars; menus with 1 px frames.

- [x] Theme vendored to `config/kvantum/NoMansSkyJux/`, selected in `config/kvantum/kvantum.kvconfig`
- [x] Klassy's inactive button state configured to match active (icons only, no circles)
- [x] Decision: keep the Kvantum style as is. Darkly stays installed but unused
- Evidence: `docs/mystical-blue-dolphin.png`, `docs/mystical-blue-settings.png`

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

### Phase 9: full reset to MacTahoe dark `[x]`

Per review on 2026-10-18 the live desktop is reset to the KDE Store global
theme **Apple MacOS Tahoe Dark** by vinceliuice (the MacTahoe-kde package,
`com.github.vinceliuice.MacTahoe-Dark`), applied with its own panel layout.
Everything built in Phases 3 to 8 that touched the frame, the panel, the
widget style or app chrome is retired from the live desktop; the scripts
stay in the repo for reference. The Tahoe-Material icon theme is not applied
yet: icons are to be re-implemented against this base as the next step.

What the theme sets: colour scheme MacTahoeDark, icons MacTahoe-dark,
cursors MacTahoe-dark, Kvantum widget style, Aurorae decoration MacTahoe-Dark
with close, maximise, minimise on the left and Tiny borders, Plasma style
MacTahoe-Dark, its own 44 px top bar (launcher, global menu, tray, clock,
show desktop) and an icon-tasks dock. The Kvantum theme is set to
MacTahoeDark because the package leaves it unset.

What the reset removed: the Rounded Corners effect (disabled), the Overview
hot corner, the Klassy and Darkly decorations, the Firefox user.js and
userChrome.css, the Konsole default profile, the custom top panel.

GTK: the MacTahoe GTK theme (vinceliuice/MacTahoe-gtk-theme) is installed in
full, all twelve variants, with the libadwaita link for GTK4, and MacTahoe-Dark
is the active GTK3 theme. Its installer needs a pseudo-terminal: without one
its progress animation aborts the run silently after the helper-app step.

An intermediate reset to the zayronxio "Apple Tahoe Dark" package was applied
by mistake and replaced within the same session; its Panel Colorizer widget
remains installed per-user and is harmless.

### Phase 10: GNOME as the desktop `[~]`

Decision on 2026-10-18: the design target is GNOME's, so GNOME becomes the
main desktop. Plasma stays installed as the proven VR fallback. GNOME 51 and
its core apps are installed from the repos. `scripts/gnome-setup.sh` does the
per-user part from any session: the MacTahoe GTK and shell theme, the
Dash to Dock, Blur my Shell and AppIndicator extensions fetched for the
installed shell version, the interface settings, the dock layout and the
blur. User Themes comes bundled with gnome-shell-extensions.

- [x] GNOME installed, extensions in place with GNOME 51 builds
- [x] Settings pre-seeded: MacTahoe-Dark GTK and shell, MacTahoe-dark icons and cursor, dark style, buttons on the left, dock at the bottom with intellihide
- [ ] First GNOME login and visual check against the reference screenshot
- [ ] Display manager: switch to GDM so the login screen is GNOME's (root, user runs it)
- [ ] GDM theme via the MacTahoe tweaks script (root)
- [ ] Icon rework against this base
