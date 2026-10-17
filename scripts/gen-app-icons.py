#!/usr/bin/env python3
"""Generate the Tahoe-Material app icons from tokens/apps.json.

Each icon is an Apple-style squircle filled with its category gradient, given a
liquid-glass treatment (inner highlight, inner shadow, lit rim, specular), and
topped with either a heavy white outlined glyph or the app's own brand mark.

Outputs icons/Tahoe-Material/apps/scalable/<icon>.svg, rasterised PNGs for the
standard sizes, desktop-entry overrides for apps whose Icon= cannot be themed,
and a contact sheet in docs/ for review.

Usage: gen-app-icons.py [--only NAME] [--no-png] [--no-sheet]
"""
import base64
import json
import math
import re
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
TOKENS = ROOT / "tokens"
GLYPHS = ROOT / "glyphs"
THEME = ROOT / "icons" / "Tahoe-Material"
OVERRIDES = ROOT / "overrides"
DOCS = ROOT / "docs"

GRID = 1024
SIZES = [16, 22, 24, 32, 48, 64, 128, 256]

ICON_DIRS = [
    "/usr/share/icons/hicolor", "/usr/local/share/icons/hicolor",
    str(Path.home() / ".local/share/icons/hicolor"),
]
PIXMAPS = ["/usr/share/pixmaps", "/usr/local/share/pixmaps"]


# ---------------------------------------------------------------- geometry

def squircle_path(size=GRID, n=5.0, inset=0.0, steps=256):
    """Superellipse |x|^n + |y|^n = 1 scaled to a square, as an SVG path."""
    r = size / 2 - inset
    c = size / 2
    pts = []
    for i in range(steps):
        t = 2 * math.pi * i / steps
        ct, st = math.cos(t), math.sin(t)
        x = c + r * math.copysign(abs(ct) ** (2 / n), ct)
        y = c + r * math.copysign(abs(st) ** (2 / n), st)
        pts.append(f"{x:.2f},{y:.2f}")
    return "M" + " L".join(pts) + " Z"


def hex_to_rgb(h):
    h = h.lstrip("#")
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4))


def rgb_to_hex(rgb):
    return "#%02x%02x%02x" % tuple(max(0, min(255, int(round(v)))) for v in rgb)


def mix(a, b, t):
    return tuple(a[i] + (b[i] - a[i]) * t for i in range(3))


def rotate_hue(rgb, deg):
    import colorsys
    r, g, b = (v / 255 for v in rgb)
    h, l, s = colorsys.rgb_to_hls(r, g, b)
    h = (h + deg / 360) % 1
    return tuple(v * 255 for v in colorsys.hls_to_rgb(h, l, s))


# ---------------------------------------------------------------- glyph parsing

def read_glyph(path):
    """Return (viewBox tuple, list of path d strings) from a simple SVG."""
    text = path.read_text()
    vb = re.search(r'viewBox="([^"]+)"', text)
    vb = tuple(float(v) for v in vb.group(1).split()) if vb else (0, 0, 24, 24)
    ds = re.findall(r'<path[^>]*\sd="([^"]+)"', text)
    if not ds:
        raise ValueError(f"no path in {path}")
    return vb, ds


def glyph_group(path, scale_pct, extra_class=""):
    """Watermark treatment: the glyph reads as frosted glass pressed into the
    squircle rather than a flat white mark. Three stacked copies: a soft dark
    offset below for depth, a light offset above for the lit edge, then the
    body at partial opacity so the category colour shows through."""
    vb, ds = read_glyph(path)
    x0, y0, w, h = vb
    target = GRID * scale_pct
    s = target / max(w, h)
    tx = (GRID - w * s) / 2 - x0 * s
    ty = (GRID - h * s) / 2 - y0 * s
    paths = "".join(f'<path d="{d}"/>' for d in ds)

    def layer(dx, dy, fill, op, extra=""):
        return (f'<g transform="translate({tx + dx:.2f},{ty + dy:.2f}) scale({s:.5f})" '
                f'fill="{fill}" fill-opacity="{op}" {extra}>{paths}</g>')

    return (layer(0, 7, "#000000", 0.20, 'filter="url(#soft-glyph)"')
            + layer(0, -4, "#ffffff", 0.28)
            + layer(0, 0, "#ffffff", 0.66, extra_class))


