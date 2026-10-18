#!/usr/bin/env python3
"""Write the highlight asset of the Tahoe-Material Plasma overlay.

widgets/viewitem.svg: hover, selected and selected+hover highlights as rounded
rectangles inset INSET px from the item's edge, so the highlight never touches
its neighbours or the card edge. Used by the system tray, Kickoff's sidebar,
and every Plasma list.

Everything else in the Plasma style falls back to MacTahoe-Dark.
"""
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "plasma" / "Tahoe-Material" / "widgets"

R = 10        # corner radius of the highlight
INSET = 3     # gap between the highlight and the item edge
T = R + INSET # corner tile size


def tiles(prefix, fill, opacity, x0, y0):
    """9-slice tiles for one state, laid out at (x0, y0)."""
    f = f'fill="{fill}" fill-opacity="{opacity}"'
    i, r = INSET, R
    out = []
    # corners: rounded quarter inset from the outer edge
    out.append(f'<path id="{prefix}-topleft" d="M{x0 + i + r},{y0 + i} A{r},{r} 0 0 0 {x0 + i},{y0 + i + r} L{x0 + i},{y0 + T} L{x0 + T},{y0 + T} L{x0 + T},{y0 + i} Z" {f}/>')
    out.append(f'<path id="{prefix}-topright" d="M{x0 + T + 1},{y0 + i} A{r},{r} 0 0 1 {x0 + T + 1 + r},{y0 + i + r} L{x0 + T + 1 + r},{y0 + T} L{x0 + T + 1},{y0 + T} Z" {f}/>')
    out.append(f'<path id="{prefix}-bottomleft" d="M{x0 + i},{y0 + T + 1} L{x0 + T},{y0 + T + 1} L{x0 + T},{y0 + T + 1 + r} L{x0 + i + r},{y0 + T + 1 + r} A{r},{r} 0 0 1 {x0 + i},{y0 + T + 1 + r - r} Z" {f}/>')
    out.append(f'<path id="{prefix}-bottomright" d="M{x0 + T + 1},{y0 + T + 1} L{x0 + T + 1 + r},{y0 + T + 1} A{r},{r} 0 0 1 {x0 + T + 1 + r - r},{y0 + T + 1 + r} L{x0 + T + 1},{y0 + T + 1 + r} Z" {f}/>')
    # edges: 1 px long in the stretch direction, inset on the outer side
    out.append(f'<rect id="{prefix}-top" x="{x0 + T}" y="{y0 + i}" width="1" height="{r}" {f}/>')
    out.append(f'<rect id="{prefix}-bottom" x="{x0 + T}" y="{y0 + T + 1}" width="1" height="{r}" {f}/>')
    out.append(f'<rect id="{prefix}-left" x="{x0 + i}" y="{y0 + T}" width="{r}" height="1" {f}/>')
    out.append(f'<rect id="{prefix}-right" x="{x0 + T + 1}" y="{y0 + T}" width="{r}" height="1" {f}/>')
    out.append(f'<rect id="{prefix}-center" x="{x0 + T}" y="{y0 + T}" width="1" height="1" {f}/>')
    # transparent bounding boxes so the tiles keep their full size including the inset
    for name, (x, y, w, h) in {
        "topleft": (x0, y0, T, T), "topright": (x0 + T + 1, y0, T, T),
        "bottomleft": (x0, y0 + T + 1, T, T), "bottomright": (x0 + T + 1, y0 + T + 1, T, T),
        "top": (x0 + T, y0, 1, T), "bottom": (x0 + T, y0 + T + 1, 1, T),
        "left": (x0, y0 + T, T, 1), "right": (x0 + T + 1, y0 + T, T, 1),
    }.items():
        out.append(f'<rect id="{prefix}-{name}-bounds" x="{x}" y="{y}" width="{w}" height="{h}" fill="none"/>')
    return out


def svg(body, w=400, h=400):
    return ('<svg xmlns="http://www.w3.org/2000/svg" width="%d" height="%d" viewBox="0 0 %d %d">'
            '<rect id="hint-tile-center" width="1" height="1" fill="none"/>' % (w, h, w, h)
            + "".join(body) + "</svg>\n")


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    body = []
    body += tiles("hover", "#ffffff", 0.14, 10, 10)
    body += tiles("selected", "#ffffff", 0.22, 10, 60)
    body += tiles("selected+hover", "#ffffff", 0.28, 10, 110)
    body += tiles("normal", "#ffffff", 0.0, 10, 160)
    (OUT / "viewitem.svg").write_text(svg(body))

    print("wrote", OUT / "viewitem.svg")


if __name__ == "__main__":
    main()
