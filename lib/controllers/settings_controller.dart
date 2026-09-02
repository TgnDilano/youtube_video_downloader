import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ytdlapp/ui/app_theme.dart';

class SettingsController extends ChangeNotifier {
  String _defaultResolution = 'best';
  String? _defaultDownloadPath;
  bool _isAutoPreviewEnabled = true;
  bool _isClipboardMonitorEnabled = true;
  String _cookieBrowser = 'auto';
  String? _cookiesFile;
  String _themeId = kColorSchemes.first.id;
  Color _customMain = kDefaultMain;
  Color _customPrimary = kColorSchemes.first.primary;
  Color _customSecondary = kColorSchemes.first.secondary;

  static const List<String> cookieBrowserValues = [
    'auto',
    'chrome',
    'edge',
    'brave',
    'firefox',
    'none',
  ];

  String get defaultResolution => _defaultResolution;
  String? get defaultDownloadPath => _defaultDownloadPath;
  bool get isAutoPreviewEnabled => _isAutoPreviewEnabled;
  bool get isClipboardMonitorEnabled => _isClipboardMonitorEnabled;
  String get cookieBrowser => _cookieBrowser;
  String? get cookiesFile => _cookiesFile;
  String get themeId => _themeId;

  /// The three effective colors driving the UI right now (preset or custom).
  TColorScheme get currentScheme {
    final preset = colorSchemeById(_themeId);
    if (preset != null) return preset;
    return TColorScheme.custom(
      main: _customMain,
      primary: _customPrimary,
      secondary: _customSecondary,
    );
  }

  Color get effectiveMain => currentScheme.main;
  Color get effectivePrimary => currentScheme.primary;
  Color get effectiveSecondary => currentScheme.secondary;

  /// Resolves once [SharedPreferences] have been read and the saved color
  /// scheme has been applied to [TColors]. Awaiting it before [runApp] avoids
  /// the startup flash of the default palette.
  late final Future<void> ready;

  SettingsController() {
    ready = _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    _defaultResolution = prefs.getString('default_resolution') ?? 'best';
    _defaultDownloadPath = prefs.getString('default_download_path');

    if (_defaultDownloadPath == null) {
      try {
        final directory = await getDownloadsDirectory();
        _defaultDownloadPath = directory?.path;
      } catch (e) {
        debugPrint("Could not fetch downloads directory: $e");
      }
    }

    _isAutoPreviewEnabled = prefs.getBool('auto_preview') ?? true;
    _isClipboardMonitorEnabled = prefs.getBool('clipboard_monitor') ?? true;
    _cookieBrowser =
        prefs.getString('cookie_browser') ?? cookieBrowserValues.first;
    _cookiesFile = prefs.getString('cookies_file');
    _themeId = prefs.getString('accent_scheme') ?? kColorSchemes.first.id;

    final main = prefs.getInt('custom_main');
    final primary = prefs.getInt('custom_primary');
    final secondary = prefs.getInt('custom_secondary');
    if (main != null) _customMain = Color(main);
    if (primary != null) _customPrimary = Color(primary);
    if (secondary != null) _customSecondary = Color(secondary);

    _applyThemeToColors();
    notifyListeners();
  }

  Future<void> setTheme(String id) async {
    final scheme = colorSchemeById(id) ?? kColorSchemes.first;
    _themeId = scheme.id;
    _applyThemeToColors();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('accent_scheme', scheme.id);
    notifyListeners();
  }

  Future<void> setCustomMain(Color c) => _setCustomColor(
        apply: () => _customMain = c,
        storeKey: 'custom_main',
        color: c,
      );

  Future<void> setCustomPrimary(Color c) => _setCustomColor(
        apply: () => _customPrimary = c,
        storeKey: 'custom_primary',
        color: c,
      );

  Future<void> setCustomSecondary(Color c) => _setCustomColor(
        apply: () => _customSecondary = c,
        storeKey: 'custom_secondary',
        color: c,
      );

  Future<void> _setCustomColor({
    required void Function() apply,
    required String storeKey,
    required Color color,
  }) async {
    apply();
    _themeId = 'custom';
    _applyThemeToColors();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('accent_scheme', 'custom');
    await prefs.setInt(storeKey, color.toARGB32());
    notifyListeners();
  }

  void _applyThemeToColors() {
    TColors.applyScheme(currentScheme);
  }

  Future<void> setDefaultResolution(String resolution) async {
    _defaultResolution = resolution;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('default_resolution', resolution);
    notifyListeners();
  }

  Future<void> setCookieBrowser(String value) async {
    if (!cookieBrowserValues.contains(value)) return;
    _cookieBrowser = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('cookie_browser', value);
    notifyListeners();
  }

  Future<void> setCookiesFile(String? path) async {
    _cookiesFile = path;
    final prefs = await SharedPreferences.getInstance();
    if (path != null && path.isNotEmpty) {
      await prefs.setString('cookies_file', path);
    } else {
      await prefs.remove('cookies_file');
    }
    notifyListeners();
  }

  Future<void> setDefaultDownloadPath(String? path) async {
    _defaultDownloadPath = path;
    final prefs = await SharedPreferences.getInstance();
    if (path != null) {
      await prefs.setString('default_download_path', path);
    } else {
      await prefs.remove('default_download_path');
    }
    notifyListeners();
  }

  Future<void> setAutoPreview(bool enabled) async {
    _isAutoPreviewEnabled = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('auto_preview', enabled);
    notifyListeners();
  }

  Future<void> setClipboardMonitor(bool enabled) async {
    _isClipboardMonitorEnabled = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('clipboard_monitor', enabled);
    notifyListeners();
  }
}
