import 'dart:convert';
import 'package:http/http.dart' as http;

/// A reliable mock HTTP client for testing
class MockHttpClient extends http.BaseClient {
  final Map<String, http.Response> _responses = {};
  final List<http.BaseRequest> requests = [];
  
  void mockGet(String url, http.Response response) {
    _responses['GET:$url'] = response;
  }
  
  void mockPost(String url, http.Response response) {
    _responses['POST:$url'] = response;
  }

  void mockPut(String url, http.Response response) {
    _responses['PUT:$url'] = response;
  }

  void mockDelete(String url, http.Response response) {
    _responses['DELETE:$url'] = response;
  }
  
  void reset() {
    _responses.clear();
    requests.clear();
  }

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    // Store the request for later inspection
    requests.add(request);
    
    final method = request.method;
    final url = request.url.toString();
    final key = '$method:$url';
    
    // First try exact match
    if (_responses.containsKey(key)) {
      final response = _responses[key]!;
      return http.StreamedResponse(
        Stream.value(utf8.encode(response.body)),
        response.statusCode,
        headers: response.headers,
      );
    }
    
    // Try to find a partial URL match for cases with query parameters
    String? matchingKey;
    for (var k in _responses.keys) {
      if (k.startsWith('$method:') && url.contains(k.substring(method.length + 1))) {
        matchingKey = k;
        break;
      }
    }
    
    if (matchingKey != null) {
      final response = _responses[matchingKey]!;
      return http.StreamedResponse(
        Stream.value(utf8.encode(response.body)),
        response.statusCode,
        headers: response.headers,
      );
    }
    
    // Return a 404 if no match
    return http.StreamedResponse(
      Stream.value(utf8.encode('{"error": "Not Found"}')),
      404,
      headers: {'content-type': 'application/json'},
    );
  }
} 