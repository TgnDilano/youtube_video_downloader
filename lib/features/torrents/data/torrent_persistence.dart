import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import 'package:ytdlapp/features/torrents/domain/persisted_torrent.dart';

/// Handles reading and writing the persisted torrent list to a JSON file
/// in the app's documents directory. All operations are async and best-effort;
/// a corrupt or missing file is treated as an empty list.
class TorrentPersistence {
  static const _fileName = 'torrents.json';

  File? _file;

  /// Resolves the JSON file, creating the documents directory if needed.
  Future<File> _getFile() async {
    if (_file != null) return _file!;
    final dir = await getApplicationDocumentsDirectory();
    _file = File('${dir.path}/$_fileName');
    return _file!;
  }

  /// Loads the persisted torrent list from disk. Returns an empty list on
  /// any error (file missing, corrupt JSON, etc.).
  Future<List<PersistedTorrent>> load() async {
    try {
      final file = await _getFile();
      debugPrint('[TorrentPersistence] loading from ${file.path}');
      if (!await file.exists()) {
        debugPrint('[TorrentPersistence] file does not exist');
        return [];
      }
      final content = await file.readAsString();
      if (content.trim().isEmpty) return [];
      final list = PersistedTorrent.decodeList(content);
      debugPrint('[TorrentPersistence] loaded ${list.length} torrents');
      return list;
    } catch (e) {
      debugPrint('TorrentPersistence.load error: $e');
      return [];
    }
  }

  /// Persists the full torrent list to disk. Replaces the entire file.
  Future<void> save(List<PersistedTorrent> torrents) async {
    try {
      final file = await _getFile();
      final json = PersistedTorrent.encodeList(torrents);
      await file.writeAsString(json);
      debugPrint('[TorrentPersistence] saved ${torrents.length} torrents to ${file.path}');
    } catch (e) {
      debugPrint('TorrentPersistence.save error: $e');
    }
  }

  /// Deletes the persistence file from disk.
  Future<void> clear() async {
    try {
      final file = await _getFile();
      if (await file.exists()) await file.delete();
    } catch (_) {}
  }
}
