# CachyOS Tahoe Theme

A KDE Plasma 6 theme for CachyOS: macOS Tahoe glass, one heavy rounded glyph
language for every icon, and unified corner rounding across windows, widgets
and menus.

Built on top of [MacTahoe-kde](https://github.com/vinceliuice/MacTahoe-kde),
[Darkly](https://github.com/Bali10050/Darkly) and
[KDE Rounded Corners](https://github.com/matinlotfali/KDE-Rounded-Corners),
with glyphs from [Material Symbols](https://github.com/google/material-design-icons)
(Apache 2.0) and [Phosphor](https://github.com/phosphor-icons/core) (MIT).

The plan, tokens and phase status live in [docs/IMPLEMENTATION.md](docs/IMPLEMENTATION.md).

## Layout

| Path | What |
|---|---|
| `docs/` | implementation plan, review contact sheets |
| `tokens/` | palette, rounding scale, per-app icon assignments |
| `scripts/` | glyph fetcher, app icon generator, action icon generator |
| `glyphs/` | fetched source glyphs, kept out of git |
| `icons/` | generated icon theme |
| `aurorae/` | the MacTahoe-Graphite-Dark window decoration |
| `config/` | Darkly, KWin and panel settings the installer applies |

## Requirements

Plasma 6.6 or newer. From the AUR: `darkly-bin`, `kwin-effect-rounded-corners-git`.
From the repos: `kvantum` is not needed. `librsvg` for rasterising.

## Install

Everything installs per user, no root.

```
./install.sh
```

## Licence

Theme files GPL-3.0. Glyphs retain their upstream licences. Brand marks belong
to their owners and are included only as application icons.
