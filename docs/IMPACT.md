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
| App icons | `docs/contact-sheet.png`, `docs/glass-vs-mactahoe.png` | **fixed**. The first watermark pass was too subtle and read as a plain gradient beside MacTahoe's icons. The recipe is now a thick glass slab: a glossy dome of light from the top, a broad inner rim highlight bright on the upper edges, a refracted glow along the bottom inside edge, a thin outer rim, and a frosted glyph with an inner glow, lit top edge and pressed shadow. Compared at 512 px against MacTahoe's Finder. |
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

## Phase E: review round three

| Check | Evidence | Verdict |
|---|---|---|
| Watermark placement | contact sheet, 512 px renders | **fixed**. Glyphs are now oversized (96 percent of the body), tilted 14 degrees, shifted 15 percent toward the bottom-right and clipped by the squircle so they bleed off the corner. Tokens `WATERMARK_SCALE`, `WATERMARK_TILT`, `WATERMARK_SHIFT` in the generator. |
| Glass overlay on every icon | Firefox at 512 px beside Dolphin | **fixed**. MacTahoe passthrough art is now embedded as the base under the same dome, inner rim, bottom glow and rim as generated icons. |
| Apps without an assigned icon | contact sheet: Desktop+, SteamVR, VRChat; dock: Claude | **fixed**. Every visible launcher not in the table gets its own mark on a white glass squircle. Marks that already fill their canvas, or are flagged `tile`, become the base under the glass instead of nesting inside a shell. Steam itself stays untouched. |
| Running-app icons in the dock | SteamVR's monitor window showed its own "VR" icon | **fixed**. `StartupWMClass=vrmonitor` on the SteamVR launcher lets the task manager match the window to the launcher and use the themed tile. The same tag can be added for any other running app that shows a stray icon. |
| Claude icon fill | 256 px render | **fixed**. The source image carries a white canvas with the orange square inset. `tile_crop` trims a tile to its coloured content before it becomes the base, so it fills the squircle. Any brand mark that does not fill sits on a white glass shell now; the sampled-colour shell is gone. |
| Window outline alignment | corner crops | **fixed** by removal, then **reworked** on review. A single 1 px edge outline sat a pixel off Darkly's anti-aliased corner. The frame now uses the effect's three concentric layers at different radii, which cannot fight each other: trial variant A is a 3 px dark outer ring outside the frame, a 2 px gap in window colour, and a 1 px light inner line. Mockups of A, B and C in `docs/frame-options.png`. |

| Frame, final | Dolphin corner crops | **settled**. A 6 px header-coloured border, then an inset panel with rounded corners, were built and rejected on review as heavy and odd. Final: 12 px rounding, Darkly titlebar, one faint light hairline outside the edge. |

| Shadows | Konsole and Claude corner crops | **settled**. The effect's own shadow draws a square corner on every window, so it stays off; Klassy's shadow follows the 20 px curve. Client-drawn Electron windows carry their own square shadow margin, which only the app can drop: Claude is launched with Chromium's Wayland decorations disabled via its flags file, effective on its next start. |

| Inactive shadow | unfocused Konsole corner crops | **fixed**. Klassy's inactive shadow defaults to half strength, which reads as a tighter, less blurred corner when a window loses focus. Inactive shadow now matches active: Large, full strength. |

## Phase F: hairline versus corner

Intent: the light hairline must sit exactly on the window's corner curve on every window.

| Check | Evidence | Verdict |
|---|---|---|
| KDE-decorated windows, as found | `docs/corner-hairline-compare.png`, top row: kcalc and Konsole, both top corners at 8x | **fail**. Klassy rounded the titlebar at its own 20 px with its own anti-aliasing, and the effect drew the hairline at its 20 px. The two arcs differ by about a pixel, which shows as a dark inner arc inside the light line. |
| Single renderer | same sheet, bottom row | **fixed**. Klassy's corner radius is set to 0, so the effect alone clips the corner and draws the line from the same path. One light arc, no inner arc, on both windows and both corners. |
| Client-drawn windows | Claude corner crops from Phase E | **pass**. These were already effect-only, which is why they never showed the mismatch. |

