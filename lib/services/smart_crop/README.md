# Smart Crop Feature Documentation

## Overview

The Smart Crop feature automatically optimizes wallpaper images for different screen ratios using intelligent cropping algorithms. Instead of simply stretching or center-cropping images, it analyzes the content to determine the best crop area that preserves important visual elements.

## Features

### Intelligent Cropping Algorithms
- **Rule of Thirds**: Positions crops based on photography composition principles
- **Center Weighted**: Balances center bias with content analysis for conservative cropping
- **Entropy Based**: Identifies areas with high visual information and complexity
- **Edge Detection**: Focuses on areas with strong edges and important boundaries

### Performance Optimizations
- **Device Capability Detection**: Automatically adapts processing based on device performance
- **Battery Optimization**: Reduces processing intensity when battery is low
- **Memory Management**: Monitors memory usage and applies graceful degradation
- **Caching System**: Stores crop coordinates to avoid reprocessing the same images

### Adaptive Processing
- **Background Processing**: Uses isolates for heavy processing on capable devices
- **Timeout Management**: Ensures processing doesn't block the UI
- **Fallback Mechanisms**: Gracefully handles errors and resource constraints

## Usage

### Basic Usage

```dart
import 'package:dailywallpaper/services/smart_crop/smart_crop.dart';

// Analyze and get crop coordinates
final result = await SmartCropper.analyzeCrop(
  'image_url_or_id',
  sourceImage,
  targetSize,
  CropSettings.defaultSettings,
);

// Apply the crop to get the final image
final croppedImage = await SmartCropper.applyCrop(
  sourceImage,
  result.bestCrop,
);
```

### Complete Processing Pipeline

```dart
// Process image with analysis and cropping in one call
final processedResult = await SmartCropper.processImage(
  'image_url_or_id',
  sourceImage,
  targetSize,
  CropSettings.defaultSettings,
);

final croppedImage = processedResult.image;
final cropAnalysis = processedResult.cropResult;
```

### Custom Settings

```dart
final customSettings = CropSettings(
  aggressiveness: CropAggressiveness.balanced,
  enableRuleOfThirds: true,
  enableEntropyAnalysis: true,
  enableEdgeDetection: false, // Disable for better performance
  enableCenterWeighting: true,
  maxProcessingTime: Duration(seconds: 2),
);

final result = await SmartCropper.analyzeCrop(
  'image_id',
  sourceImage,
  targetSize,
  customSettings,
);
```

## Settings Configuration

### Crop Aggressiveness
- **Conservative**: Favors center-weighted and rule of thirds, safer crops
- **Balanced**: Equal weighting for all strategies (default)
- **Aggressive**: Favors entropy and edge detection for more dynamic crops

### Strategy Selection
Enable or disable individual cropping strategies based on your needs:
- `enableRuleOfThirds`: Photography composition-based cropping
- `enableEntropyAnalysis`: Content density-based cropping (CPU intensive)
- `enableEdgeDetection`: Edge-based cropping (CPU intensive)
- `enableCenterWeighting`: Conservative center-biased cropping

### Performance Settings
- `maxProcessingTime`: Maximum time to spend on analysis (default: 2 seconds)

## Performance Considerations

### Device Capability Detection
The system automatically detects device capabilities and adjusts processing:
- **High Performance**: Uses all strategies with full resolution analysis
- **Medium Performance**: Reduces concurrent analyzers and image resolution
- **Low Performance**: Uses only lightweight strategies with minimal resolution

### Battery Optimization
When battery is low, the system automatically:
- Disables CPU-intensive analyzers (entropy, edge detection)
- Reduces processing timeouts
- Throttles background processing
- May defer non-critical processing

### Memory Management
The system monitors memory usage and:
- Downscales images for analysis while preserving aspect ratio
- Uses background isolates for heavy processing
- Implements graceful degradation under memory pressure
- Automatically cleans up temporary image data

## Caching System

### Automatic Caching
Crop coordinates are automatically cached based on:
- Image URL or identifier
- Target size
- Crop settings

### Cache Management
```dart
// Get cache statistics
final stats = await SmartCropper.getCacheStats();

// Clear cache
await SmartCropper.clearCache();

// Perform cache maintenance
final result = await SmartCropper.performCacheMaintenance(
  ttl: Duration(days: 7),
  maxEntries: 1000,
);
```

