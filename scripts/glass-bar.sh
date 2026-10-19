#!/usr/bin/env bash
# Floating Liquid Glass top bar for an existing GNOME desktop (MacTahoe), like the Tahoe skin's:
#   - Blur My Shell upgraded to v76 (unreleased; built from a pinned commit) for rounded glass
#   - Open Bar for the floating pill shape ONLY: its menu, notification, font and GTK styling stay off
#   - top bar: rounded static blur of the wallpaper with Blur My Shell's "Liquid Glass" effect
# Everything stays in your home folder; no sudo.
# tahoe-repair enforces this look while Blur My Shell v76 is installed ('undo' puts v75 back,
# which switches tahoe-repair back to the plain bar).
#
#   bash glass-bar.sh apply      install and configure, then LOG OUT AND BACK IN
#   bash glass-bar.sh glass off  keep the floating bar, plain blur instead of Liquid Glass (instant)
#   bash glass-bar.sh glass on   Liquid Glass back on (instant)
#   bash glass-bar.sh menus on   live blur behind quick settings, dropdowns, calendar, notifications,
#                                OSDs and dialogs such as Power Off, as in the Tahoe VM (instant)
#   bash glass-bar.sh menus off  menus back to how they were before 'apply' (instant)
#   bash glass-bar.sh dock on    the dock in live Liquid Glass, as the bar and menus (instant)
#   bash glass-bar.sh dock off   the dock back to how it was before 'apply' (instant)
#   bash glass-bar.sh apps on    live Liquid Glass behind Files and the other whitelisted apps (instant)
#   bash glass-bar.sh apps off   app windows back to how they were before 'apply' (instant)
#   bash glass-bar.sh tint light one tint for all glass: light (the tuned look) or dark (provisional)
#   bash glass-bar.sh rebuild    rebuild and reinstall the patched Blur My Shell, then log out and back in
#   bash glass-bar.sh status     whether the patched Blur My Shell is the one installed
#   bash glass-bar.sh undo       put everything back exactly as before 'apply', then log out and back in
set -euo pipefail

BMS_COMMIT=470ae2d558e53e04171e19da4907f8e6031f346f   # blur-my-shell main, 2026-10-18, version 76
OPENBAR_UUID=openbar@neuromorph
BMS_UUID=blur-my-shell@aunetx
BACKUP_ROOT="$HOME/.local/share/glass-backup"
BACKUP="$BACKUP_ROOT/original"
# your choices, which tahoe-repair enforces at every login: enabled=1, bar=glass|plain, menus=on|off, dock=on|off, apps=on|off, tint=light|dark
STATE="$HOME/.config/tahoe-glass/state"
SRC="$HOME/.local/src"
EXT="$HOME/.local/share/gnome-shell/extensions"
EXT_PATH=/org/gnome/shell/extensions/
# patch on top of BMS_COMMIT: quick settings pieces blurred one by one (no card), brighter glass edges
BMS_PATCH="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/config/bms-tahoe-glass.patch"
OPENBAR_PRESET_URL=https://raw.githubusercontent.com/kayozxo/GNOME-macOS-Tahoe/6eb17c244fdefb02e81e77128ac5f1be1bb162ee/.config/extensions/openBar/Tahoe-Dark

if [ "$(id -u)" -eq 0 ]; then echo "Run this as yourself, not root."; exit 1; fi
if [ -z "${DBUS_SESSION_BUS_ADDRESS:-}" ]; then echo "Run this from a terminal inside your GNOME session."; exit 1; fi
step() { printf '\n\033[1;36m==> %s\033[0m\n' "$*"; }

