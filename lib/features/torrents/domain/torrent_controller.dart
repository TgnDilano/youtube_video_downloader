import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

import 'package:ytdlapp/features/torrents/data/torrent_engine.dart';
import 'package:ytdlapp/features/torrents/data/torrent_persistence.dart';
import 'package:ytdlapp/features/torrents/domain/persisted_torrent.dart';
import 'package:ytdlapp/features/torrents/domain/torrent_file_info.dart';
import 'package:ytdlapp/features/torrents/domain/torrent_source.dart';
import 'package:ytdlapp/features/torrents/domain/torrent_task.dart';

/// Owns the torrent engine and exposes an observable list of [TorrentTask]s
/// to the UI. Constructed once by the shell and passed down.
class TorrentController extends ChangeNotifier {
  /// Injected engine; tests can substitute a fake by subclassing.
  final TorrentEngine engine;

  final TorrentPersistence _persistence = TorrentPersistence();
  final Map<int, TorrentTask> _tasks = {};

  /// In-memory copy of the persisted torrent list, keyed by stable id
  /// (source raw hashCode as string).
  final Map<String, PersistedTorrent> _persisted = {};

  /// Maps engine task id → persisted key, so we can update the right
  /// persisted record during the poll cycle.
  final Map<int, String> _persistedKeyByTaskId = {};

  /// Whether the initial restore from disk has completed.
  bool _restored = false;

  /// Throttle persistence writes to at most once every 5 seconds.
  DateTime? _lastPersist;
  static const _persistInterval = Duration(seconds: 5);

  TorrentController({required this.engine}) {
    engine.tasksChanged = _onEngineUpdate;
  }

  /// Live tasks in insertion order.
  List<TorrentTask> get tasks => List.unmodifiable(_tasks.values);

  /// Whether the initial restore from persistence is done.
  bool get isRestored => _restored;

  // ── Persistence lifecycle ────────────────────────────────────────────────

  /// Loads persisted torrents from disk and re-adds them to the engine.
  /// Call once after the engine is initialized. Safe to call multiple times
  /// (idempotent after the first call).
  Future<void> restoreFromDisk() async {
    if (_restored) return;
    _restored = true;

    final saved = await _persistence.load();
    if (saved.isEmpty) return;

    for (final pt in saved) {
      _persisted[pt.id] = pt;

      // Skip .torrent files that no longer exist on disk, but show them
      // in the UI with an error so the user knows what happened.
      if (pt.sourceType == 'file' && !File(pt.source).existsSync()) {
        final source = TorrentSource.file(pt.source);
        final errorTask = TorrentTask(
          // Negative id (engine ids are always non-negative) to avoid
          // collision with real engine ids; pause/resume are no-ops for
          // these since they aren't in the engine.
          id: -(pt.id.hashCode),
          savePath: pt.savePath,
          source: source,
          name: pt.name.isNotEmpty ? pt.name : _fileName(pt.source),
          status: TorrentStatus.error,
          errorMsg: 'Original .torrent file not found: ${_fileName(pt.source)}',
          totalSize: pt.totalSize,
          totalDone: pt.totalDone,
        );
        _tasks[errorTask.id] = errorTask;
        continue;
      }

      final source = pt.sourceType == 'magnet'
          ? TorrentSource.magnet(pt.source)
          : TorrentSource.file(pt.source);

      try {
        final engineId = await engine.reAdd(source, pt.savePath);
        if (engineId != null) {
          _tasks[engineId] ??= TorrentTask(
            id: engineId,
            savePath: pt.savePath,
            source: source,
            name: pt.name.isNotEmpty ? pt.name : 'Fetching metadata…',
          );
          _persistedKeyByTaskId[engineId] = pt.id;
        }
      } catch (_) {}
    }

    // Trigger a poll to pick up all restored torrents.
    engine.tasksChanged?.call();
    notifyListeners();
  }

  /// Writes the full persisted list to disk. Throttled to avoid excessive I/O.
  Future<void> _persistAll() async {
    final now = DateTime.now();
    if (_lastPersist != null && now.difference(_lastPersist!) < _persistInterval) {
      return;
    }
    _lastPersist = now;
    await _persistence.save(_persisted.values.toList());
  }

  void _saveRecord(PersistedTorrent pt) {
    _persisted[pt.id] = pt;
    _persistAll();
  }

  void _removeRecord(String id) {
    _persisted.remove(id);
    _persistAll();
  }

  // ── Engine sync ──────────────────────────────────────────────────────────

