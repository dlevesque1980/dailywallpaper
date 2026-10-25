import 'dart:convert';

import 'package:dailywallpaper/core/preferences/pref_consts.dart';
import 'package:http/http.dart' as http;

import '../models/image_item.dart';

class SupabaseWallpaperDataSource {
  SupabaseWallpaperDataSource({
    http.Client? client,
    String? apiKey,
  })  : _client = client ?? http.Client(),
        _apiKey =
            apiKey ?? const String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY');

  static const _projectUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://ncfpyfwvawyyyiqfpzwk.supabase.co',
  );
  static const _tablePath = '/rest/v1/wallpapers';
  static const _pageSize = 1000;

  final http.Client _client;
  final String? _apiKey;

  Future<List<ImageItem>> fetchLatestWallpapers() async {
    final rows = await _fetchRows({
      'select': '*',
      'order': 'date.desc,created_at.desc,id.asc',
      'limit': '$_pageSize',
    });
    if (rows.isEmpty) return [];

    final latestDate = rows.first['date'];
    return _sortForDisplay(rows
        .where((row) => row['date'] == latestDate)
        .map(ImageItem.fromJson)
        .toList(growable: false));
  }

  Future<List<DateTime>> fetchAvailableDates() async {
    final dates = <DateTime>[];
    var offset = 0;
    while (true) {
      final rows = await _fetchRows({
        'select': 'date',
        'order': 'date.desc',
        'limit': '$_pageSize',
        'offset': '$offset',
      });
      dates.addAll(rows.map((row) => DateTime.parse(row['date'] as String)));
      if (rows.length < _pageSize) break;
      offset += _pageSize;
    }

    final uniqueDates = <String, DateTime>{};
    for (final date in dates) {
      final key =
          '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
      uniqueDates.putIfAbsent(key, () => date);
    }
    return uniqueDates.values.toList(growable: false);
  }

  Future<List<ImageItem>> fetchWallpapersForDate(DateTime date) async {
    final dateKey =
        '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    final rows = await _fetchRows({
      'select': '*',
      'date': 'eq.$dateKey',
      'order': 'created_at.asc,id.asc',
      'limit': '$_pageSize',
    });
    return _sortForDisplay(rows.map(ImageItem.fromJson).toList());
  }

  List<ImageItem> _sortForDisplay(List<ImageItem> images) {
    final indexed = images.indexed.toList();
    indexed.sort((left, right) {
      final leftImage = left.$2;
      final rightImage = right.$2;
      final sourceOrder = _sourceOrder(leftImage.source)
          .compareTo(_sourceOrder(rightImage.source));
      if (sourceOrder != 0) return sourceOrder;

      if (_isPexels(leftImage.source) && _isPexels(rightImage.source)) {
        final categoryOrder = _categoryOrder(leftImage.category)
            .compareTo(_categoryOrder(rightImage.category));
        if (categoryOrder != 0) return categoryOrder;
      }
      return left.$1.compareTo(right.$1);
    });
    return indexed.map((entry) => entry.$2).toList(growable: false);
  }

  int _sourceOrder(String source) {
    final normalized = source.trim().toLowerCase();
    if (normalized.startsWith('bing')) return 0;
    if (normalized.startsWith('pexel')) return 1;
    if (normalized.startsWith('nasa')) return 3;
    return 2;
  }

  bool _isPexels(String source) =>
      source.trim().toLowerCase().startsWith('pexel');

  int _categoryOrder(String? category) {
    final index =
        pexelsCategoryOptions.indexOf(category?.trim().toLowerCase() ?? '');
    return index < 0 ? pexelsCategoryOptions.length : index;
  }

  Future<List<Map<String, dynamic>>> _fetchRows(
    Map<String, String> query,
  ) async {
    final apiKey = _apiKey;
    if (apiKey == null || apiKey.trim().isEmpty) {
      throw StateError(
        'SUPABASE_PUBLISHABLE_KEY is missing. Supply the public key with '
        '--dart-define=SUPABASE_PUBLISHABLE_KEY=sb_publishable_...',
      );
    }
    if (!apiKey.startsWith('sb_publishable_')) {
      throw StateError(
        'Only a Supabase publishable key can be used in the app. '
        'Secret keys must stay on a trusted server.',
      );
    }

    final uri = Uri.parse(_projectUrl).replace(
      path: _tablePath,
      queryParameters: query,
    );
    final headers = <String, String>{
      'apikey': apiKey,
      'Accept': 'application/json',
    };
    final response = await _client
        .get(
          uri,
          headers: headers,
        )
        .timeout(const Duration(seconds: 20));

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw SupabaseWallpaperException(
        'Supabase returned HTTP ${response.statusCode}: ${response.body}',
      );
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! List) {
      throw const FormatException(
        'Supabase wallpapers response must be a JSON array.',
      );
    }
    return decoded.map((row) {
      if (row is! Map) {
        throw const FormatException(
          'Supabase wallpapers rows must be JSON objects.',
        );
      }
      return Map<String, dynamic>.from(row);
    }).toList(growable: false);
  }
}

class SupabaseWallpaperException implements Exception {
  const SupabaseWallpaperException(this.message);

  final String message;

  @override
  String toString() => message;
}
