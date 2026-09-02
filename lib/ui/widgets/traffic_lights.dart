import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';
import 'package:ytdlapp/ui/app_theme.dart';

/// macOS-style traffic lights (close / minimize / zoom) for the frameless
/// window. The close button asks for confirmation before exiting.
class TrafficLights extends StatelessWidget {
  const TrafficLights({super.key});

  static const Color _red = Color(0xFFFF5F57);
  static const Color _yellow = Color(0xFFFEBC2E);
  static const Color _green = Color(0xFF28C840);

  Future<void> _confirmAndClose(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: TColors.panel2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.zero,
          side: BorderSide(color: TColors.line),
        ),
        child: SizedBox(
          width: 360,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 16, 18, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'MEDIA TRANSPORT / EXIT',
                      style: TText.mono(
                        context,
                        size: 10.5,
                        letterSpacing: 0.18,
                        color: TColors.amber,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Close TubeXMate?',
                      style: TText.display(
                        context,
                        size: 16,
                        weight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 8, 18, 16),
                child: Text(
                  'Active downloads will be stopped.',
                  style: TText.body(
                    context,
                    size: 12,
                    color: TColors.textMuted,
                  ),
                ),
              ),
              Divider(height: 1, color: TColors.lineSoft),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 12,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'CLICK OUTSIDE TO CANCEL',
                        style: TText.mono(
                          context,
                          size: 9,
                          letterSpacing: 0.08,
                          color: TColors.textDim,
                        ),
                      ),
                    ),
                    GestureDetector(
                      onTap: () => Navigator.of(context).pop(false),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: TColors.jackBg,
                          border: Border.all(color: TColors.line),
                        ),
                        child: Text(
                          'CANCEL',
                          style: TText.mono(
                            context,
                            size: 10.5,
                            letterSpacing: 0.06,
                            color: TColors.textMuted,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    GestureDetector(
                      onTap: () => Navigator.of(context).pop(true),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 8,
                        ),
                        color: TColors.amber,
                        child: Text(
                          'EXIT',
                          style: TText.mono(
                            context,
                            size: 10.5,
                            letterSpacing: 0.06,
                            color: const Color(0xFF14120F),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if (confirmed != true) return;
    try {
      await windowManager.close();
    } catch (_) {
      // Not running on a desktop window (e.g. tests) — nothing to close.
    }
  }

  Future<void> _toggleMaximize() async {
    try {
      final maximized = await windowManager.isMaximized();
      if (maximized) {
        await windowManager.unmaximize();
      } else {
        await windowManager.maximize();
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _Dot(
          color: _red,
          icon: Icons.close,
          tooltip: 'Close',
          onTap: () => _confirmAndClose(context),
        ),
        const SizedBox(width: 7),
        _Dot(
          color: _yellow,
          icon: Icons.remove,
          tooltip: 'Minimize',
          onTap: () async {
            try {
              await windowManager.minimize();
            } catch (_) {}
          },
        ),
        const SizedBox(width: 7),
        _Dot(
          color: _green,
          icon: Icons.zoom_out_map,
          tooltip: 'Maximize',
          onTap: _toggleMaximize,
        ),
      ],
    );
  }
}

class _Dot extends StatefulWidget {
  final Color color;
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  const _Dot({
    required this.color,
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  @override
  State<_Dot> createState() => _DotState();
}

class _DotState extends State<_Dot> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: Tooltip(
        message: widget.tooltip,
        waitDuration: const Duration(milliseconds: 600),
        child: GestureDetector(
          onTap: widget.onTap,
          behavior: HitTestBehavior.opaque,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _hovered
                  ? widget.color.withValues(alpha: 0.9)
                  : widget.color,
              boxShadow: const [
                BoxShadow(color: Color(0x33000000), blurRadius: 1),
              ],
            ),
            child: _hovered
                ? Icon(
                    widget.icon,
                    size: 7,
                    color: const Color(0x66000000),
                  )
                : null,
          ),
        ),
      ),
    );
  }
}