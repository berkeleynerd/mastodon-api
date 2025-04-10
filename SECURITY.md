# Security Best Practices

This document outlines security best practices when using the Mastodon API package.

## Credential Storage

### In Production Applications

OAuth credentials contain sensitive information that must be protected. Follow these guidelines:

1. **DO NOT** store tokens in plain text files or shared preferences without encryption.

2. **DO** use platform-specific secure storage:
   - **Flutter**: Use [flutter_secure_storage](https://pub.dev/packages/flutter_secure_storage)
   - **Web**: Use [WebCrypto API](https://developer.mozilla.org/en-US/docs/Web/API/Web_Crypto_API) or secure cookies
   - **Native**: Use Keychain (iOS) or KeyStore (Android)

3. **DO** implement proper encryption if platform-specific secure storage is not available:
   - Use AES-256 or better
   - Generate and store encryption keys securely
   - Implement proper key rotation

4. The `SecureCredentialStorage` class in this package provides a starting point, but:
   - It uses a simplified encryption method for demonstration
   - It should be extended with proper encryption for production use

## Network Security

### HTTPS Validation

1. **DO** validate HTTPS certificates in production.

2. **DO NOT** disable certificate validation globally.

3. **Consider** implementing certificate pinning for critical applications:
   - This package includes a `certificateValidator` parameter for custom validation
   - In production, pin the expected certificate or public key

Example of certificate pinning:

```dart
final expectedCertFingerprint = 'EXPECTED_SHA256_FINGERPRINT';

bool certificateValidator(X509Certificate cert, String host, int port) {
  final fingerprintBytes = cert.sha256;
  final fingerprintString = fingerprintBytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join(':');
  
  return fingerprintString.toUpperCase() == expectedCertFingerprint.toUpperCase();
}

// Use this validator in the MastodonOAuth constructor
final oauth = MastodonOAuth(
  // ...other parameters
  certificateValidator: certificateValidator,
);
```

## Token Refresh

1. **DO** handle token expiration and refresh properly:
   - The package implements automatic token refresh before expiration
   - The default buffer time is 5 minutes and can be customized

2. **Consider** implementing proper error handling for token refresh:
   - Log out the user if refresh consistently fails
   - Provide a clear way for users to re-authenticate

## Client Secrets

1. **DO NOT** hard-code client secrets in your application.

2. **Consider** strategies to protect client secrets:
   - Use a backend proxy service for OAuth flow
   - Implement the PKCE flow (used by this package) to reduce the impact of leaked secrets

## Access Control

1. **DO** request only the necessary OAuth scopes for your application:
   - `read` for read-only applications 
   - `write` for applications that need to post or modify data
   - `follow` only if your application needs to modify relationships

2. **DO NOT** store tokens with broader scope than needed.

## Secure Development

1. **DO** audit dependencies regularly for security vulnerabilities.

2. **DO** keep this package and all dependencies updated.

3. **DO** implement proper logout functionality that clears tokens.

4. **Consider** setting up secure headers in your web applications to prevent common web vulnerabilities.

## Reporting Security Issues

If you discover a security vulnerability in this package, please report it responsibly by emailing [security@example.com](mailto:security@example.com) rather than opening a public issue.

## Additional Resources

- [OAuth 2.0 Security Best Practices](https://oauth.net/2/security-best-practices/)
- [OWASP Mobile Application Security Verification Standard](https://mas.owasp.org/MASVS/)
- [Flutter Security Best Practices](https://docs.flutter.dev/development/security) 