class ImageItem {
  const ImageItem({
    required this.id,
    required this.date,
    required this.source,
    required this.imageUrl,
    required this.createdAt,
    this.title,
    this.category,
    this.credit,
    this.sourceUrl,
    this.cloudinary,
    this.focal,
    this.cropStrategy,
    this.crop,
    this.generatedAt,
    this.settingsHash,
  });

  final String id;
  final DateTime date;
  final String source;
  final String imageUrl;
  final DateTime createdAt;
  final String? title;
  final String? category;
  final String? credit;
  final String? sourceUrl;
  final Map<String, dynamic>? cloudinary;
  final Map<String, dynamic>? focal;
  final String? cropStrategy;
  final Map<String, dynamic>? crop;
  final DateTime? generatedAt;
  final String? settingsHash;

  factory ImageItem.fromJson(Map<String, dynamic> json) {
    return ImageItem(
      id: _requiredString(json, 'id'),
      date: DateTime.parse(_requiredString(json, 'date')),
      source: _requiredString(json, 'source'),
      imageUrl: _requiredString(json, 'image_url'),
      createdAt: DateTime.parse(_requiredString(json, 'created_at')),
      title: json['title'] as String?,
      category: _optionalString(json['category'], 'category'),
      credit: json['credit'] as String?,
      sourceUrl: json['source_url'] as String?,
      cloudinary: _optionalJsonObject(json['cloudinary'], 'cloudinary'),
      focal: _optionalJsonObject(json['focal'], 'focal'),
      cropStrategy: json['crop_strategy'] as String?,
      crop: _optionalJsonObject(json['crop'], 'crop'),
      generatedAt: _optionalDateTime(json['generated_at'], 'generated_at'),
      settingsHash: json['settings_hash'] as String?,
    );
  }

  String get displayTitle {
    final normalizedSource = source.trim().toLowerCase();
    if (normalizedSource.startsWith('bing')) return 'Bing Daily Image';
    if (normalizedSource.startsWith('pexel')) {
      final categoryName = category?.trim();
      return categoryName == null || categoryName.isEmpty
          ? 'Pexel'
          : 'Pexel $categoryName';
    }
    if (normalizedSource.startsWith('nasa')) return 'NASA APOD';
    return source;
  }

  static String _requiredString(Map<String, dynamic> json, String key) {
    final value = json[key];
    if (value is String && value.isNotEmpty) return value;
    throw FormatException('Wallpaper field "$key" must be a non-empty string.');
  }

  static Map<String, dynamic>? _optionalJsonObject(
    Object? value,
    String field,
  ) {
    if (value == null) return null;
    if (value is Map) return Map<String, dynamic>.from(value);
    throw FormatException('Wallpaper field "$field" must be a JSON object.');
  }

  static String? _optionalString(Object? value, String field) {
    if (value == null) return null;
    if (value is String) return value;
    throw FormatException('Wallpaper field "$field" must be a string.');
  }

  static DateTime? _optionalDateTime(Object? value, String field) {
    if (value == null) return null;
    if (value is String) return DateTime.parse(value);
    throw FormatException('Wallpaper field "$field" must be a date string.');
  }
}
