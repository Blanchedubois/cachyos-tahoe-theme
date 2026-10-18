#!/usr/bin/env bash
# GNOME setup for the CachyOS Tahoe theme. Per-user, no root. Idempotent.
#
# Prerequisites (root, once): sudo pacman -S --needed gnome gnome-tweaks gnome-shell-extensions
# Then log out and choose the GNOME session. This script can run from any
# session; GNOME reads the settings at login. Extensions are fetched for the
# installed gnome-shell major version.
set -euo pipefail
say() { printf '\033[1;36m==>\033[0m %s\n' "$*"; }

SHELL_VER="$(gnome-shell --version | grep -oE '[0-9]+' | head -1)"
EXT_DIR="$HOME/.local/share/gnome-shell/extensions"
SRC="$HOME/.local/src/MacTahoe-gtk-theme"
EXTS=(dash-to-dock@micxgx.gmail.com blur-my-shell@aunetx appindicatorsupport@rgcjonas.gmail.com)

# 1. MacTahoe GTK + shell theme, full install (needs a pseudo-terminal).
if [[ ! -d "$HOME/.themes/MacTahoe-Dark/gnome-shell" ]]; then
  say "MacTahoe GTK and shell theme"
  [[ -d "$SRC" ]] || git clone -q --depth 1 https://github.com/vinceliuice/MacTahoe-gtk-theme "$SRC"
  rm -rf /tmp/MacTahoe.lock
  ( cd "$SRC" && TERM=xterm-256color script -qfec "./install.sh" /dev/null >/dev/null 2>&1 ) || true
  ( cd "$SRC" && ./install.sh -l >/dev/null 2>&1 ) || true
fi

# 2. Extensions from extensions.gnome.org for this shell version.
say "extensions for GNOME $SHELL_VER"
mkdir -p "$EXT_DIR"
tmp="$(mktemp -d)"
for e in "${EXTS[@]}"; do
  tag="$(curl -s "https://extensions.gnome.org/extension-info/?uuid=$e&shell_version=$SHELL_VER" \
        | python3 -c 'import json,sys; print(json.load(sys.stdin)["version_tag"])' 2>/dev/null || true)"
  if [[ -z "$tag" ]]; then echo "    no build of $e for GNOME $SHELL_VER yet; skipped"; continue; fi
  curl -sL "https://extensions.gnome.org/download-extension/$e.shell-extension.zip?version_tag=$tag" -o "$tmp/$e.zip"
  rm -rf "${EXT_DIR:?}/${e:?}"; mkdir -p "$EXT_DIR/$e"
  python3 -c 'import zipfile,sys; zipfile.ZipFile(sys.argv[1]).extractall(sys.argv[2])' "$tmp/$e.zip" "$EXT_DIR/$e"
  [[ -d "$EXT_DIR/$e/schemas" ]] && glib-compile-schemas "$EXT_DIR/$e/schemas"
done
rm -rf "$tmp"

# 3. Core look.
say "interface"
gsettings set org.gnome.desktop.interface gtk-theme 'MacTahoe-Dark'
gsettings set org.gnome.desktop.interface icon-theme 'MacTahoe-dark'
gsettings set org.gnome.desktop.interface cursor-theme 'MacTahoe-dark'
gsettings set org.gnome.desktop.interface color-scheme 'prefer-dark'
gsettings set org.gnome.desktop.wm.preferences button-layout 'close,minimize,maximize:'
gsettings set org.gnome.shell disable-user-extensions false
gsettings set org.gnome.shell enabled-extensions \
  "['user-theme@gnome-shell-extensions.gcampax.github.com','dash-to-dock@micxgx.gmail.com','blur-my-shell@aunetx','appindicatorsupport@rgcjonas.gmail.com']"
gsettings set org.gnome.shell.extensions.user-theme name 'MacTahoe-Dark'
gsettings set org.gnome.shell favorite-apps \
  "['org.gnome.Nautilus.desktop','firefox.desktop','discord.desktop','steam.desktop','com.anthropic.Claude.desktop','org.gnome.Console.desktop','org.gnome.Calculator.desktop','org.gnome.TextEditor.desktop','org.gnome.Settings.desktop']"

# 4. Dock: bottom, intellihide, 48 px, themed by the shell theme, glass.
say "dock"
dd() { gsettings --schemadir "$EXT_DIR/dash-to-dock@micxgx.gmail.com/schemas" set org.gnome.shell.extensions.dash-to-dock "$1" "$2"; }
if [[ -d "$EXT_DIR/dash-to-dock@micxgx.gmail.com/schemas" ]]; then
  dd dock-position 'BOTTOM'; dd dock-fixed false; dd intellihide true
  dd intellihide-mode 'FOCUS_APPLICATION_WINDOWS'; dd autohide true
  dd dash-max-icon-size 48; dd icon-size-fixed true
  dd show-trash true; dd show-mounts false; dd show-show-apps-button true; dd show-apps-at-top false
  dd apply-custom-theme false; dd custom-theme-shrink true
  dd transparency-mode 'FIXED'; dd background-opacity 0.35
  dd running-indicator-style 'DOTS'; dd click-action 'minimize-or-previews'; dd scroll-action 'cycle-windows'
  dd multi-monitor false; dd extend-height false
fi

# 5. Blur: panel, dock and overview.
say "blur"
bs() { gsettings --schemadir "$EXT_DIR/blur-my-shell@aunetx/schemas" set "$1" "$2" "$3"; }
if [[ -d "$EXT_DIR/blur-my-shell@aunetx/schemas" ]]; then
  bs org.gnome.shell.extensions.blur-my-shell.panel blur true
  bs org.gnome.shell.extensions.blur-my-shell.panel static-blur true
  bs org.gnome.shell.extensions.blur-my-shell.dash-to-dock blur true
  bs org.gnome.shell.extensions.blur-my-shell.dash-to-dock style-dash-to-dock 0
  bs org.gnome.shell.extensions.blur-my-shell.overview blur true
fi

say "done. Log out and choose GNOME; extensions load on that login."
