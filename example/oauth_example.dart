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
    
    // Step 2: Create in-memory credential storage
    final credentialStorage = InMemoryCredentialStorage();
    
    // Step 3: Create client setup using the factory
    final clientSetup = await MastodonApiFactory.createClient(
      instanceUrl: instanceUrl,
      clientId: clientId,
      clientSecret: clientSecret,
      redirectUri: redirectUrl,
      credentialStorage: credentialStorage,
    );
    
    // Step 4: Get the authorization URL
    final authUrl = clientSetup.startAuthentication();
    print('\nOpen this URL in your browser to authorize the application:');
    print(authUrl);
    
    // Step 5: Prompt the user to enter the authorization code
    stdout.write('\nOnce authorized, enter the authorization code: ');
    final code = stdin.readLineSync();
    
    if (code == null || code.isEmpty) {
      print('No authorization code provided. Exiting...');
      return;
    }
    
    // Step 6: Exchange the authorization code for an access token
    await clientSetup.handleAuthorizationCode(code);
    
    if (!clientSetup.isAuthenticated) {
      print('\nAuthentication failed.');
      return;
    }
    
    // Get credentials from the storage
    final credentials = await credentialStorage.loadCredentials();
    
    if (credentials == null) {
      print('\nFailed to get credentials after authentication.');
      return;
    }
    
    print('\nAuthentication successful!');
    print('Access Token: ${credentials.accessToken}');
    
    // Create a standard config file with all necessary information
    final config = {
      'instance_url': instanceUrl,
      'client_id': clientId,
      'client_secret': clientSecret,
      'redirect_url': redirectUrl,
      'access_token': credentials.accessToken,
    };
    
    // Save config for use across examples
    final configFile = File('mastodon_config.json');
    final encoder = JsonEncoder.withIndent('  ');
    await configFile.writeAsString(encoder.convert(config));
    print('\nConfig saved to mastodon_config.json');
    
    // Step 7: Use the client to verify credentials
    final mastodonClient = clientSetup.client;
    
    print('\nVerifying credentials...');
    try {
      final accountData = await mastodonClient.verifyCredentials();
      print('Authenticated as: ${accountData['username']}');
      print('Display name: ${accountData['display_name']}');
    } catch (e) {
      print('Failed to verify credentials: $e');
    }
    
    // Clean up
    clientSetup.dispose();
  } catch (e) {
    print('\nError: $e');
  }
} 