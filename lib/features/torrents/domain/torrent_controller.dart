import 'dart:async';
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

  /// Save paths of magnets/torrents the user removed while metadata was still
  /// resolving.  The background Rust add may still complete afterwards; this
  /// set stops the poll loop from re-surfacing those as fresh download rows.
  final Set<String> _removedSavePaths = {};

  /// Whether the initial restore from disk has completed.  Persistence writes
  /// are gated on this so the poll loop can't clobber `torrents.json` with an
  /// empty list before the saved records are loaded.
  bool _restored = false;

  /// Re-entry guard for [restoreFromDisk] (may be called from both the success
  /// and error paths of engine init).
  bool _restoreStarted = false;

  /// Human-readable error if engine init / persistence fails, shown to the
  /// user so failures aren't hidden.
  String? _lastError;
  String? get lastError => _lastError;

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
    if (_restoreStarted) return;
    _restoreStarted = true;

    final saved = await _persistence.load();
    if (saved.isEmpty) {
      _restored = true;
      return;
    }
    debugPrint('[TorrentController] restoring ${saved.length} torrents from disk');

    for (final pt in saved) {
      _persisted[pt.id] = pt;

      // Skip .torrent files that no longer exist on disk, but show them
      // in the UI with an error so the user knows what happened.
      if (pt.sourceType == 'file' && !File(pt.source).existsSync()) {
        final source = TorrentSource.file(pt.source);
        final errorTask = TorrentTask(
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
        debugPrint('[TorrentController] re-added ${pt.sourceType} → engineId=$engineId');
        if (engineId != null) {
          if (engineId == _rustSentinelId) {
            // Magnet add spawned in background — create a placeholder so the
            // poll loop replaces it when the real torrent appears.
            final placeholderId = _nextPlaceholderId--;
            _tasks[placeholderId] = TorrentTask(
              id: placeholderId,
              savePath: pt.savePath,
              source: source,
              name: pt.name.isNotEmpty ? pt.name : 'Resolving metadata…',
              status: TorrentStatus.fetchingMetadata,
            );
            _persistedKeyByTaskId[placeholderId] = pt.id;
          } else {
            _tasks[engineId] ??= TorrentTask(
              id: engineId,
              savePath: pt.savePath,
              source: source,
              name: pt.name.isNotEmpty ? pt.name : 'Fetching metadata…',
            );
            _persistedKeyByTaskId[engineId] = pt.id;
          }
        } else {
          // The engine failed to re-add this torrent — surface it to the
          // user instead of hiding it.
          final errorTask = TorrentTask(
            id: -(pt.id.hashCode),
            savePath: pt.savePath,
            source: source,
            name: pt.name.isNotEmpty ? pt.name : _fileName(pt.source),
            status: TorrentStatus.error,
            errorMsg: 'Failed to restore this download — the engine rejected it. '
                'Try removing and re-adding it.',
            totalSize: pt.totalSize,
            totalDone: pt.totalDone,
          );
          _tasks[errorTask.id] = errorTask;
        }
      } catch (e) {
        debugPrint('[TorrentController] restore error for ${pt.id}: $e');
        // Surface the restore failure in the UI so the user isn't left guessing.
        final errorTask = TorrentTask(
          id: -(pt.id.hashCode),
          savePath: pt.savePath,
          source: source,
          name: pt.name.isNotEmpty ? pt.name : _fileName(pt.source),
          status: TorrentStatus.error,
          errorMsg: 'Restore failed: $e',
          totalSize: pt.totalSize,
          totalDone: pt.totalDone,
        );
        _tasks[errorTask.id] = errorTask;
      }
    }

    // Trigger a poll to pick up all restored torrents.
    engine.tasksChanged?.call();
    _restored = true;
    // Persist whatever fastresume / the poll already updated so the file
    // matches the live session state.
    await _persistAll(immediate: true);
    notifyListeners();
  }

  /// Writes the full persisted list to disk. When [immediate] is true the
  /// write bypasses the throttle so adds/removes are persisted right away;
  /// the poll loop uses the throttled path.
  Future<void> _persistAll({bool immediate = false}) async {
    // Never write before the initial restore has loaded the saved records,
    // otherwise the poll loop overwrites `torrents.json` with an empty list.
    if (!_restored) return;
    final now = DateTime.now();
    if (!immediate &&
        _lastPersist != null &&
        now.difference(_lastPersist!) < _persistInterval) {
      return;
    }
    if (immediate) _lastPersist = now;
    debugPrint('[TorrentController] persisting ${_persisted.length} records to disk');
    try {
      await _persistence.save(_persisted.values.toList());
    } catch (e) {
      _lastError = 'Failed to save downloads: $e';
      debugPrint('[TorrentController] persist error: $e');
      notifyListeners();
    }
  }

  void _saveRecord(PersistedTorrent pt) {
    _persisted[pt.id] = pt;
    debugPrint('[TorrentController] saving record ${pt.id} (${pt.sourceType})');
    unawaited(_persistAll(immediate: true));
  }

  void _removeRecord(String id) {
    _persisted.remove(id);
    debugPrint('[TorrentController] removed record $id');
    unawaited(_persistAll(immediate: true));
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
          // Skip torrents the user deleted while metadata was still
          // resolving; their background add may complete long after removal.
          if (_removedSavePaths.contains(info.savePath)) continue;
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
    // The user explicitly re-added to this folder; lift any tombstones from a
    // previous delete so the new torrent can appear normally.
    _removedSavePaths.remove(savePath);
    engine.clearRemoved();
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
  ///
  /// Placeholders (negative ids) were never registered with the engine, so the
  /// native delete is skipped for them; their save path is tombstoned so the
  /// background magnet add can't re-surface the row later.
  Future<void> remove(
    int id, {
    bool deleteData = false,
    bool deleteTorrentFile = false,
  }) async {
    final task = _tasks[id];

    if (_isPlaceholderId(id)) {
      if (task?.savePath.isNotEmpty ?? false) {
        _removedSavePaths.add(task!.savePath);
      }
    } else if (task != null) {
      try {
        await engine.remove(id, deleteFiles: deleteData);
      } catch (e) {
        debugPrint('[TorrentController] engine.remove failed for $id: $e');
      }
    }

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

  /// Re-runs a failed torrent/magnet. Removes any live engine entry, then
  /// re-adds the source so metadata resolution / download restarts.
  ///
  /// The persisted record is kept so a successful restart still survives an
  /// app relaunch; if the re-add itself fails, the task stays visible as an
  /// error row so the user can retry again.
  Future<TorrentTask?> restart(int id) async {
    final task = _tasks[id];
    final source = task?.source;
    if (source == null) return null;

    final savePath = task!.savePath;
    final persistedKey = _persistedKeyByTaskId[id];
    final pt = persistedKey != null ? _persisted[persistedKey] : null;
    // A user-initiated retry — clear any tombstones for this folder.
    _removedSavePaths.remove(savePath);
    engine.clearRemoved();

    // Tear down any live engine entry for a real (positive) engine id so the
    // source can be handed to librqbit again. This is awaited so the delete
    // (and its persistence-store cleanup) completes before re-adding, otherwise
    // the re-add can race and hit "already managed" without really restarting.
    if (!_isPlaceholderId(id)) {
      await engine.remove(id, deleteFiles: false);
      // librqbit may reuse the same engine id after a forget; make sure the
      // removal tombstone doesn't hide the freshly re-added torrent.
      engine.clearRemoved();
    }
    _tasks.remove(id);

    int engineId;
    try {
      engineId = await engine.add(source, savePath);
    } catch (e) {
      final errorId = _nextPlaceholderId--;
      final errorTask = TorrentTask(
        id: errorId,
        source: source,
        savePath: savePath,
        name: source.raw,
        status: TorrentStatus.error,
        errorMsg: 'Could not restart: $e',
      );
      _tasks[errorId] = errorTask;
      if (pt != null) _persistedKeyByTaskId[errorId] = pt.id;
      notifyListeners();
      return errorTask;
    }

    TorrentTask? created;
    if (engineId == _rustSentinelId) {
      final placeholderId = _nextPlaceholderId--;
      created = TorrentTask(
        id: placeholderId,
        source: source,
        savePath: savePath,
        name: 'Resolving metadata…',
        status: TorrentStatus.fetchingMetadata,
      );
      _tasks[placeholderId] = created;
      if (pt != null) _persistedKeyByTaskId[placeholderId] = pt.id;
    } else {
      created = TorrentTask(
        id: engineId,
        savePath: savePath,
        source: source,
      );
      _tasks[engineId] = created;
      if (pt != null) {
        _persistedKeyByTaskId[engineId] = pt.id;
      } else {
        _linkPersistedRecord(created);
      }
    }

    notifyListeners();
    return created;
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
