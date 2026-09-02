/// Shared date/time formatting helpers for the schedule feature.
library;

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
