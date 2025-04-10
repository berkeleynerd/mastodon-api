import 'package:mastodon_api/mastodon_api.dart';
import 'package:oauth2/oauth2.dart' as oauth2;

/// Mock OAuth implementation for testing
class MockMastodonOAuth extends MastodonOAuth {
  final bool hasCredentials;
  final oauth2.Client? clientToReturn;
  final bool throwsOnAuth;
  
  MockMastodonOAuth({
    this.hasCredentials = false,
    this.clientToReturn,
    this.throwsOnAuth = false,
  }) : super(
          instanceUrl: 'https://example.com',
          clientId: 'mock_client_id',
          clientSecret: 'mock_client_secret',
          redirectUrl: 'http://example.com/callback',
        );
  
  @override
  Future<bool> hasStoredCredentials() async {
    return hasCredentials;
  }
  
  @override
  Future<oauth2.Client?> loadClientFromStorage() async {
    if (throwsOnAuth) {
      throw Exception('Mock auth error');
    }
    return clientToReturn;
  }
  
  @override
  String getAuthorizationUrl() {
    return 'https://example.com/oauth/authorize?mock=true';
  }
} 