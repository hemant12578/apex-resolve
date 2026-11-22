import 'dart:convert';
import 'dart:io' show Platform;
import 'package:ai_nexconn_chat_plugin/ai_nexconn_chat_plugin.dart' as nc;
import 'package:file_selector/file_selector.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';
import 'workspace_routes.dart';
import 'sign_in.dart';
import 'native_chat.dart';
import 'directory.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  bool firebase = false;
  try {
    await Firebase.initializeApp();
    firebase = true;
  } catch (_) {
    /* Workspace email sign-in remains available. */
  }
  runApp(ApexApp(firebase: firebase));
}

class ApexApp extends StatelessWidget {
  const ApexApp({super.key, this.firebase = false});
  final bool firebase;
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Apex Resolve',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xffb55520)),
    ),
    darkTheme: ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xffffac77),
        brightness: Brightness.dark,
      ),
    ),
    home: SessionGate(firebase: firebase),
  );
}

class SessionGate extends StatefulWidget {
  const SessionGate({super.key, required this.firebase});
  final bool firebase;
  @override
  State<SessionGate> createState() => _SessionGateState();
}

class _SessionGateState extends State<SessionGate> {
  bool checking = true, signedIn = false, unavailable = false;
  @override
  void initState() {
    super.initState();
    check();
  }

  Future<void> check() async {
    setState(() {
      checking = true;
      unavailable = false;
    });
    try {
      await const MethodChannel(
        'apex/session',
      ).invokeMethod<String>('directory', {'section': 'chats'});
      signedIn = true;
    } on PlatformException catch (error) {
      unavailable = error.code != 'SIGN_IN';
    } finally {
      if (mounted) setState(() => checking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (checking) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (unavailable) {
      return Scaffold(
        body: Center(
          child: FilledButton(
            onPressed: check,
            child: const Text('Retry connection'),
          ),
        ),
      );
    }
    if (signedIn) return Home(firebase: widget.firebase);
    if (!widget.firebase && !Platform.isAndroid) {
      return const Workspace(path: '/login', title: 'Sign in', firebase: false);
    }
    return SignIn(
      onSuccess: (path) {
        setState(() => signedIn = true);
        if (path == '/welcome') {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder:
                  (_) => Workspace(
                    path: path,
                    title: 'Welcome',
                    firebase: widget.firebase,
                  ),
            ),
          );
        }
      },
    );
  }
}

