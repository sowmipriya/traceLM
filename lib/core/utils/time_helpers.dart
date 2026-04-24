import 'package:intl/intl.dart';

class TimeHelpers {
  TimeHelpers._();

  static final DateFormat dayFormatter = DateFormat('yyyy-MM-dd');
  static final DateFormat resetFormatter = DateFormat('MMM d, y  HH:mm');

  static DateTime startOfDay(DateTime date) =>
      DateTime(date.year, date.month, date.day);

  static DateTime? parseISODate(String? value) {
    if (value == null || value.isEmpty) return null;
    return DateTime.tryParse(value)?.toLocal();
  }

  static String iso8601(DateTime date) => date.toUtc().toIso8601String();

  static String? relativeResetString(DateTime? date) {
    if (date == null) return null;
    final remaining = date.difference(DateTime.now()).inSeconds;
    if (remaining <= 0) return null;
    final days = remaining ~/ 86400;
    final hours = (remaining % 86400) ~/ 3600;
    final minutes = (remaining % 3600) ~/ 60;
    if (days > 0) return '${days}d ${hours}h';
    if (hours > 0) return '${hours}h ${minutes}m';
    if (minutes > 0) return '${minutes}m';
    return '<1m';
  }

  static String? absoluteResetString(DateTime? date) =>
      date == null ? null : resetFormatter.format(date);
}
