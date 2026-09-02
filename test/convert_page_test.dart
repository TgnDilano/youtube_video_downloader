import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ytdlapp/features/convert/domain/convert_controller.dart';
import 'package:ytdlapp/main.dart';
import 'package:ytdlapp/features/convert/domain/convert_task.dart';
import 'package:ytdlapp/features/convert/ui/convert_page.dart';
import 'package:ytdlapp/core/widgets/tubemate_controls.dart' show RecordButton;

void main() {
  testWidgets('Convert tab renders and routes from sidebar', (tester) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const TubemateApp());
    await tester.pump();

    await tester.tap(find.text('CONVERT'));
    await tester.pumpAndSettle();

    expect(find.text('Convert'), findsOneWidget);
    expect(find.text('TARGET FORMAT'), findsOneWidget);
    expect(find.byType(RecordButton), findsOneWidget);
    expect(find.text('NO CONVERSIONS IN THIS LANE'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Convert button is inert until a source is selected', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: ConvertPage(controller: ConvertController())),
      ),
    );
    await tester.pump();

    await tester.tap(find.byType(RecordButton));
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  test('ConvertController blocks audio-to-video and reports errors', () async {
    final dir = await Directory.systemTemp.createTemp('convert_test');
    addTearDown(() => dir.delete(recursive: true));
    final audio = File('${dir.path}/song.mp3')..writeAsStringSync('fake');

    final controller = ConvertController();

    controller.addConversion(
      sourcePath: audio.path,
      outputDir: dir.path,
      targetId: 'mp4',
    );
    expect(controller.tasks.single.status, ConvertStatus.error);

    controller.addConversion(
      sourcePath: audio.path,
      outputDir: dir.path,
      targetId: 'flac',
    );
    final task = controller.tasks.first;
    await _waitForSettlement(task);
    expect(task.status, ConvertStatus.error);
    expect(task.outputPath, endsWith('song.flac'));

    controller.removeTask(task);
    expect(controller.tasks.length, 1);
  });

  test('canStreamCopy allows remux when codecs fit the container', () {
    bool copy(String target, {String? v, String? a}) =>
        ConvertController.canStreamCopy(
          target,
          hasVideo: v != null,
          videoCodec: v,
          hasAudio: a != null,
          audioCodec: a,
        );

    expect(copy('mp4', v: 'h264', a: 'aac'), isTrue);
    expect(copy('mp4', v: 'av1', a: 'opus'), isTrue);
    expect(copy('mp4', v: 'vp9', a: 'flac'), isTrue);
    expect(copy('mkv', v: 'h264', a: 'aac'), isTrue);
    expect(copy('mkv', v: 'hevc', a: 'flac'), isTrue);
    expect(copy('mov', v: 'h264', a: 'aac'), isTrue);
    expect(copy('webm', v: 'vp9', a: 'opus'), isTrue);
    expect(copy('avi', v: 'mpeg4', a: 'mp3'), isTrue);
    expect(copy('m4a', v: null, a: 'aac'), isTrue);
    expect(copy('mp3', v: null, a: 'mp3'), isTrue);
    expect(copy('flac', v: null, a: 'flac'), isTrue);
    expect(copy('ogg', v: null, a: 'vorbis'), isTrue);
    expect(copy('opus', v: null, a: 'opus'), isTrue);

    expect(copy('mp3', v: null, a: 'aac'), isFalse);
    expect(copy('webm', v: 'h264', a: 'aac'), isFalse);
    expect(copy('avi', v: 'h264', a: 'aac'), isFalse);
    expect(copy('mp4', v: null, a: 'aac'), isFalse);
    expect(copy('m4a', v: null, a: 'opus'), isFalse);
    expect(copy('mp4', v: 'mpeg2video', a: 'aac'), isFalse);
  });
}

Future<void> _waitForSettlement(ConvertTask task) async {
  for (var i = 0; i < 100; i++) {
    if (task.status == ConvertStatus.error ||
        task.status == ConvertStatus.completed) {
      return;
    }
    await Future.delayed(const Duration(milliseconds: 20));
  }
  fail('task did not settle');
}
