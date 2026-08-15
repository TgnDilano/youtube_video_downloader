import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:ytdlapp/models/convert_task.dart';
import 'package:ytdlapp/services/binary_resolver.dart';

/// Drives the local media converter: probes sources with ffprobe and
/// re-encodes files to the chosen video/audio format with ffmpeg.
class ConvertController extends ChangeNotifier {
  List<ConvertTask> tasks = [];
  List<String> log = [];

  static const List<String> videoTargets = [
    'mp4',
    'mkv',
    'webm',
    'avi',
    'mov',
    'mpeg',
  ];
  static const List<String> audioTargets = [
    'mp3',
    'm4a',
    'wav',
    'flac',
    'ogg',
    'opus',
  ];

  static const Set<String> _audioExtensions = {
    'mp3', 'm4a', 'm4b', 'aac', 'wav', 'flac',
    'ogg', 'oga', 'opus', 'wma', 'amr',
  };

  static bool isVideoTarget(String id) => videoTargets.contains(id);
  static bool isAudioTarget(String id) => audioTargets.contains(id);
  static bool isAudioSource(String path) =>
      _audioExtensions.contains(p.extension(path).toLowerCase().replaceFirst('.', ''));

  List<ConvertTask> get activeTasks =>
      tasks.where((t) => t.isActive).toList();

  List<ConvertTask> get finishedTasks =>
      tasks
          .where((t) =>
              t.status == ConvertStatus.completed ||
              t.status == ConvertStatus.error)
          .toList();

  /// Reads duration, size and stream codecs of [path] via ffprobe;
  /// null when unavailable.
  Future<Map<String, String>?> probeSource(String path) async {
    final ffprobe = await BinaryResolver.resolve('ffprobe');
    try {
      final result = await Process.run(ffprobe, [
        '-v', 'error',
        '-show_entries', 'format=duration,size:stream=codec_type,codec_name',
        '-of', 'json',
        path,
      ]);
      if (result.exitCode != 0) return null;
      final data = jsonDecode(result.stdout as String);
      final format = data is Map ? data['format'] : null;
      if (format is! Map) return null;
      var hasVideo = false;
      var hasAudio = false;
      String? videoCodec;
      String? audioCodec;
      final streams = data['streams'];
      if (streams is List) {
        for (final s in streams) {
          if (s is! Map) continue;
          final type = s['codec_type']?.toString();
          final codec = s['codec_name']?.toString();
          if (type == 'video' && !hasVideo) {
            hasVideo = true;
            videoCodec = codec;
          } else if (type == 'audio' && !hasAudio) {
            hasAudio = true;
            audioCodec = codec;
          }
        }
      }
      return {
        'duration': format['duration']?.toString() ?? '',
        'size': format['size']?.toString() ?? '',
        'hasVideo': hasVideo ? 'true' : 'false',
        'hasAudio': hasAudio ? 'true' : 'false',
        'videoCodec': videoCodec ?? '',
        'audioCodec': audioCodec ?? '',
      };
    } catch (e) {
      log.add("Error probing source: $e");
      return null;
    }
  }

