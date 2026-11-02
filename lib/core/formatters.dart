import 'package:intl/intl.dart';

/// Date, time and currency formatting used across the app (Malaysia locale).
class Fmt {
  Fmt._();

  static final DateFormat _date = DateFormat('EEE, d MMM yyyy');
  static final DateFormat _shortDate = DateFormat('d MMM');
  static final DateFormat _time = DateFormat('h:mm a');
  static final DateFormat _dateTime = DateFormat('d MMM yyyy • h:mm a');
  static final NumberFormat _rm = NumberFormat.currency(
    locale: 'en_MY',
    symbol: 'RM ',
    decimalDigits: 2,
  );

  static String date(DateTime d) => _date.format(d);
  static String shortDate(DateTime d) => _shortDate.format(d);
  static String time(DateTime d) => _time.format(d);
  static String dateTime(DateTime d) => _dateTime.format(d);
  static String timeRange(DateTime start, DateTime end) =>
      '${_time.format(start)} – ${_time.format(end)}';
  static String rm(double v) => _rm.format(v);

  static String relative(DateTime d) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(d.year, d.month, d.day);
    final days = day.difference(today).inDays;
    if (days == 0) return d.isBefore(now) ? 'Earlier today' : 'Today';
    if (days == 1) return 'Tomorrow';
    if (days == -1) return 'Yesterday';
    if (days > 1 && days < 7) return 'In $days days';
    if (days < -1 && days > -7) return '${-days} days ago';
    return _date.format(d);
  }

  static String percent(double v) => '${v.toStringAsFixed(0)}%';
}
