import 'dart:async';
import 'package:material_ui/material_ui.dart';

import 'api_client.dart';
import 'local_storage.dart';
import 'native_chat.dart';
import 'theme.dart';
import 'ui.dart';

class UserDiscoveryScreen extends StatefulWidget {
  const UserDiscoveryScreen({super.key});

  @override
  State<UserDiscoveryScreen> createState() => _UserDiscoveryScreenState();
}

class _UserDiscoveryScreenState extends State<UserDiscoveryScreen> {
  final searchCtrl = TextEditingController();
  Timer? debounce;
  List<Map<String, dynamic>> users = [];
  bool loading = false;
  String error = '';
  int page = 1;
  bool hasMore = false;

  @override
  void initState() {
    super.initState();
    loadUsers('');
  }

  @override
  void dispose() {
    debounce?.cancel();
    searchCtrl.dispose();
    super.dispose();
  }

  void onSearchChanged(String text) {
    debounce?.cancel();
    debounce = Timer(const Duration(milliseconds: 320), () {
      loadUsers(text.trim());
    });
  }

  Future<void> loadUsers(String query, {bool nextPage = false}) async {
    if (loading) return;
    setState(() {
      loading = true;
      if (!nextPage) {
        error = '';
        page = 1;
      }
    });

    try {
      final currentPage = nextPage ? page + 1 : 1;
      final res = await ApexApiClient.searchUsers(query, page: currentPage);
      final items = (res['items'] as List?)?.cast<Map<String, dynamic>>() ?? [];
      final more = res['hasMore'] == true;

      if (mounted) {
        setState(() {
          if (nextPage) {
            users.addAll(items);
            page = currentPage;
          } else {
            users = items;
            page = 1;
          }
          hasMore = more;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          error = 'Could not load members. Check your connection.';
        });
      }
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> openChat(String peerId, String peerName) async {
    Map<String, dynamic>? session;
    final cacheKey = 'chat_session_peer_$peerId';
    try {
      session = await ApexApiClient.chatSession(peerId: peerId);
      await LocalVault.save(cacheKey, session);
    } catch (_) {
      final cached = await LocalVault.read(cacheKey);
      if (cached is Map) {
        session = Map<String, dynamic>.from(cached);
      }
    }
    if (!mounted) return;
    if (session != null) {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => NativeChat(
            session: session!,
            title: peerName,
            showWorkspace: false,
          ),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Conversation not yet cached. Connect to internet once to sync.'),
        ),
      );
    }
  }

