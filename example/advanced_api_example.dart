import 'dart:convert';
import 'dart:io';

import 'package:mastodon_api/mastodon_api.dart';
import 'package:oauth2/oauth2.dart' as oauth2;

Future<void> main() async {
  print('Mastodon API Advanced Features Example');
  print('=====================================');
  
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
    
    // Create in-memory credential storage with pre-loaded credentials
    final credentialStorage = InMemoryCredentialStorage();
    await credentialStorage.saveCredentials(credentials);
    
    // Create the full client setup
    final clientSetup = await MastodonApiFactory.createClient(
      instanceUrl: instanceUrl,
      clientId: clientId,
      clientSecret: clientSecret,
      redirectUri: redirectUrl,
      credentialStorage: credentialStorage,
    );
    
    // Get Mastodon client
    final mastodon = clientSetup.client;
    
    // Verify credentials
    print('\nVerifying credentials...');
    final user = await mastodon.verifyCredentials();
    print('Logged in as: ${user['username']} (${user['display_name']})');
    
    // Get the public timeline
    print('\nFetching public timeline...');
    final publicTimeline = await mastodon.getPublicTimeline(limit: 5);
    print('Got ${publicTimeline.length} posts from the public timeline');
    
    if (publicTimeline.isEmpty) {
      print('No posts to interact with. Exiting...');
      return;
    }
    
    // Pick a post to interact with
    final postToInteractWith = publicTimeline.first;
    final postId = postToInteractWith['id'] as String;
    final postAuthor = (postToInteractWith['account'] as Map<String, dynamic>)['display_name'];
    final postContent = _stripHtml(postToInteractWith['content'] as String);
    
    print('\nSelected post:');
    print('ID: $postId');
    print('Author: $postAuthor');
    print('Content: ${postContent.substring(0, postContent.length > 50 ? 50 : postContent.length)}${postContent.length > 50 ? '...' : ''}');
    
    // COMMENTING OUT ACTUAL API CALLS TO PREVENT UNWANTED INTERACTIONS
    // Uncomment sections to test specific functionality
    
    // Example 1: Get a specific status
    print('\nFetching status details...');
    final status = await mastodon.getStatus(postId);
    print('Status fetched:');
    print('Favorites: ${status['favourites_count']}');
    print('Reblogs: ${status['reblogs_count']}');
    
    // Example 2: Favorite and unfavorite a status
    /*
    print('\nFavoriting the status...');
    final favorited = await mastodon.favoriteStatus(postId);
    print('Status favorited: ${favorited['favourited']}');
    
    await Future.delayed(const Duration(seconds: 2));
    
    print('Unfavoriting the status...');
    final unfavorited = await mastodon.unfavoriteStatus(postId);
    print('Status unfavorited: ${unfavorited['favourited']}');
    */
    
    // Example 3: Reblog and unreblog a status
    /*
    print('\nReblogging the status...');
    final reblogged = await mastodon.reblogStatus(postId);
    print('Status reblogged: ${reblogged['reblogged']}');
    
    await Future.delayed(const Duration(seconds: 2));
    
    print('Unreblogging the status...');
    final unreblogged = await mastodon.unreblogStatus(postId);
    print('Status unreblogged: ${unreblogged['reblogged']}');
    */
    
    // Example 4: Follow and unfollow a user
    // Get account ID from the status
    final accountId = (postToInteractWith['account'] as Map<String, dynamic>)['id'] as String;
    final accountUsername = (postToInteractWith['account'] as Map<String, dynamic>)['acct'] as String;
    
    print('\nFound account: $accountUsername (ID: $accountId)');
    
    /*
    print('Following the account...');
    final followResult = await mastodon.followAccount(accountId);
    print('Account followed: ${followResult['following']}');
    
    await Future.delayed(const Duration(seconds: 2));
    
    print('Unfollowing the account...');
    final unfollowResult = await mastodon.unfollowAccount(accountId);
    print('Account unfollowed: ${unfollowResult['following']}');
    */
    
    // Example 5: Get notifications
    print('\nFetching notifications...');
    final notifications = await mastodon.getNotifications(limit: 5);
    
    if (notifications.isEmpty) {
      print('No notifications found.');
    } else {
      print('Got ${notifications.length} notifications:');
      for (final notification in notifications) {
        final type = notification['type'] as String;
        final accountName = (notification['account'] as Map<String, dynamic>)['display_name'];
        
        print('- $type from $accountName');
      }
      
      // Get a single notification if available
      if (notifications.isNotEmpty) {
        final notificationId = notifications.first['id'] as String;
        print('\nFetching single notification (ID: $notificationId)...');
        final singleNotification = await mastodon.getNotification(notificationId);
        print('Notification type: ${singleNotification['type']}');
      }
    }
    
    // Example 6: Clear notifications (commented out to prevent clearing all notifications)
    /*
    print('\nClearing all notifications...');
    await mastodon.clearNotifications();
    print('All notifications cleared!');
    */
    
    // Clean up
    clientSetup.dispose();
    
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