import 'package:flutter/material.dart';
import 'package:ytdlapp/controllers/download_controller.dart';
import 'package:ytdlapp/ui/app_theme.dart';
import 'package:ytdlapp/ui/widgets/tubemate_sidebar.dart';

/// Shared quality selector: thumbnail header + lazy format list.
///
/// Fetches real formats via yt-dlp, falls back to Best/Audio and reports the
/// current pick through [onChanged]. Used by both [ResolutionDialog] and the
/// clipboard offer window.
class ResolutionPicker extends StatefulWidget {
  final DownloadController controller;
  final String url;
  final String duration;
  final String thumbnailUrl;
  final int? itemIndex;
  final String initial;
  final bool showAudio;
  final Map<String, dynamic>? preloadedInfo;
  final ValueChanged<String> onChanged;
  final String selectedLabelPrefix;
  final double maxListHeight;
  final ValueChanged<Map<String, dynamic>?>? onInfo;

  const ResolutionPicker({
    super.key,
    required this.controller,
    required this.url,
    required this.duration,
    required this.thumbnailUrl,
    required this.initial,
    required this.onChanged,
    this.itemIndex,
    this.showAudio = true,
    this.preloadedInfo,
    this.selectedLabelPrefix = 'CURRENT',
    this.maxListHeight = 264,
    this.onInfo,
  });

  @override
  State<ResolutionPicker> createState() => _ResolutionPickerState();
}

class _ResolutionPickerState extends State<ResolutionPicker> {
  bool _loading = true;
  bool _failed = false;
  List<int> _heights = [];
  Map<String, String> _sizeByOption = {};
  Map<String, dynamic>? _info;
  late String _selected = widget.initial;

  @override
  void initState() {
    super.initState();
    _fetchFormats();
  }

  Future<void> _fetchFormats() async {
    setState(() {
      _loading = true;
      _failed = false;
    });

    // Reuse an already-fetched info blob when it carries format data,
    // avoiding a second yt-dlp round-trip for the same video.
    final preloaded = widget.preloadedInfo;
    Map<String, dynamic>? info;
    if (preloaded != null && preloaded['formats'] is List) {
      info = preloaded;
    } else {
      info = await widget.controller.fetchVideoInfo(
        widget.url,
        flatPlaylist: false,
      );
    }
    if (!mounted) return;

    final heights = DownloadController.videoHeights(info);
    final sizeByOption = <String, String>{};
    if (info != null) {
      for (final o in _optionsFrom(heights)) {
        final size = DownloadController.estimateSizeForResolution(info, o);
        if (size != null && size > 0) {
          sizeByOption[o] = DownloadController.formatBytes(size);
        }
      }
    }

    setState(() {
      _loading = false;
      _failed = info == null;
      _heights = heights;
      _sizeByOption = sizeByOption;
      _info = info;
      if (!_optionsFrom(heights).contains(_selected)) {
        _selected = 'best';
      }
    });
    widget.onInfo?.call(info);
  }

  List<String> _optionsFrom(List<int> heights) => [
        'best',
        ...heights.map((h) => h.toString()),
        if (widget.showAudio) 'audio',
      ];

  List<String> get _options => _optionsFrom(_heights);

  String get _thumb {
    if (widget.thumbnailUrl.isNotEmpty) return widget.thumbnailUrl;
    final thumb = _info?['thumbnail'];
    return thumb is String ? thumb : '';
  }

  String _jackLabel(String value) {
    if (value == 'best') return 'HQ';
    if (value == 'audio') return 'AU';
    final h = int.tryParse(value) ?? 0;
    if (h >= 2160) return '4K';
    if (h >= 1440) return '2K';
    if (h >= 1080) return 'FHD';
    if (h >= 720) return 'HD';
    return 'SD';
  }

