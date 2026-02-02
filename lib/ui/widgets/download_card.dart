import 'package:flutter/material.dart';
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
        final cardContent = _buildCardContent();

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

  Widget _buildCardContent() {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          // Thumbnail
          if (!isChild)
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
                Text(
                  task.metadata,
                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                ),
                const SizedBox(height: 8),
                if (task.playlistProgress.isNotEmpty) ...[
                  Text(
                    task.playlistProgress,
                    style: const TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                  const SizedBox(height: 4),
                ],
                LinearProgressIndicator(
                  value: task.progress,
                  color: Colors.green,
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
      return const Chip(
        label: Text("Completed"),
        backgroundColor: Colors.green,
      );
    }
    if (task.status == DownloadStatus.error) {
      return const Chip(label: Text("Error"), backgroundColor: Colors.red);
    }
    return IconButton(
      icon: const Icon(Icons.close, color: Colors.red),
      onPressed: onRemove,
    );
  }
}
