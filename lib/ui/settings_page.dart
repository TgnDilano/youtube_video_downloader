import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:ytdlapp/controllers/settings_controller.dart';

class SettingsPage extends StatelessWidget {
  final SettingsController settings;

  const SettingsPage({super.key, required this.settings});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: settings,
      builder: (context, _) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Settings",
              style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
            ),
            const Text(
              "Configure your downloader preferences",
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 32),
            _buildSection(
              title: "General",
              children: [
                _buildSettingTile(
                  title: "Default Download Folder",
                  subtitle: settings.defaultDownloadPath ?? "Not set",
                  icon: Icons.folder_open,
                  onTap: () async {
                    String? path = await FilePicker.platform.getDirectoryPath();
                    if (path != null) {
                      settings.setDefaultDownloadPath(path);
                    }
                  },
                ),
              ],
            ),
            const SizedBox(height: 24),
            _buildSection(
              title: "Downloads",
              children: [
                _buildSettingTile(
                  title: "Default Resolution",
                  subtitle: settings.defaultResolution == 'best'
                      ? "Best Quality"
                      : "${settings.defaultResolution}p",
                  icon: Icons.high_quality,
                  trailing: DropdownButton<String>(
                    value: settings.defaultResolution,
                    dropdownColor: const Color(0xFF1E1E1E),
                    underline: const SizedBox(),
                    items: const [
                      DropdownMenuItem(value: 'best', child: Text("Best")),
                      DropdownMenuItem(
                        value: '2160',
                        child: Text("4K (2160p)"),
                      ),
                      DropdownMenuItem(
                        value: '1440',
                        child: Text("2K (1440p)"),
                      ),
                      DropdownMenuItem(value: '1080', child: Text("1080p")),
                      DropdownMenuItem(value: '720', child: Text("720p")),
                      DropdownMenuItem(value: '480', child: Text("480p")),
                    ],
                    onChanged: (val) {
                      if (val != null) settings.setDefaultResolution(val);
                    },
                  ),
                ),
                _buildSwitchTile(
                  title: "Auto-fetch Preview",
                  subtitle:
                      "Fetch video info immediately when a link is pasted",
                  value: settings.isAutoPreviewEnabled,
                  onChanged: settings.setAutoPreview,
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  Widget _buildSection({
    required String title,
    required List<Widget> children,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title.toUpperCase(),
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: Colors.green,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFF1E1E1E),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white10),
          ),
          child: Column(children: children),
        ),
      ],
    );
  }

  Widget _buildSettingTile({
    required String title,
    required String subtitle,
    required IconData icon,
    VoidCallback? onTap,
    Widget? trailing,
  }) {
    return ListTile(
      leading: Icon(icon, color: Colors.grey),
      title: Text(title),
      subtitle: Text(subtitle, style: const TextStyle(color: Colors.grey)),
      trailing: trailing ?? const Icon(Icons.chevron_right, color: Colors.grey),
      onTap: onTap,
    );
  }

  Widget _buildSwitchTile({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return SwitchListTile(
      title: Text(title),
      subtitle: Text(subtitle, style: const TextStyle(color: Colors.grey)),
      value: value,
      activeColor: Colors.green,
      onChanged: onChanged,
    );
  }
}
