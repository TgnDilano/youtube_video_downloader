import 'package:flutter/material.dart';

import 'package:ytdlapp/core/theme/app_theme.dart';
import 'package:ytdlapp/features/torrents/domain/torrent_source.dart';
import 'package:ytdlapp/features/torrents/domain/torrent_task.dart';

/// Tabular view of all torrent/magnet downloads: type, name, size,
/// downloaded, left, download/upload speed, and status. Each row carries
/// restart (on error), pause/resume, details, show-in-folder (when finished)
/// and remove actions.
class TorrentsTable extends StatelessWidget {
  final List<TorrentTask> tasks;
  final void Function(TorrentTask) onPause;
  final void Function(TorrentTask) onResume;
  final void Function(TorrentTask) onRemove;
  final void Function(TorrentTask) onDetails;
  final void Function(TorrentTask)? onRestart;
  final void Function(TorrentTask)? onShowInFolder;

  const TorrentsTable({
    super.key,
    required this.tasks,
    required this.onPause,
    required this.onResume,
    required this.onRemove,
    required this.onDetails,
    this.onRestart,
    this.onShowInFolder,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: TColors.panel2,
        border: Border.all(color: TColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _header(context),
          if (tasks.isEmpty)
            _empty(context)
          else
            Expanded(
              child: ListView.separated(
                padding: EdgeInsets.zero,
                itemCount: tasks.length,
                separatorBuilder: (_, _) => Container(
                      height: 1,
                      margin: const EdgeInsets.symmetric(horizontal: 16),
                      color: TColors.line,
                    ),
                itemBuilder: (context, index) => _row(context, tasks[index]),
              ),
            ),
        ],
      ),
    );
  }

  Widget _header(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: TColors.jackBg,
        border: Border(bottom: BorderSide(color: TColors.line)),
      ),
      child: const Row(
        children: [
          _Head(text: 'TYPE', width: 64),
          Expanded(child: _Head(text: 'NAME', width: double.infinity)),
          _Head(text: 'SIZE', width: 82),
          _Head(text: 'DOWNLOADED', width: 92),
          _Head(text: 'LEFT', width: 92),
          _Head(text: '↓ DOWN', width: 76),
          _Head(text: '↑ UP', width: 76),
          _Head(text: 'STATUS', width: 100),
          SizedBox(width: 138),
        ],
      ),
    );
  }

  Widget _row(BuildContext context, TorrentTask task) {
    final statusColor = _statusColor(task.status);
    final left = task.totalSize > task.totalDone
        ? task.totalSize - task.totalDone
        : 0;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          SizedBox(
            width: 64,
            child: Row(
              children: [
                Icon(
                  task.source?.kind == TorrentSourceKind.file
                      ? Icons.description_outlined
                      : Icons.link,
                  size: 13,
                  color: TColors.amber,
                ),
                const SizedBox(width: 6),
                Text(
                  task.source?.kind == TorrentSourceKind.file ? 'FILE' : 'MAGNET',
                  style: TText.mono(
                    context,
                    size: 9.5,
                    color: TColors.textDim,
                    weight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Text(
              task.status == TorrentStatus.error && task.errorMsg.isNotEmpty
                  ? task.errorMsg
                  : task.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TText.body(
                context,
                size: 12.5,
                weight: FontWeight.w500,
                color: task.status == TorrentStatus.error
                    ? TColors.red
                    : TColors.text,
              ),
            ),
          ),
          SizedBox(
            width: 82,
            child: _cell(context, task.totalSize > 0 ? _bytes(task.totalSize) : '—'),
          ),
          SizedBox(
            width: 92,
            child: _cell(context, _bytes(task.totalDone), accent: TColors.green),
          ),
          SizedBox(
            width: 92,
            child: _cell(context, task.totalSize > 0 ? _bytes(left) : '—'),
          ),
          SizedBox(
            width: 76,
            child: _cell(
              context,
              task.downloadRate,
              accent: task.downloadRate.isNotEmpty && task.downloadRate != '0 B/s'
                  ? TColors.green
                  : TColors.textDim,
            ),
          ),
          SizedBox(
            width: 76,
            child: _cell(
              context,
              task.uploadRate,
              accent: task.uploadRate.isNotEmpty && task.uploadRate != '0 B/s'
                  ? TColors.amber
                  : TColors.textDim,
            ),
          ),
          SizedBox(
            width: 100,
            child: Row(
              children: [
                task.status == TorrentStatus.fetchingMetadata
                    ? SizedBox(
                        width: 8,
                        height: 8,
                        child: CircularProgressIndicator(
                          strokeWidth: 1.5,
                          color: statusColor,
                        ),
                      )
                    : Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: statusColor,
                        ),
                      ),
                const SizedBox(width: 6),
                Text(
                  _statusLabel(task.status),
                  style: TText.mono(context, size: 9.5, color: statusColor),
                ),
              ],
            ),
          ),
          SizedBox(
            width: 138,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (task.status == TorrentStatus.error) ...[
                  if (onRestart != null)
                    _iconBtn(
                      context,
                      Icons.replay,
                      () => onRestart!(task),
                      danger: false,
                    ),
                  _iconBtn(
                    context,
                    Icons.delete_outline,
                    () => onRemove(task),
                    danger: true,
                  ),
                ] else if (task.id >= 0) ...[
                  _iconBtn(
                    context,
                    task.status == TorrentStatus.paused
                        ? Icons.play_arrow
                        : Icons.pause_outlined,
                    task.status == TorrentStatus.paused
                        ? () => onResume(task)
                        : () => onPause(task),
                  ),
                  _iconBtn(
                    context,
                    Icons.info_outline,
                    () => onDetails(task),
                  ),
                  if (task.isFinished && onShowInFolder != null)
                    _iconBtn(
                      context,
                      Icons.folder_open,
                      () => onShowInFolder!(task),
                    ),
                  _iconBtn(
                    context,
                    Icons.delete_outline,
                    () => onRemove(task),
                    danger: true,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _cell(BuildContext context, String text, {Color? accent}) {
    return Text(
      text,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TText.mono(
        context,
        size: 11,
        color: accent ?? TColors.text,
        weight: FontWeight.w600,
      ),
    );
  }

  Widget _iconBtn(BuildContext context, IconData icon, VoidCallback onTap,
      {bool danger = false}) {
    final color = danger ? TColors.red : TColors.textMuted;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 30,
        height: 30,
        margin: const EdgeInsets.only(left: 4),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: TColors.jackBg,
          border: Border.all(color: TColors.line),
        ),
        child: Icon(icon, size: 15, color: color),
      ),
    );
  }

  Widget _empty(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.bolt_outlined, size: 32, color: TColors.textDim),
            const SizedBox(height: 10),
            Text(
              'No downloads yet.',
              style: TText.body(context, size: 13.5, color: TColors.textMuted),
            ),
          ],
        ),
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

  static String _statusLabel(TorrentStatus status) {
    switch (status) {
      case TorrentStatus.downloading:
        return 'DOWNLOADING';
      case TorrentStatus.fetchingMetadata:
        return 'META…';
      case TorrentStatus.seeding:
        return 'SEEDING';
      case TorrentStatus.completed:
        return 'COMPLETED';
      case TorrentStatus.paused:
        return 'PAUSED';
      case TorrentStatus.error:
        return 'ERROR';
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

class _Head extends StatelessWidget {
  final String text;
  final double width;

  const _Head({required this.text, required this.width});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: Text(
        text,
        style: TText.mono(
          context,
          size: 9.5,
          letterSpacing: 0.1,
          color: TColors.textDim,
          weight: FontWeight.w600,
        ),
      ),
    );
  }
}