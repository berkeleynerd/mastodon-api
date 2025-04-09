import 'package:http/http.dart' as http;
import 'package:mastodon_api/mastodon_api.dart';
import 'package:test/test.dart';

void main() {
  group('ApiService', () {
    const instanceUrl = 'https://mastodon.example.com';
    
    test('instantiates correctly', () {
      final authManager = MockAuthManager();
      final apiService = ApiService(
        authManager: authManager,
        instanceUrl: instanceUrl,
      );
      
      expect(apiService.instanceUrl, equals(instanceUrl));
    });
    
    test('throws authentication error when required auth is missing', () async {
      final authManager = MockAuthManager(isAuthenticated: false);
      final apiService = ApiService(
        authManager: authManager,
        instanceUrl: instanceUrl,
      );
      
      expect(
        () => apiService.execute<String>((_) async => 'test'),
        throwsA(isA<ApiError>().having(
          (e) => e.type, 'type', equals(ApiErrorType.authentication),
        )),
      );
    });
    
    test('executes request when no auth is required', () async {
      final authManager = MockAuthManager(isAuthenticated: false);
      final apiService = ApiService(
        authManager: authManager,
        instanceUrl: instanceUrl,
      );
      
      final result = await apiService.execute<String>(
        (_) async => 'test result',
        requireAuth: false,
      );
      
      expect(result, equals('test result'));
    });
    
    test('executes request when auth is required and available', () async {
      final authManager = MockAuthManager(isAuthenticated: true);
      final apiService = ApiService(
        authManager: authManager,
        instanceUrl: instanceUrl,
      );
      
      final result = await apiService.execute<String>(
        (_) async => 'authenticated result',
      );
      
      expect(result, equals('authenticated result'));
    });
    
    test('uses custom HTTP client factory when provided', () async {
      bool factoryCalled = false;
      final authManager = MockAuthManager(isAuthenticated: false);
      
      final apiService = ApiService(
        authManager: authManager,
        instanceUrl: instanceUrl,
        httpClientFactory: () {
          factoryCalled = true;
          return MockHttpClient();
        },
      );
      
      await apiService.execute<String>(
        (_) async => 'test result',
        requireAuth: false,
      );
      
      expect(factoryCalled, isTrue);
    });
  });
}

class MockAuthManager implements AuthManager {
  final bool isAuthenticated;
  
  MockAuthManager({this.isAuthenticated = false});
  
  @override
  dynamic noSuchMethod(Invocation invocation) {
    if (invocation.memberName == Symbol('isAuthenticated')) {
      return isAuthenticated;
    }
    if (invocation.memberName == Symbol('createHttpClient')) {
      return MockHttpClient();
    }
    return super.noSuchMethod(invocation);
  }
}

class MockHttpClient extends http.BaseClient {
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    // Just return a basic response for testing
    return http.StreamedResponse(
      Stream.value([]),
      200,
    );
  }
} 