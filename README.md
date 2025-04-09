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

## Usage

### OAuth2 Authentication

Here's how to use the OAuth2 authentication flow:

```dart
import 'dart:convert';
import 'dart:io';

import 'package:mastodon_api/mastodon_api.dart';

Future<void> main() async {
  // Configuration
  const instanceUrl = 'https://mastodon.social'; // Your Mastodon instance
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
  const instanceUrl = 'https://mastodon.social';
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

## Example

Check out the `example` directory for a complete command-line example application.

## License

This project is licensed under the MIT License - see the LICENSE file for details.
