import 'package:flutter/material.dart';
import 'package:ytdlapp/ui/app_theme.dart';

const List<String> _weekdays = ['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN'];

String _two(int v) => v.toString().padLeft(2, '0');

/// "TUE 09/16 · 21:15" style timestamp.
String formatPlannedDate(DateTime when) {
  final weekday = _weekdays[when.weekday - 1];
  return '$weekday ${_two(when.month)}/${_two(when.day)} · '
      '${_two(when.hour)}:${_two(when.minute)}';
}

/// Relative "IN 4 H 05 MIN / NOW / IN 2 DAYS" preview.
String describeRelative(DateTime when) {
  final diff = when.difference(DateTime.now());
  if (diff.inMinutes < 1) return 'NOW';
  if (diff.inMinutes < 60) return 'IN ${diff.inMinutes} MIN';
  if (diff.inHours < 24) {
    return 'IN ${diff.inHours} H ${_two(diff.inMinutes % 60)} MIN';
  }
  return 'IN ${diff.inDays} DAYS';
}

/// Themed dialog that asks for a date + time; resolves null on cancel.
Future<DateTime?> showScheduleDialog(
  BuildContext context, {
  required String url,
  required String title,
}) {
  return showDialog<DateTime>(
    context: context,
    builder: (_) => _ScheduleDialog(url: url, title: title),
  );
}

class _ScheduleDialog extends StatefulWidget {
  final String url;
  final String title;

  const _ScheduleDialog({required this.url, required this.title});

  @override
  State<_ScheduleDialog> createState() => _ScheduleDialogState();
}

class _ScheduleDialogState extends State<_ScheduleDialog> {
  late DateTime _when;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _when = DateTime(now.year, now.month, now.day, now.hour + 1);
  }

  ThemeData _pickerTheme(BuildContext context) {
    final base = Theme.of(context);
    final scheme = base.colorScheme.copyWith(
      primary: TColors.amber,
      onPrimary: const Color(0xFF14120F),
      surface: TColors.panel2,
      onSurface: TColors.text,
      onSurfaceVariant: TColors.textMuted,
    );
    return base.copyWith(
      colorScheme: scheme,
      dialogTheme: base.dialogTheme.copyWith(backgroundColor: TColors.panel2),
    );
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _when.isBefore(now) ? now : _when,
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
      helpText: 'SCHEDULE · DATE',
      cancelText: 'BACK',
      confirmText: 'SET DATE',
      builder: (context, child) =>
          Theme(data: _pickerTheme(context), child: child!),
    );
    if (picked == null || !mounted) return;
    setState(() {
      _when = DateTime(
        picked.year,
        picked.month,
        picked.day,
        _when.hour,
        _when.minute,
      );
    });
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_when),
      helpText: 'SCHEDULE · TIME',
      cancelText: 'BACK',
      confirmText: 'SET TIME',
      builder: (context, child) =>
          Theme(data: _pickerTheme(context), child: child!),
    );
    if (picked == null || !mounted) return;
    setState(() {
      _when = DateTime(
        _when.year,
        _when.month,
        _when.day,
        picked.hour,
        picked.minute,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: TColors.panel2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.zero,
        side: const BorderSide(color: TColors.line),
      ),
      child: SizedBox(
        width: 440,
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
                    'MEDIA TRANSPORT / SCHEDULE',
                    style: TText.mono(
                      context,
                      size: 10.5,
                      letterSpacing: 0.18,
                      color: TColors.amber,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    widget.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
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
              padding: const EdgeInsets.fromLTRB(18, 14, 18, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.url,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TText.mono(
                      context,
                      size: 10.5,
                      color: TColors.textMuted,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      _WhenChip(
                        icon: Icons.calendar_today_outlined,
                        label: _dateLabel,
                        onTap: _pickDate,
                      ),
                      const SizedBox(width: 10),
                      _WhenChip(
                        icon: Icons.schedule,
                        label: _timeLabel,
                        onTap: _pickTime,
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Text(
                    describeRelative(_when),
                    style: TText.mono(
                      context,
                      size: 12,
                      letterSpacing: 0.08,
                      color: TColors.green,
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: TColors.lineSoft),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              child: Row(
                children: [
                  InkWell(
                    onTap: () => Navigator.of(context).pop(),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.chevron_left,
                            size: 14,
                            color: TColors.textDim,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'GO BACK',
                            style: TText.mono(
                              context,
                              size: 10,
                              letterSpacing: 0.06,
                              color: TColors.textDim,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: () => Navigator.of(context).pop(_when),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 9,
                      ),
                      color: TColors.amber,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.schedule,
                            size: 13,
                            color: Color(0xFF14120F),
                          ),
                          const SizedBox(width: 7),
                          Text(
                            'SCHEDULE',
                            style: TText.display(
                              context,
                              size: 12,
                              weight: FontWeight.w700,
                              color: const Color(0xFF14120F),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String get _dateLabel {
    final weekday = _weekdays[_when.weekday - 1];
    return '$weekday ${_two(_when.month)}/${_two(_when.day)}';
  }

  String get _timeLabel => '${_two(_when.hour)}:${_two(_when.minute)}';
}

class _WhenChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _WhenChip({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: TColors.jackBg,
          border: Border.all(color: TColors.line),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13, color: TColors.amber),
            const SizedBox(width: 8),
            Text(
              label,
              style: TText.mono(context, size: 12, color: TColors.text)
                  .copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.arrow_drop_down, size: 13, color: TColors.textDim),
          ],
        ),
      ),
    );
  }
}