# ---------------------------------------------------------------- brand marks

TAHOE_DIRS = [str(Path.home() / ".local/share/icons/MacTahoe-dark/apps/scalable"),
              "/usr/share/icons/MacTahoe-dark/apps/scalable"]


def find_tahoe_icon(name):
    """A ready-made Tahoe-style icon from the MacTahoe set, if it has one."""
    for base in TAHOE_DIRS:
        p = Path(base) / f"{name}.svg"
        if p.exists():
            return p
    return None


def find_brand_icon(name):
    """Locate the best installed icon file for a brand mark: scalable SVG first,
    then the largest PNG, then pixmaps."""
    for base in ICON_DIRS:
        p = Path(base) / "scalable" / "apps" / f"{name}.svg"
        if p.exists():
            return p
    best = None
    for base in ICON_DIRS:
        for p in Path(base).glob(f"*/apps/{name}.png"):
            try:
                size = int(p.parts[-3].split("x")[0])
            except ValueError:
                continue
            if best is None or size > best[0]:
                best = (size, p)
    if best:
        return best[1]
    for base in PIXMAPS:
        for ext in ("svg", "png"):
            p = Path(base) / f"{name}.{ext}"
            if p.exists():
                return p
    return None


def brand_group(path, scale_pct):
    target = GRID * scale_pct
    off = (GRID - target) / 2
    if path.suffix == ".svg":
        data = base64.b64encode(path.read_bytes()).decode()
        href = f"data:image/svg+xml;base64,{data}"
    else:
        data = base64.b64encode(path.read_bytes()).decode()
        href = f"data:image/png;base64,{data}"
    return (f'<image x="{off:.1f}" y="{off:.1f}" width="{target:.1f}" height="{target:.1f}" '
            f'preserveAspectRatio="xMidYMid meet" href="{href}" filter="url(#glyph-shadow)"/>')


def dominant_colour(path):
    """Average the saturated pixels of a brand mark to pick its shell colour."""
    try:
        from PIL import Image
    except ImportError:
        return None
    if path.suffix == ".svg":
        import tempfile; tmp = Path(tempfile.gettempdir()) / f"brand-{path.stem}.png"
        subprocess.run(["rsvg-convert", "-w", "64", "-h", "64", str(path), "-o", str(tmp)], check=True)
        path = tmp
    im = Image.open(path).convert("RGBA").resize((64, 64))
    acc = [0, 0, 0]
    n = 0
    for r, g, b, a in list(im.getdata()) if not hasattr(im, "get_flattened_data") else im.get_flattened_data():
        if a < 128:
            continue
        mx, mn = max(r, g, b), min(r, g, b)
        if mx - mn < 40:  # grey, skip
            continue
        acc[0] += r
        acc[1] += g
        acc[2] += b
        n += 1
    if n == 0:
        return None
    return tuple(v / n for v in acc)


# ---------------------------------------------------------------- composition

