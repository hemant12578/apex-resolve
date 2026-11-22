import 'dart:async';

import 'package:ai_nexconn_chat_plugin/ai_nexconn_chat_plugin.dart' as nc;
import 'package:material_ui/material_ui.dart';

import 'theme.dart';
import 'ui.dart';

class NativeChat extends StatefulWidget {
  const NativeChat({
    super.key,
    required this.session,
    required this.title,
    this.showWorkspace = false,
  });
  final Map<String, dynamic> session;
  final String title;
  final bool showWorkspace;
  @override
  State<NativeChat> createState() => _NativeChatState();
}

class _NativeChatState extends State<NativeChat> {
  final draft = TextEditingController();
  final messages = <String, nc.Message>{};
  late final channel = nc.GroupChannel(widget.session['channelId'] as String);
  late final history = nc.MessagesQuery(
    nc.MessagesQueryParams(
      channelIdentifier: channel.channelIdentifier,
      pageSize: 20,
      startTime: DateTime.now().millisecondsSinceEpoch,
    ),
  );
  bool connected = false, sending = false, paging = false;
  String status = 'Connecting…';
  late final Future<void> startup;

  @override
  void initState() {
    super.initState();
    startup = connect();
  }

  Future<void> connect() async {
    try {
      final session = widget.session;
      if (!nc.NCEngine.isInitialized) {
        await nc.NCEngine.initialize(
          nc.InitParams(
            appKey: session['appKey'],
            areaCode: nc.AreaCode.values.byName(
              (session['region'] as String).toLowerCase(),
            ),
            enablePush: false,
          ),
        );
      }
      if (!mounted) return;
      nc.NCEngine.addMessageHandler(
        'apex.thread',
        nc.MessageHandler(
          onMessageReceived: (e) {
            if (mounted &&
                e.message.channelId == channel.channelIdentifier.channelId) {
              setState(() => merge(e.message));
            }
          },
        ),
      );
      final ready = Completer<void>();
      await nc.NCEngine.connect(
        nc.ConnectParams(token: session['token'], timeout: 15),
        (id, error) {
          if (ready.isCompleted) return;
          if (id == session['userId'] && (error?.code ?? 0) == 0) {
            ready.complete();
          } else {
            ready.completeError(StateError('Connection failed'));
          }
        },
      );
      await ready.future.timeout(const Duration(seconds: 18));
      if (!mounted) return;
      setState(() {
        connected = true;
        status = 'Connected';
      });
      await loadHistory();
    } catch (_) {
      if (mounted) {
        setState(
          () =>
              status =
                  'Unable to connect. Go back and reopen the conversation.',
        );
      }
    }
  }

  void merge(nc.Message message) {
    final key = message.messageId;
    if (key != null) messages[key] = message;
  }

  Future<void> loadHistory() async {
    if (paging || !history.hasMore) return;
    setState(() => paging = true);
    try {
      final done = Completer<void>();
      await history.loadNextPage((page, error) {
        if (done.isCompleted) return;
        if ((error?.code ?? 0) != 0) {
          debugPrint('Chat history SDK status ${error?.code}');
          done.completeError(StateError('History unavailable'));
          return;
        }
        if (mounted) {
          setState(() {
            for (final message in page?.data ?? <nc.Message>[]) {
              merge(message);
            }
          });
        }
        done.complete();
      });
      await done.future.timeout(const Duration(seconds: 15));
    } catch (_) {
      if (mounted) {
        setState(
          () => status = 'History unavailable. Retry with Load earlier.',
        );
      }
    } finally {
      if (mounted) setState(() => paging = false);
    }
  }

  Future<void> send() async {
    final text = draft.text.trim();
    if (text.isEmpty || sending || !connected) return;
    setState(() => sending = true);
    try {
      final done = Completer<void>();
      await channel.sendMessage(
        nc.SendMessageParams(messageParams: nc.TextMessageParams(text: text)),
        callback: nc.SendMessageCallback(
          onMessageSent: (code, message) {
            if (done.isCompleted) return;
            if (code != 0 || message == null) {
              done.completeError(StateError('Send failed'));
              return;
            }
            if (mounted) setState(() => merge(message));
            done.complete();
          },
        ),
      );
      await done.future.timeout(const Duration(seconds: 20));
      if (mounted) {
        draft.clear();
        setState(() => status = 'Connected');
      }
    } catch (_) {
      if (mounted) {
        setState(
          () =>
              status =
                  'Send unconfirmed. Check the conversation before retrying.',
        );
      }
    } finally {
      if (mounted) setState(() => sending = false);
    }
  }

