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
import hashlib
import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
TOKENS = ROOT / "tokens"
GLYPHS = ROOT / "glyphs"
THEME = ROOT / "icons" / "Tahoe-Material"
THEME_KDE = ROOT / "icons" / "Tahoe-Material-KDE"  # companion for KDE apps: adds SF places icons

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
    """(viewBox, path d list, inner transform). SF Symbol exports have px
    width/height instead of a viewBox and a flipped <g>; keep the transform."""
    text = path.read_text()
    vb = re.search(r'viewBox="([^"]+)"', text)
    if vb:
        vb = tuple(float(v) for v in vb.group(1).split())
    else:
        w = re.search(r"width=['\"]([0-9.]+)", text)
        h = re.search(r"height=['\"]([0-9.]+)", text)
        vb = (0, 0, float(w.group(1)) if w else 24, float(h.group(1)) if h else 24)
    ds = re.findall(r"<path[^>]*\sd=['\"]([^'\"]+)['\"]", text, re.S)
    if not ds:
        raise ValueError(f"no path in {path}")
    ds = [re.sub(r"\s+", " ", d).strip() for d in ds]
    tr = re.search(r"<g[^>]*transform=['\"]([^'\"]+)['\"]", text)
    return vb, ds, (tr.group(1) if tr else "")


def glyph_path_for(glyph, fill):
    set_ = glyph["set"]
    if set_ == "material":
        suffix = "" if fill else "-outline"
        return GLYPHS / "material" / f"{glyph['name']}{suffix}.svg"
    return GLYPHS / set_ / f"{glyph['name']}.svg"


GLYPH_TOKENS = json.load(open(TOKENS / "glyphs.json"))
# Extra stroke added around SF outlines so they hold up at 16 px, in rendered
# px at a 16 px icon (scaled with the icon). Set in rendered px, not source
# units: SF exports differ in size (Bluetooth's is 99 units tall, Wi-Fi's 74),
# so a fixed source stroke came out thinner on every glyph that is scaled
# down more. The glyph is inset by the stroke so it is not clipped.
SF_STROKE_PX = float(GLYPH_TOKENS.get("sf_symbolic_stroke_px", 1.0))


