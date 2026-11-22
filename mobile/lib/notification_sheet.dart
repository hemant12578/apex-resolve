import 'package:material_ui/material_ui.dart';
import 'api_client.dart';
import 'notification_service.dart';
import 'theme.dart';

class NotificationSheet extends StatefulWidget {
  final VoidCallback? onRefreshHome;

  const NotificationSheet({super.key, this.onRefreshHome});

  static Future<void> show(BuildContext context, {VoidCallback? onRefreshHome}) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => NotificationSheet(onRefreshHome: onRefreshHome),
    );
  }

  @override
  State<NotificationSheet> createState() => _NotificationSheetState();
}

class _NotificationSheetState extends State<NotificationSheet> {
  final notifService = NotificationService.instance;
  final Set<String> _processing = {};

  @override
  void initState() {
    super.initState();
    notifService.addListener(_onChanged);
  }

  @override
  void dispose() {
    notifService.removeListener(_onChanged);
    super.dispose();
  }

  void _onChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _acceptRequest(ApexNotification n) async {
    if (n.peerId == null) return;
    setState(() => _processing.add(n.id));
    try {
      final res = await ApexApiClient.contactAction(peer: n.peerId!, operation: 'accept');
      if (res['ok'] == true && mounted) {
        notifService.removeNotification(n.id);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Chat request accepted for ${n.peerName ?? 'user'}!'),
            backgroundColor: ApexColors.green,
          ),
        );
        widget.onRefreshHome?.call();
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not accept request. Check connection.')),
        );
      }
    } finally {
      if (mounted) setState(() => _processing.remove(n.id));
    }
  }

  Future<void> _declineRequest(ApexNotification n) async {
    if (n.peerId == null) return;
    setState(() => _processing.add(n.id));
    try {
      await ApexApiClient.contactAction(peer: n.peerId!, operation: 'decline');
      if (mounted) {
        notifService.removeNotification(n.id);
        widget.onRefreshHome?.call();
      }
    } catch (_) {} finally {
      if (mounted) setState(() => _processing.remove(n.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final items = notifService.notifications;

    return DraggableScrollableSheet(
      initialChildSize: 0.65,
      minChildSize: 0.4,
      maxChildSize: 0.9,
      builder: (ctx, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            border: Border.all(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.2)),
            boxShadow: const [
              BoxShadow(color: Colors.black45, blurRadius: 20, spreadRadius: 4),
            ],
          ),
          child: Column(
            children: [
              // Pull bar
              Center(
                child: Container(
                  margin: const EdgeInsets.only(top: 10, bottom: 6),
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.outline.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // Title Bar
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(7),
                      decoration: BoxDecoration(
                        color: ApexColors.coral.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.notifications_active_rounded, color: ApexColors.coral, size: 20),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      'Notifications',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const Spacer(),
                    if (items.isNotEmpty)
                      TextButton(
                        onPressed: () => notifService.markAllAsRead(),
                        child: const Text('Mark all read', style: TextStyle(fontSize: 12, color: ApexColors.coral)),
                      ),
                  ],
                ),
              ),

              const Divider(height: 1),

              // Content List
              Expanded(
                child: items.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.notifications_none_rounded, size: 48, color: theme.colorScheme.outline),
                            const SizedBox(height: 12),
                            Text('No notifications yet', style: theme.textTheme.titleSmall),
                            const SizedBox(height: 4),
                            Text(
                              'Requests, reviews, and updates will appear here.',
                              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline),
                            ),
                          ],
                        ),
                      )
                    : ListView.separated(
                        controller: scrollController,
                        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                        itemCount: items.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final n = items[index];
                          final isBusy = _processing.contains(n.id);

                          return Container(
                            decoration: BoxDecoration(
                              color: n.isRead
                                  ? theme.colorScheme.surfaceContainer.withValues(alpha: 0.4)
                                  : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.7),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: n.isRead
                                    ? Colors.transparent
                                    : ApexColors.coral.withValues(alpha: 0.3),
                              ),
                            ),
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      n.type == NotificationType.contactRequest
                                          ? Icons.person_add_rounded
                                          : n.type == NotificationType.resolutionReview
                                              ? Icons.verified_user_rounded
                                              : Icons.tips_and_updates_rounded,
                                      size: 18,
                                      color: n.type == NotificationType.contactRequest
                                          ? Colors.cyan
                                          : n.type == NotificationType.resolutionReview
                                              ? Colors.amber
                                              : ApexColors.coral,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        n.title,
                                        style: theme.textTheme.bodyMedium?.copyWith(
                                          fontWeight: n.isRead ? FontWeight.w500 : FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    Text(
                                      _formatTime(n.timestamp),
                                      style: theme.textTheme.labelSmall?.copyWith(
                                        color: theme.colorScheme.outline,
                                        fontSize: 10,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  n.body,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant,
                                    fontSize: 12.5,
                                  ),
                                ),

                                // Actions for Contact Request
                                if (n.type == NotificationType.contactRequest && n.peerId != null) ...[
                                  const SizedBox(height: 10),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    children: [
                                      TextButton(
                                        onPressed: isBusy ? null : () => _declineRequest(n),
                                        style: TextButton.styleFrom(
                                          visualDensity: VisualDensity.compact,
                                          padding: const EdgeInsets.symmetric(horizontal: 10),
                                        ),
                                        child: const Text('Decline', style: TextStyle(fontSize: 12, color: Colors.grey)),
                                      ),
                                      const SizedBox(width: 8),
                                      FilledButton(
                                        onPressed: isBusy ? null : () => _acceptRequest(n),
                                        style: FilledButton.styleFrom(
                                          backgroundColor: ApexColors.coral,
                                          visualDensity: VisualDensity.compact,
                                          padding: const EdgeInsets.symmetric(horizontal: 14),
                                        ),
                                        child: isBusy
                                            ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                            : const Text('Accept', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                      ),
                                    ],
                                  ),
                                ],
                              ],
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  String _formatTime(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}
