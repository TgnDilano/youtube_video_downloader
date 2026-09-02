import 'package:flutter_test/flutter_test.dart';
import 'package:ytdlapp/features/torrents/domain/torrent_task.dart';

void main() {
  group('TorrentTask', () {
    test('defaults to fetching metadata with zero progress', () {
      final task = TorrentTask(id: 1);
      expect(task.status, TorrentStatus.fetchingMetadata);
      expect(task.progress, 0.0);
      expect(task.isSeeding, isFalse);
      expect(task.name, 'Fetching metadata…');
    });

    test('isSeeding is true only when finished and not paused', () {
      final downloading = TorrentTask(id: 1, isFinished: false);
      expect(downloading.isSeeding, isFalse);

      final finished = TorrentTask(id: 2, isFinished: true);
      expect(finished.isSeeding, isTrue);

      final paused = TorrentTask(id: 3, isFinished: true, isPaused: true);
      expect(paused.isSeeding, isFalse);
    });

    test('update() notifies listeners', () {
      final task = TorrentTask(id: 1);
      var notified = 0;
      task.addListener(() => notified++);
      task.progress = 0.5;
      task.update();
      expect(notified, 1);
    });
  });
}
