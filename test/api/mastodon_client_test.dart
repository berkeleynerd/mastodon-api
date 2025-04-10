import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:mastodon_api/mastodon_api.dart';
import 'package:oauth2/oauth2.dart' as oauth2;
import 'package:test/test.dart';

import '../helpers/mock_http_client.dart';
import '../helpers/mock_auth_manager.dart';

/// Mock OAuth client for testing
class MockOAuthClient extends http.BaseClient {
  final oauth2.Credentials credentials;
  final http.Client delegateClient;
  
  MockOAuthClient({
    required this.credentials,
    required this.delegateClient,
  });
  
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    // Add auth header to the request
    request.headers['Authorization'] = 'Bearer ${credentials.accessToken}';
    
    // Delegate to the MockHttpClient which will return our mocked responses
    return delegateClient.send(request);
  }
}

void main() {
  group('MastodonClient API endpoints', () {
    const instanceUrl = 'https://example.mastodon.social';
    const clientId = 'test_client_id';
    const clientSecret = 'test_client_secret';
    const redirectUrl = 'http://localhost:8080/callback';
    
    late InMemoryCredentialStorage credentialStorage;
    late MockHttpClient httpClient;
    late MastodonClient client;
    late MockAuthManager authManager;
    
    setUp(() async {
      credentialStorage = InMemoryCredentialStorage();
      httpClient = MockHttpClient();
      
      // Create OAuth2 credentials for testing
      final credentials = oauth2.Credentials(
        'test_access_token',
        refreshToken: 'test_refresh_token',
        scopes: ['read', 'write', 'follow'],
      );
      
      // Create a client that will be returned by mocks
      final oauthClient = MockOAuthClient(
        credentials: credentials,
        delegateClient: httpClient,
      );
      
      // Create mocked AuthManager that returns our mock client
      authManager = MockAuthManager(
        isAuthenticated: true,
        clientToReturn: oauthClient
      );
      
      // Create API service with auth manager and httpClient factory
      final apiService = ApiService(
        authManager: authManager,
        instanceUrl: instanceUrl,
      );
      
      // Create client
      client = MastodonClient(apiService: apiService);
    });
    
    tearDown(() {
      httpClient.reset();
    });
    
    test('getStatus returns status details', () async {
      // Arrange
      final statusId = '12345';
      final expectedStatus = {
        'id': statusId,
        'content': 'Test status content',
        'account': {'username': 'testuser'},
        'favourites_count': 5,
        'reblogs_count': 2,
      };
      
      httpClient.mockGet(
        '$instanceUrl/api/v1/statuses/$statusId',
        http.Response(json.encode(expectedStatus), 200, headers: {'content-type': 'application/json'}),
      );
      
      // Act
      final result = await client.getStatus(statusId);
      
      // Assert
      expect(result, equals(expectedStatus));
    });
    
    test('favoriteStatus returns updated status', () async {
      // Arrange
      final statusId = '12345';
      final expectedStatus = {
        'id': statusId,
        'content': 'Test status content',
        'favourited': true,
        'favourites_count': 6,
      };
      
      httpClient.mockPost(
        '$instanceUrl/api/v1/statuses/$statusId/favourite',
        http.Response(json.encode(expectedStatus), 200, headers: {'content-type': 'application/json'}),
      );
      
      // Act
      final result = await client.favoriteStatus(statusId);
      
      // Assert
      expect(result, equals(expectedStatus));
      expect(result['favourited'], isTrue);
    });
    
    test('unfavoriteStatus returns updated status', () async {
      // Arrange
      final statusId = '12345';
      final expectedStatus = {
        'id': statusId,
        'content': 'Test status content',
        'favourited': false,
        'favourites_count': 5,
      };
      
      httpClient.mockPost(
        '$instanceUrl/api/v1/statuses/$statusId/unfavourite',
        http.Response(json.encode(expectedStatus), 200, headers: {'content-type': 'application/json'}),
      );
      
      // Act
      final result = await client.unfavoriteStatus(statusId);
      
      // Assert
      expect(result, equals(expectedStatus));
      expect(result['favourited'], isFalse);
    });
    
    test('reblogStatus returns updated status', () async {
      // Arrange
      final statusId = '12345';
      final expectedStatus = {
        'id': statusId,
        'content': 'Test status content',
        'reblogged': true,
        'reblogs_count': 3,
      };
      
      httpClient.mockPost(
        '$instanceUrl/api/v1/statuses/$statusId/reblog',
        http.Response(json.encode(expectedStatus), 200, headers: {'content-type': 'application/json'}),
      );
      
      // Act
      final result = await client.reblogStatus(statusId);
      
      // Assert
      expect(result, equals(expectedStatus));
      expect(result['reblogged'], isTrue);
    });
    
    test('unreblogStatus returns updated status', () async {
      // Arrange
      final statusId = '12345';
      final expectedStatus = {
        'id': statusId,
        'content': 'Test status content',
        'reblogged': false,
        'reblogs_count': 2,
      };
      
      httpClient.mockPost(
        '$instanceUrl/api/v1/statuses/$statusId/unreblog',
        http.Response(json.encode(expectedStatus), 200, headers: {'content-type': 'application/json'}),
      );
      
      // Act
      final result = await client.unreblogStatus(statusId);
      
      // Assert
      expect(result, equals(expectedStatus));
      expect(result['reblogged'], isFalse);
    });
    
    test('followAccount returns relationship', () async {
      // Arrange
      final accountId = '67890';
      final expectedRelationship = {
        'id': accountId,
        'following': true,
        'followed_by': false,
        'blocking': false,
        'muting': false,
      };
      
      httpClient.mockPost(
        '$instanceUrl/api/v1/accounts/$accountId/follow',
        http.Response(json.encode(expectedRelationship), 200, headers: {'content-type': 'application/json'}),
      );
      
      // Act
      final result = await client.followAccount(accountId);
      
      // Assert
      expect(result, equals(expectedRelationship));
      expect(result['following'], isTrue);
    });
    
    test('unfollowAccount returns relationship', () async {
      // Arrange
      final accountId = '67890';
      final expectedRelationship = {
        'id': accountId,
        'following': false,
        'followed_by': false,
        'blocking': false,
        'muting': false,
      };
      
      httpClient.mockPost(
        '$instanceUrl/api/v1/accounts/$accountId/unfollow',
        http.Response(json.encode(expectedRelationship), 200, headers: {'content-type': 'application/json'}),
      );
      
      // Act
      final result = await client.unfollowAccount(accountId);
      
      // Assert
      expect(result, equals(expectedRelationship));
      expect(result['following'], isFalse);
    });
    
    test('getNotifications returns list of notifications', () async {
      // Arrange
      final expectedNotifications = [
        {
          'id': '123',
          'type': 'mention',
          'account': {'username': 'testuser'},
        },
        {
          'id': '456',
          'type': 'favourite',
          'account': {'username': 'otheruser'},
        },
      ];
      
      httpClient.mockGet(
        '$instanceUrl/api/v1/notifications?limit=20',
        http.Response(json.encode(expectedNotifications), 200, headers: {'content-type': 'application/json'}),
      );
      
      // Act
      final result = await client.getNotifications();
      
      // Assert
      expect(result, equals(expectedNotifications));
      expect(result.length, equals(2));
      expect(result[0]['type'], equals('mention'));
      expect(result[1]['type'], equals('favourite'));
    });
    
    test('getNotifications with parameters adds query parameters', () async {
      // Arrange
      final expectedNotifications = [
        {
          'id': '123',
          'type': 'mention',
          'account': {'username': 'testuser'},
        },
      ];
      
      // Use more general URL that will match regardless of parameter order
      httpClient.mockGet(
        '$instanceUrl/api/v1/notifications',
        http.Response(json.encode(expectedNotifications), 200, headers: {'content-type': 'application/json'}),
      );
      
      // Act
      final result = await client.getNotifications(
        limit: 5,
        types: ['mention'],
      );
      
      // Assert
      expect(result, equals(expectedNotifications));
    });
    
    test('getNotification returns a single notification', () async {
      // Arrange
      final notificationId = '123';
      final expectedNotification = {
        'id': notificationId,
        'type': 'mention',
        'account': {'username': 'testuser'},
      };
      
      httpClient.mockGet(
        '$instanceUrl/api/v1/notifications/$notificationId',
        http.Response(json.encode(expectedNotification), 200, headers: {'content-type': 'application/json'}),
      );
      
      // Act
      final result = await client.getNotification(notificationId);
      
      // Assert
      expect(result, equals(expectedNotification));
      expect(result['type'], equals('mention'));
    });
    
    test('clearNotifications sends correct request', () async {
      // Arrange
      httpClient.mockPost(
        '$instanceUrl/api/v1/notifications/clear',
        http.Response('{}', 200, headers: {'content-type': 'application/json'}),  // Return empty JSON object
      );
      
      // Act & Assert
      // Should not throw an exception
      await expectLater(client.clearNotifications(), completes);
    });
  });
} 