  void _onEngineUpdate() {
    for (final info in engine.snapshots.values) {
      final task = _tasks[info.id];
      if (task == null) {
        // Check if there's a placeholder magnet task whose savePath matches —
        // if so, replace it with the real task.
        final placeholderId = _findPlaceholderForSavePath(info.savePath);
        if (placeholderId != null) {
          final placeholder = _tasks.remove(placeholderId)!;
          final realTask = _fromEngine(info);
          realTask.source = placeholder.source;
          _tasks[info.id] = realTask;
          // Transfer the persisted key mapping.
          final persistedKey = _persistedKeyByTaskId.remove(placeholderId);
          if (persistedKey != null) {
            _persistedKeyByTaskId[info.id] = persistedKey;
          }
        } else {
          _tasks[info.id] = _fromEngine(info);
          _linkPersistedRecord(_tasks[info.id]!);
        }
      } else {
        _apply(task, info);
      }
    }

    // Check for magnet errors from the Rust background tasks (timeout /
    // add failure).  Mark the matching placeholder with the error message.
    for (final task in _tasks.values) {
      if (!_isPlaceholderId(task.id)) continue;
      final error = engine.takeError(task.savePath);
      if (error != null) {
        task.status = TorrentStatus.error;
        task.errorMsg = error;
      }
    }

    // Update persisted records with latest engine state.
    for (final task in _tasks.values) {
      final persistedKey = _persistedKeyByTaskId[task.id];
      if (persistedKey != null) {
        final pt = _persisted[persistedKey];
        if (pt != null) {
          final updated = pt.copyWith(
            name: task.name != 'Fetching metadata…' &&
                    task.name != 'Resolving metadata…'
                ? task.name
                : pt.name,
            totalSize: task.totalSize > 0 ? task.totalSize : pt.totalSize,
            totalDone: task.totalDone,
            totalLeft: task.totalSize > 0
                ? task.totalSize - task.totalDone
                : pt.totalLeft,
            isPaused: task.isPaused,
          );
          _persisted[persistedKey] = updated;
        }
      }
    }

    _persistAll();
    notifyListeners();
  }

  /// Returns the placeholder task id whose [savePath] matches [path], or null.
  int? _findPlaceholderForSavePath(String path) {
    for (final task in _tasks.values) {
      if (_isPlaceholderId(task.id) && task.savePath == path) {
        return task.id;
      }
    }
    return null;
  }

  /// Tries to find a persisted record matching [task] by save path and
  /// source type, then links the engine id to that record.  This lets the
  /// poll cycle update the right persisted entry for magnets that were
  /// added in the background.
  void _linkPersistedRecord(TorrentTask task) {
    for (final pt in _persisted.values) {
      if (_persistedKeyByTaskId.containsValue(pt.id)) continue;
      if (pt.savePath == task.savePath) {
        _persistedKeyByTaskId[task.id] = pt.id;
        return;
      }
    }
  }

  // ── Public API ───────────────────────────────────────────────────────────

  /// Counter for generating unique negative placeholder ids.  Decremented
  /// each time a magnet is added so every placeholder has a distinct id.
  int _nextPlaceholderId = -1;

  /// The Rust side returns this sentinel id when a magnet add is spawned
  /// in the background.  We detect it to create a placeholder task.
  static const int _rustSentinelId = 0xFFFFFFFF - 1; // u32::MAX - 1

  /// Returns true if [id] is a placeholder (negative, not yet resolved by
  /// the engine).
  static bool _isPlaceholderId(int id) => id < 0;

  /// Adds a torrent; [savePath] must be provided.
  /// Returns the new torrent id after the native engine has accepted it.
  ///
  /// For magnets a placeholder task is created immediately so the user sees
  /// feedback in the table.  The real task replaces it once the poll loop
  /// discovers the torrent after metadata resolution.
  Future<int> addTorrent(TorrentSource source, String savePath) async {
    final id = await engine.add(source, savePath);

    // Persist immediately so the download survives a restart even if
    // metadata hasn't resolved yet.
    final pt = PersistedTorrent(
      id: source.raw.hashCode.toString(),
      source: source.raw,
      sourceType: source.kind == TorrentSourceKind.magnet ? 'magnet' : 'file',
      savePath: savePath,
      addedAt: DateTime.now().toIso8601String(),
    );
    _saveRecord(pt);

    if (id == _rustSentinelId) {
      // Create a placeholder task so the user sees it in the table while
      // metadata resolves in the background.
      final placeholderId = _nextPlaceholderId--;
      final placeholder = TorrentTask(
        id: placeholderId,
        source: source,
        savePath: savePath,
        name: 'Resolving metadata…',
        status: TorrentStatus.fetchingMetadata,
      );
      _tasks[placeholderId] = placeholder;
      _persistedKeyByTaskId[placeholderId] = pt.id;
    } else {
      _tasks[id] = TorrentTask(id: id, savePath: savePath, source: source);
      _persistedKeyByTaskId[id] = pt.id;
    }

    notifyListeners();
    return id;
  }

  /// Lists the files of a torrent via the engine (needs metadata).
  List<TorrentFileInfo> files(int id) => engine.files(id);

