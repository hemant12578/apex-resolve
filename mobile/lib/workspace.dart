import 'dart:convert';
import 'dart:io' show Platform;

import 'package:ai_nexconn_chat_plugin/ai_nexconn_chat_plugin.dart' as nc;
import 'package:file_selector/file_selector.dart';
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';

import 'native_chat.dart';
import 'session.dart';
import 'sign_in.dart';
import 'workspace_routes.dart';

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
      ApexSession.expire();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          Navigator.of(context).popUntil((route) => route.isFirst);
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
