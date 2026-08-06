import 'dart:math' as math;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:ytdlapp/controllers/settings_controller.dart';
import 'package:ytdlapp/ui/app_theme.dart';
import 'package:ytdlapp/ui/widgets/tubemate_controls.dart';

class SettingsPage extends StatelessWidget {
  final SettingsController settings;

  const SettingsPage({super.key, required this.settings});

  static const List<({String value, String label})> _resolutionOptions = [
    (value: 'best', label: 'Best'),
    (value: '2160', label: '4K · 2160p'),
    (value: '1440', label: '2K · 1440p'),
    (value: '1080', label: '1080p'),
    (value: '720', label: '720p'),
    (value: '480', label: '480p'),
  ];

  String _resolutionLabel(String value) {
    if (value == 'best') return 'Best';
    for (final opt in _resolutionOptions) {
      if (opt.value == value) return opt.label.replaceAll(' · ', '');
    }
    return value;
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: settings,
      builder: (context, _) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.only(bottom: 18),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: TColors.line)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Media Transport / Configuration',
                    style: TText.mono(
                      context,
                      size: 11,
                      letterSpacing: 0.18,
                      color: TColors.amber,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Settings',
                    style: TText.display(context, size: 30),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Set the defaults every capture starts from.',
                    style: TText.body(
                      context,
                      size: 13.5,
                      color: TColors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 30),
            _GroupLabel(index: '01', label: 'General'),
            const SizedBox(height: 12),
            Container(
              decoration: BoxDecoration(
                color: TColors.panel2,
                border: Border.all(color: TColors.line),
              ),
              child: _SettingRow(
                onTap: () async {
                  String? path = await FilePicker.platform.getDirectoryPath();
                  if (path != null) {
                    settings.setDefaultDownloadPath(path);
                  }
                },
                leading: const _Jack(
                  child: Icon(
                    Icons.folder_outlined,
                    size: 14,
                    color: TColors.amber,
                  ),
                ),
                title: 'Default download folder',
                subtitle: settings.defaultDownloadPath ?? 'Not set',
                pathStyle: true,
                trailing: _Chevron(),
              ),
            ),
            const SizedBox(height: 36),
            _GroupLabel(index: '02', label: 'Downloads'),
            const SizedBox(height: 12),
            Container(
              decoration: BoxDecoration(
                color: TColors.panel2,
                border: Border.all(color: TColors.line),
              ),
              child: Column(
                children: [
                  _SettingRow(
                    leading: const _Jack(
                      monoText: 'HQ',
                    ),
                    title: 'Default resolution',
                    subtitle: 'Applied to every new capture unless overridden',
                    trailing: _DialSelect(
                      value: settings.defaultResolution,
                      label: _resolutionLabel(settings.defaultResolution),
                      onChanged: settings.setDefaultResolution,
                    ),
                  ),
                  const Divider(height: 1, color: TColors.lineSoft),
                  _SettingRow(
                    leading: const _Jack(
                      child: Icon(
                        Icons.download_outlined,
                        size: 14,
                        color: TColors.amber,
                      ),
                    ),
                    title: 'Auto-fetch preview',
                    subtitle:
                        'Fetch video info the moment a link lands in the input',
                    trailing: TubemateSwitch(
                      value: settings.isAutoPreviewEnabled,
                      onChanged: settings.setAutoPreview,
                      activeColor: TColors.green,
                      glow: true,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            const _VersionStrip(),
          ],
        );
      },
    );
  }
}

// ------------------------------------------------------------ Sub widgets

class _GroupLabel extends StatelessWidget {
  final String index;
  final String label;

  const _GroupLabel({required this.index, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          index,
          style: TText.mono(
            context,
            size: 10.5,
            letterSpacing: 0.18,
            color: TColors.amber,
          ),
        ),
        const SizedBox(width: 10),
        Container(width: 14, height: 1, color: TColors.amberDim),
        const SizedBox(width: 10),
        Text(
          label.toUpperCase(),
          style: TText.mono(
            context,
            size: 10.5,
            letterSpacing: 0.18,
            color: TColors.textDim,
          ),
        ),
      ],
    );
  }
}

class _SettingRow extends StatelessWidget {
  final Widget leading;
  final String title;
  final String subtitle;
  final Widget trailing;
  final bool pathStyle;
  final VoidCallback? onTap;

