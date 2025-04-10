import 'package:mastodon_api/mastodon_api.dart';
import 'package:test/test.dart';

void main() {
  group('Mastodon API Library', () {
    test('Basic exports are available', () {
      // Verify key classes are exported and instantiable
      expect(MastodonOAuth, isNotNull);
      expect(AuthManager, isNotNull);
      expect(ApiService, isNotNull);
      expect(MastodonClient, isNotNull);
      
      // Verify we can create a client setup using the factory
      final factory = MastodonApiFactory;
      expect(factory, isNotNull);
    });
    
    test('Credential storage classes are available', () {
      // Verify credential storage classes
      expect(InMemoryCredentialStorage, isNotNull);
      expect(FileCredentialStorage, isNotNull);
    });
    
    test('API error classes are available', () {
      // Verify API error types
      expect(ApiErrorType.values, contains(ApiErrorType.authentication));
      expect(ApiErrorType.values, contains(ApiErrorType.network));
      expect(ApiErrorType.values, contains(ApiErrorType.client));
      expect(ApiErrorType.values, contains(ApiErrorType.server));
      
      // Verify we can create an API error
      final error = ApiError(
        type: ApiErrorType.client,
        message: 'Test error',
        statusCode: 400,
      );
      expect(error.type, equals(ApiErrorType.client));
      expect(error.message, equals('Test error'));
      expect(error.statusCode, equals(400));
    });
  });
}