  /// Whether [targetId] can be produced with a pure stream copy (no
  /// re-encode) when the source streams match the target container.
  static bool canStreamCopy(
    String targetId, {
    required bool hasVideo,
    required String? videoCodec,
    required bool hasAudio,
    required String? audioCodec,
  }) {
    final v = videoCodec?.toLowerCase();
    final a = audioCodec?.toLowerCase();
    bool videoIn(Set<String> s) => v != null && s.contains(v);
    bool audioIn(Set<String> s) => a != null && s.contains(a);
    switch (targetId) {
      case 'mp4':
        return hasVideo &&
            videoIn({'h264', 'hevc', 'av1', 'vp9'}) &&
            (!hasAudio || audioIn({'aac', 'mp3', 'opus', 'flac'}));
      case 'mkv':
        return hasVideo &&
            videoIn({
              'h264', 'hevc', 'vp9', 'av1', 'vp8',
              'mpeg4', 'mpeg2video',
            }) &&
            (!hasAudio ||
                audioIn({
                  'aac', 'mp3', 'opus', 'vorbis', 'flac',
                  'ac3', 'eac3', 'pcm_s16le', 'pcm_s24le',
                }));
      case 'mov':
        return hasVideo &&
            videoIn({'h264', 'hevc', 'vp9'}) &&
            (!hasAudio ||
                audioIn({'aac', 'mp3', 'pcm_s16le', 'pcm_s24le'}));
      case 'webm':
        return hasVideo &&
            videoIn({'vp9', 'vp8', 'av1'}) &&
            (!hasAudio || audioIn({'opus', 'vorbis'}));
      case 'avi':
        return hasVideo &&
            videoIn({'mpeg4', 'mpeg2video'}) &&
            (!hasAudio || audioIn({'mp3', 'pcm_s16le', 'pcm_s24le'}));
      case 'mpeg':
        return hasVideo &&
            videoIn({'mpeg1video', 'mpeg2video'}) &&
            (!hasAudio || audioIn({'mp2', 'mp3'}));
      case 'm4a':
        return hasAudio && audioIn({'aac', 'mp3', 'alac'});
      case 'mp3':
        return hasAudio && audioIn({'mp3'});
      case 'wav':
        return hasAudio &&
            audioIn({'pcm_s16le', 'pcm_s24le', 'pcm_s32le', 'pcm_f32le'});
      case 'flac':
        return hasAudio && audioIn({'flac'});
      case 'ogg':
        return hasAudio && audioIn({'vorbis', 'opus', 'flac'});
      case 'opus':
        return hasAudio && audioIn({'opus'});
      default:
        return false;
    }
  }

  void addConversion({
    required String sourcePath,
    required String outputDir,
    required String targetId,
    double durationSeconds = 0,
  }) {
    final base = p.basenameWithoutExtension(sourcePath);
    var outPath = p.join(outputDir, '$base.${targetId.toLowerCase()}');
    var n = 1;
    while (File(outPath).existsSync()) {
      outPath = p.join(outputDir, '$base ($n).${targetId.toLowerCase()}');
      n++;
    }

    final task = ConvertTask(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      sourcePath: sourcePath,
      sourceName: p.basename(sourcePath),
      outputPath: outPath,
      targetId: targetId.toLowerCase(),
      durationSeconds: durationSeconds,
    );
    try {
      final size = File(sourcePath).lengthSync();
      task.fileSize = _formatBytes(size);
    } catch (_) {}

    tasks.insert(0, task);
    final blockers = <String>[
      if (isVideoTarget(task.targetId) && isAudioSource(sourcePath))
        'Cannot make video from an audio-only source',
      if (!File(sourcePath).existsSync()) 'Source file not found',
    ];
    if (blockers.isNotEmpty) {
      task.status = ConvertStatus.error;
      log.add('--- Convert failed: ${blockers.join('; ')} ---');
      task.update();
      notifyListeners();
      return;
    }

    notifyListeners();
    _run(task);
  }

