import 'dart:convert';
import 'dart:io';

import 'package:mastodon_api/mastodon_api.dart';
import 'package:oauth2/oauth2.dart' as oauth2;

Future<void> main() async {
  // Configuration
  const instanceUrl = 'https://social.vivaldi.net'; // Using Vivaldi's Mastodon instance
  const applicationName = 'Mastodon API Example';
  
  // The redirect URL should be registered with your application
  const redirectUrl = 'http://localhost:8080/callback';
  
  print('Mastodon OAuth Example');
  print('======================');
  
  try {
    // Step 1: Register the application with the Mastodon instance
    print('\nRegistering application with $instanceUrl...');
    final registration = await MastodonOAuth.registerApplication(
      instanceUrl: instanceUrl,
      applicationName: applicationName,
      redirectUris: [redirectUrl],
      scopes: ['read', 'write', 'follow'],
    );
    
    final clientId = registration['client_id']!;
    final clientSecret = registration['client_secret']!;
    
    print('Application registered successfully!');
    print('Client ID: $clientId');
    print('Client Secret: $clientSecret');
    
    // Step 2: Initialize the OAuth client
    final oauth = MastodonOAuth(
      instanceUrl: instanceUrl,
      clientId: clientId,
      clientSecret: clientSecret,
      redirectUrl: redirectUrl,
    );
    
    // Step 3: Get the authorization URL
    final authUrl = oauth.getAuthorizationUrl();
    print('\nOpen this URL in your browser to authorize the application:');
    print(authUrl);
    
    // Step 4: Prompt the user to enter the authorization code
    stdout.write('\nOnce authorized, enter the authorization code: ');
    final code = stdin.readLineSync();
    
    if (code == null || code.isEmpty) {
      print('No authorization code provided. Exiting...');
      return;
    }
    
    // Step 5: Exchange the authorization code for an access token
    final client = await oauth.handleAuthorizationCode(code);
    
    print('\nAuthentication successful!');
    print('Access Token: ${client.credentials.accessToken}');
    
    // Save credentials for later use (in a real app, securely store these)
    final credentialsJson = client.credentials.toJson();
    final file = File('credentials.json');
    await file.writeAsString(jsonEncode(credentialsJson));
    print('\nCredentials saved to credentials.json');
    
    // Step 6: Make an API request to verify the credentials
    print('\nVerifying credentials...');
    final response = await client.get(
      Uri.parse('$instanceUrl/api/v1/accounts/verify_credentials'),
    );
    
    if (response.statusCode == 200) {
      final accountData = jsonDecode(response.body);
      print('Authenticated as: ${accountData['username']}');
      print('Display name: ${accountData['display_name']}');
    } else {
      print('Failed to verify credentials: ${response.statusCode} ${response.body}');
    }
    
  } catch (e) {
    print('\nError: $e');
  }
} 