#!/usr/bin/env bash
# tahoe-repair: put the GNOME Tahoe look back whenever it breaks.
#
# Every failure seen so far is deterministic, so this checks each one and
# applies the known fix. Safe to run any time; it changes nothing that is
# already right. Also run once per login from the autostart entry that
# gnome-setup.sh installs, so an upgrade or a crash never leaves the shell
# on Adwaita with no dock.
#
# Checks, in order:
#   1. theme files present (else rebuild from source, one installer run)
#   2. extension folders present (else fetch builds for the running shell)
#   3. extensions loaded in the running shell (else ask it to load them)
#   4. extensions enabled
#   5. shell theme is MacTahoe-Dark and actually loaded (else re-apply)
#   6. Blur my Shell module config: applications on a system-app whitelist, popup per POPUP_BLUR
#   7. icon theme is Tahoe-Material and its files are present
#   8. extension builds match the running GNOME version (else re-fetch)
#   9. interface drift: GTK theme, cursor, button layout, resize border (never the wallpaper)
#  --gdm prints the root commands for the MacTahoe login screen
#  10. dock drift: Dash to Dock back on the theme's own styling
#  11. dock stylesheet present (the theme's -d tweak deletes it)
#  5c. Blur my Shell patched so modal dialogs do not blur the whole screen
#  5d. GTK3 windows rounded on all four corners
#  5e. Rounded Window Corners ported to GNOME 51 and configured (24 px, non-libadwaita windows)
#  12. icon theme contents: regenerate from the repo if the generated set is
#      missing or stale (symbolic places for Files, apps, KDE companion)
set -uo pipefail
log() { printf '[tahoe-repair] %s\n' "$*"; }

[[ "${XDG_CURRENT_DESKTOP:-}" == *GNOME* ]] || { log "not a GNOME session, nothing to do"; exit 0; }
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SRC="$HOME/.local/src/MacTahoe-gtk-theme"
EXT_DIR="$HOME/.local/share/gnome-shell/extensions"
EXTS=(dash-to-dock@micxgx.gmail.com blur-my-shell@aunetx appindicatorsupport@rgcjonas.gmail.com rounded-window-corners@fxgn)
# Popup blur (quick settings, menus, notifications). Static mode renders on
# this machine where dynamic painted an opaque box. Switch with
#   tahoe-repair --popup-blur off      (writes config/popup-blur)
POPUP_FLAG="$ROOT/config/popup-blur"
case "${1:-}" in
  --popup-blur) echo "${2:-on}" > "$POPUP_FLAG"; shift 2 ;;
  --gdm)
    # Login screen: needs root, so only print what to run.
    cat <<EOT
The login screen is GDM's own shell; it is themed by the MacTahoe tweaks script (root):
  sudo systemctl disable plasmalogin.service && sudo systemctl enable gdm.service   # once, if still on Plasma's login
  cd ~/.local/src/MacTahoe-gtk-theme && sudo ./tweaks.sh -g -i apple -c Dark
Options after -g: -b IMAGE (own background), -nb (no blur), -nd (no darken), -p 45 (panel opacity).
Undo: sudo ./tweaks.sh -g -r
GNOME updates can overwrite the GDM theme; rerun the tweaks command if the login screen reverts.
EOT
    exit 0 ;;
esac
POPUP_BLUR=true; [[ -f "$POPUP_FLAG" && "$(cat "$POPUP_FLAG")" == "off" ]] && POPUP_BLUR=false
WANT="['user-theme@gnome-shell-extensions.gcampax.github.com','dash-to-dock@micxgx.gmail.com','blur-my-shell@aunetx','appindicatorsupport@rgcjonas.gmail.com','rounded-window-corners@fxgn']"
SHELL_VER="$(gnome-shell --version 2>/dev/null | grep -oE '[0-9]+' | head -1)"
changed=0

