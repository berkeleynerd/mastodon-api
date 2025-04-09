/// A Dart library for interacting with the Mastodon API.
///
/// This library provides tools for authenticating with Mastodon instances,
/// making API requests, and integrating with Mastodon applications.
library mastodon_api;

export 'src/mastodon_api_base.dart';
export 'src/auth/mastodon_oauth.dart';
export 'src/auth/credential_storage.dart';
export 'src/auth/auth_manager.dart';
export 'src/api/mastodon_client.dart';
export 'src/api/api_service.dart';
export 'src/api/mastodon_api_factory.dart';

// TODO: Export any additional libraries intended for clients of this package.
