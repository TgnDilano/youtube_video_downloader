import 'dart:convert';

/// A serializable snapshot of a torrent task, persisted to disk so downloads
/// survive app restarts. Contains all fields the UI needs to display the
/// torrent's last-known state, plus the source info required to re-add it
/// to the engine on startup.
class PersistedTorrent {
  /// Unique key for this torrent (magnet btih hash, or file path).
  final String id;

  /// Raw magnet URI or `.torrent` file path.
  final String source;

  /// `'magnet'` or `'file'`.
  final String sourceType;

  /// The download destination folder.
  final String savePath;

  /// Human-readable torrent name (may be empty before metadata).
  final String name;

  /// Total torrent size in bytes (0 before metadata).
  final int totalSize;

  /// Bytes downloaded so far.
  final int totalDone;

  /// Bytes remaining (totalWanted − totalDone).
  final int totalLeft;

  /// Whether the torrent was paused when the app last closed.
  final bool isPaused;

  /// ISO 8601 timestamp of when this torrent was first added.
  final String addedAt;

  const PersistedTorrent({
    required this.id,
    required this.source,
    required this.sourceType,
    required this.savePath,
    this.name = '',
    this.totalSize = 0,
    this.totalDone = 0,
    this.totalLeft = 0,
    this.isPaused = false,
    required this.addedAt,
  });

  PersistedTorrent copyWith({
    String? name,
    int? totalSize,
    int? totalDone,
    int? totalLeft,
    bool? isPaused,
  }) {
    return PersistedTorrent(
      id: id,
      source: source,
      sourceType: sourceType,
      savePath: savePath,
      name: name ?? this.name,
      totalSize: totalSize ?? this.totalSize,
      totalDone: totalDone ?? this.totalDone,
      totalLeft: totalLeft ?? this.totalLeft,
      isPaused: isPaused ?? this.isPaused,
      addedAt: addedAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'source': source,
        'sourceType': sourceType,
        'savePath': savePath,
        'name': name,
        'totalSize': totalSize,
        'totalDone': totalDone,
        'totalLeft': totalLeft,
        'isPaused': isPaused,
        'addedAt': addedAt,
      };

  factory PersistedTorrent.fromJson(Map<String, dynamic> json) {
    return PersistedTorrent(
      id: json['id'] as String? ?? '',
      source: json['source'] as String? ?? '',
      sourceType: json['sourceType'] as String? ?? 'magnet',
      savePath: json['savePath'] as String? ?? '',
      name: json['name'] as String? ?? '',
      totalSize: json['totalSize'] as int? ?? 0,
      totalDone: json['totalDone'] as int? ?? 0,
      totalLeft: json['totalLeft'] as int? ?? 0,
      isPaused: json['isPaused'] as bool? ?? false,
      addedAt: json['addedAt'] as String? ?? '',
    );
  }

  /// Encodes a list of persisted torrents to a JSON string.
  static String encodeList(List<PersistedTorrent> torrents) {
    return jsonEncode(torrents.map((t) => t.toJson()).toList());
  }

  /// Decodes a JSON string into a list of persisted torrents.
  static List<PersistedTorrent> decodeList(String jsonStr) {
    try {
      final list = jsonDecode(jsonStr) as List;
      return list
          .map((e) => PersistedTorrent.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }
}
