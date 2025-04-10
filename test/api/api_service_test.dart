import 'package:http/http.dart' as http;
import 'package:mastodon_api/mastodon_api.dart';
import 'package:test/test.dart';

import '../helpers/mock_http_client.dart';
import '../helpers/mock_auth_manager.dart';

void main() {
  group('ApiService', () {
    const instanceUrl = 'https://mastodon.example.com';
    
    test('instantiates correctly', () {
      final mockClient = MockHttpClient();
      final authManager = MockAuthManager(clientToReturn: mockClient);
      final apiService = ApiService(
        authManager: authManager,
        instanceUrl: instanceUrl,
      );
      
      expect(apiService.instanceUrl, equals(instanceUrl));
    });
    
    test('throws authentication error when required auth is missing', () async {
      final mockClient = MockHttpClient();
      final authManager = MockAuthManager(isAuthenticated: false, clientToReturn: mockClient);
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
      final mockClient = MockHttpClient();
      final authManager = MockAuthManager(isAuthenticated: false, clientToReturn: mockClient);
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
      final mockClient = MockHttpClient();
      final authManager = MockAuthManager(isAuthenticated: true, clientToReturn: mockClient);
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
      final mockClient = MockHttpClient();
      final authManager = MockAuthManager(isAuthenticated: false, clientToReturn: mockClient);
      
      final apiService = ApiService(
        authManager: authManager,
        instanceUrl: instanceUrl,
        httpClientFactory: () {
          factoryCalled = true;
          return mockClient;
        },
      );
      
      await apiService.execute<String>(
        (_) async => 'test result',
        requireAuth: false,
      );
      
      expect(factoryCalled, isTrue);
    });
    
    test('checkResponse handles different HTTP status codes correctly', () {
      final mockClient = MockHttpClient();
      final authManager = MockAuthManager(isAuthenticated: true, clientToReturn: mockClient);
      final apiService = ApiService(
        authManager: authManager,
        instanceUrl: instanceUrl,
      );
      
      // Test success responses
      expect(apiService.checkResponse(http.Response('', 200)), isTrue);
      expect(apiService.checkResponse(http.Response('', 201)), isTrue);
      expect(apiService.checkResponse(http.Response('', 299)), isTrue);
      
      // Test client errors without throwing
      expect(apiService.checkResponse(
        http.Response('{"error":"Bad Request"}', 400), 
        throwOnError: false
      ), isFalse);
      
      // Test authentication errors
      expect(
        () => apiService.checkResponse(http.Response('{"error":"Unauthorized"}', 401)),
        throwsA(isA<ApiError>().having((e) => e.type, 'type', equals(ApiErrorType.authentication))),
      );
      expect(
        () => apiService.checkResponse(http.Response('{"error":"Forbidden"}', 403)),
        throwsA(isA<ApiError>().having((e) => e.type, 'type', equals(ApiErrorType.authentication))),
      );
      
      // Test client errors
      expect(
        () => apiService.checkResponse(http.Response('{"error":"Not Found"}', 404)),
        throwsA(isA<ApiError>().having((e) => e.type, 'type', equals(ApiErrorType.client))),
      );
      
      // Test server errors
      expect(
        () => apiService.checkResponse(http.Response('{"error":"Server Error"}', 500)),
        throwsA(isA<ApiError>().having((e) => e.type, 'type', equals(ApiErrorType.server))),
      );
    });
  });
} 