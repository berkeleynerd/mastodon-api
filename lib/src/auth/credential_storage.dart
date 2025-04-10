import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:oauth2/oauth2.dart' as oauth2;
import 'package:crypto/crypto.dart';
import 'package:meta/meta.dart';

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

/// A more secure implementation of credential storage with encryption
/// 
/// Note: This is a basic implementation for demonstration purposes.
/// For production use, consider using platform-specific secure storage solutions:
/// - Flutter: flutter_secure_storage
/// - Web: WebCrypto API or localStorage with additional encryption
/// - Native: Keychain (iOS) or KeyStore (Android)
class SecureCredentialStorage implements CredentialStorage {
  final Future<void> Function(String data) _writeFile;
  final Future<String?> Function() _readFile;
  final Future<void> Function() _deleteFile;
  final String _encryptionKey;
  
  /// Creates a SecureCredentialStorage with the specified file operations and encryption key
  /// 
  /// For security, the encryption key should be:
  /// 1. Generated securely (use a secure random generator)
  /// 2. Stored securely (use platform-specific secure storage)
  /// 3. At least 32 bytes long (for AES-256)
  SecureCredentialStorage({
    required Future<void> Function(String data) writeFile,
    required Future<String?> Function() readFile,
    required Future<void> Function() deleteFile,
    required String encryptionKey,
  })  : _writeFile = writeFile,
        _readFile = readFile,
        _deleteFile = deleteFile,
        _encryptionKey = encryptionKey;
  
  /// Create a SecureCredentialStorage with a randomly generated encryption key
  /// 
  /// Note: The key will be different each time this constructor is called,
  /// so this should only be used for testing.
  @visibleForTesting
  static SecureCredentialStorage withRandomKey({
    required Future<void> Function(String data) writeFile,
    required Future<String?> Function() readFile,
    required Future<void> Function() deleteFile,
  }) {
    final random = Random.secure();
    final keyBytes = List<int>.generate(32, (_) => random.nextInt(256));
    final key = base64Url.encode(keyBytes);
    
    return SecureCredentialStorage(
      writeFile: writeFile,
      readFile: readFile,
      deleteFile: deleteFile,
      encryptionKey: key,
    );
  }
  
  @override
  Future<void> saveCredentials(oauth2.Credentials credentials) async {
    final Map<String, dynamic> json = _credentialsToJson(credentials);
    final jsonStr = jsonEncode(json);
    
    // In a real implementation, use proper encryption
    // This is a simplified version using a basic XOR cipher for demonstration
    final encryptedData = _encrypt(jsonStr);
    
    await _writeFile(encryptedData);
  }
  
  @override
  Future<oauth2.Credentials?> loadCredentials() async {
    final encryptedData = await _readFile();
    if (encryptedData == null || encryptedData.isEmpty) {
      return null;
    }
    
    try {
      // Decrypt the data
      final decryptedData = _decrypt(encryptedData);
      
      // Parse the JSON
      final Map<String, dynamic> json = jsonDecode(decryptedData) as Map<String, dynamic>;
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
  
  /// Simple encryption method for demonstration purposes
  /// 
  /// WARNING: This is NOT secure for production use!
  /// In a real application, use a proper encryption library
  String _encrypt(String data) {
    // In a real application, use AES encryption with a secure key
    // and proper initialization vector
    
    // For demo purposes, we'll use a simple XOR with the key
    final keyBytes = sha256.convert(utf8.encode(_encryptionKey)).bytes;
    final dataBytes = utf8.encode(data);
    final encrypted = Uint8List(dataBytes.length);
    
    for (var i = 0; i < dataBytes.length; i++) {
      encrypted[i] = dataBytes[i] ^ keyBytes[i % keyBytes.length];
    }
    
    // Add a simple integrity check
    final checksum = sha256.convert(encrypted).bytes.sublist(0, 8);
    final result = [...encrypted, ...checksum];
    
    return base64Url.encode(result);
  }
  
  /// Simple decryption method for demonstration purposes
  /// 
  /// WARNING: This is NOT secure for production use!
  String _decrypt(String encryptedData) {
    final bytes = base64Url.decode(encryptedData);
    
    // Extract the checksum
    final data = bytes.sublist(0, bytes.length - 8);
    final checksum = bytes.sublist(bytes.length - 8);
    
    // Verify the checksum
    final calculatedChecksum = sha256.convert(data).bytes.sublist(0, 8);
    for (var i = 0; i < 8; i++) {
      if (checksum[i] != calculatedChecksum[i]) {
        throw Exception('Integrity check failed');
      }
    }
    
    // Decrypt using XOR
    final keyBytes = sha256.convert(utf8.encode(_encryptionKey)).bytes;
    final decrypted = Uint8List(data.length);
    
    for (var i = 0; i < data.length; i++) {
      decrypted[i] = data[i] ^ keyBytes[i % keyBytes.length];
    }
    
    return utf8.decode(decrypted);
  }
} 