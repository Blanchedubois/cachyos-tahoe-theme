#!/usr/bin/env python3
"""Fetch the source glyphs named in tokens/*.json into glyphs/<set>/<name>.svg.

Material Symbols Rounded come from google/material-design-icons at weight 700.
App glyphs use the filled variant; action glyphs use the outlined one.
Phosphor glyphs come from phosphor-icons/core, bold weight.

Usage: fetch-glyphs.py [--force]
"""
import json
import sys
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
GLYPHS = ROOT / "glyphs"

MATERIAL = ("https://raw.githubusercontent.com/google/material-design-icons/master/"
            "symbols/web/{name}/materialsymbolsrounded/{name}_wght700{fill}_48px.svg")
PHOSPHOR = "https://raw.githubusercontent.com/phosphor-icons/core/main/assets/bold/{name}-bold.svg"


def wanted():
    """Yield (set, name, fill) for every glyph referenced by the token files."""
    seen = set()
    apps = json.load(open(ROOT / "tokens" / "apps.json"))["apps"]
    for app in apps.values():
        g = app.get("glyph")
        if g:
            key = (g["set"], g["name"], True)
            if key not in seen:
                seen.add(key)
                yield key
    actions_file = ROOT / "tokens" / "actions.json"
    if actions_file.exists():
        for entry in json.load(open(actions_file))["actions"].values():
            g = entry["glyph"]
            key = (g["set"], g["name"], g.get("fill", False))
            if key not in seen:
                seen.add(key)
                yield key


def url_for(set_, name, fill):
    if set_ == "material":
        return MATERIAL.format(name=name, fill="fill1" if fill else "")
    if set_ == "phosphor":
        return PHOSPHOR.format(name=name)
    raise ValueError(f"unknown glyph set {set_}")


def dest_for(set_, name, fill):
    suffix = "" if set_ == "phosphor" or fill else "-outline"
    return GLYPHS / set_ / f"{name}{suffix}.svg"


def main():
    force = "--force" in sys.argv
    missing = []
    for set_, name, fill in wanted():
        dest = dest_for(set_, name, fill)
        if dest.exists() and not force:
            continue
        dest.parent.mkdir(parents=True, exist_ok=True)
        url = url_for(set_, name, fill)
        try:
            with urllib.request.urlopen(url, timeout=30) as r:
                dest.write_bytes(r.read())
            print(f"fetched {set_}/{dest.name}")
        except Exception as e:  # noqa: BLE001
            missing.append((set_, name, str(e)))
            print(f"MISSING {set_}/{name}: {e}", file=sys.stderr)
    if missing:
        print(f"\n{len(missing)} glyph(s) could not be fetched; fix the names in tokens/", file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()
