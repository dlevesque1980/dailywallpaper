import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
      : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[Locale('en')];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'Daily Wallpaper'**
  String get appTitle;

  /// No description provided for @analysisInProgress.
  ///
  /// In en, this message translates to:
  /// **'Analysis in progress...'**
  String get analysisInProgress;

  /// No description provided for @cropAnalysis.
  ///
  /// In en, this message translates to:
  /// **'Crop Analysis'**
  String get cropAnalysis;

  /// No description provided for @strategy.
  ///
  /// In en, this message translates to:
  /// **'Strategy'**
  String get strategy;

  /// No description provided for @confidence.
  ///
  /// In en, this message translates to:
  /// **'Confidence'**
  String get confidence;

  /// No description provided for @targetAspect.
  ///
  /// In en, this message translates to:
  /// **'Target Aspect'**
  String get targetAspect;

  /// No description provided for @coordinatesNormalized.
  ///
  /// In en, this message translates to:
  /// **'Coordinates (Normalized)'**
  String get coordinatesNormalized;

  /// No description provided for @subjectDetection.
  ///
  /// In en, this message translates to:
  /// **'Subject Detection'**
  String get subjectDetection;

  /// No description provided for @bounds.
  ///
  /// In en, this message translates to:
  /// **'Bounds'**
  String get bounds;

  /// No description provided for @close.
  ///
  /// In en, this message translates to:
  /// **'CLOSE'**
  String get close;

  /// No description provided for @optimizingWallpapers.
  ///
  /// In en, this message translates to:
  /// **'Optimizing wallpapers...'**
  String get optimizingWallpapers;

  /// No description provided for @analyzingForCrop.
  ///
  /// In en, this message translates to:
  /// **'Analyzing for the best crop'**
  String get analyzingForCrop;

  /// No description provided for @settings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// No description provided for @history.
  ///
  /// In en, this message translates to:
  /// **'History'**
  String get history;

  /// No description provided for @noWallpapersFound.
  ///
  /// In en, this message translates to:
  /// **'No wallpapers found'**
  String get noWallpapersFound;

  /// No description provided for @errorLoadingImagesForDate.
  ///
  /// In en, this message translates to:
  /// **'Error loading images for selected date'**
  String get errorLoadingImagesForDate;

  /// No description provided for @retry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retry;

  /// No description provided for @noImagesAvailable.
  ///
  /// In en, this message translates to:
  /// **'No images available'**
  String get noImagesAvailable;

  /// No description provided for @noWallpapersDownloadedToday.
  ///
  /// In en, this message translates to:
  /// **'No wallpapers have been downloaded yet today.\nCheck back later or visit the Home page to download today\'s images.'**
  String get noWallpapersDownloadedToday;

  /// No description provided for @noWallpapersSavedForDate.
  ///
  /// In en, this message translates to:
  /// **'No wallpapers were saved for {date}.'**
  String noWallpapersSavedForDate(String date);

  /// No description provided for @goToHome.
  ///
  /// In en, this message translates to:
  /// **'Go to Home'**
  String get goToHome;

  /// No description provided for @viewRecentImages.
  ///
  /// In en, this message translates to:
  /// **'View Recent Images'**
  String get viewRecentImages;

  /// No description provided for @noHistoricalImagesFound.
  ///
  /// In en, this message translates to:
  /// **'No historical images found in the database.'**
  String get noHistoricalImagesFound;

  /// No description provided for @databaseError.
  ///
  /// In en, this message translates to:
  /// **'Database Error'**
  String get databaseError;

  /// No description provided for @connectionError.
  ///
  /// In en, this message translates to:
  /// **'Connection Error'**
  String get connectionError;

  /// No description provided for @error.
  ///
  /// In en, this message translates to:
  /// **'Error'**
  String get error;

  /// No description provided for @databaseErrorMessage.
  ///
  /// In en, this message translates to:
  /// **'There was a problem accessing the image database. This might be a temporary issue.'**
  String get databaseErrorMessage;

  /// No description provided for @networkErrorMessage.
  ///
  /// In en, this message translates to:
  /// **'Unable to connect to the server. Please check your internet connection and try again.'**
  String get networkErrorMessage;

  /// No description provided for @unexpectedErrorMessage.
  ///
  /// In en, this message translates to:
  /// **'An unexpected error occurred while loading images. Please try again.'**
  String get unexpectedErrorMessage;

  /// No description provided for @loadingImagesForDate.
  ///
  /// In en, this message translates to:
  /// **'Loading images for {date}...'**
  String loadingImagesForDate(String date);

  /// No description provided for @home.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get home;

  /// No description provided for @today.
  ///
  /// In en, this message translates to:
  /// **'today'**
  String get today;

  /// No description provided for @yesterday.
  ///
  /// In en, this message translates to:
  /// **'yesterday'**
  String get yesterday;

  /// No description provided for @setLockScreenWallpaper.
  ///
  /// In en, this message translates to:
  /// **'Set lock screen wallpaper'**
  String get setLockScreenWallpaper;

  /// No description provided for @applyWallpaperToLockScreen.
  ///
  /// In en, this message translates to:
  /// **'Apply wallpaper to lock screen'**
  String get applyWallpaperToLockScreen;

  /// No description provided for @bingRegion.
  ///
  /// In en, this message translates to:
  /// **'Bing region'**
  String get bingRegion;

  /// No description provided for @selectPreferredRegion.
  ///
  /// In en, this message translates to:
  /// **'Select your preferred region for Bing images'**
  String get selectPreferredRegion;

  /// No description provided for @pexelsCategories.
  ///
  /// In en, this message translates to:
  /// **'Pexels Categories'**
  String get pexelsCategories;

  /// No description provided for @selectAtLeastOneCategory.
  ///
  /// In en, this message translates to:
  /// **'Please select at least one category'**
  String get selectAtLeastOneCategory;

  /// No description provided for @noMoreThanFiveCategories.
  ///
  /// In en, this message translates to:
  /// **'No more than 5 categories'**
  String get noMoreThanFiveCategories;

  /// No description provided for @mlEngineStatus.
  ///
  /// In en, this message translates to:
  /// **'ML Engine Status'**
  String get mlEngineStatus;

  /// No description provided for @simulatedEmulator.
  ///
  /// In en, this message translates to:
  /// **'Simulated (Emulator)'**
  String get simulatedEmulator;

  /// No description provided for @active.
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get active;

  /// No description provided for @modelSubjectSegmentation.
  ///
  /// In en, this message translates to:
  /// **'Model: Subject Segmentation v8 (Mobile f16)'**
  String get modelSubjectSegmentation;

  /// No description provided for @realMlDisabledEmulator.
  ///
  /// In en, this message translates to:
  /// **'⚠️ Real ML is disabled on emulator to avoid crashes.'**
  String get realMlDisabledEmulator;

  /// No description provided for @selectRegion.
  ///
  /// In en, this message translates to:
  /// **'Select Region'**
  String get selectRegion;

  /// No description provided for @wallpaperSetSuccess.
  ///
  /// In en, this message translates to:
  /// **'Wallpaper set successfully'**
  String get wallpaperSetSuccess;

  /// No description provided for @failedToSetWallpaper.
  ///
  /// In en, this message translates to:
  /// **'Failed to set wallpaper'**
  String get failedToSetWallpaper;

  /// No description provided for @failedToFetchWallpapers.
  ///
  /// In en, this message translates to:
  /// **'Failed to fetch wallpapers'**
  String get failedToFetchWallpapers;

  /// No description provided for @failedToRefreshWallpapers.
  ///
  /// In en, this message translates to:
  /// **'Failed to refresh wallpapers'**
  String get failedToRefreshWallpapers;

  /// No description provided for @invalidImageIndex.
  ///
  /// In en, this message translates to:
  /// **'Invalid image index'**
  String get invalidImageIndex;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
  }

  throw FlutterError(
      'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
      'an issue with the localizations generation tool. Please file an issue '
      'on GitHub with a reproducible sample app and the gen-l10n configuration '
      'that was used.');
}
