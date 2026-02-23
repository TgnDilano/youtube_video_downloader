import 'dart:async';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:ytdlapp/controllers/download_controller.dart';
import 'package:ytdlapp/controllers/settings_controller.dart';
import 'package:ytdlapp/ui/settings_page.dart';
import 'package:ytdlapp/ui/widgets/download_card.dart';
import 'package:ytdlapp/ui/widgets/input_area.dart';
import 'package:ytdlapp/ui/widgets/terminal_view.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:ytdlapp/models/download_task.dart';

class TubemateClone extends StatefulWidget {
  const TubemateClone({super.key});

  @override
  State<TubemateClone> createState() => _TubemateCloneState();
}

class _TubemateCloneState extends State<TubemateClone> {
  final DownloadController _controller = DownloadController();
  final SettingsController _settings = SettingsController();
  final TextEditingController _urlController = TextEditingController();
  final TextEditingController _playlistStartController =
      TextEditingController();
  final TextEditingController _playlistEndController = TextEditingController();

  String? _selectedPath;
  bool _isAudioOnly = false;
  bool _downloadFullPlaylist = true;
  bool _showTerminal = false;
  int _selectedIndex = 0;

  // Preview state
  Map<String, dynamic>? _currentPreview;
  bool _isFetchingPreview = false;
  String _selectedResolution = "best";
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _playlistStartController.text = '1';
    _playlistEndController.text = '10';

    _urlController.addListener(_onUrlChanged);

