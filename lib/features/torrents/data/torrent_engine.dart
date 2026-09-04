import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';

import 'package:ytdlapp/src/rust/api/torrent.dart' as rb;
export 'package:ytdlapp/src/rust/api/torrent.dart' show TorrentError;

import 'package:ytdlapp/features/torrents/domain/torrent_file_info.dart';
import 'package:ytdlapp/features/torrents/domain/torrent_source.dart';
import 'package:ytdlapp/features/torrents/domain/torrent_task.dart';

/// A plugin-free snapshot of a torrent's state, produced by the engine and
/// consumed by the controller / UI.
class TorrentEngineSnapshot {
  final int id;
  final String name;
  final String savePath;
  final String errorMsg;
  final TorrentStatus status;
  final double progress;
  final int downloadRate;
  final int uploadRate;
  final int totalDone;
  final int totalWanted;
  final int totalUploaded;
  final int numPeers;
  final int numSeeds;
  final bool isPaused;
  final bool isFinished;
  final bool hasMetadata;

  const TorrentEngineSnapshot({
    required this.id,
    required this.name,
    required this.savePath,
    required this.errorMsg,
    required this.status,
    required this.progress,
    required this.downloadRate,
    required this.uploadRate,
    required this.totalDone,
    required this.totalWanted,
    required this.totalUploaded,
    required this.numPeers,
    required this.numSeeds,
    required this.isPaused,
    required this.isFinished,
    required this.hasMetadata,
  });
}

/// Adapter over the librqbit engine (bound through flutter_rust_bridge).
/// This is the **only** file that talks to the native torrent engine; domain
/// and UI stay plugin-free and testable. Since librqbit exposes no push
/// stream over FFI, progress is refreshed via a Dart-side poll loop.
class TorrentEngine {
  /// Invoked whenever the snapshot map changes (after each engine poll).
  void Function()? tasksChanged;

  final Map<int, TorrentEngineSnapshot> _snapshots = {};

  /// Torrent ids currently being (or recently) removed.  Filtered out of poll
  /// results so an unawaited delete can't re-surface a row; entries are cleared
  /// once the torrent is confirmed gone from the session.
  final Set<int> _removedIds = {};

  bool _initialized = false;
  Timer? _pollTimer;

  /// Current snapshots keyed by torrent id (insertion/last-update order).
  Map<int, TorrentEngineSnapshot> get snapshots => Map.unmodifiable(_snapshots);

  /// Ensures the librqbit session is running and starts the progress poll.
  Future<void> initialize() async {
    if (_initialized) return;
    // The app always passes an explicit save folder per add, so the session's
    // default output folder is only a fallback; system temp is fine.
    await rb.torrentInit(downloadDir: Directory.systemTemp.path);
    _initialized = true;
    _pollTimer = Timer.periodic(const Duration(seconds: 2), (_) => _poll());
    await _poll();
  }

  Future<void> _poll() async {
    try {
      final list = await rb.torrentList();
      final live = <int>{for (final t in list) t.id};
      // Stop tombstoning ids that have actually left the session so a
      // later re-add of the same torrent isn't hidden forever.
      _removedIds.removeWhere((id) => !live.contains(id));

      final next = <int, TorrentEngineSnapshot>{};
      for (final t in list) {
        if (_removedIds.contains(t.id)) continue;
        next[t.id] = _mapSnapshot(t);
      }
      _snapshots
        ..clear()
        ..addAll(next);

      // Drain pending magnet errors from Rust (timeout / add failure).
      final errors = await pendingErrors();
      for (final e in errors) {
        _pendingErrors[e.savePath] = e.message;
      }

      tasksChanged?.call();
    } catch (_) {
      // Best-effort polling; transient native errors must not crash the loop.
    }
  }

  /// Pending magnet errors keyed by save_path, drained each poll cycle.
  final Map<String, String> _pendingErrors = {};

  /// Returns and clears any pending errors for [savePath].
  String? takeError(String savePath) => _pendingErrors.remove(savePath);

