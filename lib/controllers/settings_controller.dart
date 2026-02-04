import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsController extends ChangeNotifier {
  String _defaultResolution = 'best';
  String? _defaultDownloadPath;
  bool _isAutoPreviewEnabled = true;

  String get defaultResolution => _defaultResolution;
  String? get defaultDownloadPath => _defaultDownloadPath;
  bool get isAutoPreviewEnabled => _isAutoPreviewEnabled;

  SettingsController() {
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    _defaultResolution = prefs.getString('default_resolution') ?? 'best';
    _defaultDownloadPath = prefs.getString('default_download_path');
    _isAutoPreviewEnabled = prefs.getBool('auto_preview') ?? true;
    notifyListeners();
  }

  Future<void> setDefaultResolution(String resolution) async {
    _defaultResolution = resolution;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('default_resolution', resolution);
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
}
