import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ytdlapp/features/download/domain/download_controller.dart';
import 'package:ytdlapp/features/download/domain/download_task.dart';
import 'package:ytdlapp/features/download/ui/download_card.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});

  Widget harness(DownloadTask task, DownloadController controller) {
    return MaterialApp(
      home: Scaffold(
        body: DownloadCard(
          task: task,
          onRemove: () => controller.removeTask(task),
          onRetry: () => controller.retryTask(task),
          onPause: () => controller.pauseTask(task),
          onResume: () => controller.resumeTask(task),
        ),
      ),
    );
  }

  testWidgets('downloading task shows Pause + Cancel; tapping Pause pauses', (
    tester,
  ) async {
    final controller = DownloadController();
    final task = DownloadTask(
      id: 't1',
      url: 'http://x/y',
      status: DownloadStatus.downloading,
      progress: 0.4,
    );

    await tester.pumpWidget(harness(task, controller));
    await tester.pump();

    expect(find.byTooltip('Pause'), findsOneWidget);
    expect(find.byTooltip('Cancel'), findsOneWidget);

    await tester.tap(find.byTooltip('Pause'));
    await tester.pump();

    expect(task.pauseRequested, isTrue);
    // No process attached → status flips to paused immediately.
    expect(task.status, DownloadStatus.paused);
    expect(find.byTooltip('Resume'), findsOneWidget);
  });

  testWidgets('paused task shows Resume + Cancel; tapping Resume restarts', (
    tester,
  ) async {
    final controller = DownloadController();
    final task = DownloadTask(
      id: 't2',
      url: 'http://x/y',
      status: DownloadStatus.paused,
      progress: 0.4,
      savePath: '/tmp',
    );
    // no live process: resume must not throw and must flip to queued
    task.pauseRequested = true;

    await tester.pumpWidget(harness(task, controller));
    await tester.pump();

    expect(find.byTooltip('Resume'), findsOneWidget);
    expect(find.byTooltip('Remove'), findsOneWidget);
    expect(find.byTooltip('Pause'), findsNothing);

    await tester.tap(find.byTooltip('Resume'));
    await tester.pump();

    expect(task.pauseRequested, isFalse);
    expect(task.status, DownloadStatus.downloading);
    expect(find.byTooltip('Cancel'), findsOneWidget);
  });

  testWidgets('paused task can be removed', (tester) async {
    final controller = DownloadController();
    final task = DownloadTask(
      id: 't3',
      url: 'http://x/y',
      status: DownloadStatus.paused,
      progress: 0.4,
    );
    controller.tasks.add(task);

    await tester.pumpWidget(harness(task, controller));
    await tester.pump();

    await tester.tap(find.byTooltip('Remove'));
    await tester.pump();

    expect(controller.tasks, isEmpty);
  });
}
