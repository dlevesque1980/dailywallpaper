import 'dart:convert';

import 'package:dailywallpaper/core/preferences/pref_consts.dart';
import 'package:http/http.dart' as http;

abstract interface class DownloaderSettingsDataSource {
  Future<DownloaderSettings> fetchSettings();
  Future<void> updateSettings({
    bool? includeNasa,
    List<String>? pexelsCategories,
  });
}

class DownloaderSettings {
  const DownloaderSettings({
    required this.includeNasa,
    required this.pexelsCategories,
  });

  final bool includeNasa;
  final List<String> pexelsCategories;
}

class SupabaseDownloaderSettingsDataSource
    implements DownloaderSettingsDataSource {
  SupabaseDownloaderSettingsDataSource({
    http.Client? client,
    String? projectUrl,
    String? publishableKey,
  })  : _client = client ?? http.Client(),
        _projectUrl = projectUrl ??
            const String.fromEnvironment(
              'SUPABASE_URL',
              defaultValue: 'https://ncfpyfwvawyyyiqfpzwk.supabase.co',
            ),
        _publishableKey = publishableKey ??
            const String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY');

  final http.Client _client;
  final String _projectUrl;
  final String? _publishableKey;

  @override
  Future<DownloaderSettings> fetchSettings() async {
    final response = await _client
        .get(
          _uri('/rest/v1/downloader_settings', {
            'select': 'include_nasa,pexels_categories',
            'id': 'eq.global',
          }),
          headers: _headers,
        )
        .timeout(const Duration(seconds: 20));
    _ensureSuccess(response, 'load downloader settings');

    final row = _singleRow(response.body);
    final includeNasa = row['include_nasa'];
    final categories = row['pexels_categories'];
    if (includeNasa is! bool ||
        categories is! List ||
        categories.any((category) => category is! String)) {
      throw const FormatException(
        'Supabase returned invalid downloader settings.',
      );
    }
    return DownloaderSettings(
      includeNasa: includeNasa,
      pexelsCategories: categories.cast<String>(),
    );
  }

  @override
  Future<void> updateSettings({
    bool? includeNasa,
    List<String>? pexelsCategories,
  }) async {
    if (includeNasa == null && pexelsCategories == null) {
      throw ArgumentError('At least one downloader setting must be provided.');
    }
    if (pexelsCategories != null &&
        (pexelsCategories.isEmpty ||
            pexelsCategories.length > maxPexelsCategories)) {
      throw ArgumentError('Select between one and three Pexels categories.');
    }

    final values = <String, Object>{
      'updated_at': DateTime.now().toUtc().toIso8601String(),
      if (includeNasa != null) 'include_nasa': includeNasa,
      if (pexelsCategories != null) 'pexels_categories': pexelsCategories,
    };
    final response = await _client
        .patch(
          _uri('/rest/v1/downloader_settings', {'id': 'eq.global'}),
          headers: {
            ..._headers,
            'Prefer': 'return=representation',
          },
          body: jsonEncode(values),
        )
        .timeout(const Duration(seconds: 20));
    _ensureSuccess(response, 'save downloader settings');
    _singleRow(response.body);
  }

  Map<String, String> get _headers {
    final key = _publishableKey;
    if (key == null || key.trim().isEmpty) {
      throw StateError(
        'SUPABASE_PUBLISHABLE_KEY is missing. Supply it with '
        '--dart-define-from-file=dart_defines.json.',
      );
    }
    if (!key.startsWith('sb_publishable_')) {
      throw StateError(
        'Only a Supabase publishable key can be used in the app.',
      );
    }
    return {
      'apikey': key,
      'Accept': 'application/json',
      'Content-Type': 'application/json',
    };
  }

  Uri _uri(String path, [Map<String, String>? query]) {
    final base = Uri.parse(_projectUrl);
    return base.replace(path: path, queryParameters: query);
  }

  Map<String, dynamic> _singleRow(String body) {
    final decoded = jsonDecode(body);
    if (decoded is! List || decoded.length != 1 || decoded.single is! Map) {
      throw const FormatException(
        'Supabase must return exactly one downloader settings row.',
      );
    }
    return Map<String, dynamic>.from(decoded.single as Map);
  }

  void _ensureSuccess(http.Response response, String operation) {
    if (response.statusCode >= 200 && response.statusCode < 300) return;
    String message =
        'Supabase could not $operation (HTTP ${response.statusCode}).';
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map) {
        final apiMessage =
            decoded['msg'] ?? decoded['message'] ?? decoded['error'];
        if (apiMessage is String && apiMessage.isNotEmpty) {
          message = apiMessage;
        }
      }
    } on FormatException {
      // Keep the explicit HTTP error when the response is not JSON.
    }
    throw SupabaseSettingsException(message, response.statusCode);
  }
}

class SupabaseSettingsException implements Exception {
  const SupabaseSettingsException(this.message, [this.statusCode]);

  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}
