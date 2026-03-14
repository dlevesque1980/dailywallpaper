import 'dart:ui' as ui;

/// Service de cache intelligent avec gestion de la mémoire
/// Optimise l'utilisation de la mémoire et la performance
class IntelligentCacheService {
  static final IntelligentCacheService _instance =
      IntelligentCacheService._internal();
  factory IntelligentCacheService() => _instance;
  IntelligentCacheService._internal();

  // Cache LRU (Least Recently Used)
  final Map<String, _CacheEntry> _cache = {};
  final List<String> _accessOrder = [];

  // Configuration
  static const int maxCacheSize = 15;
  static const Duration maxAge = Duration(hours: 2);

  /// Ajoute une image au cache
  void put(String key, ui.Image image, {int priority = 1}) {
    // Nettoyer le cache si nécessaire
    _cleanup();

    // Supprimer l'ancienne entrée si elle existe
    if (_cache.containsKey(key)) {
      _cache[key]?.image.dispose();
      _accessOrder.remove(key);
    }

    // Ajouter la nouvelle entrée
    _cache[key] = _CacheEntry(
      image: image,
      timestamp: DateTime.now(),
      priority: priority,
      accessCount: 1,
    );

    _accessOrder.add(key);

    // Maintenir la taille du cache
    _enforceMaxSize();
  }

  /// Récupère une image du cache
  ui.Image? get(String key) {
    final entry = _cache[key];
    if (entry == null) return null;

    // Vérifier l'âge
    if (DateTime.now().difference(entry.timestamp) > maxAge) {
      remove(key);
      return null;
    }

    // Mettre à jour l'ordre d'accès
    _accessOrder.remove(key);
    _accessOrder.add(key);
    entry.accessCount++;

    return entry.image;
  }

  /// Supprime une entrée du cache
  void remove(String key) {
    final entry = _cache.remove(key);
    if (entry != null) {
      entry.image.dispose();
      _accessOrder.remove(key);
    }
  }

  /// Vérifie si une clé existe dans le cache
  bool contains(String key) {
    return _cache.containsKey(key) &&
        DateTime.now().difference(_cache[key]!.timestamp) <= maxAge;
  }

  /// Nettoie les entrées expirées
  void _cleanup() {
    final now = DateTime.now();
    final expiredKeys = <String>[];

    for (final entry in _cache.entries) {
      if (now.difference(entry.value.timestamp) > maxAge) {
        expiredKeys.add(entry.key);
      }
    }

    for (final key in expiredKeys) {
      remove(key);
    }
  }

  /// Maintient la taille maximale du cache
  void _enforceMaxSize() {
    while (_cache.length > maxCacheSize && _accessOrder.isNotEmpty) {
      // Trouver l'entrée la moins prioritaire et la moins récemment utilisée
      String? keyToRemove;
      int lowestPriority = 999;
      int lowestAccessCount = 999;

      for (final key in _accessOrder) {
        final entry = _cache[key];
        if (entry != null) {
          if (entry.priority < lowestPriority ||
              (entry.priority == lowestPriority &&
                  entry.accessCount < lowestAccessCount)) {
            keyToRemove = key;
            lowestPriority = entry.priority;
            lowestAccessCount = entry.accessCount;
          }
        }
      }

      if (keyToRemove != null) {
        remove(keyToRemove);
      } else {
        break;
      }
    }
  }

  /// Vide complètement le cache
  void clear() {
    for (final entry in _cache.values) {
      entry.image.dispose();
    }
    _cache.clear();
    _accessOrder.clear();
  }

  /// Statistiques du cache
  Map<String, dynamic> getStats() {
    return {
      'size': _cache.length,
      'maxSize': maxCacheSize,
      'hitRate': _calculateHitRate(),
      'memoryUsage': _estimateMemoryUsage(),
    };
  }

  double _calculateHitRate() {
    if (_cache.isEmpty) return 0.0;

    int totalAccess = 0;
    for (final entry in _cache.values) {
      totalAccess += entry.accessCount;
    }

    return totalAccess / _cache.length;
  }

  int _estimateMemoryUsage() {
    int totalBytes = 0;
    for (final entry in _cache.values) {
      // Estimation approximative: largeur * hauteur * 4 bytes (RGBA)
      totalBytes += entry.image.width * entry.image.height * 4;
    }
    return totalBytes;
  }
}

/// Entrée de cache avec métadonnées
class _CacheEntry {
  final ui.Image image;
  final DateTime timestamp;
  final int priority;
  int accessCount;

  _CacheEntry({
    required this.image,
    required this.timestamp,
    required this.priority,
    required this.accessCount,
  });
}
