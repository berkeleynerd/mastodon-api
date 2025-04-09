import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:mastodon_api/mastodon_api.dart';
import 'package:mastodon_api/src/auth/credential_storage.dart';
import 'package:oauth2/oauth2.dart' as oauth2;
import 'package:test/test.dart';

void main() {
  group('MastodonOAuth with credential persistence', () {
    const instanceUrl = 'https://social.vivaldi.net';
    const clientId = 'test_client_id';
    const clientSecret = 'test_client_secret';
    const redirectUrl = 'http://localhost:8080/callback';
    
    late InMemoryCredentialStorage credentialStorage;
    late MockHttpClient httpClient;
    late MastodonOAuth oauth;
    
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
    });
    
    test('hasStoredCredentials returns false when no credentials are stored', () async {
      final hasCredentials = await oauth.hasStoredCredentials();
      expect(hasCredentials, isFalse);
    });
    
    test('hasStoredCredentials returns true when credentials are stored', () async {
      await credentialStorage.saveCredentials(
        oauth2.Credentials('test_token'),
      );
      
      final hasCredentials = await oauth.hasStoredCredentials();
      expect(hasCredentials, isTrue);
    });
    
    test('loadClientFromStorage returns null when no credentials are stored', () async {
      final client = await oauth.loadClientFromStorage();
      expect(client, isNull);
    });
    
    test('loadClientFromStorage returns client when credentials are stored', () async {
      await credentialStorage.saveCredentials(
        oauth2.Credentials('test_token'),
      );
      
      final client = await oauth.loadClientFromStorage();
      expect(client, isNotNull);
      expect(client!.credentials.accessToken, equals('test_token'));
    });
    
    test('logout clears stored credentials', () async {
      await credentialStorage.saveCredentials(
        oauth2.Credentials('test_token'),
      );
      
      await oauth.logout();
      
      final hasCredentials = await oauth.hasStoredCredentials();
      expect(hasCredentials, isFalse);
    });
    
    test('handleAuthorizationCode saves credentials to storage', () async {
      // Create mock response for successful token exchange
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
      
      // Generate the authorization URL to create code verifier
      oauth.getAuthorizationUrl();
      
      // Exchange code for token
      final client = await oauth.handleAuthorizationCode('test_code');
      
      // Verify the client was created
      expect(client, isNotNull);
      expect(client.credentials.accessToken, equals('new_access_token'));
      
      // Verify credentials were saved to storage
      final storedCredentials = await credentialStorage.loadCredentials();
      expect(storedCredentials, isNotNull);
      expect(storedCredentials!.accessToken, equals('new_access_token'));
    });
    
    test('_onCredentialsRefreshed updates stored credentials', () async {
      // First store some credentials
      final initialCredentials = oauth2.Credentials(
        'initial_token',
        refreshToken: 'initial_refresh_token',
      );
      
      await credentialStorage.saveCredentials(initialCredentials);
      
      // Simulate credentials refresh
      final refreshedCredentials = oauth2.Credentials(
        'refreshed_token',
        refreshToken: 'refreshed_refresh_token',
      );
      
      // Call the private method
      oauth.callOnCredentialsRefreshed(refreshedCredentials);
      
      // Verify the stored credentials were updated
      final storedCredentials = await credentialStorage.loadCredentials();
      expect(storedCredentials, isNotNull);
      expect(storedCredentials!.accessToken, equals('refreshed_token'));
      expect(storedCredentials.refreshToken, equals('refreshed_refresh_token'));
    });
  });
}

// Simple mock HTTP client for testing (copied from mastodon_oauth_test.dart)
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