# GLib aborts GNOME Shell when one dconf change notification carries 256+ keys
# (gsettings.c "assertion failed: (l < 256)"), so settings are written in batches of at most 100.
dconf_apply() { # base_path dump_file [current_dump_file]: write the dump's keys in small batches;
                # with a current dump, only keys that differ are written and keys missing from the dump are reset
  python3 - "$@" <<'PY'
import subprocess, sys
base, new_file = sys.argv[1], sys.argv[2]
cur_file = sys.argv[3] if len(sys.argv) > 3 else None
def parse(f):
    out, sec = {}, None
    for line in open(f):
        line = line.rstrip('\n')
        if line.startswith('[') and line.endswith(']'):
            sec = line[1:-1]
        elif sec is not None and '=' in line:
            k, v = line.split('=', 1)
            out[(sec, k)] = v
    return out
new = parse(new_file)
cur = parse(cur_file) if cur_file else {}
writes = [(s, k, v) for (s, k), v in new.items() if cur.get((s, k)) != v]
resets = [(s, k) for (s, k) in cur if (s, k) not in new] if cur_file else []
for s, k in resets:
    subprocess.run(['dconf', 'reset', base + ('' if s == '/' else s + '/') + k], check=True)
for i in range(0, len(writes), 100):
    chunk, last = [], None
    for s, k, v in writes[i:i + 100]:
        if s != last:
            chunk.append(f'[{s}]'); last = s
        chunk.append(f'{k}={v}')
    subprocess.run(['dconf', 'load', base], input='\n'.join(chunk) + '\n', text=True, check=True)
print(f'  {len(writes)} settings written, {len(resets)} reset')
PY
}

set_state() { # key value
  mkdir -p "$(dirname "$STATE")"
  touch "$STATE"
  if grep -q "^$1=" "$STATE"; then sed -i "s|^$1=.*|$1=$2|" "$STATE"; else echo "$1=$2" >> "$STATE"; fi
}

ensure_backup() {
  if [ -e "$BACKUP/extensions.dconf" ]; then echo "  backup already present: $(readlink -f "$BACKUP")"; return; fi
  local d
  d="$BACKUP_ROOT/$(date +%Y%m%d-%H%M%S)-before-glass"
  mkdir -p "$d"
  dconf dump /org/gnome/ > "$d/org-gnome.dconf"
  dconf dump "$EXT_PATH" > "$d/extensions.dconf"
  gsettings get org.gnome.shell enabled-extensions > "$d/enabled-extensions.txt"
  gsettings get org.gnome.shell disabled-extensions > "$d/disabled-extensions.txt"
  for e in $(gnome-extensions list); do printf '%s %s\n' "$e" "$(gnome-extensions info "$e" | sed -n 's/ *Version: //p')"; done > "$d/extension-versions.txt"
  [ -d "$EXT/$BMS_UUID" ] && cp -a "$EXT/$BMS_UUID" "$d/$BMS_UUID-v75"
  ln -sfn "$d" "$BACKUP"
  echo "  backup saved: $d"
}

# enabled-extensions list editing
ext_list_add() { python3 -c 'import ast,sys;l=ast.literal_eval(sys.argv[1] or "[]");print(l if sys.argv[2] in l else l+[sys.argv[2]])' "$(gsettings get org.gnome.shell enabled-extensions | sed 's/^@as //')" "$1"; }

# One Liquid Glass recipe for every glass surface (bar, menus, dock); only the blur radius
# differs per surface. The tint is one setting for all of them: 'light' is the tuned look,
# 'dark' a provisional starting point to be designed later (glass-bar.sh tint light|dark).
glass_params() { # BLUR_RADIUS
  local tint tint_color
  case "$(sed -n 's/^tint=//p' "$STATE" 2>/dev/null | tail -1)" in
    dark) tint=0.4;  tint_color='[0.12, 0.12, 0.13, 1.0]' ;;   # provisional
    *)    tint=0.12; tint_color='[1.0, 1.0, 1.0, 1.0]' ;;     # light: the tuned look
  esac
  echo "{
  'strength': <0.8>, 'blur_radius': <$1>, 'edge_size': <12.0>, 'falloff': <2.4>,
  'refraction_style': <0.0>, 'rim_width': <3.0>, 'rgb_fringing': <0.06>,
  'gloss': <0.8>, 'fresnel_angle': <45.0>, 'fresnel_width': <1.0>, 'specular_strength': <0.0>,
  'tint': <$tint>, 'tint_color': <$tint_color>, 'backdrop_zoom': <1.0>, 'shadow': <0.2>
}"
}

