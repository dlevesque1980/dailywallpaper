import '../models/crop_coordinates.dart';

/// Represents a cached crop entry in the database
class CropCacheEntry {
  /// Unique identifier for the cache entry
  final int? id;
  
  /// Cache key (hash of image_url + target_size + settings)
  final String cacheKey;
  
  /// Original image URL or identifier
  final String imageUrl;
  
  /// Target size width
  final double targetWidth;
  
  /// Target size height
  final double targetHeight;
  
  /// Settings hash for cache invalidation
  final String settingsHash;
  
  /// Cached crop coordinates
  final CropCoordinates coordinates;
  
  /// Timestamp when the entry was created
  final DateTime createdAt;
  
  /// Timestamp when the entry was last accessed
  final DateTime lastAccessedAt;
  
  /// Number of times this cache entry has been accessed
  final int accessCount;

  const CropCacheEntry({
    this.id,
    required this.cacheKey,
    required this.imageUrl,
    required this.targetWidth,
    required this.targetHeight,
    required this.settingsHash,
    required this.coordinates,
    required this.createdAt,
    required this.lastAccessedAt,
    required this.accessCount,
  });

  /// Creates a new cache entry
  factory CropCacheEntry.create({
    required String cacheKey,
    required String imageUrl,
    required double targetWidth,
    required double targetHeight,
    required String settingsHash,
    required CropCoordinates coordinates,
  }) {
    final now = DateTime.now();
    return CropCacheEntry(
      cacheKey: cacheKey,
      imageUrl: imageUrl,
      targetWidth: targetWidth,
      targetHeight: targetHeight,
      settingsHash: settingsHash,
      coordinates: coordinates,
      createdAt: now,
      lastAccessedAt: now,
      accessCount: 1,
    );
  }

  /// Creates a copy with updated access information
  CropCacheEntry copyWithAccess() {
    return CropCacheEntry(
      id: id,
      cacheKey: cacheKey,
      imageUrl: imageUrl,
      targetWidth: targetWidth,
      targetHeight: targetHeight,
      settingsHash: settingsHash,
      coordinates: coordinates,
      createdAt: createdAt,
      lastAccessedAt: DateTime.now(),
      accessCount: accessCount + 1,
    );
  }

  /// Creates a copy with modified values
  CropCacheEntry copyWith({
    int? id,
    String? cacheKey,
    String? imageUrl,
    double? targetWidth,
    double? targetHeight,
    String? settingsHash,
    CropCoordinates? coordinates,
    DateTime? createdAt,
    DateTime? lastAccessedAt,
    int? accessCount,
  }) {
    return CropCacheEntry(
      id: id ?? this.id,
      cacheKey: cacheKey ?? this.cacheKey,
      imageUrl: imageUrl ?? this.imageUrl,
      targetWidth: targetWidth ?? this.targetWidth,
      targetHeight: targetHeight ?? this.targetHeight,
      settingsHash: settingsHash ?? this.settingsHash,
      coordinates: coordinates ?? this.coordinates,
      createdAt: createdAt ?? this.createdAt,
      lastAccessedAt: lastAccessedAt ?? this.lastAccessedAt,
      accessCount: accessCount ?? this.accessCount,
    );
  }

  /// Converts to database map
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'cache_key': cacheKey,
      'image_url': imageUrl,
      'target_width': targetWidth,
      'target_height': targetHeight,
      'settings_hash': settingsHash,
      'crop_x': coordinates.x,
      'crop_y': coordinates.y,
      'crop_width': coordinates.width,
      'crop_height': coordinates.height,
      'crop_confidence': coordinates.confidence,
      'crop_strategy': coordinates.strategy,
      'created_at': createdAt.millisecondsSinceEpoch,
      'last_accessed_at': lastAccessedAt.millisecondsSinceEpoch,
      'access_count': accessCount,
    };
  }

  /// Creates from database map
  factory CropCacheEntry.fromMap(Map<String, dynamic> map) {
    return CropCacheEntry(
      id: map['id'] as int?,
      cacheKey: map['cache_key'] as String,
      imageUrl: map['image_url'] as String,
      targetWidth: map['target_width'] as double,
      targetHeight: map['target_height'] as double,
      settingsHash: map['settings_hash'] as String,
      coordinates: CropCoordinates(
        x: map['crop_x'] as double,
        y: map['crop_y'] as double,
        width: map['crop_width'] as double,
        height: map['crop_height'] as double,
        confidence: map['crop_confidence'] as double,
        strategy: map['crop_strategy'] as String,
      ),
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int),
      lastAccessedAt: DateTime.fromMillisecondsSinceEpoch(map['last_accessed_at'] as int),
      accessCount: map['access_count'] as int,
    );
  }

  /// Checks if the cache entry is expired
  bool isExpired({Duration ttl = const Duration(days: 7)}) {
    return DateTime.now().difference(createdAt) > ttl;
  }

  /// Gets the age of the cache entry
  Duration get age => DateTime.now().difference(createdAt);

  /// Gets the time since last access
  Duration get timeSinceLastAccess => DateTime.now().difference(lastAccessedAt);

  @override
  String toString() {
    return 'CropCacheEntry(id: $id, cacheKey: $cacheKey, imageUrl: $imageUrl, '
           'coordinates: $coordinates, age: ${age.inHours}h, accessCount: $accessCount)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is CropCacheEntry &&
           other.cacheKey == cacheKey &&
           other.coordinates == coordinates;
  }

  @override
  int get hashCode {
    return Object.hash(cacheKey, coordinates);
  }
}