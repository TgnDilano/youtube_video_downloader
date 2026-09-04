import 'package:flutter_test/flutter_test.dart';
import 'package:ytdlapp/features/torrents/data/torrent_engine.dart';
import 'package:ytdlapp/features/torrents/domain/torrent_controller.dart';
import 'package:ytdlapp/features/torrents/domain/torrent_file_info.dart';
import 'package:ytdlapp/features/torrents/domain/torrent_source.dart';
import 'package:ytdlapp/features/torrents/domain/torrent_task.dart';

class _FakeEngine extends TorrentEngine {
  final paused = <int>[];
  final resumed = <int>[];
  final removed = <int, bool>{};
  final Map<int, TorrentEngineSnapshot> injected = {};

  @override
  Map<int, TorrentEngineSnapshot> get snapshots => Map.unmodifiable(injected);

  @override
  Future<int> add(TorrentSource source, String savePath) async => 1;

  @override
  void pause(int id) => paused.add(id);

  @override
  void resume(int id) => resumed.add(id);

  @override
  void remove(int id, {bool deleteFiles = false}) => removed[id] = deleteFiles;
}

void main() {
  group('TorrentController pause/resume', () {
    test('pause flips task state immediately so the UI icon changes', () async {
      final engine = _FakeEngine();
      final controller = TorrentController(engine: engine);
      final id = await controller.addTorrent(
        TorrentSource.magnet(
          'magnet:?xt=urn:btih:0123456789abcdef0123456789abcdef01234567',
        ),
        '/tmp',
      );
      final task = controller.tasks.first;
      task.downloadRate = '1.5 MiB/s';
      task.uploadRate = '200 KiB/s';

      var notified = 0;
      controller.addListener(() => notified++);

      controller.pause(id);

      expect(engine.paused, contains(id));
      expect(task.isPaused, isTrue);
      expect(task.status, TorrentStatus.paused);
      expect(
        task.downloadRate,
        '0 B/s',
        reason: 'stale download speed must clear on pause',
      );
      expect(
        task.uploadRate,
        '0 B/s',
        reason: 'stale upload speed must clear on pause',
      );
      expect(
        notified,
        greaterThan(0),
        reason: 'UI must rebuild right away on pause',
      );
    });

    test('resume flips task state back to downloading immediately', () async {
      final engine = _FakeEngine();
      final controller = TorrentController(engine: engine);
      final id = await controller.addTorrent(
        TorrentSource.magnet(
          'magnet:?xt=urn:btih:0123456789abcdef0123456789abcdef01234567',
        ),
        '/tmp',
      );
      controller.pause(id);

      controller.resume(id);

      expect(engine.resumed, contains(id));
      final task = controller.tasks.first;
      expect(task.isPaused, isFalse);
      expect(task.status, TorrentStatus.downloading);
    });

    test(
      'remove without delete options keeps data and default source file',
      () async {
        final engine = _FakeEngine();
        final controller = TorrentController(engine: engine);
        final id = await controller.addTorrent(
          TorrentSource.file('/tmp/downloads/ubuntu.torrent'),
          '/tmp',
        );

        controller.remove(id);

        expect(
          engine.removed[id],
          isFalse,
          reason: 'data files kept by default (deleteFiles=false)',
        );
        expect(controller.tasks, isEmpty);
      },
    );

    test('remove with deleteData=true requests file deletion from engine', () async {
      final engine = _FakeEngine();
      final controller = TorrentController(engine: engine);
      final id = await controller.addTorrent(
        TorrentSource.magnet(
          'magnet:?xt=urn:btih:0123456789abcdef0123456789abcdef01234567',
        ),
        '/tmp',
      );

      controller.remove(id, deleteData: true);

      expect(engine.removed[id], isTrue);
      expect(controller.tasks, isEmpty);
    });
  });

  group('TorrentController metrics', () {
    TorrentEngineSnapshot snap({
      required int id,
      required bool paused,
      required bool finished,
      required int totalWanted,
      required int totalDone,
      required int downloadRate,
    }) => TorrentEngineSnapshot(
      id: id,
      name: 'file',
      savePath: '/tmp',
      errorMsg: '',
      status: paused
          ? TorrentStatus.paused
          : finished
          ? TorrentStatus.seeding
          : TorrentStatus.downloading,
      progress: totalWanted == 0 ? 0 : totalDone / totalWanted,
      downloadRate: downloadRate,
      uploadRate: 0,
      totalDone: totalDone,
      totalWanted: totalWanted,
      totalUploaded: 0,
      numPeers: 0,
      numSeeds: 0,
      isPaused: paused,
      isFinished: finished,
      hasMetadata: totalWanted > 0,
    );

    test(
      'total size and ETA are computed from active download metrics',
      () async {
        final e = _FakeEngine();
        final controller = TorrentController(engine: e);
        e.injected[1] = snap(
          id: 1,
          paused: false,
          finished: false,
          totalWanted: 10 * 1024 * 1024,
          totalDone: 5 * 1024 * 1024,
          downloadRate: 1024 * 1024,
        );
        e.tasksChanged?.call();

        final task = controller.tasks.first;
        expect(task.totalSize, 10 * 1024 * 1024);
        // remaining 5 MiB at 1 MiB/s → 5s
        expect(task.eta, '5s');
      },
    );

    test('ETA is blank when paused or finished', () async {
      final e = _FakeEngine();
      final controller = TorrentController(engine: e);
      e.injected[1] = snap(
        id: 1,
        paused: true,
        finished: false,
        totalWanted: 10 * 1024 * 1024,
        totalDone: 5 * 1024 * 1024,
        downloadRate: 1024 * 1024,
      );
      e.tasksChanged?.call();

      final task = controller.tasks.first;
      expect(task.downloadRate, '0 B/s');
      expect(task.eta, isEmpty);
    });
  });

  group('TorrentController revealPath', () {
    test('single-file torrent reveals the exact file', () {
      final path = TorrentController.revealPath('/tmp/dl', [
        TorrentFileInfo(index: 0, name: 'movie.mp4', path: 'movie.mp4', size: 100),
      ]);
      expect(path, '/tmp/dl/movie.mp4');
    });

    test('multi-file torrent reveals the common top-level folder', () {
      final files = [
        TorrentFileInfo(index: 0, name: 'a.txt', path: 'Album/a.txt', size: 1),
        TorrentFileInfo(index: 1, name: 'b.txt', path: 'Album/b.txt', size: 2),
      ];
      expect(TorrentController.revealPath('/tmp/dl', files), '/tmp/dl/Album');
    });

    test('multi-file torrent without a shared folder falls back to savePath', () {
      final files = [
        TorrentFileInfo(index: 0, name: 'a.txt', path: 'a.txt', size: 1),
        TorrentFileInfo(index: 1, name: 'b.txt', path: 'b.txt', size: 2),
      ];
      expect(TorrentController.revealPath('/tmp/dl', files), '/tmp/dl');
    });

    test('empty file list falls back to savePath', () {
      expect(TorrentController.revealPath('/tmp/dl', []), '/tmp/dl');
    });
  });
}
