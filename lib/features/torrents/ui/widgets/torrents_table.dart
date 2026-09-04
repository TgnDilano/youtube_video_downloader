import 'package:flutter/material.dart';

import 'package:ytdlapp/core/theme/app_theme.dart';
import 'package:ytdlapp/features/torrents/domain/torrent_source.dart';
import 'package:ytdlapp/features/torrents/domain/torrent_task.dart';

/// Fills whatever width is left over like [FlexColumnWidth], but never below
/// [min]. Without the floor a narrow window shrinks the flexible NAME column
/// to zero pixels (the native flex width has no minimum), which makes the
/// whole name cell disappear.
class _MinFillingColumnWidth extends TableColumnWidth {
  const _MinFillingColumnWidth({this.min = 120});

  final double min;

  @override
  double minIntrinsicWidth(Iterable<RenderBox> cells, double containerWidth) {
    return min;
  }

  @override
  double maxIntrinsicWidth(Iterable<RenderBox> cells, double containerWidth) {
    return min;
  }

  @override
  double flex(Iterable<RenderBox> cells) => 1.0;
}

/// Fixed column widths shared by the header and every data row. The NAME
/// column is flexible and absorbs whatever width is left over; every other
/// column is fixed so cells always fall into the same column.
const List<TableColumnWidth> _columns = [
  FixedColumnWidth(76), // TYPE
  _MinFillingColumnWidth(min: 120), // NAME
  FixedColumnWidth(88), // SIZE
  FixedColumnWidth(96), // DOWNLOADED
  FixedColumnWidth(88), // LEFT
  FixedColumnWidth(76), // DOWN
  FixedColumnWidth(76), // UP
  FixedColumnWidth(102), // STATUS
  FixedColumnWidth(164), // ACTIONS (up to 4 × 34px buttons + padding)
];

/// [Table] keys column widths by column index; [_columns] is the single source
/// of truth shared by the header and every data row.
final Map<int, TableColumnWidth> _columnWidths = {
  for (var i = 0; i < _columns.length; i++) i: _columns[i],
};

/// Gridline drawn between columns and between rows.
BorderSide _gridline() => BorderSide(color: TColors.line);

/// Tabular view of all torrent/magnet downloads: type, name, size,
/// downloaded, left, download/upload speed, and status. Runs as a real
/// `<table>`-style layout (see `_columns`) so header and rows share the same
/// column boundaries. Each row carries restart (on error), pause/resume,
/// details, show-in-folder (when finished) and remove actions.
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
              child: SingleChildScrollView(
                child: Table(
columnWidths: _columnWidths,
                  defaultVerticalAlignment: TableCellVerticalAlignment.middle,
                  border: TableBorder(
                    horizontalInside: _gridline(),
                    verticalInside: _gridline(),
                  ),
                  children: [
                    for (final task in tasks) _row(context, task),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _header(BuildContext context) {
    return Container(
      color: TColors.jackBg,
      child: Table(
        columnWidths: _columnWidths,
        defaultVerticalAlignment: TableCellVerticalAlignment.middle,
        border: TableBorder(
          bottom: _gridline(),
          verticalInside: _gridline(),
        ),
        children: [
          TableRow(
            children: [
              _headCell(context, 'TYPE'),
              _headCell(context, 'NAME'),
              _headCell(context, 'SIZE', right: true),
              _headCell(context, 'DOWNLOADED', right: true),
              _headCell(context, 'LEFT', right: true),
              _headCell(context, '↓ DOWN', right: true),
              _headCell(context, '↑ UP', right: true),
              _headCell(context, 'STATUS'),
              _headCell(context, 'ACTIONS', right: true),
            ],
          ),
        ],
      ),
    );
  }

  Widget _headCell(BuildContext context, String text, {bool right = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Align(
        alignment: right ? Alignment.centerRight : Alignment.centerLeft,
        child: Text(
          text,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TText.mono(
            context,
            size: 9.5,
            letterSpacing: 0.1,
            color: TColors.textDim,
            weight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  TableRow _row(BuildContext context, TorrentTask task) {
    final statusColor = _statusColor(task.status);
    final left = task.totalSize > task.totalDone
        ? task.totalSize - task.totalDone
        : 0;
    return TableRow(
      children: [
        _cell(
          context,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Row(
              mainAxisSize: MainAxisSize.min,
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
                  task.source?.kind == TorrentSourceKind.file
                      ? 'FILE'
                      : 'MAGNET',
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
        ),
        _cell(
          context,
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
        _cell(
          context,
          right: true,
          child: Text(
            task.totalSize > 0 ? _bytes(task.totalSize) : '—',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: _monoCell(context),
          ),
        ),
        _cell(
          context,
          right: true,
          child: Text(
            _bytes(task.totalDone),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: _monoCell(context, accent: TColors.green),
          ),
        ),
        _cell(
          context,
          right: true,
          child: Text(
            task.totalSize > 0 ? _bytes(left) : '—',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: _monoCell(context),
          ),
        ),
        _cell(
          context,
          right: true,
          child: Text(
            task.downloadRate,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: _monoCell(
              context,
              accent: task.downloadRate.isNotEmpty &&
                      task.downloadRate != '0 B/s'
                  ? TColors.green
                  : TColors.textDim,
            ),
          ),
        ),
        _cell(
          context,
          right: true,
          child: Text(
            task.uploadRate,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: _monoCell(
              context,
              accent: task.uploadRate.isNotEmpty &&
                      task.uploadRate != '0 B/s'
                  ? TColors.amber
                  : TColors.textDim,
            ),
          ),
        ),
        _cell(
          context,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Row(
              mainAxisSize: MainAxisSize.min,
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
        ),
        _cell(
          context,
          right: true,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          child: _actions(context, task),
        ),
      ],
    );
  }

  /// Padding + alignment wrapper every cell goes through. [right] pushes the
  /// content to the column's right edge (numbers) instead of the left.
  Widget _cell(
    BuildContext context, {
    required Widget child,
    EdgeInsets padding = const EdgeInsets.symmetric(
      horizontal: 14,
      vertical: 12,
    ),
    bool right = false,
  }) {
    return Padding(
      padding: padding,
      child: Align(
        alignment: right ? Alignment.centerRight : Alignment.centerLeft,
        child: child,
      ),
    );
  }

  TextStyle _monoCell(BuildContext context, {Color? accent}) {
    return TText.mono(
      context,
      size: 11,
      color: accent ?? TColors.text,
      weight: FontWeight.w600,
    );
  }

  Widget _actions(BuildContext context, TorrentTask task) {
    final List<Widget> buttons = [];
    if (task.status == TorrentStatus.error) {
      if (onRestart != null) {
        buttons.add(
          _iconBtn(context, Icons.replay, () => onRestart!(task), danger: false),
        );
      }
      buttons.add(
        _iconBtn(context, Icons.delete_outline, () => onRemove(task), danger: true),
      );
    } else if (task.id >= 0) {
      buttons.add(
        _iconBtn(
          context,
          task.status == TorrentStatus.paused
              ? Icons.play_arrow
              : Icons.pause_outlined,
          task.status == TorrentStatus.paused
              ? () => onResume(task)
              : () => onPause(task),
        ),
      );
      buttons.add(_iconBtn(context, Icons.info_outline, () => onDetails(task)));
      if (task.isFinished && onShowInFolder != null) {
        buttons.add(
          _iconBtn(
            context,
            Icons.folder_open,
            () => onShowInFolder!(task),
          ),
        );
      }
      buttons.add(
        _iconBtn(context, Icons.delete_outline, () => onRemove(task), danger: true),
      );
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.end,
      children: buttons,
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