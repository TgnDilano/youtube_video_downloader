import 'dart:io';

import 'package:flutter/material.dart';

enum DownloadStatus { queued, downloading, completed, error }

class DownloadTask extends ChangeNotifier {
  final String id;
  final String url;
  String title;
  String thumbnail;
  String metadata;
  double progress;
  DownloadStatus status;
  Process? process;
  String playlistProgress = "";
  String liveOutput = "";
  bool isPlaylist = false;
  List<DownloadTask> children = [];

  DownloadTask({
    required this.id,
    required this.url,
    this.title = "Fetching info...",
    this.thumbnail = "",
    this.metadata = "Waiting...",
    this.progress = 0.0,
    this.status = DownloadStatus.queued,
    this.isPlaylist = false,
  });

  void update() => notifyListeners();
}
