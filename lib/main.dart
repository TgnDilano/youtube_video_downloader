import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';
import 'package:ytdlapp/features/settings/domain/settings_controller.dart';
import 'package:ytdlapp/core/theme/app_theme.dart';
import 'package:ytdlapp/features/shell/ui/home_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await _initWindow();
  // Apply the saved color scheme to TColors before the first frame renders so
  // the app never flashes the default amber palette on startup.
  final settings = SettingsController();
  await settings.ready;
  runApp(const TubemateApp());
}

Future<void> _initWindow() async {
  if (kIsWeb) return;
  if (defaultTargetPlatform != TargetPlatform.windows &&
      defaultTargetPlatform != TargetPlatform.macOS) {
    return;
  }

  await windowManager.ensureInitialized();

  const size = Size(1024, 740);
  final options = const WindowOptions(
    size: size,
    minimumSize: Size(800, 500),
    center: true,
    titleBarStyle: TitleBarStyle.hidden,
    windowButtonVisibility: false,
  );

  await windowManager.waitUntilReadyToShow(options, () async {
    await windowManager.setResizable(true);
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
    return ListenableBuilder(
      listenable: TColors.accentRevision,
      builder: (context, _) => MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'TubeXMate',
        theme: buildTubemateTheme(context),
        home: const TubemateClone(),
      ),
    );
  }
}
