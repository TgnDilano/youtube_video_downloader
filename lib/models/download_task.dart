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

  // New fields
  String resolution;
  String? savePath;
  DateTime timestamp;
  String speed;
  String eta;
  String fileSize;
  String downloadedSize;
  bool audioOnly;

  DownloadTask({
    required this.id,
    required this.url,
    this.title = "Fetching info...",
    this.thumbnail = "",
    this.metadata = "Waiting...",
    this.progress = 0.0,
    this.status = DownloadStatus.queued,
    this.isPlaylist = false,
    this.resolution = "best",
    this.savePath,
    DateTime? timestamp,
    this.speed = "",
    this.eta = "",
    this.fileSize = "",
    this.downloadedSize = "",
    this.audioOnly = false,
  }) : timestamp = timestamp ?? DateTime.now();

  void update() => notifyListeners();

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'url': url,
      'title': title,
      'thumbnail': thumbnail,
      'metadata': metadata,
      'progress': progress,
      'status': status.index,
      'isPlaylist': isPlaylist,
      'resolution': resolution,
      'savePath': savePath,
      'timestamp': timestamp.toIso8601String(),
      'fileSize': fileSize,
      'downloadedSize': downloadedSize,
      'audioOnly': audioOnly,
    };
  }

  factory DownloadTask.fromJson(Map<String, dynamic> json) {
    return DownloadTask(
      id: json['id'],
      url: json['url'],
      title: json['title'],
      thumbnail: json['thumbnail'],
      metadata: json['metadata'],
      progress: (json['progress'] as num).toDouble(),
      status: DownloadStatus.values[json['status']],
      isPlaylist: json['isPlaylist'],
      resolution: json['resolution'] ?? "best",
      savePath: json['savePath'],
      timestamp: DateTime.parse(json['timestamp']),
      fileSize: json['fileSize'] ?? "",
      downloadedSize: json['downloadedSize'] ?? "",
      audioOnly: json['audioOnly'] ?? false,
    );
  }
}