  /// Computes the on-disk path to reveal in the OS file manager once a torrent
  /// has finished downloading.
  static String revealPath(String savePath, List<TorrentFileInfo> files) {
    if (files.length == 1) {
      final f = files.first;
      final path = f.path.isNotEmpty ? f.path : f.name;
      if (path.isNotEmpty) return p.join(savePath, path);
      return savePath;
    }
    if (files.isNotEmpty) {
      final tops = files
          .map((f) => f.path.split(RegExp(r'[/\\]')).first)
          .where((s) => s.isNotEmpty)
          .toSet();
      if (tops.length == 1) return p.join(savePath, tops.first);
    }
    return savePath;
  }

  void pause(int id) {
    engine.pause(id);
    final task = _tasks[id];
    if (task != null) {
      task.isPaused = true;
      task.status = TorrentStatus.paused;
      task.downloadRate = '0 B/s';
      task.uploadRate = '0 B/s';
      task.eta = '';
      task.update();
      _updatePersistedPause(task, paused: true);
      notifyListeners();
    }
  }

  void resume(int id) {
    engine.resume(id);
    final task = _tasks[id];
    if (task != null) {
      task.isPaused = false;
      if (task.isFinished) {
        task.status = TorrentStatus.seeding;
      } else {
        task.status = TorrentStatus.downloading;
      }
      task.update();
      _updatePersistedPause(task, paused: false);
      notifyListeners();
    }
  }

  void _updatePersistedPause(TorrentTask task, {required bool paused}) {
    final key = _persistedKeyByTaskId[task.id];
    if (key == null) return;
    final pt = _persisted[key];
    if (pt != null) {
      _persisted[key] = pt.copyWith(isPaused: paused);
      _persistAll();
    }
  }

  /// Removes a torrent from the session. Optionally deletes the downloaded
  /// data and the original `.torrent` file. Also removes the persisted record.
  void remove(
    int id, {
    bool deleteData = false,
    bool deleteTorrentFile = false,
  }) {
    final task = _tasks[id];
    engine.remove(id, deleteFiles: deleteData);

    // Remove persisted record and clean up mapping.
    final persistedKey = _persistedKeyByTaskId.remove(id);
    if (persistedKey != null) {
      _removeRecord(persistedKey);
    }
    if (deleteTorrentFile && task?.source != null) {
      _deleteOriginalTorrentFile(task!.source!);
    }

    _tasks.remove(id);
    notifyListeners();
  }

  static void _deleteOriginalTorrentFile(TorrentSource source) {
    if (source.kind != TorrentSourceKind.file) return;
    try {
      final file = File(source.raw);
      if (file.existsSync()) file.deleteSync();
    } catch (_) {}
  }

  static String _fileName(String path) {
    final parts = path.split(RegExp(r'[/\\]'));
    return parts.isNotEmpty ? parts.last : path;
  }

  TorrentTask _fromEngine(TorrentEngineSnapshot info) =>
      _apply(TorrentTask(id: info.id, savePath: info.savePath), info);

  TorrentTask _apply(TorrentTask task, TorrentEngineSnapshot info) {
    task.name = info.name;
    task.savePath = info.savePath;
    task.errorMsg = info.errorMsg;
    task.status = info.status;
    task.progress = info.progress;
    final paused = info.status == TorrentStatus.paused;
    task.downloadRate = paused ? '0 B/s' : _formatRate(info.downloadRate);
    task.uploadRate = paused ? '0 B/s' : _formatRate(info.uploadRate);
    task.totalDone = info.totalDone;
    task.totalWanted = info.totalWanted;
    task.totalSize = info.totalWanted;
    task.totalUploaded = info.totalUploaded;
    task.numPeers = info.numPeers;
    task.numSeeds = info.numSeeds;
    task.eta = _formatEta(
      remaining: info.totalWanted - info.totalDone,
      rate: info.downloadRate,
      paused: paused,
      finished: info.isFinished,
    );
    task.isPaused = info.isPaused;
    task.isFinished = info.isFinished;
    task.hasMetadata = info.hasMetadata;
    task.update();
    return task;
  }

  static String _formatEta({
    required int remaining,
    required int rate,
    required bool paused,
    required bool finished,
  }) {
    if (finished || paused || remaining <= 0 || rate <= 0) return '';
    final secs = (remaining / rate).ceil();
    if (secs < 60) return '${secs}s';
    if (secs < 3600) return '${secs ~/ 60}m ${secs % 60}s';
    final h = secs ~/ 3600;
    final m = (secs % 3600) ~/ 60;
    return '$h h ${m}m';
  }

  static String _formatRate(int bytesPerSec) {
    if (bytesPerSec <= 0) return '0 B/s';
    if (bytesPerSec < 1024) return '$bytesPerSec B/s';
    if (bytesPerSec < 1024 * 1024) {
      return '${(bytesPerSec / 1024).toStringAsFixed(1)} KiB/s';
    }
    return '${(bytesPerSec / (1024 * 1024)).toStringAsFixed(2)} MiB/s';
  }
}
