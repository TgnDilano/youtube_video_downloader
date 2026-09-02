import 'package:flutter/material.dart';

import 'package:ytdlapp/features/torrents/domain/torrent_source.dart';

/// Lifecycle of a torrent task. `seeding` means the download is at 100% but
/// we keep uploading by default (user must pause/remove to stop sharing).
enum TorrentStatus {
  fetchingMetadata,
  downloading,
  seeding,
  paused,
  completed,
  error,
}

/// A `ChangeNotifier` mirror of a libtorrent torrent, kept free of any plugin
/// types so it can be unit-tested and rendered without touching the engine.
class TorrentTask extends ChangeNotifier {
  final int id;

  /// The original source this torrent was added from, so the UI can offer to
  /// delete the original `.torrent` file (for file sources) on removal.
  TorrentSource? source;

  /// Human name once metadata is available; otherwise a placeholder.
  String name;
  String savePath;
  String errorMsg;
  TorrentStatus status;
  double progress;
  String downloadRate;
  String uploadRate;
  int totalDone;
  int totalWanted;
  int totalUploaded;
  int numPeers;
  int numSeeds;
  bool isPaused;
  bool isFinished;
  bool hasMetadata;

  TorrentTask({
    required this.id,
    this.source,
    this.name = 'Fetching metadata…',
    this.savePath = '',
    this.errorMsg = '',
    this.status = TorrentStatus.fetchingMetadata,
    this.progress = 0.0,
    this.downloadRate = '',
    this.uploadRate = '',
    this.totalDone = 0,
    this.totalWanted = 0,
    this.totalUploaded = 0,
    this.numPeers = 0,
    this.numSeeds = 0,
    this.isPaused = false,
    this.isFinished = false,
    this.hasMetadata = false,
  });

  void update() => notifyListeners();

  /// True once the download portion has reached 100%.
  bool get isSeeding => isFinished && !isPaused;
}