bar_blur() { # glass | plain : top bar = rounded static blur, with or without Liquid Glass
  python3 - "$EXT/$BMS_UUID/schemas" "$1" "$(glass_params 12.0)" <<'PY'
import sys
from gi.repository import Gio, GLib
schemas, mode, params_text = sys.argv[1:4]
src = Gio.SettingsSchemaSource.new_from_directory(schemas, Gio.SettingsSchemaSource.get_default(), False)
def settings(sub=''):
    return Gio.Settings.new_full(src.lookup('org.gnome.shell.extensions.blur-my-shell' + sub, False), None, None)
root, panel = settings(), settings('.panel')
pipelines = {}
old = root.get_value('pipelines')
for i in range(old.n_children()):
    e = old.get_child_value(i)
    f = e.get_child_value(1)
    pipelines[e.get_child_value(0).get_string()] = {
        f.get_child_value(j).get_child_value(0).get_string(): f.get_child_value(j).get_child_value(1).get_variant()
        for j in range(f.n_children())}
def effect(text):
    return GLib.Variant.parse(GLib.VariantType('a{sv}'), text, None, None)
# kept separate from your existing pipelines, so nothing else changes
pipelines['pipeline_glassbar_glass'] = {'name': GLib.Variant('s', 'Glass bar (Liquid Glass)'), 'effects': GLib.Variant('av', [
    effect("{'type': <'refraction'>, 'id': <'effect_glassbar_glass'>, 'params': <%s>}" % params_text)])}
pipelines['pipeline_glassbar_plain'] = {'name': GLib.Variant('s', 'Glass bar (plain blur)'), 'effects': GLib.Variant('av', [
    effect("{'type': <'dual_kawase_blur'>, 'id': <'effect_glassbar_plain'>, 'params': <{'unscaled_radius': <12.0>, 'brightness': <1.0>}>}")])}
root.set_value('pipelines', GLib.Variant('a{sa{sv}}', pipelines))
panel.set_boolean('blur', True)
panel.set_boolean('static-blur', True)
panel.set_string('pipeline', 'pipeline_glassbar_glass' if mode == 'glass' else 'pipeline_glassbar_plain')
panel.set_int('corner-radius', 50)       # clamped to half the bar height: a pill
panel.set_int('rounded-corners', 0)
panel.set_boolean('override-background', True)
panel.set_int('style-panel', 0)          # transparent, so only the blur/glass shows
Gio.Settings.sync()
print(f"  top bar: {mode}, pipeline={panel.get_string('pipeline')}")
PY
}

# glass_pipeline ID NAME BLUR: a Blur My Shell pipeline with the top bar's Liquid Glass recipe
# (tint, rim, gloss) and its own blur radius, so every glass surface shares one look
glass_pipeline() {
  local id=$1 name=$2 blur=$3
  python3 - "$EXT/$BMS_UUID/schemas" "$id" "$name" "$(glass_params "$blur")" <<'PY'
import sys
from gi.repository import Gio, GLib
schemas, pid, name, params = sys.argv[1:5]
src = Gio.SettingsSchemaSource.new_from_directory(schemas, Gio.SettingsSchemaSource.get_default(), False)
root = Gio.Settings.new_full(src.lookup('org.gnome.shell.extensions.blur-my-shell', False), None, None)
pipelines = {}
old = root.get_value('pipelines')
for i in range(old.n_children()):
    e = old.get_child_value(i); f = e.get_child_value(1)
    pipelines[e.get_child_value(0).get_string()] = {
        f.get_child_value(j).get_child_value(0).get_string(): f.get_child_value(j).get_child_value(1).get_variant()
        for j in range(f.n_children())}
effect = GLib.Variant.parse(GLib.VariantType('a{sv}'),
    "{'type': <'refraction'>, 'id': <'effect_%s'>, 'params': <%s>}" % (pid.replace('pipeline_', ''), params), None, None)
pipelines[pid] = {'name': GLib.Variant('s', name), 'effects': GLib.Variant('av', [effect])}
root.set_value('pipelines', GLib.Variant('a{sa{sv}}', pipelines))
Gio.Settings.sync()
PY
}