# 1. theme files
if [[ ! -f "$HOME/.themes/MacTahoe-Dark/gnome-shell/gnome-shell.css" || ! -L "$HOME/.config/gtk-4.0/gtk.css" ]]; then
  log "theme missing: rebuilding (one run, blur variant, libadwaita)"
  [[ -d "$SRC" ]] || git clone -q --depth 1 https://github.com/vinceliuice/MacTahoe-gtk-theme "$SRC"
  rm -rf /tmp/MacTahoe.lock
  ( cd "$SRC" && TERM=xterm-256color script -qfec "./install.sh -b -l" /dev/null >/dev/null 2>&1 )
  changed=1
fi

# 2. extension folders
for e in "${EXTS[@]}"; do
  if [[ ! -f "$EXT_DIR/$e/metadata.json" ]]; then
    log "extension folder missing: $e, fetching for GNOME $SHELL_VER"
    tag="$(curl -s "https://extensions.gnome.org/extension-info/?uuid=$e&shell_version=$SHELL_VER" | python3 -c 'import json,sys; print(json.load(sys.stdin)["version_tag"])' 2>/dev/null || true)"
    if [[ -n "$tag" ]]; then
      tmp="$(mktemp -d)"; curl -sL "https://extensions.gnome.org/download-extension/$e.shell-extension.zip?version_tag=$tag" -o "$tmp/e.zip"
      mkdir -p "$EXT_DIR/$e"; python3 -c 'import zipfile,sys; zipfile.ZipFile(sys.argv[1]).extractall(sys.argv[2])' "$tmp/e.zip" "$EXT_DIR/$e"
      [[ -d "$EXT_DIR/$e/schemas" ]] && glib-compile-schemas "$EXT_DIR/$e/schemas"; rm -rf "$tmp"; changed=1
    else
      log "no build of $e for GNOME $SHELL_VER yet (normal for a few days after a GNOME major update)"
    fi
  fi
done

# 3. loaded in the running shell
for e in "${EXTS[@]}"; do
  if ! gnome-extensions info "$e" >/dev/null 2>&1; then
    log "shell has not loaded $e: asking it to"
    gdbus call --session --dest org.gnome.Shell --object-path /org/gnome/Shell \
      --method org.gnome.Shell.Extensions.InstallRemoteExtension "$e" >/dev/null 2>&1 || true
    changed=1
  fi
done

# 4. enabled
cur="$(gsettings get org.gnome.shell enabled-extensions | tr -d " ")"
if [[ "$cur" != "$(tr -d ' ' <<<"$WANT")" ]]; then
  log "enabling the extension set"
  gsettings set org.gnome.shell disable-user-extensions false
  gsettings set org.gnome.shell enabled-extensions "$WANT"; changed=1
fi
for e in "${EXTS[@]}"; do
  st="$(gnome-extensions info "$e" 2>/dev/null | awk '/State:/{print $2}')"
  if [[ "$st" == "INACTIVE" ]]; then log "re-enabling $e"; gnome-extensions enable "$e" 2>/dev/null; changed=1
  elif [[ "$st" == "ERROR" ]]; then log "$e is in ERROR; its code changed on disk and the shell needs a logout to reload it"; fi
done

# 5. shell theme applied and loaded
if [[ "$(gsettings get org.gnome.shell.extensions.user-theme name)" != "'MacTahoe-Dark'" ]]; then
  log "shell theme not set: applying"; changed=1
fi
last="$(journalctl --user -b --no-pager -o cat 2>/dev/null | grep -E 'loading (user|default) theme' | tail -1)"
if [[ "$changed" == 1 || "$last" == *Adwaita* ]]; then
  log "re-applying shell theme (last load: ${last:-unknown})"
  gsettings set org.gnome.shell.extensions.user-theme name ''; sleep 1
  gsettings set org.gnome.shell.extensions.user-theme name 'MacTahoe-Dark'
