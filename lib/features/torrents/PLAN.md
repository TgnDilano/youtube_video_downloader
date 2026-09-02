# PLAN — Torrents (BitTorrent Transport)

## Purpose

The **torrents** feature adds a second transport alongside download/convert: paste a **magnet link** or pick a **`.torrent` file**, save into a user-chosen folder, and manage the transfer (progress, peers, seeding) in a cassette-style list.

## Thought process & decisions

### Why a native engine wrapper (`libtorrent`)
- Reimplementing the BitTorrent protocol in Dart is a bad idea (speed, DHT/PEX/uTP, NAT traversal all matter). We wrap **`libtorrent_flutter`**, the Flutter binding around the same C++ `libtorrent 2.x` engine behind qBittorrent/Deluge/Transmission.
- The plugin ships prebuilt native binaries (fetched once on first build), so no manual bundling is needed; it handles init, session setup, DHT/peer discovery, and a streaming server we do not enable here.
- This matches the existing philosophy of driving heavy native work from native code (`yt-dlp`, `ffmpeg`) rather than reimplementing it.

### The adapter boundary — why `data/torrent_engine.dart`
- The plugin exposes a live singleton (`LibtorrentFlutter.instance`) and an imperative API (`addMagnet`, `pauseTorrent`, …). If domain/UI code touched that directly, nothing outside the plugin would be unit-testable and the coupling would spread.
- `TorrentEngine` is a thin adapter that:
  - starts the engine once (`init`)
  - wraps add/pause/resume/remove in our own signatures
  - subscribes to the `torrentUpdates` stream and maps plugin `TorrentInfo` → our UI `TorrentTask`
  - exposes an observable snapshot so the controller/UI never import the plugin type.
- Everything above the engine (controller, task, source, UI, tests) stays plugin-free and unit-testable.

### Task model — `torrent_task.dart`
- `TorrentTask` is a `ChangeNotifier` mirroring `DownloadTask`'s shape: id, name, savePath, source, progress, download/upload rate, total done/wanted, peers/seeds, state, error.
- Deliberately **not** reusing `DownloadTask`: torrents differ in shape (no resolution/audio/cookies; instead peers, seeds, seeding state, .torrent file) and in lifecycle (metadata resolution, seeding after 100%). Keeping them separate preserves each feature's clarity — the same reason the download feature gets its own model versus convert.

### Source model — `torrent_source.dart`
- Normalizes the two inputs into one shape: a `magnet:` URI or a path to a `.torrent` file. Provides a `kind` for the UI and validation of the input string so the page can reject garbage before handing it to the native engine.

### Seeding policy — user confirmed: **keep seeding until user stops**
- Unlike the FDM-style "stop on complete" default, we keep the torrent uploading (seeding) after it hits 100% until the user explicitly pauses or removes it. State merely transitions to "Seeding" in the card; `removeTorrent` is the only way to fully stop sharing.

### Save location — user confirmed: **always prompt per job**
- There is no global default directory for torrents. Each add (magnet or `.torrent`) opens a directory/folder picker first, and the chosen path is passed to the engine's save path. This keeps the user in complete control of where data lands.

### Entry point & UI
- A new **Torrents** item is added to the sidebar (index 3) and its page is slotted into the shell's `IndexedStack` alongside download/convert/settings.
- `torrents_page.dart` hosts the input (magnet text field + `.torrent` picker + destination prompt) and a list of `TorrentCard`s.
- `widgets/torrent_card.dart` is a cassette-style card (FDM-like): name (or "fetching metadata…"), progress bar + %, size done/total, DL/UL speed, peers/seeds badge, and a state label ("Downloading" / "Seeding" / "Paused" / error). It keeps its own `ui/widgets/` folder for symmetry with the download feature.

### Why torrents keeps seeding by default (documented choice)
- Torrent health relies on leechers seeding back. Since this is a personal transport tool, seeding is the respectful default; users who want to stop can remove the torrent. This decision is intentionally made explicit here rather than hidden in code.

## Files

- `domain/torrent_source.dart` — normalized input (magnet vs `.torrent` file) + validation.
- `domain/torrent_task.dart` — `ChangeNotifier` task model mirroring `DownloadTask` shape.
- `domain/torrent_controller.dart` — owns the engine, exposes observable tasks, add/pause/resume/remove, category list.
- `data/torrent_engine.dart` — thin `libtorrent_flutter` adapter (only file that imports the plugin).
- `ui/torrents_page.dart` — input + list page, slotted into the shell.
- `ui/widgets/torrent_card.dart` — cassette-style single-torrent card.
- `PLAN.md` — this document.

## Open questions / future (out of scope now)
- Speed limiting (upload/download caps) — plugin supports it (`setUploadLimit`/`setDownloadLimit`); not surfaced in Phase 1 UI.
- File-level selective download (priority per file) — plugin supports it; deferred.
- Persisting the active list across restarts — the plugin re-adds via `.torrent`/magnet on launch if we choose; not wired yet.

## Design invariants

- Only `data/torrent_engine.dart` may import `libtorrent_flutter`; domain and UI are plugin-free.
- The shell constructs the controller exactly once and passes it down.
- No global save directory: every add prompts for a destination.
- Seeding continues after 100% until the user pauses/removes.
- The engine lives as long as the app (session-scoped), matching the "one controller at the shell" rule.
