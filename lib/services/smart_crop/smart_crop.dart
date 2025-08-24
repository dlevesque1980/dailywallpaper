/// Smart Crop Library
/// 
/// Provides intelligent image cropping capabilities for optimizing wallpaper
/// display across different screen ratios using local analysis algorithms.

// Main orchestrator
export 'smart_cropper.dart';

// Preferences and settings
export 'smart_crop_preferences.dart';

// Models
export 'models/crop_coordinates.dart';
export 'models/crop_score.dart';
export 'models/crop_result.dart';
export 'models/crop_settings.dart';

// Interfaces
export 'interfaces/crop_analyzer.dart';

// Analyzers
export 'analyzers/analyzers.dart';

// Cache system
export 'cache/cache.dart';

// Utilities
export 'utils/utils.dart';