fi
# GTK3 apps (pywebview, Electron-with-GTK headers, older apps) use the solid
# variant: filled header bars. libadwaita apps keep the blur variant through
# the gtk-4.0 config, which is independent of this setting.
[[ "$(gsettings get org.gnome.desktop.interface gtk-theme)" == "'MacTahoe-Dark-solid'" ]] || { log "gtk3 theme drifted: resetting to the solid variant"; gsettings set org.gnome.desktop.interface gtk-theme 'MacTahoe-Dark-solid'; }
# 5b. shell CSS overrides (quick settings icon size) survive a theme rebuild
CSS="$HOME/.themes/MacTahoe-Dark/gnome-shell/gnome-shell.css"
if [[ -f "$CSS" && -f "$ROOT/config/gnome-shell-overrides.css" ]] && { ! grep -q 'tahoe-overrides' "$CSS" || grep -q '.lightbox { background-color: transparent; }' "$CSS"; }; then
  log "re-applying shell CSS overrides"
  python3 - "$CSS" "$ROOT/config/gnome-shell-overrides.css" <<'PY'
import sys,re
css=open(sys.argv[1]).read(); ov=open(sys.argv[2]).read()
css=re.sub(r"\n/\* tahoe-overrides:.*?/\* end tahoe-overrides \*/\n","\n",css,flags=re.S)
open(sys.argv[1],"w").write(css.rstrip()+"\n"+ov)
PY
  gsettings set org.gnome.shell.extensions.user-theme name ''; sleep 1; gsettings set org.gnome.shell.extensions.user-theme name 'MacTahoe-Dark'
fi

# 5c. Blur my Shell patch: modal dialogs (power off, log out, run) are
#     full-screen surfaces, so blurring them blurs and darkens the whole
#     screen. Take them out of the popup module's surface lists. Re-applied
#     after any refetch of the extension.
BSF="$EXT_DIR/blur-my-shell@aunetx/components/popup/blur_surface.js"
if [[ -f "$BSF" ]] && { grep -q "'modal-dialog'" "$BSF" || grep -q "\['modal-dialog', 'run-dialog'\]" "${BSF%blur_surface.js}targets.js"; }; then
  log "patching Blur my Shell: modal dialogs out of the blur surface lists"
  python3 - "$BSF" <<'PY'
import sys
p=sys.argv[1]; s=open(p).read()
s=s.replace("    'modal-dialog', 'run-dialog',\n","")
s=s.replace("    'datemenu-popover', 'quick-settings', 'modal-dialog',","    'datemenu-popover', 'quick-settings',")
open(p,"w").write(s)
t=p.replace("blur_surface.js","targets.js"); u=open(t).read()
u=u.replace("        style_classes: ['modal-dialog', 'run-dialog'],","        style_classes: [],  /* tahoe: modal dialogs are not blurred */")
open(t,"w").write(u)
PY
  gnome-extensions disable blur-my-shell@aunetx 2>/dev/null; gnome-extensions enable blur-my-shell@aunetx 2>/dev/null
fi

# 5d. GTK3 windows: the theme rounds only the top corners (24px 24px 0 0).
#     Round all four so pywebview, Meld and other GTK3 apps match.
for f in "$HOME"/.themes/MacTahoe-*/gtk-3.0/gtk.css "$HOME"/.themes/MacTahoe-*/gtk-3.0/gtk-dark.css; do
  [[ -f "$f" ]] && grep -q 'border-radius: 24px 24px 0 0' "$f" && { log "rounding GTK3 bottom corners in $(basename "$(dirname "$(dirname "$f")")")"; sed -i 's/border-radius: 24px 24px 0 0/border-radius: 24px/g' "$f"; }
done

