import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:oauth2/oauth2.dart' as oauth2;
import 'package:meta/meta.dart';

import 'credential_storage.dart';

/// A class for handling Mastodon OAuth2 authentication.
class MastodonOAuth {
  final String instanceUrl;
  final String clientId;
  final String clientSecret;
  final String redirectUrl;
  final List<String> scopes;
  final http.Client? _httpClient;
  final CredentialStorage? _credentialStorage;
  
  // For PKCE
  String? _codeVerifier;

  // Time buffer before expiry to trigger refresh (default: 5 minutes)
  final Duration _expirationBuffer;
  
  // Custom certificate validation function
  final bool Function(X509Certificate cert, String host, int port)? _certificateValidator;
  
  /// Creates a new MastodonOAuth instance.
  ///
  /// [instanceUrl] - The URL of the Mastodon instance (e.g., "https://mastodon.social")
  /// [clientId] - The client ID obtained from the Mastodon instance
  /// [clientSecret] - The client secret obtained from the Mastodon instance
  /// [redirectUrl] - The redirect URL registered with the Mastodon instance
  /// [scopes] - The list of scopes required for your application
  /// [httpClient] - Optional HTTP client for requests (useful for testing)
  /// [credentialStorage] - Optional storage for persisting OAuth credentials
  /// [expirationBuffer] - Time before token expiry to trigger a refresh (default: 5 minutes)
  /// [certificateValidator] - Optional custom certificate validator function
  MastodonOAuth({
    required this.instanceUrl,
    required this.clientId,
    required this.clientSecret,
    required this.redirectUrl,
    this.scopes = const ['read', 'write', 'follow'],
    http.Client? httpClient,
    CredentialStorage? credentialStorage,
    Duration? expirationBuffer,
    bool Function(X509Certificate cert, String host, int port)? certificateValidator,
  }) : _httpClient = httpClient,
       _credentialStorage = credentialStorage,
       _expirationBuffer = expirationBuffer ?? const Duration(minutes: 5),
       _certificateValidator = certificateValidator;
  
  /// Checks if there are stored credentials available.
  Future<bool> hasStoredCredentials() async {
    if (_credentialStorage == null) {
      return false;
    }
    
    final credentials = await _credentialStorage.loadCredentials();
    return credentials != null;
  }
  
  /// Loads stored credentials and creates an OAuth2 client.
  /// 
  /// Returns null if no credentials are stored or if the stored credentials
  /// cannot be loaded.
  Future<oauth2.Client?> loadClientFromStorage() async {
    if (_credentialStorage == null) {
      return null;
    }
    
    final credentials = await _credentialStorage.loadCredentials();
    if (credentials == null) {
      return null;
    }

    // Check if token is expired or close to expiry
    if (credentials.expiration != null && 
        DateTime.now().isAfter(credentials.expiration!.subtract(_expirationBuffer))) {
      
      // Token is expired or about to expire, try to refresh
      if (credentials.refreshToken != null) {
        try {
          final refreshedCredentials = await _refreshToken(credentials);
          return createClientFromCredentials(refreshedCredentials);
        } catch (e) {
          // If refresh fails, clear credentials and return null
          await _credentialStorage.clearCredentials();
          return null;
        }
      } else {
        // No refresh token, clear credentials and return null
        await _credentialStorage.clearCredentials();
        return null;
      }
    }
    
    return createClientFromCredentials(credentials);
  }
  
  /// Clears any stored credentials.
  Future<void> logout() async {
    if (_credentialStorage != null) {
      await _credentialStorage.clearCredentials();
    }
  }
  
  /// Generates the authorization URL for the OAuth2 flow.
  ///
  /// This URL should be opened in a browser to start the OAuth2 flow.
  /// After authorization, the user will be redirected to the [redirectUrl].
  String getAuthorizationUrl() {
    final authorizationEndpoint = Uri.parse('$instanceUrl/oauth/authorize');
    
    // Generate code verifier and challenge for PKCE
    _codeVerifier = _generateCodeVerifier();
    final codeChallenge = _generateCodeChallenge(_codeVerifier!);
    
    // Base parameters for authorization request
    final params = {
      'response_type': 'code',
      'client_id': clientId,
      'redirect_uri': redirectUrl,
      'code_challenge': codeChallenge,
      'code_challenge_method': 'S256',
      'scope': scopes.join(' '),
    };
    
    // Build the URL with query parameters
    final queryString = params.entries
        .map((e) => '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}')
        .join('&');
    
    return '$authorizationEndpoint?$queryString';
  }

