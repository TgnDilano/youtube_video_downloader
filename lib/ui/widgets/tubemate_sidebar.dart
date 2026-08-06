import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:ytdlapp/ui/app_theme.dart';

/// Subtle repeating scanline texture used by the sidebar and thumbnails.
class Scanlines extends StatelessWidget {
  final bool horizontal;
  final Color color;
  final int gap;
  final int thickness;

  const Scanlines({
    super.key,
    this.horizontal = true,
    this.color = const Color(0x1FFFFFFF),
    this.gap = 4,
    this.thickness = 1,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _ScanlinePainter(
        horizontal: horizontal,
        color: color,
        gap: gap,
        thickness: thickness,
      ),
    );
  }
}

class _ScanlinePainter extends CustomPainter {
  final bool horizontal;
  final Color color;
  final int gap;
  final int thickness;

  _ScanlinePainter({
    required this.horizontal,
    required this.color,
    required this.gap,
    required this.thickness,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    if (horizontal) {
      for (double y = 0; y < size.height; y += gap) {
        canvas.drawRect(
          Rect.fromLTWH(0, y, size.width, thickness.toDouble()),
          paint,
        );
      }
    } else {
      for (double x = 0; x < size.width; x += gap) {
        canvas.drawRect(
          Rect.fromLTWH(x, 0, thickness.toDouble(), size.height),
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _ScanlinePainter oldDelegate) {
    return oldDelegate.horizontal != horizontal ||
        oldDelegate.color != color ||
        oldDelegate.gap != gap ||
        oldDelegate.thickness != thickness;
  }
}

/// The 84px rail: logo, navigation, vertical version footer.
class TubemateSidebar extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;

  const TubemateSidebar({
    super.key,
    required this.selectedIndex,
    required this.onDestinationSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 84,
      decoration: BoxDecoration(
        color: TColors.panel,
        border: const Border(right: BorderSide(color: TColors.line)),
      ),
      child: Stack(
        children: [
          const Positioned.fill(
            child: IgnorePointer(
              child: Scanlines(horizontal: true, color: Color(0x03FFFFFF)),
            ),
          ),          Column(
            children: [
              const SizedBox(height: 20),
              const _Logo(),
              const SizedBox(height: 24),
              _NavItem(
                icon: Icons.home_outlined,
                label: 'Home',
                active: selectedIndex == 0,
                onTap: () => onDestinationSelected(0),
              ),
              _NavItem(
                icon: Icons.settings_outlined,
                label: 'Settings',
                active: selectedIndex == 1,
                onTap: () => onDestinationSelected(1),
              ),
              const Spacer(),
              RotatedBox(
                quarterTurns: 1,
                child: Text(
                  'TUBEMATE v2 · MEDIA TRANSPORT',
                  maxLines: 1,
                  textAlign: TextAlign.center,
                  style: TText.mono(
                    context,
                    size: 8,
                    letterSpacing: 0.15,
                    color: TColors.textDim,
                  ),
                ),
              ),
              const SizedBox(height: 6),
            ],
          ),
        ],
      ),
    );
  }
}

class _Logo extends StatelessWidget {
  const _Logo();

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        const SizedBox(width: 50, height: 50),
        Positioned.fill(
          child: CustomPaint(
            painter: _DashedRingPainter(color: TColors.amberDim),
          ),
        ),
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: TColors.amber, width: 1.5),
          ),
          child: const Icon(
            Icons.check,
            size: 16,
            color: TColors.amber,
            weight: 600,
          ),
        ),
      ],
    );
  }
}

class _DashedRingPainter extends CustomPainter {
  final Color color;

  _DashedRingPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    const dash = 3.0;
    const gap = 3.0;
    for (double angle = 0; angle < 360; angle += dash + gap) {
      final start = angle * math.pi / 180;
      final sweep = dash * math.pi / 180;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        start,
        sweep,
        false,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _DashedRingPainter oldDelegate) {
    return oldDelegate.color != color;
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: active ? TColors.amber.withValues(alpha: 0.06) : null,
          border: Border(
            left: BorderSide(
              color: active ? TColors.amber : Colors.transparent,
              width: 2,
            ),
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              size: 18,
              color: active ? TColors.amber : TColors.textDim,
            ),
            const SizedBox(height: 6),
            Text(
              label.toUpperCase(),
              style: TText.mono(
                context,
                size: 9,
                letterSpacing: 0.08,
                color: active ? TColors.amber : TColors.textDim,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
