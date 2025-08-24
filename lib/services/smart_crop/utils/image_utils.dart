import 'dart:ui' as ui;
import 'dart:typed_data';
import 'dart:math' as math;
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import '../models/crop_coordinates.dart';

/// Utility functions for image processing and crop operations
class ImageUtils {
  /// Loads an image from a URL
  /// 
  /// [url] The URL of the image to load
  /// 
  /// Returns a ui.Image or null if loading fails
  static Future<ui.Image?> loadImageFromUrl(String url) async {
    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final bytes = response.bodyBytes;
        final codec = await ui.instantiateImageCodec(bytes);
        final frame = await codec.getNextFrame();
        return frame.image;
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  /// Downscales an image while preserving aspect ratio for analysis
  /// 
  /// [image] The source image to downscale
  /// [maxDimension] Maximum width or height for the downscaled image
  /// 
  /// Returns a downscaled image suitable for analysis
  static Future<ui.Image> downscaleForAnalysis(ui.Image image, {int maxDimension = 512}) async {
    final originalWidth = image.width;
    final originalHeight = image.height;
    
    // If image is already small enough, return as-is
    if (originalWidth <= maxDimension && originalHeight <= maxDimension) {
      return image;
    }
    
    // Calculate new dimensions preserving aspect ratio
    final aspectRatio = originalWidth / originalHeight;
    late int newWidth, newHeight;
    
    if (originalWidth > originalHeight) {
      newWidth = maxDimension;
      newHeight = (maxDimension / aspectRatio).round();
    } else {
      newHeight = maxDimension;
      newWidth = (maxDimension * aspectRatio).round();
    }
    
    // Create a picture recorder to draw the scaled image
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);
    
    // Draw the image scaled to new dimensions
    canvas.drawImageRect(
      image,
      ui.Rect.fromLTWH(0, 0, originalWidth.toDouble(), originalHeight.toDouble()),
      ui.Rect.fromLTWH(0, 0, newWidth.toDouble(), newHeight.toDouble()),
      ui.Paint(),
    );
    
    // Convert to image
    final picture = recorder.endRecording();
    final scaledImage = await picture.toImage(newWidth, newHeight);
    picture.dispose();
    
    return scaledImage;
  }
  
  /// Converts an image to RGBA pixel data for analysis
  /// 
  /// [image] The source image to convert
  /// 
  /// Returns pixel data as Uint8List in RGBA format
  static Future<Uint8List> imageToRgbaBytes(ui.Image image) async {
    final byteData = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    if (byteData == null) {
      throw Exception('Failed to convert image to byte data');
    }
    return byteData.buffer.asUint8List();
  }
  
  /// Gets pixel color at specific coordinates
  /// 
  /// [pixels] RGBA pixel data
  /// [width] Image width
  /// [height] Image height
  /// [x] X coordinate (0 to width-1)
  /// [y] Y coordinate (0 to height-1)
  /// 
  /// Returns RGBA values as a list [r, g, b, a]
  static List<int> getPixelAt(Uint8List pixels, int width, int height, int x, int y) {
    if (x < 0 || x >= width || y < 0 || y >= height) {
      return [0, 0, 0, 0]; // Transparent black for out-of-bounds
    }
    
    final index = (y * width + x) * 4;
    return [
      pixels[index],     // R
      pixels[index + 1], // G
      pixels[index + 2], // B
      pixels[index + 3], // A
    ];
  }
  
  /// Calculates luminance of a pixel for grayscale conversion
  /// 
  /// [r] Red component (0-255)
  /// [g] Green component (0-255)
  /// [b] Blue component (0-255)
  /// 
  /// Returns luminance value (0.0 to 1.0)
  static double calculateLuminance(int r, int g, int b) {
    // Using standard luminance formula
    return (0.299 * r + 0.587 * g + 0.114 * b) / 255.0;
  }
  
