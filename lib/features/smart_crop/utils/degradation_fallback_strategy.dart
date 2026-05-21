import 'package:dailywallpaper/features/smart_crop/models/crop_settings.dart';

/// Represents a fallback processing strategy when system is under pressure
class FallbackStrategy {
  final String name;
  final CropSettings settings;
  final Duration timeout;

  const FallbackStrategy({
    required this.name,
    required this.settings,
    required this.timeout,
  });

  @override
  String toString() =>
      'FallbackStrategy($name, timeout: ${timeout.inMilliseconds}ms)';
}
