#!/usr/bin/env bash
# Per-user install of the CachyOS Tahoe theme. No root needed. Idempotent.
#
# Base: vinceliuice's MacTahoe-kde dark global theme, applied with its own
# panel layout. See docs/IMPLEMENTATION.md Phase 9. The Tahoe-Material icon
# theme is linked but only applied with --icons, while it is being reworked.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DATA="${XDG_DATA_HOME:-$HOME/.local/share}"
CONF="${XDG_CONFIG_HOME:-$HOME/.config}"
say() { printf '\033[1;36m==>\033[0m %s\n' "$*"; }

LNF="com.github.vinceliuice.MacTahoe-Dark"
if [[ ! -d "$DATA/plasma/look-and-feel/$LNF" && ! -d "/usr/share/plasma/look-and-feel/$LNF" ]]; then
  echo "Install MacTahoe-kde first: git clone https://github.com/vinceliuice/MacTahoe-kde && ./install.sh" >&2
  exit 1
fi

say "global theme"
kwriteconfig6 --file kwinrc --group Plugins --key shapecornersEnabled false
plasma-apply-lookandfeel -a "$LNF" --resetLayout >/dev/null 2>&1 || true
kwriteconfig6 --file kwinrc --group org.kde.kdecoration2 --key ButtonsOnLeft XAI
kwriteconfig6 --file kwinrc --group org.kde.kdecoration2 --key BorderSize Tiny
mkdir -p "$CONF/Kvantum"
printf '[General]\ntheme=MacTahoeDark\n' > "$CONF/Kvantum/kvantum.kvconfig"
kwriteconfig6 --file kdeglobals --group KDE --key widgetStyle kvantum

say "gtk theme"
# MacTahoe GTK (vinceliuice). The installer needs a pseudo-terminal for its
# progress animation, otherwise it exits before compiling anything.
GTKSRC="$HOME/.local/src/MacTahoe-gtk-theme"
if [[ ! -d "$GTKSRC" ]]; then
  mkdir -p "$HOME/.local/src"; git clone -q --depth 1 https://github.com/vinceliuice/MacTahoe-gtk-theme "$GTKSRC"
fi
if [[ ! -d "$HOME/.themes/MacTahoe-Dark" ]]; then
  rm -rf /tmp/MacTahoe.lock
  ( cd "$GTKSRC" && TERM=xterm-256color script -qfec "./install.sh" /dev/null >/dev/null 2>&1 ) || true
  ( cd "$GTKSRC" && ./install.sh -l >/dev/null 2>&1 ) || true
fi
qdbus6 org.kde.GtkConfig /GtkConfig org.kde.GtkConfig.setGtkTheme "MacTahoe-Dark" >/dev/null 2>&1 || true

say "icon theme (linked, not applied)"
mkdir -p "$DATA/icons"
ln -sfn "$ROOT/icons/Tahoe-Material" "$DATA/icons/Tahoe-Material"
gtk-update-icon-cache -q -t -f "$DATA/icons/Tahoe-Material" 2>/dev/null || true
if [[ "${1:-}" == "--icons" ]]; then
  say "applying Tahoe-Material icons"
  if compgen -G "$ROOT/overrides/*.desktop" >/dev/null; then
    mkdir -p "$DATA/applications"; cp "$ROOT"/overrides/*.desktop "$DATA/applications/"
    update-desktop-database "$DATA/applications" 2>/dev/null || true
  fi
  /usr/lib/plasma-changeicons Tahoe-Material 2>/dev/null || kwriteconfig6 --file kdeglobals --group Icons --key Theme Tahoe-Material
fi

qdbus6 org.kde.KWin /KWin reconfigure >/dev/null 2>&1 || true
say "done. Apps opened before this run pick up the style when relaunched."
