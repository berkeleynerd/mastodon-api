import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:mastodon_api/mastodon_api.dart';
import 'package:oauth2/oauth2.dart' as oauth2;
import 'package:test/test.dart';

import '../helpers/mock_http_client.dart';
import '../helpers/mock_oauth.dart';
import '../helpers/mock_auth_manager.dart';

void main() {
  group('API Integration Tests', () {
    const instanceUrl = 'https://example.mastodon.social';
    const clientId = 'test_client_id';
    const clientSecret = 'test_client_secret';
    const redirectUrl = 'http://localhost:8080/callback';
    
    late MockHttpClient httpClient;
    
    setUp(() {
      httpClient = MockHttpClient();
    });
    
    tearDown(() {
      httpClient.reset();
    });
    
    test('get instance info works without authentication', () async {
      // Set up mock response
      final instanceInfo = {
        'uri': 'example.mastodon.social',
        'title': 'Example Mastodon',
        'version': '4.0.0',
      };
      
      httpClient.mockGet(
        '$instanceUrl/api/v1/instance',
        http.Response(json.encode(instanceInfo), 200, headers: {'content-type': 'application/json'}),
      );
      
      // Create a test setup
      final authManager = MockAuthManager(isAuthenticated: false, clientToReturn: httpClient);
      final apiService = ApiService(
        authManager: authManager,
        instanceUrl: instanceUrl,
        httpClientFactory: () => httpClient,
      );
      final client = MastodonClient(apiService: apiService);
      
      // Test the API call
      final result = await client.getInstance();
      
      expect(result, equals(instanceInfo));
    });
    
    test('API calls requiring auth throw when not authenticated', () async {
      // Create a test setup without authentication
      final authManager = MockAuthManager(isAuthenticated: false, clientToReturn: httpClient);
      final apiService = ApiService(
        authManager: authManager,
        instanceUrl: instanceUrl,
        httpClientFactory: () => httpClient,
      );
      final client = MastodonClient(apiService: apiService);
      
      // Mock the error response for unauthenticated request
      httpClient.mockGet(
        '$instanceUrl/api/v1/timelines/home',
        http.Response(
          json.encode({'error': 'Unauthorized'}), 
          401, 
          headers: {'content-type': 'application/json'}
        ),
      );
      
      // Test that it throws the expected error
      expect(
        () => client.getHomeTimeline(),
        throwsA(isA<ApiError>().having(
          (e) => e.type, 'type', equals(ApiErrorType.authentication),
        )),
      );
    });
    
    test('authenticated API calls work when authenticated', () async {
      // Set up mock response for timeline
      final timelineData = [
        {
          'id': '1',
          'content': 'Test post',
          'account': {'username': 'test_user'},
        },
      ];
      
      httpClient.mockGet(
        '$instanceUrl/api/v1/timelines/home',
        http.Response(
          json.encode(timelineData), 
          200, 
          headers: {'content-type': 'application/json'}
        ),
      );
      
      // Create a test setup with authentication
      final authManager = MockAuthManager(isAuthenticated: true, clientToReturn: httpClient);
      final apiService = ApiService(
        authManager: authManager,
        instanceUrl: instanceUrl,
        httpClientFactory: () => httpClient,
      );
      final client = MastodonClient(apiService: apiService);
      
      // Test authenticated API call
      final result = await client.getHomeTimeline();
      
      expect(result, equals(timelineData));
    });
    
    test('error handling works correctly', () async {
      // Set up error response
      final errorResponse = {
        'error': 'Not found',
      };
      
      httpClient.mockGet(
        '$instanceUrl/api/v1/accounts/nonexistent',
        http.Response(
          json.encode(errorResponse), 
          404, 
          headers: {'content-type': 'application/json'}
        ),
      );
      
      // Create a test setup with authentication
      final authManager = MockAuthManager(isAuthenticated: true, clientToReturn: httpClient);
      final apiService = ApiService(
        authManager: authManager,
        instanceUrl: instanceUrl,
        httpClientFactory: () => httpClient,
      );
      final client = MastodonClient(apiService: apiService);
      
      // Test error handling
      expect(
        () => client.getAccount('nonexistent'),
        throwsA(isA<ApiError>()
          .having((e) => e.type, 'type', equals(ApiErrorType.client))
          .having((e) => e.statusCode, 'statusCode', equals(404))
          .having((e) => e.message, 'message', equals('Not found')),
        ),
      );
    });
    
    test('factory creates a working setup', () async {
      // Set up a mock response
      final instanceInfo = {
        'uri': 'example.mastodon.social',
        'title': 'Example Mastodon',
        'version': '4.0.0',
      };
      
      httpClient.mockGet(
        '$instanceUrl/api/v1/instance',
        http.Response(
          json.encode(instanceInfo), 
          200, 
          headers: {'content-type': 'application/json'}
        ),
      );
      
      // Create a test setup with authentication
      final authManager = MockAuthManager(isAuthenticated: true, clientToReturn: httpClient);
      final setup = MastodonClientSetup(
        client: MastodonClient(
          apiService: ApiService(
            authManager: authManager,
            instanceUrl: instanceUrl,
            httpClientFactory: () => httpClient,
          ),
        ),
        authManager: authManager,
      );
      
      // Test the setup works
      expect(setup.isAuthenticated, isTrue);
      
      // Test an API call
      final result = await setup.client.getInstance();
      expect(result, equals(instanceInfo));
    });
  });
} 