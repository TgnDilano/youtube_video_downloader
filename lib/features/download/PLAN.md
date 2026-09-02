# PLAN — Download (YouTube / Media Transport)

## Purpose

The **download** feature is the original core of TubeXMate: turn a YouTube URL (single video or playlist) into a local file, with user control over resolution, audio-only extraction, and playback of the run in a live terminal.

## Thought process & decisions

### Why it exists
- The app was conceived as a "media transport" tool — you drop in a URL, set a range (resolution / items / audio-only), and hit record. Everything else (settings, convert, schedule) orbits this feature.

### Why a subprocess model (yt-dlp)
- YouTube download is a moving target (bot-checks, 403s, format churn). Rather than reimplementing extraction, we drive **yt-dlp** as an external binary via `Process.start` and stream its stdout/stderr.
- The same pattern powers `ffmpeg` in the convert feature, so two heavy external tools share one convention: `BinaryResolver` (resolve bundled → well-known path → PATH), a spawned `Process`, progress parsed from output, and a log buffer shown in the terminal view.

### The 403 / cookie ladder
- YouTube frequently blocks anonymity. We built a graceful fallback ladder:
  1. no credentials → try
  2. on 403 → retry with an alternate player client (no login)
  3. still 403 → browser cookies, after explicit macOS Keychain consent (never silently)
  4. a `cookies.txt` file is always the preferred, narrowest-access option.
- This is deliberately UI-visible (consent dialog) and auditable via the log.

### Task model
- `DownloadTask` is a `ChangeNotifier` carrying a `Process` handle plus display fields (progress, size, speed, ETA, metadata). It is **YouTube-flavored** (resolution, audioOnly, cookies, playlist children), which is why the later torrent feature gets its **own** model instead of being bolted on.
- Playlists are modeled as a parent task with child tasks — one yt-dlp run can fan out into N children, each downloadable individually.

### Lane-based UI
- The controller exposes `downloadingTasks` / `completedTasks` / `failedTasks` getters; pages render these as lanes rather than filtering raw statuses in widgets.

### Concurrency / resilience choices
- Non-blocking: metadata is fetched in the background so scheduling big jobs isn't stalled.
- Pause/resume keeps the `.part` file via a graceful SIGINT, so resume continues where it left off.
- Deriving progress from yt-dlp's `[download] NN% of SIZE at SPEED ETA` lines keeps the parser independent of yt-dlp's JSON surface.

## Files

- `domain/download_task.dart` — task model + `DownloadStatus` enum + JSON persistence.
- `domain/download_controller.dart` — orchestration, subprocess execution, 403 ladder, history.
- `domain/playlist_options.dart` — result data class for the playlist pre-queue dialog.
- `ui/download_card.dart` — cassette-style queue card (reel spinner, VU meter, actions).
- `ui/input_area.dart` — URL + destination folder input panel.
- `ui/resolution_dialog.dart` — pick a resolution before queueing.
- `ui/playlist_options_dialog.dart` — full-playlist vs item selection + per-item default resolution.
- `ui/clipboard_offer_dialog.dart` — offer to queue a copied link.
- `ui/cookie_consent_dialog.dart` — Keychain/browser cookie consent.
- `ui/terminal_view.dart` — streaming log viewer shared from the shell.

## Design invariants

- Never block the UI thread on a download; always `Process.start` + stream.
- Keep the 403 ladder observable (log banners) and consent-gated (Keychain).
- Progress/size/speed are always parsed from real output, never guessed.
