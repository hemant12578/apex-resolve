import 'dart:async';
import 'dart:convert';

import 'package:ai_nexconn_chat_plugin/ai_nexconn_chat_plugin.dart' as nc;
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import 'api_client.dart';
import 'apex_ai_screen.dart';
import 'data.dart';
import 'directory.dart';
import 'local_storage.dart';
import 'native_chat.dart';
import 'notification_service.dart';
import 'notification_sheet.dart';
import 'profile_screen.dart';
import 'resolution_screens.dart';
import 'session.dart';
import 'settings.dart';
import 'sign_in.dart';
import 'theme.dart';
import 'ui.dart';
import 'user_discovery.dart';
import 'workspace.dart';
import 'workspace_management.dart';
import 'workspace_routes.dart';

class Home extends StatefulWidget {
  const Home({super.key, required this.firebase, required this.theme});
  final bool firebase;
  final ThemeController theme;

  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  ApexWorkspace? data;
  bool loading = true, signedOut = false;
  String error = '';
  Timer? _notifPollTimer;

  @override
  void initState() {
    super.initState();
    NotificationService.instance.init();
    NotificationService.instance.addListener(_onNotifsChanged);
    load();
    final isTest = WidgetsBinding.instance.runtimeType.toString().contains('Test');
    if (!isTest) {
      _checkIncomingRequests();
      _notifPollTimer = Timer.periodic(const Duration(seconds: 15), (_) {
        _checkIncomingRequests();
      });
    }
  }

