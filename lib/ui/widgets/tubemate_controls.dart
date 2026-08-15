import 'package:flutter/material.dart';
import 'package:ytdlapp/ui/app_theme.dart';

/// Jack-style toggle switch: bordered track, sliding square knob.
class TubemateSwitch extends StatelessWidget {
  final bool value;
  final ValueChanged<bool>? onChanged;
  final Color activeColor;
  final bool glow;

  const TubemateSwitch({
    super.key,
    required this.value,
    this.onChanged,
    this.activeColor = TColors.amber,
    this.glow = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onChanged == null ? null : () => onChanged!(!value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: 40,
        height: 21,
        decoration: BoxDecoration(
          color: value ? activeColor.withValues(alpha: 0.08) : TColors.jackBg,
          border: Border.all(
            color: value ? activeColor : TColors.line,
          ),
        ),
        child: AnimatedAlign(
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOut,
          alignment: value ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            width: 15,
            height: 15,
            margin: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              color: value ? activeColor : TColors.textDim,
              boxShadow: value && glow
                  ? [
                      BoxShadow(
                        color: activeColor.withValues(alpha: 0.6),
                        blurRadius: 6,
                      ),
                    ]
                  : null,
            ),
          ),
        ),
      ),
    );
  }
}

/// Square checkbox tile used across the app.
class CheckSquare extends StatelessWidget {
  final bool value;
  final double size;

  const CheckSquare({super.key, required this.value, this.size = 15});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        border: Border.all(
          color: value ? TColors.amber : TColors.textDim,
          width: 1.5,
        ),
      ),
      child: value
          ? Icon(Icons.check, size: size * 0.7, color: TColors.amber)
          : null,
    );
  }
}

/// Square checkbox with mono label, used by the "Full playlist" pill.
class MonoCheckbox extends StatelessWidget {
  final bool value;
  final String label;
  final VoidCallback onTap;

  const MonoCheckbox({
    super.key,
    required this.value,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          CheckSquare(value: value),
          const SizedBox(width: 9),
          Text(
            label.toUpperCase(),
            style: TText.mono(
              context,
              size: 11,
              color: TColors.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}

/// The amber CTA of the cassette card.
class RecordButton extends StatefulWidget {
  final VoidCallback? onPressed;
  final String label;

  const RecordButton({super.key, required this.onPressed, this.label = 'Download'});

  @override
  State<RecordButton> createState() => _RecordButtonState();
}

class _RecordButtonState extends State<RecordButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onPressed,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 11),
          color: _hovered && widget.onPressed != null
              ? TColors.amberBright
              : widget.onPressed != null
                  ? TColors.amber
                  : TColors.jackBg,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.play_circle_outline,
                size: 15,
                color: widget.onPressed != null
                    ? const Color(0xFF14120F)
                    : TColors.textDim,
              ),
              const SizedBox(width: 9),
              Text(
                widget.label.toUpperCase(),
                style: TText.display(
                  context,
                  size: 13.5,
                  weight: FontWeight.w700,
                  color: widget.onPressed != null
                      ? const Color(0xFF14120F)
                      : TColors.textDim,
                ).copyWith(letterSpacing: 0.04),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Small mono input used for the playlist range counters.
class CounterInput extends StatelessWidget {
  final TextEditingController controller;
  final String? hint;

  const CounterInput({super.key, required this.controller, this.hint});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 46,
      decoration: BoxDecoration(
        color: TColors.jackBg,
        border: Border.all(color: TColors.line),
      ),
      child: TextField(
        controller: controller,
        textAlign: TextAlign.center,
        style: TText.mono(context, size: 13, color: TColors.amber),
        cursorColor: TColors.amber,
        keyboardType: TextInputType.number,
        decoration: InputDecoration(
          isCollapsed: true,
          contentPadding: const EdgeInsets.symmetric(vertical: 5),
          border: InputBorder.none,
          hintText: hint,
          hintStyle: TText.mono(context, size: 13, color: TColors.textDim),
        ),
      ),
    );
  }
}
