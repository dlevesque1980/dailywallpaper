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
  String get analysisInProgress => 'Analysis in progress...';

  @override
  String get cropAnalysis => 'Crop Analysis';

  @override
  String get strategy => 'Strategy';

  @override
  String get confidence => 'Confidence';

  @override
  String get targetAspect => 'Target Aspect';

  @override
  String get coordinatesNormalized => 'Coordinates (Normalized)';

  @override
  String get subjectDetection => 'Subject Detection';

  @override
  String get bounds => 'Bounds';

  @override
  String get close => 'CLOSE';

  @override
  String get optimizingWallpapers => 'Optimizing wallpapers...';

  @override
  String get analyzingForCrop => 'Analyzing for the best crop';

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
      'No wallpapers have been downloaded yet today.\nCheck back later or visit the Home page to download today\'s images.';

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
      'No historical images found in the database.';

  @override
  String get databaseError => 'Database Error';

  @override
  String get connectionError => 'Connection Error';

  @override
  String get error => 'Error';

  @override
  String get databaseErrorMessage =>
      'There was a problem accessing the image database. This might be a temporary issue.';

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
  String get bingRegion => 'Bing region';

  @override
  String get selectPreferredRegion =>
      'Select your preferred region for Bing images';

  @override
  String get pexelsCategories => 'Pexels Categories';

  @override
  String get selectAtLeastOneCategory => 'Please select at least one category';

  @override
  String get noMoreThanFiveCategories => 'No more than 5 categories';

  @override
  String get mlEngineStatus => 'ML Engine Status';

  @override
  String get simulatedEmulator => 'Simulated (Emulator)';

  @override
  String get active => 'Active';

  @override
  String get modelSubjectSegmentation =>
      'Model: Subject Segmentation v8 (Mobile f16)';

  @override
  String get realMlDisabledEmulator =>
      '⚠️ Real ML is disabled on emulator to avoid crashes.';

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
