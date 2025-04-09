import 'package:flutter/material.dart';
import 'package:mastodon_api/mastodon_api.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:oauth2/oauth2.dart' as oauth2;
import 'package:webview_flutter/webview_flutter.dart';
import 'dart:io';

void main() {
  // Enable https connections on macOS
  HttpOverrides.global = MyHttpOverrides();
  runApp(MastodonApp());
}

// Custom HttpOverrides to bypass certificate verification for development
class MyHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return super.createHttpClient(context)
      ..badCertificateCallback = (X509Certificate cert, String host, int port) => true;
  }
}

class MastodonApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Mastodon Client',
      theme: ThemeData(
        primarySwatch: Colors.indigo,
        brightness: Brightness.dark,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      darkTheme: ThemeData(
        primarySwatch: Colors.indigo,
        brightness: Brightness.dark,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      themeMode: ThemeMode.system,
      initialRoute: '/',
      routes: {
        '/': (context) => LoginScreen(),
        '/home': (context) => HomeScreen(),
      },
    );
  }
}

class LoginScreen extends StatefulWidget {
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _instanceController = TextEditingController(
    text: 'mastodon.social',
  );
  bool _isLoading = false;
  bool _checkingCredentials = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _checkForExistingCredentials();
  }

  Future<void> _checkForExistingCredentials() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final hasCredentials = prefs.containsKey('mastodon_credentials');
      
      if (hasCredentials) {
        // Try to use existing credentials directly
        Navigator.of(context).pushReplacementNamed('/home');
        return;
      }
    } catch (e) {
      print('Error checking credentials: $e');
    } finally {
      if (mounted) {
        setState(() {
          _checkingCredentials = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _instanceController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final instance = _instanceController.text.trim();
      if (instance.isEmpty) {
        throw Exception('Please enter a Mastodon instance');
      }

      final instanceUrl = instance.startsWith('http') ? instance : 'https://$instance';
      final redirectUrl = 'mastodonapp://callback';

      // Save instance URL
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('mastodon_instance_url', instanceUrl);

      // For development/demo purposes, use predefined credentials
      // In a real app, this would be securely stored after initial auth
      await prefs.setString('mastodon_credentials', '{"accessToken":"demo_token","refreshToken":null,"tokenEndpoint":"$instanceUrl/oauth/token","scopes":["read","write","follow"],"expiration":null}');
      
      // Navigate directly to home screen with mock credentials for demo
      Navigator.of(context).pushReplacementNamed('/home');
      
      /* 
      // This is the real implementation that would be used in production
      // Comment out the mock credentials and uncomment this for real OAuth flow
      
      // Check if we already have client credentials
      String? clientId = prefs.getString('mastodon_client_id');
      String? clientSecret = prefs.getString('mastodon_client_secret');

      if (clientId == null || clientSecret == null) {
        // Register new application
        final registration = await MastodonOAuth.registerApplication(
          instanceUrl: instanceUrl,
          applicationName: 'Flutter Mastodon Demo',
          redirectUris: [redirectUrl],
          scopes: ['read', 'write', 'follow'],
        );

        clientId = registration['client_id']!;
        clientSecret = registration['client_secret']!;

        // Save for future use
        await prefs.setString('mastodon_client_id', clientId);
        await prefs.setString('mastodon_client_secret', clientSecret);
      }

      // Navigate to the auth screen
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => AuthWebViewScreen(
            instanceUrl: instanceUrl,
            clientId: clientId!,
            clientSecret: clientSecret!,
            redirectUrl: redirectUrl,
          ),
        ),
      );
      */
    } catch (e) {
      setState(() {
        _errorMessage = 'Error: ${e.toString()}';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_checkingCredentials) {
      return Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    
    return Scaffold(
      appBar: AppBar(
        title: Text('Login to Mastodon'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Enter your Mastodon instance',
              style: Theme.of(context).textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 24),
            TextField(
              controller: _instanceController,
              decoration: InputDecoration(
                labelText: 'Instance',
                hintText: 'mastodon.social',
                prefixText: 'https://',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.url,
              textInputAction: TextInputAction.go,
              onSubmitted: (_) => _login(),
            ),
            SizedBox(height: 24),
            ElevatedButton(
              onPressed: _isLoading ? null : _login,
              child: _isLoading
                  ? SizedBox(
                      height: 24,
                      width: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                      ),
                    )
                  : Text('Login'),
              style: ElevatedButton.styleFrom(
                padding: EdgeInsets.symmetric(vertical: 12),
              ),
            ),
            if (_errorMessage != null) ...[
              SizedBox(height: 16),
              Text(
                _errorMessage!,
                style: TextStyle(color: Colors.red),
                textAlign: TextAlign.center,
              ),
            ],
            SizedBox(height: 24),
            Text(
              'Note: For demo purposes, this will use mock credentials.\nIn a real app, this would perform OAuth authentication.',
              style: TextStyle(color: Colors.grey),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class AuthWebViewScreen extends StatefulWidget {
  final String instanceUrl;
  final String clientId;
  final String clientSecret;
  final String redirectUrl;

  AuthWebViewScreen({
    required this.instanceUrl,
    required this.clientId,
    required this.clientSecret,
    required this.redirectUrl,
  });

  @override
  State<AuthWebViewScreen> createState() => _AuthWebViewScreenState();
}

class _AuthWebViewScreenState extends State<AuthWebViewScreen> {
  late MastodonOAuth oauth;
  late String authUrl;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _initializeOAuth();
  }

  Future<void> _initializeOAuth() async {
    try {
      oauth = MastodonOAuth(
        instanceUrl: widget.instanceUrl,
        clientId: widget.clientId,
        clientSecret: widget.clientSecret,
        redirectUrl: widget.redirectUrl,
      );

      // Get authorization URL
      authUrl = oauth.getAuthorizationUrl();
      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Error initializing OAuth: ${e.toString()}';
        _isLoading = false;
      });
    }
  }

  Future<void> _handleRedirect(String url) async {
    if (url.startsWith(widget.redirectUrl)) {
      setState(() {
        _isLoading = true;
      });

      final uri = Uri.parse(url);
      final code = uri.queryParameters['code'];

      if (code != null) {
        try {
          // Exchange code for token
          final client = await oauth.handleAuthorizationCode(code);

          // Save credentials securely
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('mastodon_credentials', client.credentials.toJson());

          // Navigate to home screen
          Navigator.of(context).pushReplacementNamed('/home');
        } catch (e) {
          setState(() {
            _errorMessage = 'Error: ${e.toString()}';
            _isLoading = false;
          });
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: Text('Authenticating')),
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_errorMessage != null) {
      return Scaffold(
        appBar: AppBar(title: Text('Error')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(_errorMessage!),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text('Login to Mastodon')),
      body: WebViewWidget(
        controller: WebViewController()
          ..setJavaScriptMode(JavaScriptMode.unrestricted)
          ..setNavigationDelegate(
            NavigationDelegate(
              onNavigationRequest: (NavigationRequest request) {
                if (request.url.startsWith(widget.redirectUrl)) {
                  _handleRedirect(request.url);
                  return NavigationDecision.prevent;
                }
                return NavigationDecision.navigate;
              },
            ),
          )
          ..loadRequest(Uri.parse(authUrl)),
      ),
    );
  }
}

class HomeScreen extends StatefulWidget {
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late MastodonClient mastodon;
  List<dynamic> posts = [];
  bool _isLoading = true;
  String? _errorMessage;
  bool _usingMockData = true;

  @override
  void initState() {
    super.initState();
    _initializeClient();
  }

  Future<void> _initializeClient() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final instanceUrl = prefs.getString('mastodon_instance_url') ?? 'https://mastodon.social';
      final credentialsJson = prefs.getString('mastodon_credentials');
      
      if (credentialsJson == null) {
        throw Exception('No credentials found');
      }
      
      final credentials = oauth2.Credentials.fromJson(credentialsJson);
      
      // Mock data for demo purposes
      if (credentials.accessToken == 'demo_token') {
        setState(() {
          _usingMockData = true;
          _isLoading = false;
          posts = _getMockPosts();
        });
        return;
      }
      
      // Real implementation with actual API calls
      final clientId = prefs.getString('mastodon_client_id')!;
      final clientSecret = prefs.getString('mastodon_client_secret')!;
      final redirectUrl = 'mastodonapp://callback';

      // Create OAuth with credential storage
      final credentialStorage = InMemoryCredentialStorage();
      await credentialStorage.saveCredentials(credentials);

      final oauth = MastodonOAuth(
        instanceUrl: instanceUrl,
        clientId: clientId,
        clientSecret: clientSecret,
        redirectUrl: redirectUrl,
        credentialStorage: credentialStorage,
      );

      // Create AuthManager
      final authManager = AuthManager(oauth: oauth);
      await authManager.initialize();

      // Create API service
      final apiService = ApiService(
        authManager: authManager,
        instanceUrl: instanceUrl,
      );

      // Create Mastodon client
      mastodon = MastodonClient(apiService: apiService);

      // Load timeline
      final timeline = await mastodon.getHomeTimeline(limit: 20);
      setState(() {
        posts = timeline;
        _usingMockData = false;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Error: ${e.toString()}';
        _isLoading = false;
      });
    }
  }

  // Mock data generator for demo purposes
  List<Map<String, dynamic>> _getMockPosts() {
    return [
      {
        'id': '1',
        'content': '<p>Welcome to the Mastodon API demo! This is using mock data since we\'re in demo mode.</p>',
        'created_at': '2023-05-15T14:23:00.000Z',
        'account': {
          'id': '1',
          'username': 'admin',
          'acct': 'admin',
          'display_name': 'Admin User',
          'avatar': 'https://picsum.photos/200',
          'avatar_color': 0xFF4287f5, // Blue
        },
        'reblogs_count': 5,
        'favourites_count': 10,
        'favourited': false,
        'reblogged': false,
      },
      {
        'id': '2',
        'content': '<p>This is a second example post with some <a href="https://example.com">links</a> and <span class="hashtag">#hashtags</span>.</p>',
        'created_at': '2023-05-14T10:30:00.000Z',
        'account': {
          'id': '2',
          'username': 'jane',
          'acct': 'jane',
          'display_name': 'Jane Smith',
          'avatar': 'https://picsum.photos/201',
          'avatar_color': 0xFFe84a5f, // Red
        },
        'reblogs_count': 2,
        'favourites_count': 8,
        'favourited': true,
        'reblogged': false,
      },
      {
        'id': '3',
        'content': '<p>In a production app, this would display your actual Mastodon timeline from the API.</p>',
        'created_at': '2023-05-13T18:45:00.000Z',
        'account': {
          'id': '3',
          'username': 'john',
          'acct': 'john',
          'display_name': 'John Doe',
          'avatar': 'https://picsum.photos/202',
          'avatar_color': 0xFF2ecc71, // Green
        },
        'reblogs_count': 0,
        'favourites_count': 3,
        'favourited': false,
        'reblogged': true,
      },
    ];
  }

  Future<void> _refreshTimeline() async {
    if (_usingMockData) {
      // In mock mode, just simulate a refresh
      await Future.delayed(Duration(seconds: 1));
      setState(() {
        posts = _getMockPosts();
      });
      return;
    }
    
    try {
      final timeline = await mastodon.getHomeTimeline(limit: 20);
      setState(() {
        posts = timeline;
      });
      return Future.value();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error refreshing timeline: ${e.toString()}')),
      );
      return Future.error(e);
    }
  }

  Future<void> _logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('mastodon_credentials');
    Navigator.of(context).pushReplacementNamed('/');
  }

  String _stripHtml(String html) {
    return html
        .replaceAll(RegExp(r'<[^>]*>'), '')
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&amp;', '&')
        .replaceAll('&quot;', '"')
        .trim();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: Text('Home Timeline')),
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_errorMessage != null) {
      return Scaffold(
        appBar: AppBar(title: Text('Error')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(_errorMessage!),
              ),
              ElevatedButton(
                onPressed: _logout,
                child: Text('Logout'),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(_usingMockData ? 'Mock Timeline (Demo)' : 'Home Timeline'),
        actions: [
          IconButton(
            icon: Icon(Icons.exit_to_app),
            onPressed: _logout,
            tooltip: 'Logout',
          ),
        ],
      ),
      body: Column(
        children: [
          if (_usingMockData)
            Container(
              color: Colors.amber.withOpacity(0.2),
              padding: EdgeInsets.all(8),
              child: Text(
                'Running in mock mode with demo data. Network calls are simulated.',
                style: TextStyle(color: Colors.amber),
                textAlign: TextAlign.center,
              ),
            ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _refreshTimeline,
              child: posts.isEmpty
                  ? Center(child: Text('No posts found'))
                  : ListView.builder(
                      itemCount: posts.length,
                      itemBuilder: (context, index) {
                        final post = posts[index];
                        final account = post['account'];
  
                        return Card(
                          margin: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          child: Padding(
                            padding: const EdgeInsets.all(12.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    CircleAvatar(
                                      backgroundImage: _usingMockData 
                                        ? null  // Use null when in mock mode
                                        : NetworkImage(account['avatar']),
                                      backgroundColor: _usingMockData
                                        ? Color(account['avatar_color'])  // Use color in mock mode
                                        : null,
                                      child: _usingMockData 
                                        ? Text(account['display_name'][0].toUpperCase())  // First letter of name
                                        : null,
                                      radius: 20,
                                    ),
                                    SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            account['display_name'],
                                            style: TextStyle(fontWeight: FontWeight.bold),
                                          ),
                                          Text(
                                            '@${account['acct']}',
                                            style: TextStyle(color: Colors.grey),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                SizedBox(height: 12),
                                Text(_stripHtml(post['content'])),
                                SizedBox(height: 12),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                                  children: [
                                    _buildActionButton(
                                      icon: Icons.reply,
                                      count: post['replies_count'] ?? 0,
                                      onPressed: () {
                                        if (_usingMockData) {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(content: Text('Reply action simulated in demo mode')),
                                          );
                                        }
                                      },
                                    ),
                                    _buildActionButton(
                                      icon: Icons.repeat,
                                      count: post['reblogs_count'] ?? 0,
                                      isActive: post['reblogged'] ?? false,
                                      onPressed: () async {
                                        if (_usingMockData) {
                                          setState(() {
                                            post['reblogged'] = !(post['reblogged'] ?? false);
                                            if (post['reblogged']) {
                                              post['reblogs_count'] = (post['reblogs_count'] ?? 0) + 1;
                                            } else {
                                              post['reblogs_count'] = (post['reblogs_count'] ?? 1) - 1;
                                            }
                                          });
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(content: Text('Reblog action simulated in demo mode')),
                                          );
                                          return;
                                        }
                                        
                                        try {
                                          await mastodon.reblogStatus(post['id']);
                                          _refreshTimeline();
                                        } catch (e) {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(content: Text('Error: ${e.toString()}')),
                                          );
                                        }
                                      },
                                    ),
                                    _buildActionButton(
                                      icon: Icons.favorite,
                                      count: post['favourites_count'] ?? 0,
                                      isActive: post['favourited'] ?? false,
                                      onPressed: () async {
                                        if (_usingMockData) {
                                          setState(() {
                                            post['favourited'] = !(post['favourited'] ?? false);
                                            if (post['favourited']) {
                                              post['favourites_count'] = (post['favourites_count'] ?? 0) + 1;
                                            } else {
                                              post['favourites_count'] = (post['favourites_count'] ?? 1) - 1;
                                            }
                                          });
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(content: Text('Favorite action simulated in demo mode')),
                                          );
                                          return;
                                        }
                                        
                                        try {
                                          if (post['favourited'] == true) {
                                            await mastodon.unfavoriteStatus(post['id']);
                                          } else {
                                            await mastodon.favoriteStatus(post['id']);
                                          }
                                          _refreshTimeline();
                                        } catch (e) {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(content: Text('Error: ${e.toString()}')),
                                          );
                                        }
                                      },
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // Show a modal for composing a new status
          showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            builder: (context) => ComposeStatusSheet(
              mastodon: _usingMockData ? null : mastodon,
              onStatusPosted: _refreshTimeline,
              isMockMode: _usingMockData,
            ),
          );
        },
        child: Icon(Icons.create),
        tooltip: 'Compose new status',
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required int count,
    bool isActive = false,
    required VoidCallback onPressed,
  }) {
    return TextButton.icon(
      onPressed: onPressed,
      icon: Icon(
        icon,
        color: isActive ? Colors.indigoAccent : Colors.grey,
        size: 18,
      ),
      label: Text(
        count.toString(),
        style: TextStyle(
          color: isActive ? Colors.indigoAccent : Colors.grey,
        ),
      ),
      style: TextButton.styleFrom(
        padding: EdgeInsets.symmetric(horizontal: 8),
      ),
    );
  }
}

class ComposeStatusSheet extends StatefulWidget {
  final MastodonClient? mastodon;
  final VoidCallback onStatusPosted;
  final bool isMockMode;

  ComposeStatusSheet({
    this.mastodon,
    required this.onStatusPosted,
    this.isMockMode = false,
  });

  @override
  State<ComposeStatusSheet> createState() => _ComposeStatusSheetState();
}

class _ComposeStatusSheetState extends State<ComposeStatusSheet> {
  final TextEditingController _statusController = TextEditingController();
  String _visibility = 'public';
  bool _isSending = false;

  @override
  void dispose() {
    _statusController.dispose();
    super.dispose();
  }

  Future<void> _postStatus() async {
    if (_statusController.text.trim().isEmpty) {
      return;
    }

    setState(() {
      _isSending = true;
    });

    try {
      if (widget.isMockMode) {
        // Simulate posting in mock mode
        await Future.delayed(Duration(seconds: 1));
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Post simulated in demo mode')),
        );
      } else {
        await widget.mastodon!.postStatus(
          status: _statusController.text,
          visibility: _visibility,
        );
      }

      Navigator.pop(context);
      widget.onStatusPosted();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error posting status: ${e.toString()}')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSending = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 16,
        right: 16,
        top: 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Compose new post' + (widget.isMockMode ? ' (Demo)' : ''),
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              IconButton(
                icon: Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          if (widget.isMockMode)
            Padding(
              padding: const EdgeInsets.only(bottom: 8.0),
              child: Text(
                'Running in demo mode - post will be simulated',
                style: TextStyle(color: Colors.amber),
              ),
            ),
          SizedBox(height: 16),
          TextField(
            controller: _statusController,
            maxLines: 5,
            decoration: InputDecoration(
              hintText: "What's on your mind?",
              border: OutlineInputBorder(),
            ),
            autofocus: true,
          ),
          SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              DropdownButton<String>(
                value: _visibility,
                onChanged: (value) {
                  if (value != null) {
                    setState(() {
                      _visibility = value;
                    });
                  }
                },
                items: [
                  DropdownMenuItem(
                    value: 'public',
                    child: Text('Public'),
                  ),
                  DropdownMenuItem(
                    value: 'unlisted',
                    child: Text('Unlisted'),
                  ),
                  DropdownMenuItem(
                    value: 'private',
                    child: Text('Followers only'),
                  ),
                  DropdownMenuItem(
                    value: 'direct',
                    child: Text('Direct'),
                  ),
                ],
              ),
              ElevatedButton(
                onPressed: _isSending ? null : _postStatus,
                child: _isSending
                    ? SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text('Post'),
              ),
            ],
          ),
          SizedBox(height: 16),
        ],
      ),
    );
  }
} 