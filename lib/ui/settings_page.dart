import 'dart:math' as math;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:ytdlapp/controllers/download_controller.dart';
import 'package:ytdlapp/controllers/settings_controller.dart';
import 'package:ytdlapp/ui/app_theme.dart';
import 'package:ytdlapp/ui/widgets/tubemate_controls.dart';

class SettingsPage extends StatelessWidget {
  final SettingsController settings;
  final DownloadController controller;

  const SettingsPage({
    super.key,
    required this.settings,
    required this.controller,
  });

  static const List<({String value, String label})> _resolutionOptions = [
    (value: 'best', label: 'Best'),
    (value: '2160', label: '4K · 2160p'),
    (value: '1440', label: '2K · 1440p'),
    (value: '1080', label: '1080p'),
    (value: '720', label: '720p'),
    (value: '480', label: '480p'),
  ];

  static const List<({String value, String label})> _cookieOptions = [
    (value: 'auto', label: 'Auto'),
    (value: 'chrome', label: 'Chrome'),
    (value: 'edge', label: 'Edge'),
    (value: 'brave', label: 'Brave'),
    (value: 'firefox', label: 'Firefox'),
    (value: 'none', label: 'Off'),
  ];

  String _resolutionLabel(String value) {
    if (value == 'best') return 'Best';
    for (final opt in _resolutionOptions) {
      if (opt.value == value) return opt.label.replaceAll(' · ', '');
    }
    return value;
  }

