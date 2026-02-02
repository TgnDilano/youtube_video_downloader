import 'package:flutter/material.dart';

class InputArea extends StatelessWidget {
  final TextEditingController urlController;
  final TextEditingController playlistStartController;
  final TextEditingController playlistEndController;
  final String? selectedPath;
  final bool isAudioOnly;
  final bool isPlaylist;
  final ValueChanged<bool> onAudioOnlyChanged;
  final ValueChanged<bool> onPlaylistChanged;
  final VoidCallback onSelectFolder;
  final VoidCallback onStartDownload;

  const InputArea({
    super.key,
    required this.urlController,
    required this.playlistStartController,
    required this.playlistEndController,
    required this.selectedPath,
    required this.isAudioOnly,
    required this.isPlaylist,
    required this.onAudioOnlyChanged,
    required this.onPlaylistChanged,
    required this.onSelectFolder,
    required this.onStartDownload,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        children: [
          TextField(
            controller: urlController,
            decoration: InputDecoration(
              hintText: "Insert or Paste URL Here",
              border: InputBorder.none,
              prefixIcon: const Icon(Icons.link),
              suffixIcon: ElevatedButton(
                onPressed: onStartDownload,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                ),
                child: const Text("Convert"),
              ),
            ),
          ),
          const Divider(color: Colors.white10),
          Row(
            children: [
              TextButton.icon(
                onPressed: onSelectFolder,
                icon: const Icon(Icons.folder_open),
                label: Text(selectedPath ?? "Select Folder"),
              ),
              const Spacer(),
              const Text("Audio Only"),
              Switch(value: isAudioOnly, onChanged: onAudioOnlyChanged),
              const SizedBox(width: 16),
              const Text("Playlist"),
              Switch(value: isPlaylist, onChanged: onPlaylistChanged),
            ],
          ),
          if (isPlaylist) ...[
            const Divider(color: Colors.white10),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  const Text("Range: "),
                  Flexible(
                    child: SizedBox(
                      width: 80,
                      child: TextField(
                        controller: playlistStartController,
                        textAlign: TextAlign.center,
                        decoration: const InputDecoration(
                          hintText: "Start",
                          isDense: true,
                        ),
                        keyboardType: TextInputType.number,
                      ),
                    ),
                  ),
                  const Text(" to "),
                  Flexible(
                    child: SizedBox(
                      width: 80,
                      child: TextField(
                        controller: playlistEndController,
                        textAlign: TextAlign.center,
                        decoration: const InputDecoration(
                          hintText: "End",
                          isDense: true,
                        ),
                        keyboardType: TextInputType.number,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