  /// Validates crop coordinates and ensures they're within bounds
  /// 
  /// [coordinates] The crop coordinates to validate
  /// [imageWidth] Width of the source image
  /// [imageHeight] Height of the source image
  /// 
  /// Returns validated and clamped coordinates
  static CropCoordinates validateAndClampCoordinates(
    CropCoordinates coordinates,
    int imageWidth,
    int imageHeight,
  ) {
    // Clamp values to valid ranges
    final clampedX = math.max(0.0, math.min(1.0, coordinates.x));
    final clampedY = math.max(0.0, math.min(1.0, coordinates.y));
    
    // Ensure width and height don't exceed remaining space
    final maxWidth = 1.0 - clampedX;
    final maxHeight = 1.0 - clampedY;
    final clampedWidth = math.max(0.01, math.min(maxWidth, coordinates.width));
    final clampedHeight = math.max(0.01, math.min(maxHeight, coordinates.height));
    final clampedConfidence = math.max(0.0, math.min(1.0, coordinates.confidence));
    
    return CropCoordinates(
      x: clampedX,
      y: clampedY,
      width: clampedWidth,
      height: clampedHeight,
      confidence: clampedConfidence,
      strategy: coordinates.strategy,
    );
  }
  
  /// Checks if crop coordinates are within valid bounds
  /// 
  /// [coordinates] The crop coordinates to check
  /// 
  /// Returns true if coordinates are valid
  static bool areCoordinatesValid(CropCoordinates coordinates) {
    return coordinates.x >= 0.0 &&
           coordinates.y >= 0.0 &&
           coordinates.width > 0.0 &&
           coordinates.height > 0.0 &&
           coordinates.x + coordinates.width <= 1.0 &&
           coordinates.y + coordinates.height <= 1.0 &&
           coordinates.confidence >= 0.0 &&
           coordinates.confidence <= 1.0;
  }
  
  /// Converts relative coordinates to absolute pixel coordinates
  /// 
  /// [coordinates] Relative crop coordinates (0.0 to 1.0)
  /// [imageWidth] Width of the source image in pixels
  /// [imageHeight] Height of the source image in pixels
  /// 
  /// Returns absolute coordinates as [x, y, width, height]
  static List<int> relativeToAbsolute(
    CropCoordinates coordinates,
    int imageWidth,
    int imageHeight,
  ) {
    return [
      (coordinates.x * imageWidth).round(),
      (coordinates.y * imageHeight).round(),
      (coordinates.width * imageWidth).round(),
      (coordinates.height * imageHeight).round(),
    ];
  }
  
  /// Converts absolute pixel coordinates to relative coordinates
  /// 
  /// [x] X coordinate in pixels
  /// [y] Y coordinate in pixels
  /// [width] Width in pixels
  /// [height] Height in pixels
  /// [imageWidth] Width of the source image in pixels
  /// [imageHeight] Height of the source image in pixels
  /// [strategy] Strategy name for the coordinates
  /// [confidence] Confidence score (0.0 to 1.0)
  /// 
  /// Returns relative crop coordinates
  static CropCoordinates absoluteToRelative(
    int x,
    int y,
    int width,
    int height,
    int imageWidth,
    int imageHeight,
    String strategy,
    double confidence,
  ) {
    return CropCoordinates(
      x: x / imageWidth,
      y: y / imageHeight,
      width: width / imageWidth,
      height: height / imageHeight,
      confidence: confidence,
      strategy: strategy,
    );
  }
  
  /// Calculates the area of a crop as a percentage of the original image
  /// 
  /// [coordinates] The crop coordinates
  /// 
  /// Returns area as a value between 0.0 and 1.0
  static double calculateCropArea(CropCoordinates coordinates) {
    return coordinates.width * coordinates.height;
  }
  
  /// Calculates the center point of a crop area
  /// 
  /// [coordinates] The crop coordinates
  /// 
  /// Returns center point as [x, y] in relative coordinates
  static List<double> calculateCropCenter(CropCoordinates coordinates) {
    return [
      coordinates.x + coordinates.width / 2,
      coordinates.y + coordinates.height / 2,
    ];
  }
  
  /// Calculates the aspect ratio of a crop area
  /// 
  /// [coordinates] The crop coordinates
  /// 
  /// Returns aspect ratio (width / height)
  static double calculateCropAspectRatio(CropCoordinates coordinates) {
    return coordinates.width / coordinates.height;
  }
  
