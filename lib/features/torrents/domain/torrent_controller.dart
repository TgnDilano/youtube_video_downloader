import 'dart:io';

import 'package:flutter/material.dart';

import 'package:ytdlapp/features/torrents/data/torrent_engine.dart';
import 'package:ytdlapp/features/torrents/domain/torrent_source.dart';
import 'package:ytdlapp/features/torrents/domain/torrent_task.dart';

/// Owns the torrent engine and exposes an observable list of [TorrentTask]s
/// to the UI. Constructed once by the shell and passed down.
class TorrentController extends ChangeNotifier {
  /// Injected engine; tests can substitute a fake by subclassing.
  final TorrentEngine engine;

  final Map<int, TorrentTask> _tasks = {};

  TorrentController({required this.engine}) {
    engine.tasksChanged = _onEngineUpdate;
  }

  /// Live tasks in insertion order.
  List<TorrentTask> get tasks => List.unmodifiable(_tasks.values);

  void _onEngineUpdate() {
    for (final info in engine.snapshots.values) {
      final task = _tasks[info.id];
      if (task == null) {
        _tasks[info.id] = _fromEngine(info);
      } else {
        _apply(task, info);
      }
    }
    notifyListeners();
  }

  /// Adds a torrent; [savePath] must be provided (always-prompt policy).
  int addTorrent(TorrentSource source, String savePath) {
    final id = engine.add(source, savePath);
    _tasks[id] = TorrentTask(id: id, savePath: savePath, source: source);
    notifyListeners();
    return id;
  }

  /// Pauses a torrent. Updates the task state immediately so the UI reflects
  /// the pause right away, then lets the engine poll confirm the native state.
  void pause(int id) {
    engine.pause(id);
    final task = _tasks[id];
    if (task != null) {
      task.isPaused = true;
      task.status = TorrentStatus.paused;
      task.update();
      notifyListeners();
    }
  }

  /// Resumes a paused torrent. Flips the task state right away so the RESUME
  /// icon switches back to PAUSE without waiting for the engine poll.
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
      notifyListeners();
    }
  }

  /// Removes a torrent from the session. Optionally deletes the downloaded
  /// data and the original `.torrent` file.
  ///
  /// Always asks for confirmation before removing (see the UI), because
  /// removing with [deleteData] discards local files.
  void remove(
    int id, {
    bool deleteData = false,
    bool deleteTorrentFile = false,
  }) {
    final task = _tasks[id];
    engine.remove(id, deleteFiles: deleteData);
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
    } catch (_) {
      // Best effort — deleting the original .torrent is not critical.
    }
  }

  TorrentTask _fromEngine(TorrentEngineSnapshot info) => _apply(
        TorrentTask(id: info.id, savePath: info.savePath),
        info,
      );

  TorrentTask _apply(TorrentTask task, TorrentEngineSnapshot info) {
    task.name = info.name;
    task.savePath = info.savePath;
    task.errorMsg = info.errorMsg;
    task.status = info.status;
    task.progress = info.progress;
    task.downloadRate = _formatRate(info.downloadRate);
    task.uploadRate = _formatRate(info.uploadRate);
    task.totalDone = info.totalDone;
    task.totalWanted = info.totalWanted;
    task.totalUploaded = info.totalUploaded;
    task.numPeers = info.numPeers;
    task.numSeeds = info.numSeeds;
    task.isPaused = info.isPaused;
    task.isFinished = info.isFinished;
    task.hasMetadata = info.hasMetadata;
    task.update();
    return task;
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