  /// Adds a torrent from a magnet URI or a `.torrent` file path.
  /// Returns the native torrent id on success.
  /// Throws on failure (invalid URI, DHT resolution failure, etc.).
  Future<int> add(TorrentSource source, String savePath) async {
    final id = await rb.torrentAdd(source: source.raw, savePath: savePath);
    // Immediately poll so the new torrent appears in snapshots.
    await _poll();
    return id;
  }

  /// Re-adds a persisted torrent to the engine (used on startup restore).
  /// Returns the new engine id, or `null` if the re-add failed (e.g. missing
  /// `.torrent` file) or the torrent already exists in the engine.
  Future<int?> reAdd(TorrentSource source, String savePath) async {
    try {
      // Check if the engine already has a torrent with this save path + source.
      // If so, just return its id without re-adding.
      for (final snap in _snapshots.values) {
        if (snap.savePath == savePath) {
          return snap.id;
        }
      }
      return await add(source, savePath);
    } catch (_) {
      return null;
    }
  }

  void pause(int id) {
    if (!_initialized) return;
    unawaited(rb.torrentPause(id: id));
  }

  void resume(int id) {
    if (!_initialized) return;
    unawaited(rb.torrentResume(id: id));
  }

  /// Lists the files contained in a torrent once its metadata is available.
  /// Returns an empty list when there's no metadata yet.
  List<TorrentFileInfo> files(int id) {
    if (!_initialized) return [];
    final raw = rb.torrentFiles(id: id);
    return [
      for (final f in raw)
        TorrentFileInfo(
          index: f.index,
          name: f.name,
          path: f.path,
          size: f.size,
        ),
    ];
  }

  /// Removes a torrent from the session. The native call is awaited so the
  /// torrent is really gone before the poll loop can re-discover it.
  Future<void> remove(int id, {bool deleteFiles = false}) async {
    if (!_initialized) return;
    _removedIds.add(id);
    _snapshots.remove(id);
    try {
      await rb.torrentDelete(id: id, deleteFiles: deleteFiles);
    } catch (e) {
      debugPrint('[TorrentEngine] remove failed for $id: $e');
      // Fall through: the torrent stays tombstoned until it really leaves the
      // session, then it may reappear on a later poll (correct feedback).
    }
    tasksChanged?.call();
  }

  /// Clears removal tombstones. Called when the user explicitly re-adds a
  /// torrent, so a reused engine id (librqbit recycles ids after a delete)
  /// can't stay hidden forever.
  void clearRemoved() {
    _removedIds.clear();
  }

  /// Drains any pending magnet errors from the Rust side (timeout / add
  /// failure).  Each error is keyed by its save_path.
  Future<List<rb.TorrentError>> pendingErrors() async {
    if (!_initialized) return [];
    try {
      return await rb.torrentPendingErrors();
    } catch (_) {
      return [];
    }
  }

  /// Stops the progress poll and drops all state. Safe to call after the
  /// engine is no longer needed; the session itself stays until app exit.
  void dispose() {
    _pollTimer?.cancel();
    _pollTimer = null;
    _snapshots.clear();
    _initialized = false;
  }

  static TorrentEngineSnapshot _mapSnapshot(rb.TorrentSnapshot t) {
    return TorrentEngineSnapshot(
      id: t.id,
      name: t.hasMetadata && t.name.isNotEmpty ? t.name : 'Fetching metadata…',
      savePath: t.savePath,
      errorMsg: t.errorMsg,
      status: _status(t),
      progress: t.progress.clamp(0.0, 1.0),
      downloadRate: t.downloadRate,
      uploadRate: t.uploadRate,
      totalDone: t.totalDone,
      totalWanted: t.totalWanted,
      totalUploaded: t.totalUploaded,
      numPeers: t.numPeers,
      numSeeds: t.numSeeds,
      isPaused: t.isPaused,
      isFinished: t.isFinished,
      hasMetadata: t.hasMetadata,
    );
  }

  static TorrentStatus _status(rb.TorrentSnapshot t) {
    switch (t.status) {
      case 'error':
        return TorrentStatus.error;
      case 'paused':
        return TorrentStatus.paused;
      case 'seeding':
        return TorrentStatus.seeding;
      case 'fetchingMetadata':
        return TorrentStatus.fetchingMetadata;
      case 'downloading':
      default:
        return TorrentStatus.downloading;
    }
  }
}
