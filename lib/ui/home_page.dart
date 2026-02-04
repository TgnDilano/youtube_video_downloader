import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:ytdlapp/controllers/download_controller.dart';
import 'package:ytdlapp/controllers/settings_controller.dart';
import 'package:ytdlapp/ui/settings_page.dart';
import 'package:ytdlapp/ui/widgets/download_card.dart';
import 'package:ytdlapp/ui/widgets/input_area.dart';
import 'package:ytdlapp/ui/widgets/terminal_view.dart';
import 'package:url_launcher/url_launcher.dart';

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
  bool _isPlaylist = false;
  bool _showTerminal = false;
  int _selectedIndex = 0;

  // Preview state
  Map<String, dynamic>? _currentPreview;
  bool _isFetchingPreview = false;
  String _selectedResolution = "best";

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
        _fetchPreview(url);
      }
    } else if (url.isEmpty) {
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
            leading: const Padding(
              padding: EdgeInsets.all(16.0),
              child: Icon(
                Icons.play_circle_fill,
                color: Colors.green,
                size: 40,
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
          playlistStartController: _playlistStartController,
          playlistEndController: _playlistEndController,
          selectedPath: _selectedPath ?? _settings.defaultDownloadPath,
          isAudioOnly: _isAudioOnly,
          isPlaylist: _isPlaylist,
          onAudioOnlyChanged: (value) => setState(() => _isAudioOnly = value),
          onPlaylistChanged: (value) => setState(() => _isPlaylist = value),
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

        if (_currentPreview != null && !_isPlaylist) _buildPreviewCard(),

        const SizedBox(height: 32),

        // Task List
        Expanded(
          flex: _showTerminal ? 2 : 1,
          child: DefaultTabController(
            length: 2,
            child: Column(
              children: [
                const TabBar(
                  tabs: [
                    Tab(text: "Downloading"),
                    Tab(text: "History"),
                  ],
                ),
                Expanded(
                  child: TabBarView(
                    children: [
                      _buildTaskList(_controller.downloadingTasks),
                      _buildTaskList(_controller.completedTasks),
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
    List<int> heights = [];
    if (info['formats'] != null) {
      for (var f in info['formats']) {
        if (f['height'] != null && f['vcodec'] != 'none') {
          int h = f['height'];
          if (!heights.contains(h)) heights.add(h);
        }
      }
    }
    heights.sort((a, b) => b.compareTo(a));
    // Limit to common resolutions for the selector
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
                  info['thumbnail'] ?? "",
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
                      "${info['uploader'] ?? ''} • ${info['duration_string'] ?? ''}",
                      style: const TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.open_in_new, size: 20),
                onPressed: () => launchUrl(Uri.parse(info['webpage_url'])),
              ),
            ],
          ),
          if (!_isAudioOnly) ...[
            const Divider(height: 32, color: Colors.white10),
            Row(
              children: [
                const Text(
                  "Resolution:",
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
                          _buildResolutionChip("best", "Best"),
                          ...displayHeights.map(
                            (h) => _buildResolutionChip(h.toString(), "${h}p"),
                          ),
                        ],
                      ),
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
      onTap: () => setState(() => _selectedResolution = value),
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

  Widget _buildTaskList(List tasks) {
    return ListenableBuilder(
      listenable: _controller,
      builder: (context, _) => ListView.builder(
        itemCount: tasks.length,
        itemBuilder: (context, index) => DownloadCard(
          task: tasks[index],
          onRemove: () => _controller.removeTask(tasks[index]),
        ),
      ),
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

    if (_isPlaylist) {
      final int? start = int.tryParse(_playlistStartController.text);
      final int? end = int.tryParse(_playlistEndController.text);

      _controller.addDownload(
        url,
        path,
        _isAudioOnly,
        isPlaylist: true,
        playlistStart: start,
        playlistEnd: end,
      );
    } else {
      if (_currentPreview == null) {
        // Fallback if preview isn't fetched yet
        _controller.addDownload(url, path, _isAudioOnly);
      } else {
        _controller.addDownload(
          url,
          path,
          _isAudioOnly,
          metadata: _currentPreview,
          resolution: _selectedResolution,
        );
      }
    }

    _urlController.clear();
    setState(() => _currentPreview = null);
  }
}
