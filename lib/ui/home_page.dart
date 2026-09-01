import 'dart:async';
import 'dart:math' show max;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:ytdlapp/controllers/download_controller.dart';
import 'package:ytdlapp/controllers/convert_controller.dart';
import 'package:ytdlapp/controllers/settings_controller.dart';
import 'package:ytdlapp/models/download_task.dart';
import 'package:ytdlapp/ui/app_theme.dart';
import 'package:ytdlapp/ui/convert_page.dart';
import 'package:ytdlapp/ui/settings_page.dart';
import 'package:ytdlapp/ui/widgets/download_card.dart';
import 'package:ytdlapp/ui/widgets/input_area.dart';
import 'package:ytdlapp/ui/widgets/cookie_consent_dialog.dart';
import 'package:ytdlapp/ui/widgets/playlist_options_dialog.dart';
import 'package:ytdlapp/ui/widgets/resolution_dialog.dart';
import 'package:ytdlapp/ui/widgets/terminal_view.dart';
import 'package:ytdlapp/ui/widgets/tubemate_controls.dart';
import 'package:ytdlapp/ui/widgets/tubemate_sidebar.dart';

class TubemateClone extends StatefulWidget {
  const TubemateClone({super.key});

  @override
  State<TubemateClone> createState() => _TubemateCloneState();
}

class _TubemateCloneState extends State<TubemateClone> {
  final DownloadController _controller = DownloadController();
  final ConvertController _convertController = ConvertController();
  final SettingsController _settings = SettingsController();
  final TextEditingController _urlController = TextEditingController();
  final FocusNode _urlFocusNode = FocusNode();

  String? _selectedPath;
  bool _isAudioOnly = false;
  bool _downloadFullPlaylist = true;
  bool _showTerminal = false;
  int _selectedIndex = 0;
  int _activeTab = 0;
  double _terminalHeight = 250;

