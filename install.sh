#!/usr/bin/env bash
# Per-user install of the CachyOS Tahoe theme. No root needed.
# Idempotent: re-running updates everything in place.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DATA="${XDG_DATA_HOME:-$HOME/.local/share}"
CONF="${XDG_CONFIG_HOME:-$HOME/.config}"

say() { printf '\033[1;36m==>\033[0m %s\n' "$*"; }

# 1. Icon theme: symlink so regenerating icons needs no reinstall.
say "icon theme"
mkdir -p "$DATA/icons"
ln -sfn "$ROOT/icons/Tahoe-Material" "$DATA/icons/Tahoe-Material"
gtk-update-icon-cache -q -t -f "$DATA/icons/Tahoe-Material" 2>/dev/null || true

# 1b. Plasma style overlay: MacTahoe-Dark with a lighter frosted popup card and inset rounded highlights.
say "plasma style"
mkdir -p "$DATA/plasma/desktoptheme"
ln -sfn "$ROOT/plasma/Tahoe-Material" "$DATA/plasma/desktoptheme/Tahoe-Material"

# 2. Desktop entry overrides for apps whose Icon= is an absolute path or shared.
if compgen -G "$ROOT/overrides/*.desktop" >/dev/null; then
  say "desktop entry overrides"
  mkdir -p "$DATA/applications"
  cp "$ROOT"/overrides/*.desktop "$DATA/applications/"
  update-desktop-database "$DATA/applications" 2>/dev/null || true
fi

# 3. Darkly application style settings, Klassy window decoration settings.
say "darkly and klassy"
cp "$ROOT/config/darklyrc" "$CONF/darklyrc"
mkdir -p "$CONF/klassy"
cp "$ROOT/config/klassyrc" "$CONF/klassy/klassyrc"
if ! pacman -Q klassy >/dev/null 2>&1; then
  echo "    note: klassy is not installed; the titlebar falls back to Darkly until it is (AUR: klassy)"
fi

# 4. KWin: Darkly decoration, button layout, rounded corners.
say "kwin"
while IFS='=' read -r key val; do
  [[ -z "$key" || "$key" == \[* ]] && continue
  kwriteconfig6 --file kwinrc --group Round-Corners --key "$key" "$val"
done < "$ROOT/config/kwinrc.round-corners"
while IFS='=' read -r key val; do
  [[ -z "$key" || "$key" == \[* ]] && continue
  kwriteconfig6 --file kwinrc --group org.kde.kdecoration2 --key "$key" "$val"
done < "$ROOT/config/kwinrc.decoration"
kwriteconfig6 --file kwinrc --group Plugins --key shapecornersEnabled true
# Overview on the top-left hot corner (ElectricBorder TopLeft = 7).
kwriteconfig6 --file kwinrc --group Effect-overview --key BorderActivate 7

# 5. Accent colour, header colour and Konsole profile (Phase 5).
say "accent and konsole"
kwriteconfig6 --file kdeglobals --group General --key AccentColor "10,132,255"
mkdir -p "$DATA/konsole"
cp "$ROOT"/config/konsole/Tahoe.colorscheme "$ROOT"/config/konsole/Tahoe.profile "$DATA/konsole/"
kwriteconfig6 --file konsolerc --group "Desktop Entry" --key DefaultProfile Tahoe.profile
if ! fc-list | grep -qi 'Inter'; then
  echo "    note: the Inter font is not installed; 'sudo pacman -S inter-font' then set it under Fonts if you want it"
fi

# 5a. Electron apps: drop Chromium's client-side shadow so KWin's rounding and
# shadow apply cleanly. Takes effect on the app's next launch.
say "electron flags"
cp "$ROOT/config/electron/claude-desktop-flags.conf" "$CONF/claude-desktop-flags.conf"

# 5b. Firefox chrome (default-release profile from profiles.ini). Skipped while Firefox runs.
say "firefox"
FFDIR="$CONF/mozilla/firefox"; [[ -d "$FFDIR" ]] || FFDIR="$HOME/.mozilla/firefox"
if [[ -f "$FFDIR/profiles.ini" ]] && ! pgrep -x firefox >/dev/null; then
  FFPROF="$(awk -F= '/^\[Install/{f=1} f&&/^Default=/{print $2; exit}' "$FFDIR/profiles.ini")"
  if [[ -n "$FFPROF" && -d "$FFDIR/$FFPROF" ]]; then
    mkdir -p "$FFDIR/$FFPROF/chrome"
    cp "$ROOT/config/firefox/userChrome.css" "$FFDIR/$FFPROF/chrome/userChrome.css"
    cp "$ROOT/config/firefox/user.js" "$FFDIR/$FFPROF/user.js"
  fi
else
  echo "    note: Firefox is running or has no profile; chrome files not installed"
fi

# 6. Top panel layout (P1 to P7).
say "panel"
qdbus6 org.kde.plasmashell /PlasmaShell org.kde.PlasmaShell.evaluateScript "$(cat "$ROOT/config/panel.js")" >/dev/null 2>&1 || true

# 7. Apply: icons, widget style, then reload.
say "apply"
/usr/lib/plasma-changeicons Tahoe-Material 2>/dev/null || kwriteconfig6 --file kdeglobals --group Icons --key Theme Tahoe-Material
kwriteconfig6 --file kdeglobals --group KDE --key widgetStyle Darkly
plasma-apply-desktoptheme Tahoe-Material >/dev/null 2>&1 || kwriteconfig6 --file plasmarc --group Theme --key name Tahoe-Material
qdbus6 org.kde.KWin /KWin reconfigure >/dev/null 2>&1 || true
# The Rounded Corners effect only re-reads outline colours and widths on a
# full reload, not on reconfigure.
qdbus6 org.kde.KWin /Effects org.kde.kwin.Effects.unloadEffect kwin4_effect_shapecorners >/dev/null 2>&1 || true
qdbus6 org.kde.KWin /Effects org.kde.kwin.Effects.loadEffect kwin4_effect_shapecorners >/dev/null 2>&1 || true
dbus-send --session --type=signal /KGlobalSettings org.kde.KGlobalSettings.notifyChange int32:2 int32:0 2>/dev/null || true

say "done. Apps opened before this run pick up the style when relaunched."
