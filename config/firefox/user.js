// CachyOS Tahoe theme: Firefox chrome prefs.
// Loaded on every start; values here override prefs.js.

// Allow chrome/userChrome.css to load.
user_pref("toolkit.legacyUserProfileCustomizations.stylesheets", true);

// Let KWin draw the titlebar with the Darkly decoration so Firefox's frame
// matches every other window, instead of Firefox drawing its own tabs-in-
// titlebar chrome.
user_pref("browser.tabs.inTitlebar", 0);

// Dark toolbar and content theme regardless of the installed add-on theme.
user_pref("browser.theme.toolbar-theme", 0);
user_pref("browser.theme.content-theme", 0);

// Normal density; the stylesheet sets its own heights.
user_pref("browser.uidensity", 0);

// Rounded, tighter tab strip is CSS; nothing else here touches behaviour.