  /// Creates a center crop with the specified aspect ratio
  /// 
  /// [targetAspectRatio] Desired aspect ratio (width / height)
  /// [strategy] Strategy name for the coordinates
  /// [confidence] Confidence score (0.0 to 1.0)
  /// 
  /// Returns center crop coordinates
  static CropCoordinates createCenterCrop(
    double targetAspectRatio,
    String strategy,
    double confidence,
  ) {
    // Assume source image has aspect ratio of 1.0 (square) for calculation
    // This creates a crop that maintains the target aspect ratio
    double cropWidth, cropHeight;
    
    if (targetAspectRatio > 1.0) {
      // Target is wider than tall - crop height, keep full width
      cropWidth = 1.0;
      cropHeight = 1.0 / targetAspectRatio;
    } else {
      // Target is taller than wide - crop width, keep full height
      cropHeight = 1.0;
      cropWidth = targetAspectRatio;
    }
    
    return CropCoordinates(
      x: (1.0 - cropWidth) / 2,
      y: (1.0 - cropHeight) / 2,
      width: cropWidth,
      height: cropHeight,
      confidence: confidence,
      strategy: strategy,
    );
  }

  /// Converts a ui.Image to Uint8List bytes
  /// 
  /// [image] The image to convert
  /// [format] The image format (default: PNG for lossless quality)
  /// 
  /// Returns image bytes or null if conversion fails
  static Future<Uint8List?> imageToBytes(ui.Image image, {ui.ImageByteFormat format = ui.ImageByteFormat.png}) async {
    try {
      final byteData = await image.toByteData(format: format);
      if (byteData == null) {
        return null;
      }
      return byteData.buffer.asUint8List();
    } catch (e) {
      return null;
    }
  }

  /// Saves a ui.Image to a temporary file
  /// 
  /// [image] The image to save
  /// [filename] The filename for the temporary file
  /// 
  /// Returns the path to the saved file or null if saving fails
  static Future<String?> saveImageToTemp(ui.Image image, String filename) async {
    try {
      // Get temporary directory
      final tempDir = await getTemporaryDirectory();
      final filePath = '${tempDir.path}/$filename';
      
      // Convert image to bytes
      final bytes = await imageToBytes(image);
      if (bytes == null) {
        return null;
      }
      
      // Write to file
      final file = File(filePath);
      await file.writeAsBytes(bytes);
      
      return filePath;
    } catch (e) {
      return null;
    }
  }

  /// Saves a ui.Image to the app's documents directory (permanent storage)
  /// 
  /// [image] The image to save
  /// [filename] The filename for the file
  /// 
  /// Returns the path to the saved file or null if saving fails
  static Future<String?> saveImageToPermanent(ui.Image image, String filename) async {
    try {
      // Get application documents directory
      final appDir = await getApplicationDocumentsDirectory();
      
      // Create wallpapers subdirectory if it doesn't exist
      final wallpaperDir = Directory('${appDir.path}/wallpapers');
      if (!await wallpaperDir.exists()) {
        await wallpaperDir.create(recursive: true);
      }
      
      final filePath = '${wallpaperDir.path}/$filename';
      
      // Convert image to bytes (use JPEG for smaller file size)
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) {
        return null;
      }
      
      // Write to file
      final file = File(filePath);
      await file.writeAsBytes(byteData.buffer.asUint8List());
      
      return filePath;
    } catch (e) {
      return null;
    }
  }

  /// Cleans up old wallpaper files to save storage space
  /// 
  /// [maxAge] Maximum age of files to keep (default: 7 days)
  /// 
  /// Returns the number of files deleted
  static Future<int> cleanupOldWallpapers({Duration maxAge = const Duration(days: 7)}) async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final wallpaperDir = Directory('${appDir.path}/wallpapers');
      
      if (!await wallpaperDir.exists()) {
        return 0;
      }
      
      final cutoffTime = DateTime.now().subtract(maxAge);
      int deletedCount = 0;
      
      await for (final entity in wallpaperDir.list()) {
        if (entity is File) {
          final stat = await entity.stat();
          if (stat.modified.isBefore(cutoffTime)) {
            try {
              await entity.delete();
              deletedCount++;
            } catch (e) {
              // Continue with other files if one fails to delete
            }
          }
        }
      }
      
      return deletedCount;
    } catch (e) {
      return 0;
    }
  }
}