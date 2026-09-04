import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:ytdlapp/core/theme/app_theme.dart';
import 'package:ytdlapp/features/settings/domain/settings_controller.dart';
import 'package:ytdlapp/features/torrents/domain/torrent_controller.dart';
import 'package:ytdlapp/features/torrents/domain/torrent_source.dart';
import 'package:ytdlapp/features/torrents/domain/torrent_task.dart';
import 'package:ytdlapp/features/torrents/ui/widgets/remove_torrent_dialog.dart';
import 'package:ytdlapp/features/torrents/ui/widgets/torrent_card.dart';
import 'package:ytdlapp/features/torrents/ui/widgets/torrent_details_dialog.dart';

/// The Torrents transport page: asks for a magnet link or `.torrent` file plus
/// a save folder, then lists running torrents.
class TorrentsPage extends StatefulWidget {
  final TorrentController controller;
  final SettingsController settings;

  const TorrentsPage({
    super.key,
    required this.controller,
    required this.settings,
  });

  @override
  State<TorrentsPage> createState() => _TorrentsPageState();
}

class _TorrentsPageState extends State<TorrentsPage> {
  final TextEditingController _magnetController = TextEditingController();

  /// A chosen `.torrent` file path, if the user opted for a file.
  String? _filePath;

  /// The save folder for the in-progress add.
  String? _savePath;

  /// Whether the user has explicitly overridden the default torrent path.
  bool _savePathOverridden = false;

  /// The last added source. When set, the add button is armed.
  TorrentSource? _pendingSource;

  /// True while an add-torrent operation is in flight.
  bool _isAdding = false;

