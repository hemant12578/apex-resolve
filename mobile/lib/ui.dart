import 'package:material_ui/material_ui.dart';

import 'data.dart';
import 'theme.dart';

String greeting() {
  final hour = DateTime.now().hour;
  if (hour < 12) return 'Good morning';
  if (hour < 18) return 'Good afternoon';
  return 'Good evening';
}

String clockLabel(int? milliseconds) {
  final date = DateTime.fromMillisecondsSinceEpoch(milliseconds ?? 0);
  return '${date.hour.toString().padLeft(2, '0')}:'
      '${date.minute.toString().padLeft(2, '0')}';
}

String dayLabel(DateTime date) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(date.year, date.month, date.day);
  final difference = today.difference(day).inDays;
  if (difference == 0) return 'Today';
  if (difference == 1) return 'Yesterday';
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  return '${months[date.month - 1]} ${date.day}';
}

String firstName(String value) {
  final clean = value.trim();
  if (clean.isEmpty) return 'there';
  return clean.split(RegExp(r'\s+')).first;
}

/// Two-letter initials from a display name. Shared by Home, Chat and Settings.
String initials(String value) {
  final parts = value.trim().split(RegExp(r'\s+'));
  if (parts.isEmpty || parts.first.isEmpty) return 'A';
  if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
  return (parts.first.substring(0, 1) + parts.last.substring(0, 1))
      .toUpperCase();
}

/// Day label for chat date separators. Uses local time.
String chatDayLabel(int? milliseconds) {
  if (milliseconds == null) return '';
  final date = DateTime.fromMillisecondsSinceEpoch(milliseconds);
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(date.year, date.month, date.day);
  final difference = today.difference(day).inDays;
  if (difference == 0) return 'Today';
  if (difference == 1) return 'Yesterday';
  const months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  return '${months[date.month - 1]} ${date.day}, ${date.year}';
}

class ApexMark extends StatelessWidget {
  const ApexMark({super.key, this.size = 38});
  final double size;

  @override
  Widget build(BuildContext context) {
    final bar = size * .085;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: ApexGradients.primary,
        borderRadius: BorderRadius.circular(size * .3),
        boxShadow: [
          BoxShadow(
            color: ApexColors.rose.withValues(alpha: .28),
            blurRadius: size * .5,
            offset: Offset(0, size * .16),
          ),
        ],
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned(
            top: size * .3,
            left: size * .25,
            child: _MarkBar(width: size * .5, height: bar),
          ),
          Positioned(
            bottom: size * .3,
            left: size * .25,
            child: _MarkBar(
              width: size * .32,
              height: bar,
              opacity: .72,
            ),
          ),
        ],
      ),
    );
  }
}

class _MarkBar extends StatelessWidget {
  const _MarkBar({
    required this.width,
    required this.height,
    this.opacity = 1,
  });
  final double width, height, opacity;

  @override
  Widget build(BuildContext context) => Container(
    width: width,
    height: height,
    decoration: BoxDecoration(
      color: ApexColors.accentInk.withValues(alpha: opacity),
      borderRadius: BorderRadius.circular(height),
    ),
  );
}

class ApexBackground extends StatelessWidget {
  const ApexBackground({
    super.key,
    required this.child,
    this.chat = false,
    this.wallpaperStyle = ChatWallpaperStyle.aurora,
  });
  final Widget child;
  final bool chat;
  final ChatWallpaperStyle wallpaperStyle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    return Stack(
      children: [
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient:
                  chat
                      ? ApexGradients.chatWallpaper(theme.brightness, wallpaperStyle)
                      : LinearGradient(
                        colors: [
                          theme.scaffoldBackgroundColor,
                          (dark ? ApexColors.panel : ApexColors.paperPanel)
                              .withValues(alpha: .55),
                          theme.scaffoldBackgroundColor,
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
            ),
          ),
        ),
        Positioned(
          top: -130,
          right: -90,
          child: _Glow(
            color: ApexColors.coral.withValues(alpha: dark ? .16 : .2),
            size: 300,
          ),
        ),
        Positioned(
          bottom: -170,
          left: -120,
          child: _Glow(
            color: ApexColors.rose.withValues(alpha: dark ? .11 : .14),
            size: 340,
          ),
        ),
        if (chat)
          Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(
                painter: _ChatPatternPainter(
                  color: (dark ? Colors.white : Colors.black).withValues(
                    alpha: .035,
                  ),
                ),
              ),
            ),
          ),
        child,
      ],
    );
  }
}

