/// Represents the coordinates and metadata for a crop area
class CropCoordinates {
  /// X coordinate of the crop area (0.0 to 1.0, relative to image width)
  final double x;
  
  /// Y coordinate of the crop area (0.0 to 1.0, relative to image height)
  final double y;
  
  /// Width of the crop area (0.0 to 1.0, relative to image width)
  final double width;
  
  /// Height of the crop area (0.0 to 1.0, relative to image height)
  final double height;
  
  /// Confidence score for this crop (0.0 to 1.0)
  final double confidence;
  
  /// Strategy that generated this crop
  final String strategy;

  const CropCoordinates({
    required this.x,
    required this.y,
    required this.width,
    required this.height,
    required this.confidence,
    required this.strategy,
  });

  /// Creates a copy with modified values
  CropCoordinates copyWith({
    double? x,
    double? y,
    double? width,
    double? height,
    double? confidence,
    String? strategy,
  }) {
    return CropCoordinates(
      x: x ?? this.x,
      y: y ?? this.y,
      width: width ?? this.width,
      height: height ?? this.height,
      confidence: confidence ?? this.confidence,
      strategy: strategy ?? this.strategy,
    );
  }

  /// Validates that coordinates are within valid bounds
  bool get isValid {
    return x >= 0.0 && x <= 1.0 &&
           y >= 0.0 && y <= 1.0 &&
           width > 0.0 && width <= 1.0 &&
           height > 0.0 && height <= 1.0 &&
           (x + width) <= 1.0 &&
           (y + height) <= 1.0 &&
           confidence >= 0.0 && confidence <= 1.0;
  }

  @override
  String toString() {
    return 'CropCoordinates(x: $x, y: $y, width: $width, height: $height, confidence: $confidence, strategy: $strategy)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is CropCoordinates &&
           other.x == x &&
           other.y == y &&
           other.width == width &&
           other.height == height &&
           other.confidence == confidence &&
           other.strategy == strategy;
  }

  @override
  int get hashCode {
    return Object.hash(x, y, width, height, confidence, strategy);
  }
}