def compose(base_rgb, top_rgb, body):
    """Return the full SVG for one icon. Body is the glyph or brand group."""
    bottom = rotate_hue(mix(base_rgb, (0, 0, 0), 0.12), 6)
    outer = squircle_path()
    rim = squircle_path(inset=6)
    return f"""<svg xmlns="http://www.w3.org/2000/svg" width="{GRID}" height="{GRID}" viewBox="0 0 {GRID} {GRID}">
  <defs>
    <clipPath id="clip"><path d="{outer}"/></clipPath>
    <linearGradient id="base" x1="0" y1="0" x2="0" y2="1">
      <stop offset="0" stop-color="{rgb_to_hex(top_rgb)}"/>
      <stop offset="0.55" stop-color="{rgb_to_hex(base_rgb)}"/>
      <stop offset="1" stop-color="{rgb_to_hex(bottom)}"/>
    </linearGradient>
    <linearGradient id="rim" x1="0" y1="0" x2="0" y2="1">
      <stop offset="0" stop-color="#ffffff" stop-opacity="0.34"/>
      <stop offset="0.5" stop-color="#ffffff" stop-opacity="0.06"/>
      <stop offset="1" stop-color="#000000" stop-opacity="0.28"/>
    </linearGradient>
    <linearGradient id="band" x1="0" y1="0" x2="0" y2="1">
      <stop offset="0" stop-color="#ffffff" stop-opacity="0.22"/>
      <stop offset="1" stop-color="#ffffff" stop-opacity="0"/>
    </linearGradient>
    <radialGradient id="spec" cx="0.28" cy="0.18" r="0.42">
      <stop offset="0" stop-color="#ffffff" stop-opacity="0.16"/>
      <stop offset="1" stop-color="#ffffff" stop-opacity="0"/>
    </radialGradient>
    <filter id="soft" x="-20%" y="-20%" width="140%" height="140%"><feGaussianBlur stdDeviation="26"/></filter>
    <filter id="inner-shadow" x="-20%" y="-20%" width="140%" height="140%"><feGaussianBlur stdDeviation="34"/></filter>
    <filter id="soft-glyph" x="-20%" y="-20%" width="140%" height="140%"><feGaussianBlur stdDeviation="10"/></filter>
    <filter id="glyph-shadow" x="-20%" y="-20%" width="140%" height="140%">
      <feDropShadow dx="0" dy="10" stdDeviation="14" flood-color="#000000" flood-opacity="0.28"/>
    </filter>
  </defs>
  <path d="{outer}" fill="url(#base)"/>
  <g clip-path="url(#clip)">
    <rect x="0" y="0" width="{GRID}" height="{GRID * 0.46:.0f}" fill="url(#band)" filter="url(#soft)"/>
    <rect x="-80" y="{GRID - 40}" width="{GRID + 160}" height="200" fill="#000000" opacity="0.30" filter="url(#inner-shadow)"/>
    <ellipse cx="{GRID * 0.3:.0f}" cy="{GRID * 0.2:.0f}" rx="{GRID * 0.34:.0f}" ry="{GRID * 0.22:.0f}" fill="url(#spec)"/>
  </g>
  <path d="{rim}" fill="none" stroke="url(#rim)" stroke-width="12"/>
  {body}
</svg>
"""


# ---------------------------------------------------------------- main

