import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../auth/auth_manager.dart';

/// Types of API errors that can occur
enum ApiErrorType {
  /// Network error (no connection, timeout, etc.)
  network,
  
  /// Authentication error (invalid or expired credentials)
  authentication,
  
  /// Server error (500 status codes)
  server,
  
  /// Client error (400 status codes, excluding auth errors)
  client,
  
  /// Unknown error
  unknown,
}

/// Represents an API error
class ApiError {
  /// Type of API error
  final ApiErrorType type;
  
  /// HTTP status code, if available
  final int? statusCode;
  
  /// Error message
  final String message;
  
  /// Original exception that caused this error
  final Object? exception;
  
  /// Raw response data, if available
  final dynamic data;
  
  /// Creates an API error
  ApiError({
    required this.type,
    this.statusCode,
    required this.message,
    this.exception,
    this.data,
  });
  
  @override
  String toString() => 'ApiError($type${statusCode != null ? ', $statusCode' : ''}): $message';
}

/// Signature for a function that performs an API request
typedef ApiRequest<T> = Future<T> Function(http.Client client);

/// Service for making authenticated API requests
class ApiService {
  /// The auth manager for handling authentication
  final AuthManager _authManager;
  
  /// Base URL of the Mastodon instance
  final String _instanceUrl;
  
  /// Function to create HTTP clients
  final http.Client Function()? _httpClientFactory;
  
  /// Creates a new API service
  ///
  /// [authManager] - The auth manager for handling authentication
  /// [instanceUrl] - Base URL of the Mastodon instance
  /// [httpClientFactory] - Optional factory function for creating HTTP clients
  ApiService({
    required AuthManager authManager,
    required String instanceUrl,
    http.Client Function()? httpClientFactory,
  })  : _authManager = authManager,
        _instanceUrl = instanceUrl,
        _httpClientFactory = httpClientFactory;
  
  /// The base URL of the Mastodon instance
  String get instanceUrl => _instanceUrl;
  
  /// Executes an authenticated API request with error handling
  ///
  /// [request] - Function that performs the actual request
  /// [requireAuth] - Whether authentication is required (default: true)
  /// [retryOnAuthError] - Whether to retry on authentication errors (default: true)
  Future<T> execute<T>(
    ApiRequest<T> request, {
    bool requireAuth = true,
    bool retryOnAuthError = true,
  }) async {
    if (requireAuth && !_authManager.isAuthenticated) {
      throw ApiError(
        type: ApiErrorType.authentication,
        message: 'Authentication required',
      );
    }
    
    try {
      // Get an authenticated client or create a new one
      http.Client client;
      
      if (_authManager.isAuthenticated) {
        // Use the authenticated client from AuthManager
        client = _authManager.createHttpClient();
      } else if (_httpClientFactory != null) {
        // Use the client factory if available
        client = _httpClientFactory!();
      } else {
        // Create a new HTTP client as a fallback
        client = http.Client();
      }
      
      try {
        // Execute the request
        return await request(client);
      } on http.ClientException catch (e) {
        // Handle network errors
        throw ApiError(
          type: ApiErrorType.network,
          message: 'Network error: ${e.message}',
          exception: e,
        );
      } catch (e) {
        // Re-throw API errors, convert other exceptions
        if (e is ApiError) {
          // If it's an auth error and we should retry, attempt to re-authenticate
          if (e.type == ApiErrorType.authentication && retryOnAuthError) {
            // For now, just throw the error
            // In a future implementation, we could attempt to refresh the token
            throw e;
          }
          throw e;
        }
        
        throw ApiError(
          type: ApiErrorType.unknown,
          message: 'Unknown error: ${e.toString()}',
          exception: e,
        );
      } finally {
        // Only close the client if it's not from AuthManager and not from our factory
        bool shouldCloseClient = !_authManager.isAuthenticated && _httpClientFactory == null;
        if (shouldCloseClient) {
          client.close();
        }
      }
    } catch (e) {
      // Convert any remaining exceptions to ApiError
      if (e is ApiError) {
        throw e;
      }
      
      throw ApiError(
        type: ApiErrorType.unknown,
        message: 'Unknown error: ${e.toString()}',
        exception: e,
      );
    }
  }
  
  /// Checks an HTTP response and throws an appropriate ApiError if needed
  ///
  /// [response] - The HTTP response to check
  /// [throwOnError] - Whether to throw an exception on error (default: true)
  /// Returns true if the response is successful, false otherwise
  bool checkResponse(http.Response response, {bool throwOnError = true}) {
    // Success case
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return true;
    }
    
    // Handle different types of errors
    ApiErrorType errorType;
    String message;
    dynamic data;
    
    // Try to parse error data from response
    try {
      data = jsonDecode(response.body);
      message = (data is Map && data['error'] != null) 
          ? data['error'].toString() 
          : response.reasonPhrase ?? 'Unknown error';
    } catch (_) {
      // If we can't parse JSON, use raw response
      data = response.body;
      message = response.reasonPhrase ?? 'Unknown error';
    }
    
    // Determine error type based on status code
    if (response.statusCode == 401 || response.statusCode == 403) {
      errorType = ApiErrorType.authentication;
    } else if (response.statusCode >= 500) {
      errorType = ApiErrorType.server;
    } else if (response.statusCode >= 400) {
      errorType = ApiErrorType.client;
    } else {
      errorType = ApiErrorType.unknown;
    }
    
    // Build error object
    final error = ApiError(
      type: errorType,
      statusCode: response.statusCode,
      message: message,
      data: data,
    );
    
    // Throw or return based on throwOnError
    if (throwOnError) {
      throw error;
    }
    
    return false;
  }
} 