/// Metadata describing an analyzer's capabilities and requirements
class AnalyzerMetadata {
  /// Human-readable description of what this analyzer does
  final String description;

  /// Version of this analyzer implementation
  final String version;

  /// List of image types this analyzer works best with
  final List<String> supportedImageTypes;

  /// Minimum image dimensions required for effective analysis
  final int minImageWidth;
  final int minImageHeight;

  /// Maximum image dimensions this analyzer can handle efficiently
  final int maxImageWidth;
  final int maxImageHeight;

  /// Whether this analyzer requires significant CPU resources
  final bool isCpuIntensive;

  /// Whether this analyzer requires significant memory resources
  final bool isMemoryIntensive;

  /// Whether this analyzer can run in parallel with others
  final bool supportsParallelExecution;

  /// List of other analyzers this one depends on
  final List<String> dependencies;

  /// List of analyzers that conflict with this one
  final List<String> conflicts;

  /// Configuration options this analyzer supports
  final Map<String, dynamic> configurationOptions;

  /// Performance characteristics
  final Map<String, dynamic> performanceMetrics;

  const AnalyzerMetadata({
    required this.description,
    required this.version,
    this.supportedImageTypes = const ['jpeg', 'png', 'webp'],
    this.minImageWidth = 50,
    this.minImageHeight = 50,
    this.maxImageWidth = 4096,
    this.maxImageHeight = 4096,
    this.isCpuIntensive = false,
    this.isMemoryIntensive = false,
    this.supportsParallelExecution = true,
    this.dependencies = const [],
    this.conflicts = const [],
    this.configurationOptions = const {},
    this.performanceMetrics = const {},
  });

  /// Checks if this analyzer can handle the given image dimensions
  bool canHandleImageSize(int width, int height) {
    return width >= minImageWidth &&
        height >= minImageHeight &&
        width <= maxImageWidth &&
        height <= maxImageHeight;
  }

  /// Checks if this analyzer supports the given image type
  bool supportsImageType(String imageType) {
    return supportedImageTypes.contains(imageType.toLowerCase());
  }

  /// Checks if this analyzer has any conflicts with the given analyzer
  bool hasConflictWith(String analyzerName) {
    return conflicts.contains(analyzerName);
  }

  /// Checks if this analyzer depends on the given analyzer
  bool dependsOn(String analyzerName) {
    return dependencies.contains(analyzerName);
  }

  /// Gets the estimated processing time for the given image size
  Duration getEstimatedProcessingTime(int width, int height) {
    final pixels = width * height;
    final baseTime = performanceMetrics['baseProcessingTimeMs'] as int? ?? 100;
    final pixelFactor =
        performanceMetrics['pixelFactor'] as double? ?? 0.000001;

    final estimatedMs = (baseTime + (pixels * pixelFactor)).round();
    return Duration(milliseconds: estimatedMs);
  }

  /// Creates a copy with modified values
  AnalyzerMetadata copyWith({
    String? description,
    String? version,
    List<String>? supportedImageTypes,
    int? minImageWidth,
    int? minImageHeight,
    int? maxImageWidth,
    int? maxImageHeight,
    bool? isCpuIntensive,
    bool? isMemoryIntensive,
    bool? supportsParallelExecution,
    List<String>? dependencies,
    List<String>? conflicts,
    Map<String, dynamic>? configurationOptions,
    Map<String, dynamic>? performanceMetrics,
  }) {
    return AnalyzerMetadata(
      description: description ?? this.description,
      version: version ?? this.version,
      supportedImageTypes: supportedImageTypes ?? this.supportedImageTypes,
      minImageWidth: minImageWidth ?? this.minImageWidth,
      minImageHeight: minImageHeight ?? this.minImageHeight,
      maxImageWidth: maxImageWidth ?? this.maxImageWidth,
      maxImageHeight: maxImageHeight ?? this.maxImageHeight,
      isCpuIntensive: isCpuIntensive ?? this.isCpuIntensive,
      isMemoryIntensive: isMemoryIntensive ?? this.isMemoryIntensive,
      supportsParallelExecution:
          supportsParallelExecution ?? this.supportsParallelExecution,
      dependencies: dependencies ?? this.dependencies,
      conflicts: conflicts ?? this.conflicts,
      configurationOptions: configurationOptions ?? this.configurationOptions,
      performanceMetrics: performanceMetrics ?? this.performanceMetrics,
    );
  }

  @override
  String toString() {
    return 'AnalyzerMetadata(description: $description, version: $version, '
        'cpuIntensive: $isCpuIntensive, memoryIntensive: $isMemoryIntensive)';
  }
}