Rule recorded in the plan: the effect owns every pixel of the corner, including the line. The decoration draws a square titlebar and never rounds.

## Phase G: shadows per app

Intent: every window's shadow looks the same, focused or not.

| Window type | Who draws the shadow | State |
|---|---|---|
| KDE-decorated (Dolphin, Konsole, System Settings, kcalc) | Klassy | **pass**. Active and inactive shadows are now identical, so the corner reads the same either way. |
| Electron, Wayland, client-side frame (Claude, Discord) | Chromium, inside the app's own surface | **deferred to relaunch**. The app's shadow is part of its window, differs between focus states by the app's own rule, and ends in a square corner the effect cannot clip. Claude's launcher now carries `--disable-features=WaylandWindowDecorations` in `~/.config/claude-desktop-flags.conf`; Discord gets the same flag through a desktop-entry override. Both apply on the app's next start. Claude's restart ends the Claude Code session, so it is left to the user. |
| Steam and Steam games | Steam, or the game | **by design**. Excluded by the Steam rule. |

## Phase H: one shadow source for every app

Question: can a single renderer draw every window's shadow so they all match?

| Candidate | Test | Result |
|---|---|---|
| Rounded Corners effect's own shadow, with Klassy's shadow off | `docs/shadow-effect-test.png`: Konsole and Claude bottom corners | **rejected**. KDE-decorated windows ended up with no shadow at all; the effect draws its shadow only into the region a decoration reserves, and Klassy reserves none when its shadow is off. Client-drawn windows kept their own square shadow, untouched. With Klassy's shadow on as well, the effect's shadow adds a square corner (Phase E). |
| Klassy for KDE windows, apps' own for the rest | current | **accepted** as the best Wayland allows. KDE-decorated windows match each other exactly. Electron windows are told to stop drawing their own frame, which removes the square shadow on their next launch; KWin gives undecorated Wayland windows no shadow, so they will then be shadowless rather than mismatched. |

Why there is no perfect answer on Wayland: a shadow is either drawn by the decoration KWin manages, or by the app inside its own surface. KWin cannot add a shadow to an undecorated client surface and cannot remove one the client painted. The only uniform outcome is to make every app server-decorated, which frameless Electron apps and games do not allow.

## Phase I: panel spacing and popup cards

| Check | Evidence | Verdict |
|---|---|---|
| Tray spacing and hover room | panel at 36 px, tray spacing large | **pass** by configuration. Hover itself cannot be captured without pointer control. |
| Popup card glass | `docs/popup-card.png`, Kickoff; pixel samples of panel, card and wallpaper | **fixed**. Cards used a fixed near-black at 65 percent; the panel uses the scheme colour at 15 percent over blur. Cards now use the scheme colour at 30 percent, so both pick up the wallpaper the same way. |
| Card layout | `docs/cards-survey.png`, every tray plasmoid opened standalone | **by design**. Spacing inside each card is Plasma's QML, not themeable. Padding stays at MacTahoe's 8 px. |
| Popup card corners | `docs/popup-options.png`, Kickoff with floating and flush panel on MacTahoe's glass | **fixed** by floating the panel. Attached popups square the edge touching the panel by Plasma's rule; floating detaches them so MacTahoe's own card shows all four corners. The custom overlay card was rejected for replacing the glass look. |
| Hover highlight in popups | same capture, Favorites row | **pass**. 8 px rounded highlight from the overlay's viewitem asset. |
| List highlight inset inside app windows | System Settings sidebar | **deferred**. Darkly's `FancyMargins` is on, but the Kirigami sidebar draws its own delegates and a hover could not be captured to confirm the inset. Needs a look by eye. |

## Open items carried forward

1. Verify menus and Plasma popups once a capture path exists, or by eye.
2. The effect's custom shadow keys did not produce a shadow. Native decoration shadow is used instead. Fine for now; revisit if a shadow colour token is wanted.
3. Global menu padding stays as Plasma ships it.
