import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:ytdlapp/features/convert/domain/convert_controller.dart';
import 'package:ytdlapp/features/convert/domain/convert_task.dart';
import 'package:ytdlapp/core/theme/app_theme.dart';
import 'package:ytdlapp/core/widgets/vu_meter.dart';
import 'package:ytdlapp/core/widgets/tubemate_controls.dart';

/// The converter lane: pick a local video/audio file, choose a target
/// format, and transcode it with the bundled ffmpeg.
class ConvertPage extends StatefulWidget {
  final ConvertController controller;

  const ConvertPage({super.key, required this.controller});

  @override
  State<ConvertPage> createState() => _ConvertPageState();
}

class _ConvertPageState extends State<ConvertPage> {
  String? _sourcePath;
  String _sourceName = '';
  String _sourceMeta = '';
  double _durationSeconds = 0;
  bool _isSourceAudio = false;
  String? _selectedTarget;

  Future<void> _pickSource() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.any);
    if (result == null || result.files.isEmpty) return;
    final file = result.files.first;
    final path = file.path;
    if (path == null || path.isEmpty) return;

    setState(() {
      _sourcePath = path;
      _sourceName = file.name;
      _sourceMeta = '';
      _selectedTarget = null;
    });

    final probe = await widget.controller.probeSource(path);
    if (!mounted) return;

    final sizeText = _formatBytes(file.size);
    String? durationText;
    final rawDuration = probe?['duration'];
    final parsed = double.tryParse(rawDuration ?? '');
    if (parsed != null && parsed > 0) {
      _durationSeconds = parsed;
      durationText = _formatDuration(parsed);
    }

    setState(() {
      _isSourceAudio = ConvertController.isAudioSource(path);
      _sourceMeta = sizeText + (durationText != null ? ' · $durationText' : '');
      _selectedTarget = _isSourceAudio ? 'mp3' : 'mp4';
    });
  }

  Future<void> _startConvert() async {
    final path = _sourcePath;
    final target = _selectedTarget;
    if (path == null || target == null) return;

    final dir = await FilePicker.platform.getDirectoryPath();
    if (dir == null) return;

    widget.controller.addConversion(
      sourcePath: path,
      outputDir: dir,
      targetId: target,
      durationSeconds: _durationSeconds,
    );
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    const units = ['KB', 'MB', 'GB'];
    var value = bytes / 1024;
    var unit = 0;
    while (value >= 1024 && unit < units.length - 1) {
      value /= 1024;
      unit++;
    }
    return '${value.toStringAsFixed(1)} ${units[unit]}';
  }

  String _formatDuration(double seconds) {
    final total = seconds.round();
    final h = total ~/ 3600;
    final m = (total % 3600) ~/ 60;
    final s = total % 60;
    String two(int v) => v.toString().padLeft(2, '0');
    return h > 0 ? '$h:${two(m)}:${two(s)}' : '$m:${two(s)}';
  }

  @override
  Widget build(BuildContext context) {
    final canConvert = _sourcePath != null && _selectedTarget != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildHeader(),
        const SizedBox(height: 26),
        _buildSourcePanel(context),
        const SizedBox(height: 22),
        const _GroupTitle(label: 'Target Format'),
        const SizedBox(height: 10),
        _buildTargetSelector(context),
        const SizedBox(height: 18),
        Row(
          children: [
            const Icon(Icons.folder_outlined, size: 13, color: TColors.textDim),
            const SizedBox(width: 8),
            Text(
              'SAVE LOCATION IS ASKED FOR EACH CONVERSION',
              style: TText.mono(context, size: 10, color: TColors.textDim),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            RecordButton(
              onPressed: canConvert ? _startConvert : null,
              label: 'Convert',
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                _sourcePath == null
                    ? 'SELECT A SOURCE FILE TO BEGIN'
                    : _selectedTarget == null
                    ? 'PICK A TARGET FORMAT'
                    : '$_sourceName → ${_selectedTarget!.toUpperCase()}'
                          .toUpperCase(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TText.mono(
                  context,
                  size: 10.5,
                  letterSpacing: 0.08,
                  color: canConvert ? TColors.textMuted : TColors.textDim,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 30),
        _buildQueueHeader(context),
        const SizedBox(height: 14),
        Expanded(
          child: ListenableBuilder(
            listenable: widget.controller,
            builder: (context, _) {
              if (widget.controller.tasks.isEmpty) {
                return Center(
                  child: Text(
                    'NO CONVERSIONS IN THIS LANE',
                    style: TText.mono(
                      context,
                      size: 11,
                      color: TColors.textDim,
                    ),
                  ),
                );
              }
              return ListView.builder(
                itemCount: widget.controller.tasks.length,
                itemBuilder: (context, index) {
                  final task = widget.controller.tasks[index];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: ConvertCard(
                      task: task,
                      onRemove: () => widget.controller.removeTask(task),
                      onRetry: () => widget.controller.retryTask(task),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.only(bottom: 18),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: TColors.line)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Media Transport / Converter',
            style: TText.mono(
              context,
              size: 11,
              letterSpacing: 0.18,
              color: TColors.amber,
            ),
          ),
          const SizedBox(height: 8),
          Text('Convert', style: TText.display(context, size: 30)),
          const SizedBox(height: 6),
          Text(
            'Local files, new formats. Video to audio in one pass.',
            style: TText.body(context, size: 13.5, color: TColors.textMuted),
          ),
        ],
      ),
    );
  }

  Widget _buildSourcePanel(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: TColors.panel2,
        border: Border.all(color: TColors.line),
      ),
      child: Row(
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
              child: Row(
                children: [
                  Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: TColors.jackBg,
                      border: Border.all(color: TColors.line),
                    ),
                    child: _sourcePath == null
                        ? Icon(
                            Icons.insert_drive_file_outlined,
                            size: 14,
                            color: TColors.amber,
                          )
                        : Icon(
                            _isSourceAudio
                                ? Icons.library_music_outlined
                                : Icons.video_file_outlined,
                            size: 14,
                            color: TColors.amber,
                          ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Input · Source File',
                          style: TText.mono(
                            context,
                            size: 9.5,
                            letterSpacing: 0.1,
                            color: TColors.textDim,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          _sourcePath == null
                              ? 'No file selected — tap Browse'
                              : _sourceName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TText.mono(
                            context,
                            size: 13.5,
                            color: _sourcePath == null
                                ? TColors.textDim
                                : TColors.amber,
                          ),
                        ),
                        if (_sourcePath != null && _sourceMeta.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Text(
                              _sourceMeta.toUpperCase(),
                              style: TText.mono(
                                context,
                                size: 9.5,
                                color: TColors.textMuted,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: _BrowseButton(onTap: _pickSource),
          ),
        ],
      ),
    );
  }

  Widget _buildTargetSelector(BuildContext context) {
    final targets = <(String, List<String>)>[
      ('VIDEO', ConvertController.videoTargets),
      ('AUDIO', ConvertController.audioTargets),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final group in targets) ...[
          _GroupTitle(label: group.$1, small: true),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final target in group.$2)
                _TargetChip(
                  label: target.toUpperCase(),
                  selected: _selectedTarget == target,
                  enabled: group.$1 == 'AUDIO' || !_isSourceAudio,
                  onTap: () => setState(() => _selectedTarget = target),
                ),
            ],
          ),
          const SizedBox(height: 12),
        ],
      ],
    );
  }

  Widget _buildQueueHeader(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: TColors.line)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            Text(
              'LANE · CONVERSIONS',
              style: TText.mono(context, size: 11, color: TColors.textDim),
            ),
            const Spacer(),
            InkWell(
              onTap: widget.controller.clearFinished,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.delete_sweep_outlined,
                    size: 12,
                    color: TColors.textDim,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Clear finished',
                    style: TText.mono(
                      context,
                      size: 11,
                      color: TColors.textDim,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GroupTitle extends StatelessWidget {
  final String label;
  final bool small;

  const _GroupTitle({required this.label, this.small = false});

  @override
  Widget build(BuildContext context) {
    return Text(
      label.toUpperCase(),
      style: TText.mono(
        context,
        size: small ? 9.5 : 10.5,
        letterSpacing: 0.14,
        color: TColors.textDim,
      ),
    );
  }
}

class _BrowseButton extends StatelessWidget {
  final VoidCallback onTap;

  const _BrowseButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: TColors.jackBg,
          border: Border.all(color: TColors.line),
        ),
        child: Text(
          'BROWSE',
          style: TText.mono(
            context,
            size: 10.5,
            letterSpacing: 0.06,
            color: TColors.amber,
          ),
        ),
      ),
    );
  }
}