    _settings.addListener(() {
      if (mounted) {
        setState(() {
          _selectedPath ??= _settings.defaultDownloadPath;
          _selectedResolution = _settings.defaultResolution;
        });
      }
    });
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
      }
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _urlController.dispose();
    _playlistStartController.dispose();
    _playlistEndController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          // Sidebar
          NavigationRail(
            backgroundColor: const Color(0xFF1E1E1E),
            selectedIndex: _selectedIndex,
            onDestinationSelected: (idx) =>
                setState(() => _selectedIndex = idx),
            labelType: NavigationRailLabelType.all,
            leading: Padding(
              padding: const EdgeInsets.all(16.0),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.asset(
                  'assets/app_icon.png',
                  width: 40,
                  height: 40,
                  fit: BoxFit.cover,
                ),
              ),
            ),
            destinations: const [
              NavigationRailDestination(
                icon: Icon(Icons.home),
                label: Text('Home'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.settings),
                label: Text('Settings'),
              ),
            ],
          ),

          // Content
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(40.0),
              child: _selectedIndex == 0
                  ? _buildHome()
                  : SettingsPage(settings: _settings),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHome() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Welcome to Tubemate",
                  style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
                ),
                Text(
                  "Enter the url of a video and let the magic happen!",
                  style: TextStyle(color: Colors.grey),
                ),
              ],
            ),
            IconButton(
              icon: const Icon(Icons.terminal),
              onPressed: () => setState(() => _showTerminal = !_showTerminal),
              tooltip: "Toggle Terminal",
            ),
          ],
        ),
        const SizedBox(height: 24),

        // Input Section
        InputArea(
          urlController: _urlController,
          selectedPath: _selectedPath ?? _settings.defaultDownloadPath,
          onSelectFolder: () async {
            String? path = await FilePicker.platform.getDirectoryPath();
            if (path != null) setState(() => _selectedPath = path);
          },
          onStartDownload: _startNewDownload,
        ),

        if (_isFetchingPreview)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 20),
            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
          ),

        if (_currentPreview != null) _buildPreviewCard(),

        const SizedBox(height: 32),

        // Task List
        Expanded(
          flex: _showTerminal ? 2 : 1,
          child: DefaultTabController(
            length: 3,
            child: Column(
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: TabBar(
                        tabs: [
                          Tab(text: "Downloading"),
                          Tab(text: "History"),
                          Tab(text: "Failed"),
                        ],
                      ),
                    ),
                    TextButton.icon(
                      onPressed: () => _controller.clearAllHistory(),
                      icon: const Icon(Icons.delete_sweep_outlined, size: 18),
                      label: const Text("Clear All"),
                      style: TextButton.styleFrom(foregroundColor: Colors.grey),
                    ),
                  ],
                ),
                Expanded(
                  child: TabBarView(
                    children: [
                      _buildTaskList(filter: "downloading"),
                      _buildTaskList(filter: "completed"),
                      _buildTaskList(filter: "failed"),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        Visibility(
          visible: _showTerminal,
          child: Expanded(
            flex: 1,
            child: TerminalView(controller: _controller),
          ),
        ),
      ],
    );
  }

  Widget _buildPreviewCard() {
    final info = _currentPreview!;
    final bool isPlaylist = info['_type'] == 'playlist';

    // Extract best thumbnail
    String? thumbnailUrl = info['thumbnail'];
    if (thumbnailUrl == null && info['thumbnails'] != null) {
      final List thumbs = info['thumbnails'];
      if (thumbs.isNotEmpty) {
        thumbnailUrl = thumbs.last['url'];
      }
    }

    List<int> heights = [];
    if (!isPlaylist && info['formats'] != null) {
      for (var f in info['formats']) {
        if (f['height'] != null && f['vcodec'] != 'none') {
          int h = f['height'];
          if (!heights.contains(h)) heights.add(h);
        }
      }
    }
    heights.sort((a, b) => b.compareTo(a));
    // Limit to common resolutions
    final displayHeights = heights.take(5).toList();

    return Container(
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        children: [
          Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  thumbnailUrl ?? "",
                  width: 120,
                  height: 68,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) =>
                      Container(width: 120, height: 68, color: Colors.black),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      info['title'] ?? "Unknown Title",
                      style: const TextStyle(fontWeight: FontWeight.bold),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      isPlaylist
                          ? "Playlist • ${info['entries']?.length ?? info['n_entries'] ?? 'multiple'} items"
                          : "${info['uploader'] ?? ''} • ${info['duration_string'] ?? ''}",
                      style: const TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.open_in_new, size: 20),
                onPressed: () =>
                    launchUrl(Uri.parse(info['webpage_url'] ?? info['url'])),
              ),
            ],
          ),

          if (isPlaylist) ...[
            const Divider(height: 32, color: Colors.white10),
            Row(
              children: [
                const Text("Full Playlist", style: TextStyle(fontSize: 13)),
                Checkbox(
                  value: _downloadFullPlaylist,
                  onChanged: (v) =>
                      setState(() => _downloadFullPlaylist = v ?? true),
                  activeColor: Colors.green,
                ),
                const SizedBox(width: 16),
                if (!_downloadFullPlaylist) ...[
                  const Text(
                    "Range:",
                    style: TextStyle(fontSize: 13, color: Colors.grey),
                  ),
                  const SizedBox(width: 12),
                  SizedBox(
                    width: 60,
                    child: TextField(
                      controller: _playlistStartController,
                      textAlign: TextAlign.center,
                      decoration: const InputDecoration(
                        isDense: true,
                        hintText: "1",
                      ),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8),
                    child: Text("to"),
                  ),
                  SizedBox(
                    width: 60,
                    child: TextField(
                      controller: _playlistEndController,
                      textAlign: TextAlign.center,
                      decoration: const InputDecoration(
                        isDense: true,
                        hintText: "10",
                      ),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                ],
                const Spacer(),
                const Text("Audio Only", style: TextStyle(fontSize: 13)),
                Switch(
                  value: _isAudioOnly,
                  onChanged: (v) => setState(() => _isAudioOnly = v),
                  activeThumbColor: Colors.green,
                ),
                const SizedBox(width: 16),
                ElevatedButton.icon(
                  onPressed: _startNewDownload,
                  icon: const Icon(Icons.download, size: 18),
                  label: const Text("Download"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ],
            ),
          ] else ...[
            const Divider(height: 32, color: Colors.white10),
            Row(
              children: [
                const Text(
                  "Format:",
                  style: TextStyle(fontSize: 13, color: Colors.grey),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.black26,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _buildResolutionChip("audio", "Audio (MP3)"),
                          const VerticalDivider(
                            width: 16,
                            color: Colors.white10,
                            thickness: 1,
                          ),
                          _buildResolutionChip("best", "Best Video"),
                          ...displayHeights.map(
                            (h) => _buildResolutionChip(h.toString(), "${h}p"),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                ElevatedButton.icon(
                  onPressed: _startNewDownload,
                  icon: const Icon(Icons.download, size: 18),
                  label: const Text("Download"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildResolutionChip(String value, String label) {
    bool isSelected = _selectedResolution == value;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedResolution = value;
          _isAudioOnly = value == "audio";
        });
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? Colors.green : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            color: isSelected ? Colors.white : Colors.grey,
          ),
        ),
      ),
    );
  }

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

        return ListView.builder(
          itemCount: tasks.length,
          itemBuilder: (context, index) => DownloadCard(
            task: tasks[index],
            onRemove: () => _controller.removeTask(tasks[index]),
            onRetry: () => _controller.retryTask(tasks[index]),
          ),
        );
      },
    );
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
      final int? start = _downloadFullPlaylist
          ? null
          : int.tryParse(_playlistStartController.text);
      final int? end = _downloadFullPlaylist
          ? null
          : int.tryParse(_playlistEndController.text);

      _controller.addDownload(
        url,
        path,
        _isAudioOnly,
        isPlaylist: true,
        playlistStart: start,
        playlistEnd: end,
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
