import 'package:flutter/material.dart';

import 'package:ytdlapp/core/theme/app_theme.dart';
import 'package:ytdlapp/features/torrents/domain/torrent_source.dart';
import 'package:ytdlapp/features/torrents/domain/torrent_task.dart';

/// Result of confirming a torrent removal. [deleteTorrentFile] is only
/// meaningful when the torrent came from a `.torrent` file.
class RemoveTorrentResult {
  final bool deleteData;
  final bool deleteTorrentFile;

  const RemoveTorrentResult({
    required this.deleteData,
    required this.deleteTorrentFile,
  });
}

/// Confirmation dialog shown before removing a torrent. Warns the user that
/// the torrent will be removed, and — when the torrent was added from a
/// `.torrent` file — asks whether the original file should be deleted too.
///
/// Returns a [RemoveTorrentResult] on confirm, or `null` if cancelled.
Future<RemoveTorrentResult?> showRemoveTorrentDialog(
  BuildContext context, {
  required TorrentTask task,
}) {
  final fromFile = task.source?.kind == TorrentSourceKind.file;
  final fileName = fromFile ? _fileName(task.source!.raw) : null;

  return showDialog<RemoveTorrentResult>(
    context: context,
    builder: (dialogContext) => _RemoveTorrentDialog(
      task: task,
      fromFile: fromFile,
      fileName: fileName,
    ),
  );
}

String _fileName(String path) {
  final parts = path.split(RegExp(r'[/\\]'));
  return parts.isNotEmpty ? parts.last : path;
}

class _RemoveTorrentDialog extends StatefulWidget {
  final TorrentTask task;
  final bool fromFile;
  final String? fileName;

  const _RemoveTorrentDialog({
    required this.task,
    required this.fromFile,
    required this.fileName,
  });

  @override
  State<_RemoveTorrentDialog> createState() => _RemoveTorrentDialogState();
}

class _RemoveTorrentDialogState extends State<_RemoveTorrentDialog> {
  bool _deleteData = false;
  bool _deleteTorrentFile = false;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: TColors.panel2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.zero,
        side: BorderSide(color: TColors.line),
      ),
      child: SizedBox(
        width: 420,
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
                    'TORRENT TRANSPORT / REMOVE',
                    style: TText.mono(
                      context,
                      size: 10.5,
                      letterSpacing: 0.18,
                      color: TColors.red,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Remove "${widget.task.name}"?',
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
              padding: const EdgeInsets.fromLTRB(18, 10, 18, 6),
              child: Text(
                'This removes the torrent from the active session.',
                style: TText.body(
                  context,
                  size: 12,
                  color: TColors.textMuted,
                ),
              ),
            ),
            if (widget.fromFile)
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 4, 18, 2),
                child: _option(
                  value: _deleteTorrentFile,
                  onChanged: (v) => setState(() => _deleteTorrentFile = v),
                  label: 'Also delete the original ${widget.fileName} file',
                  mono: true,
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 4, 18, 6),
              child: _option(
                value: _deleteData,
                onChanged: (v) => setState(() => _deleteData = v),
                label: 'Also delete the downloaded data from disk',
                mono: true,
              ),
            ),
            Divider(height: 1, color: TColors.lineSoft),
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 18,
                vertical: 12,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'CLICK OUTSIDE TO CANCEL',
                      style: TText.mono(
                        context,
                        size: 9,
                        letterSpacing: 0.08,
                        color: TColors.textDim,
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.of(context).pop(null),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: TColors.jackBg,
                        border: Border.all(color: TColors.line),
                      ),
                      child: Text(
                        'CANCEL',
                        style: TText.mono(
                          context,
                          size: 10.5,
                          letterSpacing: 0.06,
                          color: TColors.textMuted,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  GestureDetector(
                    onTap: () => Navigator.of(context).pop(
                      RemoveTorrentResult(
                        deleteData: _deleteData,
                        deleteTorrentFile: _deleteTorrentFile,
                      ),
                    ),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 8,
                      ),
                      color: TColors.red,
                      child: Text(
                        'REMOVE',
                        style: TText.mono(
                          context,
                          size: 10.5,
                          letterSpacing: 0.06,
                          color: const Color(0xFF14120F),
                        ),
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

  Widget _option({
    required bool value,
    required ValueChanged<bool> onChanged,
    required String label,
    bool mono = false,
  }) {
    final textStyle = mono
        ? TText.mono(context, size: 11.5, color: TColors.text)
        : TText.body(context, size: 13);
    return InkWell(
      onTap: () => onChanged(!value),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            _checkbox(value),
            const SizedBox(width: 10),
            Expanded(child: Text(label, style: textStyle)),
          ],
        ),
      ),
    );
  }

  Widget _checkbox(bool value) {
    return Container(
      width: 15,
      height: 15,
      decoration: BoxDecoration(
        color: value ? TColors.red : TColors.jackBg,
        border: Border.all(
          color: value ? TColors.red : TColors.line,
        ),
      ),
      child: value
          ? const Icon(Icons.check, size: 12, color: Color(0xFF14120F))
          : null,
    );
  }
}
