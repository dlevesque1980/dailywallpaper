import 'package:intl/intl.dart';

class DateTimeHelper {
  static DateTime startDayDate(DateTime datetime) {
    return DateTime(datetime.year, datetime.month, datetime.day);
  }

  static DateTime endDayDate(DateTime datetime) {
    return DateTime(datetime.year, datetime.month, datetime.day, 23, 59, 59);
  }

  static String formatDisplayDate(DateTime date, {String? todayLabel, String? yesterdayLabel}) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final dateOnly = DateTime(date.year, date.month, date.day);

    if (dateOnly == today && todayLabel != null) {
      return todayLabel;
    } else if (dateOnly == yesterday && yesterdayLabel != null) {
      return yesterdayLabel;
    } else {
      return DateFormat('MMM d, y').format(date);
    }
  }
}
