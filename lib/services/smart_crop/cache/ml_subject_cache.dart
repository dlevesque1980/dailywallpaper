import 'package:sqflite/sqflite.dart';
import 'crop_cache_database.dart';

/// Normalized bounding box for a detected subject, with all values in [0.0, 1.0].
class SubjectBounds {
  /// Normalized X coordinate of the top-left corner [0.0, 1.0]
  final double x;

  /// Normalized Y coordinate of the top-left corner [0.0, 1.0]
  final double y;

  /// Normalized width [0.0, 1.0]
  final double width;

  /// Normalized height [0.0, 1.0]
  final double height;

  const SubjectBounds({
    required this.x,
    required this.y,
    required this.width,
    required this.height,
  });

  Map<String, dynamic> toMap() => {
        'subject_x': x,
        'subject_y': y,
        'subject_width': width,
        'subject_height': height,
      };

  factory SubjectBounds.fromMap(Map<String, dynamic> map) => SubjectBounds(
        x: (map['subject_x'] as num).toDouble(),
        y: (map['subject_y'] as num).toDouble(),
        width: (map['subject_width'] as num).toDouble(),
        height: (map['subject_height'] as num).toDouble(),
      );

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is SubjectBounds &&
        other.x == x &&
        other.y == y &&
        other.width == width &&
        other.height == height;
  }

  @override
  int get hashCode => Object.hash(x, y, width, height);

  @override
  String toString() =>
      'SubjectBounds(x: $x, y: $y, width: $width, height: $height)';
}

/// Persistent cache for ML subject segmentation results.
///
/// Stores [SubjectBounds] keyed by [imageUrl] in the `ml_subject_cache` SQLite
/// table. Entries have no expiration — an analysed image stays analysed
/// indefinitely. Corrupt or missing entries return `null` so the caller can
/// fall back to a fresh ML Kit call.
class MlSubjectCache {
  static const String _tableName = 'ml_subject_cache';

  final CropCacheDatabase _db;

  MlSubjectCache({CropCacheDatabase? database})
      : _db = database ?? CropCacheDatabase();

  /// Returns the cached [SubjectBounds] for [imageUrl], or `null` if absent or
  /// the stored row is corrupt / unreadable.
  Future<SubjectBounds?> getSubjectBounds(String imageUrl) async {
    try {
      final db = await _db.database;
      final rows = await db.query(
        _tableName,
        where: 'image_url = ?',
        whereArgs: [imageUrl],
        limit: 1,
      );

      if (rows.isEmpty) return null;

      return SubjectBounds.fromMap(rows.first);
    } catch (_) {
      // Corrupt or unreadable entry — signal caller to re-run ML Kit.
      return null;
    }
  }

  /// Persists [bounds] for [imageUrl], replacing any existing entry.
  Future<void> saveSubjectBounds(String imageUrl, SubjectBounds bounds) async {
    try {
      final db = await _db.database;
      await db.insert(
        _tableName,
        {
          'image_url': imageUrl,
          ...bounds.toMap(),
          'created_at': DateTime.now().millisecondsSinceEpoch,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } catch (e) {
      // Log and continue — cache write failures are non-fatal.
      // ignore: avoid_print
      print('[MlSubjectCache] Failed to save bounds for $imageUrl: $e');
    }
  }

  /// Removes the cached entry for [imageUrl].
  Future<void> deleteSubjectBounds(String imageUrl) async {
    try {
      final db = await _db.database;
      await db.delete(
        _tableName,
        where: 'image_url = ?',
        whereArgs: [imageUrl],
      );
    } catch (e) {
      // ignore: avoid_print
      print('[MlSubjectCache] Failed to delete bounds for $imageUrl: $e');
    }
  }

  /// Removes all entries from the ML subject cache table.
  Future<int> clear() async {
    try {
      final db = await _db.database;
      return await db.delete(_tableName);
    } catch (e) {
      // ignore: avoid_print
      print('[MlSubjectCache] Failed to clear cache: $e');
      return 0;
    }
  }
}
