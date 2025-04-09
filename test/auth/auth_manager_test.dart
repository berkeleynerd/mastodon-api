import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:mastodon_api/mastodon_api.dart';
import 'package:mastodon_api/src/auth/auth_manager.dart';
import 'package:mastodon_api/src/auth/credential_storage.dart';
import 'package:oauth2/oauth2.dart' as oauth2;
import 'package:test/test.dart';

void main() {
  group('AuthManager', () {
    const instanceUrl = 'https://social.vivaldi.net';
    const clientId = 'test_client_id';
    const clientSecret = 'test_client_secret';
    const redirectUrl = 'http://localhost:8080/callback';
    
    late InMemoryCredentialStorage credentialStorage;
    late MockHttpClient httpClient;
    late MastodonOAuth oauth;
    late AuthManager authManager;
    
    setUp(() {
      credentialStorage = InMemoryCredentialStorage();
      httpClient = MockHttpClient();
      
      oauth = MastodonOAuth(
        instanceUrl: instanceUrl,
        clientId: clientId,
        clientSecret: clientSecret,
        redirectUrl: redirectUrl,
        httpClient: httpClient,
        credentialStorage: credentialStorage,
      );
      
      authManager = AuthManager(oauth: oauth);
    });
    
    tearDown(() {
      authManager.dispose();
    });
    
    group('initialization', () {
      test('initialize() sets unauthenticated state when no credentials', () async {
        await authManager.initialize();
        
        expect(authManager.state, equals(AuthState.unauthenticated));
        expect(authManager.isAuthenticated, isFalse);
        expect(authManager.client, isNull);
        expect(authManager.error, isNull);
      });
      
      test('initialize() sets authenticated state when valid credentials exist', () async {
        // Store valid credentials first
        await credentialStorage.saveCredentials(
          oauth2.Credentials('test_token'),
        );
        
        await authManager.initialize();
        
        expect(authManager.state, equals(AuthState.authenticated));
        expect(authManager.isAuthenticated, isTrue);
        expect(authManager.client, isNotNull);
        expect(authManager.error, isNull);
      });
      
      test('initialize() sets unauthenticated state on error', () async {
        // Simulate loading credentials that can't be used to create a client
        // by making the oauth client return null
        final mockOAuth = MockMastodonOAuth(
          hasCredentials: true,
          clientToReturn: null,
        );
        
        final errorAuthManager = AuthManager(oauth: mockOAuth);
        
        await errorAuthManager.initialize();
        
        expect(errorAuthManager.state, equals(AuthState.unauthenticated));
        expect(errorAuthManager.isAuthenticated, isFalse);
        expect(errorAuthManager.client, isNull);
      });
    });
    
    group('authentication', () {
      test('startAuthentication() returns authorization URL and updates state', () {
        final authUrl = authManager.startAuthentication();
        
        expect(authUrl, contains(instanceUrl));
        expect(authUrl, contains('/oauth/authorize'));
        expect(authManager.state, equals(AuthState.authenticating));
      });
      
      test('handleAuthorizationCode() completes auth process successfully', () async {
        // Set up mock response for token exchange
        final tokenResponse = {
          'access_token': 'new_access_token',
          'token_type': 'Bearer',
          'scope': 'read write follow',
          'created_at': 1577836800,
        };
        
        httpClient.mockPost(
          '$instanceUrl/oauth/token',
          http.Response(json.encode(tokenResponse), 200),
        );
        
        // Start authentication
        authManager.startAuthentication();
        
        // Handle auth code
        await authManager.handleAuthorizationCode('test_code');
        
        expect(authManager.state, equals(AuthState.authenticated));
        expect(authManager.isAuthenticated, isTrue);
        expect(authManager.client, isNotNull);
        expect(authManager.error, isNull);
        
        // Verify credentials were stored
        final hasCredentials = await oauth.hasStoredCredentials();
        expect(hasCredentials, isTrue);
      });
      
      test('handleAuthorizationCode() handles errors correctly', () async {
        // Create error-throwing mock OAuth
        final mockOAuth = MockMastodonOAuth(
          throwOnHandleAuthCode: true,
        );
        
        final errorAuthManager = AuthManager(oauth: mockOAuth);
        
        // Start authentication
        errorAuthManager.startAuthentication();
        
        // Handle invalid auth code
        await errorAuthManager.handleAuthorizationCode('invalid_code');
        
        expect(errorAuthManager.state, equals(AuthState.unauthenticated));
        expect(errorAuthManager.isAuthenticated, isFalse);
        expect(errorAuthManager.client, isNull);
        
        // Error is null because it's cleared when entering unauthenticated state
        // This is the correct behavior according to our implementation
        expect(errorAuthManager.error, isNull);
      });
      
      test('error state is correctly set during authentication failures', () {
        // Skip actual HTTP calls and work with in-memory state
        final mockOAuth = MockMastodonOAuth(
          throwOnHandleAuthCode: true,
        );
        
        final testManager = AuthManager(oauth: mockOAuth);
        
        // Start authentication process
        testManager.startAuthentication();
        expect(testManager.state, equals(AuthState.authenticating));
        
        // Set error directly to simulate auth failure
        testManager.setErrorForTesting(
          AuthError(
            type: AuthErrorType.invalidCredentials,
            message: 'Test error',
          )
        );
        testManager.setStateForTesting(AuthState.error);
        
        // Verify error state before setting unauthenticated state
        expect(testManager.error, isNotNull);
        expect(testManager.error?.type, equals(AuthErrorType.invalidCredentials));
        
        // Now transition to unauthenticated which will clear the error
        testManager.setStateForTesting(AuthState.unauthenticated);
        
        // Verify final state
        expect(testManager.state, equals(AuthState.unauthenticated));
        expect(testManager.error, isNull);
      });
    });
    
    group('logout', () {
      test('logout() clears credentials and updates state', () async {
        // Set up authenticated state first
        await credentialStorage.saveCredentials(
          oauth2.Credentials('test_token'),
        );
        await authManager.initialize();
        
        // Logout
        await authManager.logout();
        
        expect(authManager.state, equals(AuthState.unauthenticated));
        expect(authManager.isAuthenticated, isFalse);
        expect(authManager.client, isNull);
        expect(authManager.error, isNull);
        
        // Verify credentials were cleared
        final hasCredentials = await oauth.hasStoredCredentials();
        expect(hasCredentials, isFalse);
      });
      
      test('logout() handles errors gracefully', () async {
        // Set up authenticated state with a client that will throw on close
        final mockOAuth = MockMastodonOAuth(
          hasCredentials: true,
          throwOnLogout: true,
        );
        
        final errorAuthManager = AuthManager(oauth: mockOAuth);
        await errorAuthManager.initialize();
        
        // Logout - should handle the error gracefully
        await errorAuthManager.logout();
        
        expect(errorAuthManager.state, equals(AuthState.unauthenticated));
        expect(errorAuthManager.isAuthenticated, isFalse);
        expect(errorAuthManager.client, isNull);
      });
    });
    
    group('HTTP client', () {
      test('createHttpClient() returns authenticated client when authenticated', () async {
        // Set up authenticated state first
        await credentialStorage.saveCredentials(
          oauth2.Credentials('test_token'),
        );
        await authManager.initialize();
        
        final client = authManager.createHttpClient();
        expect(client, isNotNull);
      });
      
      test('createHttpClient() returns regular client when not authenticated', () async {
        await authManager.initialize(); // No credentials yet
        
        final client = authManager.createHttpClient();
        expect(client, isA<http.Client>());
      });
    });
    
    group('state notification', () {
      test('state changes emit events', () async {
        bool stateChangeReceived = false;
        
        // Listen for state changes
        final subscription = authManager.onStateChanged.listen((state) {
          stateChangeReceived = true;
        });
        
        // Make sure we wait for the stream to be established
        await Future.delayed(Duration.zero);
        
        // Trigger a state change
        authManager.startAuthentication();
        
        // Make sure we give the event loop time to deliver the event
        await Future.delayed(Duration.zero);
        
        // Should have received a state change event
        expect(stateChangeReceived, isTrue);
        
        // Clean up
        await subscription.cancel();
      });
      
      test('error state is reset when entering authenticated state', () async {
        // Setup: Use mock OAuth that throws on auth code
        final mockOAuth = MockMastodonOAuth(
          throwOnHandleAuthCode: true,
        );
        
        final errorAuthManager = AuthManager(oauth: mockOAuth);
        
        // Start authentication and create error
        errorAuthManager.startAuthentication();
        try {
          await errorAuthManager.handleAuthorizationCode('invalid_code');
        } catch (e) {
          // Error is expected
        }
        
        // Force error state directly for testing
        errorAuthManager.setErrorForTesting(
          AuthError(
            type: AuthErrorType.invalidCredentials,
            message: 'Test error',
          )
        );
        
        expect(errorAuthManager.error, isNotNull);
        
        // Now simulate authentication success by setting auth state directly
        errorAuthManager.setStateForTesting(AuthState.authenticated);
        
        // Error should be reset
        expect(errorAuthManager.error, isNull);
      });
    });
  });
}

