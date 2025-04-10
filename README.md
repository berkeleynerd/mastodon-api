<!-- 
This README describes the package. If you publish this package to pub.dev,
this README's contents appear on the landing page for your package.

For information about how to write a good package README, see the guide for
[writing package pages](https://dart.dev/tools/pub/writing-package-pages). 

For general information about developing packages, see the Dart guide for
[creating packages](https://dart.dev/guides/libraries/create-packages)
and the Flutter guide for
[developing packages and plugins](https://flutter.dev/to/develop-packages). 
-->

# Mastodon API

A Dart library for interacting with the Mastodon API. This library provides tools for authenticating with Mastodon instances via OAuth2 and making API requests.

## Features

- OAuth2 authentication flow for Mastodon
- Platform-agnostic design (works with any Dart application)
- Register applications with Mastodon instances
- Handle authorization and token exchange

## Installation

Add this package to your `pubspec.yaml` file:

```yaml
dependencies:
  mastodon_api: ^1.0.0
```

Then run:

```bash
dart pub get
```

Or for Flutter:

```bash
flutter pub get
```

## Usage

### OAuth2 Authentication

Here's how to use the OAuth2 authentication flow:

```dart
import 'dart:convert';
import 'dart:io';

import 'package:mastodon_api/mastodon_api.dart';

Future<void> main() async {
  // Configuration
  const instanceUrl = 'https://social.vivaldi.net'; // Your Mastodon instance
  const applicationName = 'My Mastodon App';
  const redirectUrl = 'http://localhost:8080/callback';
  
  try {
    // Step 1: Register the application
    final registration = await MastodonOAuth.registerApplication(
      instanceUrl: instanceUrl,
      applicationName: applicationName,
      redirectUris: [redirectUrl],
    );
    
    final clientId = registration['client_id']!;
    final clientSecret = registration['client_secret']!;
    
    // Step 2: Initialize the OAuth client
    final oauth = MastodonOAuth(
      instanceUrl: instanceUrl,
      clientId: clientId,
      clientSecret: clientSecret,
      redirectUrl: redirectUrl,
    );
    
    // Step 3: Get the authorization URL for the user to visit
    final authUrl = oauth.getAuthorizationUrl();
    print('Open this URL in your browser: $authUrl');
    
    // Step 4: Get the authorization code from the user
    stdout.write('Enter the authorization code from the browser: ');
    final code = stdin.readLineSync();
    
    // Step 5: Exchange the code for an access token
    final client = await oauth.handleAuthorizationCode(code!);
    
    // Step 6: Use the client for API requests
    final response = await client.get(
      Uri.parse('$instanceUrl/api/v1/accounts/verify_credentials'),
    );
    
    print('Account info: ${response.body}');
    
    // Save credentials for later
    final credentials = client.credentials;
    // In a real app, securely store these credentials
  } catch (e) {
    print('Error: $e');
  }
}
```

### Reusing Saved Credentials

You can reuse saved credentials:

```dart
import 'dart:convert';
import 'dart:io';

import 'package:mastodon_api/mastodon_api.dart';
import 'package:oauth2/oauth2.dart' as oauth2;

Future<void> main() async {
  // Configuration
  const instanceUrl = 'https://social.vivaldi.net';
  const clientId = 'your_client_id';
  const clientSecret = 'your_client_secret';
  const redirectUrl = 'http://localhost:8080/callback';
  
  // Load saved credentials
  final file = File('credentials.json');
  final json = jsonDecode(await file.readAsString());
  final credentials = oauth2.Credentials.fromJson(json);
  
  // Create OAuth client
  final oauth = MastodonOAuth(
    instanceUrl: instanceUrl,
    clientId: clientId,
    clientSecret: clientSecret,
    redirectUrl: redirectUrl,
  );
  
  // Create HTTP client from credentials
  final client = oauth.createClientFromCredentials(credentials);
  
  // Use the client for API requests
  final response = await client.get(
    Uri.parse('$instanceUrl/api/v1/timelines/home'),
  );
  
  print('Home timeline: ${response.body}');
}
```

## Flutter Integration

This library is designed to work seamlessly with Flutter applications. Here's how to integrate it:

### Setting up Authentication in Flutter

```dart
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:mastodon_api/mastodon_api.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MastodonLoginScreen extends StatefulWidget {
  @override
  _MastodonLoginScreenState createState() => _MastodonLoginScreenState();
}

class _MastodonLoginScreenState extends State<MastodonLoginScreen> {
  late MastodonOAuth oauth;
  final instanceUrl = 'https://mastodon.social';
  final redirectUrl = 'myapp://callback';
  String? authUrl;
  
  @override
  void initState() {
    super.initState();
    _initializeOAuth();
  }
  
  Future<void> _initializeOAuth() async {
    // Register or load existing credentials
    try {
      // Check if we already have client credentials
      final prefs = await SharedPreferences.getInstance();
      String? clientId = prefs.getString('mastodon_client_id');
      String? clientSecret = prefs.getString('mastodon_client_secret');
      
      if (clientId == null || clientSecret == null) {
        // Register new application
        final registration = await MastodonOAuth.registerApplication(
          instanceUrl: instanceUrl,
          applicationName: 'My Flutter Mastodon App',
          redirectUris: [redirectUrl],
          scopes: ['read', 'write', 'follow'],
        );
        
        clientId = registration['client_id']!;
        clientSecret = registration['client_secret']!;
        
        // Save for future use
        await prefs.setString('mastodon_client_id', clientId);
        await prefs.setString('mastodon_client_secret', clientSecret);
      }
      
      // Initialize OAuth
      oauth = MastodonOAuth(
        instanceUrl: instanceUrl,
        clientId: clientId,
        clientSecret: clientSecret,
        redirectUrl: redirectUrl,
      );
      
      // Get authorization URL
      final url = oauth.getAuthorizationUrl();
      setState(() {
        authUrl = url;
      });
    } catch (e) {
      print('Error initializing OAuth: $e');
    }
  }
  
  Future<void> _handleRedirect(String url) async {
    if (url.startsWith(redirectUrl)) {
      final uri = Uri.parse(url);
      final code = uri.queryParameters['code'];
      
      if (code != null) {
        try {
          // Exchange code for token
          final client = await oauth.handleAuthorizationCode(code);
          
          // Save credentials securely
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('mastodon_credentials', client.credentials.toJson());
          
          // Navigate to home screen
          Navigator.of(context).pushReplacementNamed('/home');
        } catch (e) {
          print('Error handling authorization code: $e');
        }
      }
    }
  }
  
  @override
  Widget build(BuildContext context) {
    if (authUrl == null) {
      return Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    
    return Scaffold(
      appBar: AppBar(title: Text('Login to Mastodon')),
      body: WebView(
        initialUrl: authUrl,
        javascriptMode: JavascriptMode.unrestricted,
        navigationDelegate: (NavigationRequest request) {
          if (request.url.startsWith(redirectUrl)) {
            _handleRedirect(request.url);
            return NavigationDecision.prevent;
          }
          return NavigationDecision.navigate;
        },
      ),
    );
  }
}
```

### Using the API Client in Flutter

```dart
import 'package:flutter/material.dart';
import 'package:mastodon_api/mastodon_api.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:oauth2/oauth2.dart' as oauth2;

class HomeTimelineScreen extends StatefulWidget {
  @override
  _HomeTimelineScreenState createState() => _HomeTimelineScreenState();
}

class _HomeTimelineScreenState extends State<HomeTimelineScreen> {
  late MastodonClient mastodon;
  List<dynamic> posts = [];
  bool isLoading = true;
  
  @override
  void initState() {
    super.initState();
    _initializeClient();
  }
  
  Future<void> _initializeClient() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final instanceUrl = prefs.getString('mastodon_instance_url') ?? 'https://mastodon.social';
      final clientId = prefs.getString('mastodon_client_id')!;
      final clientSecret = prefs.getString('mastodon_client_secret')!;
      final redirectUrl = 'myapp://callback';
      
      // Create credential storage that uses shared preferences
      final credentialStorage = CredentialStorage(
        saveCredentials: (credentials) async {
          await prefs.setString('mastodon_credentials', credentials.toJson());
          return true;
        },
        loadCredentials: () async {
          final json = prefs.getString('mastodon_credentials');
          if (json == null) return null;
          return oauth2.Credentials.fromJson(json);
        },
      );
      
      // Create OAuth with credential storage
      final oauth = MastodonOAuth(
        instanceUrl: instanceUrl,
        clientId: clientId,
        clientSecret: clientSecret,
        redirectUrl: redirectUrl,
        credentialStorage: credentialStorage,
      );
      
      // Create AuthManager
      final authManager = AuthManager(oauth: oauth);
      await authManager.initialize();
      
      // Create API service
      final apiService = ApiService(
        authManager: authManager,
        instanceUrl: instanceUrl,
      );
      
      // Create Mastodon client
      mastodon = MastodonClient(apiService: apiService);
      
      // Load timeline
      final timeline = await mastodon.getHomeTimeline();
      setState(() {
        posts = timeline;
        isLoading = false;
      });
    } catch (e) {
      print('Error initializing client: $e');
      setState(() {
        isLoading = false;
      });
    }
  }
  
  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Scaffold(
        appBar: AppBar(title: Text('Home Timeline')),
        body: Center(child: CircularProgressIndicator()),
      );
    }
    
    return Scaffold(
      appBar: AppBar(title: Text('Home Timeline')),
      body: ListView.builder(
        itemCount: posts.length,
        itemBuilder: (context, index) {
          final post = posts[index];
          final account = post['account'];
          
          return ListTile(
            leading: CircleAvatar(
              backgroundImage: NetworkImage(account['avatar']),
            ),
            title: Text('${account['display_name']} @${account['username']}'),
            subtitle: Text(
              _stripHtml(post['content']),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // Navigate to compose screen
        },
        child: Icon(Icons.create),
      ),
    );
  }
  
  String _stripHtml(String html) {
    return html
        .replaceAll(RegExp(r'<[^>]*>'), '')
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&amp;', '&')
        .replaceAll('&quot;', '"')
        .trim();
  }
}
```

### Testing in Flutter

When testing this library in a Flutter application:

1. Always run the tests before using the library in your app:
   ```bash
   dart test
   ```

2. For Flutter applications using this library, follow these best practices:
   - Use a development flavor for macOS development
   - Create mock implementations of the API services for testing your Flutter UI
   - Use dependency injection to swap between real and mock implementations

Example of setting up tests in your Flutter app:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:mastodon_api/mastodon_api.dart';

class MockMastodonClient extends Mock implements MastodonClient {}

void main() {
  late MockMastodonClient mockClient;
  
  setUp(() {
    mockClient = MockMastodonClient();
  });
  
  group('Home timeline', () {
    test('loads posts successfully', () async {
      // Arrange
      when(() => mockClient.getHomeTimeline())
          .thenAnswer((_) async => [
                {
                  'id': '1',
                  'content': '<p>Test post</p>',
                  'account': {
                    'id': '1',
                    'username': 'test',
                    'display_name': 'Test User',
                    'avatar': 'https://example.com/avatar.png',
                  },
                },
              ]);
              
      // Act
      final result = await mockClient.getHomeTimeline();
      
      // Assert
      expect(result.length, 1);
      expect(result[0]['account']['username'], 'test');
    });
  });
}
```

## Example

Check out the `example` directory for a complete command-line example application.

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Security

This package implements several security best practices:

- **PKCE OAuth Flow**: For secure authentication without exposing client secrets
- **Token Refresh**: Automatic handling of token expiration and refresh
- **Certificate Validation**: Options for custom certificate validation and pinning
- **Secure Storage**: Options for encrypting stored credentials

For detailed security guidelines, see [SECURITY.md](SECURITY.md).

## Secure Credential Storage

This library provides a `CredentialStorage` interface for persisting OAuth credentials. For production applications, we recommend using platform-specific secure storage solutions:

- **Flutter Applications**: Use [flutter_secure_storage](https://pub.dev/packages/flutter_secure_storage) with a custom implementation of `CredentialStorage`
- **Web Applications**: Use the Web Crypto API or localStorage with additional encryption
- **Native Applications**: Use Keychain (iOS) or KeyStore (Android)

Example implementation with flutter_secure_storage:

```dart
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:mastodon_api/mastodon_api.dart';
import 'package:oauth2/oauth2.dart' as oauth2;

class FlutterSecureCredentialStorage implements CredentialStorage {
  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  final String _key = 'mastodon_credentials';
  
  @override
  Future<void> saveCredentials(oauth2.Credentials credentials) async {
    await _storage.write(key: _key, value: credentials.toJson());
  }
  
  @override
  Future<oauth2.Credentials?> loadCredentials() async {
    final json = await _storage.read(key: _key);
    if (json == null) return null;
    return oauth2.Credentials.fromJson(json);
  }
  
  @override
  Future<void> clearCredentials() async {
    await _storage.delete(key: _key);
  }
}
```

Note that the library intentionally does not include Flutter-specific dependencies to maintain platform neutrality. Implement secure storage appropriate for your application platform.
