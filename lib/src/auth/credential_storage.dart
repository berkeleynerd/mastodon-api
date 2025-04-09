import 'dart:convert';
import 'package:oauth2/oauth2.dart' as oauth2;

/// Interface for credential storage implementations
abstract class CredentialStorage {
  /// Saves credentials to persistent storage
  Future<void> saveCredentials(oauth2.Credentials credentials);
  
  /// Loads credentials from persistent storage
  Future<oauth2.Credentials?> loadCredentials();
  
  /// Clears stored credentials
  Future<void> clearCredentials();
}

/// In-memory implementation of CredentialStorage for testing
class InMemoryCredentialStorage implements CredentialStorage {
  oauth2.Credentials? _storedCredentials;
  
  @override
  Future<void> saveCredentials(oauth2.Credentials credentials) async {
    _storedCredentials = credentials;
  }
  
  @override
  Future<oauth2.Credentials?> loadCredentials() async {
    return _storedCredentials;
  }
  
  @override
  Future<void> clearCredentials() async {
    _storedCredentials = null;
  }
}

/// File-based implementation of CredentialStorage
class FileCredentialStorage implements CredentialStorage {
  final Future<void> Function(String data) _writeFile;
  final Future<String?> Function() _readFile;
  final Future<void> Function() _deleteFile;
  
  /// Creates a FileCredentialStorage with the specified file operations
  FileCredentialStorage({
    required Future<void> Function(String data) writeFile,
    required Future<String?> Function() readFile,
    required Future<void> Function() deleteFile,
  })  : _writeFile = writeFile,
        _readFile = readFile,
        _deleteFile = deleteFile;
  
  @override
  Future<void> saveCredentials(oauth2.Credentials credentials) async {
    final Map<String, dynamic> json = _credentialsToJson(credentials);
    final data = jsonEncode(json);
    await _writeFile(data);
  }
  
  @override
  Future<oauth2.Credentials?> loadCredentials() async {
    final data = await _readFile();
    if (data == null || data.isEmpty) {
      return null;
    }
    
    try {
      final Map<String, dynamic> json = jsonDecode(data) as Map<String, dynamic>;
      return _credentialsFromJson(json);
    } catch (e) {
      print('Error loading credentials: $e');
      return null;
    }
  }
  
  @override
  Future<void> clearCredentials() async {
    await _deleteFile();
  }
  
  /// Converts OAuth2 credentials to a JSON map.
  Map<String, dynamic> _credentialsToJson(oauth2.Credentials credentials) {
    final Map<String, dynamic> json = {
      'accessToken': credentials.accessToken,
    };
    
    if (credentials.refreshToken != null) {
      json['refreshToken'] = credentials.refreshToken;
    }
    
    if (credentials.tokenEndpoint != null) {
      json['tokenEndpoint'] = credentials.tokenEndpoint.toString();
    }
    
    if (credentials.scopes != null && credentials.scopes!.isNotEmpty) {
      json['scopes'] = credentials.scopes;
    }
    
    if (credentials.expiration != null) {
      json['expiration'] = credentials.expiration!.millisecondsSinceEpoch;
    }
    
    return json;
  }
  
  /// Creates OAuth2 credentials from a JSON map.
  oauth2.Credentials _credentialsFromJson(Map<String, dynamic> json) {
    final String accessToken = json['accessToken'] as String;
    final String? refreshToken = json['refreshToken'] as String?;
    
    Uri? tokenEndpoint;
    if (json['tokenEndpoint'] != null) {
      tokenEndpoint = Uri.parse(json['tokenEndpoint'] as String);
    }
    
    List<String>? scopes;
    if (json['scopes'] != null) {
      scopes = (json['scopes'] as List).cast<String>();
    }
    
    DateTime? expiration;
    if (json['expiration'] != null) {
      expiration = DateTime.fromMillisecondsSinceEpoch(json['expiration'] as int);
    }
    
    return oauth2.Credentials(
      accessToken,
      refreshToken: refreshToken,
      tokenEndpoint: tokenEndpoint,
      scopes: scopes,
      expiration: expiration,
    );
  }
} 