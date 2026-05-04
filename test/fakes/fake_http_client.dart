import 'package:http/http.dart' as http;
import 'dart:convert';

class FakeHttpClient extends http.BaseClient {
  String fakeBody;
  int fakeStatusCode;
  bool shouldThrow;
  Uri? lastCalledUri;
  Map<String, String>? lastCalledHeaders;

  FakeHttpClient({
    this.fakeBody = '{}',
    this.fakeStatusCode = 200,
    this.shouldThrow = false,
  });

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    lastCalledUri = request.url;
    lastCalledHeaders = request.headers;
    
    if (shouldThrow) throw Exception('Network error');
    
    return http.StreamedResponse(
      Stream.value(utf8.encode(fakeBody)),
      fakeStatusCode,
      request: request,
    );
  }
}
