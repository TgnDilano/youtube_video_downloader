import 'package:flutter/material.dart';
import 'package:ytdlapp/core/theme/app_theme.dart';

/// Themed dialog that lets the user pick an arbitrary color via an HSV
/// hue slider + saturation/value pad + hex field. Resolves the picked
/// [Color] on confirm, or null on cancel.
Future<Color?> showColorPickerDialog(
  BuildContext context, {
  required String title,
  required Color initial,
}) {
  return showDialog<Color>(
    context: context,
    builder: (_) => _ColorPickerDialog(title: title, initial: initial),
  );
}

class _ColorPickerDialog extends StatefulWidget {
  final String title;
  final Color initial;

  const _ColorPickerDialog({required this.title, required this.initial});

  @override
  State<_ColorPickerDialog> createState() => _ColorPickerDialogState();
}

class _ColorPickerDialogState extends State<_ColorPickerDialog> {
  late HSVColor _hsv;
  late TextEditingController _hex;

  @override
  void initState() {
    super.initState();
    _hsv = HSVColor.fromColor(widget.initial);
    _hex = TextEditingController(text: _hexString(widget.initial));
  }

  @override
  void dispose() {
    _hex.dispose();
    super.dispose();
  }

  static String _hexString(Color c) {
    return '#${(c.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}';
  }

  Color get _color => _hsv.toColor();

  void _applyHsv(HSVColor v) {
    setState(() {
      _hsv = v;
      _hex.text = _hexString(v.toColor());
    });
  }

  void _applyHex(String raw) {
    var text = raw.trim().replaceFirst('#', '');
    if (text.length == 3) {
      text = text.split('').map((e) => '$e$e').join();
    }
    if (text.length != 6) return;
    final parsed = int.tryParse(text, radix: 16);
    if (parsed == null) return;
    final color = Color(0xFF000000 | parsed);
    setState(() {
      _hsv = HSVColor.fromColor(color);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: TColors.panel2,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: TColors.line),
        borderRadius: BorderRadius.zero,
      ),
      child: Container(
        width: 360,
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.title.toUpperCase(),
              style: TText.mono(
                context,
                size: 10.5,
                letterSpacing: 0.14,
                color: TColors.amber,
              ),
            ),
            const SizedBox(height: 16),
            _SvPad(hsv: _hsv, onChanged: _applyHsv),
            const SizedBox(height: 14),
            _HueSlider(hsv: _hsv, onChanged: _applyHsv),
            const SizedBox(height: 16),
            Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: _color,
                    shape: BoxShape.circle,
                    border: Border.all(color: TColors.line),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    decoration: BoxDecoration(
                      color: TColors.jackBg,
                      border: Border.all(color: TColors.line),
                    ),
                    child: TextField(
                      controller: _hex,
                      style: TText.mono(
                        context,
                        size: 13,
                        color: TColors.text,
                      ),
                      onSubmitted: _applyHex,
                      onChanged: (t) {
                        if (t.replaceFirst('#', '').length >= 6) _applyHex(t);
                      },
                      cursorColor: TColors.amber,
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(vertical: 10),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => Navigator.pop(context, _color),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 9,
                      ),
                      decoration: BoxDecoration(
                        color: TColors.amber,
                        border: Border.all(color: TColors.amber),
                      ),
                      child: Text(
                        'APPLY',
                        style: TText.mono(
                          context,
                          size: 10,
                          letterSpacing: 0.06,
                          color: TColors.jackBg,
                        ).copyWith(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SvPad extends StatelessWidget {
  final HSVColor hsv;
  final ValueChanged<HSVColor> onChanged;

  const _SvPad({required this.hsv, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final height = 120.0;
        return GestureDetector(
          onPanDown: (d) => _update(d.localPosition, width, height),
          onPanUpdate: (d) => _update(d.localPosition, width, height),
          child: Stack(
            children: [
              Container(
                width: width,
                height: height,
                decoration: BoxDecoration(
                  border: Border.all(color: TColors.line),
                  gradient: LinearGradient(
                    colors: [
                      HSVColor.fromAHSV(1, hsv.hue, 0, 1).toColor(),
                      HSVColor.fromAHSV(1, hsv.hue, 1, 1).toColor(),
                    ],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  ),
                ),
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: Container(
                    height: height - 2,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Colors.transparent, Colors.black],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                left: (hsv.saturation * (width - 2)).clamp(0, width - 2) -
                    _dot / 2,
                top: ((1 - hsv.value) * (height - 2)).clamp(0, height - 2) -
                    _dot / 2,
                child: IgnorePointer(
                  child: Container(
                    width: _dot,
                    height: _dot,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: TColors.text, width: 1.5),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  static const double _dot = 12;

  void _update(Offset local, double width, double height) {
    final s = (local.dx / width).clamp(0.0, 1.0);
    final v = (1 - local.dy / height).clamp(0.0, 1.0);
    onChanged(hsv.withSaturation(s).withValue(v));
  }
}

class _HueSlider extends StatelessWidget {
  final HSVColor hsv;
  final ValueChanged<HSVColor> onChanged;

  const _HueSlider({required this.hsv, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final hue = hsv.hue;
        return GestureDetector(
          onPanDown: (d) => _update(d.localPosition.dx, width),
          onPanUpdate: (d) => _update(d.localPosition.dx, width),
          child: SizedBox(
            height: 22,
            child: Stack(
              children: [
                Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: TColors.line),
                    gradient: const LinearGradient(
                      colors: [
                        Color(0xFFFF0000),
                        Color(0xFFFFFF00),
                        Color(0xFF00FF00),
                        Color(0xFF00FFFF),
                        Color(0xFF0000FF),
                        Color(0xFFFF00FF),
                        Color(0xFFFF0000),
                      ],
                    ),
                  ),
                ),
                Positioned(
                  left: (hue / 360 * (width - 2)).clamp(0, width - 2) - 6,
                  child: IgnorePointer(
                    child: Container(
                      width: 12,
                      height: 22,
                      decoration: const BoxDecoration(
                        color: Colors.transparent,
                        border: Border.symmetric(
                          horizontal: BorderSide(color: TColors.text, width: 2),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _update(double dx, double width) {
    final hue = (dx / width * 360).clamp(0.0, 360.0);
    onChanged(hsv.withHue(hue));
  }
}