  // Preview state
  Map<String, dynamic>? _currentPreview;
  bool _isFetchingPreview = false;
  String _selectedResolution = "best";
  Set<int> _selectedPlaylistItems = {};
  Map<int, String> _itemResolutions = {};
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _urlController.addListener(_onUrlChanged);
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _urlFocusNode.requestFocus(),
    );

    _settings.addListener(() {
      if (mounted) {
        setState(() {
          _selectedPath ??= _settings.defaultDownloadPath;
          _selectedResolution = _settings.defaultResolution;
        });
      }
    });

    _controller.addListener(_onControllerChanged);
    _controller.cookieConsentRequester = _requestCookieConsent;
  }

  Future<bool> _requestCookieConsent() async {
    if (!mounted) return false;
    final browser = await _controller.cookieBrowserToUse();
    if (!mounted) return false;
    return showCookieConsentDialog(context, browser);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.removeListener(_onControllerChanged);
    _urlController.dispose();
    _urlFocusNode.dispose();
    super.dispose();
  }

  void _onControllerChanged() {
    final notifications = _controller.consumePendingNotifications();
    if (notifications.isEmpty || !mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          backgroundColor: TColors.red.withValues(alpha: 0.15),
          content: Row(
            children: [
              Expanded(
                child: Text(notifications.join('\n')),
              ),
              GestureDetector(
                onTap: () {
                  Clipboard.setData(
                    ClipboardData(text: notifications.join('\n')),
                  );
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Error copied'),
                      duration: Duration(seconds: 2),
                    ),
                  );
                },
                child: MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: Text(
                    'COPY',
                    style: TText.mono(
                      context,
                      size: 11,
                      color: TColors.textDim,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              GestureDetector(
                onTap: () {
                  final failed = _controller.failedTasks;
                  if (failed.isNotEmpty) {
                    _controller.retryTask(failed.first);
                  }
                },
                child: MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: Text(
                    'RETRY',
                    style: TText.mono(
                      context,
                      size: 11,
                      color: TColors.green,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
  }

  void _onUrlChanged() {
    final url = _urlController.text.trim();
    if (url.isNotEmpty && _settings.isAutoPreviewEnabled) {
      if (_currentPreview == null || _currentPreview!['webpage_url'] != url) {
        _debounce?.cancel();
        _debounce = Timer(const Duration(milliseconds: 500), () {
          _fetchPreview(url);
        });
      }
    } else if (url.isEmpty) {
      _debounce?.cancel();
      setState(() => _currentPreview = null);
    }
  }

  Future<void> _fetchPreview(String url) async {
    setState(() {
      _isFetchingPreview = true;
      _currentPreview = null;
    });

    final info = await _controller.fetchVideoInfo(url);
    if (!mounted) return;

    setState(() {
      _isFetchingPreview = false;
      _currentPreview = info;
      if (info != null) {
        // Reset resolution to default when new video is fetched
        _selectedResolution = _settings.defaultResolution;
        // Default selection: every playlist item
        final entries = info['entries'];
        _selectedPlaylistItems = entries is List
            ? {for (var i = 1; i <= entries.length; i++) i}
            : {};
        _itemResolutions = {};
      }
    });
  }

  bool get _isTransportActive => _controller.tasks.any(
        (t) =>
            t.status == DownloadStatus.downloading ||
            t.status == DownloadStatus.queued,
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          TubemateSidebar(
            selectedIndex: _selectedIndex,
            onDestinationSelected: (idx) =>
                setState(() => _selectedIndex = idx),
          ),
          Expanded(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1180),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(34, 30, 34, 24),
                  child: _selectedIndex == 0
                      ? _buildHome()
                      : _selectedIndex == 1
                          ? ConvertPage(controller: _convertController)
                          : SettingsPage(settings: _settings, controller: _controller),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------- Home

  Widget _buildHome() {
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildHeader(),
              const SizedBox(height: 26),
              InputArea(
                urlController: _urlController,
                urlFocusNode: _urlFocusNode,
                selectedPath: _selectedPath ?? _settings.defaultDownloadPath,
                onSelectFolder: () async {
                  String? path = await FilePicker.platform.getDirectoryPath();
                  if (path != null) setState(() => _selectedPath = path);
                },
                onUrlSubmitted: _onUrlSubmitted,
                onStartDownload: _startNewDownload,
              ),

              if (_isFetchingPreview)
                Padding(
                  padding: const EdgeInsets.only(top: 18),
                  child: Row(
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: TColors.green,
                          boxShadow: [
                            BoxShadow(color: TColors.green, blurRadius: 6),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'FETCHING PREVIEW…',
                        style: TText.mono(
                          context,
                          size: 11,
                          color: TColors.textDim,
                        ),
                      ),
                    ],
                  ),
                ),

              if (_currentPreview != null) _buildCassetteCard(),

              const SizedBox(height: 30),
              _buildTabs(context),
            ],
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.only(top: 18),
          sliver: SliverLayoutBuilder(
            builder: (context, constraints) {
              final remaining = max(
                0.0,
                constraints.viewportMainAxisExtent -
                    constraints.precedingScrollExtent,
              );
              final taskH = max(200.0, remaining);
              return SliverToBoxAdapter(
                child: SizedBox(
                  height: taskH,
                  child: _buildTaskArea(taskH),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildTaskArea(double height) {
    if (_showTerminal) {
      final handleH = 8.0;
      final termMin = 100.0;
      final maxTerm =
          (height - handleH - termMin).clamp(0.0, height - handleH);
      final termH = maxTerm <= termMin
          ? maxTerm
          : _terminalHeight.clamp(termMin, maxTerm);
      final taskH = (height - termH - handleH).clamp(0.0, height);
      return Column(
        children: [
          SizedBox(
            height: taskH,
            child: IndexedStack(
              index: _activeTab,
              children: [
                _buildTaskList(filter: "downloading"),
                _buildTaskList(filter: "completed"),
                _buildTaskList(filter: "failed"),
              ],
            ),
          ),
          GestureDetector(
            onVerticalDragUpdate: (details) {
              setState(() {
                _terminalHeight -= details.delta.dy;
              });
            },
            child: MouseRegion(
              cursor: SystemMouseCursors.resizeUpDown,
              child: Container(
                height: handleH,
                color: TColors.line,
                child: Center(
                  child: Container(
                    width: 30,
                    height: 2,
                    color: TColors.textDim,
                  ),
                ),
              ),
            ),
          ),
          SizedBox(
            height: termH,
            child: TerminalView(controller: _controller),
          ),
        ],
      );
    }
    return IndexedStack(
      index: _activeTab,
      children: [
        _buildTaskList(filter: "downloading"),
        _buildTaskList(filter: "completed"),
        _buildTaskList(filter: "failed"),
      ],
    );
  }

  Widget _buildHeader() {
    final active = _isTransportActive;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.only(bottom: 18),
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: TColors.line)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      active
                          ? 'Media Transport / Active'
                          : 'Media Transport / Idle',
                      style: TText.mono(
                        context,
                        size: 11,
                        letterSpacing: 0.18,
                        color: TColors.amber,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'TubeXMate',
                      style: TText.display(context, size: 30),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Drop in a URL, set your range, hit record.',
                      style: TText.body(context, size: 13.5, color: TColors.textMuted),
                    ),
                  ],
                ),
              ),
              Row(
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: active ? TColors.amber : TColors.green,
                      boxShadow: [
                        BoxShadow(
                          color: active ? TColors.amber : TColors.green,
                          blurRadius: 6,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    active ? 'Capturing stream' : 'Ready to capture',
                    style: TText.mono(context, size: 11, color: TColors.textDim),
                  ),
                  const SizedBox(width: 12),
                  IconButton(
                    onPressed: () =>
                        setState(() => _showTerminal = !_showTerminal),
                    icon: const Icon(
                      Icons.terminal,
                      size: 16,
                      color: TColors.textDim,
                    ),
                    visualDensity: VisualDensity.compact,
                    tooltip: 'Toggle Terminal',
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ------------------------------------------------------- Cassette card

  Widget _buildCassetteCard() {
    final info = _currentPreview!;
    final bool isPlaylist = info['_type'] == 'playlist';

    final String thumbnailUrl = _previewThumb(info);

    final entryCount = isPlaylist
        ? (info['entries']?.length ??
            info['n_entries'] ??
            (info['entries'] == null ? null : 0))
        : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 18),
        Container(
          decoration: BoxDecoration(
            color: TColors.panel2,
            border: Border.all(color: TColors.line),
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(18),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _Thumbnail(url: thumbnailUrl, tag: isPlaylist ? 'Playlist' : 'Video'),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isPlaylist
                                ? 'Playlist · ${entryCount ?? '…'} items'
                                : '${info['uploader'] ?? 'YouTube'} · ${info['duration_string'] ?? ''}'
                                    .toUpperCase(),
                            style: TText.mono(
                              context,
                              size: 9.5,
                              letterSpacing: 0.08,
                              color: TColors.textDim,
                            ),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            info['title'] ?? 'Unknown Title',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TText.display(
                              context,
                              size: 19,
                              weight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            isPlaylist
                                ? (info['description']?.toString() ??
                                    (info['entries'] is List &&
                                            (info['entries'] as List).isNotEmpty
                                        ? ((info['entries'] as List).first['title']
                                                ?.toString() ??
                                            '')
                                        : ''))
                                : '${info['uploader'] ?? ''} · ${info['duration_string'] ?? ''}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TText.body(
                              context,
                              size: 12.5,
                              color: TColors.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    _OpenLinkButton(
                      onPressed: () {
                        final url = info['webpage_url'] ?? info['url'];
                        if (url != null) launchUrl(Uri.parse(url));
                      },
                    ),
                  ],
                ),
              ),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                decoration: const BoxDecoration(
                  color: TColors.counterBg,
                  border: Border(top: BorderSide(color: TColors.lineSoft)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: isPlaylist
                          ? _buildPlaylistControls(context)
                          : _buildResolutionSelector(context),
                    ),
                    const SizedBox(width: 20),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Audio only',
                          style: TText.mono(
                            context,
                            size: 10.5,
                            letterSpacing: 0.08,
                            color: TColors.textDim,
                          ),
                        ),
                        const SizedBox(width: 9),
                        TubemateSwitch(
                          value: _isAudioOnly,
                          onChanged: (v) => setState(() {
                            _isAudioOnly = v;
                            if (v) {
                              _selectedResolution = 'audio';
                            } else if (_selectedResolution == 'audio') {
                              _selectedResolution = _settings.defaultResolution;
                            }
                          }),
                        ),
                        const SizedBox(width: 20),
                        RecordButton(onPressed: _startNewDownload),
                      ],
                    ),
                  ],
                ),
              ),
              if (isPlaylist) _buildPlaylistSelector(context),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPlaylistControls(BuildContext context) {
    final total = _playlistEntryCount;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        MonoCheckbox(
          value: _downloadFullPlaylist,
          label: 'Full playlist',
          onTap: () => setState(
            () => _downloadFullPlaylist = !_downloadFullPlaylist,
          ),
        ),
        if (!_downloadFullPlaylist && total > 0) ...[
          const SizedBox(width: 18),
          Text(
            '${_selectedPlaylistItems.length} / $total selected',
            style: TText.mono(context, size: 11, color: TColors.textMuted),
          ),
        ],
      ],
    );
  }

  int get _playlistEntryCount {
    final entries = _currentPreview?['entries'];
    return entries is List ? entries.length : 0;
  }

  /// Selector panel listing every playlist item with a checkbox.
  Widget _buildPlaylistSelector(BuildContext context) {
    final entries = _currentPreview?['entries'];
    if (entries is! List || entries.isEmpty) {
      return const SizedBox.shrink();
    }

    final total = entries.length;
    final selectedCount = _selectedPlaylistItems.length;
    final allSelected = selectedCount == total;

    return Container(
      decoration: const BoxDecoration(
        color: TColors.counterBg,
        border: Border(top: BorderSide(color: TColors.lineSoft)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 10, 10, 4),
            child: Row(
              children: [
                Text(
                  'TRACKS'.toUpperCase(),
                  style: TText.mono(
                    context,
                    size: 9.5,
                    letterSpacing: 0.1,
                    color: TColors.textDim,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _downloadFullPlaylist
                        ? 'Downloading all'
                        : '$selectedCount of $total selected',
                    style: TText.mono(
                      context,
                      size: 10,
                      color: _downloadFullPlaylist
                          ? TColors.greenDim
                          : TColors.textMuted,
                    ),
                  ),
                ),
                _SelectorAction(
                  label: allSelected ? 'Clear' : 'Select all',
                  enabled: !_downloadFullPlaylist,
                  onTap: () => setState(() {
                    if (allSelected) {
                      _selectedPlaylistItems = {};
                    } else {
                      _selectedPlaylistItems = {
                        for (var i = 1; i <= total; i++) i
                      };
                    }
                  }),
                ),
              ],
            ),
          ),
          if (!_downloadFullPlaylist)
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 240),
              child: ListView.builder(
                shrinkWrap: true,
                padding: const EdgeInsets.only(bottom: 6),
                itemCount: entries.length,
                itemBuilder: (context, index) {
                  final entry = entries[index] as Map? ?? {};
                  final itemIndex = index + 1;
                  final selected =
                      _selectedPlaylistItems.contains(itemIndex);
                  return _PlaylistItemRow(
                    index: itemIndex,
                    title: entry['title']?.toString() ?? 'Untitled item',
                    duration: _formatDuration(entry['duration']),
                    thumbnailUrl: _entryThumb(entry),
                    selected: selected,
                    resolutionLabel: _itemResolutionLabel(itemIndex),
                    resolutionExplicit: _itemResolutionExplicit(itemIndex),
                    onTap: () => setState(() {
                      if (selected) {
                        _selectedPlaylistItems.remove(itemIndex);
                      } else {
                        _selectedPlaylistItems.add(itemIndex);
                      }
                    }),
                    onSelectResolution:
                        entry['url'] != null || entry['webpage_url'] != null
                            ? () => _pickItemResolution(context, entry, itemIndex)
                            : null,
                  );
                },
              ),
            ),
        ],
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

  String _entryThumb(Map entry) {
    final thumb = entry['thumbnail'];
    if (thumb is String && thumb.isNotEmpty) return thumb;
    final thumbs = entry['thumbnails'];
    if (thumbs is List && thumbs.isNotEmpty) {
      final last = thumbs.last;
      if (last is Map) return last['url']?.toString() ?? '';
    }
    return '';
  }

  String _itemResolutionLabel(int index) {
    final res = _itemResolutions[index] ?? _settings.defaultResolution;
    if (res == 'audio') return 'Audio';
    return res == 'best' ? 'Best' : '${res}p';
  }

  bool _itemResolutionExplicit(int index) =>
      _itemResolutions.containsKey(index);

  Future<void> _pickItemResolution(
    BuildContext context,
    Map entry,
    int index,
  ) async {
    final url = (entry['url'] ?? entry['webpage_url'])?.toString();
    if (url == null || url.isEmpty) return;

    final chosen = await showDialog<String>(
      context: context,
      builder: (_) => ResolutionDialog(
        controller: _controller,
        url: url,
        title: entry['title']?.toString() ?? 'Untitled item',
        duration: _formatDuration(entry['duration']),
        thumbnailUrl: _entryThumb(entry),
        itemIndex: index,
        current: _itemResolutions[index] ?? _settings.defaultResolution,
      ),
    );
    if (chosen != null && mounted) {
      setState(() => _itemResolutions[index] = chosen);
    }
  }

  Widget _buildResolutionSelector(BuildContext context) {
    final sizeLabel = _previewSizeLabel();
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _ResChipButton(
          label: _singleResolutionLabel,
          explicit: _singleResolutionExplicit,
          onTap: () => _pickSingleResolution(context),
        ),
        if (sizeLabel.isNotEmpty) ...[
          const SizedBox(width: 12),
          Text(
            sizeLabel,
            style: TText.mono(context, size: 10.5, color: TColors.textMuted),
          ),
        ],
      ],
    );
  }

  String get _singleResolutionLabel {
    if (_selectedResolution == 'audio') return 'Audio MP3';
    if (_selectedResolution == 'best') return 'Best';
    return '${_selectedResolution}p';
  }

  /// Estimated size of the currently selected resolution, from the preview's
  /// format list. Empty when unknown.
  String _previewSizeLabel() {
    final info = _currentPreview;
    if (info == null) return '';
    final size = DownloadController.estimateSizeForResolution(
      info,
      _selectedResolution,
    );
    if (size == null || size <= 0) return '';
    return DownloadController.formatBytes(size);
  }

  bool get _singleResolutionExplicit =>
      _selectedResolution != _settings.defaultResolution;

  String _previewThumb(Map info) {
    final thumb = info['thumbnail'];
    if (thumb is String && thumb.isNotEmpty) return thumb;
    final thumbs = info['thumbnails'];
    if (thumbs is List && thumbs.isNotEmpty) {
      final last = thumbs.last;
      if (last is Map) return last['url']?.toString() ?? '';
    }
    return '';
  }

  Future<void> _pickSingleResolution(BuildContext context) async {
    final info = _currentPreview!;
    final url = info['webpage_url'] ?? info['url'];
    if (url == null) return;

    final chosen = await showDialog<String>(
      context: context,
      builder: (_) => ResolutionDialog(
        controller: _controller,
        url: url.toString(),
        title: info['title']?.toString() ?? 'Unknown Title',
        duration: _formatDuration(info['duration']),
        thumbnailUrl: _previewThumb(info),
        current: _selectedResolution,
        showAudio: true,
        preloadedInfo: info,
      ),
    );
    if (chosen != null && mounted) {
      setState(() {
        if (chosen == 'audio') {
          _isAudioOnly = true;
          _selectedResolution = 'audio';
        } else {
          _isAudioOnly = false;
          _selectedResolution = chosen;
        }
      });
    }
  }

  // ------------------------------------------------------------- Tabs

  Widget _buildTabs(BuildContext context) {
    final counts = [
      _controller.downloadingTasks.length,
      _controller.completedTasks.length,
      _controller.failedTasks.length,
    ];
    final labels = ['Downloading', 'History', 'Failed'];

    return Container(
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: TColors.line)),
      ),
      child: Row(
        children: [
          for (var i = 0; i < labels.length; i++) ...[
            _TabItem(
              label: labels[i],
              count: counts[i],
              active: _activeTab == i,
              onTap: () => setState(() => _activeTab = i),
            ),
            const SizedBox(width: 30),
          ],
          const Spacer(),
          InkWell(
            onTap: () => _controller.clearAllHistory(),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
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
                    'Clear all',
                    style: TText.mono(
                      context,
                      size: 11,
                      color: TColors.textDim,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ----------------------------------------------------------- Task list

  Widget _buildTaskList({required String filter}) {
    return ListenableBuilder(
      listenable: _controller,
      builder: (context, _) {
        List<DownloadTask> tasks;
        if (filter == "downloading") {
          tasks = _controller.downloadingTasks;
        } else if (filter == "completed") {
          tasks = _controller.completedTasks;
        } else {
          tasks = _controller.failedTasks;
        }

        if (tasks.isEmpty) {
          return Center(
            child: Text(
              'NO ITEMS IN THIS LANE',
              style: TText.mono(context, size: 11, color: TColors.textDim),
            ),
          );
        }

        return ListView.builder(
          itemCount: tasks.length,
          itemBuilder: (context, index) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: DownloadCard(
              task: tasks[index],
              onRemove: () => _controller.removeTask(tasks[index]),
              onRetry: () => _controller.retryTask(tasks[index]),
              onPause: () => _controller.pauseTask(tasks[index]),
              onResume: () => _controller.resumeTask(tasks[index]),
            ),
          ),
        );
      },
    );
  }

  // ----------------------------------------------------------- Actions

  /// Enter in the URL field: fetch the preview if needed, let the user pick
  /// options (resolution / playlist items) and only then queue the download.
  Future<void> _onUrlSubmitted() async {
    final url = _urlController.text.trim();
    if (url.isEmpty) return;

    _debounce?.cancel();

    if (_currentPreview == null || _currentPreview!['webpage_url'] != url) {
      await _fetchPreview(url);
      if (!mounted) return;
    }
    final info = _currentPreview;
    if (info == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Couldn't fetch video info — check the link"),
        ),
      );
      return;
    }

    if (info['_type'] == 'playlist') {
      final proceed = await _showPlaylistOptions(url, info);
      if (!proceed || !mounted) return;
    } else {
      final proceed = await _showSingleVideoOptions(url, info);
      if (!proceed || !mounted) return;
    }
    _startNewDownload();
  }

  /// Returns true when the user picked an option (download should queue).
  Future<bool> _showSingleVideoOptions(
    String url,
    Map<String, dynamic> info,
  ) async {
    final videoUrl = (info['webpage_url'] ?? info['url'])?.toString() ?? url;
    final chosen = await showDialog<String>(
      context: context,
      builder: (_) => ResolutionDialog(
        controller: _controller,
        url: videoUrl,
        title: info['title']?.toString() ?? 'Unknown Title',
        duration: _formatDuration(info['duration']),
        thumbnailUrl: _previewThumb(info),
        current: _selectedResolution == 'audio'
            ? 'audio'
            : _settings.defaultResolution,
        showAudio: true,
        preloadedInfo: info,
      ),
    );
    if (chosen == null || !mounted) return false;
    setState(() {
      if (chosen == 'audio') {
        _isAudioOnly = true;
        _selectedResolution = 'audio';
      } else {
        _isAudioOnly = false;
        _selectedResolution = chosen;
      }
    });
    return true;
  }

  /// Returns true when the user confirmed the playlist options.
  Future<bool> _showPlaylistOptions(
    String url,
    Map<String, dynamic> info,
  ) async {
    final entries = info['entries'];
    if (entries is! List || entries.isEmpty) {
      return true;
    }
    final opts = await showDialog<PlaylistOptions>(
      context: context,
      builder: (_) => PlaylistOptionsDialog(
        controller: _controller,
        url: url,
        title: info['title']?.toString() ?? 'Playlist',
        thumbnailUrl: _previewThumb(info),
        entries: entries,
        initialFullPlaylist: _downloadFullPlaylist,
        initialSelection: _selectedPlaylistItems,
        initialResolution: _settings.defaultResolution,
        initialAudioOnly: _isAudioOnly,
      ),
    );
    if (opts == null || !mounted) return false;
    setState(() {
      _downloadFullPlaylist = opts.fullPlaylist;
      _selectedPlaylistItems = opts.selectedItems;
      _isAudioOnly = opts.audioOnly;
      _selectedResolution =
          opts.audioOnly ? 'audio' : opts.resolution;
    });
    return true;
  }

  void _startNewDownload() async {
    final path = _selectedPath ?? _settings.defaultDownloadPath;
    if (path == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please select a folder first!")),
      );
      return;
    }

    final String url = _urlController.text.trim();
    if (url.isEmpty) return;

    if (_currentPreview != null && _currentPreview!['_type'] == 'playlist') {
      String? playlistItems;
      if (!_downloadFullPlaylist) {
        if (_selectedPlaylistItems.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Select at least one item to download"),
            ),
          );
          return;
        }
        final sorted = _selectedPlaylistItems.toList()..sort();
        playlistItems = sorted.join(',');
      }

      _controller.addDownload(
        url,
        path,
        _isAudioOnly,
        isPlaylist: true,
        playlistItems: playlistItems,
        resolution: _selectedResolution == "audio"
            ? "best"
            : _selectedResolution,
        itemResolutions: _itemResolutions.isEmpty
            ? null
            : {
                for (final e in _itemResolutions.entries) '${e.key}': e.value,
              },
        metadata:
            _currentPreview, // Pass metadata to include title for subfolder
      );
    } else {
      _controller.addDownload(
        url,
        path,
        _selectedResolution == "audio",
        metadata: _currentPreview,
        resolution: _selectedResolution == "audio"
            ? "best"
            : _selectedResolution,
      );
    }

    _urlController.clear();
    setState(() {
      _currentPreview = null;
      _isAudioOnly = false;
      _selectedResolution = _settings.defaultResolution;
    });
  }
}

