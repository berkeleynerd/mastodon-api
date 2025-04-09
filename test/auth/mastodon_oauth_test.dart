import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:mastodon_api/mastodon_api.dart';
import 'package:oauth2/oauth2.dart' as oauth2;
import 'package:test/test.dart';

void main() {
  group('MastodonOAuth', () {
    const instanceUrl = 'https://social.vivaldi.net';
    const clientId = 'test_client_id';
    const clientSecret = 'test_client_secret';
    const redirectUrl = 'http://localhost:8080/callback';
    late MockHttpClient mockHttpClient;
    
    setUp(() {
      mockHttpClient = MockHttpClient();
    });
    
    test('MastodonOAuth constructor initializes correctly', () {
      final oauth = MastodonOAuth(
        instanceUrl: instanceUrl,
        clientId: clientId,
        clientSecret: clientSecret,
        redirectUrl: redirectUrl,
      );
      
      expect(oauth.instanceUrl, equals(instanceUrl));
      expect(oauth.clientId, equals(clientId));
      expect(oauth.clientSecret, equals(clientSecret));
      expect(oauth.redirectUrl, equals(redirectUrl));
      expect(oauth.scopes, equals(['read', 'write', 'follow']));
    });
    
    test('MastodonOAuth constructor accepts custom scopes', () {
      final customScopes = ['read', 'write'];
      final oauth = MastodonOAuth(
        instanceUrl: instanceUrl,
        clientId: clientId,
        clientSecret: clientSecret,
        redirectUrl: redirectUrl,
        scopes: customScopes,
      );
      
      expect(oauth.scopes, equals(customScopes));
    });
    
    test('getAuthorizationUrl constructs proper URL with PKCE', () {
      final oauth = MastodonOAuth(
        instanceUrl: instanceUrl,
        clientId: clientId,
        clientSecret: clientSecret,
        redirectUrl: redirectUrl,
      );
      
      final authUrl = oauth.getAuthorizationUrl();
      
      expect(authUrl, contains(instanceUrl));
      expect(authUrl, contains('/oauth/authorize'));
      expect(authUrl, contains('client_id=$clientId'));
      expect(authUrl, contains('redirect_uri=http%3A%2F%2Flocalhost%3A8080%2Fcallback'));
      expect(authUrl, contains('scope=read%20write%20follow'));
      expect(authUrl, contains('code_challenge='));
      expect(authUrl, contains('code_challenge_method=S256'));
    });
    
    test('handleAuthorizationCode exchanges code for token successfully', () async {
      // Create mock response for successful token exchange
      final tokenResponse = {
        'access_token': 'test_access_token',
        'token_type': 'Bearer',
        'scope': 'read write follow',
        'created_at': 1577836800,
      };
      
      mockHttpClient.mockPost(
        '$instanceUrl/oauth/token',
        http.Response(json.encode(tokenResponse), 200),
      );
      
      final oauth = MastodonOAuth(
        instanceUrl: instanceUrl,
        clientId: clientId,
        clientSecret: clientSecret,
        redirectUrl: redirectUrl,
        httpClient: mockHttpClient,
      );
      
      // Generate the authorization URL to create code verifier
      oauth.getAuthorizationUrl();
      
      final client = await oauth.handleAuthorizationCode('test_code');
      
      expect(client, isA<oauth2.Client>());
      expect(client.credentials.accessToken, equals('test_access_token'));
      expect(client.credentials.scopes, equals(['read', 'write', 'follow']));
    });
    
    test('handleAuthorizationCode throws exception on error', () async {
      // Create mock response for failed token exchange
      mockHttpClient.mockPost(
        '$instanceUrl/oauth/token',
        http.Response(json.encode({'error': 'invalid_grant'}), 400),
      );
      
      final oauth = MastodonOAuth(
        instanceUrl: instanceUrl,
        clientId: clientId,
        clientSecret: clientSecret,
        redirectUrl: redirectUrl,
        httpClient: mockHttpClient,
      );
      
      // Generate the authorization URL to create code verifier
      oauth.getAuthorizationUrl();
      
      expect(
        () => oauth.handleAuthorizationCode('invalid_code'),
        throwsException,
      );
    });
    
    test('createClientFromCredentials creates valid OAuth2 client', () {
      final oauth = MastodonOAuth(
        instanceUrl: instanceUrl,
        clientId: clientId,
        clientSecret: clientSecret,
        redirectUrl: redirectUrl,
      );
      
      final credentials = oauth2.Credentials(
        'test_access_token',
        refreshToken: 'test_refresh_token',
        scopes: ['read', 'write'],
        expiration: DateTime.now().add(Duration(hours: 1)),
      );
      
      final client = oauth.createClientFromCredentials(credentials);
      
      expect(client, isA<oauth2.Client>());
      expect(client.credentials.accessToken, equals('test_access_token'));
      expect(client.credentials.refreshToken, equals('test_refresh_token'));
      expect(client.credentials.scopes, equals(['read', 'write']));
    });
    
    test('registerApplication creates application successfully', () async {
      // Create mock response for successful app registration
      final registrationResponse = {
        'client_id': 'new_client_id',
        'client_secret': 'new_client_secret',
      };
      
      mockHttpClient.mockPost(
        '$instanceUrl/api/v1/apps',
        http.Response(json.encode(registrationResponse), 200),
      );
      
      final result = await MastodonOAuth.registerApplication(
        instanceUrl: instanceUrl,
        applicationName: 'Test App',
        website: 'https://example.com',
        httpClient: mockHttpClient,
      );
      
      expect(result, isA<Map<String, String>>());
      expect(result['client_id'], equals('new_client_id'));
      expect(result['client_secret'], equals('new_client_secret'));
    });
    
    test('registerApplication throws exception on error', () async {
      // Create mock response for failed app registration
      mockHttpClient.mockPost(
        '$instanceUrl/api/v1/apps',
        http.Response(json.encode({'error': 'Application already exists'}), 422),
      );
      
      expect(
        () => MastodonOAuth.registerApplication(
          instanceUrl: instanceUrl,
          applicationName: 'Test App',
          httpClient: mockHttpClient,
        ),
        throwsException,
      );
    });
  });
}

/// A simple mock HTTP client for testing
class MockHttpClient extends http.BaseClient {
  final Map<String, http.Response> _postResponses = {};
  
  /// Mock a POST response for a specific URL
  void mockPost(String url, http.Response response) {
    _postResponses[url] = response;
  }
  
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    if (request is http.Request) {
      if (request.method == 'POST') {
        final url = request.url.toString();
        
        // Find matching response with exact URL or path match if host matches
        final response = _postResponses[url] ?? 
          _postResponses.entries
              .firstWhere(
                (entry) => url.endsWith(entry.key) || 
                           url.contains(entry.key),
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