def symbolic_svg(vb, ds, size, inner_tr="", stroke_px=0.0):
    """Wrap the glyph paths in a size-by-size SVG that scales the source grid
    to the icon box. Material's viewBox is 0 -960 960 960; Phosphor's is
    0 0 256 256. Both are designed with their own optical padding. stroke_px
    is the outline added at 16 px; it scales with the icon, the glyph is
    inset by it, and it renders the same width whatever the glyph's size."""
    x0, y0, w, h = vb
    pad = stroke_px * size / 16
    s = (size - pad) / max(w, h)
    stroke = pad / s if stroke_px else 0.0
    tx = -x0 * s + (size - w * s) / 2
    ty = -y0 * s + (size - h * s) / 2
    paths = "".join(f'<path d="{d}"/>' for d in ds)
    if inner_tr:
        paths = f'<g transform="{inner_tr}">{paths}</g>'
    # GNOME recolours a symbolic icon by replacing this fill; KDE uses the
    # stylesheet class. Both are present so one file serves both desktops.
    stroke_attr = (f' stroke="#bebebe" stroke-width="{stroke:.3f}" stroke-linejoin="round"' if stroke else "")
    return (f'<svg xmlns="http://www.w3.org/2000/svg" width="{size}" height="{size}" '
            f'viewBox="0 0 {size} {size}">{STYLE}'
            f'<g class="ColorScheme-Text" fill="#bebebe"{stroke_attr} '
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
    kde_ctx = {c: cfg for c, cfg in contexts.items() if cfg.get("theme") == "kde"}
    all_ctx = dict(contexts)
    contexts = {c: cfg for c, cfg in contexts.items() if cfg.get("theme") != "kde"}
    write_kde_index(kde_ctx)
    dirs = [f"apps/{s}" for s in APP_SIZES] + ["apps/scalable", "places/scalable"]
    for ctx, cfg in contexts.items():
        dirs += [f"{ctx}/{s}" for s in cfg["sizes"]]
    dirs += [f"symbolic/{ctx}" for ctx in all_ctx]
    lines = ["[Icon Theme]", "Name=Tahoe-Material",
             "Comment=macOS Tahoe glass squircles with Material and Phosphor glyphs",
             "Inherits=MacTahoe-dark,Adwaita,breeze-dark,breeze,hicolor",
             "FollowsColorScheme=true",
             "Directories=" + ",".join(dirs), ""]
    for s in APP_SIZES:
        lines += [f"[apps/{s}]", f"Size={s}", "Context=Applications", "Type=Fixed", ""]
    lines += ["[apps/scalable]", "Size=48", "MinSize=16", "MaxSize=512",
              "Context=Applications", "Type=Scalable", ""]
    lines += ["[places/scalable]", "Size=48", "MinSize=8", "MaxSize=512",
              "Context=Places", "Type=Scalable", ""]
    ctx_names = {"actions": "Actions", "status": "Status", "places": "Places",
                 "devices": "Devices", "emblems": "Emblems"}
    ctx_names.setdefault("places", "Places")
    for ctx, cfg in contexts.items():
        for s in cfg["sizes"]:
            lines += [f"[{ctx}/{s}]", f"Size={s}", f"Context={ctx_names[ctx]}", "Type=Fixed", ""]
    for ctx in all_ctx:
        lines += [f"[symbolic/{ctx}]", "Size=16", "MinSize=8", "MaxSize=512", f"Context={ctx_names.get(ctx, ctx.title())}", "Type=Scalable", ""]
    (THEME / "index.theme").write_text("\n".join(lines))


MACTAHOE_PLACES = Path.home() / ".local/share/icons/MacTahoe-dark/places/scalable"


def passthrough_places():
    """Copy MacTahoe's coloured place icons under their plain names. GTK tries
    a theme's own "-symbolic" variant before consulting parent themes, so
    without these Files' grid would show the SF sidebar glyphs for folders."""
    if not MACTAHOE_PLACES.is_dir():
        return 0
    dest = THEME / "places" / "scalable"
    dest.mkdir(parents=True, exist_ok=True)
    n = 0
    for f in MACTAHOE_PLACES.glob("*.svg"):
        if f.name.endswith("-symbolic.svg"):
            continue
        target = dest / f.name
        if f.is_symlink():
            # keep the set self-contained: resolve to real content
            try:
                target.write_bytes(f.resolve().read_bytes())
            except OSError:
                continue
        else:
            target.write_bytes(f.read_bytes())
        n += 1
    return n


def write_kde_index(kde_ctx):
    ctx_names = {"places": "Places"}
    dirs = [f"{c}/{s}" for c, cfg in kde_ctx.items() for s in cfg["sizes"]]
    lines = ["[Icon Theme]", "Name=Tahoe-Material-KDE",
             "Comment=Tahoe-Material plus SF places icons for KDE apps",
             "Inherits=Tahoe-Material,MacTahoe-dark,breeze-dark,breeze,hicolor",
             "FollowsColorScheme=true", "Directories=" + ",".join(dirs), ""]
    for c, cfg in kde_ctx.items():
        for sz in cfg["sizes"]:
            lines += [f"[{c}/{sz}]", f"Size={sz}", f"Context={ctx_names.get(c, c.title())}", "Type=Fixed", ""]
    THEME_KDE.mkdir(parents=True, exist_ok=True)
    (THEME_KDE / "index.theme").write_text("\n".join(lines))


def inputs_hash():
    """Hash of what the symbolic set is generated from. Written next to the
    icons; tahoe-repair regenerates when it no longer matches."""
    h = hashlib.sha256()
    for f in (TOKENS / "actions.json", TOKENS / "glyphs.json", Path(__file__)):
        h.update(f.read_bytes())
    return h.hexdigest()


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
        kde_only = cfg.get("theme") == "kde"
        base = THEME_KDE if kde_only else THEME
        if "source" in entry:
            src = ROOT / entry["source"]
            if not src.exists():
                missing.append((name, entry["source"]))
                continue
            sd = THEME / "symbolic" / ctx
            sd.mkdir(parents=True, exist_ok=True)
            for n in names:
                (sd / f"{n}-symbolic.svg").write_text(asset_svg(src, 16, entry.get("scale", 0.86)))
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
        vb, ds, inner_tr = read_glyph(gpath)
        stroke = SF_STROKE_PX if entry["glyph"]["set"] == "sf" else 0.0
        # GNOME: one scalable "-symbolic" file per name under symbolic/<ctx>/.
        # For places this is what Files' sidebar asks for; the plain names
        # (main view, large coloured folders) are left to MacTahoe.
        sd = THEME / "symbolic" / ctx
        sd.mkdir(parents=True, exist_ok=True)
        svg16 = symbolic_svg(vb, ds, 16, inner_tr, stroke)
        for n in names:
            (sd / f"{n}-symbolic.svg").write_text(svg16)
            written += 1
        for size in cfg["sizes"]:
            d = base / ctx / str(size)
            d.mkdir(parents=True, exist_ok=True)
            svg = symbolic_svg(vb, ds, size, inner_tr, stroke)
            for n in names:
                (d / f"{n}.svg").write_text(svg)
                written += 1
    write_index_theme(contexts)
    (THEME / ".generated-from").write_text(inputs_hash() + "\n")
    print(f"wrote {written} files for {len(spec['actions'])} entries; "
          f"{passthrough_places()} coloured place icons carried from MacTahoe")
    if missing:
        print(f"{len(missing)} entries skipped, glyph missing:", file=sys.stderr)
        for n, p in missing:
            print(f"  {n}: {p}", file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()
