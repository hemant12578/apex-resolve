import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

class Directory extends StatefulWidget {
  const Directory({
    super.key,
    required this.section,
    required this.title,
    required this.open,
    required this.workspacePath,
  });
  final String section, title, workspacePath;
  final Future<void> Function(String path, {String? threadTitle}) open;
  @override
  State<Directory> createState() => _DirectoryState();
}

class _DirectoryState extends State<Directory> {
  List<dynamic> items = [];
  String error = '', query = '';
  bool loading = true, auth = false;
  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    setState(() {
      loading = true;
      error = '';
      auth = false;
    });
    try {
      final raw = await const MethodChannel(
        'apex/session',
      ).invokeMethod<String>('directory', {'section': widget.section});
      final result = jsonDecode(raw!) as Map;
      if (mounted) setState(() => items = result['items'] as List);
    } on PlatformException catch (e) {
      if (mounted) {
        setState(() {
          auth = e.code == 'SIGN_IN';
          error =
              auth
                  ? 'Sign in to see your ${widget.title.toLowerCase()}.'
                  : 'Could not load your workspace.';
          items = [];
        });
      }
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  bool opening = false;
  Future<void> open(String path, {String? threadTitle}) async {
    if (opening) return;
    setState(() => opening = true);
    try {
      await widget.open(path, threadTitle: threadTitle);
    } finally {
      if (mounted) setState(() => opening = false);
    }
    if (mounted) await load();
  }

  @override
  Widget build(BuildContext context) {
    final matches =
        items
            .where(
              (e) => e['title'].toString().toLowerCase().contains(
                query.toLowerCase(),
              ),
            )
            .toList();
    final action = switch (widget.section) {
      'chats' => 'Find people',
      'groups' => 'Create community',
      'issues' => 'Create issue',
      _ => 'Search all solutions',
    };
    final path = switch (widget.section) {
      'chats' => '/communication?tab=people',
      'groups' => '/communities/new',
      'issues' => '/dashboard?view=resolution&create=issue#new-issue',
      _ => '/knowledge',
    };
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: loading ? null : load,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            if (loading || opening) const LinearProgressIndicator(),
            if (error.isNotEmpty)
              Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    Text(error),
                    FilledButton(
                      onPressed:
                          () => open(auth ? '/login' : widget.workspacePath),
                      child: Text(auth ? 'Sign in' : 'Open workspace'),
                    ),
                  ],
                ),
              )
            else ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: TextField(
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.search),
                    hintText: 'Search ${widget.title.toLowerCase()}',
                    border: const OutlineInputBorder(),
                  ),
                  onChanged: (text) => setState(() => query = text),
                ),
              ),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: load,
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: [
                      if (!loading && matches.isEmpty)
                        Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text(
                            query.isEmpty ? 'Nothing here yet.' : 'No matches.',
                          ),
                        ),
                      for (final item in matches)
                        ListTile(
                          title: Text(item['title'] as String),
                          subtitle: Text(
                            item['detail']?.toString() ?? '',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          trailing: const Icon(Icons.chevron_right),
                          onTap:
                              () => open(
                                item['path'] as String,
                                threadTitle: item['title'] as String,
                              ),
                        ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(12),
                child: FilledButton.icon(
                  onPressed: () => open(path),
                  icon: const Icon(Icons.arrow_forward),
                  label: Text(action),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
