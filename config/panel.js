// Top panel layout for the CachyOS Tahoe theme. Applied by install.sh through
// plasmashell's scripting interface. Idempotent: safe to re-run.
//
// Steps P1 to P7 from docs/IMPLEMENTATION.md section 4.1.
for (var p of panels()) {
  if (p.location != "top") continue;

  // P1: 36 px, floating so popups detach as full rounded cards.
  p.height = 36;
  p.floating = true;

  var toRemove = [];
  var separators = 0;
  for (var id of p.widgetIds) {
    var w = p.widgetById(id);

    // P2: CachyOS mark as the launcher glyph (symbolic, from the icon theme).
    if (w.type == "org.kde.plasma.kickoff") {
      w.currentConfigGroup = ["General"];
      w.writeConfig("icon", "cachyos-launcher");
      w.reloadConfig();
    }

    // P6: 24 hour clock, no date, semibold 13.
    if (w.type == "org.kde.plasma.digitalclock") {
      w.currentConfigGroup = ["Appearance"];
      w.writeConfig("showDate", false);
      w.writeConfig("use24hFormat", 2);
      w.writeConfig("autoFontAndSize", false);
      w.writeConfig("fontFamily", "Noto Sans");
      w.writeConfig("fontSize", 13);
      w.writeConfig("fontWeight", 600);
      w.reloadConfig();
    }

    // P5: large spacing between tray icons so the hover highlight of one
    // item does not bleed into its neighbours.
    if (w.type == "org.kde.plasma.systemtray") {
      w.currentConfigGroup = ["General"];
      w.writeConfig("iconSpacing", 2);
      w.reloadConfig();
    }

    // P4: one margins separator is enough between the tray and the clock.
    if (w.type == "org.kde.plasma.marginsseparator") {
      separators++;
      if (separators > 1) toRemove.push(w);
    }

    // P7: show desktop leaves; Overview takes the top-left hot corner instead.
    if (w.type == "org.kde.plasma.showdesktop") toRemove.push(w);
  }
  for (var w of toRemove) w.remove();
}