class Home extends StatelessWidget {
  const Home({super.key, required this.firebase});
  final bool firebase;
  static const entries = [
    (
      Icons.forum_outlined,
      'Messages',
      'Private conversations and requests',
      '/communication?tab=chats',
    ),
    (
      Icons.groups_outlined,
      'Communities',
      'Group chats, members and invitations',
      '/communication?tab=groups',
    ),
    (
      Icons.fact_check_outlined,
      'Resolution',
      'Issues, evidence and independent review',
      '/dashboard?view=resolution',
    ),
    (
      Icons.library_books_outlined,
      'Knowledge',
      'Find verified resolutions',
      '/knowledge',
    ),
    (
      Icons.auto_awesome_outlined,
      'Apex AI',
      'Ask about your workspace',
      '/communication?tab=ai',
    ),
    (
      Icons.settings_outlined,
      'Settings',
      'Profile and workspace preferences',
      '/settings',
    ),
  ];
  void open(BuildContext c, String path, String title) {
    Future<void> workspace(String destination, {String? threadTitle}) async {
      final target = chatTarget(
        Uri.parse(workspaceOrigin).resolve(destination),
      );
      if (target != null &&
          threadTitle != null &&
          !target.containsKey('issueId')) {
        try {
          final value = await const MethodChannel(
            'apex/session',
          ).invokeMethod<String>('chat', target);
          if (!c.mounted) return;
          final details = await Navigator.push<bool>(
            c,
            MaterialPageRoute(
              builder:
                  (_) => NativeChat(
                    session: jsonDecode(value!) as Map<String, dynamic>,
                    title: threadTitle,
                    showWorkspace: true,
                  ),
            ),
          );
          if (nc.NCEngine.isInitialized) await nc.NCEngine.disconnect();
          if (!c.mounted || details != true) return;
        } on PlatformException {
          if (!c.mounted) return;
        }
      }
      if (destination == '/login' && firebase) {
        final next = await Navigator.push<String>(
          c,
          MaterialPageRoute(builder: (_) => const SignIn()),
        );
        if (!c.mounted || next == null) return;
        if (next != '/login' && next != '/welcome') return;
        destination = next;
      }
      await Navigator.push(
        c,
        MaterialPageRoute(
          builder:
              (_) => Workspace(
                path: destination,
                title: title,
                firebase: firebase,
              ),
        ),
      );
    }

    final section = switch (path) {
      '/communication?tab=chats' => 'chats',
      '/communication?tab=groups' => 'groups',
      '/dashboard?view=resolution' => 'issues',
      '/knowledge' => 'knowledge',
      _ => null,
    };
    if (section == null) {
      workspace(path);
      return;
    }
    Navigator.push(
      c,
      MaterialPageRoute(
        builder:
            (_) => Directory(
              section: section,
              title: title,
              open: workspace,
              workspacePath: path,
            ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(18, 24, 18, 24),
        children: [
          Text(
            'Apex Resolve',
            style: Theme.of(
              context,
            ).textTheme.headlineLarge?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: () => open(context, '/dashboard', 'Workspace'),
            icon: const Icon(Icons.dashboard_outlined),
            label: const Text('Open workspace'),
          ),
          const SizedBox(height: 20),
          for (final (index, e) in entries.indexed)
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: 1),
              duration:
                  MediaQuery.disableAnimationsOf(context)
                      ? Duration.zero
                      : Duration(milliseconds: 220 + index * 45),
              curve: Curves.easeOutCubic,
              builder:
                  (_, v, child) => Opacity(
                    opacity: v,
                    child: Transform.translate(
                      offset: Offset(0, 16 * (1 - v)),
                      child: child,
                    ),
                  ),
              child: Card(
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 6,
                  ),
                  leading: CircleAvatar(child: Icon(e.$1)),
                  title: Text(e.$2),
                  subtitle: Text(e.$3),
                  onTap: () => open(context, e.$4, e.$2),
                ),
              ),
            ),
        ],
      ),
    ),
  );
}

class Workspace extends StatefulWidget {
  const Workspace({
    super.key,
    required this.path,
    required this.title,
    required this.firebase,
  });
  final String path, title;
  final bool firebase;
  @override
  State<Workspace> createState() => _WorkspaceState();
}

class _WorkspaceState extends State<Workspace> {
  late final WebViewController web;
  late Uri current;
  bool error = false, opening = false, canBack = false;
  int progress = 0;
  Uri route(String path) => Uri.parse(workspaceOrigin).resolve(path);
  @override
  void initState() {
    super.initState();
    current = route(widget.path);
    web = WebViewController();
    configure();
  }

