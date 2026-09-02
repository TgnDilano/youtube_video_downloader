import 'package:flutter/material.dart';
import 'package:ytdlapp/controllers/download_controller.dart';
import 'package:ytdlapp/ui/app_theme.dart';
import 'package:ytdlapp/ui/widgets/resolution_dialog.dart';

enum ClipboardOfferAction { queue, schedule }

class ClipboardOfferResult {
  final ClipboardOfferAction action;
  final String resolution;
  final bool audioOnly;
  final String? title;

  const ClipboardOfferResult({
    required this.action,
    required this.resolution,
    this.audioOnly = false,
    this.title,
  });
}

/// Single window for a clipboard-detected link: thumbnail + quality picker,
/// then either download now or pin it for a later time.
Future<ClipboardOfferResult?> showClipboardOfferDialog(
  BuildContext context, {
  required String url,
  required DownloadController controller,
  String initialResolution = 'best',
}) {
  return showDialog<ClipboardOfferResult>(
    context: context,
    builder: (_) => _ClipboardOfferDialog(
      url: url,
      controller: controller,
      initialResolution: initialResolution,
    ),
  );
}

class _ClipboardOfferDialog extends StatefulWidget {
  final String url;
  final DownloadController controller;
  final String initialResolution;

  const _ClipboardOfferDialog({
    required this.url,
    required this.controller,
    required this.initialResolution,
  });

  @override
  State<_ClipboardOfferDialog> createState() => _ClipboardOfferDialogState();
}

class _ClipboardOfferDialogState extends State<_ClipboardOfferDialog> {
  late String _selected = widget.initialResolution;
  String? _title;

  void _submit(ClipboardOfferAction action) {
    Navigator.of(context).pop(
      ClipboardOfferResult(
        action: action,
        resolution: _selected,
        audioOnly: _selected == 'audio',
        title: _title,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: TColors.panel2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.zero,
        side: BorderSide(color: TColors.line),
      ),
      child: SizedBox(
        width: 440,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 16, 10, 0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'MEDIA TRANSPORT / CLIPBOARD',
                          style: TText.mono(
                            context,
                            size: 10.5,
                            letterSpacing: 0.18,
                            color: TColors.amber,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          _title ?? 'YouTube link detected',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TText.display(
                            context,
                            size: 16,
                            weight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          _title == null ? 'FETCHING VIDEO…' : 'YOUTUBE',
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
                  InkWell(
                    onTap: () => Navigator.of(context).pop(),
                    child: const Padding(
                      padding: EdgeInsets.all(6),
                      child: Icon(
                        Icons.close,
                        size: 16,
                        color: TColors.textDim,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 0),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 9,
                ),
                decoration: BoxDecoration(
                  color: TColors.jackBg,
                  border: Border.all(color: TColors.line),
                ),
                child: Row(
                  children: [
                    Icon(Icons.link, size: 14, color: TColors.amber),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        widget.url,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TText.mono(
                          context,
                          size: 11.5,
                          color: TColors.amber,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            ResolutionPicker(
              controller: widget.controller,
              url: widget.url,
              duration: '',
              thumbnailUrl: '',
              initial: _selected,
              selectedLabelPrefix: 'SELECTED',
              maxListHeight: 210,
              onInfo: (info) {
                final t = info?['title']?.toString();
                if (t != null && t.isNotEmpty && mounted) {
                  setState(() => _title = t);
                }
              },
              onChanged: (value) => setState(() => _selected = value),
            ),
            Divider(height: 1, color: TColors.lineSoft),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              child: Row(
                children: [
                  InkWell(
                    onTap: () => Navigator.of(context).pop(),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.chevron_left,
                            size: 14,
                            color: TColors.textDim,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'DISMISS',
                            style: TText.mono(
                              context,
                              size: 10,
                              letterSpacing: 0.06,
                              color: TColors.textDim,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const Spacer(),
                  _OfferButton(
                    icon: Icons.schedule,
                    label: 'SCHEDULE',
                    outline: true,
                    onTap: () => _submit(ClipboardOfferAction.schedule),
                  ),
                  const SizedBox(width: 10),
                  _OfferButton(
                    icon: Icons.play_circle_outline,
                    label: 'DOWNLOAD',
                    outline: false,
                    onTap: () => _submit(ClipboardOfferAction.queue),
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

class _OfferButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool outline;
  final VoidCallback onTap;

  const _OfferButton({
    required this.icon,
    required this.label,
    required this.outline,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final Color fg = outline ? TColors.amber : const Color(0xFF14120F);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: outline ? TColors.jackBg : TColors.amber,
          border: Border.all(
            color: outline ? TColors.amberDim : TColors.amber,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: fg),
            const SizedBox(width: 7),
            Text(
              label,
              style: TText.display(
                context,
                size: 12,
                weight: FontWeight.w700,
                color: fg,
              ),
            ),
          ],
        ),
      ),
    );
  }
}