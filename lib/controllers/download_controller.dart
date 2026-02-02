import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:ytdlapp/models/download_task.dart';

class DownloadController extends ChangeNotifier {
  List<DownloadTask> tasks = [];
  List<String> log = [];

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

  void addDownload(
    String url,
    String savePath,
    bool audioOnly, {
    bool isPlaylist = false,
    int? playlistStart,
    int? playlistEnd,
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
      final task = DownloadTask(id: DateTime.now().toString(), url: url);
      tasks.insert(0, task);
      notifyListeners();
      await _fetchMetadata(task);
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
            id: data['id'],
            url: data['url'],
            title: data['title'] ?? 'Unknown Title',
            metadata: "Queued",
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
      notifyListeners();
    } else {
      await _executeDownload(task, savePath, audioOnly);
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
    List<String> args = audioOnly
        ? ['-x', '--audio-format', 'mp3']
        : ['-f', 'bv*+ba/b', '--merge-output-format', 'mp4'];

    args.addAll([
      '--no-playlist',
      '--newline',
      '-o',
      '$savePath/%(title)s.%(ext)s',
      task.url,
    ]);

    log.add('--- Starting Download: ${task.title} ---');
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

        final progressRegex = RegExp(r'\[download\]\s+(\d+\.\d+)%');
        final progressMatch = progressRegex.firstMatch(data);
        if (progressMatch != null) {
          task.progress = double.parse(progressMatch.group(1)!) / 100;
          task.metadata = data.split('[download]')[1].trim();
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
        return true;
      } else {
        task.status = DownloadStatus.error;
        return false;
      }
    } catch (e) {
      log.add('--- Download Error: $e ---');
      task.status = DownloadStatus.error;
      notifyListeners();
      return false;
    } finally {
      task.update();
    }
  }

  void removeTask(DownloadTask task) {
    task.process?.kill();
    tasks.remove(task);
    notifyListeners();
  }
}
