# CachyOS Tahoe Theme

A macOS Tahoe look for GNOME on CachyOS: the MacTahoe shell and GTK theme in
its glass variant, a generated icon theme of SF Symbol watermarks on liquid
glass squircles, SF glyphs throughout the shell and system apps, rounded
corners on every window, and a repair script that puts it all back whenever
something drifts.

Built on [MacTahoe-gtk-theme](https://github.com/vinceliuice/MacTahoe-gtk-theme)
and its icon set, with [Dash to Dock](https://github.com/micheleg/dash-to-dock),
[Blur my Shell](https://github.com/aunetx/blur-my-shell),
[AppIndicator](https://github.com/ubuntu/gnome-shell-extension-appindicator) and
[Rounded Window Corners Reborn](https://github.com/flexagoon/rounded-window-corners).
Glyphs from [SF Symbols SVG](https://github.com/brendanballon/sfsymbols-svg).

The full history, decisions and findings are in
[docs/IMPLEMENTATION.md](docs/IMPLEMENTATION.md); the audit of each feature
is in [docs/IMPACT.md](docs/IMPACT.md). Plasma files from the first phases
are kept for reference but the live target is GNOME.

## Requirements

GNOME 51 on CachyOS. Root once, for the packages:

```
sudo pacman -S --needed gnome gnome-tweaks gnome-shell-extensions
```

Everything else installs per user. `librsvg` and Python with Pillow are used
to generate icons.

## Install

Log into a GNOME session, then:

```
git clone https://github.com/Blanchedubois/cachyos-tahoe-theme
cd cachyos-tahoe-theme
scripts/gnome-setup.sh
```

The script installs the theme (one installer run: a second pass wipes it),
fetches the extensions for the running GNOME version and loads them into the
live shell, applies the author's Blur my Shell settings, links the icon
theme, and installs `tahoe-repair` with a login hook. Log out once afterwards
so extension code loads cleanly.

Login screen (root): `tahoe-repair --gdm` prints the two commands.

## Keeping it working

```
tahoe-repair
```

Runs automatically a few seconds after each login and on demand. It checks
and fixes, in order: theme files, extension folders, extensions loaded and
enabled, shell theme loaded (falls back to Adwaita after a rebuild), the
shell CSS overrides, the Blur my Shell patches and module settings, the
GTK3 solid variant and all-corner rounding, the GNOME 51 port of the corner
extension, interface settings, dock settings and stylesheet, the icon theme
link and contents. On a healthy system it prints one line.

Switches: `tahoe-repair --popup-blur off` if the quick settings ever show an
opaque box; `tahoe-repair --gdm` for the login screen commands.

After a GNOME major update, extensions stay disabled until builds for the
new version exist; the script reports that and fetches them once published.

## Layout

| Path | What |
|---|---|
| `scripts/gnome-setup.sh` | per-user install of everything |
| `scripts/tahoe-repair.sh` | the repair script, installed as `tahoe-repair` |
| `scripts/gen-app-icons.py` | app icons: SF watermark on a glass squircle, brand passthrough, white fallback |
| `scripts/gen-action-icons.py` | symbolic icons for the shell, Settings, Files, and a KDE companion theme |
| `scripts/fetch-glyphs.py` | pulls SF, Material and Phosphor glyphs named in the tokens |
| `tokens/` | palette, glyph weight, per-app and per-name icon assignments |
| `icons/Tahoe-Material` | the generated icon theme (SVGs tracked, PNGs regenerated) |
| `icons/Tahoe-Material-KDE` | companion theme with SF places icons for KDE apps |
| `config/` | shell CSS overrides, the corner extension's GNOME 51 port, GDM and Konsole bits |
| `docs/` | implementation plan, impact analysis, contact sheet |

## Known limits

- Live blur of windows behind a surface needs Blur my Shell's dynamic mode,
  which renders surfaces opaque on NVIDIA with GNOME 51. Static blur is used.
- KDE tools that need KWin (Spectacle, Info Center) do not run under GNOME.
- Apps that bundle their own icons (Discord, Steam, Firefox toolbar) keep them.

## Licence

Theme files GPL-3.0. Glyphs and brand marks keep their upstream licences.