class _Glow extends StatelessWidget {
  const _Glow({required this.color, required this.size});
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: size,
    height: size,
    child: DecoratedBox(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(colors: [color, color.withValues(alpha: 0)]),
      ),
    ),
  );
}

class _ChatPatternPainter extends CustomPainter {
  const _ChatPatternPainter({required this.color});
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint =
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1;
    const step = 54.0;
    for (double y = 18; y < size.height; y += step) {
      for (double x = 22; x < size.width; x += step) {
        canvas.drawCircle(Offset(x, y), 8, paint);
      }
    }
  }

  @override
  bool shouldRepaint(_ChatPatternPainter oldDelegate) =>
      oldDelegate.color != color;
}

class ApexAvatar extends StatelessWidget {
  const ApexAvatar({
    super.key,
    required this.initials,
    required this.seed,
    this.size = 46,
    this.ring = false,
    this.online = false,
    this.icon,
  });

  final String initials, seed;
  final double size;
  final bool ring, online;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final inner = ring ? size - 10 : size;
    final avatar = Container(
      width: inner,
      height: inner,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: _avatarGradient(seed),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: .18),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child:
          icon != null
              ? Icon(icon, size: inner * .44, color: Colors.white)
              : Text(
                initials,
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: inner * .34,
                  letterSpacing: -.3,
                ),
              ),
    );
    final body =
        ring
            ? Container(
              padding: const EdgeInsets.all(3),
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: ApexGradients.story,
              ),
              child: Container(
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: theme.colorScheme.surface,
                ),
                child: avatar,
              ),
            )
            : avatar;
    if (!online) return body;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        body,
        Positioned(
          right: 1,
          bottom: 1,
          child: Container(
            width: size * .27,
            height: size * .27,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: ApexColors.green,
              border: Border.all(color: theme.colorScheme.surface, width: 2.5),
            ),
          ),
        ),
      ],
    );
  }

  LinearGradient _avatarGradient(String value) {
    var hash = 0;
    for (final unit in value.codeUnits) {
      hash = (hash * 31 + unit) % 360;
    }
    final hue = hash.toDouble();
    final first = HSLColor.fromAHSL(1, hue, .52, .38).toColor();
    final second = HSLColor.fromAHSL(1, (hue + 46) % 360, .58, .24).toColor();
    return LinearGradient(
      colors: [first, second],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );
  }
}

class ApexStatusPill extends StatelessWidget {
  const ApexStatusPill({super.key, required this.status, this.compact = false});
  final ApexStatus status;
  final bool compact;

  @override
  Widget build(BuildContext context) => Container(
    padding: EdgeInsets.symmetric(
      horizontal: compact ? 7 : 9,
      vertical: compact ? 3 : 4,
    ),
    decoration: BoxDecoration(
      color: status.color.withValues(alpha: .14),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: status.color.withValues(alpha: .34)),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(status.icon, size: compact ? 11 : 12, color: status.color),
        const SizedBox(width: 4),
        Text(
          compact ? status.shortLabel : status.label,
          style: TextStyle(
            color: status.color,
            fontSize: compact ? 10 : 10.5,
            fontWeight: FontWeight.w800,
            letterSpacing: .1,
          ),
        ),
      ],
    ),
  );
}

class ApexSectionHeader extends StatelessWidget {
  const ApexSectionHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.action,
    this.onAction,
  });

  final String title;
  final String? subtitle;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: theme.textTheme.titleLarge),
              if (subtitle != null)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    subtitle!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
            ],
          ),
        ),
        if (action != null)
          TextButton(
            onPressed: onAction,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(action!),
                const SizedBox(width: 2),
                const Icon(Icons.arrow_outward_rounded, size: 15),
              ],
            ),
          ),
      ],
    );
  }
}

class ApexCard extends StatelessWidget {
  const ApexCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(14),
    this.onTap,
    this.gradient,
    this.borderColor,
    this.radius = 18,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final Gradient? gradient;
  final Color? borderColor;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final borderRadius = BorderRadius.circular(radius);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: gradient == null ? theme.colorScheme.surface : null,
        gradient: gradient,
        borderRadius: borderRadius,
        border: Border.all(color: borderColor ?? theme.colorScheme.outline),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(
              alpha: theme.brightness == Brightness.dark ? .16 : .05,
            ),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: borderRadius,
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}

