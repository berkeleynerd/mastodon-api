import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:oauth2/oauth2.dart' as oauth2;

/// A client for interacting with the Mastodon API.
class MastodonClient {
  /// The base URL of the Mastodon instance.
  final String instanceUrl;
  
  /// The OAuth2 client used for authenticated requests.
  final oauth2.Client client;
  
  /// Creates a new Mastodon API client.
  ///
  /// [instanceUrl] - The base URL of the Mastodon instance.
  /// [client] - The OAuth2 client used for authenticated requests.
  MastodonClient({
    required this.instanceUrl,
    required this.client,
  });
  
  /// Verifies the user's credentials and returns the user's account information.
  Future<Map<String, dynamic>> verifyCredentials() async {
    final response = await client.get(
      Uri.parse('$instanceUrl/api/v1/accounts/verify_credentials'),
    );
    
    _checkResponse(response);
    
    return jsonDecode(response.body) as Map<String, dynamic>;
  }
  
  /// Fetches the public timeline.
  ///
  /// [limit] - The maximum number of posts to return (default: 20).
  /// [onlyLocal] - Whether to only return posts from the local instance (default: false).
  Future<List<Map<String, dynamic>>> getPublicTimeline({
    int limit = 20,
    bool onlyLocal = false,
  }) async {
    final queryParams = <String, String>{
      'limit': limit.toString(),
    };
    
    if (onlyLocal) {
      queryParams['local'] = 'true';
    }
    
    final uri = Uri.parse('$instanceUrl/api/v1/timelines/public')
        .replace(queryParameters: queryParams);
    
    final response = await client.get(uri);
    
    _checkResponse(response);
    
    return (jsonDecode(response.body) as List)
        .cast<Map<String, dynamic>>();
  }
  
  /// Fetches the home timeline (posts from followed users).
  ///
  /// [limit] - The maximum number of posts to return (default: 20).
  Future<List<Map<String, dynamic>>> getHomeTimeline({int limit = 20}) async {
    final uri = Uri.parse('$instanceUrl/api/v1/timelines/home')
        .replace(queryParameters: {'limit': limit.toString()});
    
    final response = await client.get(uri);
    
    _checkResponse(response);
    
    return (jsonDecode(response.body) as List)
        .cast<Map<String, dynamic>>();
  }
  
  /// Posts a new status (toot) to the user's timeline.
  ///
  /// [status] - The text content of the status.
  /// [visibility] - The visibility level of the status (public, unlisted, private, direct).
  /// [spoilerText] - Optional text to be shown as a spoiler warning.
  /// [inReplyToId] - ID of the status being replied to.
  Future<Map<String, dynamic>> postStatus({
    required String status,
    String visibility = 'public',
    String? spoilerText,
    String? inReplyToId,
  }) async {
    final body = <String, String>{
      'status': status,
      'visibility': visibility,
    };
    
    if (spoilerText != null) {
      body['spoiler_text'] = spoilerText;
    }
    
    if (inReplyToId != null) {
      body['in_reply_to_id'] = inReplyToId;
    }
    
    final response = await client.post(
      Uri.parse('$instanceUrl/api/v1/statuses'),
      body: body,
    );
    
    _checkResponse(response);
    
    return jsonDecode(response.body) as Map<String, dynamic>;
  }
  
  /// Fetches information about a user.
  ///
  /// [accountId] - The ID of the account to fetch.
  Future<Map<String, dynamic>> getAccount(String accountId) async {
    final response = await client.get(
      Uri.parse('$instanceUrl/api/v1/accounts/$accountId'),
    );
    
    _checkResponse(response);
    
    return jsonDecode(response.body) as Map<String, dynamic>;
  }
  
  /// Searches for content.
  ///
  /// [query] - The search query.
  /// [type] - The type of content to search for (accounts, hashtags, statuses).
  /// [limit] - The maximum number of results to return (default: 20).
  Future<Map<String, dynamic>> search({
    required String query,
    String? type,
    int limit = 20,
  }) async {
    final queryParams = <String, String>{
      'q': query,
      'limit': limit.toString(),
    };
    
    if (type != null) {
      queryParams['type'] = type;
    }
    
    final uri = Uri.parse('$instanceUrl/api/v2/search')
        .replace(queryParameters: queryParams);
    
    final response = await client.get(uri);
    
    _checkResponse(response);
    
    return jsonDecode(response.body) as Map<String, dynamic>;
  }
  
  /// Fetches the instance information.
  Future<Map<String, dynamic>> getInstance() async {
    final response = await client.get(
      Uri.parse('$instanceUrl/api/v1/instance'),
    );
    
    _checkResponse(response);
    
    return jsonDecode(response.body) as Map<String, dynamic>;
  }
  
  /// Helper method to check API responses and throw appropriate exceptions.
  void _checkResponse(http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return;
    }
    
    Map<String, dynamic>? errorData;
    try {
      errorData = jsonDecode(response.body) as Map<String, dynamic>;
    } catch (_) {
      // If we can't parse the error as JSON, just use the raw body
      throw MastodonApiException(
        response.statusCode,
        response.reasonPhrase ?? 'Unknown error',
        response.body,
      );
    }
    
    throw MastodonApiException(
      response.statusCode,
      errorData['error'] as String? ?? response.reasonPhrase ?? 'Unknown error',
      errorData,
    );
  }
}

/// Exception thrown when a Mastodon API request fails.
class MastodonApiException implements Exception {
  /// The HTTP status code of the response.
  final int statusCode;
  
  /// The error message.
  final String message;
  
  /// The full error data.
  final dynamic data;
  
  MastodonApiException(this.statusCode, this.message, this.data);
  
  @override
  String toString() {
    return 'MastodonApiException: $statusCode - $message';
  }
} 