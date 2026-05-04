import 'dart:ui' as ui;

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

  /// Bounding box of the main subject (0.0 to 1.0, relative to image width/height)
  final ui.Rect? subjectBounds;

  /// Whether the crop was scaled/zoomed out to fit the subject
  final bool scalingApplied;

  const CropCoordinates({
    required this.x,
    required this.y,
    required this.width,
    required this.height,
    required this.confidence,
    required this.strategy,
    this.subjectBounds,
    this.scalingApplied = false,
  });

  /// Factory for an empty/default crop
  factory CropCoordinates.empty(String strategy) => CropCoordinates(
    x: 0,
    y: 0,
    width: 1,
    height: 1,
    confidence: 0,
    strategy: strategy,
  );

  /// Creates a copy with modified values
  CropCoordinates copyWith({
    double? x,
    double? y,
    double? width,
    double? height,
    double? confidence,
    String? strategy,
    ui.Rect? subjectBounds,
    bool? scalingApplied,
  }) {
    return CropCoordinates(
      x: x ?? this.x,
      y: y ?? this.y,
      width: width ?? this.width,
      height: height ?? this.height,
      confidence: confidence ?? this.confidence,
      strategy: strategy ?? this.strategy,
      subjectBounds: subjectBounds ?? this.subjectBounds,
      scalingApplied: scalingApplied ?? this.scalingApplied,
    );
  }

  /// Validates that coordinates are within valid bounds
  bool get isValid {
    return x >= 0.0 &&
        x <= 1.0 &&
        y >= 0.0 &&
        y <= 1.0 &&
        width > 0.0 &&
        width <= 1.0 &&
        height > 0.0 &&
        height <= 1.0 &&
        (x + width) <= 1.0 &&
        (y + height) <= 1.0 &&
        confidence >= 0.0 &&
        confidence <= 1.0;
  }

  /// Converts to JSON for serialization
  Map<String, dynamic> toJson() {
    final map = {
      'x': x,
      'y': y,
      'width': width,
      'height': height,
      'confidence': confidence,
      'strategy': strategy,
      'scalingApplied': scalingApplied,
    };
    
    if (subjectBounds != null) {
      map['subjectBounds'] = {
        'left': subjectBounds!.left,
        'top': subjectBounds!.top,
        'right': subjectBounds!.right,
        'bottom': subjectBounds!.bottom,
      };
    }
    
    return map;
  }

  /// Creates from JSON
  factory CropCoordinates.fromJson(Map<String, dynamic> json) {
    ui.Rect? bounds;
    if (json['subjectBounds'] != null) {
      final b = json['subjectBounds'];
      bounds = ui.Rect.fromLTRB(
        (b['left'] ?? 0.0).toDouble(),
        (b['top'] ?? 0.0).toDouble(),
        (b['right'] ?? 0.0).toDouble(),
        (b['bottom'] ?? 0.0).toDouble(),
      );
    }

    return CropCoordinates(
      x: (json['x'] ?? 0.0).toDouble(),
      y: (json['y'] ?? 0.0).toDouble(),
      width: (json['width'] ?? 1.0).toDouble(),
      height: (json['height'] ?? 1.0).toDouble(),
      confidence: (json['confidence'] ?? 0.0).toDouble(),
      strategy: json['strategy'] ?? 'unknown',
      scalingApplied: json['scalingApplied'] ?? false,
      subjectBounds: bounds,
    );
  }

  @override
  String toString() {
    return 'CropCoordinates(x: $x, y: $y, width: $width, height: $height, confidence: $confidence, strategy: $strategy, subjectBounds: $subjectBounds, scalingApplied: $scalingApplied)';
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
        other.strategy == strategy &&
        other.subjectBounds == subjectBounds &&
        other.scalingApplied == scalingApplied;
  }

  @override
  int get hashCode {
    return Object.hash(x, y, width, height, confidence, strategy, subjectBounds, scalingApplied);
  }
}