# restore_bms_section SECTION: one Blur My Shell section back to the pre-apply backup
restore_bms_section() {
  local section=$1 b cur
  b=$(readlink -f "$BACKUP")
  cur=$(mktemp)
  dconf dump "${EXT_PATH}blur-my-shell/" > "$cur"
  python3 - "$cur" "$b/extensions.dconf" "$section" > "$cur.new" <<'PY'
import sys
def sections(f):
    out, sec = {}, None
    for line in open(f):
        line = line.rstrip('\n')
        if line.startswith('['):
            sec = line
            out.setdefault(sec, [])
        elif sec and '=' in line:
            out[sec].append(line)
    return out
cur = sections(sys.argv[1]); old = sections(sys.argv[2]); sec = sys.argv[3]
cur[f'[{sec}]'] = old.get(f'[blur-my-shell/{sec}]', [])
for s, lines in cur.items():
    print(s); print('\n'.join(lines)); print()
PY
  dconf_apply "${EXT_PATH}blur-my-shell/" "$cur.new" "$cur"
  rm -f "$cur" "$cur.new"
}

dock() { # on | off : the dock in live Liquid Glass, its own theme background cleared
  local BS="$EXT/$BMS_UUID/schemas" S=org.gnome.shell.extensions.blur-my-shell.dash-to-dock
  if [ "$1" = on ]; then
    glass_pipeline pipeline_glassbar_dock 'Glass dock' 18.0
    gsettings --schemadir "$BS" set $S blur true
    gsettings --schemadir "$BS" set $S static-blur false
    gsettings --schemadir "$BS" set $S pipeline pipeline_glassbar_dock
    gsettings --schemadir "$BS" set $S override-background true
    gsettings --schemadir "$BS" set $S style-dash-to-dock 0
    gsettings --schemadir "$BS" set $S unblur-in-overview true
  else
    restore_bms_section dash-to-dock
  fi
  echo "  dock: $1"
}

apps() { # on | off : live Liquid Glass behind the whitelisted app windows (Files, Settings, ...)
  local BS="$EXT/$BMS_UUID/schemas" S=org.gnome.shell.extensions.blur-my-shell.applications
  if [ "$1" = on ]; then
    # windows are large and full of text: the blur a step stronger than the menus' (24)
    glass_pipeline pipeline_glassbar_apps 'Glass apps' 24.0
    gsettings --schemadir "$BS" set $S blur true
    gsettings --schemadir "$BS" set $S static-blur false
    gsettings --schemadir "$BS" set $S pipeline pipeline_glassbar_apps
    # the theme rounds windows at 24 px (GTK4 window.csd, and Rounded Window Corners for the
    # rest); square when maximised or fullscreen, as the windows are
    gsettings --schemadir "$BS" set $S corner-radius 24
    gsettings --schemadir "$BS" set $S rounded-corners 0
    gsettings --schemadir "$BS" set $S corner-when-maximized false
  else
    restore_bms_section applications
  fi
  echo "  apps: $1"
}

menus() { # on | off : Blur My Shell's popup module
  local mode=$1 b cur
  b=$(readlink -f "$BACKUP")
  cur=$(mktemp)
  dconf dump "${EXT_PATH}blur-my-shell/" > "$cur"
  if [ "$mode" = on ]; then
    # the Tahoe VM's popup settings: v76 defaults (live blur, its own see-through menu style,
    # corner radii per surface), keeping every other Blur My Shell setting as it is
    python3 - "$cur" > "$cur.new" <<'PY'
import sys
out, sec = [], None
for line in open(sys.argv[1]):
    line = line.rstrip('\n')
    if line.startswith('['):
        sec = line
    elif sec == '[popup]':
        continue
    out.append(line)
out += ['', '[popup]', 'blur=true', 'static-blur=false', "pipeline='pipeline_default'",
        'override-background=true', 'preserve-shell-theme=false', 'style-popup=3']
print('\n'.join(out))
PY
  else
    # popup section from the backup taken before 'apply'
    python3 - "$cur" "$b/extensions.dconf" > "$cur.new" <<'PY'
import sys
def sections(f, prefix=''):
    out, sec = {}, None
    for line in open(f):
        line = line.rstrip('\n')
        if line.startswith('['):
            sec = line
            out.setdefault(sec, [])
        elif sec and '=' in line:
            out[sec].append(line)
    return out
cur = sections(sys.argv[1])
old = sections(sys.argv[2])
cur['[popup]'] = old.get('[blur-my-shell/popup]', [])
for sec, lines in cur.items():
    print(sec); print('\n'.join(lines)); print()
PY
  fi
  dconf_apply "${EXT_PATH}blur-my-shell/" "$cur.new" "$cur"
  rm -f "$cur" "$cur.new"
  if [ "$mode" = on ]; then
    # the top bar's Liquid Glass recipe, its blur a step stronger at 18; a pipeline of its own
    # so the shared default (windows) stays as it is
    glass_pipeline pipeline_glassbar_menus 'Glass menus' 18.0
    gsettings --schemadir "$EXT/$BMS_UUID/schemas" set org.gnome.shell.extensions.blur-my-shell.popup pipeline pipeline_glassbar_menus
  fi
  echo "  menus: $mode"
}