  void _onNotifsChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _notifPollTimer?.cancel();
    NotificationService.instance.removeListener(_onNotifsChanged);
    NotificationService.instance.cancelTimers();
    super.dispose();
  }

  Future<void> _checkIncomingRequests() async {
    try {
      final res = await ApexApiClient.searchUsers('');
      final users = (res['users'] as List?) ?? [];
      for (final u in users) {
        if (u is Map) {
          final contact = u['contact'] as Map?;
          final incoming = contact?['incoming'] == true;
          final status = contact?['status']?.toString();
          if (incoming && status == 'pending') {
            final peerId = u['id']?.toString() ?? '';
            final name = u['name']?.toString() ?? u['handle']?.toString() ?? 'Teammate';
            NotificationService.instance.notifyContactRequest(peerId: peerId, peerName: name);
          }
        }
      }
    } catch (_) {}
  }

  Future<void> load() async {
    if (mounted) {
      setState(() {
        loading = true;
        error = '';
        signedOut = false;
      });
    }
    try {
      final next = await loadWorkspace();
      if (mounted) setState(() => data = next);
    } on PlatformException catch (e) {
      if (mounted) {
        setState(() {
          signedOut = e.code == 'SIGN_IN';
          error = signedOut ? '' : 'Could not load your workspace.';
        });
      }
    } catch (_) {
      if (mounted) setState(() => error = 'Could not load your workspace.');
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _signIn() async {
    final path = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => const SignIn()),
    );
    if (path != null && mounted) await load();
  }

  Future<void> open(String path, {String? threadTitle}) async {
    final title = threadTitle ?? 'Workspace';
    var destination = path;

    // Check for issues path
    if (destination.startsWith('/issues/')) {
      final parts = destination.split('?').first.split('#').first.split('/');
      if (parts.length >= 3 && parts[2].isNotEmpty) {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ResolutionDetailScreen(
              issueId: parts[2],
              initialTitle: title != 'Workspace' ? title : null,
            ),
          ),
        );
        if (mounted) await load();
        return;
      }
    }

    // Check for user discovery / people search
    if (destination.contains('tab=people')) {
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const UserDiscoveryScreen()),
      );
      if (mounted) await load();
      return;
    }

    // Check for community creation / management
    if (destination == '/communities/new' || destination.startsWith('/workspaces')) {
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const WorkspaceManagementScreen()),
      );
      if (mounted) await load();
      return;
    }

    // Check for issue creation
    if (destination.contains('create=issue') || destination == '/issues/new') {
      final newId = await Navigator.push<String>(
        context,
        MaterialPageRoute(builder: (_) => const CreateIssueScreen()),
      );
      if (newId != null && mounted) {
        await Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => ResolutionDetailScreen(issueId: newId)),
        );
        await load();
      }
      return;
    }

    // Check for settings
    if (destination.startsWith('/settings')) {
      await openSettings();
      return;
    }

    // Check for Apex AI
    if (destination == '/ai') {
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const ApexAiScreen()),
      );
      return;
    }

    // Check for direct / community chat target
    final target = chatTarget(Uri.parse(workspaceOrigin).resolve(destination));
    if (target != null) {
      if (target.containsKey('issueId')) {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ResolutionDetailScreen(
              issueId: target['issueId']!,
              initialTitle: title != 'Workspace' ? title : null,
            ),
          ),
        );
        if (mounted) await load();
        return;
      }

      Map<String, dynamic>? sessionData;
      final sessionCacheKey =
          'chat_session_${target['channelId'] ?? target['communityId'] ?? target['peerUserId'] ?? destination.replaceAll('/', '_')}';
      try {
        final value = await const MethodChannel(
          'apex/session',
        ).invokeMethod<String>('chat', target);
        if (value != null && value.isNotEmpty) {
          sessionData = jsonDecode(value) as Map<String, dynamic>;
          await LocalVault.save(sessionCacheKey, sessionData);
        }
      } catch (_) {
        final cached = await LocalVault.read(sessionCacheKey);
        if (cached is Map) {
          sessionData = Map<String, dynamic>.from(cached);
        }
      }

      if (sessionData != null && mounted) {
        await Navigator.push<bool>(
          context,
          MaterialPageRoute(
            builder:
                (_) => NativeChat(
                  session: sessionData!,
                  title: title,
                  showWorkspace: false,
                ),
          ),
        );
        if (nc.NCEngine.isInitialized) await nc.NCEngine.disconnect();
        if (mounted) await load();
        return;
      }
      if (!mounted) return;
      if (sessionData == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Chat room not yet cached. Connect to internet once to sync.'),
          ),
        );
        return;
      }
    }
    if (!mounted) return;
    if (destination == '/login' && widget.firebase) {
      final next = await Navigator.push<String>(
        context,
        MaterialPageRoute(builder: (_) => const SignIn()),
      );
      if (!mounted || next == null) return;
      if (next != '/login' && next != '/welcome') return;
      destination = next;
    }
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (_) => Workspace(
              path: destination,
              title: title,
              firebase: widget.firebase,
            ),
      ),
    );
    if (mounted) await load();
  }

  Future<void> openSection(String section, String title, String path) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (_) => Directory(
              section: section,
              title: title,
              open: open,
              workspacePath: path,
            ),
      ),
    );
    if (mounted) await load();
  }

  Future<void> openSettings() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (_) => SettingsScreen(
              theme: widget.theme,
              onOpenWorkspace:
                  () => open('/settings', threadTitle: 'Settings'),
            ),
      ),
    );
    if (mounted) await load();
  }

  void _nav(int index) {
    switch (index) {
      case 1:
        openSection('chats', 'Chats', '/communication?tab=chats');
      case 2:
        openSection('issues', 'Resolution', '/dashboard?view=resolution');
      case 3:
        openSettings();
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    extendBody: true,
    body: ApexBackground(
      child: SafeArea(
        bottom: false,
        child: RefreshIndicator(onRefresh: load, child: _content(context)),
      ),
    ),
    bottomNavigationBar: ApexNavBar(index: 0, onTap: _nav),
  );

  Widget _content(BuildContext context) {
    if (loading && data == null) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          const SizedBox(height: 150),
          const Center(child: ApexMark(size: 62)),
          const SizedBox(height: 22),
          Center(
            child: SizedBox(
              width: 140,
              child: LinearProgressIndicator(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Center(
            child: Text(
              'Opening your workspace…',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      );
    }

    final workspace = data;
    final alerts = workspace?.alerts ?? const <ApexEntry>[];
    final name =
        ApexSession.name.isNotEmpty ? ApexSession.name : 'workspace account';
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(18, 10, 18, 120),
      children: [
        Row(
          children: [
            const ApexMark(size: 38),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Apex Resolve',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      letterSpacing: -.4,
                    ),
                  ),
                  Text(
                    'Explorer',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: muted,
                      fontSize: 11.5,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: 'Notifications',
              onPressed: () => NotificationSheet.show(context, onRefreshHome: load),
              icon: Badge(
                isLabelVisible: NotificationService.instance.unreadCount > 0 || alerts.isNotEmpty,
                label: NotificationService.instance.unreadCount > 0
                    ? Text('${NotificationService.instance.unreadCount}', style: const TextStyle(fontSize: 9))
                    : null,
                backgroundColor: ApexColors.coral,
                child: const Icon(Icons.notifications_none_rounded),
              ),
            ),
            const SizedBox(width: 2),
            GestureDetector(
              onTap: () async {
                final updated = await Navigator.push<bool>(
                  context,
                  MaterialPageRoute(builder: (_) => const ProfileScreen()),
                );
                if (updated == true && mounted) setState(() {});
              },
              child: ApexAvatar(
                initials: initials(name),
                seed: name,
                size: 40,
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        Row(
          children: [
            Container(
              width: 22,
              height: 2,
              color: ApexColors.coral,
            ),
            const SizedBox(width: 8),
            Text(
              'EXPLORER',
              style: theme.textTheme.labelSmall?.copyWith(
                color: ApexColors.coral,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.2,
                fontSize: 10,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Text(
          '${greeting()},\n${firstName(ApexSession.name)}.',
          style: theme.textTheme.headlineLarge?.copyWith(fontSize: 38),
        ),
        const SizedBox(height: 8),
        Text(
          'Your workspace at a glance — alerts first, noise last.',
          style: theme.textTheme.bodyMedium?.copyWith(color: muted),
        ),
        const SizedBox(height: 20),
        _HeroCard(
          alertCount: alerts.length,
          onChats:
              () => openSection(
                'chats',
                'Chats',
                '/communication?tab=chats',
              ),
          onQueue:
              () => openSection(
                'issues',
                'Resolution',
                '/dashboard?view=resolution',
              ),
        ),
        const SizedBox(height: 14),
        ApexCard(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          gradient: ApexGradients.surfaceGlow(theme.brightness),
          borderColor: ApexColors.coral.withValues(alpha: .3),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  gradient: ApexGradients.primary,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Apex AI Copilot', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 2),
                    Text('Troubleshoot issues & structure evidence', style: theme.textTheme.bodySmall?.copyWith(color: muted, fontSize: 11.5)),
                  ],
                ),
              ),
              FilledButton.tonal(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const ApexAiScreen()),
                  );
                },
                child: const Text('Ask AI'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const UserDiscoveryScreen()),
                  );
                },
                icon: const Icon(Icons.person_search_outlined, size: 18),
                label: const Text('Find People'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: FilledButton.icon(
                onPressed: () async {
                  final nav = Navigator.of(context);
                  final newId = await nav.push<String>(
                    MaterialPageRoute(builder: (_) => const CreateIssueScreen()),
                  );
                  if (newId != null && mounted) {
                    await nav.push(
                      MaterialPageRoute(builder: (_) => ResolutionDetailScreen(issueId: newId)),
                    );
                    if (mounted) load();
                  }
                },
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('New Issue'),
              ),
            ),
          ],
        ),
        if (signedOut) ...[
          const SizedBox(height: 14),
          _NoticeCard(
            icon: Icons.lock_clock_outlined,
            title: 'Session expired',
            body: 'Sign in again to load your workspace.',
            action: 'Sign in',
            onAction: _signIn,
          ),
        ] else if (error.isNotEmpty) ...[
          const SizedBox(height: 14),
          _NoticeCard(
            icon: Icons.cloud_off_outlined,
            title: 'Workspace unavailable',
            body: error,
            action: 'Retry',
            onAction: load,
          ),
        ],
        if (workspace != null) ...[
          const SizedBox(height: 14),
          _StatGrid(
            open: workspace.openCount,
            working: workspace.workingCount,
            review: workspace.reviewCount,
            verified: workspace.verifiedCount,
          ),
          const SizedBox(height: 24),
          ApexSectionHeader(
            title: 'Alerts, not noise',
            subtitle: 'Needs attention',
            action: 'Queue',
            onAction:
                () => openSection(
                  'issues',
                  'Resolution',
                  '/dashboard?view=resolution',
                ),
          ),
          const SizedBox(height: 10),
          if (alerts.isEmpty)
            ApexCard(
              child: Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: ApexColors.green.withValues(alpha: .13),
                      borderRadius: BorderRadius.circular(13),
                      border: Border.all(
                        color: ApexColors.green.withValues(alpha: .3),
                      ),
                    ),
                    child: const Icon(
                      Icons.check_circle_outline_rounded,
                      color: ApexColors.green,
                      size: 21,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'You are all caught up.',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontSize: 14,
                          ),
                        ),
                        Text(
                          'No reviews, requests or critical issues are waiting.',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: muted,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            )
          else
            for (final alert in alerts.take(4))
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _AlertTile(
                  entry: alert,
                  onTap: () => open(alert.path, threadTitle: alert.title),
                ),
              ),
          const SizedBox(height: 18),
          ApexSectionHeader(
            title: 'Start something',
            subtitle: 'Quick actions',
          ),
          const SizedBox(height: 10),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 9,
            crossAxisSpacing: 9,
            childAspectRatio: 1.30,
            children: [
              _QuickAction(
                icon: Icons.forum_outlined,
                title: 'Messages',
                subtitle: 'Find a teammate',
                onTap:
                    () => openSection(
                      'chats',
                      'Chats',
                      '/communication?tab=chats',
                    ),
              ),
              _QuickAction(
                icon: Icons.groups_outlined,
                title: 'Communities',
                subtitle: 'Bring people together',
                onTap:
                    () => openSection(
                      'groups',
                      'Communities',
                      '/communication?tab=groups',
                    ),
              ),
              _QuickAction(
                icon: Icons.fact_check_outlined,
                title: 'Resolution',
                subtitle: 'Track a problem',
                onTap:
                    () => openSection(
                      'issues',
                      'Resolution',
                      '/dashboard?view=resolution',
                    ),
              ),
              _QuickAction(
                icon: Icons.auto_awesome_outlined,
                title: 'Apex AI',
                subtitle: 'Get a second look',
                onTap:
                    () => open(
                      '/communication?tab=ai',
                      threadTitle: 'Apex AI',
                    ),
              ),
            ],
          ),
          if (workspace.pulse.isNotEmpty) ...[
            const SizedBox(height: 22),
            ApexSectionHeader(
              title: 'People and groups',
              subtitle: 'Your conversations',
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 96,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: workspace.pulse.length,
                separatorBuilder: (_, _) => const SizedBox(width: 14),
                itemBuilder: (context, index) {
                  final entry = workspace.pulse[index];
                  return GestureDetector(
                    onTap:
                        () => open(entry.path, threadTitle: entry.title),
                    child: SizedBox(
                      width: 64,
                      child: Column(
                        children: [
                          ApexAvatar(
                            initials: entry.initials,
                            seed: entry.seed,
                            size: 58,
                            ring: true,
                          ),
                          const SizedBox(height: 6),
                          Text(
                            entry.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodySmall?.copyWith(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
          if (workspace.issues.isNotEmpty) ...[
            const SizedBox(height: 22),
            ApexSectionHeader(
              title: 'Resolution queue',
              subtitle: 'Most recently updated',
              action: 'See all',
              onAction:
                  () => openSection(
                    'issues',
                    'Resolution',
                    '/dashboard?view=resolution',
                  ),
            ),
            const SizedBox(height: 10),
            for (final issue in workspace.issues.take(5))
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: ApexEntryTile(
                  entry: issue,
                  onTap: () => open(issue.path, threadTitle: issue.title),
                ),
              ),
          ],
          const SizedBox(height: 20),
          Center(
            child: Text(
              'Apex Resolve · conversation → verified fix',
              style: theme.textTheme.bodySmall?.copyWith(
                color: muted,
                fontSize: 10.5,
              ),
            ),
          ),
        ],
      ],
    );
  }

}

class _HeroCard extends StatelessWidget {
  const _HeroCard({
    required this.alertCount,
    required this.onChats,
    required this.onQueue,
  });
  final int alertCount;
  final VoidCallback onChats, onQueue;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ApexCard(
      gradient: ApexGradients.surfaceGlow(theme.brightness),
      borderColor: ApexColors.coral.withValues(alpha: .28),
      padding: const EdgeInsets.all(18),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            right: -46,
            top: -54,
            child: Container(
              width: 170,
              height: 170,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: ApexColors.coral.withValues(alpha: .16),
                  width: 1.2,
                ),
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.auto_awesome_rounded,
                    size: 14,
                    color: ApexColors.coral,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'LIVE WORKSPACE',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: ApexColors.coral,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1,
                      fontSize: 9.5,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                alertCount == 0
                    ? 'Everything is calm.'
                    : '$alertCount thing${alertCount == 1 ? '' : 's'} want your attention',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontSize: 25,
                  height: 1.08,
                ),
              ),
              const SizedBox(height: 7),
              Text(
                'Review what is stuck, jump into a conversation, or start the next resolution.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: onChats,
                      icon: const Icon(Icons.forum_rounded, size: 18),
                      label: const Text('Open chats'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: onQueue,
                      icon: const Icon(Icons.fact_check_outlined, size: 18),
                      label: const Text('Queue'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatGrid extends StatelessWidget {
  const _StatGrid({
    required this.open,
    required this.working,
    required this.review,
    required this.verified,
  });
  final int open, working, review, verified;

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 9,
      crossAxisSpacing: 9,
      childAspectRatio: 1.72,
      children: [
        _StatCard(
          label: 'Open',
          value: open,
          caption: 'need a fix',
          color: ApexColors.coral,
        ),
        _StatCard(
          label: 'Working',
          value: working,
          caption: 'in progress',
          color: ApexColors.cyan,
        ),
        _StatCard(
          label: 'Review',
          value: review,
          caption: 'waiting on proof',
          color: ApexColors.violet,
        ),
        _StatCard(
          label: 'Verified',
          value: verified,
          caption: 'closed with evidence',
          color: ApexColors.green,
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.value,
    required this.caption,
    required this.color,
  });
  final String label, caption;
  final int value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ApexCard(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              const SizedBox(width: 6),
              Text(
                label.toUpperCase(),
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w800,
                  letterSpacing: .8,
                  fontSize: 9,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '$value',
            style: theme.textTheme.headlineMedium?.copyWith(
              fontSize: 26,
              color: color,
              height: 1,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            caption,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }
}

class _AlertTile extends StatelessWidget {
  const _AlertTile({required this.entry, required this.onTap});
  final ApexEntry entry;
  final VoidCallback onTap;

  String get detail {
    if (entry.needsReview) {
      return 'Evidence is waiting for an independent verifier.';
    }
    if (entry.isCritical) return 'Critical priority needs a resolver.';
    if (entry.isOpen) return 'Open issue needs a fix.';
    return 'Review this issue.';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final status = entry.status;
    return ApexCard(
      onTap: onTap,
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: status.color.withValues(alpha: .13),
              borderRadius: BorderRadius.circular(13),
              border: Border.all(color: status.color.withValues(alpha: .3)),
            ),
            child: Icon(status.icon, color: status.color, size: 20),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  detail,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontSize: 11.5,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          Icon(
            Icons.arrow_outward_rounded,
            size: 16,
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ],
      ),
    );
  }
}

class _QuickAction extends StatelessWidget {
  const _QuickAction({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });
  final IconData icon;
  final String title, subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ApexCard(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: ApexColors.coral.withValues(alpha: .13),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(icon, color: ApexColors.coral, size: 18),
          ),
          const SizedBox(height: 9),
          Text(
            title,
            style: theme.textTheme.titleMedium?.copyWith(
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 1),
          Text(
            subtitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontSize: 10.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _NoticeCard extends StatelessWidget {
  const _NoticeCard({
    required this.icon,
    required this.title,
    required this.body,
    required this.action,
    required this.onAction,
  });
  final IconData icon;
  final String title, body, action;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ApexCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: ApexColors.coral, size: 20),
              const SizedBox(width: 8),
              Text(title, style: theme.textTheme.titleMedium),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            body,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 10),
          FilledButton(onPressed: onAction, child: Text(action)),
        ],
      ),
    );
  }
}