class _TargetChip extends StatefulWidget {
  final String label;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  const _TargetChip({
    required this.label,
    required this.selected,
    required this.enabled,
    required this.onTap,
  });

  @override
  State<_TargetChip> createState() => _TargetChipState();
}

class _TargetChipState extends State<_TargetChip> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final finalColor = widget.enabled
        ? widget.selected
              ? TColors.amber
              : _hovered
              ? TColors.amber
              : TColors.textMuted
        : TColors.textDim;
    return MouseRegion(
      cursor: widget.enabled
          ? SystemMouseCursors.click
          : SystemMouseCursors.basic,
      onEnter: widget.enabled ? (_) => setState(() => _hovered = true) : null,
      onExit: widget.enabled ? (_) => setState(() => _hovered = false) : null,
      child: GestureDetector(
        onTap: widget.enabled ? widget.onTap : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
          decoration: BoxDecoration(
            color: widget.selected
                ? TColors.amber.withValues(alpha: 0.08)
                : TColors.jackBg,
            border: Border.all(
              color: widget.selected || (_hovered && widget.enabled)
                  ? TColors.amber
                  : TColors.line,
            ),
          ),
          child: Text(
            widget.label,
            style: TText.mono(
              context,
              size: 10.5,
              letterSpacing: 0.08,
              color: finalColor,
            ),
          ),
        ),
      ),
    );
  }
}