build_bms() {
  for c in git make msgfmt glib-compile-schemas; do command -v "$c" >/dev/null || { echo "missing tool: $c"; exit 1; }; done
  mkdir -p "$SRC"
  [ -d "$SRC/blur-my-shell/.git" ] || git clone -q https://github.com/aunetx/blur-my-shell.git "$SRC/blur-my-shell"
  git -C "$SRC/blur-my-shell" fetch -q origin
  # a checkout of our own, so it is reset to the pinned commit before patching
  git -C "$SRC/blur-my-shell" reset -q --hard "$BMS_COMMIT"
  git -C "$SRC/blur-my-shell" clean -fdq
  git -C "$SRC/blur-my-shell" apply "$BMS_PATCH"
  /usr/bin/make -C "$SRC/blur-my-shell" install >/dev/null
  # GNOME's update check sends each extension's version to extensions.gnome.org and installs
  # whatever it answers "upgrade" or "downgrade" with at the next login. Version 76 is not
  # published there, so it answers "downgrade" and the patched build is swapped for v75.
  # Labelled with the published version, the answer is "current" and the build stays.
  local shell_major ego_ver
  shell_major=$(gnome-shell --version | grep -oE '[0-9]+' | head -1)
  ego_ver=$(curl -sf "https://extensions.gnome.org/extension-info/?uuid=$BMS_UUID&shell_version=$shell_major" |
            python3 -c 'import json,sys;print(json.load(sys.stdin).get("version",""))' || true)
  if [ -n "$ego_ver" ]; then
    python3 - "$EXT/$BMS_UUID/metadata.json" "$ego_ver" <<'PY'
import json, sys
p, v = sys.argv[1], int(sys.argv[2])
m = json.load(open(p))
m['tahoe-glass-built-from'] = m.get('version')
m['version'] = v
json.dump(m, open(p, 'w'), indent=2)
PY
    echo "  built from v76 + $(basename "$BMS_PATCH"), labelled v$ego_ver (extensions.gnome.org's current) so GNOME does not swap it"
    if [ "$ego_ver" -ge 76 ]; then
      echo "  note: extensions.gnome.org now has v$ego_ver; GNOME may replace this build with it (dropping the patch)"
    fi
  else
    echo "  warning: could not read extensions.gnome.org; GNOME's update check may swap this build for the published one"
  fi
}

# a build GNOME replaced with the published version has no patch in it
check_bms() {
  if ! grep -q QUICK_SETTINGS_PIECE "$EXT/$BMS_UUID/components/popup/targets.js" 2>/dev/null; then
    echo "  Blur My Shell is not the patched build (GNOME's update check may have replaced it): run 'bash $0 rebuild'"
  fi
}

