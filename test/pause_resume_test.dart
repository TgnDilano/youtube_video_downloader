import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ytdlapp/features/download/domain/download_controller.dart';
import 'package:ytdlapp/features/download/domain/download_task.dart';

// End-to-end pause/resume test against a local throttled HTTP server.
// Generates a 24MB file, serves it at ~1.5MB/s, pauses mid-download and
// verifies yt-dlp resumes from the .part file.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({'cookie_browser': 'none'});

  late Directory workDir;
  late Process server;
  late String url;

  setUpAll(() async {
    workDir = Directory(
      '${Directory.systemTemp.path}/ytdl_pause_resume_${DateTime.now().millisecondsSinceEpoch}',
    );
    await workDir.create(recursive: true);
    final big = File('${workDir.path}/source.bin');
    await big.writeAsBytes(
      List<int>.generate(24 * 1024 * 1024, (i) => i % 251),
    );

    final serverScript = File('${workDir.path}/server.py');
    await serverScript.writeAsString('''
import os, re, time, sys
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
SIZE = os.path.getsize(sys.argv[1])
class H(BaseHTTPRequestHandler):
    def log_message(self, *a): pass
    def do_GET(self):
        m = re.match(r'bytes=(\\d+)-(\\d*)', self.headers.get('Range',''))
        start, end, st = 0, SIZE-1, 200
        if m:
            start = int(m.group(1))
            if m.group(2): end = int(m.group(2))
            st = 206
        length = end - start + 1
        self.send_response(st)
        self.send_header('Content-Type','application/octet-stream')
        self.send_header('Content-Length', str(length))
        self.send_header('Accept-Ranges','bytes')
        if st == 206: self.send_header('Content-Range', f'bytes {start}-{end}/{SIZE}')
        self.end_headers()
        sent = 0
        t0 = time.monotonic()
        with open(sys.argv[1],'rb') as f:
            f.seek(start)
            while sent < length:
                data = f.read(min(65536, length - sent))
                if not data: break
                try: self.wfile.write(data)
                except (BrokenPipeError, ConnectionResetError): return
                sent += len(data)
                e = time.monotonic() - t0
                t = sent / 1500000.0
                if t > e: time.sleep(min(t - e, 0.1))
        self.wfile.flush()
ThreadingHTTPServer(('127.0.0.1', 8788), H).serve_forever()
''');
    server = await Process.start('python3', [serverScript.path, big.path]);
    await Future<void>.delayed(const Duration(milliseconds: 500));
    url = 'http://127.0.0.1:8788/source.bin';
  });

  tearDownAll(() async {
    server.kill();
    try {
      await workDir.delete(recursive: true);
    } catch (_) {}
  });

  test(
    'pause kills the process and keeps the .part file; resume continues',
    () async {
      final controller = DownloadController();
      controller.addDownload(
        url,
        workDir.path,
        false,
        metadata: {'title': 'big'},
      );

      final task = controller.tasks.first;

      // Wait until the download process is alive and has started writing data.
      await _waitUntil(
        () =>
            task.status == DownloadStatus.downloading &&
            task.process != null &&
            task.process!.pid > 0,
        timeout: const Duration(seconds: 20),
      );
      await _waitUntil(
        () => Directory(workDir.path).listSync().any(
          (f) => f.path.endsWith('.part') && f.statSync().size > 100000,
        ),
        timeout: const Duration(seconds: 20),
      );

      final partSizeBefore = Directory(
        workDir.path,
      ).listSync().firstWhere((f) => f.path.endsWith('.part')).statSync().size;
      expect(partSizeBefore, greaterThan(100000));

      // ---- Pause
      controller.pauseTask(task);
      await _waitUntil(
        () => task.status == DownloadStatus.paused,
        timeout: const Duration(seconds: 10),
      );
      expect(task.pauseRequested, isTrue, reason: 'flagged until resumed');
      expect(task.process!.exitCode, isNotNull, reason: 'process was killed');

      final part = Directory(
        workDir.path,
      ).listSync().firstWhere((f) => f.path.endsWith('.part'));
      final partSizeAfter = part.statSync().size;
      expect(
        partSizeAfter,
        greaterThanOrEqualTo(partSizeBefore),
        reason: '.part must survive the pause',
      );

      // ---- Resume
      controller.resumeTask(task);
      await _waitUntil(
        () => task.status == DownloadStatus.completed,
        timeout: const Duration(seconds: 60),
      );

      final out = File('${workDir.path}/source.unknown_video');
      expect(out.existsSync(), isTrue, reason: 'final file written');
      expect(out.lengthSync(), 24 * 1024 * 1024);
      expect(task.status, DownloadStatus.completed);
      // Definitive evidence of a real resume: yt-dlp logs the continuation
      // byte from the .part file.
      final resumeLine = controller.log
          .where((l) => l.contains('Resuming download at byte'))
          .toList();
      expect(resumeLine, isNotEmpty, reason: 'yt-dlp must resume from .part');
      expect(
        int.parse(resumeLine.first.replaceAll(RegExp(r'[^0-9]'), '')),
        greaterThan(0),
      );
    },
  );
}

Future<void> _waitUntil(
  bool Function() predicate, {
  required Duration timeout,
}) async {
  final deadline = DateTime.now().add(timeout);
  while (!predicate()) {
    if (DateTime.now().isAfter(deadline)) {
      fail('condition not met within $timeout');
    }
    await Future<void>.delayed(const Duration(milliseconds: 100));
  }
}
