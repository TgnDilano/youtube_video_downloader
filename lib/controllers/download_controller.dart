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

  List<DownloadTask> get completedTasks => tasks
      .where(
        (t) =>
            t.status == DownloadStatus.completed ||
            t.status == DownloadStatus.error,
      )
      .toList();

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
        '--dump-json',
        '--no-playlist',
        url,
      ]);
      if (result.exitCode == 0) {
        return jsonDecode(result.stdout);
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
      );
    } else {
      final task = DownloadTask(
        id: DateTime.now().toString(),
        url: url,
        resolution: resolution,
        savePath: savePath,
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
  }) async {
    final parentTask = DownloadTask(
      id: DateTime.now().toString(),
      url: url,
      title: "Fetching playlist info...",
      isPlaylist: true,
      savePath: savePath,
    );
    tasks.insert(0, parentTask);
    notifyListeners();

    final ytDlp = await _getBinaryPath('yt-dlp');
    try {
      final result = await Process.run(ytDlp, [
        '--flat-playlist',
        '--dump-json',
        '--playlist-start',
        (playlistStart ?? 1).toString(),
        '--playlist-end',
        (playlistEnd ?? 10).toString(),
        url,
      ]);

      if (result.exitCode == 0) {
        final lines = (result.stdout as String)
            .split('\n')
            .where((line) => line.trim().isNotEmpty);
        parentTask.title = "Playlist"; // Generic title for the parent
        for (var line in lines) {
          final data = jsonDecode(line);
          final childTask = DownloadTask(
            id: data['id'] ?? DateTime.now().toString(),
            url: data['url'] ?? data['webpage_url'] ?? url,
            title: data['title'] ?? 'Unknown Title',
            metadata: "Queued",
            savePath: savePath,
          );
          parentTask.children.add(childTask);
        }
      } else {
        parentTask.title = "Error fetching playlist";
        parentTask.status = DownloadStatus.error;
      }
    } catch (e) {
      parentTask.title = "Error fetching playlist";
      parentTask.status = DownloadStatus.error;
    }

    parentTask.update();
    notifyListeners();
    if (parentTask.status != DownloadStatus.error) {
      _startDownload(parentTask, savePath, audioOnly);
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
      int completed = 0;
      for (var i = 0; i < task.children.length; i++) {
        final child = task.children[i];
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
      task.process = await Process.start(ytDlp, args);

      final processCompleter = Completer<void>();

      void processOutput(String data, {bool isError = false}) {
        if (isError)
          log.add("ERROR: $data");
        else
          log.add(data);

        task.liveOutput += data;

        // Better progress parsing
        // [download]  10.5% of 100.00MiB at 10.00MiB/s ETA 00:09
        final progressRegex = RegExp(r'\[download\]\s+(\d+\.\d+)%');
        final sizeRegex = RegExp(r'of\s+(\d+\.\d+\w+)');
        final speedRegex = RegExp(r'at\s+(\d+\.\d+\w+/s)');
        final etaRegex = RegExp(r'ETA\s+(\d+:\d+)');

        final progressMatch = progressRegex.firstMatch(data);
        if (progressMatch != null) {
          task.progress = double.parse(progressMatch.group(1)!) / 100;

          final sizeMatch = sizeRegex.firstMatch(data);
          if (sizeMatch != null) task.fileSize = sizeMatch.group(1)!;

          final speedMatch = speedRegex.firstMatch(data);
          if (speedMatch != null) task.speed = speedMatch.group(1)!;

          final etaMatch = etaRegex.firstMatch(data);
          if (etaMatch != null) task.eta = etaMatch.group(1)!;

          task.metadata = "${task.fileSize} • ${task.speed} • ETA ${task.eta}";
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
      task.metadata = "Error: $e";
      notifyListeners();
      return false;
    } finally {
      task.update();
    }
  }

  void removeTask(DownloadTask task) {
    task.process?.kill();
    tasks.remove(task);
    saveHistory();
    notifyListeners();
  }
}