  /// The effective save path: explicit override → settings default.
  String get _effectiveSavePath =>
      _savePath ?? widget.settings.defaultTorrentPath ?? '';

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onChanged);
    widget.settings.addListener(_onSettingsChanged);
    _magnetController.addListener(_onInputChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onChanged);
    widget.settings.removeListener(_onSettingsChanged);
    _magnetController.removeListener(_onInputChanged);
    _magnetController.dispose();
    super.dispose();
  }

  void _onChanged() {
    if (mounted) setState(() {});
  }

  void _onSettingsChanged() {
    if (mounted && !_savePathOverridden) setState(() {});
  }

  void _onInputChanged() {
    setState(() {
      _filePath = null;
      final text = _magnetController.text.trim();
      if (text.isNotEmpty && text.startsWith('magnet:')) {
        _pendingSource = TorrentSource.magnet(text);
      } else {
        _pendingSource = null;
      }
    });
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['torrent'],
    );
    if (result == null || result.files.isEmpty) return;
    setState(() {
      _filePath = result.files.single.path;
      _pendingSource = TorrentSource.file(_filePath!);
    });
  }

  void _sourceFromMagnet(String raw) {
    final source = raw.trim();
    if (source.isEmpty) return;
    setState(() {
      _pendingSource = TorrentSource.magnet(source);
      _filePath = null;
    });
  }

  Future<void> _pickSavePath() async {
    final path = await FilePicker.platform.getDirectoryPath();
    if (path == null) return;
    setState(() {
      _savePath = path;
      _savePathOverridden = true;
    });
  }

  void _clearOverride() {
    setState(() {
      _savePath = null;
      _savePathOverridden = false;
    });
  }

  Future<void> _add() async {
    final source = _pendingSource;
    final savePath = _effectiveSavePath;
    if (source == null || savePath.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            source == null
                ? 'Enter a magnet link or choose a .torrent file first.'
                : 'Set a default torrent path in Settings or choose a folder.',
          ),
        ),
      );
      return;
    }
    if (_isAdding) return;
    setState(() => _isAdding = true);
    try {
      final id = await widget.controller.addTorrent(source, savePath);
      final task = widget.controller.tasks.firstWhere(
        (t) => t.id == id,
        orElse: () => TorrentTask(id: id),
      );
      await _showDetails(task);
      _magnetController.clear();
      setState(() {
        _filePath = null;
        _pendingSource = null;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to add torrent: $e'),
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isAdding = false);
    }
  }

  Future<void> _confirmRemove(TorrentTask task) async {
    final result = await showRemoveTorrentDialog(context, task: task);
    if (result == null) return;
    widget.controller.remove(
      task.id,
      deleteData: result.deleteData,
      deleteTorrentFile: result.deleteTorrentFile,
    );
  }

  Future<void> _showDetails(TorrentTask task) async {
    // Pull the current file list from the engine so the dialog always shows
    // fresh content (size may be unknown until metadata arrives).
    final files = widget.controller.files(task.id);
    await showTorrentDetailsDialog(context, task: task, files: files);
    setState(() {});
  }

  /// Opens the torrent's downloaded file (or its folder for multi-file
  /// torrents) in the OS file manager. Desktop platforms only: url_launcher
  /// cannot open a file manager on Android/iOS, so mobile is left out for now.
  Future<void> _showInFolder(TorrentTask task) async {
    if (kIsWeb ||
        defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS) {
      return;
    }
    final destination = TorrentController.revealPath(
      task.savePath,
      widget.controller.files(task.id),
    );
    final ok = await launchUrl(Uri.file(destination));
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not open "$destination" in the file manager.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final tasks = widget.controller.tasks;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildHeader(context, tasks),
        const SizedBox(height: 22),
        _buildInput(context),
        const SizedBox(height: 22),
        Expanded(
          child: tasks.isEmpty
              ? _buildEmpty(context)
              : ListView(
                  children: [
                    for (final task in tasks)
                      TorrentCard(
                        task: task,
                        onPause: () => widget.controller.pause(task.id),
                        onResume: () => widget.controller.resume(task.id),
                        onRemove: () => _confirmRemove(task),
                        onDetails: () => _showDetails(task),
                        onShowInFolder: () => _showInFolder(task),
                      ),
                  ],
                ),
        ),
      ],
    );
  }

  Widget _buildHeader(BuildContext context, List<TorrentTask> tasks) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text('Torrents', style: TText.display(context, size: 30)),
        const SizedBox(width: 12),
        Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Text(
            'MAGNET / .TORRENT TRANSPORT',
            style: TText.mono(context, size: 10, color: TColors.textDim),
          ),
        ),
        const Spacer(),
        if (tasks.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text(
              '${tasks.length} ACTIVE',
              style: TText.mono(context, size: 10, color: TColors.green),
            ),
          ),
      ],
    );
  }

  Widget _buildInput(BuildContext context) {
    final primary = _pendingSource != null && _effectiveSavePath.isNotEmpty;
    return Container(
      decoration: BoxDecoration(
        color: TColors.panel2,
        border: Border.all(color: TColors.line),
      ),
      child: Column(
        children: [
          _field(
            context,
            icon: Icons.link,
            label: 'Magnet Link',
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _magnetController,
                    onSubmitted: (_) =>
                        _sourceFromMagnet(_magnetController.text),
                    style: TText.mono(context, size: 13, color: TColors.text),
                    cursorColor: TColors.amber,
                    decoration: const InputDecoration(
                      isCollapsed: true,
                      border: InputBorder.none,
                      hintText: 'paste magnet:?xt=urn:btih:…',
                      hintStyle: TextStyle(color: TColors.textDim),
                    ),
                  ),
                ),
                if (_filePath != null)
                  Text(
                    basename(_filePath!),
                    overflow: TextOverflow.ellipsis,
                    style: TText.mono(context, size: 12, color: TColors.green),
                  ),
                const SizedBox(width: 8),
                _chip(
                  context,
                  Icons.description_outlined,
                  'FROM FILE',
                  onTap: _pickFile,
                ),
              ],
            ),
          ),
          Divider(height: 1, color: TColors.lineSoft),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _pickSavePath,
            child: _field(
              context,
              icon: Icons.folder_outlined,
              label: 'Save Location',
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      _effectiveSavePath.isNotEmpty
                          ? _effectiveSavePath
                          : 'Not set — tap to choose folder',
                      overflow: TextOverflow.ellipsis,
                      style: TText.mono(
                        context,
                        size: 13,
                        color: _effectiveSavePath.isNotEmpty
                            ? TColors.amber
                            : TColors.textDim,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (_savePathOverridden)
                    GestureDetector(
                      onTap: _clearOverride,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: TColors.jackBg,
                          border: Border.all(color: TColors.line),
                        ),
                        child: Text(
                          'DEFAULT',
                          style: TText.mono(
                            context,
                            size: 9,
                            color: TColors.textDim,
                          ),
                        ),
                      ),
                    )
                  else
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: TColors.jackBg,
                        border: Border.all(color: TColors.line),
                      ),
                      child: Text(
                        'CHANGE',
                        style: TText.mono(
                          context,
                          size: 9,
                          color: TColors.amber,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          Divider(height: 1, color: TColors.lineSoft),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
            child: Row(
              children: [
                if (_pendingSource != null)
                  Expanded(
                    child: Text(
                      _pendingSource!.label,
                      overflow: TextOverflow.ellipsis,
                      style: TText.mono(
                        context,
                        size: 11,
                        color: TColors.green,
                      ),
                    ),
                  ),
                const Spacer(),
                GestureDetector(
                  onTap: _isAdding ? null : _add,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 9,
                    ),
                    decoration: BoxDecoration(
                      color: _isAdding
                          ? TColors.textDim
                          : (primary ? TColors.amber : TColors.lineSoft),
                      border: Border.all(color: TColors.line),
                    ),
                    child: _isAdding
                        ? SizedBox(
                            width: 11,
                            height: 11,
                            child: CircularProgressIndicator(
                              strokeWidth: 1.5,
                              color: TColors.textDim,
                            ),
                          )
                        : Text(
                            'ADD TORRENT',
                            style: TText.mono(
                              context,
                              size: 11,
                              weight: FontWeight.w600,
                              color: primary ? TColors.jackBg : TColors.textDim,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _field(
    BuildContext context, {
    required IconData icon,
    required String label,
    required Widget child,
  }) {
    return Padding(
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
            child: Icon(icon, size: 13, color: TColors.amber),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label.toUpperCase(),
                  style: TText.mono(
                    context,
                    size: 9.5,
                    letterSpacing: 0.1,
                    color: TColors.textDim,
                  ),
                ),
                const SizedBox(height: 4),
                child,
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _chip(
    BuildContext context,
    IconData icon,
    String label, {
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Row(
        children: [
          Icon(icon, size: 14, color: TColors.amber),
          const SizedBox(width: 5),
          Text(
            label,
            style: TText.mono(context, size: 10, color: TColors.amber),
          ),
        ],
      ),
    );
  }

  Widget _buildEmpty(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.bolt_outlined, size: 40, color: TColors.textDim),
          const SizedBox(height: 14),
          Text(
            'No torrents yet.',
            style: TText.body(context, size: 14, color: TColors.textMuted),
          ),
          const SizedBox(height: 6),
          Text(
            'Paste a magnet link or pick a .torrent file, choose a folder,\n'
            'and tap ADD TORRENT.',
            textAlign: TextAlign.center,
            style: TText.mono(context, size: 11, color: TColors.textDim),
          ),
        ],
      ),
    );
  }

  static String basename(String path) {
    final parts = path.split(RegExp(r'[/\\]'));
    return parts.isNotEmpty ? parts.last : path;
  }
}
