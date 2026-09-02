/// Result of the playlist pre-queue options dialog.
class PlaylistOptions {
  final bool fullPlaylist;
  final Set<int> selectedItems;
  final String resolution;
  final bool audioOnly;

  const PlaylistOptions({
    required this.fullPlaylist,
    required this.selectedItems,
    required this.resolution,
    required this.audioOnly,
  });
}
