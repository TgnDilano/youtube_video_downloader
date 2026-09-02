# PLAN — Convert (Media Transcoding)

## Purpose

The **convert** feature takes a downloaded (or arbitrary local) media file and re-encodes it into another container/codec using **ffmpeg**, surfacing the live encode progress in the shared terminal view.

## Thought process & decisions

### Why it is a sibling of download
- Download and convert both live on the same "transport" metaphor: download brings media in, convert reshapes it. They share the exact subprocess lifecycle, so they are modeled symmetrically:
  - external binary (`ffmpeg` here) resolved via `BinaryResolver`
  - `Process.start`, streaming stderr
  - destination-folder picker via `input_area`
  - spooled logs shown through the shared `terminal_view`

### The right subprocess for the job
- ffmpeg re-encodes in a tight, single process with minimal surface — no metadata fetch, no format ladder, no cookie handling. So the convert model is intentionally **leaner** than `DownloadTask`:
  - `ConvertTask` carries the source/destination paths, container (`mp4`/`mkv`), codec choice, and video/audio quality, plus a `Process` handle.
  - Progress is parsed from ffmpeg's `time=` / `bitrate=` stderr lines rather than any JSON API.

### UI philosophy
- Convert is a single focused panel (fits on one page) rather than the lane-based queue of download:
  - source file picker
  - destination folder (reuses `input_area` package picker)
  - format preset (container) selector
  - optional re-encode settings (codec / CRF-ish quality)
  - a "Convert" CTA that watches the process and streams output into the shared terminal.
- The VU/metadata styling is reused but convert doesn't need a cassette queue.

### Why a shares `VuMeter` instead of a download-specific one
- Convert surfaced the need for a load/activity meter in a second place, so `VuMeter` was extracted from `download_card` into `core/widgets/vu_meter.dart` — shared, not duplicated.

## Files

- `domain/convert_task.dart` — lean task model (source, dest, container, codec, quality) + `Process`.
- `domain/convert_controller.dart` — spool convert jobs, run ffmpeg subprocesses, report progress, keep history.
- `ui/convert_page.dart` — the single-panel encode UI, routed from the sidebar.

## Design invariants

- Never transcode on the UI thread; always a streaming `Process`.
- Parse progress only from real ffmpeg output.
- Reuse `input_area` (dest picker), `terminal_view` (log), and `VuMeter` (activity) from core — do not fork copies.
