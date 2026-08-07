import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';
import 'package:ytdlapp/ui/app_theme.dart';
import 'package:ytdlapp/ui/home_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await _initWindow();
  runApp(const TubemateApp());
}

/// Frameless, fixed-size window on Windows, driven by window_manager.
Future<void> _initWindow() async {
  if (kIsWeb) return;
  if (defaultTargetPlatform != TargetPlatform.windows &&
      defaultTargetPlatform != TargetPlatform.macOS) {
    return;
  }

  await windowManager.ensureInitialized();

  const size = Size(1024, 640);
  final options = const WindowOptions(
    size: size,
    minimumSize: Size(800, 500),
    center: true,
    titleBarStyle: TitleBarStyle.hidden,
    windowButtonVisibility: false,
  );

  await windowManager.waitUntilReadyToShow(options, () async {
    await windowManager.setResizable(true); // <-- this was your bug
    await windowManager.setMaximizable(true);
    await windowManager.setMinimizable(true);

    if (defaultTargetPlatform == TargetPlatform.windows) {
      await windowManager.setAsFrameless();
    }

    await windowManager.show();
    await windowManager.focus();
  });
}

class TubemateApp extends StatelessWidget {
  const TubemateApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'TubeXMate',
      theme: buildTubemateTheme(context),
      home: const TubemateClone(),
    );
  }
}
