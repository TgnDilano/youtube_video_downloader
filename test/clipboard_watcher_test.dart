import 'package:flutter_test/flutter_test.dart';
import 'package:ytdlapp/core/services/clipboard_watcher.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ClipboardWatcher.isYouTubeUrl', () {
    test('matches standard watch URLs', () {
      expect(
        ClipboardWatcher.isYouTubeUrl(
          'https://www.youtube.com/watch?v=abc123def',
        ),
        isTrue,
      );
    });

    test('matches youtu.be short links', () {
      expect(
        ClipboardWatcher.isYouTubeUrl('https://youtu.be/abc123def'),
        isTrue,
      );
    });

    test('matches mobile, shorts, music and embed hosts', () {
      expect(
        ClipboardWatcher.isYouTubeUrl('https://m.youtube.com/watch?v=x'),
        isTrue,
      );
      expect(
        ClipboardWatcher.isYouTubeUrl('https://www.youtube.com/shorts/xYz'),
        isTrue,
      );
      expect(
        ClipboardWatcher.isYouTubeUrl(
          'https://music.youtube.com/watch?v=xYz',
        ),
        isTrue,
      );
      expect(
        ClipboardWatcher.isYouTubeUrl(
          'https://www.youtube.com/embed/xYz',
        ),
        isTrue,
      );
    });

    test('matches a link embedded inside surrounding text', () {
      expect(
        ClipboardWatcher.isYouTubeUrl(
          'Check this out: https://youtu.be/ab12cd !',
        ),
        isTrue,
      );
    });

    test('rejects empty, feed URLs and other domains', () {
      expect(ClipboardWatcher.isYouTubeUrl(''), isFalse);
      expect(ClipboardWatcher.isYouTubeUrl('   '), isFalse);
      expect(ClipboardWatcher.isYouTubeUrl('https://example.com/watch?v=x'),
          isFalse);
      expect(
        ClipboardWatcher.isYouTubeUrl(
          'https://www.youtube.com',
        ),
        isFalse,
      );
    });

    test('starts and stops the polling timer', () async {
      final watcher = ClipboardWatcher();
      expect(watcher.isRunning, isFalse);
      watcher.start();
      expect(watcher.isRunning, isTrue);
      watcher.stop();
      expect(watcher.isRunning, isFalse);
      watcher.dispose();
    });
  });
}