  bool redirecting = false;
  bool interceptAuth(Uri uri) {
    if (!widget.firebase && !Platform.isAndroid) return false;
    if (!(uri.scheme == 'https' &&
        ((isWorkspace(uri) &&
                (uri.path == '/login' || uri.path == '/signup')) ||
            uri.host == 'accounts.google.com'))) {
      return false;
    }
    if (!redirecting && mounted) {
      redirecting = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(
              builder: (_) => SessionGate(firebase: widget.firebase),
            ),
            (_) => false,
          );
        }
      });
    }
    return true;
  }

  Future<void> configure() async {
    await web.setJavaScriptMode(JavaScriptMode.unrestricted);
    await web.setOnJavaScriptAlertDialog((request) async {
      if (mounted) {
        await showDialog<void>(
          context: context,
          builder:
              (c) => AlertDialog(
                content: Text(request.message),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(c),
                    child: const Text('OK'),
                  ),
                ],
              ),
        );
      }
    });
    await web.setOnJavaScriptConfirmDialog((request) async {
      if (!mounted) return false;
      return await showDialog<bool>(
            context: context,
            builder:
                (c) => AlertDialog(
                  content: Text(request.message),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(c, false),
                      child: const Text('Cancel'),
                    ),
                    FilledButton(
                      onPressed: () => Navigator.pop(c, true),
                      child: const Text('Confirm'),
                    ),
                  ],
                ),
          ) ??
          false;
    });
    final android = web.platform;
    if (android is AndroidWebViewController) {
      await android.setOnShowFileSelector((params) async {
        final file = await openFile();
        return file == null ? [] : [Uri.file(file.path).toString()];
      });
    }
    await web.setNavigationDelegate(
      NavigationDelegate(
        onNavigationRequest: (request) async {
          final uri = Uri.tryParse(request.url);
          if (uri == null || (request.isMainFrame && interceptAuth(uri))) {
            return NavigationDecision.prevent;
          }
          if (uri.toString() == 'about:blank' ||
              (uri.scheme == 'https' && isWorkspace(uri))) {
            return NavigationDecision.navigate;
          }
          if (request.isMainFrame && uri.scheme == 'https') {
            await launchUrl(uri, mode: LaunchMode.externalApplication);
          }
          return NavigationDecision.prevent;
        },
        onUrlChange: (event) {
          final uri = Uri.tryParse(event.url ?? '');
          if (uri != null && interceptAuth(uri)) return;
          if (mounted &&
              uri != null &&
              uri.scheme == 'https' &&
              isWorkspace(uri)) {
            setState(() => current = uri);
          }
        },
        onProgress: (value) {
          if (mounted) setState(() => progress = value);
        },
        onPageStarted: (_) {
          if (mounted) setState(() => error = false);
        },
        onPageFinished: (_) async {
          final back = await web.canGoBack();
          if (mounted) setState(() => canBack = back);
        },
        onWebResourceError: (e) {
          if (mounted && e.isForMainFrame == true) setState(() => error = true);
        },
      ),
    );
    await web.loadRequest(current);
  }

  Future<void> chat() async {
    final target = chatTarget(current), resume = current;
    if (target == null || opening) return;
    setState(() => opening = true);
    try {
      final value = await const MethodChannel(
        'apex/session',
      ).invokeMethod<String>('chat', target);
      final session = jsonDecode(value!) as Map<String, dynamic>;
      if (!mounted) return;
      await web.loadRequest(Uri.parse('about:blank'));
      if (!mounted) return;
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder:
              (_) => NativeChat(
                session: session,
                title:
                    session['peerName'] ??
                    (target.containsKey('communityId')
                        ? 'Group chat'
                        : 'Conversation'),
              ),
        ),
      );
      if (nc.NCEngine.isInitialized) await nc.NCEngine.disconnect();
      await web.loadRequest(resume);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Unable to connect to Android chat. The workspace conversation is available.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => opening = false);
    }
  }

  Future<void> login() async {
    final path = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => const SignIn()),
    );
    if (path != null && mounted) await web.loadRequest(route(path));
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !canBack,
    onPopInvokedWithResult: (didPop, _) async {
      if (!didPop && await web.canGoBack()) await web.goBack();
    },
    child: Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Home',
          icon: const Icon(Icons.home_outlined),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(widget.title),
        actions: [
          if (widget.firebase &&
              (current.path == '/login' || current.path == '/signup'))
            TextButton(onPressed: login, child: const Text('App sign-in')),
          if (chatTarget(current) != null)
            TextButton.icon(
              onPressed: opening ? null : chat,
              icon: const Icon(Icons.chat_outlined),
              label: const Text('App chat'),
            ),
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh),
            onPressed: () => web.loadRequest(current),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            if (progress < 100 && !error)
              LinearProgressIndicator(
                value: progress == 0 ? null : progress / 100,
              ),
            Expanded(
              child:
                  error
                      ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text('Could not reach Apex Resolve.'),
                            FilledButton(
                              onPressed: () => web.loadRequest(current),
                              child: const Text('Retry'),
                            ),
                          ],
                        ),
                      )
                      : WebViewWidget(controller: web),
            ),
          ],
        ),
      ),
    ),
  );
}