  Future<void> _run(ConvertTask task) async {
    task.status = ConvertStatus.converting;
    task.update();

    final ffmpeg = await BinaryResolver.resolve('ffmpeg');
    final info = await probeSource(task.sourcePath);
    final canCopy = info != null &&
        canStreamCopy(
          task.targetId,
          hasVideo: info['hasVideo'] == 'true',
          videoCodec: info['videoCodec'],
          hasAudio: info['hasAudio'] == 'true',
          audioCodec: info['audioCodec'],
        );

    final args = <String>[
      '-hide_banner',
      '-y',
      '-loglevel', 'error',
      '-i', task.sourcePath,
      if (canCopy) ...[
        if (isAudioTarget(task.targetId)) ...[
          '-map', '0:a:0',
        ] else ...[
          '-map', '0:v:0',
          if (info['hasAudio'] == 'true') '-map', '0:a:0',
        ],
        '-c', 'copy',
        if (task.targetId == 'mp4') '-movflags', '+faststart',
      ] else ...[
        ..._codecArgs(task.targetId),
        if (isAudioTarget(task.targetId)) '-vn',
        '-sn', '-dn',
      ],
      '-nostats',
      '-progress', 'pipe:1',
      task.outputPath,
    ];

    final mode = canCopy ? 'remux (stream copy)' : 're-encode';
    task.mode = canCopy ? 'remux' : 're-encode';
    log.add('--- Starting convert: ${task.sourceName} → ${task.targetLabel} '
        '($mode) ---');
    log.add('ffmpeg ${args.join(' ')}');
    notifyListeners();

    try {
      task.process = await Process.start(ffmpeg, args);
      final sub = task.process!.stdout
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen((line) {
        if (line.startsWith('out_time_ms=')) {
          final ms = double.tryParse(line.substring('out_time_ms='.length));
          final total = task.durationSeconds * 1e6;
          if (ms != null && total > 0) {
            task.progress = (ms / total).clamp(0.0, 1.0);
          }
          task.update();
        } else if (line == 'progress=end') {
          task.progress = 1.0;
          task.update();
        }
      });

      // Drain stderr continuously: an unread pipe fills up (64KB) and
      // blocks ffmpeg mid-encode when a source floods warnings. Keep a
      // rolling tail so errors are still reportable afterwards.
      task.process!.stderr
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen((line) {
        task.stderrTail.add(line);
        if (task.stderrTail.length > 40) task.stderrTail.removeAt(0);
      });

      final exitCode = await task.process!.exitCode;
      await sub.cancel();

      if (exitCode == 0) {
        task.status = ConvertStatus.completed;
        task.progress = 1.0;
      } else {
        task.status = ConvertStatus.error;
        log.add('--- Convert error (exit code $exitCode) ---');
        if (task.stderrTail.isNotEmpty) {
          log.addAll(task.stderrTail.sublist(
            task.stderrTail.length > 6
                ? task.stderrTail.length - 6
                : 0,
          ));
        }
      }
    } catch (e) {
      task.status = ConvertStatus.error;
      log.add('--- Convert error: $e ---');
    }
    task.update();
    notifyListeners();
  }

  List<String> _codecArgs(String target) {
    switch (target) {
      case 'mp4':
        return [
          '-c:v', 'libx264', '-preset', 'veryfast', '-crf', '23',
          '-c:a', 'aac', '-b:a', '192k',
          '-movflags', '+faststart',
        ];
      case 'mkv':
        return [
          '-c:v', 'libx264', '-preset', 'veryfast', '-crf', '23',
          '-c:a', 'aac', '-b:a', '192k',
        ];
      case 'webm':
        return [
          '-c:v', 'libvpx-vp9', '-crf', '30', '-b:v', '0',
          '-c:a', 'libopus', '-b:a', '128k',
        ];
      case 'avi':
        return [
          '-c:v', 'mpeg4', '-q:v', '4',
          '-c:a', 'libmp3lame', '-q:a', '4',
        ];
      case 'mov':
        return [
          '-c:v', 'libx264', '-preset', 'veryfast', '-crf', '23',
          '-c:a', 'aac', '-b:a', '192k',
        ];
      case 'mpeg':
        return [
          '-c:v', 'mpeg2video', '-q:v', '4',
          '-c:a', 'mp2', '-b:a', '192k',
        ];
      case 'mp3':
        return ['-c:a', 'libmp3lame', '-b:a', '192k'];
      case 'm4a':
        return ['-c:a', 'aac', '-b:a', '192k'];
      case 'wav':
        return ['-c:a', 'pcm_s16le'];
      case 'flac':
        return ['-c:a', 'flac'];
      case 'ogg':
        return ['-c:a', 'libvorbis', '-q:a', '4'];
      case 'opus':
        return ['-c:a', 'libopus', '-b:a', '160k'];
      default:
        return ['-c', 'copy'];
    }
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    const units = ['KB', 'MB', 'GB'];
    var value = bytes / 1024;
    var unit = 0;
    while (value >= 1024 && unit < units.length - 1) {
      value /= 1024;
      unit++;
    }
    return '${value.toStringAsFixed(1)} ${units[unit]}';
  }

  void removeTask(ConvertTask task) {
    task.process?.kill();
    tasks.remove(task);
    notifyListeners();
  }

  void retryTask(ConvertTask task) {
    if (task.status != ConvertStatus.error) return;
    task.status = ConvertStatus.queued;
    task.progress = 0.0;
    task.update();
    _run(task);
    notifyListeners();
  }

  void clearFinished() {
    tasks.removeWhere(
      (t) =>
          t.status == ConvertStatus.completed ||
          t.status == ConvertStatus.error,
    );
    notifyListeners();
  }
}