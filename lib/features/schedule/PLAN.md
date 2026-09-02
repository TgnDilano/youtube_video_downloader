# PLAN — Schedule (Planned Downloads)

## Purpose

The **schedule** feature lets the user stage a download to start later: pick an absolute date+time, and the app triggers the actual download (which itself runs through the **download** feature) at that moment.

## Thought process & decisions

### Why a separate feature (not part of download)
- *What* gets downloaded is download's concern; *when* is schedule's concern. Keeping them separate preserves download's lane-based queue and lets scheduling rules evolve (repeat intervals, wake-from-sleep, backfill) without touching transport code.
- Cross-feature connection is deliberately minimal: schedule only needs the download controller as a hook to fire a queued task.

### Task model
- `PlannedDownload` is a self-contained, **persistable** record (raw JSON) holding the URL, resolution, audio-only flag, destination folder, and the planned start `DateTime`. Persisting the record (not the process) means planned jobs survive a restart — the actual `DownloadTask`/`Process` only exist once the time arrives.
- The id is stable across restarts so a planned job can be cancelled by id before it fires.

### When-does-it-run semantics
- A single, app-level timer watches the queue and, when `now >= plannedStart`, hands the fields to `DownloadController.queue(...)`. If the app is closed at that moment, the job is picked up on next launch, not silently dropped.
- We deliberately **do not** do OS-level (launchd / context) delayed execution in Phase 1 — an in-app watchdog is simpler, fully portable, and testable.

### Dialog UX
- `schedule_dialog.dart` presents a themed date + time picker.
- It renders two helper strings extracted into `schedule_utils.dart`:
  - `formatPlannedDate` → absolute "TUE 09/16 · 21:15" timestamp.
  - `describeRelative` → preview "IN 4 H 05 MIN / NOW / IN 2 DAYS".
- Both are shared with the shell's "live schedule row" so the queued list and the picker always render identically.

### Why `schedule_utils.dart` lives in schedule/domain
- The formatters are pure logic used by both the picker UI and the shell list — i.e. `domain/` shared logic for this feature only. They are not generic enough for `core/`, so they stay feature-local and reusable within the feature + its consumers.

## Files

- `domain/planned_download.dart` — persistable plan record + JSON (de)serialization + stable id.
- `domain/schedule_controller.dart` — queue of `PlannedDownload`, watchdog timer, fire/cancel logic.
- `domain/schedule_utils.dart` — `formatPlannedDate` + `describeRelative` helpers.
- `ui/schedule_dialog.dart` — themed date/time picker; returns a `PlannedDownload` or null.

## Design invariants

- Persist the *plan*, never the running process.
- Firing the plan delegates to the download controller; schedule never starts its own subprocess.
- Relative/absolute formatting must be shared (single source of truth) between the dialog and the shell list.
