import 'package:dailywallpaper/features/wallpaper/domain/usecases/fetch_daily_images.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter/foundation.dart';
import 'package:workmanager/workmanager.dart';
import 'package:dailywallpaper/services/background/background_scheduler.dart';
import 'package:dailywallpaper/services/image_cache_service.dart';
import 'package:dailywallpaper/core/database/database_helper.dart';

class DailyFetchTask {
  static const String taskName = "dailyFetchTask";

  @pragma('vm:entry-point')
  static Future<bool> execute() async {
    debugPrint('Background Task: Starting daily fetch...');

    try {
      // 1. Load environment variables for API keys
      try {
        await dotenv.load(fileName: ".env");
      } catch (e) {
        debugPrint('Background Task Warning: Could not load .env file ($e)');
      }

      // 2. Initialize and execute UseCase
      final useCase = FetchDailyImagesUseCase();
      final images = await useCase(forceRefresh: false);

      debugPrint(
          'Background Task: Successfully fetched ${images.length} images.');

      // 3. Pre-download source images to local disk
      final imageCache = ImageCacheServiceImpl();
      final dbHelper = DatabaseHelper();
      int downloaded = 0;
      for (final image in images) {
        final path = await imageCache.downloadAndSaveSourceImage(
            image.url, image.imageIdent);
        if (path != null) {
          downloaded++;
          await dbHelper.updateImagePaths(
            image.imageIdent,
            localSourcePath: path,
          );
        }
      }
      debugPrint(
          'Background Task: Pre-downloaded $downloaded source images to local disk.');

      // 4. Clean up old local cache files (older than 2 days)
      final deleted = await imageCache.cleanupOldWallpapers(
          maxAge: const Duration(days: 2));
      debugPrint('Background Task: Cleaned up $deleted old cache files.');

      // 5. Reschedule for tomorrow if it was a one-time task
      // Note: We use one-time tasks for precise timing (WorkManager periodic is less flexible)
      await BackgroundScheduler.scheduleNextDailyFetch();

      return true;
    } catch (e) {
      debugPrint('Background Task Error: $e');
      return false;
    }
  }
}
