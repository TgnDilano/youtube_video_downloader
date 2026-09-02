import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:ytdlapp/core/theme/app_theme.dart';
import 'package:ytdlapp/core/widgets/vu_meter.dart';
import 'package:ytdlapp/features/download/domain/download_task.dart';

/// Queue item styled after the cassette-reel design:
/// spinning reel, mono meta, VU meter, timecode.
class DownloadCard extends StatefulWidget {
  final DownloadTask task;
  final VoidCallback onRemove;
  final VoidCallback? onRetry;
  final VoidCallback? onPause;
  final VoidCallback? onResume;
  final bool isChild;

  const DownloadCard({
    super.key,
    required this.task,
    required this.onRemove,
    this.onRetry,
    this.onPause,
    this.onResume,
    this.isChild = false,
  });

  @override
  State<DownloadCard> createState() => _DownloadCardState();
}

class _DownloadCardState extends State<DownloadCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _spinController;

  DownloadTask get task => widget.task;

  @override
  void initState() {
    super.initState();
    final seed = (task.id.hashCode % 10).abs();
    _spinController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 3000 + seed * 250),
    );
    task.addListener(_onTaskChanged);
    _syncAnimation();
  }

  void _onTaskChanged() {
    if (!mounted) return;
    _syncAnimation();
  }

  void _syncAnimation() {
    if (task.status == DownloadStatus.downloading) {
      if (!_spinController.isAnimating) _spinController.repeat();
    } else {
      _spinController.stop();
      _spinController.value = 0;
    }
  }

  @override
  void dispose() {
    task.removeListener(_onTaskChanged);
    _spinController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: task,
      builder: (context, _) {
        final content = _buildRow(context);
        if (task.isPlaylist) {
          return Container(
            decoration: BoxDecoration(
              color: TColors.panel2,
              border: Border.all(color: TColors.line),
            ),
            child: Theme(
              data: Theme.of(context).copyWith(
                dividerColor: TColors.lineSoft,
              ),
              child: ExpansionTile(
                initiallyExpanded: true,
                tilePadding: const EdgeInsets.symmetric(horizontal: 18),
                childrenPadding: const EdgeInsets.fromLTRB(18, 0, 18, 14),
                iconColor: TColors.textDim,
                collapsedIconColor: TColors.textDim,
                shape: const Border(),
                collapsedShape: const Border(),
                title: content,
                children: task.children
                    .map(
                      (childTask) => Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: DownloadCard(
                          task: childTask,
                          onRemove: widget.onRemove,
                          onRetry: widget.onRetry,
                          onPause: widget.onPause,
                          onResume: widget.onResume,
                          isChild: true,
                        ),
                      ),
                    )
                    .toList(),
              ),
            ),
          );
        }
        return Container(
          decoration: BoxDecoration(
            color: TColors.panel2,
            border: Border.all(color: TColors.line),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            child: content,
          ),
        );
      },
    );
  }

  Widget _buildRow(BuildContext context) {
    return Row(
      children: [
        _StatusIndicator(
          task: task,
          spin: _spinController,
          size: widget.isChild ? 24 : 34,
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                task.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TText.body(context, size: 13.5),
              ),
              const SizedBox(height: 3),
              Text(
                _metaLine(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TText.mono(context, size: 10.5, color: TColors.textDim),
              ),
            ],
          ),
        ),
        const SizedBox(width: 16),
        if (!widget.isChild) ...[
          VuMeter(progress: task.progress),
          const SizedBox(width: 16),
        ],
        if (widget.isChild)
          Text(
            _timecode(),
            style: TText.mono(context, size: 11, color: TColors.textMuted),
          )
        else
          _buildActions(context),
      ],
    );
  }

  String _metaLine() {
    if (task.isPlaylist) {
      final base =
          'Playlist · ${task.children.isEmpty ? '…' : task.children.length.toString()} items';
      if (task.playlistProgress.isNotEmpty) {
        return '${task.playlistProgress} · $base';
      }
      return base;
    }
    final res = task.audioOnly
        ? 'Audio'
        : task.resolution == 'best'
            ? 'Best'
            : '${task.resolution}p';
    final fmt = task.audioOnly ? 'MP3' : 'MP4';
    final pct = switch (task.status) {
      DownloadStatus.completed => 'Done',
      DownloadStatus.error => 'Failed',
      DownloadStatus.paused =>
        'Paused · ${(task.progress * 100).clamp(0, 100).round()}%',
      DownloadStatus.downloading =>
        '${(task.progress * 100).clamp(0, 100).round()}%',
      DownloadStatus.queued => 'Queued',
    };
    final size = task.fileSize.isNotEmpty ? ' · ${task.fileSize}' : '';
    return '$res · $fmt · $pct$size';
  }

  String _timecode() {
    if (task.status == DownloadStatus.downloading ||
        task.status == DownloadStatus.paused) {
      if (task.downloadedSize.isNotEmpty && task.fileSize.isNotEmpty) {
        return '${task.downloadedSize} / ${task.fileSize}';
      }
      if (task.eta.isNotEmpty) return 'ETA ${task.eta}';
      return '${(task.progress * 100).toStringAsFixed(1)}%';
    }
    if (task.fileSize.isNotEmpty) return task.fileSize;
    final t = task.timestamp;
    final hh = t.hour.toString().padLeft(2, '0');
    final mm = t.minute.toString().padLeft(2, '0');
    return '$hh:$mm';
  }

  Widget _buildActions(BuildContext context) {
    final (icon, onTap, tooltip, color) = switch (task.status) {
      DownloadStatus.completed => (
          Icons.folder_open,
          () => _openFolder(task.savePath),
          'Open folder',
          TColors.textMuted,
        ),
      DownloadStatus.error => (
          Icons.refresh,
          widget.onRetry,
          'Retry',
          TColors.amber,
        ),
      DownloadStatus.paused => (
          Icons.close,
          widget.onRemove,
          'Remove',
          TColors.red,
        ),
      _ => (
          Icons.close,
          widget.onRemove,
          'Cancel',
          TColors.red,
        ),
    };

    final actions = <Widget>[
      if (task.status == DownloadStatus.downloading &&
          widget.onPause != null)
        _ActionButton(
          icon: Icons.pause,
          color: TColors.amber,
          tooltip: 'Pause',
          onTap: widget.onPause,
        ),
      if (task.status == DownloadStatus.paused && widget.onResume != null)
        _ActionButton(
          icon: Icons.play_arrow,
          color: TColors.green,
          tooltip: 'Resume',
          onTap: widget.onResume,
        ),
      _ActionButton(
        icon: icon,
        color: color,
        tooltip: tooltip,
        onTap: onTap,
      ),
    ];
    if (task.status == DownloadStatus.completed) {
      actions.insert(
        0,
        _ActionButton(
          icon: Icons.delete_outline,
          color: TColors.red,
          tooltip: 'Remove from history',
          onTap: widget.onRemove,
        ),
      );
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: actions,
    );
  }

  Future<void> _openFolder(String? path) async {
    if (path == null) return;
    final uri = Uri.file(path);
    await launchUrl(uri);
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String tooltip;
  final VoidCallback? onTap;

  const _ActionButton({
    required this.icon,
    required this.color,
    required this.tooltip,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onTap,
      icon: Icon(icon, size: 16, color: color),
      iconSize: 16,
      visualDensity: VisualDensity.compact,
      tooltip: tooltip,
    );
  }
}