  String _optionLabel(String value) {
    if (value == 'best') return 'Best quality';
    if (value == 'audio') return 'Audio (MP3)';
    return '${value}p';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 14, 18, 16),
          child: Row(
            children: [
              _DialogThumbnail(url: _thumb, width: 64, height: 36),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      (widget.itemIndex != null
                              ? 'ITEM ${widget.itemIndex!.toString().padLeft(2, '0')}'
                              : 'CAPTURE')
                          + (widget.duration.isNotEmpty
                              ? ' · ${widget.duration}'
                              : ''),
                      style: TText.mono(
                        context,
                        size: 10,
                        color: TColors.textDim,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${widget.selectedLabelPrefix}: '
                      '${_optionLabel(_selected).toUpperCase()}',
                      style: TText.mono(
                        context,
                        size: 9.5,
                        letterSpacing: 0.08,
                        color: TColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const Divider(height: 1, color: TColors.lineSoft),
        ConstrainedBox(
          constraints: BoxConstraints(maxHeight: widget.maxListHeight),
          child: _loading
              ? Padding(
                  padding: const EdgeInsets.all(24),
                  child: Row(
                    children: [
                      const _PulseDot(),
                      const SizedBox(width: 10),
                      Text(
                        'FETCHING FORMATS…',
                        style: TText.mono(
                          context,
                          size: 11,
                          color: TColors.textDim,
                        ),
                      ),
                    ],
                  ),
                )
              : ListView(
                  shrinkWrap: true,
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  children: [
                    if (_failed)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(18, 8, 18, 12),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.error_outline,
                              size: 13,
                              color: TColors.red,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'UNABLE TO FETCH FORMATS — RETRYING NOT REQUIRED, BEST WORKS',
                                style: TText.mono(
                                  context,
                                  size: 9.5,
                                  color: TColors.red,
                                ),
                              ),
                            ),
                            InkWell(
                              onTap: _fetchFormats,
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
                    for (final value in _options)
                      _OptionRow(
                        jackLabel: _jackLabel(value),
                        label: _optionLabel(value),
                        sizeLabel: _sizeByOption[value] ?? '',
                        selected: _selected == value,
                        onTap: () => widget.onChanged(value),
                      ),
                  ],
                ),
        ),
      ],
    );
  }
}

/// Themed popup to pick a quality for one download. Pops the chosen value.
class ResolutionDialog extends StatelessWidget {
  final DownloadController controller;
  final String url;
  final String title;
  final String duration;
  final String thumbnailUrl;
  final int? itemIndex;
  final String current;
  final bool showAudio;
  final Map<String, dynamic>? preloadedInfo;

  const ResolutionDialog({
    super.key,
    required this.controller,
    required this.url,
    required this.title,
    required this.duration,
    required this.thumbnailUrl,
    required this.current,
    this.itemIndex,
    this.showAudio = true,
    this.preloadedInfo,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: TColors.panel2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.zero,
        side: const BorderSide(color: TColors.line),
      ),
      child: SizedBox(
        width: 440,
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
                    'MEDIA TRANSPORT / RESOLUTION',
                    style: TText.mono(
                      context,
                      size: 10.5,
                      letterSpacing: 0.18,
                      color: TColors.amber,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    title,
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
            ResolutionPicker(
              controller: controller,
              url: url,
              duration: duration,
              thumbnailUrl: thumbnailUrl,
              itemIndex: itemIndex,
              initial: current,
              showAudio: showAudio,
              preloadedInfo: preloadedInfo,
              onChanged: (value) => Navigator.of(context).pop(value),
            ),
            const Divider(height: 1, color: TColors.lineSoft),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
              child: Row(
                children: [
                  Text(
                    'TAP TO APPLY · CLICK OUTSIDE TO CANCEL',
                    style: TText.mono(
                      context,
                      size: 9,
                      letterSpacing: 0.08,
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

class _DialogThumbnail extends StatelessWidget {
  final String? url;
  final double width;
  final double height;

  const _DialogThumbnail({required this.url, required this.width, required this.height});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        border: Border.all(color: TColors.line),
        gradient: const LinearGradient(
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

class _PulseDot extends StatefulWidget {
  const _PulseDot();

  @override
  State<_PulseDot> createState() => _PulseDotState();
}

class _PulseDotState extends State<_PulseDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween(begin: 0.3, end: 1.0).animate(_controller),
      child: Container(
        width: 6,
        height: 6,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          color: TColors.green,
          boxShadow: [BoxShadow(color: TColors.green, blurRadius: 6)],
        ),
      ),
    );
  }
}

class _OptionRow extends StatelessWidget {
  final String jackLabel;
  final String label;
  final String sizeLabel;
  final bool selected;
  final VoidCallback onTap;

  const _OptionRow({
    required this.jackLabel,
    required this.label,
    required this.sizeLabel,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        height: 42,
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
                  size: 13,
                  color: selected ? TColors.amber : TColors.text,
                ),
              ),
            ),
            if (sizeLabel.isNotEmpty) ...[
              const SizedBox(width: 10),
              Text(
                sizeLabel,
                style: TText.mono(
                  context,
                  size: 9.5,
                  color: selected ? TColors.amber : TColors.textDim,
                ),
              ),
            ],
            if (selected) ...[
              const SizedBox(width: 10),
              const Icon(Icons.check, size: 13, color: TColors.amber),
            ],
          ],
        ),
      ),
    );
  }
}