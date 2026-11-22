import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import 'session.dart';
import 'theme.dart';
import 'ui.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({
    super.key,
    required this.theme,
    required this.onOpenWorkspace,
  });
  final ThemeController theme;
  final Future<void> Function() onOpenWorkspace;
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool signingOut = false;

  Future<void> signOut() async {
    if (signingOut) return;
    setState(() => signingOut = true);
    try {
      final cleared = await const MethodChannel(
        'apex/session',
      ).invokeMethod<bool>('logout');
      if (cleared != true) throw StateError('Sign-out incomplete');
    } catch (_) {
      if (mounted) {
        setState(() => signingOut = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not sign out. Please try again.'),
          ),
        );
      }
      return;
    }
    ApexSession.clear();
    ApexSession.expire();
    if (mounted) Navigator.of(context).popUntil((route) => route.isFirst);
  }

  Future<void> openWorkspace() async {
    Navigator.of(context).pop();
    await widget.onOpenWorkspace();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    final name =
        ApexSession.name.isEmpty ? 'Workspace member' : ApexSession.name;
    final email =
        ApexSession.email.isEmpty
            ? 'Signed in to Apex Resolve'
            : ApexSession.email;
    return Scaffold(
      body: ApexBackground(
        child: SafeArea(
          child: AnimatedBuilder(
            animation: widget.theme,
            builder:
                (context, _) => ListView(
                  padding: const EdgeInsets.fromLTRB(18, 8, 18, 40),
                  children: [
                    Row(
                      children: [
                        IconButton(
                          tooltip: 'Back',
                          onPressed: () => Navigator.of(context).pop(),
                          icon: const Icon(Icons.arrow_back_rounded),
                        ),
                        const SizedBox(width: 4),
                        Text('Settings', style: theme.textTheme.headlineSmall),
                      ],
                    ),
                    const SizedBox(height: 14),
                    ApexCard(
                      padding: const EdgeInsets.all(18),
                      gradient: ApexGradients.surfaceGlow(theme.brightness),
                      borderColor: ApexColors.coral.withValues(alpha: .26),
                      child: Row(
                        children: [
                          ApexAvatar(
                            initials: initials(name),
                            seed: name,
                            size: 58,
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.titleLarge?.copyWith(
                                    fontSize: 19,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  email,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: muted,
                                    fontSize: 11.5,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                GestureDetector(
                                  onTap: openWorkspace,
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        'Edit on workspace',
                                        style: theme.textTheme.labelSmall
                                            ?.copyWith(
                                              color: ApexColors.coral,
                                              fontWeight: FontWeight.w800,
                                              fontSize: 11,
                                            ),
                                      ),
                                      const SizedBox(width: 3),
                                      const Icon(
                                        Icons.arrow_outward_rounded,
                                        size: 13,
                                        color: ApexColors.coral,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    const _SectionLabel('APPEARANCE'),
                    const SizedBox(height: 8),
                    ApexCard(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.palette_outlined,
                                size: 18,
                                color: theme.colorScheme.primary,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Theme',
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontSize: 14,
                                ),
                              ),
                              const Spacer(),
                              Text(
                                widget.theme.label,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: muted,
                                  fontSize: 11.5,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              for (final (mode, label) in const [
                                (ThemeMode.system, 'System'),
                                (ThemeMode.light, 'Daylight'),
                                (ThemeMode.dark, 'Midnight'),
                              ])
                                Expanded(
                                  child: Padding(
                                    padding: const EdgeInsets.only(right: 6),
                                    child: _ThemeTile(
                                      label: label,
                                      mode: mode,
                                      selected: widget.theme.mode == mode,
                                      onTap: () => widget.theme.setMode(mode),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Daylight is a calm paper theme. Midnight is the warm ink cockpit.',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: muted,
                              fontSize: 11,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 22),
                    const _SectionLabel('WORKSPACE'),
                    const SizedBox(height: 8),
                    ApexCard(
                      padding: EdgeInsets.zero,
                      child: Column(
                        children: [
                          _SettingsTile(
                            icon: Icons.badge_outlined,
                            title: 'Account and profile',
                            subtitle: 'Username, email and password',
                            onTap: openWorkspace,
                          ),
                          _SettingsTile(
                            icon: Icons.face_retouching_natural_outlined,
                            title: 'Chat identity',
                            subtitle: 'How you appear in conversations',
                            onTap: openWorkspace,
                          ),
                          _SettingsTile(
                            icon: Icons.notifications_none_rounded,
                            title: 'Notifications',
                            subtitle: 'Alerts for reviews and replies',
                            onTap: openWorkspace,
                          ),
                          _SettingsTile(
                            icon: Icons.space_dashboard_outlined,
                            title: 'Home view',
                            subtitle: 'Start in Communication or Resolution',
                            onTap: openWorkspace,
                            last: true,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 22),
                    const _SectionLabel('ABOUT'),
                    const SizedBox(height: 8),
                    ApexCard(
                      padding: EdgeInsets.zero,
                      child: Column(
                        children: [
                          _SettingsTile(
                            icon: Icons.verified_outlined,
                            title: 'Apex Resolve for Android',
                            subtitle:
                                'Version 1.1.0 · conversation → verified fix',
                          ),
                          _SettingsTile(
                            icon: Icons.shield_outlined,
                            title: 'ProofGuard',
                            subtitle:
                                'Evidence integrity and independent review',
                            last: true,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 22),
                    OutlinedButton.icon(
                      onPressed: signingOut ? null : signOut,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: ApexColors.danger,
                        side: BorderSide(
                          color: ApexColors.danger.withValues(alpha: .5),
                        ),
                      ),
                      icon: const Icon(Icons.logout_rounded, size: 18),
                      label: Text(signingOut ? 'Signing out…' : 'Sign out'),
                    ),
                    const SizedBox(height: 10),
                    Center(
                      child: Text(
                        'Signed in on this device',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: muted,
                          fontSize: 10.5,
                        ),
                      ),
                    ),
                  ],
                ),
          ),
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Container(width: 16, height: 2, color: ApexColors.coral),
        const SizedBox(width: 7),
        Text(
          text,
          style: theme.textTheme.labelSmall?.copyWith(
            color: ApexColors.coral,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.1,
            fontSize: 9.5,
          ),
        ),
      ],
    );
  }
}

class _ThemeTile extends StatelessWidget {
  const _ThemeTile({
    required this.label,
    required this.mode,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final ThemeMode mode;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final previewDark =
        mode == ThemeMode.dark ||
        (mode == ThemeMode.system &&
            MediaQuery.platformBrightnessOf(context) == Brightness.dark);
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color:
              selected
                  ? theme.colorScheme.primary.withValues(alpha: .12)
                  : theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(13),
          border: Border.all(
            color:
                selected
                    ? theme.colorScheme.primary.withValues(alpha: .65)
                    : theme.colorScheme.outline,
            width: selected ? 1.4 : 1,
          ),
        ),
        child: Column(
          children: [
            Container(
              height: 34,
              decoration: BoxDecoration(
                gradient:
                    previewDark
                        ? const LinearGradient(
                          colors: [ApexColors.ink, ApexColors.panel2],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        )
                        : const LinearGradient(
                          colors: [ApexColors.paper, ApexColors.paperPanel2],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: previewDark ? ApexColors.line : ApexColors.paperLine,
                ),
              ),
              child: Center(
                child: Container(
                  width: 26,
                  height: 8,
                  decoration: BoxDecoration(
                    gradient: ApexGradients.primary,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (selected) ...[
                  Icon(
                    Icons.check_circle_rounded,
                    size: 12,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 3),
                ],
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                    color:
                        selected
                            ? theme.colorScheme.primary
                            : theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  const _SettingsTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.onTap,
    this.last = false,
  });
  final IconData icon;
  final String title, subtitle;
  final VoidCallback? onTap;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          decoration: BoxDecoration(
            border:
                last
                    ? null
                    : Border(
                      bottom: BorderSide(color: theme.colorScheme.outline),
                    ),
          ),
          child: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: ApexColors.coral.withValues(alpha: .11),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(icon, size: 17, color: ApexColors.coral),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontSize: 13,
                      ),
                    ),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              if (onTap != null)
                Icon(
                  Icons.chevron_right_rounded,
                  size: 20,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
