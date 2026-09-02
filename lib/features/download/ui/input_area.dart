import 'package:flutter/material.dart';
import 'package:ytdlapp/core/theme/app_theme.dart';

/// The jack panel: input URL + output save-location rows.
class InputArea extends StatelessWidget {
  final TextEditingController urlController;
  final FocusNode urlFocusNode;
  final String? selectedPath;
  final VoidCallback onSelectFolder;
  final VoidCallback onUrlSubmitted;
  final VoidCallback onStartDownload;

  const InputArea({
    super.key,
    required this.urlController,
    required this.urlFocusNode,
    required this.selectedPath,
    required this.onSelectFolder,
    required this.onUrlSubmitted,
    required this.onStartDownload,
  });

  @override
  Widget build(BuildContext context) {
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
            label: 'Input · Video or Playlist URL',
            child: TextField(
              controller: urlController,
              focusNode: urlFocusNode,
              onSubmitted: (_) => onUrlSubmitted(),
              style: TText.mono(context, size: 13.5, color: TColors.text),
              cursorColor: TColors.amber,
              decoration: const InputDecoration(
                isCollapsed: true,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                hintStyle: TextStyle(color: TColors.textDim),
              ),
            ),
          ),
          Divider(
            height: 1,
            color: TColors.lineSoft,
            indent: 0,
            endIndent: 0,
          ),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onSelectFolder,
            child: _field(
              context,
              icon: Icons.folder_outlined,
              label: 'Output · Save Location',
              child: Text(
                selectedPath ?? 'Not set — tap to choose',
                overflow: TextOverflow.ellipsis,
                style: TText.mono(
                  context,
                  size: 13.5,
                  color: TColors.amber,
                ),
              ),
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
                const SizedBox(height: 3),
                child,
              ],
            ),
          ),
        ],
      ),
    );
  }
}
