import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ytdlapp/core/theme/app_theme.dart';
import 'package:ytdlapp/features/torrents/domain/torrent_file_info.dart';
import 'package:ytdlapp/features/torrents/domain/torrent_task.dart';
import 'package:ytdlapp/features/torrents/ui/widgets/torrent_details_dialog.dart';

Widget _harness(TorrentTask task, List<TorrentFileInfo> files) {
  return MaterialApp(
    theme: buildTubemateTheme(
      TestWidgetsFlutterBinding.ensureInitialized().rootElement!,
    ),
    home: Builder(
      builder: (context) => Scaffold(
        body: Center(
          child: TextButton(
            onPressed: () =>
                showTorrentDetailsDialog(context, task: task, files: files),
            child: const Text('open'),
          ),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('lists torrent files with their sizes and a total footer', (
    tester,
  ) async {
    final task = TorrentTask(
      id: 1,
      name: 'ubuntu.iso',
      totalSize: 3 * 1024 * 1024,
    );
    final files = [
      const TorrentFileInfo(
        index: 0,
        name: 'part1.bin',
        path: 'ubuntu/part1.bin',
        size: 1024 * 1024,
      ),
      const TorrentFileInfo(
        index: 1,
        name: 'part2.bin',
        path: 'ubuntu/part2.bin',
        size: 2 * 1024 * 1024,
      ),
    ];

    await tester.pumpWidget(_harness(task, files));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('ubuntu.iso'), findsOneWidget);
    expect(find.text('part1.bin'), findsOneWidget);
    expect(find.text('1.0 MiB'), findsOneWidget);
    expect(find.text('part2.bin'), findsOneWidget);
    expect(find.text('2.0 MiB'), findsOneWidget);
    // Footer total comes from the known torrent total size.
    expect(find.text('3.0 MiB'), findsOneWidget);
    expect(find.text('TOTAL'), findsOneWidget);
  });

  testWidgets('shows a placeholder message when there is no metadata yet', (
    tester,
  ) async {
    final task = TorrentTask(id: 2, name: 'unknown');
    await tester.pumpWidget(_harness(task, const []));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('Waiting for torrent metadata…'), findsOneWidget);
  });

  testWidgets('shows a dash when individual file sizes are unknown but total '
      'is known for multiple files', (tester) async {
    final task = TorrentTask(id: 3, name: 'bundle', totalSize: 8 * 1024 * 1024);
    final files = [
      const TorrentFileInfo(index: 0, name: 'a.bin', path: 'a.bin', size: 0),
      const TorrentFileInfo(index: 1, name: 'b.bin', path: 'b.bin', size: 0),
    ];

    await tester.pumpWidget(_harness(task, files));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('—'), findsNWidgets(2));
    // aggregate total still shown in the footer
    expect(find.text('8.0 MiB'), findsOneWidget);
  });
}
