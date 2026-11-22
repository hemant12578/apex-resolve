import 'dart:convert';
import 'package:image_picker/image_picker.dart';
import 'package:material_ui/material_ui.dart';
import 'package:url_launcher/url_launcher.dart';

import 'api_client.dart';
import 'native_chat.dart';
import 'theme.dart';
import 'ui.dart';

class ResolutionDetailScreen extends StatefulWidget {
  const ResolutionDetailScreen({
    super.key,
    required this.issueId,
    this.initialTitle,
  });

  final String issueId;
  final String? initialTitle;

  @override
  State<ResolutionDetailScreen> createState() => _ResolutionDetailScreenState();
}

class _ResolutionDetailScreenState extends State<ResolutionDetailScreen> {
  bool loading = true;
  String error = '';
  Map<String, dynamic>? data;

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    setState(() {
      loading = true;
      error = '';
    });
    try {
      final res = await ApexApiClient.getIssue(widget.issueId);
      if (res.containsKey('error') && res['error'] != null) {
        throw Exception(res['error']);
      }
      if (mounted) setState(() => data = res);
    } catch (e) {
      if (mounted) {
        setState(() => error = e.toString().replaceAll('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> openChat() async {
    try {
      final session = await ApexApiClient.chatSession(issueId: widget.issueId);
      if (!mounted) return;
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => NativeChat(
            session: session,
            title: data?['issue']?['title'] ?? widget.initialTitle ?? 'Resolution Room',
            showWorkspace: false,
          ),
        ),
      );
      load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not open chat: $e')),
        );
      }
    }
  }

  Future<void> transition(String action, {String? notes, List<String>? tags, String? reqId}) async {
    try {
      final res = await ApexApiClient.transitionIssue(
        issueId: widget.issueId,
        action: action,
        notes: notes,
        tags: tags,
        reviewRequest: reqId,
      );
      if (res['ok'] == true && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Workflow updated: $action')),
        );
        load();
      } else {
        throw Exception(res['error'] ?? 'Transition failed');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceAll('Exception: ', ''))),
        );
      }
    }
  }

  void showReviewDialog(bool approve, String? reviewRequestId) {
    final notesCtrl = TextEditingController();
    final tagsCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(approve ? 'Approve Resolution' : 'Reject with Reason'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: notesCtrl,
              maxLines: 3,
              decoration: InputDecoration(
                labelText: approve ? 'Review Notes' : 'Reason for Rejection',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
            if (approve) ...[
              const SizedBox(height: 12),
              TextField(
                controller: tagsCtrl,
                decoration: InputDecoration(
                  labelText: 'Knowledge Tags (comma separated)',
                  hintText: 'e.g. auth, security, mobile',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: approve ? ApexColors.green : ApexColors.danger,
            ),
            onPressed: () {
              Navigator.pop(ctx);
              final tags = tagsCtrl.text.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
              transition(
                approve ? 'approve' : 'reject',
                notes: notesCtrl.text.trim(),
                tags: tags,
                reqId: reviewRequestId,
              );
            },
            child: Text(approve ? 'Confirm Approval' : 'Confirm Rejection'),
          ),
        ],
      ),
    );
  }

  void showAddTaskDialog() {
    final titleCtrl = TextEditingController();
    final descCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Task Item'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleCtrl,
              decoration: InputDecoration(
                labelText: 'Task Title',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: descCtrl,
              maxLines: 2,
              decoration: InputDecoration(
                labelText: 'Description (optional)',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              if (titleCtrl.text.trim().isEmpty) return;
              Navigator.pop(ctx);
              await ApexApiClient.saveTask(
                issueId: widget.issueId,
                title: titleCtrl.text.trim(),
                description: descCtrl.text.trim(),
              );
              load();
            },
            child: const Text('Add Task'),
          ),
        ],
      ),
    );
  }

  void showAddEvidenceDialog() {
    String kind = 'note';
    final descCtrl = TextEditingController();
    final urlCtrl = TextEditingController();
    XFile? pickedFile;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDState) => AlertDialog(
          title: const Text('Attach Evidence'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: 'note', label: Text('Note')),
                    ButtonSegment(value: 'url', label: Text('URL')),
                    ButtonSegment(value: 'file', label: Text('Photo/File')),
                  ],
                  selected: {kind},
                  onSelectionChanged: (set) => setDState(() => kind = set.first),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: descCtrl,
                  maxLines: 3,
                  decoration: InputDecoration(
                    labelText: 'Evidence Description',
                    hintText: 'Explain the fix or verification step…',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
                if (kind == 'url') ...[
                  const SizedBox(height: 12),
                  TextField(
                    controller: urlCtrl,
                    decoration: InputDecoration(
                      labelText: 'Verification URL (HTTPS)',
                      hintText: 'https://...',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ],
                if (kind == 'file') ...[
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: () async {
                      final picker = ImagePicker();
                      final f = await picker.pickImage(source: ImageSource.gallery);
                      if (f != null) {
                        setDState(() => pickedFile = f);
                      }
                    },
                    icon: const Icon(Icons.attach_file_rounded),
                    label: Text(pickedFile != null ? pickedFile!.name : 'Choose Image / File'),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            FilledButton(
              onPressed: () async {
                if (descCtrl.text.trim().isEmpty) return;
                Navigator.pop(ctx);
                String? b64;
                if (kind == 'file' && pickedFile != null) {
                  final bytes = await pickedFile!.readAsBytes();
                  b64 = base64Encode(bytes);
                }

                await ApexApiClient.addEvidence(
                  issueId: widget.issueId,
                  kind: kind,
                  description: descCtrl.text.trim(),
                  value: kind == 'url' ? urlCtrl.text.trim() : null,
                  fileBase64: b64,
                  fileName: pickedFile?.name,
                );
                load();
              },
              child: const Text('Attach Evidence'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;

    if (loading && data == null) {
      return Scaffold(
        appBar: AppBar(title: Text(widget.initialTitle ?? 'Resolution')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (error.isNotEmpty && data == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Resolution')),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 48, color: ApexColors.danger),
              const SizedBox(height: 12),
              Text(error, style: theme.textTheme.titleMedium),
              const SizedBox(height: 12),
              FilledButton(onPressed: load, child: const Text('Retry')),
            ],
          ),
        ),
      );
    }

    final issue = data!['issue'] as Map<String, dynamic>;
    final permissions = (data!['permissions'] as Map?)?.cast<String, dynamic>() ?? {};
    final tasks = (data!['tasks'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    final evidence = (data!['evidence'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    final audit = (data!['audit'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    final reviews = (data!['reviews'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    final people = (data!['people'] as List?)?.cast<Map<String, dynamic>>() ?? [];

    final statusStr = issue['status'] as String? ?? 'OPEN';
    final priority = issue['priority'] as String? ?? 'MEDIUM';
    final title = issue['title'] as String? ?? 'Untitled';
    final description = issue['description'] as String? ?? '';
    final editable = permissions['editable'] == true;
    final canVerify = permissions['canVerify'] == true;
    final independent = permissions['independent'] == true;
    final isRequestedByMe = permissions['isRequestedByMe'] == true;

    final steps = ['OPEN', 'IN_PROGRESS', 'PENDING_VERIFICATION', 'VERIFIED_RESOLVED'];
    final stepLabels = ['Reported', 'In progress', 'Review', 'Verified'];
    final currentStep = steps.indexOf(statusStr);

    String personName(String? id) {
      if (id == null) return 'Unassigned';
      final p = people.firstWhere((e) => e['userId'] == id, orElse: () => {});
      return p['name'] as String? ?? id.substring(0, 8);
    }

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
        actions: [
          IconButton(
            tooltip: 'Resolution Chat',
            icon: const Icon(Icons.forum_outlined, color: ApexColors.coral),
            onPressed: openChat,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: ApexBackground(
        child: SafeArea(
          child: RefreshIndicator(
            onRefresh: load,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
              children: [
                // Header Stepper
                ApexCard(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Wrap(
                              spacing: 8,
                              runSpacing: 4,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: statusStr == 'VERIFIED_RESOLVED'
                                        ? ApexColors.green.withValues(alpha: 0.15)
                                        : ApexColors.coral.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    statusStr.replaceAll('_', ' '),
                                    style: TextStyle(
                                      color: statusStr == 'VERIFIED_RESOLVED'
                                          ? ApexColors.green
                                          : ApexColors.coral,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 11,
                                    ),
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: theme.colorScheme.surfaceContainerHighest,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    priority,
                                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          FilledButton.tonalIcon(
                            onPressed: openChat,
                            icon: const Icon(Icons.forum_rounded, size: 16),
                            label: const Text('Chat'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      // Progress Stepper Row
                      Row(
                        children: List.generate(steps.length, (i) {
                          final done = i <= currentStep;
                          final isCurrent = i == currentStep;
                          return Expanded(
                            child: Column(
                              children: [
                                Row(
                                  children: [
                                    if (i > 0)
                                      Expanded(
                                        child: Container(
                                          height: 3,
                                          color: i <= currentStep
                                              ? ApexColors.coral
                                              : theme.colorScheme.outline,
                                        ),
                                      ),
                                    Container(
                                      width: 22,
                                      height: 22,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: done ? ApexColors.coral : theme.colorScheme.surface,
                                        border: Border.all(
                                          color: done ? ApexColors.coral : theme.colorScheme.outline,
                                          width: isCurrent ? 2 : 1,
                                        ),
                                      ),
                                      child: Center(
                                        child: done
                                            ? const Icon(Icons.check, size: 12, color: Colors.white)
                                            : Text(
                                                '${i + 1}',
                                                style: TextStyle(fontSize: 10, color: muted),
                                              ),
                                      ),
                                    ),
                                    if (i < steps.length - 1)
                                      Expanded(
                                        child: Container(
                                          height: 3,
                                          color: i < currentStep
                                              ? ApexColors.coral
                                              : theme.colorScheme.outline,
                                        ),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  stepLabels[i],
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 9.5,
                                    fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                                    color: isCurrent ? ApexColors.coral : muted,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Issue Details Card
                ApexCard(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.description_outlined, size: 18, color: ApexColors.coral),
                          const SizedBox(width: 8),
                          Text('Issue Description', style: theme.textTheme.titleMedium),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        description.isNotEmpty ? description : 'No description provided.',
                        style: theme.textTheme.bodyMedium?.copyWith(height: 1.45),
                      ),
                      const Divider(height: 24),
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Reporter', style: TextStyle(fontSize: 11, color: muted)),
                                const SizedBox(height: 2),
                                Text(
                                  personName(issue['reporter_id'] as String?),
                                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                                ),
                              ],
                            ),
                          ),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Resolver (Assignee)', style: TextStyle(fontSize: 11, color: muted)),
                                const SizedBox(height: 2),
                                Text(
                                  personName(issue['assignee_id'] as String?),
                                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Independent Human Verification Card
                ApexCard(
                  padding: const EdgeInsets.all(16),
                  borderColor: ApexColors.violet.withValues(alpha: 0.3),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.verified_user_outlined, size: 20, color: ApexColors.violet),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Independent Verification',
                              style: theme.textTheme.titleMedium,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Enforced separation: The person resolving the issue cannot approve their own fix. An independent verifier must review the evidence.',
                        style: theme.textTheme.bodySmall?.copyWith(color: muted),
                      ),
                      const SizedBox(height: 14),

                      // Transition Actions
                      if (statusStr == 'OPEN' && editable)
                        FilledButton.icon(
                          onPressed: () => transition('start'),
                          icon: const Icon(Icons.play_arrow_rounded),
                          label: const Text('Start Work'),
                        )
                      else if (statusStr == 'IN_PROGRESS' && editable)
                        FilledButton.icon(
                          style: FilledButton.styleFrom(backgroundColor: ApexColors.violet),
                          onPressed: evidence.isEmpty
                              ? () {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Attach evidence before requesting verification.')),
                                  );
                                }
                              : () => transition('request'),
                          icon: const Icon(Icons.rate_review_outlined),
                          label: const Text('Request Verification'),
                        )
                      else if (statusStr == 'PENDING_VERIFICATION') ...[
                        if (independent) ...[
                          Row(
                            children: [
                              Expanded(
                                child: FilledButton(
                                  style: FilledButton.styleFrom(backgroundColor: ApexColors.green),
                                  onPressed: () => showReviewDialog(true, issue['verification_request_id'] as String?),
                                  child: const Text('Approve Fix'),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: () => showReviewDialog(false, issue['verification_request_id'] as String?),
                                  child: const Text('Reject'),
                                ),
                              ),
                            ],
                          ),
                        ] else ...[
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: ApexColors.amber.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: ApexColors.amber.withValues(alpha: 0.3)),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.shield_outlined, color: ApexColors.amber),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    isRequestedByMe
                                        ? 'Verification requested by you. Awaiting an independent verifier.'
                                        : 'Awaiting independent reviewer. Only authorized verifiers who did not resolve the fix can approve.',
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (isRequestedByMe) ...[
                            const SizedBox(height: 8),
                            TextButton(
                              onPressed: () => transition('withdraw', reqId: issue['verification_request_id'] as String?),
                              child: const Text('Withdraw for revision'),
                            ),
                          ],
                        ],
                      ] else if (statusStr == 'VERIFIED_RESOLVED' && canVerify) ...[
                        OutlinedButton.icon(
                          onPressed: () => transition('reopen'),
                          icon: const Icon(Icons.refresh_rounded),
                          label: const Text('Reopen Issue'),
                        ),
                      ],

                      // Review logs
                      if (reviews.isNotEmpty) ...[
                        const Divider(height: 24),
                        Text('Past Reviews', style: theme.textTheme.labelLarge),
                        const SizedBox(height: 8),
                        for (final r in reviews)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Row(
                              children: [
                                Icon(
                                  r['approved'] == true ? Icons.check_circle : Icons.cancel,
                                  color: r['approved'] == true ? ApexColors.green : ApexColors.danger,
                                  size: 16,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    '${r['approved'] == true ? "Approved" : "Rejected"} by ${personName(r['verifier_id'] as String?)}: ${r['notes'] ?? ""}',
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Task Checklist Card
                ApexCard(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Row(
                              children: [
                                const Icon(Icons.checklist_rounded, size: 20, color: ApexColors.cyan),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Tasks (${tasks.length})',
                                    style: theme.textTheme.titleMedium,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (editable)
                            IconButton(
                              icon: const Icon(Icons.add_rounded),
                              tooltip: 'Add Task',
                              onPressed: showAddTaskDialog,
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      if (tasks.isEmpty)
                        Text('No tasks added yet.', style: TextStyle(color: muted, fontSize: 13))
                      else
                        for (final t in tasks) ...[
                          CheckboxListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(
                              t['title'] as String? ?? 'Task',
                              style: TextStyle(
                                fontSize: 14,
                                decoration: t['status'] == 'DONE' ? TextDecoration.lineThrough : null,
                              ),
                            ),
                            subtitle: t['description'] != null && (t['description'] as String).isNotEmpty
                                ? Text(t['description'] as String, style: TextStyle(fontSize: 11, color: muted))
                                : null,
                            value: t['status'] == 'DONE',
                            onChanged: editable
                                ? (val) async {
                                    await ApexApiClient.saveTask(
                                      issueId: widget.issueId,
                                      title: t['title'] as String,
                                      status: val == true ? 'DONE' : 'TODO',
                                      taskId: t['id'] as String?,
                                    );
                                    load();
                                  }
                                : null,
                            secondary: editable
                                ? IconButton(
                                    icon: const Icon(Icons.delete_outline, size: 16),
                                    onPressed: () async {
                                      await ApexApiClient.deleteTask(
                                        issueId: widget.issueId,
                                        taskId: t['id'] as String,
                                      );
                                      load();
                                    },
                                  )
                                : null,
                          ),
                        ],
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Evidence Card
                ApexCard(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Row(
                              children: [
                                const Icon(Icons.attach_file_rounded, size: 20, color: ApexColors.coral),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Evidence Vault (${evidence.length})',
                                    style: theme.textTheme.titleMedium,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (editable)
                            IconButton(
                              icon: const Icon(Icons.add_rounded),
                              tooltip: 'Attach Evidence',
                              onPressed: showAddEvidenceDialog,
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      if (evidence.isEmpty)
                        Text('No evidence attached. Attach notes, URLs or files.', style: TextStyle(color: muted, fontSize: 13))
                      else
                        for (final e in evidence) ...[
                          Container(
                            margin: const EdgeInsets.symmetric(vertical: 4),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Chip(
                                      label: Text((e['kind'] as String? ?? 'note').toUpperCase(), style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold)),
                                      padding: EdgeInsets.zero,
                                      visualDensity: VisualDensity.compact,
                                    ),
                                    const Spacer(),
                                    Text(
                                      personName(e['uploader_id'] as String?),
                                      style: TextStyle(fontSize: 11, color: muted),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Text(e['description'] as String? ?? '', style: const TextStyle(fontSize: 13.5)),
                                if (e['value'] != null) ...[
                                  const SizedBox(height: 6),
                                  InkWell(
                                    onTap: () {
                                      final val = e['value'] as String;
                                      if (val.startsWith('http')) {
                                        launchUrl(Uri.parse(val), mode: LaunchMode.externalApplication);
                                      }
                                    },
                                    child: Text(
                                      e['value'] as String,
                                      style: const TextStyle(
                                        color: ApexColors.cyan,
                                        fontSize: 12,
                                        decoration: TextDecoration.underline,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Activity Timeline Card
                if (audit.isNotEmpty) ...[
                  ApexCard(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.history_rounded, size: 20, color: ApexColors.muted),
                            const SizedBox(width: 8),
                            Text('Activity Timeline', style: theme.textTheme.titleMedium),
                          ],
                        ),
                        const SizedBox(height: 10),
                        for (final a in audit.take(10)) ...[
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 5),
                            child: Row(
                              children: [
                                const Icon(Icons.circle, size: 6, color: ApexColors.coral),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    (a['action'] as String? ?? 'event').replaceAll('_', ' '),
                                    style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
                                  ),
                                ),
                                Text(
                                  personName(a['actor_id'] as String?),
                                  style: TextStyle(fontSize: 11, color: muted),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class CreateIssueScreen extends StatefulWidget {
  const CreateIssueScreen({super.key});

  @override
  State<CreateIssueScreen> createState() => _CreateIssueScreenState();
}

class _CreateIssueScreenState extends State<CreateIssueScreen> {
  final titleCtrl = TextEditingController();
  final descCtrl = TextEditingController();
  String priority = 'MEDIUM';
  String? selectedWorkspace;
  List<Map<String, dynamic>> workspaces = [];
  bool loading = true;
  bool submitting = false;
  String error = '';

  @override
  void initState() {
    super.initState();
    loadWorkspaces();
  }

  @override
  void dispose() {
    titleCtrl.dispose();
    descCtrl.dispose();
    super.dispose();
  }

  Future<void> loadWorkspaces() async {
    try {
      final res = await ApexApiClient.getWorkspaces();
      final items = (res['items'] as List?)?.cast<Map<String, dynamic>>() ?? [];
      if (mounted) {
        setState(() {
          workspaces = items;
          if (items.isNotEmpty) selectedWorkspace = items.first['id'] as String?;
        });
      }
    } catch (_) {} finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> create() async {
    final title = titleCtrl.text.trim();
    if (title.isEmpty || selectedWorkspace == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Title and workspace are required')),
      );
      return;
    }

    setState(() {
      submitting = true;
      error = '';
    });

    try {
      final res = await ApexApiClient.fileIssue(
        workspaceId: selectedWorkspace!,
        title: title,
        description: descCtrl.text.trim(),
        priority: priority,
      );

      if (res['ok'] == true && mounted) {
        final issueId = res['issueId'] as String;
        Navigator.pop(context, issueId);
      } else {
        throw Exception(res['error'] ?? 'Could not create issue');
      }
    } catch (e) {
      if (mounted) setState(() => error = e.toString().replaceAll('Exception: ', ''));
    } finally {
      if (mounted) setState(() => submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Issue'),
        actions: [
          TextButton(
            onPressed: submitting ? null : create,
            child: submitting
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('File Issue', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: ApexBackground(
        child: SafeArea(
          child: loading
              ? const Center(child: CircularProgressIndicator())
              : ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    if (error.isNotEmpty) ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: ApexColors.danger.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(error, style: const TextStyle(color: ApexColors.danger, fontSize: 13)),
                      ),
                      const SizedBox(height: 16),
                    ],
                    DropdownButtonFormField<String>(
                      decoration: InputDecoration(
                        labelText: 'Target Workspace',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      initialValue: selectedWorkspace,
                      items: [
                        for (final w in workspaces)
                          DropdownMenuItem(
                            value: w['id'] as String,
                            child: Text(w['name'] as String? ?? 'Workspace'),
                          ),
                      ],
                      onChanged: (val) => setState(() => selectedWorkspace = val),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: titleCtrl,
                      maxLength: 180,
                      decoration: InputDecoration(
                        labelText: 'Issue Title',
                        hintText: 'e.g. Payment gateway 401 error on checkout',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      decoration: InputDecoration(
                        labelText: 'Priority',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      initialValue: priority,
                      items: const [
                        DropdownMenuItem(value: 'LOW', child: Text('Low')),
                        DropdownMenuItem(value: 'MEDIUM', child: Text('Medium')),
                        DropdownMenuItem(value: 'HIGH', child: Text('High')),
                        DropdownMenuItem(value: 'CRITICAL', child: Text('Critical')),
                      ],
                      onChanged: (val) {
                        if (val != null) setState(() => priority = val);
                      },
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: descCtrl,
                      maxLines: 5,
                      maxLength: 4000,
                      decoration: InputDecoration(
                        labelText: 'Problem Description',
                        hintText: 'Detailed reproduction steps or observed defect…',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}
