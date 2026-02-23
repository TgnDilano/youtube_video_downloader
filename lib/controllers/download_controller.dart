import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ytdlapp/models/download_task.dart';

class DownloadController extends ChangeNotifier {
  List<DownloadTask> tasks = [];
  List<String> log = [];

  DownloadController() {
    loadHistory();
  }

  List<DownloadTask> get downloadingTasks => tasks
      .where(
        (t) =>
            t.status == DownloadStatus.downloading ||
            t.status == DownloadStatus.queued,
      )
      .toList();

  List<DownloadTask> get completedTasks =>
      tasks.where((t) => t.status == DownloadStatus.completed).toList();

  List<DownloadTask> get failedTasks =>
      tasks.where((t) => t.status == DownloadStatus.error).toList();

  Future<void> loadHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final historyJson = prefs.getStringList('download_history') ?? [];
    tasks = historyJson
        .map((j) => DownloadTask.fromJson(jsonDecode(j)))
        .toList();
    notifyListeners();
  }

  Future<void> saveHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final historyJson = tasks.map((t) => jsonEncode(t.toJson())).toList();
    await prefs.setStringList('download_history', historyJson);
  }

  Future<Map<String, dynamic>?> fetchVideoInfo(String url) async {
    if (url.isEmpty) return null;
    final ytDlp = await _getBinaryPath('yt-dlp');
    try {
      final result = await Process.run(ytDlp, [
        '--dump-single-json',
        '--flat-playlist',
        url,
      ]);
      if (result.exitCode == 0) {
        final output = result.stdout as String;
        if (output.trim().isEmpty) return null;
        return jsonDecode(output);
      }
    } catch (e) {
      log.add("Error fetching video info: $e");
    }
    return null;
  }

  void addDownload(
    String url,
    String savePath,
    bool audioOnly, {
    bool isPlaylist = false,
    int? playlistStart,
    int? playlistEnd,
    String resolution = "best",
    Map<String, dynamic>? metadata,
  }) async {
    if (url.isEmpty) return;

    if (isPlaylist) {
      _addPlaylistDownload(
        url,
        savePath,
        audioOnly,
        playlistStart: playlistStart,
        playlistEnd: playlistEnd,
        playlistTitle: metadata?['title'],
        resolution: resolution,
      );
    } else {
      final task = DownloadTask(
        id: DateTime.now().toString(),
        url: url,
        resolution: resolution,
        savePath: savePath,
        audioOnly: audioOnly,
      );

      if (metadata != null) {
        task.title = metadata['title'] ?? "Unknown Title";
        task.thumbnail = metadata['thumbnail'] ?? "";
        task.metadata = "YouTube • ${metadata['duration_string'] ?? 'Unknown'}";
      }

      tasks.insert(0, task);
      notifyListeners();

      if (metadata == null) {
        await _fetchMetadata(task);
      }

      _startDownload(task, savePath, audioOnly);
    }
  }

  Future<void> _addPlaylistDownload(
    String url,
    String savePath,
    bool audioOnly, {
    int? playlistStart,
    int? playlistEnd,
    String? playlistTitle,
    String resolution = 'best',
  }) async {
    String finalSavePath = savePath;
    if (playlistTitle != null) {
      final sanitized = playlistTitle
          .replaceAll(RegExp(r'[\\/:*?"<>|]'), '_')
          .trim();
      final dir = Directory('$savePath/$sanitized');
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }
      finalSavePath = dir.path;
    }

    final parentTask = DownloadTask(
      id: DateTime.now().toString(),
      url: url,
      title: playlistTitle ?? "Fetching playlist info...",
      isPlaylist: true,
      savePath: finalSavePath,
    );
    tasks.insert(0, parentTask);
    notifyListeners();

    final ytDlp = await _getBinaryPath('yt-dlp');
    try {
      final args = ['--flat-playlist', '--dump-json', '--newline'];

      if (playlistStart != null) {
        args.addAll(['--playlist-start', playlistStart.toString()]);
      }
      if (playlistEnd != null) {
        args.addAll(['--playlist-end', playlistEnd.toString()]);
      }

      args.add(url);

      final process = await Process.start(ytDlp, args);

      process.stdout
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen((line) {
            if (line.trim().isEmpty) return;
            try {
              final data = jsonDecode(line);
              if (data['_type'] == 'playlist' ||
                  data['_type'] == 'multi_video') {
                parentTask.title = data['title'] ?? parentTask.title;
              } else {
                final childTask = DownloadTask(
                  id: data['id'] ?? DateTime.now().toString(),
                  url: data['url'] ?? data['webpage_url'] ?? url,
                  title: data['title'] ?? 'Unknown Title',
                  metadata: "Queued",
                  savePath: finalSavePath,
                  resolution: resolution,
                  audioOnly: audioOnly,
                );
                parentTask.children.add(childTask);
              }
              parentTask.update();
              notifyListeners();
            } catch (e) {
              log.add("Error parsing playlist item: $e");
            }
          });

      final exitCode = await process.exitCode;

      if (exitCode != 0) {
        if (parentTask.children.isEmpty) {
          parentTask.title = "Error fetching playlist (Code $exitCode)";
          parentTask.status = DownloadStatus.error;
        }
      }
    } catch (e) {
      log.add("Error starting playlist fetch: $e");
      parentTask.title = "Error fetching playlist";
      parentTask.status = DownloadStatus.error;
    }

    parentTask.update();
    notifyListeners();
    if (parentTask.status != DownloadStatus.error) {
      _startDownload(parentTask, finalSavePath, audioOnly);
    }
  }

  Future<String> _getBinaryPath(String cmd) async {
    List<String> paths = ['/opt/homebrew/bin/$cmd', '/usr/local/bin/$cmd'];
    for (var path in paths) {
      if (await File(path).exists()) return path;
    }
    return cmd;
  }

  Future<void> _fetchMetadata(DownloadTask task) async {
    final ytDlp = await _getBinaryPath('yt-dlp');
    try {
      final result = await Process.run(ytDlp, [
        '--dump-json',
        '--no-playlist',
        task.url,
      ]);
      if (result.exitCode == 0) {
        final data = jsonDecode(result.stdout);
        task.title = data['title'] ?? "Unknown Title";
        task.thumbnail = data['thumbnail'] ?? "";
        task.metadata = "YouTube • ${data['duration_string'] ?? 'Unknown'}";
      } else {
        task.title = "Video info unavailable";
      }
    } catch (e) {
      task.title = "Error fetching info";
    }
    task.update();
  }

  Future<void> _startDownload(
    DownloadTask task,
    String savePath,
    bool audioOnly,
  ) async {
    if (task.isPlaylist) {
      task.status = DownloadStatus.downloading;
      task.update();
      int completed = task.children
          .where((c) => c.status == DownloadStatus.completed)
          .length;

      for (var i = 0; i < task.children.length; i++) {
        final child = task.children[i];
        if (child.status == DownloadStatus.completed) continue;

        child.metadata = "Preparing...";
        child.status = DownloadStatus.downloading;
        task.playlistProgress =
            "Downloading video ${i + 1} of ${task.children.length}";
        task.update();

        final success = await _executeDownload(child, savePath, audioOnly);

        if (success) {
          completed++;
          child.status = DownloadStatus.completed;
          child.metadata = "Completed";
          child.progress = 1.0;
        } else {
          child.status = DownloadStatus.error;
          child.metadata = "Error";
        }
        task.progress = completed / task.children.length;
        task.update();
      }
      task.status = DownloadStatus.completed;
      task.playlistProgress = "All videos downloaded";
      task.update();
      saveHistory();
      notifyListeners();
    } else {
      await _executeDownload(task, savePath, audioOnly);
      saveHistory();
    }
  }

  Future<bool> _executeDownload(
    DownloadTask task,
    String savePath,
    bool audioOnly,
  ) async {
    task.status = DownloadStatus.downloading;
    task.update();

    final ytDlp = await _getBinaryPath('yt-dlp');
    List<String> args = [];

    if (audioOnly) {
      args = ['-x', '--audio-format', 'mp3'];
    } else {
      // Use selected resolution or default to best
      String format = task.resolution == "best"
          ? 'bv*[ext=mp4]+ba[ext=m4a]/b[ext=mp4] / bv*+ba/b'
          : 'bv*[height<=${task.resolution}][ext=mp4]+ba[ext=m4a]/b[height<=${task.resolution}][ext=mp4] / bv*[height<=${task.resolution}]+ba/b[height<=${task.resolution}]';
      args = ['-f', format, '--merge-output-format', 'mp4'];
    }

    args.addAll([
      '--no-playlist',
      '--newline',
      '-o',
      '$savePath/%(title)s.%(ext)s',
      task.url,
    ]);

    log.add(
      '--- Starting Download: ${task.title} (Res: ${task.resolution}) ---',
    );
    log.add('yt-dlp ${args.join(' ')}');
    notifyListeners();

    try {
      final saveDir = Directory(savePath);
      if (!await saveDir.exists()) {
        await saveDir.create(recursive: true);
      }
    } catch (e) {
      log.add("Failed to create/check directory: $savePath - $e");
    }

    try {
      task.process = await Process.start(ytDlp, args);

      final processCompleter = Completer<void>();

      void processOutput(String data, {bool isError = false}) {
        if (isError) {
          log.add("ERROR: $data");
        } else {
          log.add(data);
        }

        task.liveOutput += data;

        // Better progress parsing
        // [download]  10.5% of 100.00MiB at 10.00MiB/s ETA 00:09
        final progressRegex = RegExp(r'\[download\]\s+([\d\.]+)%');
        final totalSizeRegex = RegExp(r'of\s+([\d\.]+[kMGTP]i?B)');
        final downloadedSizeRegex = RegExp(
          r'\[download\]\s+([\d\.]+[kMGTP]i?B)\s+of',
        );
        final speedRegex = RegExp(r'at\s+([\d\.]+[kMGTP]i?B/s)');
        final etaRegex = RegExp(r'ETA\s+(\d+:\d+)');

        final progressMatch = progressRegex.firstMatch(data);
        if (progressMatch != null) {
          task.progress = double.parse(progressMatch.group(1)!) / 100;
        }

        final sizeMatch = totalSizeRegex.firstMatch(data);
        if (sizeMatch != null) task.fileSize = sizeMatch.group(1)!;

        final downloadedMatch = downloadedSizeRegex.firstMatch(data);
        if (downloadedMatch != null) {
          task.downloadedSize = downloadedMatch.group(1)!;
        }

        final speedMatch = speedRegex.firstMatch(data);
        if (speedMatch != null) task.speed = speedMatch.group(1)!;

        final etaMatch = etaRegex.firstMatch(data);
        if (etaMatch != null) task.eta = etaMatch.group(1)!;

        if (task.fileSize.isNotEmpty) {
          String display = "";
          if (task.downloadedSize.isNotEmpty) {
            display += "${task.downloadedSize} / ";
          }
          display += task.fileSize;
          if (task.speed.isNotEmpty) display += " • ${task.speed}";
          if (task.eta.isNotEmpty) display += " • ETA ${task.eta}";
          task.metadata = display;
        } else {
          task.metadata =
              "Downloading... ${(task.progress * 100).toStringAsFixed(1)}%";
        }

        task.update();
        notifyListeners();
      }

      task.process!.stdout
          .transform(utf8.decoder)
          .listen(
            (data) => processOutput(data),
            onDone: () {
              if (!processCompleter.isCompleted) processCompleter.complete();
            },
            onError: (e) {
              processOutput(e.toString(), isError: true);
            },
          );

      task.process!.stderr
          .transform(utf8.decoder)
          .listen(
            (data) => processOutput(data, isError: true),
            onDone: () {
              if (!processCompleter.isCompleted) processCompleter.complete();
            },
            onError: (e) {
              processOutput(e.toString(), isError: true);
            },
          );

      await processCompleter.future;
      final exitCode = await task.process!.exitCode;

      log.add('--- Download Finished (Exit Code: $exitCode) ---');
      notifyListeners();

      if (exitCode == 0) {
        task.status = DownloadStatus.completed;
        task.progress = 1.0;
        task.metadata = "Completed • ${task.fileSize}";
        return true;
      } else {
        task.status = DownloadStatus.error;
        task.metadata = "Error (Exit code $exitCode)";
        return false;
      }
    } catch (e) {
      log.add('--- Download Error: $e ---');
      task.status = DownloadStatus.error;
      task.metadata = "Critical Error: $e";
      notifyListeners();
      return false;
    } finally {
      task.update();
    }
  }

  void removeTask(DownloadTask task) {
    task.process?.kill();
    // Check if it's a child task
    bool removed = tasks.remove(task);
    if (!removed) {
      // Search in playlist children
      for (var t in tasks) {
        if (t.isPlaylist) {
          if (t.children.remove(task)) {
            t.update();
            break;
          }
        }
      }
    }
    saveHistory();
    notifyListeners();
  }

  void retryTask(DownloadTask task) {
    if (task.status != DownloadStatus.error &&
        !(task.isPlaylist &&
            task.children.any((c) => c.status == DownloadStatus.error))) {
      return;
    }

    if (!task.isPlaylist) {
      task.status = DownloadStatus.queued;
      task.progress = 0.0;
      task.metadata = "Retrying...";
      task.update();
    }

    _startDownload(task, task.savePath ?? "", task.audioOnly);
    notifyListeners();
  }

  void clearAllHistory() {
    // Only remove completed/error tasks
    tasks.removeWhere(
      (t) =>
          t.status == DownloadStatus.completed ||
          t.status == DownloadStatus.error,
    );
    saveHistory();
    notifyListeners();
  }
}
