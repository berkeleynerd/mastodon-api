import 'dart:convert';

import 'package:http/http.dart' as http;

import 'api_service.dart';

/// A client for interacting with the Mastodon API.
class MastodonClient {
  /// The API service used for making authenticated requests
  final ApiService _apiService;
  
  /// Creates a new Mastodon API client.
  ///
  /// [apiService] - The API service used for making authenticated requests.
  MastodonClient({
    required ApiService apiService,
  }) : _apiService = apiService;
  
  /// The base URL of the Mastodon instance.
  String get instanceUrl => _apiService.instanceUrl;
  
  /// Verifies the user's credentials and returns the user's account information.
  Future<Map<String, dynamic>> verifyCredentials() async {
    return _apiService.execute<Map<String, dynamic>>((client) async {
      final response = await client.get(
        Uri.parse('${_apiService.instanceUrl}/api/v1/accounts/verify_credentials'),
      );
      
      _apiService.checkResponse(response);
      
      return jsonDecode(response.body) as Map<String, dynamic>;
    });
  }
  
  /// Fetches the public timeline.
  ///
  /// [limit] - The maximum number of posts to return (default: 20).
  /// [onlyLocal] - Whether to only return posts from the local instance (default: false).
  Future<List<Map<String, dynamic>>> getPublicTimeline({
    int limit = 20,
    bool onlyLocal = false,
    bool requireAuth = false,  // Public timeline can be accessed without auth
  }) async {
    return _apiService.execute<List<Map<String, dynamic>>>(
      (client) async {
        final queryParams = <String, String>{
          'limit': limit.toString(),
        };
        
        if (onlyLocal) {
          queryParams['local'] = 'true';
        }
        
        final uri = Uri.parse('${_apiService.instanceUrl}/api/v1/timelines/public')
            .replace(queryParameters: queryParams);
        
        final response = await client.get(uri);
        
        _apiService.checkResponse(response);
        
        return (jsonDecode(response.body) as List)
            .cast<Map<String, dynamic>>();
      },
      requireAuth: requireAuth,
    );
  }
  
