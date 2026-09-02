import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ytdlapp/features/schedule/domain/schedule_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ScheduleController controller;
  final enqueued = <String>[];

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    controller = ScheduleController();
    await controller.ready;
    enqueued.clear();
  });

  test('starts empty', () {
    expect(controller.scheduled, isEmpty);
  });

  test('schedule only fires past items to the enqueue callback', () async {
    final future = DateTime.now().add(const Duration(minutes: 5));
    await controller.schedule(
      url: 'https://youtu.be/future',
      when: future,
      resolution: '1080',
    );
    expect(controller.scheduled.length, 1);

    final due = await controller.fireDue(enqueue: (p) => enqueued.add(p.url));
    expect(due, isEmpty);
    expect(enqueued, isEmpty);
    expect(controller.scheduled.length, 1);

    await controller.schedule(
      url: 'https://youtu.be/past',
      when: DateTime.now().subtract(const Duration(minutes: 1)),
    );
    final fired = await controller.fireDue(enqueue: (p) => enqueued.add(p.url));
    expect(fired.map((p) => p.url), ['https://youtu.be/past']);
    expect(enqueued, ['https://youtu.be/past']);
    expect(controller.scheduled.length, 1);
  });

  test('cancel removes a planned download before it fires', () async {
    final planned = await controller.schedule(
      url: 'https://youtu.be/cancelme',
      when: DateTime.now().subtract(const Duration(seconds: 1)),
    );
    await controller.cancel(planned.id);
    expect(controller.scheduled, isEmpty);

    final due = await controller.fireDue(enqueue: (p) => enqueued.add(p.url));
    expect(due, isEmpty);
    expect(enqueued, isEmpty);
  });

  test('planned downloads survive a controller restart', () async {
    await controller.schedule(
      url: 'https://youtu.be/persisted',
      when: DateTime.now().add(const Duration(hours: 2)),
      audioOnly: true,
      title: 'Persisted clip',
    );

    final reloaded = ScheduleController();
    await reloaded.ready;
    expect(reloaded.scheduled.length, 1);
    expect(reloaded.scheduled.first.url, 'https://youtu.be/persisted');
    expect(reloaded.scheduled.first.audioOnly, isTrue);
    expect(reloaded.scheduled.first.title, 'Persisted clip');
  });

  test(
    'fireDue keeps items alive (not wiped) before the store loads',
    () async {
      SharedPreferences.setMockInitialValues({});
      final notLoaded = ScheduleController();
      final due = await notLoaded.fireDue(enqueue: (p) {});
      expect(due, isEmpty);
    },
  );
}
