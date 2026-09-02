import 'package:flutter/material.dart';

import 'package:ytdlapp/core/theme/app_theme.dart';
import 'package:ytdlapp/features/torrents/domain/torrent_file_info.dart';
import 'package:ytdlapp/features/torrents/domain/torrent_task.dart';

/// Popup that shows the content of a torrent (its files and their sizes)
/// before / during the download, once metadata is available.
Future<void> showTorrentDetailsDialog(
  BuildContext context, {
  required TorrentTask task,
  required List<TorrentFileInfo> files,
}) {
  return showDialog<void>(
    context: context,
    builder: (_) => _TorrentDetailsDialog(task: task, files: files),
  );
}

class _TorrentDetailsDialog extends StatelessWidget {
  final TorrentTask task;
  final List<TorrentFileInfo> files;

  const _TorrentDetailsDialog({required this.task, required this.files});

  @override
  Widget build(BuildContext context) {
    // Per-file sizes can be 0 when the engine exposes only an aggregate size,
    // so prefer the known torrent total for the footer and treat 0 as unknown.
    final knownTotal = task.totalSize > 0 ? task.totalSize : null;
    final knownFileCount = files.isNotEmpty
        ? files.where((f) => f.size > 0).length
        : 0;

    return Dialog(
      backgroundColor: TColors.panel2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.zero,
        side: BorderSide(color: TColors.line),
      ),
      child: SizedBox(
        width: 480,
        height: 460,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Header ──────────────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: TColors.lineSoft)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: TColors.jackBg,
                      border: Border.all(color: TColors.line),
                    ),
                    child: Icon(Icons.folder_open, size: 15, color: TColors.amber),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'TORRENT CONTENT',
                          style: TText.mono(
                            context,
                            size: 9.5,
                            letterSpacing: 0.18,
                            color: TColors.textDim,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          task.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TText.display(
                            context,
                            size: 15,
                            weight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          _subtitle(task, files, knownTotal),
                          style: TText.mono(
                            context,
                            size: 10.5,
                            color: TColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // ── Column labels ───────────────────────────────────────────────
            if (files.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 10, 18, 6),
                child: Row(
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _pill(context, '#'),
                        const SizedBox(width: 6),
                        _pill(context, files.length > 1 ? 'FILES' : 'FILE'),
                      ],
                    ),
                    const Spacer(),
                    _pill(context, knownFileCount == files.length
                        ? 'SIZE'
                        : 'SIZE · PARTIAL'),
                  ],
                ),
              ),

            // ── File list ───────────────────────────────────────────────────
            Expanded(
              child: files.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.hourglass_empty,
                              size: 28, color: TColors.textDim),
                          const SizedBox(height: 10),
                          Text(
                            'Waiting for torrent metadata…',
                            style: TText.body(
                              context,
                              size: 12.5,
                              color: TColors.textMuted,
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      itemCount: files.length,
                      separatorBuilder: (_, _) =>
                          Divider(height: 1, color: TColors.lineSoft),
                      itemBuilder: (context, index) {
                        final f = files[index];
                        return Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 18,
                            vertical: 9,
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 24,
                                height: 24,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: TColors.jackBg,
                                  border: Border.all(color: TColors.line),
                                ),
                                child: Text(
                                  '${index + 1}',
                                  style: TText.mono(
                                    context,
                                    size: 9.5,
                                    color: TColors.textDim,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _leafName(f.path, f.name),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TText.mono(
                                        context,
                                        size: 11.5,
                                        color: TColors.text,
                                        weight: FontWeight.w500,
                                      ),
                                    ),
                                    if (f.path.isNotEmpty &&
                                        f.path != f.name)
                                      Text(
                                        f.path,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TText.mono(
                                          context,
                                          size: 9.5,
                                          color: TColors.textDim,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 12),
                              Text(
                                f.size > 0
                                    ? _format(f.size)
                                    : knownTotal != null && files.length == 1
                                        ? _format(knownTotal)
                                        : '—',
                                style: TText.mono(
                                  context,
                                  size: 11,
                                  color: f.size > 0
                                      ? TColors.amber
                                      : TColors.textDim,
                                  weight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),

            // ── Footer ──────────────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 12),
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: TColors.lineSoft)),
              ),
              child: Row(
                children: [
                  if (knownTotal != null)
                    Flexible(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.storage, size: 13, color: TColors.amber),
                          const SizedBox(width: 6),
                          Text(
                            _format(knownTotal),
                            style: TText.mono(
                              context,
                              size: 12,
                              color: TColors.text,
                              weight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'TOTAL',
                            style: TText.mono(
                              context,
                              size: 9.5,
                              letterSpacing: 0.14,
                              color: TColors.textDim,
                            ),
                          ),
                        ],
                      ),
                    )
                  else if (files.isNotEmpty)
                    Flexible(
                      child: Text(
                        'SIZE UNAVAILABLE UNTIL METADATA ARRIVES',
                        overflow: TextOverflow.ellipsis,
                        style: TText.mono(
                          context,
                          size: 9.5,
                          letterSpacing: 0.08,
                          color: TColors.textDim,
                        ),
                      ),
                    ),
                  const Spacer(),
                  GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 8,
                      ),
                      color: TColors.amber,
                      child: Text(
                        'CLOSE',
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

  String _subtitle(TorrentTask task, List<TorrentFileInfo> files, int? total) {
    final parts = <String>[
      task.status.name.toUpperCase(),
      if (files.isNotEmpty) '${files.length} FILE${files.length == 1 ? '' : 'S'}',
    ];
    return parts.join(' · ');
  }

  String _leafName(String path, String name) {
    if (path.isEmpty) return name;
    final parts = path.split(RegExp(r'[/\\]'));
    return parts.isNotEmpty && parts.last.isNotEmpty ? parts.last : name;
  }

  Widget _pill(BuildContext context, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: TColors.jackBg,
        border: Border.all(color: TColors.line),
      ),
      child: Text(
        text,
        style: TText.mono(context, size: 8.5, letterSpacing: 0.1, color: TColors.textDim),
      ),
    );
  }

  static String _format(int bytes) {
    if (bytes <= 0) return '0 B';
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KiB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MiB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GiB';
  }
}
