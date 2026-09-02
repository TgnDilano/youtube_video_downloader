/// Plugin-free description of a single file inside a torrent, used by the
/// details dialog. Mirrors the plugin's `FileInfo` without importing it.
class TorrentFileInfo {
  final int index;
  final String name;
  final String path;
  final int size;

  const TorrentFileInfo({
    required this.index,
    required this.name,
    required this.path,
    required this.size,
  });
}
