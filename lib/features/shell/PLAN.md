# PLAN — Shell (App Frame & Navigation)

## Purpose

The **shell** feature is the application frame: the themed sidebar navigation, the traffic-light chrome, and the routed page host (`home_page.dart`) that instantiates the other features' pages and hands them their controllers.

## Thought process & decisions

### Why the shell is a feature rather than boilerplate in `ui/`
- The shell is *compositional glue*: it decides which pages exist, what order they appear in, and how they're wired to shared controllers. That is real product logic worth documenting and testing — not incidental scaffolding.
- Keeping it a feature means the sidebar's nav model (the list of `_NavItem`s and the `_selectedIndex` page switch) is a first-class, extensible thing. Adding a new capability (e.g. Phase 2's **Torrents** page) is a one-line nav item + one indexed page — the shell is the natural integration point.

### Which parts live here vs. in core
- The shared chrome is split deliberately:
  - **core** owns the reusable widgets: `tubemate_sidebar` (nav rail + `Scanlines` decorative effect), `tubemate_controls` (button/toggle primitives), `traffic_lights` (the macOS-style window chrome). These are visual, dependency-free pieces.
  - **shell** owns the *wiring*: `home_page.dart` selects the active page, constructs each feature's controller (Download, Convert, Schedule, Settings) once, and passes them down.
- This is why `Scanlines` lives in `core/widgets/tubemate_sidebar.dart` — it's a generic visual used by both the shell and by dialogs (e.g. convert page), so it must not be trapped inside a feature.

### Page hosting
- `home_page.dart` keeps a `_selectedIndex` and swaps among shell/download/convert/schedule/settings content. It is the single place that instantiates the domain controllers, so controller lifecycle is owned exactly once and shared across pages that need them.

### Navigation testability
- The sidebar routes (eg. "Convert tab renders and routes from sidebar") are covered by widget tests, which is why nav behavior lives in a testable widget container rather than scattered across pages.

## Files

- `ui/home_page.dart` — app shell: instantiates feature controllers, hosts the sidebar + indexed pages.

## Design invariants

- Controllers are constructed exactly once at the shell and passed down (no per-page singletons).
- Sidebar nav is data-driven (`_NavItem` list + `_selectedIndex`) so adding a page is additive, not invasive.
- Reusable chrome stays in `core`; the shell only wires it together.
- Phase 2 integration point: add a "Torrents" `_NavItem`, a `TorrentController`, and a `TorrentsPage` slot here.
