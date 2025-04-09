import '../auth/auth_manager.dart';
import '../auth/credential_storage.dart';
import '../auth/mastodon_oauth.dart';
import 'api_service.dart';
import 'mastodon_client.dart';

/// Factory class for creating a fully configured Mastodon API client
class MastodonApiFactory {
  /// Creates a new Mastodon API client with all required dependencies
  ///
  /// [instanceUrl] - The URL of the Mastodon instance to connect to
  /// [clientId] - OAuth client ID for the application
  /// [clientSecret] - OAuth client secret for the application
  /// [redirectUri] - OAuth redirect URI for the application
  /// [credentialStorage] - Storage for persisting OAuth credentials (optional)
  static Future<MastodonClientSetup> createClient({
    required String instanceUrl,
    required String clientId,
    required String clientSecret,
    required String redirectUri,
    CredentialStorage? credentialStorage,
  }) async {
    // Create the OAuth client
    final oauth = MastodonOAuth(
      instanceUrl: instanceUrl,
      clientId: clientId,
      clientSecret: clientSecret,
      redirectUrl: redirectUri,
      credentialStorage: credentialStorage,
    );
    
    // Create the auth manager
    final authManager = AuthManager(oauth: oauth);
    
    // Initialize the auth manager to load saved credentials if available
    await authManager.initialize();
    
    // Create the API service
    final apiService = ApiService(
      authManager: authManager,
      instanceUrl: instanceUrl,
    );
    
    // Create the Mastodon client
    final client = MastodonClient(apiService: apiService);
    
    // Return the setup with both client and auth manager
    return MastodonClientSetup(
      client: client,
      authManager: authManager,
    );
  }
}

/// Holds the Mastodon client and auth manager for easy access
class MastodonClientSetup {
  /// The Mastodon API client
  final MastodonClient client;
  
  /// The authentication manager
  final AuthManager authManager;
  
  /// Creates a new Mastodon client setup
  MastodonClientSetup({
    required this.client,
    required this.authManager,
  });
  
  /// Whether the client is currently authenticated
  bool get isAuthenticated => authManager.isAuthenticated;
  
  /// The current authentication state
  AuthState get authState => authManager.state;
  
  /// Stream of authentication state changes
  Stream<AuthState> get onAuthStateChanged => authManager.onStateChanged;
  
  /// Begins the authentication process
  ///
  /// Returns the authorization URL that should be opened in a browser
  String startAuthentication() {
    return authManager.startAuthentication();
  }
  
  /// Completes the authentication process with a code received from the OAuth redirect
  ///
  /// [code] is the authorization code received from the redirect
  Future<void> handleAuthorizationCode(String code) {
    return authManager.handleAuthorizationCode(code);
  }
  
  /// Logs out the current user and clears credentials
  Future<void> logout() {
    return authManager.logout();
  }
  
  /// Releases resources used by the client setup
  void dispose() {
    authManager.dispose();
  }
} 