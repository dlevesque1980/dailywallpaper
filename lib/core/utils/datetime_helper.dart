class DateTimeHelper {
  static DateTime startDayDate(DateTime datetime) {
    return new DateTime(datetime.year, datetime.month, datetime.day);
  }

  static DateTime endDayDate(DateTime datetime) {
    return new DateTime(datetime.year, datetime.month, datetime.day, 23, 59, 59);
  }
}
