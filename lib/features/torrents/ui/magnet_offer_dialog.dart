import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:ytdlapp/core/theme/app_theme.dart';
import 'package:ytdlapp/features/torrents/domain/torrent_source.dart';

enum MagnetOfferAction { download, openTorrents }

class MagnetOfferResult {
  final MagnetOfferAction action;
  final String savePath;

  const MagnetOfferResult({required this.action, required this.savePath});
}

/// Single window for a clipboard-detected magnet link: confirm the save
/// folder, then start resolving via DHT right away, or hop to the Torrents
/// page to review first.
Future<MagnetOfferResult?> showMagnetOfferDialog(
  BuildContext context, {
  required String magnet,
  String? initialPath,
}) {
  return showDialog<MagnetOfferResult>(
    context: context,
    builder: (_) => _MagnetOfferDialog(
      magnet: magnet,
      initialPath: initialPath,
    ),
  );
}

class _MagnetOfferDialog extends StatefulWidget {
  final String magnet;
  final String? initialPath;

  const _MagnetOfferDialog({required this.magnet, this.initialPath});

  @override
  State<_MagnetOfferDialog> createState() => _MagnetOfferDialogState();
}

class _MagnetOfferDialogState extends State<_MagnetOfferDialog> {
  late String? _savePath = widget.initialPath;

  String get _label => TorrentSource.magnet(widget.magnet).label;

  Future<void> _pickPath() async {
    final path = await FilePicker.platform.getDirectoryPath();
    if (path != null && path.isNotEmpty && mounted) {
      setState(() => _savePath = path);
    }
  }

  void _submit(MagnetOfferAction action) {
    Navigator.of(context).pop(
      MagnetOfferResult(action: action, savePath: _savePath ?? ''),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool canDownload = _savePath != null && _savePath!.isNotEmpty;
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
                          'TORRENT TRANSPORT / CLIPBOARD',
                          style: TText.mono(
                            context,
                            size: 10.5,
                            letterSpacing: 0.18,
                            color: TColors.amber,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Magnet link detected',
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
                          _label.toUpperCase(),
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
                        widget.magnet,
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
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 0),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: TColors.jackBg,
                  border: Border.all(color: TColors.line),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.folder_outlined,
                      size: 14,
                      color: canDownload ? TColors.amber : TColors.textDim,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _savePath ?? 'No download folder selected',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TText.mono(
                          context,
                          size: 11.5,
                          color: canDownload ? TColors.text : TColors.textDim,
                        ),
                      ),
                    ),
                    if (_savePath != null)
                      InkWell(
                        onTap: () => setState(() => _savePath = null),
                        child: const Padding(
                          padding: EdgeInsets.all(4),
                          child: Icon(
                            Icons.close,
                            size: 12,
                            color: TColors.textDim,
                          ),
                        ),
                      ),
                    const SizedBox(width: 4),
                    InkWell(
                      onTap: _pickPath,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Text(
                          'CHANGE',
                          style: TText.mono(
                            context,
                            size: 9.5,
                            letterSpacing: 0.06,
                            color: TColors.amber,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
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
                  _MagnetOfferButton(
                    icon: Icons.folder_open,
                    label: 'TORRENTS',
                    outline: true,
                    onTap: () => _submit(MagnetOfferAction.openTorrents),
                  ),
                  const SizedBox(width: 10),
                  _MagnetOfferButton(
                    icon: Icons.play_circle_outline,
                    label: 'DOWNLOAD',
                    outline: false,
                    enabled: canDownload,
                    onTap: () => _submit(MagnetOfferAction.download),
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

class _MagnetOfferButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool outline;
  final bool enabled;
  final VoidCallback onTap;

  const _MagnetOfferButton({
    required this.icon,
    required this.label,
    required this.outline,
    required this.onTap,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    final Color fg = outline ? TColors.amber : const Color(0xFF14120F);
    final Color color = enabled
        ? (outline ? TColors.jackBg : TColors.amber)
        : TColors.amberDim.withValues(alpha: 0.35);
    final Color iconColor = enabled
        ? fg
        : (outline ? TColors.textDim : fg.withValues(alpha: 0.4));
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: color,
          border: Border.all(
            color: enabled
                ? (outline ? TColors.amberDim : TColors.amber)
                : TColors.line,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: iconColor),
            const SizedBox(width: 7),
            Text(
              label,
              style: TText.display(
                context,
                size: 12,
                weight: FontWeight.w700,
                color: iconColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}