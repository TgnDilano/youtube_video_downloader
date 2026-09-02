import 'package:flutter/material.dart';
import 'package:ytdlapp/core/theme/app_theme.dart';
import 'package:ytdlapp/core/widgets/tubemate_controls.dart';
import 'package:ytdlapp/core/widgets/tubemate_sidebar.dart';
import 'package:ytdlapp/features/download/domain/download_controller.dart';
import 'package:ytdlapp/features/download/domain/playlist_options.dart';

/// Pre-queue options for a playlist: full vs item selection, default
/// resolution and audio-only, shown when the user submits a playlist URL.
class PlaylistOptionsDialog extends StatefulWidget {
  final DownloadController controller;
  final String url;
  final String title;
  final String thumbnailUrl;
  final List<dynamic> entries;
  final bool initialFullPlaylist;
  final Set<int> initialSelection;
  final String initialResolution;
  final bool initialAudioOnly;

  const PlaylistOptionsDialog({
    super.key,
    required this.controller,
    required this.url,
    required this.title,
    required this.thumbnailUrl,
    required this.entries,
    required this.initialFullPlaylist,
    required this.initialSelection,
    required this.initialResolution,
    required this.initialAudioOnly,
  });

  @override
  State<PlaylistOptionsDialog> createState() => _PlaylistOptionsDialogState();
}

class _PlaylistOptionsDialogState extends State<PlaylistOptionsDialog> {
  late bool _fullPlaylist = widget.initialFullPlaylist;
  late final Set<int> _selected = {...widget.initialSelection};
  late bool _audioOnly = widget.initialAudioOnly;
  String _resolution = 'best';
  bool _loadingResolutions = true;
  bool _resolutionsFailed = false;
  List<int> _heights = const [];

  @override
  void initState() {
    super.initState();
    _fetchResolutions();
  }

  Future<void> _fetchResolutions() async {
    setState(() {
      _loadingResolutions = true;
      _resolutionsFailed = false;
    });
    final info = await widget.controller.fetchVideoInfo(
      widget.url,
      flatPlaylist: false,
    );
    if (!mounted) return;

    final heights = <int>[];
    if (info != null && info['formats'] is List) {
      for (final f in info['formats']) {
        if (f['height'] != null && f['vcodec'] != 'none') {
          final h = f['height'] as int;
          if (!heights.contains(h)) heights.add(h);
        }
      }
      heights.sort((a, b) => b.compareTo(a));
    }

    setState(() {
      _loadingResolutions = false;
      _resolutionsFailed = info == null;
      _heights = heights.take(5).toList();
    });
  }

  void _toggleItem(int index) {
    setState(() {
      if (_selected.contains(index)) {
        _selected.remove(index);
      } else {
        _selected.add(index);
      }
    });
  }

  void _confirm() {
    Navigator.of(context).pop(
      PlaylistOptions(
        fullPlaylist: _fullPlaylist,
        selectedItems: _selected,
        resolution: _resolution,
        audioOnly: _audioOnly,
      ),
    );
  }

  String _formatDuration(Object? value) {
    if (value is! num) return '';
    final total = value.toInt();
    final h = total ~/ 3600;
    final m = (total % 3600) ~/ 60;
    final s = total % 60;
    String two(int v) => v.toString().padLeft(2, '0');
    return h > 0 ? '$h:${two(m)}:${two(s)}' : '$m:${two(s)}';
  }

  String _jackLabel(String value) {
    if (value == 'best') return 'HQ';
    final h = int.tryParse(value) ?? 0;
    if (h >= 2160) return '4K';
    if (h >= 1440) return '2K';
    if (h >= 1080) return 'FHD';
    if (h >= 720) return 'HD';
    return 'SD';
  }

  String _optionLabel(String value) {
    if (value == 'best') return 'Best quality';
    return '${value}p';
  }