apply() {
  step "1/5 Backup of your current settings and Blur My Shell"
  ensure_backup

  step "2/5 Blur My Shell v76 (built from source)"
  build_bms

  step "3/5 Open Bar"
  local shell_major path tmp
  shell_major=$(gnome-shell --version | grep -oE '[0-9]+' | head -1)
  path=$(curl -sf "https://extensions.gnome.org/extension-info/?uuid=$OPENBAR_UUID&shell_version=$shell_major" |
         python3 -c 'import json,sys;print(json.load(sys.stdin).get("download_url",""))')
  tmp=$(mktemp -d)
  curl -sfLo "$tmp/openbar.zip" "https://extensions.gnome.org$path"
  gnome-extensions install -f "$tmp/openbar.zip"
  # Open Bar is not marked GNOME 51 compatible; GNOME only loads it with version checks off
  gsettings set org.gnome.shell disable-extension-version-validation true
  gsettings set org.gnome.shell enabled-extensions "$(ext_list_add "$OPENBAR_UUID")"

  step "4/5 Open Bar: Tahoe's floating pill bar, everything else left to MacTahoe"
  curl -sfLo "$tmp/preset.dconf" "$OPENBAR_PRESET_URL"
  local dark light barfont
  # Open Bar forces the bar text to weight 400 unless given a font; MacTahoe's bar text is the
  # interface font in bold, pure white, so hand Open Bar exactly that
  barfont=$(python3 -c 'import sys, gi; gi.require_version("Pango", "1.0")
from gi.repository import Pango
d = Pango.FontDescription.from_string(sys.argv[1]); d.set_weight(Pango.Weight.BOLD); print(d.to_string())' \
    "$(gsettings get org.gnome.desktop.interface font-name | tr -d "'")")
  echo "  bar font: $barfont"
  dark=$(gsettings get org.gnome.desktop.background picture-uri-dark)
  light=$(gsettings get org.gnome.desktop.background picture-uri)
  # keep the bar shape/colours from the preset; switch off every part that styles anything but the bar
  sed -e "s|^dark-bguri=.*|dark-bguri=$dark|" -e "s|^light-bguri=.*|light-bguri=$light|" \
      -e "s|^font=.*|font='$barfont'|" \
      -e "s|^fgcolor=.*|fgcolor=['1.0', '1.0', '1.0']|" -e "s|^fgalpha=.*|fgalpha=1.0|" \
      -e "s|^dark-fgcolor=.*|dark-fgcolor=['1.0', '1.0', '1.0']|" -e "s|^light-fgcolor=.*|light-fgcolor=['1.0', '1.0', '1.0']|" \
      -e "s|^menustyle=.*|menustyle=false|" \
      -e "s|^apply-menu-shell=.*|apply-menu-shell=false|" -e "s|^apply-menu-notif=.*|apply-menu-notif=false|" \
      -e "s|^apply-all-shell=.*|apply-all-shell=false|" -e "s|^apply-accent-shell=.*|apply-accent-shell=false|" \
      -e "s|^apply-gtk=.*|apply-gtk=false|" -e "s|^apply-flatpak=.*|apply-flatpak=false|" \
      -e "s|^gtk-popover=.*|gtk-popover=false|" -e "s|^set-yarutheme=.*|set-yarutheme=false|" \
      -e "s|^set-notifications=.*|set-notifications=false|" -e "s|^set-notif-position=.*|set-notif-position=false|" \
      -e "s|^set-overview=.*|set-overview=false|" \
      -e "s|^wmaxbar=.*|wmaxbar=false|" \
      "$tmp/preset.dconf" > "$tmp/openbar.dconf"
  dconf_apply "${EXT_PATH}openbar/" "$tmp/openbar.dconf"
  # the preset was exported with import-export=true, which pauses Open Bar's restyling; clear it and reload
  dconf write "${EXT_PATH}openbar/import-export" false
  if [ "$(dconf read "${EXT_PATH}openbar/trigger-reload")" = true ]; then t=false; else t=true; fi
  dconf write "${EXT_PATH}openbar/trigger-reload" "$t"
  rm -rf "$tmp"

  step "5/5 Top bar: rounded static blur with Liquid Glass"
  bar_blur glass
  set_state enabled 1
  set_state bar glass
  grep -q '^menus=' "$STATE" || set_state menus off

  step "Done. LOG OUT AND BACK IN now (the new Blur My Shell and Open Bar load at login)."
  echo "  To undo everything: bash $0 undo"
}

