# Aleph X-Ray (standalone) — modifications

This is a modified version of BookOrbit and is not an official BookOrbit release.

## 2026-11-26 — 1.3.0-standalone.1

Taken from Aleph 1.3.0 (https://github.com/lara-2-ko/aleph.koplugin, commit 9de0a4a),
itself a modified version of BookOrbit (https://github.com/bookorbit/bookorbit):

- **Only X-Ray**: Aleph's own X-Ray (aleph_xr.lua, aleph_xr_ai.lua, aleph_xr_more.lua,
  aleph_xr_names.lua, aleph_xr_page.lua, aleph_xr_story.lua) and the 20 parts of Aleph it
  draws with (board UI, menus, sheets, toasts, background jobs, translations), unchanged
  except as listed here. Home, library, Goodreads, stats and every other Aleph feature
  are left out.
- **Renamed** every module aleph_* -> axr_*, the reader state ui._aleph_xr -> ui._axr,
  the paint hook flag, the text-menu button id and the tap zone id, so this plugin and
  Aleph can be installed together without one loading the other's files.
- **Own settings**: G_reader_settings "alephxray" instead of "aleph". The first time, the
  X-Ray settings found in Aleph's (xray_*) are copied over. Icon cache:
  cache/alephxray/icons. Translations: l10n/<code>/alephxray.po (Aleph's, renamed).
- **Same book files**: the names are still kept as aleph_xray.lua, aleph_xray_hits.lua,
  aleph_xray_text.lua, aleph_xray_story*.lua next to the book, so a book read for its
  names in Aleph opens here with them.
- **axr_local.lua**: a stand-in for Aleph's library (aleph_local.lua). The AI recap's
  "The book before" uses the title alone (Aleph's behaviour for a book not in its library).
- **axr_library_view.lua**: only ListView.sheet (the bottom sheet's layout) and its helpers
  from aleph_library_view.lua.
- **axr_xr.lua, XR.attach**: when X-Ray is attached after the book has opened (turned on in
  an open book), the tap-zone setup runs on the next tick instead of as a post-init
  callback, which KOReader no longer accepts then.
- **main.lua, _meta.lua**: new. KOReader menus (Tools > X-Ray (Aleph)) for what Aleph's
  Settings > X-Ray page did, the gesture "X-Ray (Aleph): open", and About / Legal notices.

## 2026-11-26 — 1.3.0-standalone.2

- **axr_xr_page.lua**: the hints for a missing AI key pointed to "Aleph's Settings > X-Ray";
  they now point to Tools > X-Ray (Aleph) > Descriptions with AI.

## 2026-11-26 — 1.3.0-standalone.3

- **main.lua**: the menu entry carries sorting_hint "tools", so KOReader shows it in Tools
  instead of the first tab as "NEW: X-Ray (Aleph)".

## 2026-11-26 — 1.3.0-standalone.4

- **main.lua**: the entry is placed first in Tools (reader and file browser) by adding it to
  KOReader's cached menu-order tables at start, the way Aleph pins itself (aleph_menu_pin.lua).
  Nothing is written to disk; sorting_hint "tools" stays as the fallback.

## 2026-11-26 — 1.3.0-standalone.5

- **main.lua**: a menu order saved on the device (settings/*_menu_order.lua) replaced the
  Tools list each time a menu was built, so the entry fell back to the end of Tools. The
  saved order is now given the entry as KOReader reads it (MenuSorter.readMSSettings);
  the file is never written. About shows the version.
