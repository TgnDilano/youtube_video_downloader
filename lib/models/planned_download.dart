/// A download that should launch automatically at [scheduledAt].
/// Persisted so it survives restarts.
class PlannedDownload {
  final String id;
  final String url;
  final DateTime scheduledAt;
  final bool audioOnly;
  final String resolution;
  final bool isPlaylist;
  final String? playlistItems;
  final String? title;

  const PlannedDownload({
    required this.id,
    required this.url,
    required this.scheduledAt,
    this.audioOnly = false,
    this.resolution = 'best',
    this.isPlaylist = false,
    this.playlistItems,
    this.title,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'url': url,
      'scheduledAt': scheduledAt.toIso8601String(),
      'audioOnly': audioOnly,
      'resolution': resolution,
      'isPlaylist': isPlaylist,
      'playlistItems': playlistItems,
      'title': title,
    };
  }

  factory PlannedDownload.fromJson(Map<String, dynamic> json) {
    return PlannedDownload(
      id: json['id'] as String,
      url: json['url'] as String,
      scheduledAt: DateTime.parse(json['scheduledAt'] as String),
      audioOnly: json['audioOnly'] as bool? ?? false,
      resolution: json['resolution'] as String? ?? 'best',
      isPlaylist: json['isPlaylist'] as bool? ?? false,
      playlistItems: json['playlistItems'] as String?,
      title: json['title'] as String?,
    );
  }
}