import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import 'data.dart';
import 'resolution_screens.dart';
import 'user_discovery.dart';
import 'ui.dart';
import 'workspace_management.dart';

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
  final search = TextEditingController();
  @override
  void dispose() {
    search.dispose();
    super.dispose();
  }

  List<ApexEntry> items = [];
  String error = '', query = '', filter = 'All';
  bool loading = true, auth = false, opening = false;

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
      final list =
          widget.section == 'chats'
              ? (await Future.wait([
                loadDirectory('chats'),
                loadDirectory('groups'),
              ])).expand((entries) => entries).toList()
              : await loadDirectory(widget.section);
      if (mounted) setState(() => items = list);
    } on PlatformException catch (e) {
      if (mounted) {
        setState(() {
          auth = e.code == 'SIGN_IN';
          error =
              auth
                  ? 'Sign in to load ${widget.title.toLowerCase()}.'
                  : 'Could not load ${widget.title.toLowerCase()}.';
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => error = 'Could not load ${widget.title.toLowerCase()}.');
      }
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  List<ApexEntry> get visible {
    final q = query.trim().toLowerCase();
    return items.where((entry) {
      if (q.isNotEmpty &&
          !('${entry.title} ${entry.detail}'.toLowerCase().contains(q))) {
        return false;
      }
      if (filter == 'People') return entry.isChat;
      if (filter == 'Groups') return entry.isGroup;
      if (filter == 'Needs review') return entry.needsReview;
      if (filter == 'Open') return entry.isOpen;
      if (filter == 'Working') return entry.status == ApexStatus.inProgress;
      return true;
    }).toList();
  }

  List<String> get filters =>
      widget.section == 'issues'
          ? const ['All', 'Open', 'Working', 'Needs review']
          : widget.section == 'chats'
          ? const ['All', 'People', 'Groups']
          : const ['All'];

  Future<void> open(String path, {String? threadTitle}) async {
    if (opening) return;
    setState(() => opening = true);
    try {
      if (path.startsWith('/issues/')) {
        final id = path.replaceFirst('/issues/', '').split('#').first.split('?').first;
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ResolutionDetailScreen(
              issueId: id,
              initialTitle: threadTitle,
            ),
          ),
        );
      } else {
        await widget.open(path, threadTitle: threadTitle);
      }
    } finally {
      if (mounted) setState(() => opening = false);
    }
    if (mounted) await load();
  }

  String get actionPath => switch (widget.section) {
    'chats' => '/communication?tab=people',
    'groups' => '/communities/new',
    'issues' => '/dashboard?view=resolution&create=issue#new-issue',
    _ => '/knowledge',
  };

  Future<void> handleAction() async {
    if (widget.section == 'chats') {
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const UserDiscoveryScreen()),
      );
    } else if (widget.section == 'groups') {
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const WorkspaceManagementScreen()),
      );
    } else if (widget.section == 'issues') {
      final newId = await Navigator.push<String>(
        context,
        MaterialPageRoute(builder: (_) => const CreateIssueScreen()),
      );
      if (newId != null && mounted) {
        await Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => ResolutionDetailScreen(issueId: newId)),
        );
      }
    } else {
      await open(actionPath);
    }
    if (mounted) await load();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    final matches = visible;
    final action = switch (widget.section) {
      'chats' => 'Find people',
      'groups' => 'Create community',
      'issues' => 'Create issue',
      _ => 'Search all solutions',
    };
    final actionIcon = switch (widget.section) {
      'chats' => Icons.person_search_outlined,
      'groups' => Icons.group_add_outlined,
      'issues' => Icons.add_rounded,
      _ => Icons.search_rounded,
    };
    final path = switch (widget.section) {
      'chats' => '/communication?tab=people',
      'groups' => '/communities/new',
      'issues' => '/dashboard?view=resolution&create=issue#new-issue',
      _ => '/knowledge',
    };
    return Scaffold(
      body: ApexBackground(
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 4, 12, 0),
                child: Row(
                  children: [
                    IconButton(
                      tooltip: 'Back',
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.arrow_back_rounded),
                    ),
                    const SizedBox(width: 2),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.title,
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontSize: 20,
                            ),
                          ),
                          Text(
                            '${items.length} ${items.length == 1 ? 'entry' : 'entries'}',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: muted,
                              fontSize: 10.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'Refresh',
                      onPressed: loading ? null : load,
                      icon: const Icon(Icons.refresh_rounded),
                    ),
                  ],
                ),
              ),
              if (loading || opening)
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 18),
                  child: LinearProgressIndicator(minHeight: 2),
                ),
              Expanded(
                child:
                    error.isNotEmpty
                        ? ApexEmpty(
                          icon:
                              auth
                                  ? Icons.lock_outline_rounded
                                  : Icons.cloud_off_outlined,
                          title: auth ? 'Sign in required' : 'Unavailable',
                          body: error,
                          action: auth ? 'Sign in' : 'Try again',
                          onAction: () => auth ? open('/login') : load(),
                        )
                        : RefreshIndicator(
                          onRefresh: load,
                          child: ListView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: const EdgeInsets.fromLTRB(18, 12, 18, 110),
                            children: [
                              TextField(
                                controller: search,
                                onChanged:
                                    (text) => setState(() => query = text),
                                decoration: InputDecoration(
                                  hintText:
                                      'Search ${widget.title.toLowerCase()}',
                                  prefixIcon: const Icon(
                                    Icons.search_rounded,
                                    size: 20,
                                  ),
                                  isDense: true,
                                ),
                              ),
                              if (filters.length > 1) ...[
                                const SizedBox(height: 10),
                                SizedBox(
                                  height: 34,
                                  child: ListView.separated(
                                    scrollDirection: Axis.horizontal,
                                    itemCount: filters.length,
                                    separatorBuilder:
                                        (_, _) => const SizedBox(width: 7),
                                    itemBuilder: (context, index) {
                                      final option = filters[index];
                                      final active = option == filter;
                                      return GestureDetector(
                                        onTap:
                                            () =>
                                                setState(() => filter = option),
                                        child: AnimatedContainer(
                                          duration: const Duration(
                                            milliseconds: 150,
                                          ),
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 13,
                                          ),
                                          alignment: Alignment.center,
                                          decoration: BoxDecoration(
                                            color:
                                                active
                                                    ? theme.colorScheme.primary
                                                        .withValues(alpha: .16)
                                                    : theme
                                                        .colorScheme
                                                        .surfaceContainerHighest,
                                            borderRadius: BorderRadius.circular(
                                              20,
                                            ),
                                            border: Border.all(
                                              color:
                                                  active
                                                      ? theme
                                                          .colorScheme
                                                          .primary
                                                          .withValues(
                                                            alpha: .55,
                                                          )
                                                      : theme
                                                          .colorScheme
                                                          .outline,
                                            ),
                                          ),
                                          child: Text(
                                            option,
                                            style: TextStyle(
                                              fontSize: 11.5,
                                              fontWeight:
                                                  active
                                                      ? FontWeight.w800
                                                      : FontWeight.w600,
                                              color:
                                                  active
                                                      ? theme
                                                          .colorScheme
                                                          .primary
                                                      : muted,
                                            ),
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              ],
                              const SizedBox(height: 14),
                              if (!loading && matches.isEmpty)
                                ApexEmpty(
                                  icon:
                                      query.isEmpty && filter == 'All'
                                          ? Icons.inbox_outlined
                                          : Icons.search_off_rounded,
                                  title:
                                      query.isEmpty && filter == 'All'
                                          ? 'Nothing here yet'
                                          : 'No matches',
                                  body:
                                      query.isEmpty && filter == 'All'
                                          ? 'New ${widget.title.toLowerCase()} will appear here.'
                                          : 'Try a different name or clear the filters.',
                                  action:
                                      query.isEmpty && filter == 'All'
                                          ? action
                                          : 'Clear filters',
                                  onAction:
                                      () =>
                                          query.isEmpty && filter == 'All'
                                              ? open(path)
                                              : setState(() {
                                                search.clear();
                                                query = '';
                                                filter = 'All';
                                              }),
                                )
                              else
                                for (final entry in matches)
                                  Padding(
                                    padding: const EdgeInsets.only(bottom: 8),
                                    child: ApexEntryTile(
                                      entry: entry,
                                      onTap:
                                          () => open(
                                            entry.path,
                                            threadTitle: entry.title,
                                          ),
                                    ),
                                  ),
                            ],
                          ),
                        ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: handleAction,
        icon: Icon(actionIcon, size: 19),
        label: Text(action),
      ),
    );
  }
}
