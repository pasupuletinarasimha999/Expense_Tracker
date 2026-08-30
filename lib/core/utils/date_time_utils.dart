import 'package:intl/intl.dart';

/// Date/time formatting & month-range helpers, ported 1:1 from `DateTimeUtils.kt`.
/// Timestamps are epoch milliseconds (`DateTime.millisecondsSinceEpoch`), matching
/// the original `Long` timestamp columns.
class DateTimeUtils {
  DateTimeUtils._();

  static final _fullDateFormat = DateFormat('MMM dd, yyyy');
  static final _monthYearFormat = DateFormat('MMMM yyyy');
  static final _fileTimestampFormat = DateFormat('yyyyMMdd_HHmmss');
  static final _isoDateFormat = DateFormat('yyyy-MM-dd');

  static String formatDate(int timestamp) {
    return _fullDateFormat.format(DateTime.fromMillisecondsSinceEpoch(timestamp));
  }

  static String formatMonthYear(DateTime date) {
    return _monthYearFormat.format(date);
  }

  static String formatMonthYearFromTimestamp(int timestamp) {
    return _monthYearFormat.format(DateTime.fromMillisecondsSinceEpoch(timestamp));
  }

  static String formatFileTimestamp([int? timestamp]) {
    return _fileTimestampFormat.format(
      DateTime.fromMillisecondsSinceEpoch(timestamp ?? DateTime.now().millisecondsSinceEpoch),
    );
  }

  static String formatIsoDate(int timestamp) {
    return _isoDateFormat.format(DateTime.fromMillisecondsSinceEpoch(timestamp));
  }

  /// Day 1, 00:00:00.000 of the given date's month.
  static int getStartOfMonthTimestamp(DateTime date) {
    return DateTime(date.year, date.month, 1).millisecondsSinceEpoch;
  }

  /// Last day of the given date's month, 23:59:59.999.
  static int getEndOfMonthTimestamp(DateTime date) {
    final firstOfNextMonth = DateTime(date.year, date.month + 1, 1);
    return firstOfNextMonth.subtract(const Duration(milliseconds: 1)).millisecondsSinceEpoch;
  }

  static String getRelativeDateString(int timestamp) {
    final now = DateTime.now();
    final target = DateTime.fromMillisecondsSinceEpoch(timestamp);

    final nowDay = DateTime(now.year, now.month, now.day);
    final targetDay = DateTime(target.year, target.month, target.day);
    final diffDays = nowDay.difference(targetDay).inDays;

    if (diffDays == 0) return 'Today';
    if (diffDays == 1) return 'Yesterday';
    return _fullDateFormat.format(target);
  }
}
