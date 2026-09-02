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
    _tasks[id] = TorrentTask(id: id, savePath: savePath);
    notifyListeners();
    return id;
  }

  void pause(int id) => engine.pause(id);

  void resume(int id) => engine.resume(id);

  void remove(int id) {
    engine.remove(id);
    _tasks.remove(id);
    notifyListeners();
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
