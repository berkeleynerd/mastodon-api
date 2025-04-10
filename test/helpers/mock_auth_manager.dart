import 'package:http/http.dart' as http;
import 'package:mastodon_api/mastodon_api.dart';
import 'package:oauth2/oauth2.dart' as oauth2;

/// Mock AuthManager for testing
class MockAuthManager implements AuthManager {
  final bool _isAuthenticated;
  final http.Client? _clientToReturn;
  
  MockAuthManager({
    bool isAuthenticated = false,
    http.Client? clientToReturn,
  }) : _isAuthenticated = isAuthenticated,
       _clientToReturn = clientToReturn;
  
  @override
  bool get isAuthenticated => _isAuthenticated;
  
  @override
  Future<void> initialize() async {
    // Do nothing in the mock
  }
  
  @override
  http.Client createHttpClient() {
    if (!_isAuthenticated) {
      throw Exception('Not authenticated');
    }
    return _clientToReturn ?? http.Client();
  }
  
  @override
  Future<String> getAuthorizationUrl() async {
    return 'https://example.com/oauth/authorize?mock=true';
  }
  
  @override
  Future<bool> handleAuthorizationCode(String code) async {
    return true;
  }
  
  @override
  Future<bool> handleRedirectUri(String uri) async {
    return true;
  }
  
  @override
  Future<void> logout() async {
    // Do nothing in the mock
  }
  
  @override
  dynamic noSuchMethod(Invocation invocation) {
    throw UnimplementedError('${invocation.memberName} is not implemented');
  }
} 