import 'package:mastodon_api/mastodon_api.dart';
import 'package:test/test.dart';

void main() {
  group('MastodonOAuth', () {
    const instanceUrl = 'https://social.vivaldi.net';
    const clientId = 'test_client_id';
    const clientSecret = 'test_client_secret';
    const redirectUrl = 'http://localhost:8080/callback';
    
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
    
    test('getAuthorizationUrl constructs proper URL', () {
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
      expect(authUrl, contains('scope=read+write+follow'));
    });
    
    // Note: We don't test the authenticate() method here because it requires
    // opening a browser and user interaction. These would be better tested
    // with integration tests or mocked HTTP responses.
  });
} 