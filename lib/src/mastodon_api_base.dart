/// This file contains base configuration and utilities for the Mastodon API library.
///
/// This library provides a streamlined way to interact with Mastodon instances,
/// handling authentication, API calls, and data management.

/// Library version
const String libraryVersion = '0.1.0';

/// Mastodon API version supported
const String apiVersion = 'v1';

/// Default scopes requested during OAuth authentication
const List<String> defaultScopes = ['read', 'write', 'follow'];

// TODO: Put public facing types in this file.

/// Checks if you are awesome. Spoiler: you are.
class Awesome {
  bool get isAwesome => true;
}