  /// Exchanges an authorization code for an access token.
  ///
  /// [code] - The authorization code received from the authorization server
  ///
  /// Returns a [Future] that completes with the OAuth2 client when the exchange is complete.
  Future<oauth2.Client> handleAuthorizationCode(String code) async {
    if (_codeVerifier == null) {
      throw Exception('Authorization URL has not been generated. Call getAuthorizationUrl() first.');
    }
    
    // Directly exchange the code for a token using a POST request
    final tokenEndpoint = Uri.parse('$instanceUrl/oauth/token');
    
    final client = _createSecureHttpClient();
    try {
      final response = await client.post(
        tokenEndpoint,
        body: {
          'client_id': clientId,
          'client_secret': clientSecret,
          'grant_type': 'authorization_code',
          'code': code,
          'redirect_uri': redirectUrl,
          'scope': scopes.join(' '),
          'code_verifier': _codeVerifier!,
        },
      );
      
      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        
        // Create OAuth2 credentials from the response data
        final credentials = oauth2.Credentials(
          data['access_token'] as String,
          refreshToken: data['refresh_token'] as String?,
          idToken: data['id_token'] as String?,
          tokenEndpoint: tokenEndpoint,
          scopes: data['scope'] != null
              ? (data['scope'] as String).split(' ')
              : scopes,
          expiration: data['expires_in'] != null
              ? DateTime.now().add(Duration(seconds: data['expires_in'] as int))
              : null,
        );
        
        // Store credentials if we have a credential storage
        if (_credentialStorage != null) {
          await _credentialStorage.saveCredentials(credentials);
        }
        
        // Create and return the OAuth2 client
        return createClientFromCredentials(credentials);
      } else {
        throw Exception(
          'Failed to exchange authorization code for token: ${response.statusCode} ${response.body}',
        );
      }
    } finally {
      // Only close the client if we created it
      if (_httpClient == null) {
        client.close();
      }
    }
  }
  
  /// Creates a client from saved credentials.
  ///
  /// [credentials] - The saved OAuth2 credentials
  ///
  /// Returns an OAuth2 client that can be used to make authenticated requests.
  oauth2.Client createClientFromCredentials(oauth2.Credentials credentials) {
    return oauth2.Client(
      credentials,
      identifier: clientId,
      secret: clientSecret,
      httpClient: _createSecureHttpClient(),
      onCredentialsRefreshed: _onCredentialsRefreshed,
    );
  }
  
  /// Creates a secure HTTP client with proper certificate validation
  http.Client _createSecureHttpClient() {
    if (_httpClient != null) {
      return _httpClient!;
    }
    
    // In a real application, this would use a more sophisticated approach
    // such as certificate pinning or a custom TLS configuration
    if (_certificateValidator != null) {
      HttpClient httpClient = HttpClient()
        ..badCertificateCallback = _certificateValidator;
      
      return _IOClientWithCustomValidation(httpClient);
    }
    
    return http.Client();
  }
  
  /// Refreshes an OAuth token
  Future<oauth2.Credentials> _refreshToken(oauth2.Credentials credentials) async {
    if (credentials.refreshToken == null) {
      throw Exception('Cannot refresh token: No refresh token available');
    }
    
    final tokenEndpoint = Uri.parse('$instanceUrl/oauth/token');
    final client = _createSecureHttpClient();
    
    try {
      final response = await client.post(
        tokenEndpoint,
        body: {
          'client_id': clientId,
          'client_secret': clientSecret,
          'grant_type': 'refresh_token',
          'refresh_token': credentials.refreshToken!,
          'scope': scopes.join(' '),
        },
      );
      
      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        
        // Create OAuth2 credentials from the response data
        final refreshedCredentials = oauth2.Credentials(
          data['access_token'] as String,
          refreshToken: data['refresh_token'] as String? ?? credentials.refreshToken,
          tokenEndpoint: tokenEndpoint,
          scopes: data['scope'] != null
              ? (data['scope'] as String).split(' ')
              : credentials.scopes,
          expiration: data['expires_in'] != null
              ? DateTime.now().add(Duration(seconds: data['expires_in'] as int))
              : null,
        );
        
        // Store credentials if we have a credential storage
        if (_credentialStorage != null) {
          await _credentialStorage.saveCredentials(refreshedCredentials);
        }
        
        return refreshedCredentials;
      } else {
        throw Exception(
          'Failed to refresh token: ${response.statusCode} ${response.body}',
        );
      }
    } finally {
      // Only close the client if we created it
      if (_httpClient == null) {
        client.close();
      }
    }
  }
  
  /// Called when credentials are refreshed.
  ///
  /// Override this method to save the refreshed credentials for later use.
  void _onCredentialsRefreshed(oauth2.Credentials credentials) {
    // Save refreshed credentials to storage if available
    _credentialStorage?.saveCredentials(credentials);
  }
  
  /// Exposes the onCredentialsRefreshed functionality for testing.
  /// This should only be used in tests.
  @visibleForTesting
  void callOnCredentialsRefreshed(oauth2.Credentials credentials) {
    _onCredentialsRefreshed(credentials);
  }
  
  /// Generates a random code verifier for PKCE.
  String _generateCodeVerifier() {
    final random = Random.secure();
    final codeVerifierBytes = List<int>.generate(96, (_) => random.nextInt(256));
    return base64Url.encode(codeVerifierBytes)
        .replaceAll('+', '-')
        .replaceAll('/', '_')
        .replaceAll('=', '')
        .substring(0, 128);
  }
  
  /// Generates a code challenge from the code verifier using SHA-256.
  String _generateCodeChallenge(String codeVerifier) {
    final bytes = utf8.encode(codeVerifier);
    final digest = sha256.convert(bytes);
    return base64Url.encode(digest.bytes)
        .replaceAll('+', '-')
        .replaceAll('/', '_')
        .replaceAll('=', '');
  }
  
  /// Registers a new application with the Mastodon instance.
  ///
  /// [instanceUrl] - The URL of the Mastodon instance
  /// [applicationName] - The name of your application
  /// [website] - The website of your application (optional)
  /// [redirectUris] - A list of redirect URIs (defaults to ['urn:ietf:wg:oauth:2.0:oob'])
  /// [scopes] - The list of scopes to request
  /// [httpClient] - Optional HTTP client for requests (useful for testing)
  /// [certificateValidator] - Optional custom certificate validator function
  ///
  /// Returns a [Future] that completes with the client ID and client secret.
  static Future<Map<String, String>> registerApplication({
    required String instanceUrl,
    required String applicationName,
    String? website,
    List<String> redirectUris = const ['urn:ietf:wg:oauth:2.0:oob'],
    List<String> scopes = const ['read', 'write', 'follow'],
    http.Client? httpClient,
    bool Function(X509Certificate cert, String host, int port)? certificateValidator,
  }) async {
    final client = httpClient ?? _createStaticSecureHttpClient(certificateValidator);
    try {
      final response = await client.post(
        Uri.parse('$instanceUrl/api/v1/apps'),
        body: {
          'client_name': applicationName,
          'redirect_uris': redirectUris.join('\n'),
          'scopes': scopes.join(' '),
          if (website != null) 'website': website,
        },
      );
      
      if (response.statusCode == 200) {
        // Parse response body to JSON
        final Map<String, dynamic> data = _parseResponseBody(response.body);
        
        return {
          'client_id': data['client_id'] as String,
          'client_secret': data['client_secret'] as String,
        };
      } else {
        throw Exception(
          'Failed to register application: ${response.statusCode} ${response.body}',
        );
      }
    } finally {
      // Only close the client if we created it
      if (httpClient == null) {
        client.close();
      }
    }
  }
  
  /// Creates a secure HTTP client with proper certificate validation for static methods
  static http.Client _createStaticSecureHttpClient(
    bool Function(X509Certificate cert, String host, int port)? certificateValidator
  ) {
    // In a real application, this would use a more sophisticated approach
    // such as certificate pinning or a custom TLS configuration
    if (certificateValidator != null) {
      HttpClient httpClient = HttpClient()
        ..badCertificateCallback = certificateValidator;
      
      return _IOClientWithCustomValidation(httpClient);
    }
    
    return http.Client();
  }
  
  /// Helper method to parse the response body from the server.
  ///
  /// Handles both JSON and form-encoded responses from different Mastodon instances.
  static Map<String, dynamic> _parseResponseBody(String body) {
    try {
      // First try to parse as JSON
      return jsonDecode(body) as Map<String, dynamic>;
    } catch (e) {
      // If that fails, try to parse as form data
      return Uri.splitQueryString(body);
    }
  }
}

