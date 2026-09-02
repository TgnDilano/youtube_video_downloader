import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ytdlapp/features/schedule/domain/planned_download.dart';

/// Keeps the list of planned downloads, persists them to local preferences
/// and launches the ones whose time has come. Survives app restarts.
class ScheduleController extends ChangeNotifier {
  static const String _prefsKey = 'scheduled_downloads';

  final List<PlannedDownload> _planned = [];
  Future<void> get ready => _loadedFuture;
  late final Future<void> _loadedFuture = _load();

  List<PlannedDownload> get scheduled => List.unmodifiable(_planned);

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefsKey);
    if (raw != null && raw.isNotEmpty) {
      try {
        final decoded = jsonDecode(raw) as List;
        _planned
          ..clear()
          ..addAll(
            decoded.map(
              (e) => PlannedDownload.fromJson(e as Map<String, dynamic>),
            ),
          );
        _planned.sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));
      } catch (_) {
        // Corrupt store — start fresh.
      }
    }
    notifyListeners();
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _prefsKey,
      jsonEncode([for (final p in _planned) p.toJson()]),
    );
  }

  Future<PlannedDownload> schedule({
    required String url,
    required DateTime when,
    bool audioOnly = false,
    String resolution = 'best',
    bool isPlaylist = false,
    String? playlistItems,
    String? title,
  }) async {
    await _loadedFuture;
    final item = PlannedDownload(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      url: url,
      scheduledAt: when,
      audioOnly: audioOnly,
      resolution: resolution,
      isPlaylist: isPlaylist,
      playlistItems: playlistItems,
      title: title,
    );
    _planned.add(item);
    _planned.sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));
    await _persist();
    notifyListeners();
    return item;
  }

  Future<void> cancel(String id) async {
    await _loadedFuture;
    _planned.removeWhere((p) => p.id == id);
    await _persist();
    notifyListeners();
  }

  /// Removes every item whose time has passed and hands each to [enqueue],
  /// which is expected to start the actual download. Nothing happens until
  /// the store is loaded, so a fresh controller never wipes planned work.
  Future<List<PlannedDownload>> fireDue({
    required void Function(PlannedDownload planned) enqueue,
  }) async {
    await _loadedFuture;
    final now = DateTime.now();
    final due = _planned.where((p) => !p.scheduledAt.isAfter(now)).toList();
    if (due.isEmpty) return const [];
    _planned.removeWhere((p) => due.contains(p));
    await _persist();
    for (final p in due) {
      enqueue(p);
    }
    notifyListeners();
    return due;
  }
}