undo() {
  [ -e "$BACKUP/extensions.dconf" ] || { echo "no backup found at $BACKUP"; exit 1; }
  local b
  b=$(readlink -f "$BACKUP")
  step "Restoring from $b"
  # extension list first, so Open Bar stops before its settings are removed
  gsettings set org.gnome.shell enabled-extensions "$(cat "$b/enabled-extensions.txt")"
  gsettings set org.gnome.shell disabled-extensions "$(cat "$b/disabled-extensions.txt")"
  gsettings set org.gnome.shell disable-extension-version-validation \
    "$(python3 - "$b/org-gnome.dconf" <<'PY'
import sys
sec = None
val = 'false'
for line in open(sys.argv[1]):
    line = line.strip()
    if line.startswith('['): sec = line
    elif sec == '[shell]' and line.startswith('disable-extension-version-validation='): val = line.split('=', 1)[1]
print(val)
PY
)"
  if ! grep -q "^$OPENBAR_UUID " "$b/extension-versions.txt"; then
    gnome-extensions uninstall "$OPENBAR_UUID" 2>/dev/null || true
    dconf reset -f "${EXT_PATH}openbar/"   # one path reset, not 285 key changes
  fi
  if [ -d "$b/$BMS_UUID-v75" ]; then
    rm -rf "$EXT/$BMS_UUID"
    cp -a "$b/$BMS_UUID-v75" "$EXT/$BMS_UUID"
    echo "  Blur My Shell v75 files restored"
  fi
  local cur
  cur=$(mktemp)
  dconf dump "$EXT_PATH" > "$cur"
  dconf_apply "$EXT_PATH" "$b/extensions.dconf" "$cur"
  rm -f "$cur"
  rm -f "$STATE"
  step "Done. LOG OUT AND BACK IN to finish going back."
}

case "${1:-}" in
  apply) apply ;;
  undo) undo ;;
  status) check_bms; echo "  installed: $(python3 -c 'import json,sys;m=json.load(open(sys.argv[1]));print("v%s (built from v%s)" % (m["version"], m.get("tahoe-glass-built-from", m["version"])))' "$EXT/$BMS_UUID/metadata.json")" ;;
  apps)
    case "${2:-}" in
      on|off) apps "$2"; set_state apps "$2" ;;
      *) echo "usage: apps on|off"; exit 1 ;;
    esac ;;
  dock)
    case "${2:-}" in
      on|off) dock "$2"; set_state dock "$2" ;;
      *) echo "usage: dock on|off"; exit 1 ;;
    esac ;;
  tint)
    case "${2:-}" in
      light|dark)
        set_state tint "$2"
        # rewrite every glass surface that is on, from the one recipe
        [ "$(sed -n 's/^bar=//p' "$STATE" | tail -1)" = plain ] || bar_blur glass
        if [ "$(sed -n 's/^menus=//p' "$STATE" | tail -1)" = on ]; then glass_pipeline pipeline_glassbar_menus 'Glass menus' 18.0; fi
        if [ "$(sed -n 's/^dock=//p' "$STATE" | tail -1)" = on ]; then glass_pipeline pipeline_glassbar_dock 'Glass dock' 18.0; fi
        if [ "$(sed -n 's/^apps=//p' "$STATE" | tail -1)" = on ]; then glass_pipeline pipeline_glassbar_apps 'Glass apps' 24.0; fi
        echo "  tint: $2" ;;
      *) echo "usage: tint light|dark"; exit 1 ;;
    esac ;;
  rebuild) step "Blur My Shell v76, patched"; build_bms; step "Done. LOG OUT AND BACK IN to load it." ;;
  menus)
    case "${2:-}" in
      on|off) menus "$2"; set_state menus "$2" ;;
      *) echo "usage: menus on|off"; exit 1 ;;
    esac ;;
  glass)
    case "${2:-}" in
      on) bar_blur glass; set_state bar glass ;;
      off) bar_blur plain; set_state bar plain ;;
      *) echo "usage: glass on|off"; exit 1 ;;
    esac ;;
  *) sed -n '2,23p' "$0" | sed 's/^# \{0,1\}//'; exit 1 ;;
esac
