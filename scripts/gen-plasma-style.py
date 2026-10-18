#!/usr/bin/env python3
"""Generate the Tahoe-Material Plasma style overlay.

It inherits everything from MacTahoe-Dark and replaces only the pieces that
set the card language: popup dialogs, tooltips, and the hover/selection
highlight used by the tray, Kickoff and list views.

Design (tokens/radius.json): popups 20 px, tooltips and highlights 8 px, a
1 px light hairline on the card edge, a glass tint with blur behind, and a
soft gradient shadow. KSvg renders with QtSvg, which has no filters, so every
shadow is a gradient tile rather than a blur.

Output: plasma/Tahoe-Material/ in the repo. install.sh links it into
~/.local/share/plasma/desktoptheme/.
"""
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "plasma" / "Tahoe-Material"
TOK = json.load(open(ROOT / "tokens" / "radius.json"))

POPUP_R = int(TOK.get("popup", 20))
SMALL_R = int(TOK.get("widget", 8))

TINT = "#1c1c1e"
TINT_ALPHA = 0.78
HAIRLINE = "#ffffff"
HAIRLINE_ALPHA = 0.16
SHADOW = 28          # shadow extent in px
SHADOW_ALPHA = 0.42


def nine_slice(prefix, r, fill, fill_alpha, line_alpha, pad, with_shadow, with_mask):
    """Return SVG fragments for a Plasma 9-slice frame named <prefix>-<part>.

    Geometry: the frame tiles live in a grid; each corner tile is r x r, edge
    tiles are r long and 1 px thick in the stretch direction (Plasma scales
    them), and the centre is 1 x 1. Shadow tiles sit outside the frame.
    """
    t = r  # tile size for corners
    s = SHADOW if with_shadow else 0
    frags = []
    # layout origin: leave room for shadow on the left/top
    ox, oy = s + 2, s + 2

    def rect(id_, x, y, w, h, extra=""):
        return f'<rect id="{id_}" x="{x}" y="{y}" width="{w}" height="{h}" {extra}/>'

    def arc_path(cx, cy, which):
        # quarter-disc path for a corner, filled
        if which == "tl":
            return f"M{cx + r},{cy} A{r},{r} 0 0 0 {cx},{cy + r} L{cx + r},{cy + r} Z"
        if which == "tr":
            return f"M{cx},{cy} A{r},{r} 0 0 1 {cx + r},{cy + r} L{cx},{cy + r} Z"
        if which == "bl":
            return f"M{cx},{cy} A{r},{r} 0 0 0 {cx + r},{cy + r} L{cx + r},{cy} Z"
        return f"M{cx},{cy} A{r},{r} 0 0 1 {cx + r},{cy + r} L{cx},{cy} Z" if False else \
            f"M{cx},{cy} L{cx + r},{cy} A{r},{r} 0 0 1 {cx},{cy + r} Z"

    body = f'fill="{fill}" fill-opacity="{fill_alpha}"'
    # frame tiles (ids without prefix for the main frame, Plasma expects plain names there)
    p = (prefix + "-") if prefix else ""
    # positions: corners at (ox,oy), edges adjacent, centre 1x1
    W = 2 * t + 1
    frags.append(f'<path id="{p}topleft" d="{arc_path(ox, oy, "tl")}" {body}/>')
    frags.append(f'<path id="{p}topright" d="{arc_path(ox + t + 1, oy, "tr")}" {body}/>')
    frags.append(f'<path id="{p}bottomleft" d="{arc_path(ox, oy + t + 1, "bl")}" {body}/>')
    frags.append(f'<path id="{p}bottomright" d="{arc_path(ox + t + 1, oy + t + 1, "br")}" {body}/>')
    frags.append(rect(f"{p}top", ox + t, oy, 1, t, body))
    frags.append(rect(f"{p}bottom", ox + t, oy + t + 1, 1, t, body))
    frags.append(rect(f"{p}left", ox, oy + t, t, 1, body))
    frags.append(rect(f"{p}right", ox + t + 1, oy + t, t, 1, body))
    frags.append(rect(f"{p}center", ox + t, oy + t, 1, 1, body))

    # hairline: a 1 px stroke along the outer edge, drawn inside the tiles
    if line_alpha:
        stroke = f'fill="none" stroke="{HAIRLINE}" stroke-opacity="{line_alpha}" stroke-width="1"'
        frags.append(f'<path d="M{ox + t},{oy + 0.5} A{r - 0.5},{r - 0.5} 0 0 0 {ox + 0.5},{oy + t}" {stroke}/>')
        frags.append(f'<path d="M{ox + t + 1},{oy + 0.5} A{r - 0.5},{r - 0.5} 0 0 1 {ox + W - 0.5},{oy + t}" {stroke}/>')
        frags.append(f'<path d="M{ox + 0.5},{oy + t + 1} A{r - 0.5},{r - 0.5} 0 0 0 {ox + t},{oy + W - 0.5}" {stroke}/>')
        frags.append(f'<path d="M{ox + W - 0.5},{oy + t + 1} A{r - 0.5},{r - 0.5} 0 0 1 {ox + t + 1},{oy + W - 0.5}" {stroke}/>')
        frags.append(rect("", ox + t, oy, 1, 1, f'fill="{HAIRLINE}" fill-opacity="{line_alpha}"').replace('id="" ', ''))
        frags.append(rect("", ox + t, oy + W - 1, 1, 1, f'fill="{HAIRLINE}" fill-opacity="{line_alpha}"').replace('id="" ', ''))
        frags.append(rect("", ox, oy + t, 1, 1, f'fill="{HAIRLINE}" fill-opacity="{line_alpha}"').replace('id="" ', ''))
        frags.append(rect("", ox + W - 1, oy + t, 1, 1, f'fill="{HAIRLINE}" fill-opacity="{line_alpha}"').replace('id="" ', ''))

    # content margins (padding inside the frame) and insets
    hx = ox + 3 * t + 20
    frags.append(rect(f"{p}hint-left-margin", hx, oy, pad, 4, 'fill="#ff00ff"'))
    frags.append(rect(f"{p}hint-right-margin", hx + 10, oy, pad, 4, 'fill="#ff00ff"'))
    frags.append(rect(f"{p}hint-top-margin", hx + 20, oy, 4, pad, 'fill="#ff00ff"'))
    frags.append(rect(f"{p}hint-bottom-margin", hx + 30, oy, 4, pad, 'fill="#ff00ff"'))

    if with_mask:
        mk = 'fill="#000000"'
        mx = ox + 3 * t + 80
        frags.append(f'<path id="mask-topleft" d="{arc_path(mx, oy, "tl")}" {mk}/>')
        frags.append(f'<path id="mask-topright" d="{arc_path(mx + t + 1, oy, "tr")}" {mk}/>')
        frags.append(f'<path id="mask-bottomleft" d="{arc_path(mx, oy + t + 1, "bl")}" {mk}/>')
        frags.append(f'<path id="mask-bottomright" d="{arc_path(mx + t + 1, oy + t + 1, "br")}" {mk}/>')
        frags.append(rect("mask-top", mx + t, oy, 1, t, mk))
        frags.append(rect("mask-bottom", mx + t, oy + t + 1, 1, t, mk))
        frags.append(rect("mask-left", mx, oy + t, t, 1, mk))
        frags.append(rect("mask-right", mx + t + 1, oy + t, t, 1, mk))
        frags.append(rect("mask-center", mx + t, oy + t, 1, 1, mk))

    if with_shadow:
        # gradient shadow tiles around a frame placed further down
        sy = oy + 3 * t + 60
        sx = ox
        defs = []
        defs.append(f'<linearGradient id="sh-top" x1="0" y1="1" x2="0" y2="0"><stop offset="0" stop-color="#000" stop-opacity="{SHADOW_ALPHA}"/><stop offset="1" stop-color="#000" stop-opacity="0"/></linearGradient>')
        defs.append(f'<linearGradient id="sh-bottom" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#000" stop-opacity="{SHADOW_ALPHA}"/><stop offset="1" stop-color="#000" stop-opacity="0"/></linearGradient>')
        defs.append(f'<linearGradient id="sh-left" x1="1" y1="0" x2="0" y2="0"><stop offset="0" stop-color="#000" stop-opacity="{SHADOW_ALPHA}"/><stop offset="1" stop-color="#000" stop-opacity="0"/></linearGradient>')
        defs.append(f'<linearGradient id="sh-right" x1="0" y1="0" x2="1" y2="0"><stop offset="0" stop-color="#000" stop-opacity="{SHADOW_ALPHA}"/><stop offset="1" stop-color="#000" stop-opacity="0"/></linearGradient>')
        for c in ("tl", "tr", "bl", "br"):
            cx = {"tl": 1, "tr": 0, "bl": 1, "br": 0}[c]
            cy = {"tl": 1, "tr": 1, "bl": 0, "br": 0}[c]
            defs.append(f'<radialGradient id="sh-{c}" cx="{cx}" cy="{cy}" r="1"><stop offset="0" stop-color="#000" stop-opacity="{SHADOW_ALPHA}"/><stop offset="1" stop-color="#000" stop-opacity="0"/></radialGradient>')
        frags.insert(0, "<defs>" + "".join(defs) + "</defs>")
        frags.append(rect("shadow-topleft", sx, sy, s, s, 'fill="url(#sh-tl)"'))
        frags.append(rect("shadow-top", sx + s, sy, 1, s, 'fill="url(#sh-top)"'))
        frags.append(rect("shadow-topright", sx + s + 1, sy, s, s, 'fill="url(#sh-tr)"'))
        frags.append(rect("shadow-left", sx, sy + s, s, 1, 'fill="url(#sh-left)"'))
        frags.append(rect("shadow-center", sx + s, sy + s, 1, 1, 'fill="#000" fill-opacity="0"'))
        frags.append(rect("shadow-right", sx + s + 1, sy + s, s, 1, 'fill="url(#sh-right)"'))
        frags.append(rect("shadow-bottomleft", sx, sy + s + 1, s, s, 'fill="url(#sh-bl)"'))
        frags.append(rect("shadow-bottom", sx + s, sy + s + 1, 1, s, 'fill="url(#sh-bottom)"'))
        frags.append(rect("shadow-bottomright", sx + s + 1, sy + s + 1, s, s, 'fill="url(#sh-br)"'))
        # shadow margins tell Plasma how far the shadow extends past the frame
        hx2 = sx + 3 * s + 10
        for name, (w, h) in (("shadow-hint-left-margin", (s, 4)), ("shadow-hint-right-margin", (s, 4)),
                             ("shadow-hint-top-margin", (4, s)), ("shadow-hint-bottom-margin", (4, s))):
            frags.append(rect(name, hx2, sy, w, h, 'fill="#ff00ff"'))
            hx2 += s + 10
    return frags


