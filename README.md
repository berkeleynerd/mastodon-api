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

# Mastodon API for Dart

A Dart library for interacting with the Mastodon API. This library provides tools for authenticating with Mastodon instances via OAuth2 and making API requests to Mastodon servers.

## Features

- OAuth2 authentication flow for Mastodon
- Credential storage and management
- Platform-agnostic design (works with any Dart application)
- Comprehensive API client for Mastodon REST API
- CLI example application

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

## Usage

### Configuration

The library requires a valid Mastodon application registration. You can store your configuration in a JSON file:

```json
{
  "instance_url": "https://your.mastodon.instance",
  "client_id": "your_client_id",
  "client_secret": "your_client_secret",
  "redirect_url": "http://localhost:8080/callback"
}
```

### CLI Example

This package includes a command-line example application in the `example` directory. To run it:

```bash
cd example
dart mastodon_cli.dart
```

The CLI app demonstrates:
- OAuth2 authentication flow
- Retrieving instance information
- Viewing account details
- Browsing home and public timelines

### OAuth2 Authentication

Here's how to use the OAuth2 authentication flow:

```dart
import 'dart:io';
import 'package:mastodon_api/mastodon_api.dart';
import 'package:http/http.dart' as http;

Future<void> main() async {
  // Configuration
  const instanceUrl = 'https://mastodon.social';
  const clientId = 'your_client_id';
  const clientSecret = 'your_client_secret';
  const redirectUrl = 'http://localhost:8080/callback';
  
  // Setup credential storage
  final credentialStorage = FileCredentialStorage(
    writeFile: (data) async {
      await File('credentials.json').writeAsString(data);
    },
    readFile: () async {
      final file = File('credentials.json');
      if (await file.exists()) {
        return await file.readAsString();
      }
      return null;
    },
    deleteFile: () async {
      final file = File('credentials.json');
      if (await file.exists()) {
        await file.delete();
      }
    },
  );

  // Initialize OAuth
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
  
  // If not authenticated, start auth flow
  if (!authManager.isAuthenticated) {
    final authUrl = authManager.startAuthentication();
    print('Open this URL in your browser: $authUrl');
    
    stdout.write('Enter the authorization code: ');
    final code = stdin.readLineSync();
    
    await authManager.handleAuthorizationCode(code!);
    
    if (!authManager.isAuthenticated) {
      print('Authentication failed: ${authManager.error?.message}');
      return;
    }
    
    print('Authentication successful!');
  }
  
  // Create API service and client
  final apiService = ApiService(
    authManager: authManager,
    instanceUrl: instanceUrl,
  );
  
  final client = MastodonClient(apiService: apiService);
  
  // Use client for API requests
  final accountInfo = await client.verifyCredentials();
  print('Logged in as: ${accountInfo['username']}');
}
```

### Using the API Client

Once authenticated, you can use the MastodonClient to interact with the API:

```dart
// Get instance information
final instanceInfo = await client.getInstance();
print('Instance: ${instanceInfo['title']}');

// Get home timeline
final timeline = await client.getHomeTimeline(limit: 10);
for (final post in timeline) {
  print('${post['account']['username']}: ${post['content']}');
}

// Post a status
final status = await client.createStatus(
  status: 'Hello from Mastodon API for Dart!',
  visibility: 'public',
);

// Get notifications
final notifications = await client.getNotifications();
for (final notification in notifications) {
  print('${notification['type']} from ${notification['account']['username']}');
}
```

## Testing

This library includes comprehensive tests. To run them:

```bash
dart test
```

The test suite includes:
- Unit tests for API services
- Authentication tests
- Integration tests
- Mock HTTP client for testing

## Development

For development, use the provided development flavor:

```bash
dart run example/mastodon_cli.dart
```

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## Security

This package implements several security best practices:

- **PKCE OAuth Flow**: For secure authentication without exposing client secrets
- **Token Refresh**: Automatic handling of token expiration and refresh
- **Certificate Validation**: Options for custom certificate validation and pinning
- **Secure Storage**: Options for encrypting stored credentials

For detailed security guidelines, see [SECURITY.md](SECURITY.md).

## Secure Credential Storage

This library provides a `CredentialStorage` interface for persisting OAuth credentials. For production applications, we recommend using platform-specific secure storage solutions.

The library implements the following storage options:

- **InMemoryCredentialStorage**: For testing and development
- **FileCredentialStorage**: Basic file-based storage
- **SecureCredentialStorage**: Optional encrypted storage with basic protection

For applications with specific security requirements, implement a custom `CredentialStorage` with your preferred security approach.
