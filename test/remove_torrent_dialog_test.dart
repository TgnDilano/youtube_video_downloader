import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ytdlapp/core/theme/app_theme.dart';
import 'package:ytdlapp/features/torrents/domain/torrent_source.dart';
import 'package:ytdlapp/features/torrents/domain/torrent_task.dart';
import 'package:ytdlapp/features/torrents/ui/widgets/remove_torrent_dialog.dart';

Widget _harness(TorrentTask task) {
  return MaterialApp(
    theme: buildTubemateTheme(
      TestWidgetsFlutterBinding.ensureInitialized().rootElement!,
    ),
    home: Builder(
      builder: (context) => Scaffold(
        body: Center(
          child: TextButton(
            onPressed: () => showRemoveTorrentDialog(context, task: task),
            child: const Text('open'),
          ),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets(
    'shows a warning and asks about the original file for file source',
    (tester) async {
      final task = TorrentTask(
        id: 1,
        name: 'ubuntu.iso',
        source: TorrentSource.file('/tmp/downloads/ubuntu.torrent'),
      );

      await tester.pumpWidget(_harness(task));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Remove "ubuntu.iso"?'), findsOneWidget);
      // warning text
      expect(
        find.text('This removes the torrent from the active session.'),
        findsOneWidget,
      );
      // original .torrent file option is present for file sources
      expect(
        find.text('Also delete the original ubuntu.torrent file'),
        findsOneWidget,
      );
      expect(
        find.text('Also delete the downloaded data from disk'),
        findsOneWidget,
      );

      // tapping the original-file checkbox stays within the dialog; REMOVE dismisses it
      await tester.tap(
        find.text('Also delete the original ubuntu.torrent file'),
      );
      await tester.pump();
      expect(
        find.text('Also delete the original ubuntu.torrent file'),
        findsOneWidget,
      );

      await tester.tap(find.text('REMOVE'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Remove "ubuntu.iso"?'), findsNothing);
    },
  );

  testWidgets('magnet source does not show the original-file option', (
    tester,
  ) async {
    final task = TorrentTask(
      id: 2,
      name: 'movie',
      source: TorrentSource.magnet(
        'magnet:?xt=urn:btih:0123456789abcdef0123456789abcdef01234567',
      ),
    );

    await tester.pumpWidget(_harness(task));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Also delete the original'), findsNothing);
    expect(
      find.text('Also delete the downloaded data from disk'),
      findsOneWidget,
    );
  });
}