// -------------------------------------------------------------- Sub widgets

class _TabItem extends StatelessWidget {
  final String label;
  final int count;
  final bool active;
  final VoidCallback onTap;

  const _TabItem({
    required this.label,
    required this.count,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: active ? TColors.amber : Colors.transparent,
              width: 2,
            ),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label.toUpperCase(),
              style: TText.mono(
                context,
                size: 11.5,
                letterSpacing: 0.08,
                color: active ? TColors.amber : TColors.textDim,
              ),
            ),
            const SizedBox(width: 7),
            Text(
              '· ${count.toString().padLeft(2, '0')}',
              style: TText.mono(
                context,
                size: 10,
                color: active ? TColors.amber : TColors.textDim,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Thumbnail extends StatelessWidget {
  final String? url;
  final String? tag;
  final double width;
  final double height;

  const _Thumbnail({
    required this.url,
    this.tag,
    this.width = 108,
    this.height = 72,
  });

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
          if (tag != null)
            Positioned(
              top: 5,
              left: 6,
              child: Container(
                color: const Color(0x59FFFFFF),
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                child: Text(
                  tag!.toUpperCase(),
                  style: TText.mono(
                    context,
                    size: 7,
                    letterSpacing: 0.06,
                    color: Colors.white.withValues(alpha: 0.85),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _OpenLinkButton extends StatefulWidget {
  final VoidCallback onPressed;

  const _OpenLinkButton({required this.onPressed});

  @override
  State<_OpenLinkButton> createState() => _OpenLinkButtonState();
}

class _OpenLinkButtonState extends State<_OpenLinkButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: InkWell(
        onTap: widget.onPressed,
        child: Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            border: Border.all(
              color: _hovered ? TColors.amber : TColors.line,
            ),
          ),
          child: Icon(
            Icons.open_in_new,
            size: 13,
            color: _hovered ? TColors.amber : TColors.textDim,
          ),
        ),
      ),
    );
  }
}

class _SelectorAction extends StatelessWidget {
  final String label;
  final bool enabled;
  final VoidCallback onTap;

  const _SelectorAction({
    required this.label,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: enabled ? onTap : null,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Text(
          label.toUpperCase(),
          style: TText.mono(
            context,
            size: 10,
            letterSpacing: 0.06,
            color: enabled ? TColors.textMuted : TColors.textDim,
          ),
        ),
      ),
    );
  }
}

class _PlaylistItemRow extends StatelessWidget {
  final int index;
  final String title;
  final String duration;
  final String thumbnailUrl;
  final bool selected;
  final String resolutionLabel;
  final bool resolutionExplicit;
  final VoidCallback onTap;
  final VoidCallback? onSelectResolution;

  const _PlaylistItemRow({
    required this.index,
    required this.title,
    required this.duration,
    required this.thumbnailUrl,
    required this.selected,
    required this.resolutionLabel,
    required this.resolutionExplicit,
    required this.onTap,
    this.onSelectResolution,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        color: selected
            ? TColors.amber.withValues(alpha: 0.04)
            : Colors.transparent,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
        child: Row(
          children: [
            CheckSquare(value: selected),
            const SizedBox(width: 12),
            _Thumbnail(url: thumbnailUrl, width: 56, height: 32),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    index.toString().padLeft(2, '0'),
                    style: TText.mono(
                      context,
                      size: 9,
                      letterSpacing: 0.08,
                      color: TColors.textDim,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TText.body(
                      context,
                      size: 12.5,
                      color: selected ? TColors.text : TColors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            _ResChipButton(
              label: resolutionLabel,
              explicit: resolutionExplicit,
              onTap: onSelectResolution,
            ),
            const SizedBox(width: 12),
            Text(
              duration,
              style: TText.mono(context, size: 10.5, color: TColors.textMuted),
            ),
          ],
        ),
      ),
    );
  }
}

/// Mono chip that opens the per-item quality dialog.
class _ResChipButton extends StatefulWidget {
  final String label;
  final bool explicit;
  final VoidCallback? onTap;

  const _ResChipButton({
    required this.label,
    required this.explicit,
    this.onTap,
  });

  @override
  State<_ResChipButton> createState() => _ResChipButtonState();
}

class _ResChipButtonState extends State<_ResChipButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null;
    return MouseRegion(
      cursor:
          enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
      onEnter: enabled ? (_) => setState(() => _hovered = true) : null,
      onExit: enabled ? (_) => setState(() => _hovered = false) : null,
      child: InkWell(
        onTap: widget.onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: TColors.jackBg,
            border: Border.all(
              color: _hovered && enabled ? TColors.amber : TColors.line,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                widget.label,
                style: TText.mono(
                  context,
                  size: 10.5,
                  color: widget.explicit
                      ? TColors.amber
                      : TColors.textMuted,
                ),
              ),
              const SizedBox(width: 4),
              Icon(
                Icons.arrow_drop_down,
                size: 13,
                color: enabled ? TColors.textDim : TColors.line,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
