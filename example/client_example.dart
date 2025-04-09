import 'dart:convert';
import 'dart:io';

import 'package:mastodon_api/mastodon_api.dart';
import 'package:oauth2/oauth2.dart' as oauth2;

Future<void> main() async {
  print('Mastodon API Client Example');
  print('==========================');
  
  try {
    // Check if config file exists
    final configFile = File('mastodon_config.json');
    if (!await configFile.exists()) {
      print('Config file not found. Please run oauth_example.dart first.');
      return;
    }
    
    // Load the config
    final configJson = await configFile.readAsString();
    final config = jsonDecode(configJson) as Map<String, dynamic>;
    
    final instanceUrl = config['instance_url'] as String;
    final clientId = config['client_id'] as String;
    final clientSecret = config['client_secret'] as String;
    final redirectUrl = config['redirect_url'] as String;
    final accessToken = config['access_token'] as String;
    
    print('Using instance: $instanceUrl');
    
    // Create OAuth credentials
    final credentials = oauth2.Credentials(
      accessToken,
      tokenEndpoint: Uri.parse('$instanceUrl/oauth/token'),
    );
    
    // Create OAuth client
    final oauth = MastodonOAuth(
      instanceUrl: instanceUrl,
      clientId: clientId,
      clientSecret: clientSecret,
      redirectUrl: redirectUrl,
    );
    
    final oauthClient = oauth.createClientFromCredentials(credentials);
    
    // Create an in-memory credential storage with pre-loaded credentials
    final credentialStorage = InMemoryCredentialStorage();
    await credentialStorage.saveCredentials(credentials);
    
    // Create OAuth with credential storage
    final oauthWithStorage = MastodonOAuth(
      instanceUrl: instanceUrl,
      clientId: clientId,
      clientSecret: clientSecret,
      redirectUrl: redirectUrl,
      credentialStorage: credentialStorage,
    );
    
    // Create AuthManager with credential storage
    final authManager = AuthManager(oauth: oauthWithStorage);
    await authManager.initialize(); // This will load the credentials we just saved
    
    // Create API service
    final apiService = ApiService(
      authManager: authManager,
      instanceUrl: instanceUrl,
    );
    
    // Create Mastodon API client
    final mastodon = MastodonClient(
      apiService: apiService,
    );
    
    // Get instance information
    print('\nFetching instance information...');
    final instance = await mastodon.getInstance();
    print('Instance: ${instance['title']}');
    print('Description: ${instance['description']}');
    print('Version: ${instance['version']}');
    
    // Get user information
    print('\nFetching user information...');
    final user = await mastodon.verifyCredentials();
    print('Logged in as: ${user['username']} (${user['display_name']})');
    print('Followers: ${user['followers_count']}');
    print('Following: ${user['following_count']}');
    print('Posts: ${user['statuses_count']}');
    
    // Get home timeline
    print('\nFetching home timeline...');
    final timeline = await mastodon.getHomeTimeline(limit: 3);
    print('Got ${timeline.length} posts from your home timeline:');
    
    for (final status in timeline) {
      final account = status['account'] as Map<String, dynamic>;
      final content = status['content'] as String;
      print('\n• ${account['display_name']} (@${account['username']}) posted:');
      print('  ${_stripHtml(content).substring(0, _stripHtml(content).length > 100 ? 100 : _stripHtml(content).length)}${_stripHtml(content).length > 100 ? '...' : ''}');
    }
    
    // Post a status (commented out to prevent accidental posting)
    /*
    print('\nPosting a status...');
    final status = await mastodon.postStatus(
      status: 'Hello from Mastodon API Dart Library! #testing',
      visibility: 'unlisted', // Use 'unlisted' for testing
    );
    print('Status posted! ID: ${status['id']}');
    */
    
    // Search for content
    print('\nSearching for content...');
    final searchQuery = 'mastodon';
    final searchResults = await mastodon.search(query: searchQuery, limit: 3);
    
    final accounts = searchResults['accounts'] as List;
    final statuses = searchResults['statuses'] as List;
    final hashtags = searchResults['hashtags'] as List;
    
    print('Search results for "$searchQuery":');
    print('- Accounts: ${accounts.length}');
    print('- Statuses: ${statuses.length}');
    print('- Hashtags: ${hashtags.length}');
    
    if (accounts.isNotEmpty) {
      print('\nTop account result:');
      final account = accounts.first as Map<String, dynamic>;
      print('${account['display_name']} (@${account['acct']})');
      print('Followers: ${account['followers_count']}');
    }
    
  } catch (e) {
    print('\nError: $e');
  }
}

// Helper function to strip HTML from post content
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