class ConvertCard extends StatefulWidget {
  final ConvertTask task;
  final VoidCallback onRemove;
  final VoidCallback onRetry;

  const ConvertCard({
    super.key,
    required this.task,
    required this.onRemove,
    required this.onRetry,
  });

  @override
  State<ConvertCard> createState() => _ConvertCardState();
}

class _ConvertCardState extends State<ConvertCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _spinController;

  ConvertTask get task => widget.task;

  @override
  void initState() {
    super.initState();
    _spinController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    );
    _syncAnimation();
    task.addListener(_onTaskChanged);
  }

  void _onTaskChanged() {
    if (!mounted) return;
    _syncAnimation();
  }

  void _syncAnimation() {
    if (task.status == ConvertStatus.converting &&
        !_spinController.isAnimating) {
      _spinController.repeat();
    } else if (task.status != ConvertStatus.converting) {
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

  String get _statusLine {
    switch (task.status) {
      case ConvertStatus.completed:
        return 'COMPLETED${task.fileSize.isNotEmpty ? ' · ${task.fileSize}' : ''}';
      case ConvertStatus.error:
        return 'FAILED — RETRY OR REMOVE';
      case ConvertStatus.converting:
        final total = task.durationSeconds * 1e6;
        final pct = total > 0
            ? ' · ${(task.progress * 100).clamp(0, 100).round()}%'
            : '';
        final mode = task.mode == 'remux' ? ' · REMUX (FAST)' : '';
        return 'CONVERTING$pct$mode';
      case ConvertStatus.queued:
        return 'QUEUED';
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: task,
      builder: (context, _) {
        return Container(
          decoration: BoxDecoration(
            color: TColors.panel2,
            border: Border.all(color: TColors.line),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            child: Row(
              children: [
                _StatusGlyph(task: task, spin: _spinController),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        task.sourceName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TText.body(context, size: 13.5),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '→ ${task.targetLabel} · $_statusLine',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TText.mono(
                          context,
                          size: 10.5,
                          color: task.status == ConvertStatus.error
                              ? TColors.red
                              : TColors.textDim,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                VuMeter(
                  progress: task.status == ConvertStatus.completed
                      ? 1
                      : task.progress,
                  width: 110,
                ),
                const SizedBox(width: 16),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (task.status == ConvertStatus.completed)
                      _IconAction(
                        icon: Icons.folder_open,
                        color: TColors.textMuted,
                        tooltip: 'Open folder',
                        onTap: () => _openFolder(),
                      ),
                    if (task.status == ConvertStatus.error)
                      _IconAction(
                        icon: Icons.refresh,
                        color: TColors.amber,
                        tooltip: 'Retry',
                        onTap: widget.onRetry,
                      ),
                    _IconAction(
                      icon: task.isActive ? Icons.close : Icons.delete_outline,
                      color: task.isActive ? TColors.red : TColors.textDim,
                      tooltip: task.isActive ? 'Cancel' : 'Remove',
                      onTap: widget.onRemove,
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _openFolder() async {
    final uri = Uri.file(task.sourcePath);
    await launchUrl(uri);
  }
}

class _StatusGlyph extends StatelessWidget {
  final ConvertTask task;
  final Animation<double> spin;

  const _StatusGlyph({required this.task, required this.spin});

  @override
  Widget build(BuildContext context) {
    final size = 28.0;
    final color = switch (task.status) {
      ConvertStatus.completed => TColors.green,
      ConvertStatus.error => TColors.red,
      ConvertStatus.queued => TColors.textDim,
      ConvertStatus.converting => TColors.amber,
    };
    final child = switch (task.status) {
      ConvertStatus.completed => Icon(
        Icons.check,
        size: size * 0.4,
        color: TColors.green,
      ),
      ConvertStatus.error => Icon(
        Icons.close,
        size: size * 0.4,
        color: TColors.red,
      ),
      ConvertStatus.queued => Icon(
        Icons.hourglass_empty,
        size: size * 0.45,
        color: color,
      ),
      ConvertStatus.converting => RotationTransition(
        turns: spin,
        child: Icon(Icons.sync, size: size * 0.45, color: color),
      ),
    };
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: color, width: 1.5),
      ),
      child: Center(child: child),
    );
  }
}

class _IconAction extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String tooltip;
  final VoidCallback? onTap;

  const _IconAction({
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