  @override
  Widget build(BuildContext context) {
    final total = widget.entries.length;
    final canSelect = total > 0;
    final resolutionOptions = <String>[
      'best',
      ..._heights.map((h) => h.toString()),
    ];
    final confirmEnabled = _fullPlaylist || _selected.isNotEmpty;

    return Dialog(
      backgroundColor: TColors.panel2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.zero,
        side: BorderSide(color: TColors.line),
      ),
      child: SizedBox(
        width: 470,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'MEDIA TRANSPORT / PLAYLIST OPTIONS',
                    style: TText.mono(
                      context,
                      size: 10.5,
                      letterSpacing: 0.18,
                      color: TColors.amber,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    widget.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TText.display(
                      context,
                      size: 16,
                      weight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 14, 18, 16),
              child: Row(
                children: [
                  _DialogThumbnail(
                    url: widget.thumbnailUrl,
                    width: 64,
                    height: 36,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'PLAYLIST · ${total.toString().padLeft(2, '0')} ITEMS',
                      style: TText.mono(
                        context,
                        size: 10.5,
                        letterSpacing: 0.1,
                        color: TColors.textDim,
                      ),
                    ),
                  ),
                  if (canSelect)
                    MonoCheckbox(
                      value: _fullPlaylist,
                      label: 'Full playlist',
                      onTap: () =>
                          setState(() => _fullPlaylist = !_fullPlaylist),
                    ),
                ],
              ),
            ),
            Divider(height: 1, color: TColors.lineSoft),

            if (!_fullPlaylist && canSelect)
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 210),
                child: ListView.builder(
                  shrinkWrap: true,
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  itemCount: widget.entries.length,
                  itemBuilder: (context, index) {
                    final entry = widget.entries[index] as Map? ?? {};
                    final itemIndex = index + 1;
                    final selected = _selected.contains(itemIndex);
                    return InkWell(
                      onTap: () => _toggleItem(itemIndex),
                      child: Container(
                        color: selected
                            ? TColors.amber.withValues(alpha: 0.04)
                            : Colors.transparent,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 5,
                        ),
                        child: Row(
                          children: [
                            CheckSquare(value: selected, size: 14),
                            const SizedBox(width: 12),
                            Text(
                              itemIndex.toString().padLeft(2, '0'),
                              style: TText.mono(
                                context,
                                size: 9,
                                letterSpacing: 0.08,
                                color: TColors.textDim,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                entry['title']?.toString() ?? 'Untitled item',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TText.body(
                                  context,
                                  size: 12.5,
                                  color: selected
                                      ? TColors.text
                                      : TColors.textMuted,
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Text(
                              _formatDuration(entry['duration']),
                              style: TText.mono(
                                context,
                                size: 10.5,
                                color: TColors.textMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),

            Container(
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 8),
              color: TColors.counterBg,
              child: Row(
                children: [
                  Text(
                    'RESOLUTION',
                    style: TText.mono(
                      context,
                      size: 9.5,
                      letterSpacing: 0.1,
                      color: TColors.textDim,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _loadingResolutions
                        ? Text(
                            'FETCHING FORMATS…',
                            style: TText.mono(
                              context,
                              size: 10,
                              color: TColors.textMuted,
                            ),
                          )
                        : Text(
                            _resolutionsFailed
                                ? 'BEST WILL BE USED — RETRY'
                                : 'DEFAULT FOR ALL ITEMS',
                            style: TText.mono(
                              context,
                              size: 10,
                              color: _resolutionsFailed
                                  ? TColors.red
                                  : TColors.textMuted,
                            ),
                          ),
                  ),
                  if (_resolutionsFailed)
                    InkWell(
                      onTap: _fetchResolutions,
                      child: Padding(
                        padding: const EdgeInsets.all(4),
                        child: Text(
                          'RETRY',
                          style: TText.mono(
                            context,
                            size: 10,
                            color: TColors.amber,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            if (!_loadingResolutions && !_resolutionsFailed)
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 150),
                child: ListView(
                  shrinkWrap: true,
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  children: [
                    for (final value in resolutionOptions)
                      _ResRow(
                        jackLabel: _jackLabel(value),
                        label: _optionLabel(value),
                        selected: _resolution == value,
                        onTap: () => setState(() => _resolution = value),
                      ),
                  ],
                ),
              ),

            Divider(height: 1, color: TColors.lineSoft),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
              child: Row(
                children: [
                  Text(
                    'AUDIO ONLY',
                    style: TText.mono(
                      context,
                      size: 9.5,
                      letterSpacing: 0.1,
                      color: TColors.textDim,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Extract MP3 from every item',
                      style: TText.mono(
                        context,
                        size: 10,
                        color: TColors.textMuted,
                      ),
                    ),
                  ),
                  TubemateSwitch(
                    value: _audioOnly,
                    onChanged: (v) => setState(() => _audioOnly = v),
                    activeColor: TColors.green,
                    glow: true,
                  ),
                ],
              ),
            ),
            Divider(height: 1, color: TColors.lineSoft),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      _fullPlaylist
                          ? 'QUEUE ALL ${total.toString().padLeft(2, '0')} ITEMS'
                          : _selected.isNotEmpty
                          ? 'QUEUE ${_selected.length.toString().padLeft(2, '0')} SELECTED'
                          : 'SELECT ITEMS TO QUEUE',
                      style: TText.mono(
                        context,
                        size: 10.5,
                        letterSpacing: 0.1,
                        color: confirmEnabled ? TColors.text : TColors.textDim,
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: confirmEnabled ? _confirm : null,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 9,
                      ),
                      color: confirmEnabled ? TColors.amber : TColors.jackBg,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _fullPlaylist ? 'QUEUE PLAYLIST' : 'QUEUE ITEMS',
                            style: TText.mono(
                              context,
                              size: 11,
                              letterSpacing: 0.06,
                              color: confirmEnabled
                                  ? const Color(0xFF14120F)
                                  : TColors.textDim,
                            ),
                          ),
                        ],
                      ),
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

class _DialogThumbnail extends StatelessWidget {
  final String? url;
  final double width;
  final double height;

  const _DialogThumbnail({
    required this.url,
    required this.width,
    required this.height,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        border: Border.all(color: TColors.line),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [TColors.thumbGradA, TColors.thumbGradB, TColors.thumbGradC],
        ),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (url != null && url!.isNotEmpty)
            Image.network(
              url!,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => const SizedBox.shrink(),
            ),
          const Scanlines(
            horizontal: false,
            color: Color(0x26000000),
            thickness: 2,
          ),
        ],
      ),
    );
  }
}

class _ResRow extends StatelessWidget {
  final String jackLabel;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _ResRow({
    required this.jackLabel,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        height: 34,
        padding: const EdgeInsets.symmetric(horizontal: 18),
        color: selected
            ? TColors.amber.withValues(alpha: 0.05)
            : Colors.transparent,
        child: Row(
          children: [
            Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                color: TColors.jackBg,
                borderRadius: BorderRadius.circular(3),
                border: Border.all(color: TColors.line),
              ),
              child: Center(
                child: Text(
                  jackLabel,
                  style: TText.mono(
                    context,
                    size: 8.5,
                    color: TColors.amber,
                  ).copyWith(fontWeight: FontWeight.w600),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: TText.body(
                  context,
                  size: 12.5,
                  color: selected ? TColors.amber : TColors.text,
                ),
              ),
            ),
            if (selected) Icon(Icons.check, size: 13, color: TColors.amber),
          ],
        ),
      ),
    );
  }
}
