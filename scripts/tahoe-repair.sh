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
#   9. interface drift: GTK theme, cursor, button layout (never the wallpaper)
#  10. dock drift: Dash to Dock back on the theme's own styling
#  11. dock stylesheet present (the theme's -d tweak deletes it)
#  12. icon theme contents: regenerate from the repo if the generated set is
#      missing or stale (symbolic places for Files, apps, KDE companion)
set -uo pipefail
log() { printf '[tahoe-repair] %s\n' "$*"; }

[[ "${XDG_CURRENT_DESKTOP:-}" == *GNOME* ]] || { log "not a GNOME session, nothing to do"; exit 0; }
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SRC="$HOME/.local/src/MacTahoe-gtk-theme"
EXT_DIR="$HOME/.local/share/gnome-shell/extensions"
EXTS=(dash-to-dock@micxgx.gmail.com blur-my-shell@aunetx appindicatorsupport@rgcjonas.gmail.com)
# Popup blur (quick settings, menus, notifications). Static mode renders on
# this machine where dynamic painted an opaque box. Switch with
#   tahoe-repair --popup-blur off      (writes config/popup-blur)
POPUP_FLAG="$ROOT/config/popup-blur"
case "${1:-}" in
  --popup-blur) echo "${2:-on}" > "$POPUP_FLAG"; shift 2 ;;
esac
POPUP_BLUR=true; [[ -f "$POPUP_FLAG" && "$(cat "$POPUP_FLAG")" == "off" ]] && POPUP_BLUR=false
WANT="['user-theme@gnome-shell-extensions.gcampax.github.com','dash-to-dock@micxgx.gmail.com','blur-my-shell@aunetx','appindicatorsupport@rgcjonas.gmail.com']"
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
  if [[ "$st" == "INACTIVE" || "$st" == "ERROR" ]]; then log "re-enabling $e ($st)"; gnome-extensions enable "$e" 2>/dev/null; changed=1; fi
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
[[ "$(gsettings get org.gnome.desktop.interface gtk-theme)" == "'MacTahoe-Dark'" ]] || gsettings set org.gnome.desktop.interface gtk-theme 'MacTahoe-Dark'
# 5b. shell CSS overrides (quick settings icon size) survive a theme rebuild
CSS="$HOME/.themes/MacTahoe-Dark/gnome-shell/gnome-shell.css"
if [[ -f "$CSS" && -f "$ROOT/config/gnome-shell-overrides.css" ]] && ! grep -q 'tahoe-overrides' "$CSS"; then
  log "re-appending shell CSS overrides"; printf '\n' >> "$CSS"; cat "$ROOT/config/gnome-shell-overrides.css" >> "$CSS"
  gsettings set org.gnome.shell.extensions.user-theme name ''; sleep 1; gsettings set org.gnome.shell.extensions.user-theme name 'MacTahoe-Dark'
fi

# 6. blur: the exact Blur my Shell module config. Applications blur on a
#    whitelist of system apps (static pipeline, works here); enable-all off.
BS="$EXT_DIR/blur-my-shell@aunetx/schemas"
if [[ -d "$BS" ]]; then
  bsg() { [[ "$(gsettings --schemadir "$BS" get "org.gnome.shell.extensions.blur-my-shell$1" "$2" | tr -d ' ')" == "$(tr -d ' ' <<<"$3")" ]] || { log "blur$1 $2 drifted: resetting"; gsettings --schemadir "$BS" set "org.gnome.shell.extensions.blur-my-shell$1" "$2" "$3"; }; }
  bsg .applications blur true
  bsg .applications enable-all false
  bsg .applications static-blur true    # dynamic mode paints the window opaque on this GPU; static shows what is behind, blurred
  bsg .applications corner-radius 16
  bsg .applications pipeline "'pipeline_default_rounded'"
  bsg .applications customize true
  bsg "" hacks-level 0
  bsg .applications whitelist "['org.gnome.Nautilus','org.gnome.Settings','gnome-control-center','org.gnome.Console','kgx','org.gnome.TextEditor','org.gnome.Calculator','org.gnome.Loupe','org.gnome.Papers','org.gnome.Characters','org.gnome.clocks','org.gnome.Calendar','org.gnome.Weather','org.gnome.Music','org.gnome.Software','org.gnome.DiskUtility','org.gnome.baobab','org.gnome.SystemMonitor','org.gnome.tweaks','org.gnome.Extensions','org.gnome.Logs','org.gnome.font-viewer','org.kde.dolphin','org.kde.kate','org.kde.konsole']"
  bsg .popup blur "$POPUP_BLUR"
  [[ "$POPUP_BLUR" == true ]] && { bsg .popup static-blur true; bsg .popup pipeline "'pipeline_default'"; }
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
