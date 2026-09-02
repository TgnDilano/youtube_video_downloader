import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ytdlapp/features/download/domain/download_controller.dart';
import 'package:ytdlapp/features/download/domain/playlist_options.dart';
import 'package:ytdlapp/main.dart';
import 'package:ytdlapp/features/download/ui/playlist_options_dialog.dart';

void main() {
  testWidgets('URL field is focused on launch', (tester) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const TubemateApp());
    await tester.pump();

    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.focusNode?.hasFocus, isTrue);
  });

  testWidgets('Close button asks for confirmation before exiting',
      (tester) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const TubemateApp());
    await tester.pump();

    await tester.tap(find.byTooltip('Close'));
    await tester.pumpAndSettle();

    expect(find.text('Close TubeXMate?'), findsOneWidget);

    await tester.tap(find.text('CANCEL'));
    await tester.pumpAndSettle();
    expect(find.text('Close TubeXMate?'), findsNothing);

    await tester.tap(find.byTooltip('Close'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('EXIT'));
    await tester.pumpAndSettle();

    expect(find.text('Close TubeXMate?'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Playlist options dialog renders and returns selection',
      (tester) async {
    final controller = DownloadController();
    PlaylistOptions? result;

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Center(
            child: TextButton(
              onPressed: () async {
                result = await showDialog<PlaylistOptions>(
                  context: context,
                  builder: (_) => PlaylistOptionsDialog(
                    controller: controller,
                    url: 'https://example.com/playlist',
                    title: 'Test Playlist',
                    thumbnailUrl: '',
                    entries: [
                      {'title': 'Item One', 'duration': 120},
                      {'title': 'Item Two', 'duration': 300},
                    ],
                    initialFullPlaylist: true,
                    initialSelection: {1, 2},
                    initialResolution: 'best',
                    initialAudioOnly: false,
                  ),
                );
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('MEDIA TRANSPORT / PLAYLIST OPTIONS'), findsOneWidget);
    expect(find.text('PLAYLIST · 02 ITEMS'), findsOneWidget);

    await tester.tap(find.text('FULL PLAYLIST'));
    await tester.pumpAndSettle();
    expect(find.text('Item One'), findsOneWidget);
    expect(find.text('Item Two'), findsOneWidget);

    await tester.tap(find.text('Item One'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('QUEUE ITEMS'));
    await tester.pumpAndSettle();

    expect(result, isNotNull);
    expect(result!.fullPlaylist, isFalse);
    expect(result!.selectedItems, {2});
  });
}
