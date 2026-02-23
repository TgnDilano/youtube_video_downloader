import 'package:flutter/material.dart';

class InputArea extends StatelessWidget {
  final TextEditingController urlController;
  final String? selectedPath;
  final VoidCallback onSelectFolder;
  final VoidCallback onStartDownload;

  const InputArea({
    super.key,
    required this.urlController,
    required this.selectedPath,
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
            onSubmitted: (_) => onStartDownload(),
            decoration: const InputDecoration(
              hintText: "Insert or Paste URL Here",
              border: InputBorder.none,
              prefixIcon: Icon(Icons.link),
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
            ],
          ),
        ],
      ),
    );
  }
}