  Future<void> sendRequest(String peerId, String name) async {
    try {
      final res = await ApexApiClient.contactAction(peer: peerId, operation: 'request');
      if (res['ok'] == true && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Message request sent to $name')),
        );
        loadUsers(searchCtrl.text.trim());
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not send message request.')),
        );
      }
    }
  }

  Future<void> unlockWithPin(String peerId, String name) async {
    final pinCtrl = TextEditingController();
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Unlock Chat with $name'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Enter the contact PIN shared by this user to start messaging immediately.',
              style: TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: pinCtrl,
              autofocus: true,
              obscureText: true,
              keyboardType: TextInputType.text,
              maxLength: 12,
              decoration: InputDecoration(
                labelText: 'Contact PIN',
                counterText: '',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Unlock'),
          ),
        ],
      ),
    );

    if (result == true && pinCtrl.text.trim().isNotEmpty) {
      try {
        final res = await ApexApiClient.contactAction(
          peer: peerId,
          operation: 'pin',
          pin: pinCtrl.text.trim(),
        );

        if (res['ok'] == true && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Chat unlocked with $name!')),
          );
          await openChat(peerId, name);
          loadUsers(searchCtrl.text.trim());
        } else if (res['invalidPin'] == true && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('That PIN did not match.')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('PIN unlock failed.')),
          );
        }
      }
    }
  }

  Future<void> acceptRequest(String peerId, String name) async {
    try {
      final res = await ApexApiClient.contactAction(peer: peerId, operation: 'accept');
      if (res['ok'] == true && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Chat request accepted from $name')),
        );
        loadUsers(searchCtrl.text.trim());
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Find People'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: ApexBackground(
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: TextField(
                  controller: searchCtrl,
                  onChanged: onSearchChanged,
                  decoration: InputDecoration(
                    hintText: 'Search by name or handle (@alex…)',
                    prefixIcon: const Icon(Icons.search_rounded),
                    suffixIcon: searchCtrl.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear_rounded),
                            onPressed: () {
                              searchCtrl.clear();
                              loadUsers('');
                            },
                          )
                        : null,
                    filled: true,
                    fillColor: theme.colorScheme.surfaceContainerHighest,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(color: theme.colorScheme.outline),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(color: theme.colorScheme.outline),
                    ),
                  ),
                ),
              ),
              if (error.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: ApexCard(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline_rounded, color: ApexColors.danger),
                        const SizedBox(width: 8),
                        Expanded(child: Text(error, style: const TextStyle(fontSize: 12))),
                        TextButton(
                          onPressed: () => loadUsers(searchCtrl.text.trim()),
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                ),
              Expanded(
                child: loading && users.isEmpty
                    ? const Center(child: CircularProgressIndicator())
                    : users.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.people_outline_rounded, size: 48, color: ApexColors.muted),
                                const SizedBox(height: 12),
                                Text(
                                  searchCtrl.text.isEmpty
                                      ? 'No workspace members found'
                                      : 'No members match "${searchCtrl.text}"',
                                  style: theme.textTheme.titleMedium,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Try searching by full display name or @handle',
                                  style: theme.textTheme.bodySmall?.copyWith(color: muted),
                                ),
                              ],
                            ),
                          )
                        : RefreshIndicator(
                            onRefresh: () => loadUsers(searchCtrl.text.trim()),
                            child: ListView.separated(
                              padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                              itemCount: users.length + (hasMore ? 1 : 0),
                              separatorBuilder: (_, _) => const SizedBox(height: 8),
                              itemBuilder: (context, index) {
                                if (index == users.length) {
                                  return Center(
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(vertical: 16),
                                      child: OutlinedButton(
                                        onPressed: () => loadUsers(searchCtrl.text.trim(), nextPage: true),
                                        child: const Text('Load more'),
                                      ),
                                    ),
                                  );
                                }
                                final u = users[index];
                                final name = u['displayName'] as String? ?? 'Member';
                                final handle = u['handle'] as String? ?? '';
                                final peerId = u['id'] as String;
                                final status = u['contactStatus'] as String? ?? 'none';
                                final incoming = u['incoming'] == true;

                                return ApexCard(
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                  child: Row(
                                    children: [
                                      ApexAvatar(
                                        initials: initials(name),
                                        seed: name,
                                        size: 44,
                                        ring: true,
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              name,
                                              style: theme.textTheme.titleSmall?.copyWith(
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              handle,
                                              style: theme.textTheme.bodySmall?.copyWith(
                                                color: muted,
                                                fontSize: 11.5,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      if (status == 'accepted')
                                        FilledButton.tonalIcon(
                                          onPressed: () => openChat(peerId, name),
                                          icon: const Icon(Icons.chat_bubble_outline_rounded, size: 16),
                                          label: const Text('Chat'),
                                        )
                                      else if (incoming && status == 'pending')
                                        Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            FilledButton(
                                              onPressed: () => acceptRequest(peerId, name),
                                              style: FilledButton.styleFrom(
                                                padding: const EdgeInsets.symmetric(horizontal: 12),
                                              ),
                                              child: const Text('Accept'),
                                            ),
                                          ],
                                        )
                                      else if (status == 'pending')
                                        Chip(
                                          label: const Text('Requested', style: TextStyle(fontSize: 11)),
                                          backgroundColor: theme.colorScheme.surfaceContainerHighest,
                                          padding: EdgeInsets.zero,
                                        )
                                      else
                                        Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            IconButton(
                                              tooltip: 'Unlock with PIN',
                                              icon: const Icon(Icons.pin_outlined, color: ApexColors.coral),
                                              onPressed: () => unlockWithPin(peerId, name),
                                            ),
                                            FilledButton.tonal(
                                              onPressed: () => sendRequest(peerId, name),
                                              style: FilledButton.styleFrom(
                                                padding: const EdgeInsets.symmetric(horizontal: 12),
                                              ),
                                              child: const Text('Connect'),
                                            ),
                                          ],
                                        ),
                                    ],
                                  ),
                                );
                              },
                            ),
                          ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
