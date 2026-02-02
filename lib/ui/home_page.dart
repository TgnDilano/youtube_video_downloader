import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:ytdlapp/controllers/download_controller.dart';
import 'package:ytdlapp/models/download_task.dart';
import 'package:ytdlapp/ui/widgets/download_card.dart';
import 'package:ytdlapp/ui/widgets/input_area.dart';
import 'package:ytdlapp/ui/widgets/terminal_view.dart';

class TubemateClone extends StatefulWidget {
  const TubemateClone({super.key});

  @override
  State<TubemateClone> createState() => _TubemateCloneState();
}

class _TubemateCloneState extends State<TubemateClone> {
  final DownloadController _controller = DownloadController();
  final TextEditingController _urlController = TextEditingController();
  final TextEditingController _playlistStartController =
      TextEditingController();
  final TextEditingController _playlistEndController = TextEditingController();
  String? _selectedPath;
  bool _isAudioOnly = false;
  bool _isPlaylist = false;
  bool _showTerminal = false;

  @override
  void initState() {
    super.initState();
    _playlistStartController.text = '1';
    _playlistEndController.text = '10';
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
            selectedIndex: 0,
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
                icon: Icon(Icons.video_library),
                label: Text('Video'),
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
              child: Column(
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
                            style: TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            "Enter the url of a video and let the magic happen!",
                            style: TextStyle(color: Colors.grey),
                          ),
                        ],
                      ),
                      IconButton(
                        icon: const Icon(Icons.terminal),
                        onPressed: () =>
                            setState(() => _showTerminal = !_showTerminal),
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
                    selectedPath: _selectedPath,
                    isAudioOnly: _isAudioOnly,
                    isPlaylist: _isPlaylist,
                    onAudioOnlyChanged: (value) =>
                        setState(() => _isAudioOnly = value),
                    onPlaylistChanged: (value) =>
                        setState(() => _isPlaylist = value),
                    onSelectFolder: () async {
                      String? path = await FilePicker.platform
                          .getDirectoryPath();
                      if (path != null) setState(() => _selectedPath = path);
                    },
                    onStartDownload: _startNewDownload,
                  ),
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
                              Tab(text: "Completed"),
                            ],
                          ),
                          Expanded(
                            child: TabBarView(
                              children: [
                                ListenableBuilder(
                                  listenable: _controller,
                                  builder: (context, _) {
                                    return ListView.builder(
                                      itemCount:
                                          _controller.downloadingTasks.length,
                                      itemBuilder: (context, index) =>
                                          DownloadCard(
                                            task: _controller
                                                .downloadingTasks[index],
                                            onRemove: () =>
                                                _controller.removeTask(
                                                  _controller
                                                      .downloadingTasks[index],
                                                ),
                                          ),
                                    );
                                  },
                                ),
                                ListenableBuilder(
                                  listenable: _controller,
                                  builder: (context, _) {
                                    return ListView.builder(
                                      itemCount:
                                          _controller.completedTasks.length,
                                      itemBuilder: (context, index) =>
                                          DownloadCard(
                                            task: _controller
                                                .completedTasks[index],
                                            onRemove: () =>
                                                _controller.removeTask(
                                                  _controller
                                                      .completedTasks[index],
                                                ),
                                          ),
                                    );
                                  },
                                ),
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
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _startNewDownload() {
    if (_selectedPath == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please select a folder first!")),
      );
      return;
    }

    final int? start = int.tryParse(_playlistStartController.text);
    final int? end = int.tryParse(_playlistEndController.text);

    _controller.addDownload(
      _urlController.text,
      _selectedPath!,
      _isAudioOnly,
      isPlaylist: _isPlaylist,
      playlistStart: start,
      playlistEnd: end,
    );
    _urlController.clear();
  }
}
