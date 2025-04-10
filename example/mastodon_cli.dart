import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:mastodon_api/mastodon_api.dart';
import 'package:http/http.dart' as http;

// Configuration file is expected to be in the project root
const configFile = '../mastodon_config.json';

Future<void> main() async {
  print('Mastodon API CLI Example');
  print('------------------------');

  try {
    // Load configuration from file
    final configJson = await loadConfig();
    final instanceUrl = configJson['instance_url'] as String;
    final clientId = configJson['client_id'] as String;
    final clientSecret = configJson['client_secret'] as String;
    final redirectUrl = configJson['redirect_url'] as String;

    print('Using Mastodon instance: $instanceUrl');

    // Setup file operations for credential storage
    final credentialsFilePath = 'credentials.json';
    final credentialStorage = FileCredentialStorage(
      writeFile: (data) async {
        final file = File(credentialsFilePath);
        await file.writeAsString(data);
      },
      readFile: () async {
        final file = File(credentialsFilePath);
        if (await file.exists()) {
          return await file.readAsString();
        }
        return null;
      },
      deleteFile: () async {
        final file = File(credentialsFilePath);
        if (await file.exists()) {
          await file.delete();
        }
      },
    );

    // Create oauth flow
    final oauth = MastodonOAuth(
      instanceUrl: instanceUrl,
      clientId: clientId,
      clientSecret: clientSecret,
      redirectUrl: redirectUrl,
      credentialStorage: credentialStorage,
      httpClient: http.Client(),
    );

    // Create auth manager
    final authManager = AuthManager(oauth: oauth);
    await authManager.initialize();

    // Create API service
    final apiService = ApiService(
      authManager: authManager,
      instanceUrl: instanceUrl,
    );

    // Create client
    final client = MastodonClient(apiService: apiService);

    // Check if we're already authenticated
    if (!authManager.isAuthenticated) {
      // Start the auth flow
      await startAuthFlow(authManager);
    }

    // Main loop
    bool running = true;
    while (running) {
      print('\nWhat would you like to do?');
      print('1. Show instance info');
      print('2. Show my account info');
      print('3. Show home timeline');
      print('4. Show public timeline');
      print('5. Exit');
      stdout.write('Enter your choice (1-5): ');

      final choice = stdin.readLineSync()?.trim() ?? '';
      print('');

      try {
        switch (choice) {
          case '1':
            await showInstanceInfo(client);
            break;
          case '2':
            await showAccountInfo(client);
            break;
          case '3':
            await showHomeTimeline(client);
            break;
          case '4':
            await showPublicTimeline(client);
            break;
          case '5':
            running = false;
            break;
          default:
            print('Invalid choice, please try again.');
        }
      } catch (e) {
        print('Error: $e');
      }
    }

    print('Goodbye!');
  } catch (e) {
    print('Error: $e');
    exit(1);
  }
}

Future<Map<String, dynamic>> loadConfig() async {
  final file = File(configFile);
  if (!await file.exists()) {
    throw Exception('Configuration file not found: $configFile');
  }

  final contents = await file.readAsString();
  return json.decode(contents) as Map<String, dynamic>;
}

Future<void> startAuthFlow(AuthManager authManager) async {
  print('You need to authenticate first.');
  final authUrl = authManager.startAuthentication();
  print('Please open this URL in your browser:');
  print(authUrl);
  print('');

  stdout.write('After authorizing, enter the code from the browser: ');
  final code = stdin.readLineSync()?.trim() ?? '';

  await authManager.handleAuthorizationCode(code);

  if (authManager.isAuthenticated) {
    print('Authentication successful!');
  } else {
    throw Exception('Authentication failed: ${authManager.error?.message}');
  }
}

Future<void> showInstanceInfo(MastodonClient client) async {
  print('Getting instance info...');
  final info = await client.getInstance();
  print('Instance: ${info['title']}');
  print('Version: ${info['version']}');
  print('Description: ${info['description'] ?? 'No description'}');
  print('URI: ${info['uri']}');
}

Future<void> showAccountInfo(MastodonClient client) async {
  print('Getting account info...');
  final info = await client.verifyCredentials();
  print('Username: @${info['username']}@${client.instanceUrl.replaceAll('https://', '')}');
  print('Display name: ${info['display_name']}');
  print('Followers: ${info['followers_count']}');
  print('Following: ${info['following_count']}');
  print('Posts: ${info['statuses_count']}');
}

Future<void> showHomeTimeline(MastodonClient client) async {
  print('Getting home timeline...');
  final posts = await client.getHomeTimeline(limit: 5);
  _displayPosts(posts);
}

Future<void> showPublicTimeline(MastodonClient client) async {
  print('Getting public timeline...');
  final posts = await client.getPublicTimeline(limit: 5);
  _displayPosts(posts);
}

void _displayPosts(List<dynamic> posts) {
  if (posts.isEmpty) {
    print('No posts to display.');
    return;
  }

  for (final post in posts) {
    final account = post['account'];
    final content = _stripHtml(post['content']);
    
    print('----------------------------------------');
    print('${account['display_name']} (@${account['username']})');
    print(content);
    print('❤ ${post['favourites_count']} ♺ ${post['reblogs_count']}');
  }
}

String _stripHtml(String html) {
  return html
      .replaceAll(RegExp(r'<[^>]*>'), '')
      .replaceAll('&nbsp;', ' ')
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll('&amp;', '&');
} 