def main():
    args = sys.argv[1:]
    only = args[args.index("--only") + 1] if "--only" in args else None
    do_png = "--no-png" not in args
    do_sheet = "--no-sheet" not in args

    palette = json.load(open(TOKENS / "palette.json"))["categories"]
    apps = json.load(open(TOKENS / "apps.json"))["apps"]

    scalable = THEME / "apps" / "scalable"
    scalable.mkdir(parents=True, exist_ok=True)
    OVERRIDES.mkdir(exist_ok=True)

    produced = {}
    for desktop, app in apps.items():
        if app.get("skip"):
            continue
        icon = app.get("icon_override") or app["icon"]
        if only and only not in (icon, app["name"]):
            continue
        if icon in produced:
            continue
        cat = palette[app["category"]]
        base, top = hex_to_rgb(cat["base"]), hex_to_rgb(cat["top"])

        if app.get("brand"):
            tahoe = find_tahoe_icon(app["brand_icon"])
            if tahoe:
                # passthrough: MacTahoe already draws this brand in Tahoe style
                out = scalable / f"{icon}.svg"
                out.write_text(tahoe.read_text())
                produced[icon] = app["name"]
                continue
            src = find_brand_icon(app["brand_icon"])
            if not src:
                print(f"brand mark not found for {app['name']} ({app['brand_icon']}), skipping", file=sys.stderr)
                continue
            dom = dominant_colour(src)
            if dom:
                base = mix(dom, hex_to_rgb("#808080"), 0.2)
                top = mix(base, (255, 255, 255), 0.22)
            body = brand_group(src, 0.74)
        else:
            g = app["glyph"]
            gpath = GLYPHS / g["set"] / (f"{g['name']}-outline.svg" if g["set"] == "material" else f"{g['name']}.svg")
            if not gpath.exists():
                print(f"glyph missing for {app['name']}: {gpath}", file=sys.stderr)
                continue
            body = glyph_group(gpath, 0.68)

        svg = compose(base, top, body)
        out = scalable / f"{icon}.svg"
        out.write_text(svg)
        produced[icon] = app["name"]

        if app.get("icon_override") or app.get("desktop_override"):
            write_override(desktop, icon)

    if do_png:
        for size in SIZES:
            d = THEME / "apps" / str(size)
            d.mkdir(parents=True, exist_ok=True)
            for icon in produced:
                subprocess.run(["rsvg-convert", "-w", str(size), "-h", str(size),
                                str(scalable / f"{icon}.svg"), "-o", str(d / f"{icon}.png")], check=True)

    if not (TOKENS / "actions.json").exists():
        write_index_theme()  # gen-action-icons.py owns index.theme once the symbolic set exists
    if do_sheet and do_png:
        contact_sheet(produced)
    print(f"generated {len(produced)} icons")


def write_override(desktop, icon):
    """Copy the system desktop entry into overrides/ with the themed icon name."""
    for base in ("/usr/share/applications", "/usr/local/share/applications"):
        src = Path(base) / desktop
        if src.exists():
            text = src.read_text(errors="ignore")
            text = re.sub(r"^Icon=.*$", f"Icon={icon}", text, count=1, flags=re.M)
            (OVERRIDES / desktop).write_text(text)
            return


def write_index_theme():
    dirs = [f"apps/{s}" for s in SIZES] + ["apps/scalable"]
    lines = ["[Icon Theme]", "Name=Tahoe-Material",
             "Comment=macOS Tahoe glass squircles with Material and Phosphor glyphs",
             "Inherits=MacTahoe-dark,breeze-dark,breeze,hicolor",
             "Directories=" + ",".join(dirs), ""]
    for s in SIZES:
        lines += [f"[apps/{s}]", f"Size={s}", "Context=Applications", "Type=Fixed", ""]
    lines += ["[apps/scalable]", "Size=48", "MinSize=16", "MaxSize=512",
              "Context=Applications", "Type=Scalable", ""]
    (THEME / "index.theme").write_text("\n".join(lines))


def contact_sheet(produced):
    try:
        from PIL import Image, ImageDraw
    except ImportError:
        return
    icons = sorted(produced.items(), key=lambda kv: kv[1].lower())
    cols = 8
    cell, pad = 128, 24
    rows = (len(icons) + cols - 1) // cols
    sheet = Image.new("RGB", (cols * (cell + pad) + pad, rows * (cell + pad + 20) + pad), (30, 30, 32))
    draw = ImageDraw.Draw(sheet)
    for i, (icon, name) in enumerate(icons):
        x = pad + (i % cols) * (cell + pad)
        y = pad + (i // cols) * (cell + pad + 20)
        im = Image.open(THEME / "apps" / "128" / f"{icon}.png").convert("RGBA")
        sheet.paste(im, (x, y), im)
        draw.text((x, y + cell + 4), name[:20], fill=(200, 200, 205))
    DOCS.mkdir(exist_ok=True)
    sheet.save(DOCS / "contact-sheet.png")


if __name__ == "__main__":
    main()
