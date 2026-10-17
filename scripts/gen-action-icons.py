#!/usr/bin/env python3
"""Generate the symbolic action, status, places, devices and emblem icons
from tokens/actions.json into icons/Tahoe-Material/.

Each icon is a single-colour SVG that carries KDE's colour-scheme stylesheet
block, so Plasma, Qt and KIconLoader recolour it to the current text colour
(light on dark, dark on light) exactly like Breeze. The glyph fills the icon
box the way Material's 24 dp grid intends: 960 units map to the full box, so
the built-in 2 dp optical padding is preserved at every size.

Usage: gen-action-icons.py [--only NAME]
"""
import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
TOKENS = ROOT / "tokens"
GLYPHS = ROOT / "glyphs"
THEME = ROOT / "icons" / "Tahoe-Material"

APP_SIZES = [16, 22, 24, 32, 48, 64, 128, 256]

STYLE = ('<defs><style type="text/css" id="current-color-scheme">'
         '.ColorScheme-Text { color:#e0e0e0; }'
         '.ColorScheme-Background { color:#232629; }'
         '.ColorScheme-Highlight { color:#3daee9; }'
         '.ColorScheme-NegativeText { color:#da4453; }'
         '.ColorScheme-PositiveText { color:#27ae60; }'
         '.ColorScheme-NeutralText { color:#f67400; }'
         '</style></defs>')


def read_glyph(path):
    text = path.read_text()
    vb = re.search(r'viewBox="([^"]+)"', text)
    vb = tuple(float(v) for v in vb.group(1).split()) if vb else (0, 0, 24, 24)
    ds = re.findall(r'<path[^>]*\sd="([^"]+)"', text)
    if not ds:
        raise ValueError(f"no path in {path}")
    return vb, ds


def glyph_path_for(glyph, fill):
    set_ = glyph["set"]
    if set_ == "material":
        suffix = "" if fill else "-outline"
        return GLYPHS / "material" / f"{glyph['name']}{suffix}.svg"
    return GLYPHS / set_ / f"{glyph['name']}.svg"


def symbolic_svg(vb, ds, size):
    """Wrap the glyph paths in a size-by-size SVG that scales the source grid
    to the icon box. Material's viewBox is 0 -960 960 960; Phosphor's is
    0 0 256 256. Both are designed with their own optical padding."""
    x0, y0, w, h = vb
    s = size / max(w, h)
    tx = -x0 * s + (size - w * s) / 2
    ty = -y0 * s + (size - h * s) / 2
    paths = "".join(f'<path d="{d}"/>' for d in ds)
    return (f'<svg xmlns="http://www.w3.org/2000/svg" width="{size}" height="{size}" '
            f'viewBox="0 0 {size} {size}">{STYLE}'
            f'<g class="ColorScheme-Text" fill="currentColor" '
            f'transform="translate({tx:.4f},{ty:.4f}) scale({s:.6f})">{paths}</g></svg>\n')


def asset_svg(path, size, scale=0.86):
    """Embed a repo asset (viewBox 0 0 N N, fills stripped) as a symbolic icon,
    keeping its internal group transforms."""
    text = path.read_text()
    vb = re.search(r'viewBox="([^"]+)"', text)
    n = float(vb.group(1).split()[2]) if vb else 64.0
    body = re.search(r'<svg[^>]*>(.*)</svg>', text, re.S).group(1)
    off = (1 - scale) / 2 * size
    return (f'<svg xmlns="http://www.w3.org/2000/svg" width="{size}" height="{size}" '
            f'viewBox="0 0 {size} {size}">{STYLE}'
            f'<g class="ColorScheme-Text" fill="currentColor" '
            f'transform="translate({off:.3f},{off:.3f}) scale({size * scale / n:.5f})">{body}</g></svg>\n')


def write_index_theme(contexts):
    dirs = [f"apps/{s}" for s in APP_SIZES] + ["apps/scalable"]
    for ctx, cfg in contexts.items():
        dirs += [f"{ctx}/{s}" for s in cfg["sizes"]]
    lines = ["[Icon Theme]", "Name=Tahoe-Material",
             "Comment=macOS Tahoe glass squircles with Material and Phosphor glyphs",
             "Inherits=MacTahoe-dark,breeze-dark,breeze,hicolor",
             "FollowsColorScheme=true",
             "Directories=" + ",".join(dirs), ""]
    for s in APP_SIZES:
        lines += [f"[apps/{s}]", f"Size={s}", "Context=Applications", "Type=Fixed", ""]
    lines += ["[apps/scalable]", "Size=48", "MinSize=16", "MaxSize=512",
              "Context=Applications", "Type=Scalable", ""]
    ctx_names = {"actions": "Actions", "status": "Status", "places": "Places",
                 "devices": "Devices", "emblems": "Emblems"}
    for ctx, cfg in contexts.items():
        for s in cfg["sizes"]:
            lines += [f"[{ctx}/{s}]", f"Size={s}", f"Context={ctx_names[ctx]}", "Type=Fixed", ""]
    (THEME / "index.theme").write_text("\n".join(lines))


def main():
    args = sys.argv[1:]
    only = args[args.index("--only") + 1] if "--only" in args else None
    spec = json.load(open(TOKENS / "actions.json"))
    contexts = spec["contexts"]
    written = 0
    missing = []
    for name, entry in spec["actions"].items():
        if only and only != name:
            continue
        ctx = entry["context"]
        cfg = contexts[ctx]
        names = [name] + entry.get("aliases", [])
        if "source" in entry:
            src = ROOT / entry["source"]
            if not src.exists():
                missing.append((name, entry["source"]))
                continue
            for size in cfg["sizes"]:
                d = THEME / ctx / str(size)
                d.mkdir(parents=True, exist_ok=True)
                svg = asset_svg(src, size, entry.get("scale", 0.86))
                for n in names:
                    (d / f"{n}.svg").write_text(svg)
                    written += 1
            continue
        fill = entry["glyph"].get("fill", cfg["fill"])
        gpath = glyph_path_for(entry["glyph"], fill)
        if not gpath.exists():
            missing.append((name, str(gpath.relative_to(ROOT))))
            continue
        vb, ds = read_glyph(gpath)
        for size in cfg["sizes"]:
            d = THEME / ctx / str(size)
            d.mkdir(parents=True, exist_ok=True)
            svg = symbolic_svg(vb, ds, size)
            for n in names:
                (d / f"{n}.svg").write_text(svg)
                written += 1
    write_index_theme(contexts)
    print(f"wrote {written} files for {len(spec['actions'])} entries")
    if missing:
        print(f"{len(missing)} entries skipped, glyph missing:", file=sys.stderr)
        for n, p in missing:
            print(f"  {n}: {p}", file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()
