import 'dart:async';

import 'package:libtorrent_flutter/libtorrent_flutter.dart' as lt;

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

/// Thin adapter over `libtorrent_flutter`. This is the **only** file that
/// imports the plugin; domain and UI stay plugin-free and testable.
class TorrentEngine {
  /// Invoked whenever the snapshot map changes (after each engine poll).
  void Function()? tasksChanged;

  final Map<int, TorrentEngineSnapshot> _snapshots = {};

  bool _initialized = false;
  StreamSubscription<Map<int, lt.TorrentInfo>>? _subscription;

  /// Current snapshots keyed by torrent id (insertion/last-update order).
  Map<int, TorrentEngineSnapshot> get snapshots => Map.unmodifiable(_snapshots);

  /// Ensures the libtorrent session is running.
  Future<void> initialize() async {
    if (_initialized) return;
    if (!lt.LibtorrentFlutter.isInitialized) {
      await lt.LibtorrentFlutter.init();
    }
    _subscription ??=
        lt.LibtorrentFlutter.instance.torrentUpdates.listen(_handleUpdates);
    _initialized = true;
  }

  /// Adds a torrent from a magnet URI or a `.torrent` file path.
  int add(TorrentSource source, String savePath) {
    final engine = lt.LibtorrentFlutter.instance;
    final id = source.kind == TorrentSourceKind.magnet
        ? engine.addMagnet(source.raw, savePath)
        : engine.addTorrentFile(source.raw, savePath);
    return id;
  }

  void pause(int id) {
    if (!_initialized) return;
    lt.LibtorrentFlutter.instance.pauseTorrent(id);
  }

  void resume(int id) {
    if (!_initialized) return;
    lt.LibtorrentFlutter.instance.resumeTorrent(id);
  }

  void remove(int id) {
    if (!_initialized) return;
    lt.LibtorrentFlutter.instance.removeTorrent(id, deleteFiles: false);
    _snapshots.remove(id);
  }

  void _handleUpdates(Map<int, lt.TorrentInfo> torrents) {
    _snapshots.clear();
    for (final info in torrents.values) {
      _snapshots[info.id] = _mapInfo(info);
    }
    tasksChanged?.call();
  }

  static TorrentEngineSnapshot _mapInfo(lt.TorrentInfo t) {
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

  static TorrentStatus _status(lt.TorrentInfo t) {
    if (t.errorMsg.isNotEmpty) return TorrentStatus.error;
    if (t.isPaused) return TorrentStatus.paused;
    if (t.isFinished) return TorrentStatus.seeding;
    switch (t.state) {
      case lt.TorrentState.downloadingMetadata:
        return TorrentStatus.fetchingMetadata;
      case lt.TorrentState.downloading:
      case lt.TorrentState.allocating:
      case lt.TorrentState.checkingFiles:
      case lt.TorrentState.checkingResume:
        return TorrentStatus.downloading;
      case lt.TorrentState.finished:
      case lt.TorrentState.seeding:
        return TorrentStatus.seeding;
      case lt.TorrentState.error:
        return TorrentStatus.error;
      case lt.TorrentState.unknown:
        return TorrentStatus.fetchingMetadata;
    }
  }
}
