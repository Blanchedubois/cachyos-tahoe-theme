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
#   6. Blur my Shell applications module off (it breaks the quick settings)
#   7. icon theme is Tahoe-Material
set -uo pipefail
log() { printf '[tahoe-repair] %s\n' "$*"; }

[[ "${XDG_CURRENT_DESKTOP:-}" == *GNOME* ]] || { log "not a GNOME session, nothing to do"; exit 0; }
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SRC="$HOME/.local/src/MacTahoe-gtk-theme"
EXT_DIR="$HOME/.local/share/gnome-shell/extensions"
EXTS=(dash-to-dock@micxgx.gmail.com blur-my-shell@aunetx appindicatorsupport@rgcjonas.gmail.com)
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

# 6. blur: applications module off
BS="$EXT_DIR/blur-my-shell@aunetx/schemas"
if [[ -d "$BS" && "$(gsettings --schemadir "$BS" get org.gnome.shell.extensions.blur-my-shell.applications blur)" == "true" ]]; then
  log "turning off Blur my Shell applications module (breaks quick settings)"
  gsettings --schemadir "$BS" set org.gnome.shell.extensions.blur-my-shell.applications blur false
fi

# 7. icons
[[ "$(gsettings get org.gnome.desktop.interface icon-theme)" == "'Tahoe-Material'" ]] || { [[ -d "$HOME/.local/share/icons/Tahoe-Material" ]] && gsettings set org.gnome.desktop.interface icon-theme 'Tahoe-Material'; }

log "done"
