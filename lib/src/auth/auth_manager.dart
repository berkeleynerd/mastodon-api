import 'dart:async';

import 'package:http/http.dart' as http;
import 'package:meta/meta.dart';
import 'package:oauth2/oauth2.dart' as oauth2;

import 'credential_storage.dart';
import 'mastodon_oauth.dart';

/// Enum representing the current authentication state
enum AuthState {
  /// Initial state, not yet determined
  initializing,

  /// User is not authenticated
  unauthenticated,

  /// User is fully authenticated with valid credentials
  authenticated,

  /// Authentication in progress
  authenticating,

  /// Error state, authentication failed
  error,
}

/// Authentication error types
enum AuthErrorType {
  /// Generic error, not specified
  unknown,

  /// Network error occurred
  network,

  /// Authentication credentials invalid or expired
  invalidCredentials,

  /// Refresh token is invalid
  refreshFailed,

  /// User cancelled authentication
  userCancelled,
}

/// Detailed auth error information
class AuthError {
  /// The type of error that occurred
  final AuthErrorType type;

  /// Detailed error message
  final String message;

  /// Original exception that caused the error, if any
  final Object? exception;

  /// Creates a new auth error
  const AuthError({
    required this.type,
    required this.message,
    this.exception,
  });

  @override
  String toString() => 'AuthError($type): $message';
}

/// Manages authentication state and operations for Mastodon API access
class AuthManager {
  /// The underlying OAuth implementation
  final MastodonOAuth _oauth;

  /// Current authenticated client, if any
  oauth2.Client? _client;

  /// Current authentication state
  AuthState _state = AuthState.initializing;

  /// Current authentication error, if any
  AuthError? _error;

  /// Stream controller for auth state changes
  final _stateController = StreamController<AuthState>.broadcast();

  /// Creates a new AuthManager
  ///
  /// [oauth] is the MastodonOAuth instance to use for authentication operations.
  AuthManager({
    required MastodonOAuth oauth,
  }) : _oauth = oauth {
    // Start in initializing state and emit initial state
    _updateState(AuthState.initializing);
  }

  /// Stream of authentication state changes
  Stream<AuthState> get onStateChanged => _stateController.stream;

  /// The current authentication state
  AuthState get state => _state;

  /// The current authentication error, if any
  AuthError? get error => _error;

  /// Whether the user is currently authenticated
  bool get isAuthenticated => _state == AuthState.authenticated;

  /// The current authenticated client, if any
  oauth2.Client? get client => _client;

  /// Initializes the auth manager
  ///
  /// Checks for existing credentials and initializes the state accordingly.
  Future<void> initialize() async {
    _updateState(AuthState.initializing);

    try {
      final hasCredentials = await _oauth.hasStoredCredentials();

      if (!hasCredentials) {
        _updateState(AuthState.unauthenticated);
        return;
      }

      final client = await _oauth.loadClientFromStorage();

      if (client == null) {
        _updateState(AuthState.unauthenticated);
        return;
      }

      _client = client;
      _updateState(AuthState.authenticated);
    } catch (e) {
      _handleError(
        AuthErrorType.unknown,
        'Failed to initialize authentication: ${e.toString()}',
        e,
      );
      _updateState(AuthState.unauthenticated);
    }
  }

  /// Begins the authentication process
  ///
  /// Returns the authorization URL that should be opened in a browser.
  String startAuthentication() {
    _updateState(AuthState.authenticating);
    return _oauth.getAuthorizationUrl();
  }

  /// Completes the authentication process
  ///
  /// [code] is the authorization code received from the authorization server.
  Future<void> handleAuthorizationCode(String code) async {
    _updateState(AuthState.authenticating);

    try {
      _client = await _oauth.handleAuthorizationCode(code);
      _updateState(AuthState.authenticated);
    } catch (e) {
      _error = AuthError(
        type: AuthErrorType.invalidCredentials,
        message: 'Failed to exchange authorization code: ${e.toString()}',
        exception: e,
      );
      _updateState(AuthState.error);
      _updateState(AuthState.unauthenticated);
    }
  }

  /// Logs the user out
  ///
  /// Clears all stored credentials and resets the authentication state.
  Future<void> logout() async {
    try {
      await _oauth.logout();
      _client?.close();
      _client = null;
      _updateState(AuthState.unauthenticated);
    } catch (e) {
      _handleError(
        AuthErrorType.unknown,
        'Error during logout: ${e.toString()}',
        e,
      );
      // Still set to unauthenticated even if there was an error
      _updateState(AuthState.unauthenticated);
    }
  }

  /// Creates a new HTTP client with authentication headers
  ///
  /// Returns an authenticated HTTP client that can be used to make requests.
  /// If not authenticated, returns a regular HTTP client.
  http.Client createHttpClient() {
    return _client ?? http.Client();
  }

  /// Updates the authentication state and notifies listeners
  void _updateState(AuthState newState) {
    final oldState = _state;
    _state = newState;
    
    // Reset error when entering authenticated or unauthenticated state
    if (newState == AuthState.authenticated || 
        newState == AuthState.unauthenticated) {
      _error = null;
    }
    
    // Always emit the state change, even if it's the same state
    // This is important for tests and for clients that need to know
    // when state transitions occur, even if the end state is the same
    _stateController.add(newState);
  }

  /// Handles an authentication error
  void _handleError(AuthErrorType type, String message, [Object? exception]) {
    _error = AuthError(
      type: type,
      message: message,
      exception: exception,
    );
    
    // Emit error state
    _updateState(AuthState.error);
  }

  /// Disposes resources used by the auth manager
  void dispose() {
    _stateController.close();
    _client?.close();
  }
  
  /// Sets the error for testing purposes only.
  /// This method should not be used in production code.
  @visibleForTesting
  void setErrorForTesting(AuthError error) {
    _error = error;
  }
  
  /// Sets the state for testing purposes only.
  /// This method should not be used in production code.
  @visibleForTesting
  void setStateForTesting(AuthState state) {
    _updateState(state);
  }
} 