def svg(frags, size=400):
    return ('<svg xmlns="http://www.w3.org/2000/svg" width="%d" height="%d" viewBox="0 0 %d %d">'
            '<rect id="hint-tile-center" width="1" height="1" fill="none"/>' % (size, size, size, size)
            + "".join(frags) + "</svg>\n")


def main():
    (OUT / "dialogs").mkdir(parents=True, exist_ok=True)
    (OUT / "widgets").mkdir(parents=True, exist_ok=True)

    # popup cards
    (OUT / "dialogs" / "background.svg").write_text(svg(nine_slice(
        "", POPUP_R, TINT, TINT_ALPHA, HAIRLINE_ALPHA, pad=12, with_shadow=True, with_mask=True)))
    # tooltips: same language, smaller radius, tighter padding
    (OUT / "widgets" / "tooltip.svg").write_text(svg(nine_slice(
        "", SMALL_R, TINT, 0.92, HAIRLINE_ALPHA, pad=8, with_shadow=True, with_mask=True)))
    # highlight: hover and selected rounded at the widget radius, no outline
    frags = []
    frags += nine_slice("hover", SMALL_R, "#ffffff", 0.14, 0, pad=0, with_shadow=False, with_mask=False)
    frags += [f.replace('id="selected', 'id="selected') for f in
              nine_slice("selected", SMALL_R, "#ffffff", 0.22, 0, pad=0, with_shadow=False, with_mask=False)]
    frags += nine_slice("normal", SMALL_R, "#ffffff", 0.0, 0, pad=0, with_shadow=False, with_mask=False)
    (OUT / "widgets" / "viewitem.svg").write_text(svg(frags))

    (OUT / "metadata.desktop").write_text("""[Desktop Entry]
Name=Tahoe-Material
Comment=CachyOS Tahoe theme: Material-weight cards over the MacTahoe glass shell
X-KDE-PluginInfo-Author=CachyOS Tahoe theme
X-KDE-PluginInfo-Name=Tahoe-Material
X-KDE-PluginInfo-Version=1.0
X-KDE-PluginInfo-License=GPL-3.0
X-KDE-PluginInfo-EnabledByDefault=true
X-Plasma-API=5.0

[Settings]
FallbackTheme=MacTahoe-Dark

[ContrastEffect]
enabled=false

[BlurBehindEffect]
enabled=true

[AdaptiveTransparency]
enabled=true

[Wallpaper]
defaultWallpaperTheme=MacTahoe-Dark
defaultFileSuffix=.jpeg
defaultWidth=3840
defaultHeight=2160
""")
    print(f"wrote {OUT}")


if __name__ == "__main__":
    main()
