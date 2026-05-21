import 'package:workmanager/workmanager.dart';
import 'package:flutter/foundation.dart';
import 'daily_fetch_task.dart';

class BackgroundScheduler {
  static const String uniqueTaskId = "daily_wallpaper_fetch_job";

  /// Schedules the next fetch task at 5:00 AM.
  static Future<void> scheduleNextDailyFetch() async {
    final now = DateTime.now();

    // Target 5:00 AM
    var scheduledDate = DateTime(now.year, now.month, now.day, 5, 0, 0);

    // If it's already past 5:00 AM today, schedule for tomorrow
    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }

    final delay = scheduledDate.difference(now);

    debugPrint(
        'BackgroundScheduler: Next fetch scheduled in ${delay.inHours}h ${delay.inMinutes % 60}m (at $scheduledDate)');

    await Workmanager().registerOneOffTask(
      uniqueTaskId,
      DailyFetchTask.taskName,
      initialDelay: delay,
      constraints: Constraints(
        networkType: NetworkType.connected,
      ),
      existingWorkPolicy: ExistingWorkPolicy.replace,
    );
  }

  /// Cancels all background tasks
  static Future<void> cancelAll() async {
    await Workmanager().cancelAll();
  }
}
