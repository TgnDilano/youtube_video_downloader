# PLAN — Settings (Preferences & Theme)

## Purpose

The **settings** feature owns user preferences that shape the rest of the app — the color **theme** and the global media **directory** (where downloads / converts / torrents land) — plus the handful of toggleable behaviors (clipboard watch, retention, autostart).

## Thought process & decisions

### Why settings is its own feature
- Preferences are consumed by every other feature, so settings is the canonical source of shared state. Putting it in a feature (not core) keeps core as pure "plumbing" (theme tokens, services, widgets) while settings owns the *user-facing* concept of a preference and its persistence.
- Other features depend on settings' values but never write them; direction of dependency is one-way (features read settings).

### Persistence
- Perferences are loaded once at startup **before** `runApp` via a `ready` future on `SettingsController`. This removes the startup color flash — the theme is correct on the very first frame rather than swapping after first paint.
- Everything is serialized to a single JSON store and restored on launch so the app state (theme color, directory, toggles) is consistent across restarts.

### Theme model
- `TColors` / `TText` / `TColorScheme` are the design tokens; `kColorSchemes` is the curated palette; `buildTubemateTheme` assembles a `ThemeData`.
- `TColors.accentRevision` lets a live, user-chosen accent drive the theme reactively. The sidebar `_Logo` is deliberately **non-const** so it re-renders with the new primary color the moment the user changes it.
- The color picker (`color_picker_dialog.dart`) is where the user picks from `kColorSchemes`.

### Directory
- The global media directory (the default destination for downloads/converts/torrents) is resolved through `BinaryResolver`-style path plumbing and exposed to every feature so they default to it, while still letting the user override per-job in `input_area`.

### Cosmetic behavior
- The settings scrollbar is hidden (via `ScrollConfiguration`) for a cleaner panel, since the panel content is short and always fits.

## Files

- `domain/settings_controller.dart` — loads/saves preferences, exposes theme + directory + toggles, `ready` future for pre-runApp init.
- `ui/settings_page.dart` — the preferences panel (theme color, media directory, toggles).
- `ui/color_picker_dialog.dart` — pick a color scheme from `kColorSchemes`.

## Design invariants

- Settings is the one writer of user preferences; other features are read-only consumers.
- Startup must apply the stored theme before the first frame (no flash).
- Directory + theme values must be observable so dependent features rebuild when changed.
