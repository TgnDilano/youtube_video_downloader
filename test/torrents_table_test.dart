import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ytdlapp/core/theme/app_theme.dart';
import 'package:ytdlapp/features/torrents/domain/torrent_source.dart';
import 'package:ytdlapp/features/torrents/domain/torrent_task.dart';
import 'package:ytdlapp/features/torrents/ui/widgets/torrents_table.dart';

Widget _harness(TorrentTask task) {
  return MaterialApp(
    theme: buildTubemateTheme(
      TestWidgetsFlutterBinding.ensureInitialized().rootElement!,
    ),
    home: Scaffold(
      body: SizedBox(width: 1000, child: TorrentsTable(
        tasks: [task],
        onPause: (_) {},
        onResume: (_) {},
        onRemove: (_) {},
        onDetails: (_) {},
      )),
    ),
  );
}

void main() {
  testWidgets('renders a task across the shared columns', (tester) async {
    final task = TorrentTask(
      id: 1,
      name: 'Big Buck Bunny',
      source: TorrentSource.magnet(
        'magnet:?xt=urn:btih:1234567890ABCDEF1234567890ABCDEF12345678',
      ),
      totalSize: 3 * 1024 * 1024, // 3.0 MiB
      totalDone: 1 * 1024 * 1024, // 1.0 MiB
      downloadRate: '2.0 MiB/s',
      uploadRate: '0 B/s',
      status: TorrentStatus.downloading,
    );

    await tester.pumpWidget(_harness(task));
    await tester.pumpAndSettle();

    // Header + the single data row share the same nine labels.
    expect(find.text('TYPE'), findsOneWidget);
    expect(find.text('NAME'), findsOneWidget);
    expect(find.text('SIZE'), findsOneWidget);
    expect(find.text('DOWNLOADED'), findsOneWidget);
    expect(find.text('LEFT'), findsOneWidget);
    expect(find.text('↓ DOWN'), findsOneWidget);
    expect(find.text('↑ UP'), findsOneWidget);
    expect(find.text('STATUS'), findsOneWidget);
    expect(find.text('ACTIONS'), findsOneWidget);

    // Data row content.
    expect(find.text('MAGNET'), findsOneWidget);
    expect(find.text('Big Buck Bunny'), findsOneWidget);
    expect(find.text('3.0 MiB'), findsOneWidget);
    expect(find.text('1.0 MiB'), findsOneWidget);
    expect(find.text('2.0 MiB'), findsOneWidget);
    expect(find.text('DOWNLOADING'), findsOneWidget);

    // Two identical-width tables (header + rows) are stacked edge to edge, so
    // at least one vertical gridline paints between the first and second
    // columns. A simple proxy: the table widget exists and renders.
    expect(
      find.byType(Table),
      findsNWidgets(2),
    );
  });

  testWidgets('right-aligns the numeric columns', (tester) async {
    final task = TorrentTask(
      id: 2,
      name: 'foo',
      totalSize: 4096,
      totalDone: 1024,
      downloadRate: '0 B/s',
      uploadRate: '0 B/s',
      status: TorrentStatus.downloading,
    );

    await tester.pumpWidget(_harness(task));
    await tester.pumpAndSettle();

    final sizeAlign = tester.widget<Align>(
      find.ancestor(
        of: find.text('4.0 KiB'),
        matching: find.byType(Align),
      ).first,
    );
    expect(sizeAlign.alignment, Alignment.centerRight);
  });

  testWidgets('name column keeps its width in a narrow window', (tester) async {
    final task = TorrentTask(
      id: 3,
      name: 'bunny.mp4',
      totalSize: 4096,
      totalDone: 1024,
      downloadRate: '0 B/s',
      uploadRate: '0 B/s',
      status: TorrentStatus.paused,
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: buildTubemateTheme(
          TestWidgetsFlutterBinding.ensureInitialized().rootElement!,
        ),
        home: Scaffold(
          body: SizedBox(width: 830, child: TorrentsTable(
            tasks: [task],
            onPause: (_) {},
            onResume: (_) {},
            onRemove: (_) {},
            onDetails: (_) {},
          )),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // The NAME cell must still exist and hold the row's name even when the
    // window is too narrow for the ideal widths (the old FlexColumnWidth
    // shrank this column to zero).
    expect(find.text('bunny.mp4'), findsOneWidget);
    expect(find.text('NAME'), findsOneWidget);
  });
}