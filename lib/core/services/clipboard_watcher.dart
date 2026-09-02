import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Polls the system clipboard and surfaces YouTube-style links the moment
/// they are copied. Desktop Flutter offers no clipboard event stream, so a
/// short poll is the standard approach.
class ClipboardWatcher extends ChangeNotifier {
  static final RegExp _youtubeUrlPattern = RegExp(
    r'https?://([a-z0-9-]+\.)?(youtube\.com|youtu\.be|youtube\.googleapis\.com)/\S+',
    caseSensitive: false,
  );

  Timer? _timer;
  String? _lastSeen;
  String? _detectedUrl;
  DateTime? _detectedAt;

  /// The most recently detected YouTube URL (reset by [acknowledge]).
  String? get detectedUrl => _detectedUrl;
  DateTime? get detectedAt => _detectedAt;
  bool get isRunning => _timer != null;

  static bool isYouTubeUrl(String text) {
    if (text.trim().isEmpty) return false;
    return _youtubeUrlPattern.hasMatch(text);
  }

  void start({Duration interval = const Duration(seconds: 2)}) {
    if (_timer != null) return;
    _timer = Timer.periodic(interval, (_) => _poll());
    _poll();
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  Future<void> _poll() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text?.trim() ?? '';
    if (text == _lastSeen) return;
    _lastSeen = text;
    if (!isYouTubeUrl(text)) return;
    _detectedUrl = text;
    _detectedAt = DateTime.now();
    notifyListeners();
  }

  /// Marks the current detection as handled so it isn't surfaced twice.
  void acknowledge(String url) {
    if (_detectedUrl == url) _detectedUrl = null;
  }

  @override
  void dispose() {
    stop();
    super.dispose();
  }
}
