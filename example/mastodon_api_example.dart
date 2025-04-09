import 'dart:io';

import 'package:mastodon_api/mastodon_api.dart';
import 'package:oauth2/oauth2.dart' as oauth2;

// Credentials storage for persisting OAuth tokens
class FileSystemCredentialStorage implements CredentialStorage {
  final String filePath;
  
  FileSystemCredentialStorage(this.filePath);
  
  @override
  Future<void> saveCredentials(oauth2.Credentials credentials) async {
    final file = File(filePath);
    final json = credentials.toJson();
    await file.writeAsString(json);
    print('Credentials saved to $filePath');
  }
  
  @override
  Future<oauth2.Credentials?> loadCredentials() async {
    final file = File(filePath);
    if (!await file.exists()) {
      return null;
    }
    
    final json = await file.readAsString();
    try {
      return oauth2.Credentials.fromJson(json);
    } catch (e) {
      print('Error loading credentials: $e');
      return null;
    }
  }
  
  @override
  Future<void> clearCredentials() async {
    final file = File(filePath);
    if (await file.exists()) {
      await file.delete();
      print('Credentials cleared from $filePath');
    }
  }
}

Future<void> main() async {
  // Configuration
  const instanceUrl = 'https://social.vivaldi.net';
  const clientId = 'YOUR_CLIENT_ID';  // Replace with your client ID
  const clientSecret = 'YOUR_CLIENT_SECRET';  // Replace with your client secret
  const redirectUrl = 'http://localhost:8080/callback';
  final credentialsFile = '${Directory.current.path}/credentials.json';
  
  print('Mastodon API Example\n------------------');
  
  // Create storage for credentials
  final storage = FileSystemCredentialStorage(credentialsFile);
  
  // Create the Mastodon API client setup
  final clientSetup = await MastodonApiFactory.createClient(
    instanceUrl: instanceUrl,
    clientId: clientId,
    clientSecret: clientSecret,
    redirectUri: redirectUrl,
    credentialStorage: storage,
  );
  
  // Get a reference to the client and auth manager
  final client = clientSetup.client;
  final authManager = clientSetup.authManager;
  
  // Authentication state listener
  authManager.onStateChanged.listen((state) {
    print('Auth state changed: $state');
  });
  
  // Check if the user is already authenticated
  if (clientSetup.isAuthenticated) {
    print('Already authenticated!');
  } else {
    // Start the authentication process
    print('Not authenticated, starting auth flow...');
    
    // Get the authorization URL to open in a browser
    final authUrl = clientSetup.startAuthentication();
    print('Please open this URL in your browser:');
    print(authUrl);
    
    // Wait for the user to enter the authorization code
    print('\nAfter authorization, enter the code from the redirect URL:');
    final code = stdin.readLineSync()?.trim() ?? '';
    
    // Exchange the code for an access token
    try {
      await clientSetup.handleAuthorizationCode(code);
      print('Authentication successful!');
    } catch (e) {
      print('Authentication failed: $e');
      exit(1);
    }
  }
  
  // Now we can use the API
  print('\nFetching instance info...');
  try {
    final instanceInfo = await client.getInstance();
    print('Connected to: ${instanceInfo['title']}');
    print('Version: ${instanceInfo['version']}');
    print('Users: ${instanceInfo['stats']['user_count']}');
  } catch (e) {
    print('Error fetching instance info: $e');
  }
  
  // Fetch user information
  print('\nFetching user info...');
  try {
    final accountInfo = await client.verifyCredentials();
    print('Logged in as: ${accountInfo['username']}');
    print('Display name: ${accountInfo['display_name']}');
    print('Followers: ${accountInfo['followers_count']}');
    print('Following: ${accountInfo['following_count']}');
  } catch (e) {
    print('Error fetching user info: $e');
  }
  
  // Fetch home timeline
  print('\nFetching home timeline...');
  try {
    final timeline = await client.getHomeTimeline(limit: 5);
    print('Recent posts:');
    for (var post in timeline) {
      final account = post['account'] as Map<String, dynamic>;
      print('- ${account['display_name']} (@${account['username']}): ${_stripHtml(post['content'] as String)}');
    }
  } catch (e) {
    print('Error fetching timeline: $e');
  }
  
  // Clean up
  clientSetup.dispose();
  print('\nDone!');
}

// Helper to strip HTML from post content
String _stripHtml(String html) {
  // Very simple HTML stripping
  return html
      .replaceAll(RegExp(r'<[^>]*>'), '') // Remove HTML tags
      .replaceAll('&nbsp;', ' ')         // Replace common HTML entities
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll('&amp;', '&')
      .trim();
}
