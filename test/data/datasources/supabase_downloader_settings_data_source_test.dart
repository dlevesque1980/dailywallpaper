import 'dart:convert';

import 'package:dailywallpaper/data/datasources/supabase_downloader_settings_data_source.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

void main() {
  const projectUrl = 'https://example.supabase.co';
  const publishableKey = 'sb_publishable_test';

  test('reads NASA and Pexels settings from the global row', () async {
    final client = QueuedHttpClient([
      _response(
        '[{"include_nasa":true,"pexels_categories":["portrait","animals"]}]',
      ),
    ]);
    final source = SupabaseDownloaderSettingsDataSource(
      client: client,
      projectUrl: projectUrl,
      publishableKey: publishableKey,
    );

    final settings = await source.fetchSettings();

    expect(settings.includeNasa, isTrue);
    expect(settings.pexelsCategories, ['portrait', 'animals']);
    expect(client.requests.single.url.path, '/rest/v1/downloader_settings');
    expect(client.requests.single.url.queryParameters['id'], 'eq.global');
    expect(
      client.requests.single.url.queryParameters['select'],
      'include_nasa,pexels_categories',
    );
    expect(client.requests.single.headers['apikey'], publishableKey);
  });

  test('does not read a secret key from app configuration', () async {
    final client = QueuedHttpClient([]);
    final source = SupabaseDownloaderSettingsDataSource(
      client: client,
      projectUrl: projectUrl,
      publishableKey: 'sb_secret_never_send',
    );

    await expectLater(source.fetchSettings(), throwsA(isA<StateError>()));
    expect(client.requests, isEmpty);
  });

  test('updates Pexels categories without an auth session', () async {
    final client = QueuedHttpClient([
      _response(
        '[{"include_nasa":true,"pexels_categories":["portrait","people","animals"]}]',
      ),
    ]);
    final source = SupabaseDownloaderSettingsDataSource(
      client: client,
      projectUrl: projectUrl,
      publishableKey: publishableKey,
    );

    await source.updateSettings(
      pexelsCategories: ['portrait', 'people', 'animals'],
    );

    final request = client.requests.single;
    expect(request.method, 'PATCH');
    expect(request.url.path, '/rest/v1/downloader_settings');
    expect(request.headers['apikey'], publishableKey);
    expect(request.headers.containsKey('Authorization'), isFalse);
    expect(jsonDecode(request.body), {
      'updated_at': isA<String>(),
      'pexels_categories': ['portrait', 'people', 'animals'],
    });
  });

  test('rejects empty and oversized category selections', () async {
    final client = QueuedHttpClient([]);
    final source = SupabaseDownloaderSettingsDataSource(
      client: client,
      projectUrl: projectUrl,
      publishableKey: publishableKey,
    );

    await expectLater(
      source.updateSettings(pexelsCategories: []),
      throwsArgumentError,
    );
    await expectLater(
      source.updateSettings(
        pexelsCategories: ['a', 'b', 'c', 'd'],
      ),
      throwsArgumentError,
    );
    expect(client.requests, isEmpty);
  });

  test('reports an update that matches no global settings row', () async {
    final client = QueuedHttpClient([_response('[]')]);
    final source = SupabaseDownloaderSettingsDataSource(
      client: client,
      projectUrl: projectUrl,
      publishableKey: publishableKey,
    );

    await expectLater(
      source.updateSettings(includeNasa: false),
      throwsA(isA<FormatException>()),
    );
  });
}

http.Response _response(String body, [int statusCode = 200]) =>
    http.Response(body, statusCode);

class QueuedHttpClient extends http.BaseClient {
  QueuedHttpClient(this._responses);

  final List<http.Response> _responses;
  final requests = <http.Request>[];

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final buffered = http.Request(request.method, request.url)
      ..headers.addAll(request.headers);
    if (request is http.Request) buffered.body = request.body;
    requests.add(buffered);
    final response = _responses.removeAt(0);
    return http.StreamedResponse(
      Stream.value(utf8.encode(response.body)),
      response.statusCode,
      request: request,
      headers: response.headers,
    );
  }
}
