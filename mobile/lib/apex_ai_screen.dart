import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:material_ui/material_ui.dart';

import 'api_client.dart';
import 'theme.dart';
import 'ui.dart';

class ApexAiMessage {
  final String role; // 'user' or 'assistant'
  final String content;
  final DateTime time;

  const ApexAiMessage({
    required this.role,
    required this.content,
    required this.time,
  });

  bool get isUser => role == 'user';
}

class ApexAiScreen extends StatefulWidget {
  const ApexAiScreen({super.key});

  @override
  State<ApexAiScreen> createState() => _ApexAiScreenState();
}

class _ApexAiScreenState extends State<ApexAiScreen> {
  final draftCtrl = TextEditingController();
  final scrollCtrl = ScrollController();
  final List<ApexAiMessage> messages = [
    ApexAiMessage(
      role: 'assistant',
      content: 'Hello! I am **Apex AI**, your collaboration and issue resolution assistant. I can help troubleshoot bugs, structure evidence, draft replies, and summarize resolution workflows.',
      time: DateTime.now(),
    ),
  ];
  bool loading = false;
  String error = '';

  final quickPrompts = [
    'How do I attach evidence to an issue?',
    'Explain the independent verification rule',
    'Help draft a bug report from chat',
    'What steps are required to close an issue?',
  ];

  @override
  void dispose() {
    draftCtrl.dispose();
    scrollCtrl.dispose();
    super.dispose();
  }

