import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ytdlapp/models/download_task.dart';
import 'package:ytdlapp/services/binary_resolver.dart';

class DownloadController extends ChangeNotifier {
  List<DownloadTask> tasks = [];
  List<String> log = [];
  final List<String> _pendingNotifications = [];

  DownloadController() {
    loadHistory();
  }

  List<String> consumePendingNotifications() {
    final copy = List<String>.from(_pendingNotifications);
    _pendingNotifications.clear();
    return copy;
  }

  void _notifyFailed(DownloadTask task) {
    _pendingNotifications.add('Download failed: ${task.title}');
  }

  List<DownloadTask> get downloadingTasks => tasks
      .where(
        (t) =>
            t.status == DownloadStatus.downloading ||
            t.status == DownloadStatus.queued ||
            t.status == DownloadStatus.paused,
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

  Future<Map<String, dynamic>?> fetchVideoInfo(
    String url, {
    bool flatPlaylist = true,
  }) async {
    if (url.isEmpty) return null;
    final ytDlp = await _getBinaryPath('yt-dlp');
    try {
      final result = await Process.run(ytDlp, [
        '--dump-single-json',
        if (flatPlaylist) '--flat-playlist',
        if (!flatPlaylist) '--no-playlist',
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
    String? playlistItems,
    String resolution = "best",
    Map<String, String>? itemResolutions,
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
        playlistItems: playlistItems,
        playlistTitle: metadata?['title'],
        resolution: resolution,
        itemResolutions: itemResolutions,
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
    String? playlistItems,
    String? playlistTitle,
    String resolution = 'best',
    Map<String, String>? itemResolutions,
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
      if (playlistItems != null && playlistItems.isNotEmpty) {
        args.addAll(['--playlist-items', playlistItems]);
      }

      args.add(url);

      final process = await Process.start(ytDlp, args);

      var streamIndex = 0;
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
                streamIndex++;
                final listIndex = data['playlist_index'] ?? streamIndex;
                final itemRes =
                    itemResolutions?['$listIndex'] ?? resolution;
                final childTask = DownloadTask(
                  id: data['id'] ?? DateTime.now().toString(),
                  url: data['url'] ?? data['webpage_url'] ?? url,
                  title: data['title'] ?? 'Unknown Title',
                  metadata: "Queued",
                  savePath: finalSavePath,
                  resolution: itemRes == 'audio' ? 'best' : itemRes,
                  audioOnly: audioOnly || itemRes == 'audio',
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

  Future<String> _getBinaryPath(String cmd) => BinaryResolver.resolve(cmd);

  /// Runs `<tool> --version` and returns the first output line, or null if
  /// the tool is unavailable.
  Future<String?> getToolVersion(String tool) async {
    final bin = await _getBinaryPath(tool);
    try {
      final result = await Process.run(bin, ['--version']);
      if (result.exitCode == 0) {
        final out = (result.stdout as String).trim();
        if (out.isEmpty) return null;
        return out.split('\n').first;
      }
    } catch (e) {
      log.add("Error reading $tool version: $e");
    }
    return null;
  }

  /// Fetches the latest yt-dlp release tag (e.g. "v2026.08.01") from GitHub,
  /// or null on failure.
  Future<String?> fetchLatestYtDlpVersion() async {
    final curl = Platform.isWindows ? 'curl.exe' : 'curl';
    try {
      final result = await Process.run(curl, [
        '-sL',
        '--max-time',
        '20',
        'https://api.github.com/repos/yt-dlp/yt-dlp/releases/latest',
      ]);
      if (result.exitCode != 0) return null;
      final data = jsonDecode(result.stdout as String);
      if (data is Map) return data['tag_name']?.toString();
    } catch (e) {
      log.add("Error fetching latest yt-dlp version: $e");
    }
    return null;
  }

  /// Downloads the latest yt-dlp release and replaces the bundled binary.
  /// Returns the installed version on success, null on failure.
  Future<String?> updateYtDlp() async {
    final bundle = BinaryResolver.bundleDirectory();
    if (bundle == null) return null;
    final exeName = Platform.isWindows ? 'yt-dlp.exe' : 'yt-dlp';
    final target = File('${bundle.path}/$exeName');
    if (!await target.exists()) return null;

    final asset = Platform.isWindows ? 'yt-dlp.exe' : 'yt-dlp_macos';
    final url =
        'https://github.com/yt-dlp/yt-dlp/releases/latest/download/$asset';
    final tmp = File('${target.path}.new');
    final curl = Platform.isWindows ? 'curl.exe' : 'curl';

    try {
      final dl = await Process.run(curl, ['-sL', '-f', '-o', tmp.path, url]);
      if (dl.exitCode != 0) return null;
      if (!await tmp.exists() || await tmp.length() < 1000000) return null;
      if (Platform.isMacOS || Platform.isLinux) {
        await Process.run('chmod', ['+x', tmp.path]);
      }

      final verify = await Process.run(tmp.path, ['--version']);
      if (verify.exitCode != 0) return null;
      final version = (verify.stdout as String).trim().split('\n').first;

      try {
        await tmp.rename(target.path);
      } catch (_) {
        await target.delete();
        await tmp.rename(target.path);
      }
      log.add('--- yt-dlp updated to $version ---');
      return version;
    } catch (e) {
      log.add("Error updating yt-dlp: $e");
      return null;
    } finally {
      if (await tmp.exists()) {
        try {
          await tmp.delete();
        } catch (_) {}
      }
    }
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

        final success = await _executeDownload(
          child,
          savePath,
          child.audioOnly,
        );

        if (success) {
          completed++;
          child.status = DownloadStatus.completed;
          child.metadata = "Completed";
          child.progress = 1.0;
        } else if (child.pauseRequested) {
          child.pauseRequested = false;
          child.status = DownloadStatus.paused;
          child.metadata = "Paused";
          task.playlistProgress =
              "Paused at video ${i + 1} of ${task.children.length}";
          task.status = DownloadStatus.paused;
          task.update();
          break;
        } else {
          child.status = DownloadStatus.error;
          child.metadata = "Error";
          _notifyFailed(child);
        }
        task.progress = completed / task.children.length;
        task.update();
      }
      if (task.status != DownloadStatus.paused) {
        task.status = DownloadStatus.completed;
        task.playlistProgress = "All videos downloaded";
        task.update();
      }
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
      '--retries',
      '10',
      '--retry-sleep',
      '5',
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
      if (task.pauseRequested) {
        task.status = DownloadStatus.paused;
        task.metadata = "Paused";
        task.update();
        return false;
      }
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

      if (task.pauseRequested) {
        task.status = DownloadStatus.paused;
        final pct = (task.progress * 100).clamp(0, 100).round();
        task.metadata = task.progress > 0 ? 'Paused • $pct%' : 'Paused';
        return false;
      }

      if (exitCode == 0) {
        task.status = DownloadStatus.completed;
        task.progress = 1.0;
        task.metadata = "Completed • ${task.fileSize}";
        return true;
      } else {
        task.status = DownloadStatus.error;
        task.metadata = "Error (Exit code $exitCode)";
        notifyListeners();
        _notifyFailed(task);
        return false;
      }
    } catch (e) {
      log.add('--- Download Error: $e ---');
      task.status = DownloadStatus.error;
      task.metadata = "Critical Error: $e";
      notifyListeners();
      _notifyFailed(task);
      return false;
    } finally {
      task.update();
    }
  }

  /// Pauses a download. The running yt-dlp process is killed gracefully
  /// (SIGINT on POSIX, terminate on Windows) so the partial `.part` file is
  /// kept for a later resume.
  void pauseTask(DownloadTask task) {
    if (task.isPlaylist) {
      final child = task.children
          .where((c) => c.status == DownloadStatus.downloading)
          .firstOrNull;
      if (child != null) {
        child.pauseRequested = true;
        _killProcess(child.process);
      }
      task.status = DownloadStatus.paused;
      task.metadata = "Paused";
    } else {
      task.pauseRequested = true;
      _killProcess(task.process);
      task.status = DownloadStatus.paused;
      final pct = (task.progress * 100).clamp(0, 100).round();
      task.metadata = task.progress > 0
          ? 'Paused • $pct%'
          : 'Paused';
    }
    task.update();
    saveHistory();
    notifyListeners();
  }

  /// Resumes a paused download. yt-dlp continues from the `.part` file.
  void resumeTask(DownloadTask task) {
    if (task.status != DownloadStatus.paused) return;

    // Make sure any lingering process from a previous run is gone.
    _killProcess(task.process);
    task.pauseRequested = false;
    task.status = DownloadStatus.queued;
    task.metadata = "Resuming...";
    task.update();

    _startDownload(task, task.savePath ?? "", task.audioOnly);
    notifyListeners();
  }

  void _killProcess(Process? process) {
    if (process == null) return;
    try {
      if (Platform.isWindows) {
        process.kill();
      } else {
        process.kill(ProcessSignal.sigint);
      }
    } catch (e) {
      log.add("Error killing process: $e");
      try {
        process.kill();
      } catch (_) {}
    }
  }

  void removeTask(DownloadTask task) {
    _killProcess(task.process);
    if (task.isPlaylist) {
      for (final child in task.children) {
        _killProcess(child.process);
        child.pauseRequested = false;
      }
    }
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
      task.pauseRequested = false;
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
