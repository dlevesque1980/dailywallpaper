// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Daily Wallpaper';

  @override
  String get loadingWallpapers => 'Loading wallpapers...';

  @override
  String get settings => 'Settings';

  @override
  String get history => 'History';

  @override
  String get noWallpapersFound => 'No wallpapers found';

  @override
  String get errorLoadingImagesForDate =>
      'Error loading images for selected date';

  @override
  String get retry => 'Retry';

  @override
  String get noImagesAvailable => 'No images available';

  @override
  String get noWallpapersDownloadedToday =>
      'No wallpapers are available for today yet.';

  @override
  String noWallpapersSavedForDate(String date) {
    return 'No wallpapers were saved for $date.';
  }

  @override
  String get goToHome => 'Go to Home';

  @override
  String get viewRecentImages => 'View Recent Images';

  @override
  String get noHistoricalImagesFound =>
      'No historical wallpapers are available yet.';

  @override
  String get connectionError => 'Connection Error';

  @override
  String get error => 'Error';

  @override
  String get networkErrorMessage =>
      'Unable to connect to the server. Please check your internet connection and try again.';

  @override
  String get unexpectedErrorMessage =>
      'An unexpected error occurred while loading images. Please try again.';

  @override
  String loadingImagesForDate(String date) {
    return 'Loading images for $date...';
  }

  @override
  String get home => 'Home';

  @override
  String get today => 'today';

  @override
  String get yesterday => 'yesterday';

  @override
  String get setLockScreenWallpaper => 'Set lock screen wallpaper';

  @override
  String get applyWallpaperToLockScreen => 'Apply wallpaper to lock screen';

  @override
  String get includeNasaImages => 'Include NASA images';

  @override
  String get includeNasaImagesDescription =>
      'Allow the downloader to fetch NASA images';

  @override
  String get pexelsCategories => 'Pexels categories';

  @override
  String get selectAtLeastOneCategory => 'Select at least one category';

  @override
  String get noMoreThanThreeCategories =>
      'Select no more than three categories';

  @override
  String get cancel => 'Cancel';

  @override
  String get save => 'Save';

  @override
  String get selectRegion => 'Select Region';

  @override
  String get wallpaperSetSuccess => 'Wallpaper set successfully';

  @override
  String get failedToSetWallpaper => 'Failed to set wallpaper';

  @override
  String get failedToFetchWallpapers => 'Failed to fetch wallpapers';

  @override
  String get failedToRefreshWallpapers => 'Failed to refresh wallpapers';

  @override
  String get invalidImageIndex => 'Invalid image index';
}
