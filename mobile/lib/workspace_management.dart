import 'package:material_ui/material_ui.dart';

import 'api_client.dart';
import 'theme.dart';
import 'ui.dart';

class WorkspaceManagementScreen extends StatefulWidget {
  const WorkspaceManagementScreen({super.key});

  @override
  State<WorkspaceManagementScreen> createState() => _WorkspaceManagementScreenState();
}

class _WorkspaceManagementScreenState extends State<WorkspaceManagementScreen> {
  bool loading = true;
  String error = '';
  List<Map<String, dynamic>> workspaces = [];

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
      final res = await ApexApiClient.getWorkspaces();
      final items = (res['items'] as List?)?.cast<Map<String, dynamic>>() ?? [];
      if (mounted) setState(() => workspaces = items);
    } catch (e) {
      if (mounted) setState(() => error = 'Could not load workspaces');
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  void showCreateDialog({bool isCommunity = false}) {
    final nameCtrl = TextEditingController();
    final descCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isCommunity ? 'Create Community' : 'Create Workspace'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              decoration: InputDecoration(
                labelText: isCommunity ? 'Community Name' : 'Workspace Name',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: descCtrl,
              maxLines: 2,
              decoration: InputDecoration(
                labelText: 'Description',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              if (nameCtrl.text.trim().isEmpty) return;
              Navigator.pop(ctx);
              await ApexApiClient.createWorkspace(
                name: nameCtrl.text.trim(),
                description: descCtrl.text.trim(),
                isCommunity: isCommunity,
              );
              load();
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  void showEditDialog(Map<String, dynamic> w) {
    final nameCtrl = TextEditingController(text: w['name'] as String? ?? '');
    final descCtrl = TextEditingController(text: w['description'] as String? ?? '');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit Workspace'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              decoration: InputDecoration(
                labelText: 'Name',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: descCtrl,
              maxLines: 3,
              decoration: InputDecoration(
                labelText: 'Description',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              if (nameCtrl.text.trim().isEmpty) return;
              Navigator.pop(ctx);
              await ApexApiClient.updateWorkspace(
                workspaceId: w['id'] as String,
                name: nameCtrl.text.trim(),
                description: descCtrl.text.trim(),
              );
              load();
            },
            child: const Text('Save Changes'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Workspaces & Communities'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_rounded),
            tooltip: 'Create Community',
            onPressed: () => showCreateDialog(isCommunity: true),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: ApexBackground(
        child: SafeArea(
          child: loading
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                  onRefresh: load,
                  child: ListView(
                    padding: const EdgeInsets.all(18),
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Your Environments', style: theme.textTheme.titleMedium),
                          FilledButton.tonalIcon(
                            onPressed: () => showCreateDialog(isCommunity: false),
                            icon: const Icon(Icons.add, size: 16),
                            label: const Text('New Space'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      if (workspaces.isEmpty)
                        Center(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 40),
                            child: Column(
                              children: [
                                const Icon(Icons.domain_disabled_rounded, size: 48, color: ApexColors.muted),
                                const SizedBox(height: 12),
                                Text('No workspaces joined yet', style: theme.textTheme.titleMedium),
                              ],
                            ),
                          ),
                        )
                      else
                        for (final w in workspaces) ...[
                          ApexCard(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      w['isCommunity'] == true
                                          ? Icons.groups_rounded
                                          : Icons.business_center_rounded,
                                      color: ApexColors.coral,
                                      size: 22,
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            w['name'] as String? ?? 'Workspace',
                                            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                                          ),
                                          Text(
                                            w['isCommunity'] == true ? 'Community Group' : 'Main Workspace',
                                            style: TextStyle(color: muted, fontSize: 11),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Chip(
                                      label: Text(
                                        (w['role'] as String? ?? 'member').toUpperCase(),
                                        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                                      ),
                                      padding: EdgeInsets.zero,
                                      visualDensity: VisualDensity.compact,
                                    ),
                                  ],
                                ),
                                if (w['description'] != null && (w['description'] as String).isNotEmpty) ...[
                                  const SizedBox(height: 8),
                                  Text(
                                    w['description'] as String,
                                    style: TextStyle(color: muted, fontSize: 12.5),
                                  ),
                                ],
                                const Divider(height: 20),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    if (w['isOwner'] == true || ['admin', 'owner'].contains(w['role']))
                                      TextButton.icon(
                                        onPressed: () => showEditDialog(w),
                                        icon: const Icon(Icons.edit_outlined, size: 16),
                                        label: const Text('Edit'),
                                      ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                        ],
                    ],
                  ),
                ),
        ),
      ),
    );
  }
}
