import 'dart:async';
import 'package:ai_nexconn_chat_plugin/ai_nexconn_chat_plugin.dart' as nc;
import 'package:material_ui/material_ui.dart';

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
      pageSize: 50,
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
    final list =
        messages.values.toList()
          ..sort((a, b) => (b.sentTime ?? 0).compareTo(a.sentTime ?? 0));
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: [
          if (widget.showWorkspace)
            IconButton(
              tooltip: 'Conversation details and actions',
              icon: const Icon(Icons.more_horiz),
              onPressed: () => Navigator.pop(context, true),
            ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Expanded(child: Text(status)),
                  if (connected && history.hasMore)
                    TextButton(
                      onPressed: paging ? null : loadHistory,
                      child: const Text('Load earlier'),
                    ),
                ],
              ),
            ),
            Expanded(
              child:
                  list.isEmpty
                      ? Center(
                        child: Text(
                          connected && !paging
                              ? 'No messages yet'
                              : 'Loading conversation…',
                        ),
                      )
                      : ListView.builder(
                        reverse: true,
                        padding: const EdgeInsets.all(12),
                        itemCount: list.length,
                        itemBuilder: (context, i) {
                          final m = list[i],
                              mine = m.senderUserId == widget.session['userId'];
                          final body =
                              m is nc.TextMessage
                                  ? m.text ?? ''
                                  : 'Open the workspace thread to view this update.';
                          return Align(
                            alignment:
                                mine
                                    ? Alignment.centerRight
                                    : Alignment.centerLeft,
                            child: Card(
                              color:
                                  mine
                                      ? Theme.of(
                                        context,
                                      ).colorScheme.primaryContainer
                                      : null,
                              child: Padding(
                                padding: const EdgeInsets.all(12),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      mine
                                          ? 'You'
                                          : m.userInfo?.name ??
                                              widget.session['peerName'] ??
                                              'Member',
                                      style:
                                          Theme.of(
                                            context,
                                          ).textTheme.labelSmall,
                                    ),
                                    SelectableText(body),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
            ),
            Padding(
              padding: const EdgeInsets.all(10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: TextField(
                      controller: draft,
                      enabled: connected && !sending,
                      minLines: 1,
                      maxLines: 4,
                      maxLength: 2000,
                      decoration: const InputDecoration(
                        hintText: 'Message',
                        counterText: '',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  ValueListenableBuilder<TextEditingValue>(
                    valueListenable: draft,
                    builder:
                        (context, value, child) => IconButton.filled(
                          tooltip: 'Send message',
                          onPressed:
                              connected &&
                                      !sending &&
                                      value.text.trim().isNotEmpty
                                  ? send
                                  : null,
                          icon: const Icon(Icons.send_rounded),
                        ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