  String _cookieLabel(String value) {
    for (final opt in _cookieOptions) {
      if (opt.value == value) return opt.label;
    }
    return 'Auto';
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: settings,
      builder: (context, _) {
        return SingleChildScrollView(
          child: Column(
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
                  const Divider(height: 1, color: TColors.lineSoft),
                  _SettingRow(
                    leading: const _Jack(
                      child: Icon(
                        Icons.key_outlined,
                        size: 14,
                        color: TColors.green,
                      ),
                    ),
                    title: 'YouTube cookie source',
                    subtitle:
                        'Fixes "HTTP Error 403: Forbidden". Pick the browser '
                        'you are logged into YouTube with.',
                    trailing: _DialSelect(
                      value: settings.cookieBrowser,
                      label: _cookieLabel(settings.cookieBrowser),
                      onChanged: settings.setCookieBrowser,
                      options: _cookieOptions,
                      accentColor: TColors.green,
                    ),
                  ),
                  const Divider(height: 1, color: TColors.lineSoft),
                  _SettingRow(
                    leading: const _Jack(
                      child: Icon(
                        Icons.file_open_outlined,
                        size: 14,
                        color: TColors.amber,
                      ),
                    ),
                    title: 'Cookies file (safer)',
                    subtitle: settings.cookiesFile != null
                        ? 'Priority use in downloads — no Keychain access'
                        : 'Export a cookies.txt (YouTube log-in) and pick it — '
                            'narrowest option, no browser access',
                    trailing: GestureDetector(
                      onTap: () async {
                        final picked = await FilePicker.platform.pickFiles(
                          dialogTitle: 'Select cookies.txt',
                          type: FileType.any,
                        );
                        if (picked != null &&
                            picked.files.single.path != null) {
                          settings.setCookiesFile(picked.files.single.path);
                        } else if (settings.cookiesFile != null) {
                          // Tapping with a file set clears it.
                          settings.setCookiesFile(null);
                        }
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
                              painter: _DialPainter(
                                color: settings.cookiesFile != null
                                    ? TColors.green
                                    : TColors.textDim,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Text(
                              settings.cookiesFile != null
                                  ? 'SET'
                                  : 'PICK FILE',
                              style: TText.mono(
                                context,
                                size: 12.5,
                                color: settings.cookiesFile != null
                                    ? TColors.green
                                    : TColors.text,
                              ).copyWith(fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 36),
            _GroupLabel(index: '03', label: 'Engine'),
            const SizedBox(height: 12),
            Container(
              decoration: BoxDecoration(
                color: TColors.panel2,
                border: Border.all(color: TColors.line),
              ),
              child: _EngineGroup(controller: controller),
            ),
            const SizedBox(height: 8),
            const _VersionStrip(),
            ],
          ),
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

class _EngineGroup extends StatefulWidget {
  final DownloadController controller;

  const _EngineGroup({required this.controller});

  @override
  State<_EngineGroup> createState() => _EngineGroupState();
}

class _EngineGroupState extends State<_EngineGroup> {
  String? _ytDlpVersion;
  String? _ffmpegVersion;
  String? _latestVersion;
  String? _error;
  bool _checking = false;
  bool _updating = false;

  @override
  void initState() {
    super.initState();
    _loadInstalled();
  }

  Future<void> _loadInstalled() async {
    final ytDlp = await widget.controller.getToolVersion('yt-dlp');
    final ffmpeg = await widget.controller.getToolVersion('ffmpeg');
    if (!mounted) return;
    setState(() {
      _ytDlpVersion = ytDlp;
      _ffmpegVersion = ffmpeg;
    });
  }

  static String _normalize(String? v) =>
      (v ?? '').replaceFirst(RegExp(r'^v'), '').trim();

  bool get _updateAvailable =>
      _latestVersion != null &&
      _normalize(_latestVersion) != _normalize(_ytDlpVersion);

  bool get _busy => _checking || _updating;

  Future<void> _checkForUpdate() async {
    setState(() {
      _checking = true;
      _error = null;
    });
    final latest = await widget.controller.fetchLatestYtDlpVersion();
    if (!mounted) return;
    setState(() {
      _checking = false;
      if (latest == null) {
        _error = 'Could not reach the update server';
      } else {
        _latestVersion = latest;
      }
    });
  }

  Future<void> _runUpdate() async {
    setState(() {
      _updating = true;
      _error = null;
    });
    final updated = await widget.controller.updateYtDlp();
    if (!mounted) return;
    setState(() {
      _updating = false;
      if (updated != null) {
        _ytDlpVersion = updated;
      } else {
        _error = 'Update failed — check your connection and try again';
      }
    });
  }

  String get _subtitle {
    if (_error != null) return _error!;
    if (_checking) return 'Checking for yt-dlp updates…';
    if (_latestVersion != null) {
      return _updateAvailable
          ? 'Update available: ${_latestVersion!}'
          : 'Engine is up to date';
    }
    final parts = <String>[
      _ytDlpVersion != null ? 'yt-dlp $_ytDlpVersion' : 'yt-dlp not detected',
      if (_ffmpegVersion != null) 'ffmpeg $_ffmpegVersion',
    ];
    return parts.join(' · ');
  }

  String get _actionLabel {
    if (_updating) return 'UPDATING…';
    if (_checking) return 'CHECKING…';
    if (_latestVersion == null) return 'CHECK';
    return _updateAvailable ? 'UPDATE' : 'UP TO DATE';
  }

  @override
  Widget build(BuildContext context) {
    return _SettingRow(
      leading: const _Jack(
        child: Icon(
          Icons.settings_ethernet,
          size: 14,
          color: TColors.amber,
        ),
      ),
      title: 'Download engine',
      subtitle: _subtitle,
      trailing: _EngineActionButton(
        label: _actionLabel,
        enabled: !_busy && (_latestVersion == null || _updateAvailable),
        onPressed: _latestVersion == null ? _checkForUpdate : _runUpdate,
      ),
    );
  }
}

class _EngineActionButton extends StatefulWidget {
  final String label;
  final bool enabled;
  final VoidCallback onPressed;

  const _EngineActionButton({
    required this.label,
    required this.enabled,
    required this.onPressed,
  });

  @override
  State<_EngineActionButton> createState() => _EngineActionButtonState();
}

class _EngineActionButtonState extends State<_EngineActionButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: widget.enabled
          ? SystemMouseCursors.click
          : SystemMouseCursors.basic,
      onEnter: widget.enabled ? (_) => setState(() => _hovered = true) : null,
      onExit: widget.enabled ? (_) => setState(() => _hovered = false) : null,
      child: InkWell(
        onTap: widget.enabled ? widget.onPressed : null,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: TColors.jackBg,
            border: Border.all(
              color: _hovered && widget.enabled ? TColors.amber : TColors.line,
            ),
          ),
          child: Text(
            widget.label,
            style: TText.mono(
              context,
              size: 10.5,
              letterSpacing: 0.06,
              color: widget.enabled ? TColors.amber : TColors.textDim,
            ),
          ),
        ),
      ),
    );
  }
}

class _DialSelect extends StatelessWidget {
  final String value;
  final String label;
  final ValueChanged<String> onChanged;
  final List<({String value, String label})> options;
  final Color accentColor;

  const _DialSelect({
    required this.value,
    required this.label,
    required this.onChanged,
    this.options = SettingsPage._resolutionOptions,
    this.accentColor = TColors.amber,
  });

  @override
  Widget build(BuildContext context) {
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
              painter: _DialPainter(color: accentColor),
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