/// Status glyph: spinning reel while downloading, check/dot otherwise.
class _StatusIndicator extends StatelessWidget {
  final DownloadTask task;
  final Animation<double> spin;
  final double size;

  const _StatusIndicator({
    required this.task,
    required this.spin,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    final child = switch (task.status) {
      DownloadStatus.completed =>
        Icon(Icons.check, size: size * 0.45, color: TColors.green),
      DownloadStatus.error =>
        Icon(Icons.close, size: size * 0.45, color: TColors.red),
      DownloadStatus.paused =>
        Icon(Icons.pause, size: size * 0.45, color: TColors.textMuted),
      DownloadStatus.queued => _Reel(radius: size / 2, color: TColors.textDim),
      DownloadStatus.downloading => RotationTransition(
          turns: spin,
          child: _Reel(radius: size / 2, color: TColors.amber),
        ),
    };
    final isReel = task.status == DownloadStatus.downloading ||
        task.status == DownloadStatus.queued;
    return SizedBox(
      width: size,
      height: size,
      child: Center(
        child: isReel
            ? child
            : Container(
                width: size,
                height: size,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: switch (task.status) {
                      DownloadStatus.completed => TColors.green,
                      DownloadStatus.paused => TColors.textMuted,
                      _ => TColors.red,
                    },
                    width: 2,
                  ),
                ),
                child: Center(child: child),
              ),
      ),
    );
  }
}

class _Reel extends StatelessWidget {
  final double radius;
  final Color color;

  const _Reel({required this.radius, required this.color});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size.square(radius * 2),
      painter: _ReelPainter(radius: radius, color: color),
    );
  }
}

class _ReelPainter extends CustomPainter {
  final double radius;
  final Color color;

  _ReelPainter({required this.radius, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final ring = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawCircle(center, radius, ring);

    final dot = Paint()..color = color;
    const dotR = 2.0;
    canvas.drawCircle(
      Offset(center.dx, center.dy - radius + 4),
      dotR,
      dot,
    );
    canvas.drawCircle(
      Offset(center.dx, center.dy + radius - 4),
      dotR,
      dot,
    );
  }

  @override
  bool shouldRepaint(covariant _ReelPainter oldDelegate) {
    return oldDelegate.radius != radius || oldDelegate.color != color;
  }
}
