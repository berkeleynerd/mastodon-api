import 'dart:convert';
import 'package:mastodon_api/src/auth/credential_storage.dart';
import 'package:oauth2/oauth2.dart' as oauth2;
import 'package:test/test.dart';

void main() {
  group('InMemoryCredentialStorage', () {
    late InMemoryCredentialStorage storage;
    
    setUp(() {
      storage = InMemoryCredentialStorage();
    });
    
    test('loadCredentials returns null when no credentials stored', () async {
      final credentials = await storage.loadCredentials();
      expect(credentials, isNull);
    });
    
    test('saveCredentials and loadCredentials work correctly', () async {
      final initialCredentials = oauth2.Credentials(
        'test_access_token',
        refreshToken: 'test_refresh_token',
        scopes: ['read', 'write', 'follow'],
        expiration: DateTime.now().add(Duration(hours: 1)),
      );
      
      await storage.saveCredentials(initialCredentials);
      
      final loadedCredentials = await storage.loadCredentials();
      expect(loadedCredentials, isNotNull);
      expect(loadedCredentials!.accessToken, equals('test_access_token'));
      expect(loadedCredentials.refreshToken, equals('test_refresh_token'));
      expect(loadedCredentials.scopes, equals(['read', 'write', 'follow']));
    });
    
    test('clearCredentials removes stored credentials', () async {
      final initialCredentials = oauth2.Credentials(
        'test_access_token',
      );
      
      await storage.saveCredentials(initialCredentials);
      await storage.clearCredentials();
      
      final loadedCredentials = await storage.loadCredentials();
      expect(loadedCredentials, isNull);
    });
  });
  
  group('FileCredentialStorage', () {
    late FileCredentialStorage storage;
    String? storedData;
    
    setUp(() {
      storedData = null;
      storage = FileCredentialStorage(
        writeFile: (data) async => storedData = data,
        readFile: () async => storedData,
        deleteFile: () async => storedData = null,
      );
    });
    
    test('loadCredentials returns null when no credentials stored', () async {
      final credentials = await storage.loadCredentials();
      expect(credentials, isNull);
    });
    
    test('saveCredentials writes credentials to file', () async {
      final initialCredentials = oauth2.Credentials(
        'test_access_token',
        refreshToken: 'test_refresh_token',
        scopes: ['read', 'write', 'follow'],
      );
      
      await storage.saveCredentials(initialCredentials);
      
      expect(storedData, isNotNull);
      if (storedData != null) {
        print('Stored data: $storedData');
        final parsed = jsonDecode(storedData!);
        expect(parsed['accessToken'], equals('test_access_token'));
        expect(parsed['refreshToken'], equals('test_refresh_token'));
      }
    });
    
    test('loadCredentials reads and parses credentials from file', () async {
      // First save credentials
      final initialCredentials = oauth2.Credentials(
        'test_access_token',
        refreshToken: 'test_refresh_token',
        scopes: ['read', 'write', 'follow'],
      );
      await storage.saveCredentials(initialCredentials);
      
      // Then load them
      final loadedCredentials = await storage.loadCredentials();
      print('Loaded credentials: $loadedCredentials');
      expect(loadedCredentials, isNotNull);
      expect(loadedCredentials!.accessToken, equals('test_access_token'));
      expect(loadedCredentials.refreshToken, equals('test_refresh_token'));
    });
    
    test('clearCredentials deletes the file', () async {
      final initialCredentials = oauth2.Credentials(
        'test_access_token',
      );
      
      await storage.saveCredentials(initialCredentials);
      await storage.clearCredentials();
      
      expect(storedData, isNull);
      final loadedCredentials = await storage.loadCredentials();
      expect(loadedCredentials, isNull);
    });
    
    test('loadCredentials handles invalid JSON', () async {
      storedData = 'not valid json';
      final credentials = await storage.loadCredentials();
      expect(credentials, isNull);
    });
  });
} 