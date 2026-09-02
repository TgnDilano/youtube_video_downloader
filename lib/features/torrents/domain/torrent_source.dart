/// The two ways a torrent can be introduced to the engine.
enum TorrentSourceKind { magnet, file }

/// A normalized torrent input, either a magnet URI or a path to a `.torrent`
/// file. The UI produces this; the engine consumes it.
class TorrentSource {
  /// Raw input as the user provided it.
  final String raw;

  /// What kind of source `raw` is.
  final TorrentSourceKind kind;

  const TorrentSource.magnet(String uri)
    : raw = uri,
      kind = TorrentSourceKind.magnet;

  const TorrentSource.file(String path)
    : raw = path,
      kind = TorrentSourceKind.file;

  /// Short human-readable label used in the UI (magnet hash or file name).
  String get label {
    if (kind == TorrentSourceKind.magnet) {
      final btih = RegExp(r'btih:([a-fA-F0-9]{40})').firstMatch(raw);
      if (btih != null) return 'magnet:${btih.group(1)!.toUpperCase()}';
      const prefix = 'magnet:';
      return raw.startsWith(prefix) && raw.length > prefix.length
          ? 'magnet:${raw.substring(prefix.length)}'
          : 'magnet link';
    }
    final parts = raw.split(RegExp(r'[/\\]'));
    final file = parts.isNotEmpty ? parts.last : raw;
    return 'file: $file';
  }
}
