import 'package:flutter/material.dart';
import 'package:ytdlapp/core/theme/app_theme.dart';

/// 13-bar level meter; bars light green, warm amber above 60%.
class VuMeter extends StatelessWidget {
  final double progress;
  final double width;

  const VuMeter({super.key, required this.progress, this.width = 130});

  static const int barCount = 13;

  @override
  Widget build(BuildContext context) {
    final filled = (progress * barCount).round().clamp(0, barCount);
    return SizedBox(
      width: width,
      height: 20,
      child: Row(
        children: [
          for (var i = 0; i < barCount; i++) ...[
            Expanded(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                margin: const EdgeInsets.symmetric(horizontal: 1),
                decoration: BoxDecoration(
                  color: i < filled
                      ? (i < (barCount * 0.6).round()
                            ? TColors.green
                            : TColors.amber)
                      : TColors.line,
                  borderRadius: BorderRadius.circular(1),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
