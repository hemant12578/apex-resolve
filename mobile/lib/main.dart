import 'dart:convert';
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
    home: Home(firebase: firebase),
  );
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
          Row(
            children: [
              Icon(
                Icons.layers_rounded,
                size: 34,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 10),
              Text(
                'Apex Resolve',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: () => open(context, '/dashboard', 'Workspace'),
            icon: const Icon(Icons.dashboard_outlined),
            label: const Text('Open workspace'),
          ),
          const SizedBox(height: 14),
          for (final e in entries)
            Card(
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 5,
                ),
                leading: Icon(e.$1),
                title: Text(e.$2),
                subtitle: Text(e.$3),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => open(context, e.$4, e.$2),
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
          if (uri == null) return NavigationDecision.prevent;
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