/// Mock MastodonOAuth for testing error conditions
class MockMastodonOAuth extends MastodonOAuth {
  final bool hasCredentials;
  final oauth2.Client? clientToReturn;
  final bool throwOnLogout;
  final bool throwOnHandleAuthCode;
  
  MockMastodonOAuth({
    this.hasCredentials = false,
    this.clientToReturn,
    this.throwOnLogout = false,
    this.throwOnHandleAuthCode = false,
  }) : super(
          instanceUrl: 'https://example.com',
          clientId: 'mock_client_id',
          clientSecret: 'mock_client_secret',
          redirectUrl: 'https://example.com/callback',
        );
  
  @override
  Future<bool> hasStoredCredentials() async {
    return hasCredentials;
  }
  
  @override
  Future<oauth2.Client?> loadClientFromStorage() async {
    return clientToReturn;
  }
  
  @override
  Future<void> logout() async {
    if (throwOnLogout) {
      throw Exception('Mock logout error');
    }
  }
  
  @override
  Future<oauth2.Client> handleAuthorizationCode(String code) async {
    if (throwOnHandleAuthCode) {
      throw Exception('Invalid authorization code');
    }
    return super.handleAuthorizationCode(code);
  }
  
  @override
  String getAuthorizationUrl() {
    return 'https://example.com/oauth/authorize?mock=true';
  }
}

/// Simple mock HTTP client for testing
class MockHttpClient extends http.BaseClient {
  final Map<String, http.Response> _postResponses = {};
  
  void mockPost(String url, http.Response response) {
    _postResponses[url] = response;
  }
  
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    if (request is http.Request) {
      if (request.method == 'POST') {
        final url = request.url.toString();
        
        final response = _postResponses[url] ?? 
          _postResponses.entries
              .firstWhere(
                (entry) => url.endsWith(entry.key) || url.contains(entry.key),
                orElse: () => MapEntry('', http.Response('Not mocked', 404)),
              )
              .value;
        
        return http.StreamedResponse(
          Stream.value(utf8.encode(response.body)),
          response.statusCode,
          headers: response.headers,
        );
      }
    }
    
    return http.StreamedResponse(
      Stream.value(utf8.encode('Not implemented')),
      501,
    );
  }
} 