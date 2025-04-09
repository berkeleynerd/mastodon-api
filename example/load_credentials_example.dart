import 'dart:convert';
import 'dart:io';

import 'package:mastodon_api/mastodon_api.dart';
import 'package:oauth2/oauth2.dart' as oauth2;

Future<void> main() async {
  // Configuration - use the values from your successful authorization
  print('Loading Credentials Example');
  print('==========================');
  
  try {
    // Load saved config
    final file = File('mastodon_config.json');
    
    if (!await file.exists()) {
      print('No mastodon_config.json file found. Please run oauth_example.dart first.');
      return;
    }
    
    final json = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
    
    final instanceUrl = json['instance_url'] as String;
    final clientId = json['client_id'] as String;
    final clientSecret = json['client_secret'] as String;
    final redirectUrl = json['redirect_url'] as String;
    final accessToken = json['access_token'] as String;
    
    print('Loaded configuration for $instanceUrl');
    print('Access Token: $accessToken');
    
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
    
    // Create HTTP client from credentials
    final client = oauth.createClientFromCredentials(credentials);
    
    // Make a test API request to verify credentials
    print('\nVerifying credentials...');
    final response = await client.get(
      Uri.parse('$instanceUrl/api/v1/accounts/verify_credentials'),
    );
    
    if (response.statusCode == 200) {
      final accountData = jsonDecode(response.body);
      print('Authentication successful!');
      print('Authenticated as: ${accountData['username']}');
      print('Display name: ${accountData['display_name']}');
      
      // Make another API request to show public timeline
      print('\nFetching public timeline...');
      final timelineResponse = await client.get(
        Uri.parse('$instanceUrl/api/v1/timelines/public?limit=2'),
      );
      
      if (timelineResponse.statusCode == 200) {
        final timeline = jsonDecode(timelineResponse.body) as List;
        print('Successfully fetched ${timeline.length} posts from the public timeline:');
        
        for (final post in timeline) {
          final content = post['content'] as String;
          final account = post['account'] as Map<String, dynamic>;
          final displayName = account['display_name'] as String? ?? account['username'];
          
          print('\n• $displayName posted:');
          print('  ${_stripHtml(content).substring(0, _stripHtml(content).length > 100 ? 100 : _stripHtml(content).length)}${_stripHtml(content).length > 100 ? '...' : ''}');
        }
      } else {
        print('Failed to fetch timeline: ${timelineResponse.statusCode} ${timelineResponse.body}');
      }
    } else if (response.statusCode == 401) {
      print('Authentication failed: Credentials may be expired');
      print('Error details: ${response.body}');
      print('\nPlease run oauth_example.dart to get new credentials.');
    } else {
      print('Failed to verify credentials: ${response.statusCode} ${response.body}');
    }
  } catch (e, stackTrace) {
    print('\nError: $e');
    print('Stack trace: $stackTrace');
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