  /// Fetches the home timeline (posts from followed users).
  ///
  /// [limit] - The maximum number of posts to return (default: 20).
  Future<List<Map<String, dynamic>>> getHomeTimeline({int limit = 20}) async {
    return _apiService.execute<List<Map<String, dynamic>>>((client) async {
      final uri = Uri.parse('${_apiService.instanceUrl}/api/v1/timelines/home')
          .replace(queryParameters: {'limit': limit.toString()});
      
      final response = await client.get(uri);
      
      _apiService.checkResponse(response);
      
      return (jsonDecode(response.body) as List)
          .cast<Map<String, dynamic>>();
    });
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
    return _apiService.execute<Map<String, dynamic>>((client) async {
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
        Uri.parse('${_apiService.instanceUrl}/api/v1/statuses'),
        body: body,
      );
      
      _apiService.checkResponse(response);
      
      return jsonDecode(response.body) as Map<String, dynamic>;
    });
  }
  
  /// Fetches information about a user.
  ///
  /// [accountId] - The ID of the account to fetch.
  Future<Map<String, dynamic>> getAccount(String accountId) async {
    return _apiService.execute<Map<String, dynamic>>((client) async {
      final response = await client.get(
        Uri.parse('${_apiService.instanceUrl}/api/v1/accounts/$accountId'),
      );
      
      _apiService.checkResponse(response);
      
      return jsonDecode(response.body) as Map<String, dynamic>;
    });
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
    return _apiService.execute<Map<String, dynamic>>((client) async {
      final queryParams = <String, String>{
        'q': query,
        'limit': limit.toString(),
      };
      
      if (type != null) {
        queryParams['type'] = type;
      }
      
      final uri = Uri.parse('${_apiService.instanceUrl}/api/v2/search')
          .replace(queryParameters: queryParams);
      
      final response = await client.get(uri);
      
      _apiService.checkResponse(response);
      
      return jsonDecode(response.body) as Map<String, dynamic>;
    });
  }
  
  /// Fetches the instance information.
  ///
  /// This endpoint doesn't require authentication.
  Future<Map<String, dynamic>> getInstance() async {
    return _apiService.execute<Map<String, dynamic>>(
      (client) async {
        final response = await client.get(
          Uri.parse('${_apiService.instanceUrl}/api/v1/instance'),
        );
        
        _apiService.checkResponse(response);
        
        return jsonDecode(response.body) as Map<String, dynamic>;
      },
      requireAuth: false,
    );
  }

  /// Fetches a status by its ID.
  ///
  /// [id] - The ID of the status to fetch.
  Future<Map<String, dynamic>> getStatus(String id) async {
    return _apiService.execute<Map<String, dynamic>>((client) async {
      final response = await client.get(
        Uri.parse('${_apiService.instanceUrl}/api/v1/statuses/$id'),
      );
      
      _apiService.checkResponse(response);
      
      return jsonDecode(response.body) as Map<String, dynamic>;
    });
  }

  /// Favorites (likes) a status.
  ///
  /// [id] - The ID of the status to favorite.
  Future<Map<String, dynamic>> favoriteStatus(String id) async {
    return _apiService.execute<Map<String, dynamic>>((client) async {
      final response = await client.post(
        Uri.parse('${_apiService.instanceUrl}/api/v1/statuses/$id/favourite'),
      );
      
      _apiService.checkResponse(response);
      
      return jsonDecode(response.body) as Map<String, dynamic>;
    });
  }

  /// Unfavorites (unlikes) a status.
  ///
  /// [id] - The ID of the status to unfavorite.
  Future<Map<String, dynamic>> unfavoriteStatus(String id) async {
    return _apiService.execute<Map<String, dynamic>>((client) async {
      final response = await client.post(
        Uri.parse('${_apiService.instanceUrl}/api/v1/statuses/$id/unfavourite'),
      );
      
      _apiService.checkResponse(response);
      
      return jsonDecode(response.body) as Map<String, dynamic>;
    });
  }

  /// Reblogs (boosts) a status.
  ///
  /// [id] - The ID of the status to reblog.
  Future<Map<String, dynamic>> reblogStatus(String id) async {
    return _apiService.execute<Map<String, dynamic>>((client) async {
      final response = await client.post(
        Uri.parse('${_apiService.instanceUrl}/api/v1/statuses/$id/reblog'),
      );
      
      _apiService.checkResponse(response);
      
      return jsonDecode(response.body) as Map<String, dynamic>;
    });
  }

  /// Unreblogs (unboosts) a status.
  ///
  /// [id] - The ID of the status to unreblog.
  Future<Map<String, dynamic>> unreblogStatus(String id) async {
    return _apiService.execute<Map<String, dynamic>>((client) async {
      final response = await client.post(
        Uri.parse('${_apiService.instanceUrl}/api/v1/statuses/$id/unreblog'),
      );
      
      _apiService.checkResponse(response);
      
      return jsonDecode(response.body) as Map<String, dynamic>;
    });
  }

  /// Follows a user.
  ///
  /// [id] - The ID of the account to follow.
  Future<Map<String, dynamic>> followAccount(String id) async {
    return _apiService.execute<Map<String, dynamic>>((client) async {
      final response = await client.post(
        Uri.parse('${_apiService.instanceUrl}/api/v1/accounts/$id/follow'),
      );
      
      _apiService.checkResponse(response);
      
      return jsonDecode(response.body) as Map<String, dynamic>;
    });
  }

  /// Unfollows a user.
  ///
  /// [id] - The ID of the account to unfollow.
  Future<Map<String, dynamic>> unfollowAccount(String id) async {
    return _apiService.execute<Map<String, dynamic>>((client) async {
      final response = await client.post(
        Uri.parse('${_apiService.instanceUrl}/api/v1/accounts/$id/unfollow'),
      );
      
      _apiService.checkResponse(response);
      
      return jsonDecode(response.body) as Map<String, dynamic>;
    });
  }

  /// Fetches the user's notifications.
  ///
  /// [limit] - The maximum number of notifications to return (default: 20).
  /// [types] - The types of notifications to include (follow, mention, reblog, favourite, etc).
  /// [excludeTypes] - The types of notifications to exclude.
  Future<List<Map<String, dynamic>>> getNotifications({
    int limit = 20,
    List<String>? types,
    List<String>? excludeTypes,
  }) async {
    return _apiService.execute<List<Map<String, dynamic>>>((client) async {
      final queryParams = <String, String>{
        'limit': limit.toString(),
      };
      
      if (types != null && types.isNotEmpty) {
        queryParams['types[]'] = types.join(',');
      }
      
      if (excludeTypes != null && excludeTypes.isNotEmpty) {
        queryParams['exclude_types[]'] = excludeTypes.join(',');
      }
      
      final uri = Uri.parse('${_apiService.instanceUrl}/api/v1/notifications')
          .replace(queryParameters: queryParams);
      
      final response = await client.get(uri);
      
      _apiService.checkResponse(response);
      
      return (jsonDecode(response.body) as List)
          .cast<Map<String, dynamic>>();
    });
  }

  /// Fetches a single notification by its ID.
  ///
  /// [id] - The ID of the notification to fetch.
  Future<Map<String, dynamic>> getNotification(String id) async {
    return _apiService.execute<Map<String, dynamic>>((client) async {
      final response = await client.get(
        Uri.parse('${_apiService.instanceUrl}/api/v1/notifications/$id'),
      );
      
      _apiService.checkResponse(response);
      
      return jsonDecode(response.body) as Map<String, dynamic>;
    });
  }

  /// Clears all notifications.
  Future<void> clearNotifications() async {
    return _apiService.execute<void>((client) async {
      final response = await client.post(
        Uri.parse('${_apiService.instanceUrl}/api/v1/notifications/clear'),
      );
      
      _apiService.checkResponse(response);
    });
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