  @override
  void dispose() {
    nc.NCEngine.removeMessageHandler('apex.thread');
    draft.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    final list =
        messages.values.toList()
          ..sort((a, b) => (b.sentTime ?? 0).compareTo(a.sentTime ?? 0));
    final peer = widget.session['peerName']?.toString() ?? widget.title;
    final group = widget.session.containsKey('communityId');
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Back',
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
        titleSpacing: 0,
        title: Row(
          children: [
            ApexAvatar(
              initials: initials(peer),
              seed: peer,
              size: 36,
              ring: !group,
              icon: group ? Icons.groups_rounded : null,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    peer,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Row(
                    children: [
                      Container(
                        width: 5,
                        height: 5,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: connected ? ApexColors.green : ApexColors.amber,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        status,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: connected ? ApexColors.green : muted,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          if (widget.showWorkspace)
            IconButton(
              tooltip: 'Conversation details and actions',
              icon: const Icon(Icons.more_horiz_rounded),
              onPressed: () => Navigator.pop(context, true),
            ),
          const SizedBox(width: 4),
        ],
      ),
      body: ApexBackground(
        chat: true,
        child: SafeArea(
          top: false,
          child: Column(
            children: [
              Expanded(
                child:
                    list.isEmpty
                        ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 66,
                                height: 66,
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      ApexColors.coral.withValues(alpha: .2),
                                      ApexColors.rose.withValues(alpha: .1),
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(22),
                                  border: Border.all(
                                    color: theme.colorScheme.outline,
                                  ),
                                ),
                                child: const Icon(
                                  Icons.forum_outlined,
                                  color: ApexColors.coral,
                                  size: 28,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                connected && !paging
                                    ? 'No messages yet'
                                    : 'Loading conversation…',
                                style: theme.textTheme.titleMedium,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                connected
                                    ? 'Say hello and get the resolution moving.'
                                    : 'Reconnecting to Apex chat.',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: muted,
                                ),
                              ),
                            ],
                          ),
                        )
                        : ListView.builder(
                          reverse: true,
                          padding: const EdgeInsets.fromLTRB(12, 14, 12, 10),
                          itemCount: list.length + (history.hasMore ? 1 : 0),
                          itemBuilder: (context, i) {
                            if (i == list.length) {
                              return Center(
                                child: Padding(
                                  padding: const EdgeInsets.only(bottom: 10),
                                  child: OutlinedButton.icon(
                                    onPressed: paging ? null : loadHistory,
                                    icon:
                                        paging
                                            ? const SizedBox(
                                              width: 12,
                                              height: 12,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 1.6,
                                              ),
                                            )
                                            : const Icon(
                                              Icons.history_rounded,
                                              size: 15,
                                            ),
                                    label: Text(
                                      paging ? 'Loading…' : 'Load earlier',
                                      style: const TextStyle(fontSize: 11),
                                    ),
                                  ),
                                ),
                              );
                            }
                            final m = list[i];
                            final mine =
                                m.senderUserId == widget.session['userId'];
                            final body =
                                m is nc.TextMessage
                                    ? m.text ?? ''
                                    : 'Open the workspace thread to view this update.';
                            final sender =
                                mine
                                    ? 'You'
                                    : m.userInfo?.name ??
                                        widget.session['peerName'] ??
                                        'Member';
                            final prev =
                                i + 1 < list.length ? list[i + 1] : null;
                            final showDate =
                                m.sentTime != null &&
                                m.sentTime! > 0 &&
                                (prev == null ||
                                    _isDifferentDay(m.sentTime, prev.sentTime));
                            return Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (showDate)
                                  _DateBadge(label: chatDayLabel(m.sentTime)),
                                _Bubble(
                                  mine: mine,
                                  body: body,
                                  sender: group ? sender : null,
                                  time: _clock(m.sentTime),
                                ),
                              ],
                            );
                          },
                        ),
              ),
              _Composer(
                draft: draft,
                enabled: connected && !sending,
                sending: sending,
                onSend: send,
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _clock(int? milliseconds) {
    if (milliseconds == null || milliseconds <= 0) return '';
    final date = DateTime.fromMillisecondsSinceEpoch(milliseconds);
    return '${date.hour.toString().padLeft(2, '0')}:'
        '${date.minute.toString().padLeft(2, '0')}';
  }

  bool _isDifferentDay(int? t1, int? t2) {
    if (t1 == null || t2 == null || t1 <= 0 || t2 <= 0) return false;
    final d1 = DateTime.fromMillisecondsSinceEpoch(t1);
    final d2 = DateTime.fromMillisecondsSinceEpoch(t2);
    return d1.year != d2.year || d1.month != d2.month || d1.day != d2.day;
  }
}

class _DateBadge extends StatelessWidget {
  const _DateBadge({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    if (label.isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context);
    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 8),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: .7),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: theme.colorScheme.outline.withValues(alpha: .5),
          ),
        ),
        child: Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            fontSize: 10.5,
            fontWeight: FontWeight.w600,
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({
    required this.mine,
    required this.body,
    required this.time,
    this.sender,
  });
  final bool mine;
  final String body, time;
  final String? sender;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final radius = BorderRadius.only(
      topLeft: const Radius.circular(16),
      topRight: const Radius.circular(16),
      bottomLeft: Radius.circular(mine ? 16 : 5),
      bottomRight: Radius.circular(mine ? 5 : 16),
    );
    return Padding(
      padding: EdgeInsets.only(
        bottom: 5,
        left: mine ? 46 : 0,
        right: mine ? 0 : 46,
      ),
      child: Column(
        crossAxisAlignment:
            mine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          if (sender != null && !mine)
            Padding(
              padding: const EdgeInsets.only(left: 6, bottom: 3),
              child: Text(
                sender!,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: ApexColors.coral,
                  fontWeight: FontWeight.w800,
                  fontSize: 10,
                ),
              ),
            ),
          Container(
            padding: const EdgeInsets.fromLTRB(12, 9, 12, 7),
            decoration: BoxDecoration(
              gradient: mine ? ApexGradients.bubble : null,
              color: mine ? null : theme.colorScheme.surface,
              borderRadius: radius,
              border:
                  mine
                      ? null
                      : Border.all(color: theme.colorScheme.outline),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(
                    alpha: theme.brightness == Brightness.dark ? .16 : .05,
                  ),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                SelectableText(
                  body,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: mine ? Colors.white : theme.colorScheme.onSurface,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      time,
                      style: TextStyle(
                        fontSize: 9,
                        color:
                            mine
                                ? Colors.white.withValues(alpha: .75)
                                : theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Composer extends StatelessWidget {
  const _Composer({
    required this.draft,
    required this.enabled,
    required this.sending,
    required this.onSend,
  });
  final TextEditingController draft;
  final bool enabled, sending;
  final Future<void> Function() onSend;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface.withValues(alpha: .92),
        border: Border(top: BorderSide(color: theme.colorScheme.outline)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: theme.colorScheme.outline),
              ),
              child: TextField(
                controller: draft,
                enabled: enabled,
                minLines: 1,
                maxLines: 4,
                maxLength: 2000,
                textCapitalization: TextCapitalization.sentences,
                style: theme.textTheme.bodyMedium?.copyWith(fontSize: 14),
                decoration: InputDecoration(
                  hintText: sending ? 'Sending…' : 'Message',
                  counterText: '',
                  filled: false,
                  isDense: true,
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 11),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          ValueListenableBuilder<TextEditingValue>(
            valueListenable: draft,
            builder:
                (context, value, _) {
                  final canSend =
                      enabled && !sending && value.text.trim().isNotEmpty;
                  return Semantics(
                    button: true,
                    enabled: canSend,
                    label: sending ? 'Sending message' : 'Send message',
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: canSend ? onSend : null,
                        borderRadius: BorderRadius.circular(22),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 160),
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            gradient:
                                canSend ? ApexGradients.primary : null,
                            color:
                                canSend
                                    ? null
                                    : theme.colorScheme.surfaceContainerHighest,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color:
                                  canSend
                                      ? Colors.transparent
                                      : theme.colorScheme.outline,
                            ),
                          ),
                          child: Icon(
                            sending
                                ? Icons.hourglass_top_rounded
                                : Icons.arrow_upward_rounded,
                            size: 21,
                            color:
                                canSend
                                    ? ApexColors.accentInk
                                    : theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ),
                  );
                },
          ),
        ],
      ),
    );
  }
}
