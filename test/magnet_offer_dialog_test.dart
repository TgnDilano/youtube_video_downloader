import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ytdlapp/core/theme/app_theme.dart';
import 'package:ytdlapp/features/torrents/ui/magnet_offer_dialog.dart';

const _magnet =
    'magnet:?xt=urn:btih:1234567890ABCDEF1234567890ABCDEF12345678'
    '&dn=Big+Buck+Bunny&tr=udp%3A%2F%2Ftracker.opentrackr.org%3A1337';

Widget _harness(String? initialPath) {
  return MaterialApp(
    theme: buildTubemateTheme(
      TestWidgetsFlutterBinding.ensureInitialized().rootElement!,
    ),
    home: Builder(
      builder: (context) => Scaffold(
        body: Center(
          child: TextButton(
            onPressed: () => showMagnetOfferDialog(
              context,
              magnet: _magnet,
              initialPath: initialPath,
            ),
            child: const Text('open'),
          ),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('shows the magnet and a copy of the btih label', (tester) async {
    await tester.pumpWidget(_harness('/tmp/downloads'));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('Magnet link detected'), findsOneWidget);
    expect(find.textContaining('MAGNET:1234567890ABCDEF'), findsOneWidget);
    expect(find.text(_magnet), findsOneWidget);
    expect(find.text('/tmp/downloads'), findsOneWidget);
    expect(find.text('DOWNLOAD'), findsOneWidget);
    expect(find.text('TORRENTS'), findsOneWidget);
  });

  testWidgets('download stays disabled until a save path exists', (
    tester,
  ) async {
    await tester.pumpWidget(_harness(null));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('No download folder selected'), findsOneWidget);
    expect(find.text('DOWNLOAD'), findsOneWidget);
  });

  testWidgets('TORRENTS button pops with the action and no path', (tester) async {
    await tester.pumpWidget(_harness('/tmp/downloads'));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('TORRENTS'));
    await tester.pumpAndSettle();

    expect(
      find.text('Magnet link detected'),
      findsNothing,
    );
  });
}