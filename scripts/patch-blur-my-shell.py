#!/usr/bin/env python3
"""Patch Blur my Shell for the Tahoe look. Idempotent; run by gnome-setup.sh
and tahoe-repair.sh after any fetch of the extension.

1. Quick settings blur piece by piece: each toggle, slider, system button
   and submenu gets its own blur, and the panel gets none (the shell
   overrides draw it without a card).
2. Those pieces are rounded as capsules and circles: a fixed 9999 px radius,
   which the corner effect clamps to half the piece's size. Submenus take
   the 14 px menu radius.
3. Popup menus of whitelisted apps (GTK4 popovers in Files, Settings...) are
   blurred like their window: a popover is its own window with no wm class,
   so it takes the class of the window it belongs to.

Prints one line per change, nothing when everything is already in place.
Exits 1 when an anchor is missing, which means the extension changed
upstream and the patch needs a look.

Usage: patch-blur-my-shell.py EXTENSION_DIR
"""
import sys
from pathlib import Path

ext = Path(sys.argv[1])
popup = ext / "components" / "popup"
missing = []


def patch(path, marker, edits, what):
    s = path.read_text()
    if marker in s:
        return
    for old, new in edits:
        if old not in s:
            missing.append(f"{path.name}: {what}")
            return
        s = s.replace(old, new, 1)
    path.write_text(s)
    print(f"patched {path.name}: {what}")


# Replaces the earlier patch that left quick settings unblurred altogether.
t = popup / "targets.js"
s = t.read_text()
old_skip = (
    "        /* tahoe: quick settings stand on the desktop, unblurred */\n"
    "        if (this.has_style_class(delegate?.box, 'quick-settings') || this.has_style_class(actor, 'quick-settings'))\n"
    "            return [];\n"
)
if old_skip in s:
    t.write_text(s.replace(old_skip, "", 1))

patch(t, "tahoe: quick settings blur piece by piece", [
    ("const POPUP_DESCENDANT_TARGET_STYLE_CLASSES = ['switcher-list'];\n",
     "const POPUP_DESCENDANT_TARGET_STYLE_CLASSES = ['switcher-list'];\n"
     "/* tahoe: the quick-settings pieces that each get a blur of their own */\n"
     "const TAHOE_QS_PIECES = ['quick-toggle', 'quick-toggle-has-menu', 'quick-slider', 'icon-button', 'quick-toggle-menu'];\n"),
    ("        const targets = this.create_targets();\n"
     "        const delegate = this.actor.get_actor_delegate(actor);\n",
     "        const targets = this.create_targets();\n"
     "        const delegate = this.actor.get_actor_delegate(actor);\n"
     "        /* tahoe: quick settings blur piece by piece, no panel backing */\n"
     "        if (this.has_style_class(delegate?.box, 'quick-settings') || this.has_style_class(actor, 'quick-settings')) {\n"
     "            this.find_tahoe_pieces(actor, targets);\n"
     "            return targets.actors;\n"
     "        }\n"),
    ("    prefers_descendant_targets(actor) {\n",
     "    /* tahoe: a piece is blurred whole; the halves of a split toggle and\n"
     "       the items of a submenu are not looked into */\n"
     "    find_tahoe_pieces(actor, targets) {\n"
     "        const stack = this.get_children(actor).slice();\n"
     "        while (stack.length > 0) {\n"
     "            const child = stack.pop();\n"
     "            if (!child || this.actor.is_internal_actor(child))\n"
     "                continue;\n"
     "            if (this.has_any_style_class(child, TAHOE_QS_PIECES)) {\n"
     "                this.add(targets, child);\n"
     "                continue;\n"
     "            }\n"
     "            stack.push(...this.get_children(child));\n"
     "        }\n"
     "    }\n"
     "\n"
     "    prefers_descendant_targets(actor) {\n"),
], "quick settings blurred piece by piece")

patch(t, "tahoe: capsules and circles", [
    ("export const POPUP_CORNER_RADII = [\n",
     "export const POPUP_CORNER_RADII = [\n"
     "    /* tahoe: capsules and circles; the corner effect clamps to half the size */\n"
     "    {\n"
     "        key: 'quick-settings-corner-radius',\n"
     "        property: 'QUICK_SETTINGS_CORNER_RADIUS',\n"
     "        fixed: 9999,\n"
     "        style_classes: ['quick-toggle', 'quick-toggle-has-menu', 'quick-slider', 'icon-button'],\n"
     "    },\n"
     "    {\n"
     "        key: 'menu-corner-radius',\n"
     "        property: 'MENU_CORNER_RADIUS',\n"
     "        style_classes: ['quick-toggle-menu'],\n"
     "    },\n"),
], "capsule radius for quick-settings pieces")

patch(popup / "blur_surface.js", "tahoe: fixed radius", [
    ("    get_corner_radius() {\n"
     "        return this.settings.popup[this.corner_radius.property] ?? this.settings.popup.CORNER_RADIUS;\n",
     "    get_corner_radius() {\n"
     "        /* tahoe: fixed radius for capsules and circles */\n"
     "        if (this.corner_radius.fixed)\n"
     "            return this.corner_radius.fixed;\n"
     "        return this.settings.popup[this.corner_radius.property] ?? this.settings.popup.CORNER_RADIUS;\n"),
], "fixed corner radius")

patch(ext / "components" / "applications.js", "tahoe: a popup menu", [
    ("        const window_wm_class = meta_window.get_wm_class();\n",
     "        /* tahoe: a popup menu (a GTK4 popover) has no wm class of its own;\n"
     "           it takes the class of the window it belongs to */\n"
     "        const tahoe_popup = !meta_window.get_wm_class()\n"
     "            && !!meta_window.get_transient_for()\n"
     "            && [Meta.WindowType.DROPDOWN_MENU, Meta.WindowType.POPUP_MENU, Meta.WindowType.MENU, Meta.WindowType.COMBO]\n"
     "                .includes(meta_window.get_window_type());\n"
     "        const window_wm_class = (tahoe_popup\n"
     "            ? meta_window.get_transient_for().get_wm_class()\n"
     "            : meta_window.get_wm_class()) ?? \"\";\n"),
    ("            && [\n"
     "                Meta.FrameType.NORMAL,\n",
     "            && (tahoe_popup || [\n"
     "                Meta.FrameType.NORMAL,\n"),
    ("            ].includes(meta_window.get_frame_type())\n"
     "        ) {\n",
     "            ].includes(meta_window.get_frame_type()))\n"
     "        ) {\n"),
], "app popup menus blurred with their window")

if missing:
    for m in missing:
        print(f"anchor not found, not patched: {m}")
    sys.exit(1)
