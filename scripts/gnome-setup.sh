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
EXTS=(dash-to-dock@micxgx.gmail.com blur-my-shell@aunetx appindicatorsupport@rgcjonas.gmail.com rounded-window-corners@fxgn)
WINDOW_RADIUS=14   # px; the theme ships 24, which reads as Finder-heavy

# 1. MacTahoe GTK + shell theme, exactly as the README recommends for GNOME:
#    the blur variant (-b) since Blur my Shell is used, all colour and
#    opacity variants, the libadwaita link, the Dash to Dock fix, and the
#    bundled day/night wallpaper. The installer needs a pseudo-terminal.
say "MacTahoe GTK and shell theme (blur variant)"
[[ -d "$SRC" ]] || git clone -q --depth 1 https://github.com/vinceliuice/MacTahoe-gtk-theme "$SRC"
# One window radius for everything: patch the theme's Sass variable before
# building, and clip non-GTK windows at the same value with the extension.
sed -i "s/^\$wm_radius: .*/\$wm_radius: ${WINDOW_RADIUS}px;/" "$SRC/src/sass/_variables.scss"
rm -rf /tmp/MacTahoe.lock
( cd "$SRC" && TERM=xterm-256color script -qfec "./install.sh -b" /dev/null >/dev/null 2>&1 ) || true
( cd "$SRC" && ./install.sh -b -l >/dev/null 2>&1 ) || true
( cd "$SRC" && ./tweaks.sh -d >/dev/null 2>&1 ) || true
# The wallpaper installer writes its properties file where a directory should
# be when run as a user; create the directory first.
PROPS="$HOME/.local/share/gnome-background-properties"
[[ -f "$PROPS" ]] && rm -f "$PROPS"; mkdir -p "$PROPS"
( cd "$SRC/wallpaper" && ./install-gnome-backgrounds.sh >/dev/null 2>&1 ) || true
BG="$HOME/.local/share/backgrounds/MacTahoe"
if [[ -f "$BG/MacTahoe-night.jpeg" ]]; then
  gsettings set org.gnome.desktop.background picture-uri "file://$BG/MacTahoe-day.jpeg"
  gsettings set org.gnome.desktop.background picture-uri-dark "file://$BG/MacTahoe-night.jpeg"
  gsettings set org.gnome.desktop.background picture-options 'zoom'
  gsettings set org.gnome.desktop.screensaver picture-uri "file://$BG/MacTahoe-night.jpeg"
fi
# Firefox theme from the same repo, only when Firefox is closed.
pgrep -x firefox >/dev/null || ( cd "$SRC" && ./tweaks.sh -f >/dev/null 2>&1 ) || true

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
# Rounded Window Corners Reborn ships marked for GNOME 50 but runs on 51.
gsettings set org.gnome.shell disable-extension-version-validation true
gsettings set org.gnome.shell enabled-extensions \
  "['user-theme@gnome-shell-extensions.gcampax.github.com','dash-to-dock@micxgx.gmail.com','blur-my-shell@aunetx','appindicatorsupport@rgcjonas.gmail.com','rounded-window-corners@fxgn']"
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

# 5. Blur my Shell, key for key from the author's screenshot in the README
#    (blur-my-shell.png): panel off, overview on with unstyled components,
#    app folders on, dock on with the rounded pipeline, applications on for all.
say "blur (author's settings)"
bs() { gsettings --schemadir "$EXT_DIR/blur-my-shell@aunetx/schemas" set "org.gnome.shell.extensions.blur-my-shell$1" "$2" "$3"; }
if [[ -d "$EXT_DIR/blur-my-shell@aunetx/schemas" ]]; then
  bs .panel blur false; bs .panel override-background true; bs .panel unblur-in-overview true
  bs .overview blur true; bs .overview style-components 0; bs .overview pipeline 'pipeline_default'
  bs .appfolder blur true; bs .appfolder sigma 30; bs .appfolder brightness 1.0; bs .appfolder style-dialogs 1
  bs .dash-to-dock blur true; bs .dash-to-dock static-blur true; bs .dash-to-dock pipeline 'pipeline_default_rounded'
  bs .dash-to-dock override-background false; bs .dash-to-dock unblur-in-overview true
  bs .applications blur true; bs .applications sigma 50; bs .applications brightness 1.0; bs .applications opacity 255
  bs .applications blur-on-overview false; bs .applications enable-all true
  bs .applications blacklist "['Plank','com.desktop.ding','Conky']"
fi
# 6. Rounded corners for windows that do not draw their own (Electron, Firefox,
#    Steam, Qt). libadwaita apps are skipped: the theme already rounds them.
say "window corners"
RW="$EXT_DIR/rounded-window-corners@fxgn/schemas"; RS=org.gnome.shell.extensions.rounded-window-corners-reborn
if [[ -d "$RW" ]]; then
  gsettings --schemadir "$RW" set $RS skip-libadwaita-app true
  gsettings --schemadir "$RW" set $RS border-width 0
  gsettings --schemadir "$RW" set $RS global-rounded-corner-settings "{'padding': <{'left': uint32 0, 'right': uint32 0, 'top': uint32 0, 'bottom': uint32 0}>, 'keepRoundedCorners': <{'maximized': false, 'fullscreen': false}>, 'borderRadius': <uint32 $WINDOW_RADIUS>, 'smoothing': <0.0>, 'borderColor': <(0.5, 0.5, 0.5, 1.0)>, 'enabled': <true>}"
fi
# Icons: the Tahoe-Material theme, SF Symbol watermarks on glass squircles.
say "icons"
mkdir -p "$HOME/.local/share/icons"; ln -sfn "$ROOT/icons/Tahoe-Material" "$HOME/.local/share/icons/Tahoe-Material"
gtk-update-icon-cache -q -t -f "$HOME/.local/share/icons/Tahoe-Material" 2>/dev/null || true
gsettings set org.gnome.desktop.interface icon-theme 'Tahoe-Material'
# Reload the shell theme so a reinstalled stylesheet is picked up.
gsettings set org.gnome.shell.extensions.user-theme name ''; gsettings set org.gnome.shell.extensions.user-theme name 'MacTahoe-Dark'

say "done. Log out and choose GNOME; extensions load on that login."
