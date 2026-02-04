import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:ytdlapp/models/download_task.dart';

class DownloadCard extends StatelessWidget {
  final DownloadTask task;
  final VoidCallback onRemove;
  final bool isChild;

  const DownloadCard({
    super.key,
    required this.task,
    required this.onRemove,
    this.isChild = false,
  });

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: task,
      builder: (context, _) {
        final cardContent = _buildCardContent(context);

        if (task.isPlaylist) {
          return Card(
            color: const Color(0xFF1E1E1E),
            margin: const EdgeInsets.only(bottom: 12),
            child: ExpansionTile(
              title: cardContent,
              children: task.children
                  .map(
                    (childTask) => DownloadCard(
                      task: childTask,
                      onRemove: () {
                        // Child removal can be complex, disable for now
                      },
                      isChild: true,
                    ),
                  )
                  .toList(),
            ),
          );
        } else {
          return Card(
            color: isChild ? const Color(0xFF282828) : const Color(0xFF1E1E1E),
            margin: isChild
                ? const EdgeInsets.fromLTRB(16, 0, 16, 8)
                : const EdgeInsets.only(bottom: 12),
            child: cardContent,
          );
        }
      },
    );
  }

  Widget _buildCardContent(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          // Thumbnail
          if (!isChild)
            Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: task.thumbnail.isNotEmpty
                      ? Image.network(
                          task.thumbnail,
                          width: 140,
                          height: 80,
                          fit: BoxFit.cover,
                        )
                      : Container(
                          width: 140,
                          height: 80,
                          color: Colors.black,
                          child: const Icon(Icons.movie),
                        ),
                ),
                if (task.thumbnail.isNotEmpty)
                  Positioned.fill(
                    child: Center(
                      child: IconButton(
                        icon: const Icon(
                          Icons.play_arrow,
                          color: Colors.white,
                          size: 40,
                        ),
                        onPressed: () => _launchUrl(task.url),
                      ),
                    ),
                  ),
              ],
            ),
          if (!isChild) const SizedBox(width: 16),

          // Details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  task.title,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Row(
                  children: [
                    Text(
                      task.metadata,
                      style: const TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                    if (task.resolution != "best") ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 1,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white10,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          task.resolution,
                          style: const TextStyle(
                            color: Colors.grey,
                            fontSize: 10,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 8),
                if (task.playlistProgress.isNotEmpty) ...[
                  Text(
                    task.playlistProgress,
                    style: const TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                  const SizedBox(height: 4),
                ],
                if (task.status == DownloadStatus.downloading) ...[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "${(task.progress * 100).toStringAsFixed(1)}%",
                        style: const TextStyle(
                          fontSize: 10,
                          color: Colors.green,
                        ),
                      ),
                      if (task.speed.isNotEmpty)
                        Text(
                          "${task.speed} • ETA ${task.eta}",
                          style: const TextStyle(
                            fontSize: 10,
                            color: Colors.grey,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                ],
                LinearProgressIndicator(
                  value: task.progress,
                  color: task.status == DownloadStatus.error
                      ? Colors.red
                      : Colors.green,
                  backgroundColor: Colors.white10,
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),

          // Status/Action
          if (!isChild) _buildTaskAction(),
        ],
      ),
    );
  }

  Widget _buildTaskAction() {
    if (task.status == DownloadStatus.completed) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.folder_open, color: Colors.blue),
            onPressed: () => _openFolder(task.savePath),
            tooltip: "Open folder",
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.red),
            onPressed: onRemove,
            tooltip: "Remove from history",
          ),
        ],
      );
    }
    if (task.status == DownloadStatus.error) {
      return IconButton(
        icon: const Icon(Icons.refresh, color: Colors.orange),
        onPressed: () {
          // Retry logic could be added here
        },
        tooltip: "Retry",
      );
    }
    return IconButton(
      icon: const Icon(Icons.close, color: Colors.red),
      onPressed: onRemove,
      tooltip: "Cancel",
    );
  }

  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (!await launchUrl(uri)) {
      throw Exception('Could not launch $url');
    }
  }

  Future<void> _openFolder(String? path) async {
    if (path == null) return;
    final uri = Uri.file(path);
    if (!await launchUrl(uri)) {
      // On some platforms file uri might fail, try opening the parent directory
    }
  }
}