# 5e. Rounded Window Corners Reborn: its published build targets GNOME 50 and
#     fails on 51 (Shell.GLSLEffect was removed). Apply the GNOME 51 port of
#     its three shader-effect files (from upstream PR 175) after any refetch.
#     A running shell only picks the port up after a logout.
RWC="$EXT_DIR/rounded-window-corners@fxgn"
if [[ -d "$RWC/effect" && -d "$ROOT/config/rwc-gnome51" ]] && grep -q "gi://Shell" "$RWC/effect/rounded_corners_effect.js" 2>/dev/null; then
  log "porting Rounded Window Corners to GNOME 51 (logout to activate)"
  cp "$ROOT"/config/rwc-gnome51/*.js "$RWC/effect/"
  python3 - "$RWC/metadata.json" <<'PY'
import json,sys
p=sys.argv[1]; m=json.load(open(p)); m["shell-version"]=["51"]; json.dump(m,open(p,"w"),indent=4)
PY
fi
gsettings set org.gnome.shell disable-extension-version-validation true
RWS="$RWC/schemas"; RS=org.gnome.shell.extensions.rounded-window-corners-reborn
if [[ -d "$RWS" ]]; then
  gsettings --schemadir "$RWS" set $RS skip-libadwaita-app true
  gsettings --schemadir "$RWS" set $RS border-width 0
  gsettings --schemadir "$RWS" set $RS blacklist "['steam','VRChat.exe','vrmonitor']"
  gsettings --schemadir "$RWS" set $RS global-rounded-corner-settings "{'padding': <{'left': uint32 0, 'right': uint32 0, 'top': uint32 0, 'bottom': uint32 0}>, 'keepRoundedCorners': <{'maximized': false, 'fullscreen': false}>, 'borderRadius': <uint32 24>, 'smoothing': <0.0>, 'borderColor': <(0.5, 0.5, 0.5, 1.0)>, 'enabled': <true>}"
fi

# 6. blur: the exact Blur my Shell module config. Applications blur on a
#    whitelist of system apps (static pipeline, works here); enable-all off.
BS="$EXT_DIR/blur-my-shell@aunetx/schemas"
if [[ -d "$BS" ]]; then
  # Compare as values, not text: gsettings prints 0.6 as 0.59999999999999998.
  bsg() {
    cur="$(gsettings --schemadir "$BS" get "org.gnome.shell.extensions.blur-my-shell$1" "$2")"
    if ! python3 - "$cur" "$3" <<'PY' 2>/dev/null
import sys
a, b = sys.argv[1].strip(), sys.argv[2].strip()
norm = lambda v: v.replace(" ", "")
try:
    same = abs(float(a) - float(b)) < 1e-6
except ValueError:
    same = norm(a) == norm(b)
sys.exit(0 if same else 1)
PY
    then log "blur$1 $2 drifted: resetting"; gsettings --schemadir "$BS" set "org.gnome.shell.extensions.blur-my-shell$1" "$2" "$3"; fi
  }
  bsg .applications blur true
  bsg .applications enable-all false
  bsg .applications static-blur true    # dynamic mode paints the window opaque on this GPU; static shows what is behind, blurred
  bsg .applications corner-radius 16
  bsg .applications pipeline "'pipeline_default_rounded'"
  bsg .applications customize true
  bsg "" hacks-level 0
  bsg .applications whitelist "['org.gnome.Nautilus','org.gnome.Settings','gnome-control-center','org.gnome.Console','kgx','org.gnome.TextEditor','org.gnome.Calculator','org.gnome.Loupe','org.gnome.Papers','org.gnome.Characters','org.gnome.clocks','org.gnome.Calendar','org.gnome.Weather','org.gnome.Music','org.gnome.Software','org.gnome.DiskUtility','org.gnome.baobab','org.gnome.SystemMonitor','org.gnome.tweaks','org.gnome.Extensions','org.gnome.Logs','org.gnome.font-viewer','org.kde.dolphin','org.kde.kate','org.kde.konsole']"
  bsg .applications sigma 30; bsg .applications brightness 0.6; bsg .applications opacity 215
  # Shell surfaces, per the theme author's Blur my Shell screenshot.
  bsg .panel blur false; bsg .panel override-background true; bsg .panel unblur-in-overview true
  bsg .overview blur true; bsg .overview style-components 0
  bsg .appfolder blur true; bsg .appfolder sigma 30; bsg .appfolder style-dialogs 1
  bsg .dash-to-dock blur true; bsg .dash-to-dock static-blur true; bsg .dash-to-dock pipeline "'pipeline_default_rounded'"
  bsg .dash-to-dock override-background false; bsg .dash-to-dock unblur-in-overview true
  # Popups: quick settings, menus, notifications. Static only; corner radii
  # follow the shell theme (33 px quick settings, 14 px menus and banners).
  bsg .popup blur "$POPUP_BLUR"
  if [[ "$POPUP_BLUR" == true ]]; then
    bsg .popup static-blur true; bsg .popup pipeline "'pipeline_default'"
    bsg .popup override-background true; bsg .popup preserve-shell-theme true; bsg .popup style-popup 0
    bsg .popup sigma 30; bsg .popup brightness 0.6
    bsg .popup quick-settings-corner-radius 33; bsg .popup menu-corner-radius 14; bsg .popup notification-corner-radius 14
  fi
fi

# 7. icons: theme selected and present (it is a symlink into the repo)
if [[ ! -f "$HOME/.local/share/icons/Tahoe-Material/index.theme" && -d "$ROOT/icons/Tahoe-Material" ]]; then
  log "icon theme link missing: restoring"; mkdir -p "$HOME/.local/share/icons"
  ln -sfn "$ROOT/icons/Tahoe-Material" "$HOME/.local/share/icons/Tahoe-Material"; changed=1
fi
[[ "$(gsettings get org.gnome.desktop.interface icon-theme)" == "'Tahoe-Material'" ]] || { [[ -d "$HOME/.local/share/icons/Tahoe-Material" ]] && { log "icon theme not set: applying"; gsettings set org.gnome.desktop.interface icon-theme 'Tahoe-Material'; }; }
# KDE apps (Dolphin, Kate, Konsole) read kdeglobals: the companion theme adds SF places icons
if [[ -d "$ROOT/icons/Tahoe-Material-KDE" ]]; then
  [[ -L "$HOME/.local/share/icons/Tahoe-Material-KDE" ]] || { log "KDE companion icon theme link missing: restoring"; ln -sfn "$ROOT/icons/Tahoe-Material-KDE" "$HOME/.local/share/icons/Tahoe-Material-KDE"; }
  [[ "$(kreadconfig6 --file kdeglobals --group Icons --key Theme 2>/dev/null)" == "Tahoe-Material-KDE" ]] || { log "KDE icon theme not set: applying"; kwriteconfig6 --file kdeglobals --group Icons --key Theme Tahoe-Material-KDE; }
fi

# 8. extension builds vs running shell: after a GNOME major update the old
#    build is refused; fetch the one for this version when it exists.
for e in "${EXTS[@]}"; do
  m="$EXT_DIR/$e/metadata.json"; [[ -f "$m" ]] || continue
  if ! python3 -c 'import json,sys; sys.exit(0 if sys.argv[2] in json.load(open(sys.argv[1]))["shell-version"] else 1)' "$m" "$SHELL_VER" 2>/dev/null; then
    tag="$(curl -s "https://extensions.gnome.org/extension-info/?uuid=$e&shell_version=$SHELL_VER" | python3 -c 'import json,sys; print(json.load(sys.stdin)["version_tag"])' 2>/dev/null || true)"
    if [[ -n "$tag" ]]; then
      log "$e is built for another GNOME; fetching the GNOME $SHELL_VER build"
      tmp="$(mktemp -d)"; curl -sL "https://extensions.gnome.org/download-extension/$e.shell-extension.zip?version_tag=$tag" -o "$tmp/e.zip"
      rm -rf "${EXT_DIR:?}/${e:?}"; mkdir -p "$EXT_DIR/$e"; python3 -c 'import zipfile,sys; zipfile.ZipFile(sys.argv[1]).extractall(sys.argv[2])' "$tmp/e.zip" "$EXT_DIR/$e"
      [[ -d "$EXT_DIR/$e/schemas" ]] && glib-compile-schemas "$EXT_DIR/$e/schemas"; rm -rf "$tmp"
      gdbus call --session --dest org.gnome.Shell --object-path /org/gnome/Shell --method org.gnome.Shell.Extensions.InstallRemoteExtension "$e" >/dev/null 2>&1 || true
      changed=1
    else
      log "$e has no GNOME $SHELL_VER build yet; it stays disabled until one is published"
    fi
  fi
done

# 9. interface drift
gs() { [[ "$(gsettings get "$1" "$2")" == "$3" ]] || { log "$2 drifted: resetting"; gsettings set "$1" "$2" "${3//\'/}"; }; }
gs org.gnome.desktop.interface cursor-theme "'MacTahoe-dark'"
gs org.gnome.desktop.interface color-scheme "'prefer-dark'"
gs org.gnome.desktop.wm.preferences button-layout "'close,minimize,maximize:'"
# Resize handles: Mutter's default 10 px grab area falls inside the 24 px
# rounded-corner clip, so corners cannot be grabbed. Widen it past the radius.
gs org.gnome.mutter draggable-border-width 28
# Wallpaper is deliberately not touched: the user picks it.

# 10. dock drift: the theme styles the dock; Dash to Dock must not override it
DD="$EXT_DIR/dash-to-dock@micxgx.gmail.com/schemas"
if [[ -d "$DD" ]]; then
  ddg() { [[ "$(gsettings --schemadir "$DD" get org.gnome.shell.extensions.dash-to-dock "$1")" == "$2" ]] || { log "dock $1 drifted: resetting"; gsettings --schemadir "$DD" set org.gnome.shell.extensions.dash-to-dock "$1" "${2//\'/}"; }; }
  ddg apply-custom-theme false; ddg transparency-mode "'DEFAULT'"; ddg custom-background-color false; ddg dock-position "'BOTTOM'"
fi

# 11. dock stylesheet: the theme's "tweaks.sh -d" renames it, which breaks Dash to Dock 110
if [[ -f "$EXT_DIR/dash-to-dock@micxgx.gmail.com/stylesheet.css.bak" && ! -f "$EXT_DIR/dash-to-dock@micxgx.gmail.com/stylesheet.css" ]]; then
  log "restoring Dash to Dock stylesheet"; mv "$EXT_DIR/dash-to-dock@micxgx.gmail.com/stylesheet.css.bak" "$EXT_DIR/dash-to-dock@micxgx.gmail.com/stylesheet.css"
  gnome-extensions disable dash-to-dock@micxgx.gmail.com; gnome-extensions enable dash-to-dock@micxgx.gmail.com
fi

# 12. icon theme contents: the generated set must exist and carry the current
#     layout (symbolic places for Files' sidebar, KDE companion). Regenerate
#     from the repo tokens when it does not; glyphs are fetched if missing.
if [[ -d "$ROOT/scripts" ]] && { [[ ! -f "$ROOT/icons/Tahoe-Material/symbolic/places/user-home-symbolic.svg" ]] || [[ ! -f "$ROOT/icons/Tahoe-Material-KDE/index.theme" ]] || [[ ! -f "$ROOT/icons/Tahoe-Material/apps/scalable/org.gnome.Nautilus.svg" ]] || [[ ! -f "$ROOT/icons/Tahoe-Material/places/scalable/folder-documents.svg" ]]; }; then
  log "icon theme incomplete: regenerating from tokens"
  ( cd "$ROOT" && python3 scripts/fetch-glyphs.py >/dev/null 2>&1; python3 scripts/gen-action-icons.py >/dev/null 2>&1; python3 -W ignore scripts/gen-app-icons.py --no-sheet >/dev/null 2>&1 )
  gtk-update-icon-cache -q -t -f "$HOME/.local/share/icons/Tahoe-Material" 2>/dev/null || true
  gsettings set org.gnome.desktop.interface icon-theme 'Adwaita'; sleep 1; gsettings set org.gnome.desktop.interface icon-theme 'Tahoe-Material'
fi

log "done"
