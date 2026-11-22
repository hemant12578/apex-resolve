import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:material_ui/material_ui.dart';

import 'api_client.dart';
import 'session.dart';
import 'theme.dart';
import 'ui.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final nameCtrl = TextEditingController();
  final bioCtrl = TextEditingController();
  final picker = ImagePicker();

  bool loading = true;
  bool saving = false;
  String error = '';
  String email = '';
  String handle = '';
  String? avatarUrl;
  Uint8List? localAvatarBytes;
  List<Map<String, dynamic>> memberships = [];

  @override
  void initState() {
    super.initState();
    nameCtrl.text = ApexSession.name;
    email = ApexSession.email;
    loadProfile();
  }

  @override
  void dispose() {
    nameCtrl.dispose();
    bioCtrl.dispose();
    super.dispose();
  }

  Future<void> loadProfile() async {
    setState(() => loading = true);
    try {
      final res = await ApexApiClient.getProfile();
      final u = (res['user'] as Map?)?.cast<String, dynamic>();
      if (u != null && mounted) {
        setState(() {
          nameCtrl.text = u['displayName'] as String? ?? ApexSession.name;
          email = u['email'] as String? ?? ApexSession.email;
          handle = u['handle'] as String? ?? '';
          bioCtrl.text = u['bio'] as String? ?? '';
          avatarUrl = u['avatarUrl'] as String?;
          memberships = (u['memberships'] as List?)?.cast<Map<String, dynamic>>() ?? [];
        });
      }
    } catch (_) {
      // Non-blocking: keep initial session values
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> pickPhoto(ImageSource source) async {
    try {
      final file = await picker.pickImage(
        source: source,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 85,
      );
      if (file == null) return;

      final bytes = await file.readAsBytes();
      setState(() {
        localAvatarBytes = bytes;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not access image: $e')),
        );
      }
    }
  }

  void showPhotoOptions() {
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
              ListTile(
                leading: const Icon(Icons.photo_library_outlined),
                title: const Text('Choose from Gallery'),
                onTap: () {
                  Navigator.pop(ctx);
                  pickPhoto(ImageSource.gallery);
                },
              ),
              ListTile(
                leading: const Icon(Icons.camera_alt_outlined),
                title: const Text('Take Photo with Camera'),
                onTap: () {
                  Navigator.pop(ctx);
                  pickPhoto(ImageSource.camera);
                },
              ),
              if (localAvatarBytes != null || avatarUrl != null)
                ListTile(
                  leading: const Icon(Icons.delete_outline, color: ApexColors.danger),
                  title: const Text('Remove Photo', style: TextStyle(color: ApexColors.danger)),
                  onTap: () {
                    Navigator.pop(ctx);
                    setState(() {
                      localAvatarBytes = null;
                      avatarUrl = null;
                    });
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> saveProfile() async {
    final cleanName = nameCtrl.text.trim();
    if (cleanName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Display name cannot be empty')),
      );
      return;
    }

    setState(() {
      saving = true;
      error = '';
    });

    try {
      String? base64Photo;
      if (localAvatarBytes != null) {
        base64Photo = base64Encode(localAvatarBytes!);
      }

      final res = await ApexApiClient.updateProfile(
        displayName: cleanName,
        bio: bioCtrl.text.trim(),
        avatarBase64: base64Photo,
      );

      if (res['ok'] == true && mounted) {
        ApexSession.remember(displayName: cleanName, address: email);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile updated successfully!')),
        );
        Navigator.pop(context, true);
      } else {
        throw Exception(res['error'] ?? 'Could not save profile');
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          error = e.toString().replaceAll('Exception: ', '');
        });
      }
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final displayName = nameCtrl.text.trim().isNotEmpty ? nameCtrl.text.trim() : 'Account';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Profile'),
        actions: [
          TextButton(
            onPressed: saving ? null : saveProfile,
            child: saving
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Save', style: TextStyle(fontWeight: FontWeight.w700)),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: ApexBackground(
        child: SafeArea(
          child: loading
              ? const Center(child: CircularProgressIndicator())
              : ListView(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
                  children: [
                    Center(
                      child: Stack(
                        children: [
                          if (localAvatarBytes != null)
                            CircleAvatar(
                              radius: 50,
                              backgroundImage: MemoryImage(localAvatarBytes!),
                            )
                          else if (avatarUrl != null && avatarUrl!.startsWith('http'))
                            CircleAvatar(
                              radius: 50,
                              backgroundImage: NetworkImage(avatarUrl!),
                            )
                          else
                            ApexAvatar(
                              initials: initials(displayName),
                              seed: displayName,
                              size: 100,
                              ring: true,
                            ),
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: Material(
                              color: ApexColors.coral,
                              shape: const CircleBorder(),
                              elevation: 2,
                              child: InkWell(
                                onTap: showPhotoOptions,
                                customBorder: const CircleBorder(),
                                child: const Padding(
                                  padding: EdgeInsets.all(8),
                                  child: Icon(Icons.camera_alt, color: Colors.white, size: 20),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Center(
                      child: TextButton.icon(
                        onPressed: showPhotoOptions,
                        icon: const Icon(Icons.photo_camera_outlined, size: 16),
                        label: const Text('Change Profile Photo'),
                      ),
                    ),
                    if (handle.isNotEmpty)
                      Center(
                        child: Text(
                          handle,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: ApexColors.coral,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    const SizedBox(height: 24),
                    if (error.isNotEmpty) ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: ApexColors.danger.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: ApexColors.danger.withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.error_outline, color: ApexColors.danger, size: 18),
                            const SizedBox(width: 8),
                            Expanded(child: Text(error, style: const TextStyle(fontSize: 12.5))),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                    ApexCard(
                      padding: const EdgeInsets.all(18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Profile Details', style: theme.textTheme.titleMedium),
                          const SizedBox(height: 16),
                          TextField(
                            controller: nameCtrl,
                            maxLength: 100,
                            decoration: InputDecoration(
                              labelText: 'Display Name',
                              counterText: '',
                              prefixIcon: const Icon(Icons.person_outline),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                          const SizedBox(height: 16),
                          TextField(
                            controller: bioCtrl,
                            maxLength: 500,
                            maxLines: 3,
                            decoration: InputDecoration(
                              labelText: 'Bio / Status',
                              hintText: 'Share what you work on or focus areas…',
                              prefixIcon: const Icon(Icons.info_outline),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                          const SizedBox(height: 16),
                          TextField(
                            enabled: false,
                            controller: TextEditingController(text: email),
                            decoration: InputDecoration(
                              labelText: 'Email Address (Verified)',
                              prefixIcon: const Icon(Icons.mail_outline),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    if (memberships.isNotEmpty) ...[
                      ApexCard(
                        padding: const EdgeInsets.all(18),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Workspace Memberships', style: theme.textTheme.titleMedium),
                            const SizedBox(height: 12),
                            for (final m in memberships)
                              Padding(
                                padding: const EdgeInsets.symmetric(vertical: 6),
                                child: Row(
                                  children: [
                                    Icon(
                                      m['isCommunity'] == true
                                          ? Icons.groups_rounded
                                          : Icons.business_center_rounded,
                                      size: 20,
                                      color: ApexColors.coral,
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        m['name'] as String? ?? 'Workspace',
                                        style: const TextStyle(fontWeight: FontWeight.w600),
                                      ),
                                    ),
                                    Chip(
                                      label: Text(
                                        (m['role'] as String? ?? 'member').toUpperCase(),
                                        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                                      ),
                                      padding: EdgeInsets.zero,
                                      visualDensity: VisualDensity.compact,
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
        ),
      ),
    );
  }
}