## Performance Analytics

### Getting Performance Data
```dart
// Get comprehensive performance analytics
final analytics = SmartCropper.getPerformanceAnalytics();

// Get device capability information
final deviceInfo = await SmartCropper.getDeviceCapabilityInfo();
```

### Monitoring Metrics
The system tracks:
- Processing times and success rates
- Memory usage patterns
- Cache hit/miss ratios
- Device performance characteristics
- Battery optimization effectiveness

## Error Handling

### Automatic Fallbacks
The system provides multiple fallback mechanisms:
1. **Timeout Fallback**: If processing takes too long, uses center crop
2. **Memory Fallback**: If memory pressure detected, uses lightweight processing
3. **Error Fallback**: If analysis fails, uses safe center crop
4. **Strategy Fallback**: If all strategies fail, uses basic geometric crop

### Error Recovery
```dart
try {
  final result = await SmartCropper.analyzeCrop(imageUrl, image, targetSize, settings);
  // Use result.bestCrop
} catch (e) {
  // Fallback to standard cropping
  final fallbackCrop = CropCoordinates.centerCrop(image, targetSize);
}
```

## Integration with Existing Features

### Image Sources
Smart Crop works with all image sources:
- **Bing Wallpapers**: Optimizes landscape images for mobile screens
- **Pexels Photos**: Handles various aspect ratios and compositions
- **NASA APOD**: Adapts scientific images for wallpaper use

### Settings Screen Integration
The feature integrates with the app's settings:
- Enable/disable smart cropping
- Adjust crop aggressiveness
- Manage cache settings
- View performance statistics

### Background Processing
Smart Crop works seamlessly with:
- Image downloading and caching
- Wallpaper setting workflows
- Background refresh operations

## Best Practices

### Performance
1. Use appropriate crop aggressiveness for your use case
2. Disable heavy analyzers on low-end devices
3. Monitor cache hit rates and adjust cache size accordingly
4. Consider battery state when processing multiple images

### Quality
1. Enable multiple strategies for best results
2. Use balanced aggressiveness for general use
3. Test with various image types and aspect ratios
4. Monitor crop confidence scores

### Resource Management
1. Clear performance data periodically
2. Perform cache maintenance regularly
3. Monitor memory usage in production
4. Implement proper error handling

## Troubleshooting

### Common Issues

**Slow Processing**
- Check device capability tier
- Reduce enabled strategies
- Lower crop aggressiveness
- Increase timeout or use shorter timeout with fallback

**Poor Crop Quality**
- Enable more strategies
- Increase crop aggressiveness
- Check image resolution and quality
- Verify target size is reasonable

**High Memory Usage**
- Monitor memory statistics
- Reduce max image dimension for analysis
- Clear caches more frequently
- Check for memory leaks in image disposal

**Cache Issues**
- Verify cache database permissions
- Check available storage space
- Clear and rebuild cache if corrupted
- Monitor cache statistics

### Debug Information
```dart
// Get comprehensive debug information
final deviceInfo = await SmartCropper.getDeviceCapabilityInfo();
final analytics = SmartCropper.getPerformanceAnalytics();
final cacheStats = await SmartCropper.getCacheStats();

print('Device Tier: ${deviceInfo['device_capability']['overall_tier']}');
print('Success Rate: ${analytics['overall_stats']['success_rate']}');
print('Cache Hit Rate: ${cacheStats['hit_rate_percentage']}%');
```

## API Reference

### Main Classes
- `SmartCropper`: Main orchestrator class
- `CropSettings`: Configuration for crop analysis
- `CropResult`: Result of crop analysis
- `CropCoordinates`: Normalized crop coordinates (0.0 to 1.0)

### Utility Classes
- `DeviceCapabilityDetector`: Detects device performance characteristics
- `BatteryOptimizer`: Optimizes processing for battery usage
- `PerformanceMonitor`: Tracks and analyzes performance metrics

### Cache Classes
- `CropCacheManager`: Manages persistent crop coordinate cache
- `CropCacheDatabase`: SQLite database for cache storage

For detailed API documentation, see the individual class documentation in the source code.