/// A custom HTTP client that wraps an [HttpClient] with custom certificate validation
class _IOClientWithCustomValidation extends http.BaseClient {
  final HttpClient _httpClient;
  
  _IOClientWithCustomValidation(this._httpClient);
  
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final ioRequest = await _httpClient.openUrl(
      request.method,
      request.url,
    );
    
    // Copy headers from the request
    request.headers.forEach((name, value) {
      ioRequest.headers.set(name, value);
    });
    
    // Add content-length if available
    if (request is http.Request) {
      final bodyBytes = request.bodyBytes;
      ioRequest.contentLength = bodyBytes.length;
      ioRequest.add(bodyBytes);
    } else if (request is http.MultipartRequest) {
      // For multipart requests, we need to manually construct the body
      throw UnsupportedError(
        'Multipart requests are not supported with custom certificate validation',
      );
    }
    
    final response = await ioRequest.close();
    
    // Convert HttpHeaders to Map<String, String>
    final headers = <String, String>{};
    response.headers.forEach((name, values) {
      headers[name] = values.join(',');
    });
    
    // Convert the HttpClientResponse to a StreamedResponse
    final streamedResponse = http.StreamedResponse(
      response.handleError((error) {
        throw http.ClientException('Network error: $error', request.url);
      }),
      response.statusCode,
      contentLength: response.contentLength == -1 ? null : response.contentLength,
      request: request,
      headers: headers,
      reasonPhrase: response.reasonPhrase,
      isRedirect: response.isRedirect,
      persistentConnection: response.persistentConnection,
    );
    
    return streamedResponse;
  }
  
  @override
  void close() {
    _httpClient.close();
    super.close();
  }
} 