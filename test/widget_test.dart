import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ytdlapp/main.dart';

void main() {
  testWidgets('Tubemate renders home without layout errors', (tester) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const TubemateApp());
    await tester.pump();

    expect(find.text('Tubemate'), findsOneWidget);
    expect(find.text('HOME'), findsOneWidget);
    expect(find.text('SETTINGS'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Settings tab renders without layout errors', (tester) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const TubemateApp());
    await tester.pump();

    await tester.tap(find.text('SETTINGS'));
    await tester.pumpAndSettle();

    expect(find.text('Default resolution'), findsOneWidget);
    expect(find.text('Auto-fetch preview'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
