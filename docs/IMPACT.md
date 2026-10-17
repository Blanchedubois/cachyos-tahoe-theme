# Impact analysis

Each design feature checked against its intent, with the evidence used and
what changed as a result. Done in phases so each verdict stands on its own.

Verdicts: **pass**, **fixed** (failed, then corrected in this pass),
**deferred** (known, not addressed yet), **by design** (looks unusual on
purpose).

## Phase A: window frame

Intent: one radius, one outline, one shadow on every window, KDE-decorated or
client-drawn, with nothing drawn outside the frame.

| Check | Evidence | Verdict |
|---|---|---|
| Single corner arc | 16x crops of Dolphin's four corners | **fixed**. The Aurorae decoration drew its own 14 px mask and outline while the effect drew a second one at the same radius, giving concentric rings. Dropping Aurorae for Darkly's native decoration with its outline off leaves one arc. |
| No band or ghost below the frame | pixel scans across the bottom edge | **fixed**. Aurorae painted its padding zone in frame colour and its embedded Graphite shadow images drew a second rounded shape 12 px below. Darkly paints nothing outside the frame. |
| Outline on client-drawn windows | pixel probe on the Claude app window edge | **pass**. The effect clips and outlines CSD windows the same as KDE ones. |
| Shadow present | bottom-left crop with wallpaper behind | **pass**. Darkly's large shadow, consumed by the effect in native-shadow mode. The effect's own custom shadow did not render and is left off. |
| Radius token | effect `Size` and `InactiveCornerRadius`, Darkly `CornerRadius` | **pass**, all 12 px. |
| Titlebar buttons | titlebar crop | **fixed**. Traffic lights replaced by Darkly's line glyphs for close, minimise, maximise, left-aligned. |

Lesson recorded in the plan: never have two systems draw window chrome. The
effect owns rounding and outline; the decoration owns only the titlebar and
the shadow extent.

## Phase B: icons

Intent: every icon KDE requests by a standard name is a Material or Phosphor
glyph; app icons are glass squircles; folders stay Tahoe; Steam untouched.

| Check | Evidence | Verdict |
|---|---|---|
| Resolution coverage | `kiconfinder6` over 129 common action, status, places, devices names | **pass**. 118 resolve to Tahoe-Material, 11 to MacTahoe-dark (the folders and places kept on purpose), 0 unresolved. |
| Tray glyphs | panel crop at weight 600 | **pass**. Notifications, clipboard, volume, bluetooth, settings, USB, wifi, expander all outlined Material. App-supplied tray pixmaps (Discord, Steam, Claude) are theirs by design. |
| Weight | tray and Dolphin crops before and after | **fixed**. 700 read heavy; 600 is the token now in `tokens/glyphs.json`. |
| Fallback hijack | `user-home` resolved to a generic `user` glyph | **fixed**. One-word aliases pruned; documented. |
| Folders | Dolphin sidebar and view | **pass**. MacTahoe's coloured Tahoe folders. |
| App icons | `docs/contact-sheet.png` | **pass**. Watermark treatment: glyph at 66 percent white over the category colour with a lit upper edge and soft lower shadow, so it reads as frosted glass rather than a flat mark. |
| Brand apps | contact sheet rows for Brave, Chromium, Firefox, Discord, Heroic, Lutris, OBS, Telegram, VLC | **pass**. Passed through from the MacTahoe icon set, which already draws them in Tahoe style. Claude has no MacTahoe icon and keeps the restyled shell. |
| Steam | `kiconfinder6 steam` | **pass**. Falls through to MacTahoe. |
| Squircle size | alpha bounding boxes of generated and passthrough icons at 128 px | **fixed**. MacTahoe insets its squircle 64 units on a 1024 canvas; generated icons filled the canvas, so Firefox and the other passthroughs looked smaller. The generator now uses the same inset and all icons measure 8 to 120 px at 128. |
| Launcher mark | panel left crop | **pass**. CachyOS hex mark from `assets/cachyos-mark.svg`. |

## Phase C: widget rounding

Intent: buttons, inputs, frames, menus, popups share one radius below the
window radius.

| Check | Evidence | Verdict |
|---|---|---|
| Darkly radius | `darklyrc` `[Common] CornerRadius=8` | **pass** by configuration. |
| Dialog capture | attempted twice | **deferred**. The capture tooling kept grabbing the Claude app, which holds focus while this session runs. Judged from Dolphin's tab bar, selection highlight and toolbar buttons, which are all on the 8 px radius. |
| Menus | not captured | **deferred**. Menus cannot be opened without input injection on Wayland. Darkly applies `CornerRadius` to menus as well, so they follow by construction. |
| Plasma popups | Kickoff opened over D-Bus and captured | **pass** by inspection. Free corners round at about the 12 px token; the edge touching the panel is square, as Plasma intends. Pixel measurement was not possible because the window behind the popup shares its colour. |

## Phase D: panel, dock, glass, dark mode

| Check | Evidence | Verdict |
|---|---|---|
| Top panel | `docs/panel-after.png` | **pass**. 32 px, flush, launcher mark, tray, 24 hour clock, no show-desktop. |
| Global menu padding | applet QML | **deferred** by design, not configurable. |
| Dock | dock crop with hide temporarily off | **pass**. MacTahoe glass dock untouched; icons are the new set; Steam's own. Hide mode restored to dodge windows. |
| Glass surfaces | panel and dock crops | **pass**. MacTahoe blur and tint intact. |
| Dark mode | colour scheme, portal `color-scheme=1`, GTK prefer-dark | **pass**. |

## Open items carried forward

1. Verify menus and Plasma popups once a capture path exists, or by eye.
2. The effect's custom shadow keys did not produce a shadow. Native decoration shadow is used instead. Fine for now; revisit if a shadow colour token is wanted.
3. Global menu padding stays as Plasma ships it.
