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

  /// Matches a magnet URI anywhere in the clipboard, up to the next
  /// whitespace (magnet URIs never contain spaces).
  static final RegExp _magnetPattern = RegExp(r'magnet:\S+');

  Timer? _timer;
  String? _lastSeen;
  String? _detectedUrl;
  String? _detectedMagnet;
  DateTime? _detectedAt;

  /// The most recently detected YouTube URL (reset by [acknowledge]).
  String? get detectedUrl => _detectedUrl;

  /// The most recently detected magnet URI (reset by [acknowledgeMagnet]).
  String? get detectedMagnet => _detectedMagnet;

  DateTime? get detectedAt => _detectedAt;
  bool get isRunning => _timer != null;

  static bool isYouTubeUrl(String text) {
    if (text.trim().isEmpty) return false;
    return _youtubeUrlPattern.hasMatch(text);
  }

  /// True when [text] contains a `magnet:` URI.
  static bool isMagnetLink(String text) {
    if (text.trim().isEmpty) return false;
    return extractMagnet(text) != null;
  }

  /// Returns the magnet URI embedded in [text], or null when there is none.
  static String? extractMagnet(String text) {
    final match = _magnetPattern.firstMatch(text.trim());
    return match?.group(0)?.trim();
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
    _detectedUrl = null;
    _detectedMagnet = null;

    // Magnets take priority; a magnet URI is self-contained, so surface it
    // as-is rather than treating it as arbitrary text.
    final magnet = extractMagnet(text);
    if (magnet != null) {
      _detectedMagnet = magnet;
      _detectedAt = DateTime.now();
      notifyListeners();
      return;
    }

    if (isYouTubeUrl(text)) {
      _detectedUrl = text;
      _detectedAt = DateTime.now();
      notifyListeners();
    }
  }

  /// Marks the current YouTube detection as handled so it isn't surfaced twice.
  void acknowledge(String url) {
    if (_detectedUrl == url) _detectedUrl = null;
  }

  /// Marks the current magnet detection as handled so it isn't surfaced twice.
  void acknowledgeMagnet(String magnet) {
    if (_detectedMagnet == magnet) _detectedMagnet = null;
  }

  @override
  void dispose() {
    stop();
    super.dispose();
  }
}