  const _SettingRow({
    required this.leading,
    required this.title,
    required this.subtitle,
    required this.trailing,
    this.pathStyle = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: onTap != null ? SystemMouseCursors.click : MouseCursor.defer,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
          child: Row(
            children: [
              leading,
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TText.body(context, size: 14.5, weight: FontWeight.w500),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: pathStyle
                          ? TText.mono(
                              context,
                              size: 12,
                              color: TColors.textDim,
                            )
                          : TText.body(
                              context,
                              size: 12,
                              color: TColors.textMuted,
                            ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              trailing,
            ],
          ),
        ),
      ),
    );
  }
}

class _Jack extends StatelessWidget {
  final Widget? child;
  final String? monoText;

  const _Jack({this.child, this.monoText});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 34,
      height: 34,
      decoration: BoxDecoration(
        color: TColors.jackBg,
        borderRadius: monoText != null
            ? BorderRadius.circular(3)
            : BorderRadius.circular(17),
        border: Border.all(color: TColors.line),
      ),
      child: monoText != null
          ? Center(
              child: Text(
                monoText!,
                style: TText.mono(
                  context,
                  size: 8.5,
                  color: TColors.amber,
                ).copyWith(fontWeight: FontWeight.w600),
              ),
            )
          : child,
    );
  }
}

class _Chevron extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return const Icon(
      Icons.chevron_right,
      size: 15,
      color: TColors.textDim,
    );
  }
}

class _DialSelect extends StatelessWidget {
  final String value;
  final String label;
  final ValueChanged<String> onChanged;

  const _DialSelect({
    required this.value,
    required this.label,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final options = SettingsPage._resolutionOptions;
    return GestureDetector(
      onTap: () async {
        final box = context.findRenderObject() as RenderBox;
        final offset = box.localToGlobal(Offset(box.size.width, box.size.height));
        final selected = await showMenu<String>(
          context: context,
          position: RelativeRect.fromLTRB(
            offset.dx - 190,
            offset.dy + 6,
            offset.dx + 190,
            offset.dy + 6,
          ),
          color: TColors.panel2,
          shape: RoundedRectangleBorder(
            side: const BorderSide(color: TColors.line),
            borderRadius: BorderRadius.zero,
          ),
          items: [
            for (final opt in options)
              PopupMenuItem<String>(
                value: opt.value,
                height: 38,
                child: Row(
                  children: [
                    if (opt.value == value)
                      const Icon(Icons.check, size: 13, color: TColors.amber)
                    else
                      const SizedBox(width: 13),
                    const SizedBox(width: 8),
                    Text(
                      opt.label,
                      style: TText.mono(
                        context,
                        size: 12,
                        color: opt.value == value
                            ? TColors.amber
                            : TColors.text,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        );
        if (selected != null && selected != value) onChanged(selected);
      },
      child: Container(
        padding: const EdgeInsets.only(left: 8, right: 14),
        decoration: BoxDecoration(
          color: TColors.jackBg,
          border: Border.all(color: TColors.line),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            CustomPaint(
              size: const Size.square(22),
              painter: _DialPainter(color: TColors.amber),
            ),
            const SizedBox(width: 10),
            Text(
              label,
              style: TText.mono(context, size: 13, color: TColors.text)
                  .copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(width: 6),
            const Icon(Icons.arrow_drop_down, size: 13, color: TColors.textDim),
          ],
        ),
      ),
    );
  }
}

class _DialPainter extends CustomPainter {
  final Color color;

  _DialPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final ring = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawCircle(center, size.width / 2, ring);

    final needle = Paint()
      ..color = color
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(35 * math.pi / 180);
    canvas.drawLine(
      Offset(0, -size.height / 2 + 4),
      Offset(0, -size.height / 2 + 10),
      needle,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _DialPainter oldDelegate) {
    return oldDelegate.color != color;
  }
}

class _VersionStrip extends StatelessWidget {
  const _VersionStrip();

  @override
  Widget build(BuildContext context) {
    final platform = defaultTargetPlatform.name.toUpperCase();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: TColors.line)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'BUILD 2.0.4 · $platform',
            style: TText.mono(context, size: 10, color: TColors.textDim),
          ),
          Row(
            children: [
              const Icon(Icons.circle, size: 6, color: TColors.green),
              const SizedBox(width: 8),
              Text(
                'ALL SYSTEMS NOMINAL',
                style: TText.mono(context, size: 10, color: TColors.amber),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
