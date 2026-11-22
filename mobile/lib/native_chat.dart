import 'dart:async';
import 'dart:convert';
import 'package:ai_nexconn_chat_plugin/ai_nexconn_chat_plugin.dart' as nc;
import 'package:file_selector/file_selector.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:material_ui/material_ui.dart';
import 'package:url_launcher/url_launcher.dart';

import 'api_client.dart';
import 'resolution_screens.dart';
import 'theme.dart';
import 'ui.dart';
import 'user_discovery.dart';

class ApexStickerItem {
  const ApexStickerItem({
    required this.emoji,
    required this.title,
    required this.pack,
  });
  final String emoji;
  final String title;
  final String pack;
}

const starterStickers = <ApexStickerItem>[
  ApexStickerItem(emoji: '🚀', title: 'Ship It!', pack: 'Engineering'),
  ApexStickerItem(emoji: '🐛', title: 'Bug Hunt', pack: 'Engineering'),
  ApexStickerItem(emoji: '🔍', title: 'Investigating', pack: 'Engineering'),
  ApexStickerItem(emoji: '🧪', title: 'Testing Fix', pack: 'Engineering'),
  ApexStickerItem(emoji: '🛡️', title: 'Verified', pack: 'Engineering'),
  ApexStickerItem(emoji: '⚡', title: 'P0 Incident', pack: 'Engineering'),
  ApexStickerItem(emoji: '💡', title: 'Eureka!', pack: 'Engineering'),
  ApexStickerItem(emoji: '🤝', title: 'LGTM', pack: 'Engineering'),
  ApexStickerItem(emoji: '🎉', title: 'Celebrate', pack: 'Team Vibes'),
  ApexStickerItem(emoji: '🔥', title: 'On Fire!', pack: 'Team Vibes'),
  ApexStickerItem(emoji: '💯', title: '100% Solid', pack: 'Team Vibes'),
  ApexStickerItem(emoji: '👏', title: 'Bravo', pack: 'Team Vibes'),
  ApexStickerItem(emoji: '☕', title: 'Need Coffee', pack: 'Team Vibes'),
  ApexStickerItem(emoji: '🎯', title: 'Nailed It', pack: 'Team Vibes'),
  ApexStickerItem(emoji: '✨', title: 'Clean Work', pack: 'Team Vibes'),
  ApexStickerItem(emoji: '🏆', title: 'Victory', pack: 'Team Vibes'),
  ApexStickerItem(emoji: '⏳', title: 'In Progress', pack: 'Status'),
  ApexStickerItem(emoji: '🛑', title: 'Blocked', pack: 'Status'),
  ApexStickerItem(emoji: '👀', title: 'Reviewing', pack: 'Status'),
  ApexStickerItem(emoji: '🚢', title: 'In Prod', pack: 'Status'),
  ApexStickerItem(emoji: '🔒', title: 'Secured', pack: 'Status'),
  ApexStickerItem(emoji: '📝', title: 'Documented', pack: 'Status'),
];

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
  final searchCtrl = TextEditingController();
  final messages = <String, nc.Message>{};
  final reactions = <String, Map<String, int>>{}; // messageId -> {emoji: count}

  late final channel = nc.GroupChannel(widget.session['channelId'] as String);
  late final history = nc.MessagesQuery(
    nc.MessagesQueryParams(
      channelIdentifier: channel.channelIdentifier,
      pageSize: 30,
      startTime: DateTime.now().millisecondsSinceEpoch,
    ),
  );

  bool connected = false, sending = false, paging = false;
  bool searchOpen = false;
  String searchQuery = '';
  String status = 'Connecting…';
  nc.Message? replyTarget;

  late final Future<void> startup;

  final emojis = ['👍', '❤️', '🔥', '🎉', '🚀', '👏', '💡', '⚠️', '👀', '✅'];
  final quickReplies = [
    'On it — I’ll take a look now.',
    'Investigating now. I’ll share findings shortly.',
    'Retest is ready for verification.',
    'Fixed and verified on staging.',
  ];

  @override
  void initState() {
    super.initState();
    ThemeController.global.addListener(_onThemeChanged);
    startup = connect();
  }

  @override
  void dispose() {
    ThemeController.global.removeListener(_onThemeChanged);
    nc.NCEngine.removeMessageHandler('apex.thread');
    draft.dispose();
    searchCtrl.dispose();
    super.dispose();
  }

  void _onThemeChanged() {
    if (mounted) setState(() {});
  }

  void showStickerPicker() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => _StickerPickerSheet(
        onSelectSticker: (sticker) {
          Navigator.pop(ctx);
          sendRawText('[Sticker:${sticker.emoji}|${sticker.title}|${sticker.pack}]');
        },
      ),
    );
  }

  Future<void> showConversationDetails() async {
    final communityId = widget.session['communityId']?.toString();
    final peerName = widget.session['peerName']?.toString() ?? widget.title;
    final isGroup = communityId != null;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => _ConversationDetailsSheet(
        session: widget.session,
        isGroup: isGroup,
        peerName: peerName,
        communityId: communityId,
        onWallpaperChanged: (style) {
          ThemeController.global.setWallpaper(style);
        },
      ),
    );
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
            if (mounted && e.message.channelId == channel.channelIdentifier.channelId) {
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
        setState(() => status = 'Unable to connect. Tap retry to reconnect.');
      }
    }
  }

  void merge(nc.Message message) {
    final key = message.messageId;
    if (key != null) {
      messages[key] = message;
      // Parse reaction messages if any
      if (message is nc.TextMessage && message.text != null && message.text!.startsWith('[React:')) {
        final match = RegExp(r'^\[React:\s*([^\s]+)\s+to\s+([A-Za-z0-9_-]+)\]').firstMatch(message.text!);
        if (match != null) {
          final emoji = match.group(1)!;
          final targetId = match.group(2)!;
          reactions.putIfAbsent(targetId, () => {});
          reactions[targetId]![emoji] = (reactions[targetId]![emoji] ?? 0) + 1;
        }
      }
    }
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
        setState(() => status = 'History unavailable. Retry with Load earlier.');
      }
    } finally {
      if (mounted) setState(() => paging = false);
    }
  }

  Future<void> sendRawText(String text) async {
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
        setState(() {
          replyTarget = null;
          status = 'Connected';
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => status = 'Send unconfirmed. Check connection before retrying.');
      }
    } finally {
      if (mounted) setState(() => sending = false);
    }
  }

  Future<void> send() async {
    final text = draft.text.trim();
    if (text.isEmpty) return;

    String payload = text;
    if (replyTarget != null) {
      final replyText = replyTarget is nc.TextMessage ? (replyTarget as nc.TextMessage).text ?? '' : '';
      final snippet = replyText.length > 60 ? '${replyText.substring(0, 60)}…' : replyText;
      payload = '> Replying: "$snippet"\n$text';
    }

    await sendRawText(payload);
  }

  void addReaction(String messageId, String emoji) {
    setState(() {
      reactions.putIfAbsent(messageId, () => {});
      reactions[messageId]![emoji] = (reactions[messageId]![emoji] ?? 0) + 1;
    });
    // Send subtle reaction sync message
    sendRawText('[React: $emoji to $messageId]');
  }

  Future<void> pickAndSendMedia(ImageSource source, {bool isVideo = false}) async {
    final picker = ImagePicker();
    try {
      if (isVideo) {
        final video = await picker.pickVideo(source: source);
        if (video == null) return;
        final bytes = await video.readAsBytes();
        final b64 = base64Encode(bytes);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Uploading video attachment…')),
          );
        }
        final res = await ApexApiClient.uploadAttachment(
          fileName: video.name,
          fileType: 'video/mp4',
          fileBase64: b64,
        );
        if (res['url'] != null) {
          final payload = '[Media:video|${video.name}|${res['url']}]';
          await sendRawText(payload);
        }
      } else {
        final photo = await picker.pickImage(source: source, imageQuality: 80);
        if (photo == null) return;
        final bytes = await photo.readAsBytes();
        final b64 = base64Encode(bytes);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Uploading image attachment…')),
          );
        }
        final res = await ApexApiClient.uploadAttachment(
          fileName: photo.name,
          fileType: 'image/jpeg',
          fileBase64: b64,
        );
        if (res['url'] != null) {
          final payload = '[Media:image|${photo.name}|${res['url']}]';
          await sendRawText(payload);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Media upload failed: $e')),
        );
      }
    }
  }

  Future<void> pickAndSendDocument() async {
    try {
      const typeGroup = XTypeGroup(
        label: 'documents',
        extensions: ['pdf', 'doc', 'docx', 'txt', 'zip', 'csv'],
      );
      final file = await openFile(acceptedTypeGroups: [typeGroup]);
      if (file == null) return;

      final bytes = await file.readAsBytes();
      final b64 = base64Encode(bytes);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Uploading document attachment…')),
        );
      }
      final res = await ApexApiClient.uploadAttachment(
        fileName: file.name,
        fileType: 'application/octet-stream',
        fileBase64: b64,
      );
      if (res['url'] != null) {
        final payload = '[Media:file|${file.name}|${res['url']}]';
        await sendRawText(payload);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Document upload failed: $e')),
        );
      }
    }
  }

  void showAttachmentPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Share to Conversation',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 16),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _AttachTile(
                      icon: Icons.camera_alt_rounded,
                      label: 'Camera',
                      color: ApexColors.coral,
                      onTap: () {
                        Navigator.pop(ctx);
                        pickAndSendMedia(ImageSource.camera);
                      },
                    ),
                    const SizedBox(width: 8),
                    _AttachTile(
                      icon: Icons.photo_library_rounded,
                      label: 'Photos',
                      color: ApexColors.rose,
                      onTap: () {
                        Navigator.pop(ctx);
                        pickAndSendMedia(ImageSource.gallery);
                      },
                    ),
                    const SizedBox(width: 8),
                    _AttachTile(
                      icon: Icons.videocam_rounded,
                      label: 'Videos',
                      color: ApexColors.violet,
                      onTap: () {
                        Navigator.pop(ctx);
                        pickAndSendMedia(ImageSource.gallery, isVideo: true);
                      },
                    ),
                    const SizedBox(width: 8),
                    _AttachTile(
                      icon: Icons.insert_drive_file_rounded,
                      label: 'Document',
                      color: ApexColors.cyan,
                      onTap: () {
                        Navigator.pop(ctx);
                        pickAndSendDocument();
                      },
                    ),
                    const SizedBox(width: 8),
                    _AttachTile(
                      icon: Icons.auto_awesome_rounded,
                      label: 'Stickers',
                      color: ApexColors.amber,
                      onTap: () {
                        Navigator.pop(ctx);
                        showStickerPicker();
                      },
                    ),
                  ],
                ),
              ),
              const Divider(height: 32),
              Text(
                'Quick Responses',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  for (final qr in quickReplies)
                    ActionChip(
                      label: Text(qr, style: const TextStyle(fontSize: 12)),
                      onPressed: () {
                        Navigator.pop(ctx);
                        sendRawText(qr);
                      },
                    ),
                ],
              ),
              const SizedBox(height: 8),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.bolt_rounded, color: ApexColors.coral),
                title: const Text('Convert Message to Issue'),
                subtitle: const Text('Turn this thread into a tracked resolution room'),
                onTap: () {
                  Navigator.pop(ctx);
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const CreateIssueScreen()),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void showMessageOptions(nc.Message m, String body, bool mine) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Emoji reaction bar
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    for (final e in emojis.take(6))
                      InkWell(
                        onTap: () {
                          Navigator.pop(ctx);
                          if (m.messageId != null) addReaction(m.messageId!, e);
                        },
                        borderRadius: BorderRadius.circular(16),
                        child: Padding(
                          padding: const EdgeInsets.all(6),
                          child: Text(e, style: const TextStyle(fontSize: 26)),
                        ),
                      ),
                  ],
                ),
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.reply_rounded),
                title: const Text('Reply to message'),
                onTap: () {
                  Navigator.pop(ctx);
                  setState(() => replyTarget = m);
                },
              ),
              ListTile(
                leading: const Icon(Icons.copy_rounded),
                title: const Text('Copy message text'),
                onTap: () {
                  Navigator.pop(ctx);
                  Clipboard.setData(ClipboardData(text: body));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Message copied')),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.bolt_rounded, color: ApexColors.coral),
                title: const Text('File an issue from this message'),
                onTap: () {
                  Navigator.pop(ctx);
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const CreateIssueScreen()),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;

    // Filter out internal reaction command messages from display
    final allList = messages.values
        .where((m) => !(m is nc.TextMessage && m.text != null && m.text!.startsWith('[React:')))
        .toList()
      ..sort((a, b) => (b.sentTime ?? 0).compareTo(a.sentTime ?? 0));

    final list = searchQuery.isEmpty
        ? allList
        : allList.where((m) {
            final t = m is nc.TextMessage ? m.text?.toLowerCase() ?? '' : '';
            return t.contains(searchQuery.toLowerCase());
          }).toList();

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
        title: searchOpen
            ? TextField(
                controller: searchCtrl,
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: 'Search in conversation…',
                  border: InputBorder.none,
                ),
                onChanged: (val) => setState(() => searchQuery = val.trim()),
              )
            : InkWell(
                onTap: showConversationDetails,
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
                  child: Row(
                    children: [
                      ApexAvatar(
                        initials: initials(peer),
                        seed: peer,
                        size: 38,
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
                                fontSize: 15.5,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            Row(
                              children: [
                                Container(
                                  width: 6,
                                  height: 6,
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
                                    fontSize: 10.5,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
        actions: [
          IconButton(
            tooltip: searchOpen ? 'Close search' : 'Search messages',
            icon: Icon(searchOpen ? Icons.close : Icons.search_rounded),
            onPressed: () {
              setState(() {
                searchOpen = !searchOpen;
                if (!searchOpen) {
                  searchCtrl.clear();
                  searchQuery = '';
                }
              });
            },
          ),
          IconButton(
            tooltip: 'Conversation info and actions',
            icon: const Icon(Icons.info_outline_rounded),
            onPressed: showConversationDetails,
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: ApexBackground(
        chat: true,
        wallpaperStyle: ThemeController.global.wallpaper,
        child: SafeArea(
          top: false,
          child: Column(
            children: [
              Expanded(
                child: list.isEmpty
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
                                border: Border.all(color: theme.colorScheme.outline),
                              ),
                              child: const Icon(Icons.forum_outlined, color: ApexColors.coral, size: 28),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              searchQuery.isNotEmpty
                                  ? 'No messages matching "$searchQuery"'
                                  : connected && !paging
                                      ? 'No messages yet'
                                      : 'Loading conversation…',
                              style: theme.textTheme.titleMedium,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              connected ? 'Say hello and begin collaborating.' : 'Connecting to chat room…',
                              style: theme.textTheme.bodySmall?.copyWith(color: muted),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        reverse: true,
                        padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
                        itemCount: list.length + (history.hasMore ? 1 : 0),
                        itemBuilder: (context, i) {
                          if (i == list.length) {
                            return Center(
                              child: Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: OutlinedButton.icon(
                                  onPressed: paging ? null : loadHistory,
                                  icon: paging
                                      ? const SizedBox(
                                          width: 12,
                                          height: 12,
                                          child: CircularProgressIndicator(strokeWidth: 1.6),
                                        )
                                      : const Icon(Icons.history_rounded, size: 15),
                                  label: Text(paging ? 'Loading…' : 'Load earlier'),
                                ),
                              ),
                            );
                          }
                          final m = list[i];
                          final mine = m.senderUserId == widget.session['userId'];
                          final rawText = m is nc.TextMessage ? m.text ?? '' : '';
                          final sender = mine
                              ? 'You'
                              : m.userInfo?.name ?? widget.session['peerName'] ?? 'Member';

                          final prev = i + 1 < list.length ? list[i + 1] : null;
                          final showDate = m.sentTime != null &&
                              m.sentTime! > 0 &&
                              (prev == null || _isDifferentDay(m.sentTime, prev.sentTime));

                          final msgReactions = m.messageId != null ? reactions[m.messageId!] : null;

                          return Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (showDate) _DateBadge(label: chatDayLabel(m.sentTime)),
                              _ChatBubbleV2(
                                messageId: m.messageId,
                                mine: mine,
                                rawText: rawText,
                                sender: group ? sender : null,
                                time: _clock(m.sentTime),
                                reactions: msgReactions,
                                onLongPress: () => showMessageOptions(m, rawText, mine),
                                onReactionTap: (e) {
                                  if (m.messageId != null) addReaction(m.messageId!, e);
                                },
                              ),
                            ],
                          );
                        },
                      ),
              ),

              // Reply preview bar
              if (replyTarget != null) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  color: theme.colorScheme.surfaceContainerHighest,
                  child: Row(
                    children: [
                      const Icon(Icons.reply_rounded, size: 16, color: ApexColors.coral),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Replying: ${replyTarget is nc.TextMessage ? (replyTarget as nc.TextMessage).text : "Message"}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, size: 16),
                        onPressed: () => setState(() => replyTarget = null),
                      ),
                    ],
                  ),
                ),
              ],

              // Composer
              _ComposerV2(
                draft: draft,
                enabled: connected && !sending,
                sending: sending,
                onSend: send,
                onAttach: showAttachmentPicker,
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
    return '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
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
          border: Border.all(color: theme.colorScheme.outline.withValues(alpha: .5)),
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

class _ChatBubbleV2 extends StatelessWidget {
  const _ChatBubbleV2({
    this.messageId,
    required this.mine,
    required this.rawText,
    required this.time,
    this.sender,
    this.reactions,
    required this.onLongPress,
    required this.onReactionTap,
  });

  final String? messageId;
  final bool mine;
  final String rawText, time;
  final String? sender;
  final Map<String, int>? reactions;
  final VoidCallback onLongPress;
  final Function(String) onReactionTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isSticker = rawText.startsWith('[Sticker:');
    String stickerEmoji = '';
    String stickerTitle = '';
    if (isSticker) {
      final parts = rawText.replaceAll('[Sticker:', '').replaceAll(']', '').split('|');
      if (parts.isNotEmpty) stickerEmoji = parts[0];
      if (parts.length > 1) stickerTitle = parts[1];
    }

    if (isSticker) {
      return Padding(
        padding: EdgeInsets.only(
          bottom: 8,
          left: mine ? 48 : 0,
          right: mine ? 0 : 48,
        ),
        child: Column(
          crossAxisAlignment: mine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            if (sender != null && !mine)
              Padding(
                padding: const EdgeInsets.only(left: 6, bottom: 2),
                child: Text(
                  sender!,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: ApexColors.coral,
                    fontWeight: FontWeight.w800,
                    fontSize: 10.5,
                  ),
                ),
              ),
            GestureDetector(
              onLongPress: onLongPress,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.8),
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(
                    color: mine ? ApexColors.coral.withValues(alpha: 0.45) : theme.colorScheme.outline,
                    width: mine ? 1.5 : 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: (mine ? ApexColors.coral : Colors.black).withValues(alpha: 0.1),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      stickerEmoji,
                      style: const TextStyle(fontSize: 46),
                    ),
                    const SizedBox(height: 5),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                      decoration: BoxDecoration(
                        gradient: mine ? ApexGradients.primary : null,
                        color: mine ? null : theme.colorScheme.surface,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        stickerTitle,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: mine ? ApexColors.accentInk : theme.colorScheme.onSurface,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          time,
                          style: TextStyle(
                            fontSize: 9.5,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        if (mine) ...[
                          const SizedBox(width: 4),
                          const Icon(Icons.done_all_rounded, size: 12, color: ApexColors.coral),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ),
            if (reactions != null && reactions!.isNotEmpty) ...[
              const SizedBox(height: 2),
              Padding(
                padding: const EdgeInsets.only(left: 4),
                child: Wrap(
                  spacing: 4,
                  children: [
                    for (final entry in reactions!.entries)
                      InkWell(
                        onTap: () => onReactionTap(entry.key),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: theme.colorScheme.outline.withValues(alpha: 0.4)),
                          ),
                          child: Text(
                            '${entry.key} ${entry.value}',
                            style: const TextStyle(fontSize: 10),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ],
        ),
      );
    }

    final isMedia = rawText.startsWith('[Media:');
    String mediaType = '';
    String mediaName = '';
    String mediaUrl = '';
    String displayText = rawText;

    if (isMedia) {
      final parts = rawText.replaceAll('[Media:', '').replaceAll(']', '').split('|');
      if (parts.length >= 3) {
        mediaType = parts[0];
        mediaName = parts[1];
        mediaUrl = parts.sublist(2).join('|');
      }
    }

    final isReply = rawText.startsWith('> Replying:');
    String replySnippet = '';
    if (isReply) {
      final lines = rawText.split('\n');
      replySnippet = lines.first.replaceFirst('> Replying: ', '');
      displayText = lines.sublist(1).join('\n');
    }

    final radius = BorderRadius.only(
      topLeft: const Radius.circular(18),
      topRight: const Radius.circular(18),
      bottomLeft: Radius.circular(mine ? 18 : 4),
      bottomRight: Radius.circular(mine ? 4 : 18),
    );

    return Padding(
      padding: EdgeInsets.only(
        bottom: 6,
        left: mine ? 48 : 0,
        right: mine ? 0 : 48,
      ),
      child: Column(
        crossAxisAlignment: mine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          if (sender != null && !mine)
            Padding(
              padding: const EdgeInsets.only(left: 6, bottom: 2),
              child: Text(
                sender!,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: ApexColors.coral,
                  fontWeight: FontWeight.w800,
                  fontSize: 10.5,
                ),
              ),
            ),
          GestureDetector(
            onLongPress: onLongPress,
            child: Container(
              padding: const EdgeInsets.fromLTRB(12, 9, 12, 7),
              decoration: BoxDecoration(
                gradient: mine ? ApexGradients.primary : null,
                color: mine ? null : theme.colorScheme.surface,
                borderRadius: radius,
                border: mine ? null : Border.all(color: theme.colorScheme.outline),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(
                      alpha: theme.brightness == Brightness.dark ? .18 : .06,
                    ),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (isReply && replySnippet.isNotEmpty) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      margin: const EdgeInsets.only(bottom: 6),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                        border: const Border(left: BorderSide(color: Colors.white, width: 3)),
                      ),
                      child: Text(
                        replySnippet,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11,
                          fontStyle: FontStyle.italic,
                          color: mine ? Colors.white.withValues(alpha: 0.9) : mutedColor(theme),
                        ),
                      ),
                    ),
                  ],
                  if (isMedia) ...[
                    if (mediaType == 'image' && mediaUrl.isNotEmpty) ...[
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: GestureDetector(
                          onTap: () {
                            showDialog(
                              context: context,
                              builder: (_) => Dialog(
                                backgroundColor: Colors.transparent,
                                insetPadding: const EdgeInsets.all(12),
                                child: InteractiveViewer(
                                  child: Image.network(mediaUrl),
                                ),
                              ),
                            );
                          },
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxHeight: 220),
                            child: Image.network(
                              mediaUrl,
                              fit: BoxFit.cover,
                              loadingBuilder: (_, child, prog) =>
                                  prog == null ? child : const Center(child: CircularProgressIndicator()),
                              errorBuilder: (context, error, stackTrace) => const Icon(Icons.broken_image),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                    ] else ...[
                      InkWell(
                        onTap: () => launchUrl(Uri.parse(mediaUrl), mode: LaunchMode.externalApplication),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              mediaType == 'video' ? Icons.videocam : Icons.insert_drive_file,
                              color: mine ? Colors.white : ApexColors.coral,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                mediaName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: mine ? Colors.white : theme.colorScheme.onSurface,
                                  decoration: TextDecoration.underline,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ] else ...[
                    SelectableText(
                      displayText,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: mine ? Colors.white : theme.colorScheme.onSurface,
                        height: 1.4,
                        fontSize: 14.5,
                      ),
                    ),
                  ],
                  const SizedBox(height: 3),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        time,
                        style: TextStyle(
                          fontSize: 9.5,
                          color: mine
                              ? Colors.white.withValues(alpha: .75)
                              : theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      if (mine) ...[
                        const SizedBox(width: 4),
                        Icon(
                          Icons.done_all_rounded,
                          size: 13,
                          color: Colors.white.withValues(alpha: 0.8),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
          if (reactions != null && reactions!.isNotEmpty) ...[
            const SizedBox(height: 2),
            Padding(
              padding: const EdgeInsets.only(left: 4),
              child: Wrap(
                spacing: 4,
                children: [
                  for (final entry in reactions!.entries)
                    InkWell(
                      onTap: () => onReactionTap(entry.key),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: theme.colorScheme.outline.withValues(alpha: 0.4)),
                        ),
                        child: Text(
                          '${entry.key} ${entry.value}',
                          style: const TextStyle(fontSize: 10),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  static Color mutedColor(ThemeData theme) => theme.colorScheme.onSurfaceVariant;
}

class _AttachTile extends StatelessWidget {
  const _AttachTile({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Column(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 26),
            ),
            const SizedBox(height: 6),
            Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}

class _ComposerV2 extends StatelessWidget {
  const _ComposerV2({
    required this.draft,
    required this.enabled,
    required this.sending,
    required this.onSend,
    required this.onAttach,
  });

  final TextEditingController draft;
  final bool enabled, sending;
  final Future<void> Function() onSend;
  final VoidCallback onAttach;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 8, 12, 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface.withValues(alpha: .95),
        border: Border(top: BorderSide(color: theme.colorScheme.outline)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          IconButton(
            tooltip: 'Add attachment or action',
            icon: const Icon(Icons.add_circle_outline_rounded, size: 26, color: ApexColors.coral),
            onPressed: enabled ? onAttach : null,
          ),
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
                  contentPadding: const EdgeInsets.symmetric(vertical: 10),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          ValueListenableBuilder<TextEditingValue>(
            valueListenable: draft,
            builder: (context, value, _) {
              final canSend = enabled && !sending && value.text.trim().isNotEmpty;
              return Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: canSend ? onSend : null,
                  borderRadius: BorderRadius.circular(22),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 160),
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      gradient: canSend ? ApexGradients.primary : null,
                      color: canSend ? null : theme.colorScheme.surfaceContainerHighest,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: canSend ? Colors.transparent : theme.colorScheme.outline,
                      ),
                    ),
                    child: Icon(
                      sending ? Icons.hourglass_top_rounded : Icons.arrow_upward_rounded,
                      size: 21,
                      color: canSend ? ApexColors.accentInk : theme.colorScheme.onSurfaceVariant,
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

class _StickerPickerSheet extends StatefulWidget {
  const _StickerPickerSheet({required this.onSelectSticker});
  final ValueChanged<ApexStickerItem> onSelectSticker;

  @override
  State<_StickerPickerSheet> createState() => _StickerPickerSheetState();
}

class _StickerPickerSheetState extends State<_StickerPickerSheet> {
  String selectedPack = 'All';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final packs = ['All', 'Engineering', 'Team Vibes', 'Status'];
    final filtered = selectedPack == 'All'
        ? starterStickers
        : starterStickers.where((s) => s.pack == selectedPack).toList();

    return SafeArea(
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.65,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                const Icon(Icons.auto_awesome_rounded, color: ApexColors.amber, size: 22),
                const SizedBox(width: 8),
                Text(
                  'Starter Stickers',
                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close_rounded, size: 20),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 10),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (final pack in packs)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        selected: selectedPack == pack,
                        label: Text(pack, style: const TextStyle(fontSize: 12)),
                        onSelected: (_) => setState(() => selectedPack = pack),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: GridView.builder(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 4,
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                  childAspectRatio: 0.88,
                ),
                itemCount: filtered.length,
                itemBuilder: (context, i) {
                  final sticker = filtered[i];
                  return InkWell(
                    onTap: () => widget.onSelectSticker(sticker),
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: theme.colorScheme.outline.withValues(alpha: 0.5)),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(sticker.emoji, style: const TextStyle(fontSize: 34)),
                          const SizedBox(height: 4),
                          Text(
                            sticker.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ConversationDetailsSheet extends StatelessWidget {
  const _ConversationDetailsSheet({
    required this.session,
    required this.isGroup,
    required this.peerName,
    this.communityId,
    required this.onWallpaperChanged,
  });

  final Map<String, dynamic> session;
  final bool isGroup;
  final String peerName;
  final String? communityId;
  final ValueChanged<ChatWallpaperStyle> onWallpaperChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;

    return SafeArea(
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.82,
        ),
        child: ListView(
          shrinkWrap: true,
          children: [
            Row(
              children: [
                Text(
                  isGroup ? 'Group Details' : 'Conversation Info',
                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close_rounded, size: 20),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Center(
              child: Column(
                children: [
                  ApexAvatar(
                    initials: initials(peerName),
                    seed: peerName,
                    size: 72,
                    icon: isGroup ? Icons.groups_rounded : null,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    peerName,
                    style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    isGroup
                        ? 'Community Collaboration Room'
                        : (session['peerId'] != null ? '@${session['peerId']}' : 'Direct Messaging'),
                    style: theme.textTheme.bodySmall?.copyWith(color: muted),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                if (isGroup)
                  _ActionIconBtn(
                    icon: Icons.person_add_rounded,
                    label: 'Invite',
                    color: ApexColors.coral,
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const UserDiscoveryScreen()),
                      );
                    },
                  ),
                _ActionIconBtn(
                  icon: Icons.bolt_rounded,
                  label: 'New Issue',
                  color: ApexColors.rose,
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const CreateIssueScreen()),
                    );
                  },
                ),
                _ActionIconBtn(
                  icon: Icons.wallpaper_rounded,
                  label: 'Wallpaper',
                  color: ApexColors.cyan,
                  onTap: () {
                    _showWallpaperPickerModal(context);
                  },
                ),
              ],
            ),
            const Divider(height: 32),
            if (isGroup && communityId != null) ...[
              FutureBuilder<Map<String, dynamic>>(
                future: ApexApiClient.getWorkspaceDetails(communityId!),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.all(20),
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    );
                  }
                  final data = snapshot.data ?? {};
                  final members = (data['members'] as List?) ?? [];
                  final myRole = data['myRole']?.toString() ?? 'member';
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            'Members (${members.length})',
                            style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: ApexColors.coral.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              'Your Role: ${myRole.toUpperCase()}',
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: ApexColors.coral,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      if (members.isEmpty)
                        Text(
                          'No member details loaded.',
                          style: theme.textTheme.bodySmall?.copyWith(color: muted),
                        )
                      else
                        for (final m in members)
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: ApexAvatar(
                              initials: initials(m['name']?.toString() ?? 'M'),
                              seed: m['name']?.toString() ?? 'M',
                              size: 36,
                            ),
                            title: Text(
                              m['name']?.toString() ?? 'Member',
                              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5),
                            ),
                            trailing: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.surfaceContainerHighest,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                (m['role']?.toString() ?? 'member').toUpperCase(),
                                style: TextStyle(
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.bold,
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ),
                          ),
                    ],
                  );
                },
              ),
            ] else ...[
              Text(
                'Direct Thread Information',
                style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.fingerprint_rounded, color: ApexColors.coral),
                title: const Text('Channel Reference'),
                subtitle: Text(
                  session['channelId']?.toString() ?? 'Active thread',
                  style: const TextStyle(fontSize: 11),
                ),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.shield_outlined, color: ApexColors.green),
                title: const Text('End-to-End Resolution Ready'),
                subtitle: const Text('Messages in this channel can be attached to issue evidence.'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _showWallpaperPickerModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Choose Chat Wallpaper',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              for (final style in ChatWallpaperStyle.values)
                ListTile(
                  leading: Icon(style.icon, color: ApexColors.coral),
                  title: Text(style.label),
                  selected: ThemeController.global.wallpaper == style,
                  onTap: () {
                    onWallpaperChanged(style);
                    Navigator.pop(ctx);
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActionIconBtn extends StatelessWidget {
  const _ActionIconBtn({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(height: 6),
            Text(label, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}