  void scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (scrollCtrl.hasClients) {
        scrollCtrl.animateTo(
          scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> send(String text) async {
    final clean = text.trim();
    if (clean.isEmpty || loading) return;

    draftCtrl.clear();
    setState(() {
      error = '';
      loading = true;
      messages.add(
        ApexAiMessage(
          role: 'user',
          content: clean,
          time: DateTime.now(),
        ),
      );
    });
    scrollToBottom();

    try {
      // Build turns history (last 10 turns max)
      final history = messages
          .take(12)
          .map((m) => {'role': m.role, 'content': m.content})
          .toList();

      final res = await ApexApiClient.askApex(history);

      if (!mounted) return;

      if (res.containsKey('error') && res['error'] != null) {
        setState(() {
          error = res['error'].toString();
        });
      } else if (res.containsKey('answer') && res['answer'] != null) {
        final answer = res['answer'].toString();
        setState(() {
          messages.add(
            ApexAiMessage(
              role: 'assistant',
              content: answer,
              time: DateTime.now(),
            ),
          );
        });
        scrollToBottom();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          error = 'Apex AI is momentarily unavailable. Check your connection and retry.';
        });
      }
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  void copyToClipboard(String text) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Response copied to clipboard'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final muted = theme.colorScheme.onSurfaceVariant;

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                gradient: ApexGradients.primary,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.auto_awesome_rounded,
                color: Colors.white,
                size: 20,
              ),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Apex AI',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                ),
                Text(
                  'Intelligent Workspace Copilot',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: ApexColors.coral,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Clear conversation',
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () {
              setState(() {
                messages.clear();
                messages.add(
                  ApexAiMessage(
                    role: 'assistant',
                    content: 'Hi again! How can I help resolve issues or collaborate today?',
                    time: DateTime.now(),
                  ),
                );
              });
            },
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: ApexBackground(
        chat: true,
        child: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: ListView.builder(
                  controller: scrollCtrl,
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                  itemCount: messages.length + (loading ? 1 : 0),
                  itemBuilder: (context, index) {
                    if (index == messages.length && loading) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Row(
                          children: [
                            Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                color: ApexColors.coral.withValues(alpha: 0.15),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.auto_awesome_rounded,
                                size: 16,
                                color: ApexColors.coral,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.surface,
                                borderRadius: BorderRadius.circular(18),
                                border: Border.all(color: theme.colorScheme.outline),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const SizedBox(
                                    width: 12,
                                    height: 12,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Apex AI is thinking…',
                                    style: theme.textTheme.bodySmall?.copyWith(color: muted),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    }

                    final m = messages[index];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 14),
                      child: Column(
                        crossAxisAlignment:
                            m.isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (!m.isUser) ...[
                                const Icon(Icons.auto_awesome_rounded, size: 13, color: ApexColors.coral),
                                const SizedBox(width: 4),
                                Text(
                                  'Apex AI',
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    color: ApexColors.coral,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ] else ...[
                                Text(
                                  'You',
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    color: muted,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 4),
                          Container(
                            constraints: BoxConstraints(
                              maxWidth: MediaQuery.of(context).size.width * 0.85,
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            decoration: BoxDecoration(
                              gradient: m.isUser ? ApexGradients.primary : null,
                              color: m.isUser ? null : theme.colorScheme.surface,
                              borderRadius: BorderRadius.only(
                                topLeft: const Radius.circular(18),
                                topRight: const Radius.circular(18),
                                bottomLeft: Radius.circular(m.isUser ? 18 : 4),
                                bottomRight: Radius.circular(m.isUser ? 4 : 18),
                              ),
                              border: m.isUser ? null : Border.all(color: theme.colorScheme.outline),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: dark ? 0.2 : 0.05),
                                  blurRadius: 8,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                            ),
                            child: m.isUser
                                ? Text(
                                    m.content,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 14.5,
                                      height: 1.4,
                                    ),
                                  )
                                : MarkdownBody(
                                    data: m.content,
                                    selectable: true,
                                    styleSheet: MarkdownStyleSheet(
                                      p: theme.textTheme.bodyMedium?.copyWith(
                                        height: 1.45,
                                        fontSize: 14,
                                      ),
                                      code: TextStyle(
                                        backgroundColor: theme.colorScheme.surfaceContainerHighest,
                                        fontFamily: 'monospace',
                                        fontSize: 12.5,
                                      ),
                                      codeblockDecoration: BoxDecoration(
                                        color: theme.colorScheme.surfaceContainerHighest,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                    ),
                                  ),
                          ),
                          if (!m.isUser)
                            Padding(
                              padding: const EdgeInsets.only(top: 4, left: 4),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.copy_rounded, size: 14),
                                    tooltip: 'Copy reply',
                                    visualDensity: VisualDensity.compact,
                                    onPressed: () => copyToClipboard(m.content),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              if (error.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  decoration: BoxDecoration(
                    color: ApexColors.danger.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: ApexColors.danger.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline_rounded, size: 16, color: ApexColors.danger),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          error,
                          style: const TextStyle(fontSize: 12, color: ApexColors.danger),
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          final lastUser = messages.lastWhere((m) => m.isUser, orElse: () => messages.first);
                          if (lastUser.isUser) send(lastUser.content);
                        },
                        child: const Text('Retry', style: TextStyle(fontSize: 12)),
                      ),
                    ],
                  ),
                ),
              if (messages.length <= 2)
                SizedBox(
                  height: 38,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: quickPrompts.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 8),
                    itemBuilder: (context, i) {
                      return ActionChip(
                        label: Text(quickPrompts[i], style: const TextStyle(fontSize: 12)),
                        onPressed: () => send(quickPrompts[i]),
                      );
                    },
                  ),
                ),
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 8, 14, 12),
                child: Row(
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: theme.colorScheme.outline),
                        ),
                        child: TextField(
                          controller: draftCtrl,
                          minLines: 1,
                          maxLines: 4,
                          maxLength: 4000,
                          textCapitalization: TextCapitalization.sentences,
                          decoration: const InputDecoration(
                            hintText: 'Message Apex AI…',
                            counterText: '',
                            border: InputBorder.none,
                            isDense: true,
                            contentPadding: EdgeInsets.symmetric(vertical: 10),
                          ),
                          onSubmitted: (val) => send(val),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton.filled(
                      onPressed: loading ? null : () => send(draftCtrl.text),
                      icon: loading
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.arrow_upward_rounded, size: 20),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