class ApexEntryTile extends StatelessWidget {
  const ApexEntryTile({
    super.key,
    required this.entry,
    required this.onTap,
    this.showChevron = true,
  });

  final ApexEntry entry;
  final VoidCallback onTap;
  final bool showChevron;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ApexCard(
      onTap: onTap,
      padding: const EdgeInsets.all(11),
      child: Row(
        children: [
          entry.isIssue
              ? _StatusOrb(status: entry.status)
              : ApexAvatar(
                initials: entry.initials,
                seed: entry.seed,
                size: 48,
                ring: entry.isChat,
              ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  entry.subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (entry.isIssue)
            ApexStatusPill(status: entry.status, compact: true)
          else if (showChevron)
            Icon(
              Icons.chevron_right_rounded,
              color: theme.colorScheme.onSurfaceVariant,
              size: 22,
            ),
        ],
      ),
    );
  }
}

class _StatusOrb extends StatelessWidget {
  const _StatusOrb({required this.status});
  final ApexStatus status;

  @override
  Widget build(BuildContext context) => Container(
    width: 46,
    height: 46,
    decoration: BoxDecoration(
      color: status.color.withValues(alpha: .13),
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: status.color.withValues(alpha: .3)),
    ),
    child: Icon(status.icon, color: status.color, size: 21),
  );
}

class ApexEmpty extends StatelessWidget {
  const ApexEmpty({
    super.key,
    required this.icon,
    required this.title,
    required this.body,
    this.action,
    this.onAction,
  });

  final IconData icon;
  final String title, body;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 34),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  ApexColors.coral.withValues(alpha: .22),
                  ApexColors.rose.withValues(alpha: .12),
                ],
              ),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: theme.colorScheme.outline),
            ),
            child: Icon(icon, size: 30, color: ApexColors.coral),
          ),
          const SizedBox(height: 14),
          Text(
            title,
            textAlign: TextAlign.center,
            style: theme.textTheme.titleLarge,
          ),
          const SizedBox(height: 6),
          Text(
            body,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          if (action != null) ...[
            const SizedBox(height: 16),
            FilledButton(onPressed: onAction, child: Text(action!)),
          ],
        ],
      ),
    );
  }
}

Future<T?> showApexSheet<T>(
  BuildContext context, {
  required String title,
  required Widget child,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder:
        (sheet) => Padding(
          padding: EdgeInsets.fromLTRB(
            20,
            0,
            20,
            20 + MediaQuery.viewInsetsOf(sheet).bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: Theme.of(sheet).textTheme.titleLarge,
                    ),
                  ),
                  IconButton(
                    tooltip: 'Close',
                    onPressed: () => Navigator.pop(sheet),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Flexible(child: SingleChildScrollView(child: child)),
            ],
          ),
        ),
  );
}

class ApexNavBar extends StatelessWidget {
  const ApexNavBar({
    super.key,
    required this.index,
    required this.onTap,
  });

  final int index;
  final ValueChanged<int> onTap;

  static const items = [
    (Icons.explore_outlined, Icons.explore_rounded, 'Explore'),
    (Icons.forum_outlined, Icons.forum_rounded, 'Chats'),
    (Icons.fact_check_outlined, Icons.fact_check_rounded, 'Resolve'),
    (Icons.tune_outlined, Icons.tune_rounded, 'Settings'),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      top: false,
      child: Container(
        margin: const EdgeInsets.fromLTRB(14, 0, 14, 12),
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface.withValues(alpha: .97),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: theme.colorScheme.outline),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: .28),
              blurRadius: 28,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: Row(
          children: [
            for (final (i, item) in items.indexed)
              Expanded(
                child: InkWell(
                  onTap: () => onTap(i),
                  borderRadius: BorderRadius.circular(18),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    curve: Curves.easeOut,
                    padding: const EdgeInsets.symmetric(vertical: 9),
                    decoration: BoxDecoration(
                      color:
                          i == index
                              ? theme.colorScheme.primary.withValues(alpha: .14)
                              : Colors.transparent,
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          i == index ? item.$2 : item.$1,
                          size: 21,
                          color:
                              i == index
                                  ? theme.colorScheme.primary
                                  : theme.colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          item.$3,
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight:
                                i == index ? FontWeight.w800 : FontWeight.w600,
                            color:
                                i == index
                                    ? theme.colorScheme.primary
                                    : theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
