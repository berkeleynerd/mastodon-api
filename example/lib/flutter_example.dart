import 'package:flutter/material.dart';
import 'package:mastodon_api/mastodon_api.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:oauth2/oauth2.dart' as oauth2;
import 'package:webview_flutter/webview_flutter.dart';

void main() {
  runApp(MastodonApp());
}

class MastodonApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Mastodon Client',
      theme: ThemeData(
        primarySwatch: Colors.indigo,
        brightness: Brightness.light,
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
  String? _errorMessage;

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

      final instanceUrl = 'https://$instance';
      final redirectUrl = 'mastodonapp://callback';

      // Save instance URL
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('mastodon_instance_url', instanceUrl);

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

  @override
  void initState() {
    super.initState();
    _initializeClient();
  }

  Future<void> _initializeClient() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final instanceUrl = prefs.getString('mastodon_instance_url')!;
      final clientId = prefs.getString('mastodon_client_id')!;
      final clientSecret = prefs.getString('mastodon_client_secret')!;
      final credentialsJson = prefs.getString('mastodon_credentials')!;
      final credentials = oauth2.Credentials.fromJson(credentialsJson);
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
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Error: ${e.toString()}';
        _isLoading = false;
      });
    }
  }

  Future<void> _refreshTimeline() async {
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
        title: Text('Home Timeline'),
        actions: [
          IconButton(
            icon: Icon(Icons.exit_to_app),
            onPressed: _logout,
            tooltip: 'Logout',
          ),
        ],
      ),
      body: RefreshIndicator(
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
                                backgroundImage: NetworkImage(account['avatar']),
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
                                onPressed: () {},
                              ),
                              _buildActionButton(
                                icon: Icons.repeat,
                                count: post['reblogs_count'] ?? 0,
                                onPressed: () async {
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
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // Show a modal for composing a new status
          showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            builder: (context) => ComposeStatusSheet(
              mastodon: mastodon,
              onStatusPosted: _refreshTimeline,
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
  final MastodonClient mastodon;
  final VoidCallback onStatusPosted;

  ComposeStatusSheet({
    required this.mastodon,
    required this.onStatusPosted,
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
      await widget.mastodon.postStatus(
        status: _statusController.text,
        visibility: _visibility,
      );

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
                  'Compose new post',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              IconButton(
                icon: Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              ),
            ],
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