import 'package:flutter/material.dart';

import 'package:ytdlapp/core/theme/app_theme.dart';
import 'package:ytdlapp/features/torrents/domain/torrent_task.dart';

/// Cassette-style card for a single torrent: name, progress bar, DL/UL
/// speeds, peers, and pause/resume/remove actions.
class TorrentCard extends StatelessWidget {
  final TorrentTask task;
  final VoidCallback onPause;
  final VoidCallback onResume;
  final VoidCallback onRemove;
  final VoidCallback onDetails;
  final VoidCallback? onShowInFolder;

  const TorrentCard({
    super.key,
    required this.task,
    required this.onPause,
    required this.onResume,
    required this.onRemove,
    required this.onDetails,
    this.onShowInFolder,
  });

  @override
  Widget build(BuildContext context) {
    final statusColor = _statusColor(task.status);
    final pct = (task.progress * 100).clamp(0, 100).toInt();
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: TColors.panel2,
        border: Border.all(color: TColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: statusColor,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  task.name,
                  overflow: TextOverflow.ellipsis,
                  style: TText.body(context, size: 14, weight: FontWeight.w600),
                ),
              ),
              _label(context, task.status.name.toUpperCase(), statusColor),
            ],
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(
              value: task.progress.clamp(0.0, 1.0),
              minHeight: 6,
              backgroundColor: TColors.counterBg,
              valueColor: AlwaysStoppedAnimation<Color>(statusColor),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _metric(context, '$pct%', 'DONE'),
              const SizedBox(width: 16),
              _metric(
                context,
                _bytes(task.totalDone),
                task.totalSize > 0 ? 'OF ${_bytes(task.totalSize)}' : 'SIZE …',
              ),
              if (task.eta.isNotEmpty) ...[
                const SizedBox(width: 16),
                _metric(context, task.eta, 'ETA'),
              ],
              const Spacer(),
              _metric(context, task.downloadRate, '↓ DL'),
              const SizedBox(width: 16),
              _metric(context, task.uploadRate, '↑ UL'),
              const SizedBox(width: 16),
              _metric(context, '${task.numPeers} / ${task.numSeeds}', 'P/S'),
            ],
          ),
          const SizedBox(height: 12),
          if (task.errorMsg.isNotEmpty) ...[
            Text(
              task.errorMsg,
              style: TText.mono(context, size: 10.5, color: TColors.red),
            ),
            const SizedBox(height: 8),
          ],
          Row(
            children: [
              if (task.status == TorrentStatus.paused)
                _action(context, Icons.play_arrow, 'RESUME', onResume)
              else
                _action(context, Icons.pause, 'PAUSE', onPause),
              const SizedBox(width: 16),
              _action(
                context,
                Icons.info_outline,
                'DETAILS',
                onDetails,
                dim: true,
              ),
              if (task.isFinished && onShowInFolder != null) ...[
                const SizedBox(width: 16),
                _action(
                  context,
                  Icons.folder_open,
                  'SHOW IN FOLDER',
                  onShowInFolder!,
                  dim: true,
                ),
              ],
              const Spacer(),
              _action(
                context,
                Icons.delete_outline,
                'REMOVE',
                onRemove,
                danger: true,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _label(BuildContext context, String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(text, style: TText.mono(context, size: 9.5, color: color)),
    );
  }

  Widget _metric(BuildContext context, String value, String caption) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: TText.mono(context, size: 12, weight: FontWeight.w600),
        ),
        Text(
          caption,
          style: TText.mono(context, size: 8.5, color: TColors.textDim),
        ),
      ],
    );
  }

  Widget _action(
    BuildContext context,
    IconData icon,
    String label,
    VoidCallback onTap, {
    bool danger = false,
    bool dim = false,
  }) {
    final color = danger
        ? TColors.red
        : dim
        ? TColors.textMuted
        : TColors.amber;
    return GestureDetector(
      onTap: onTap,
      child: Row(
        children: [
          Icon(icon, size: 15, color: color),
          const SizedBox(width: 6),
          Text(label, style: TText.mono(context, size: 10.5, color: color)),
        ],
      ),
    );
  }

  static Color _statusColor(TorrentStatus status) {
    switch (status) {
      case TorrentStatus.downloading:
      case TorrentStatus.fetchingMetadata:
        return TColors.amber;
      case TorrentStatus.seeding:
      case TorrentStatus.completed:
        return TColors.green;
      case TorrentStatus.paused:
        return TColors.textMuted;
      case TorrentStatus.error:
        return TColors.red;
    }
  }

  static String _bytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KiB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MiB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GiB';
  }
}
