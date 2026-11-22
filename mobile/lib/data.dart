import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import 'theme.dart';

enum ApexStatus { open, inProgress, review, verified, todo, done, unknown }

extension ApexStatusStyle on ApexStatus {
  String get label => switch (this) {
    ApexStatus.open => 'Open',
    ApexStatus.inProgress => 'In progress',
    ApexStatus.review => 'Review',
    ApexStatus.verified => 'Verified',
    ApexStatus.todo => 'To do',
    ApexStatus.done => 'Done',
    ApexStatus.unknown => 'Conversation',
  };

  String get shortLabel => switch (this) {
    ApexStatus.open => 'Open',
    ApexStatus.inProgress => 'Working',
    ApexStatus.review => 'Review',
    ApexStatus.verified => 'Verified',
    ApexStatus.todo => 'To do',
    ApexStatus.done => 'Done',
    ApexStatus.unknown => 'Chat',
  };

  Color get color => switch (this) {
    ApexStatus.open => ApexColors.coral,
    ApexStatus.inProgress => ApexColors.cyan,
    ApexStatus.review => ApexColors.violet,
    ApexStatus.verified => ApexColors.green,
    ApexStatus.todo => ApexColors.muted,
    ApexStatus.done => ApexColors.green,
    ApexStatus.unknown => ApexColors.coral,
  };

  IconData get icon => switch (this) {
    ApexStatus.open => Icons.bolt_rounded,
    ApexStatus.inProgress => Icons.autorenew_rounded,
    ApexStatus.review => Icons.verified_outlined,
    ApexStatus.verified => Icons.check_circle_outline_rounded,
    ApexStatus.todo => Icons.radio_button_unchecked_rounded,
    ApexStatus.done => Icons.task_alt_rounded,
    ApexStatus.unknown => Icons.forum_outlined,
  };

  bool get isActive => this == ApexStatus.open || this == ApexStatus.inProgress;
}

class ApexEntry {
  const ApexEntry({
    required this.title,
    required this.detail,
    required this.path,
    required this.section,
  });

  final String title;
  final String detail;
  final String path;
  final String section;

  factory ApexEntry.fromJson(Map<String, dynamic> json, String section) {
    return ApexEntry(
      title: (json['title'] ?? 'Untitled').toString(),
      detail: (json['detail'] ?? '').toString(),
      path: (json['path'] ?? '').toString(),
      section: section,
    );
  }

  bool get isIssue => section == 'issues';
  bool get isChat => section == 'chats';
  bool get isGroup => section == 'groups';

  String get initials {
    final clean = title.trim();
    if (clean.isEmpty) return 'A';
    final parts = clean.split(RegExp(r'\s+')).where((e) => e.isNotEmpty);
    if (parts.length == 1) {
      return parts.first.characters.take(1).toString().toUpperCase();
    }
    return (parts.first.characters.take(1).toString() +
            parts.last.characters.take(1).toString())
        .toUpperCase();
  }

  String get seed => '$title$path';

  ApexStatus get status {
    if (!isIssue) return ApexStatus.unknown;
    final head = detail.split('·').first.trim().toLowerCase();
    return switch (head) {
      'open' => ApexStatus.open,
      'in progress' => ApexStatus.inProgress,
      'pending verification' => ApexStatus.review,
      'verified resolved' => ApexStatus.verified,
      'todo' || 'to do' => ApexStatus.todo,
      'done' => ApexStatus.done,
      _ => ApexStatus.unknown,
    };
  }

  String get priority {
    if (!isIssue) return '';
    final parts = detail.split('·');
    return parts.length > 1 ? parts.last.trim() : '';
  }

  bool get needsReview => status == ApexStatus.review;
  bool get isCritical =>
      priority.toLowerCase() == 'critical' &&
      status != ApexStatus.verified &&
      status != ApexStatus.done;
  bool get isOpen => status == ApexStatus.open;

  String get subtitle {
    if (isIssue) {
      final bits = <String>[status.label];
      if (priority.isNotEmpty) bits.add(priority);
      return bits.join(' · ');
    }
    return detail.isEmpty ? 'Open conversation' : detail;
  }
}

class ApexWorkspace {
  const ApexWorkspace({
    required this.chats,
    required this.groups,
    required this.issues,
  });

  final List<ApexEntry> chats;
  final List<ApexEntry> groups;
  final List<ApexEntry> issues;

  int get openCount => issues.where((e) => e.isOpen).length;
  int get workingCount =>
      issues.where((e) => e.status == ApexStatus.inProgress).length;
  int get reviewCount => issues.where((e) => e.needsReview).length;
  int get verifiedCount =>
      issues.where((e) => e.status == ApexStatus.verified).length;

  List<ApexEntry> get alerts {
    final review = issues.where((e) => e.needsReview);
    final critical = issues.where((e) => e.isCritical);
    final open = issues.where((e) => e.isOpen);
    final seen = <String>{};
    final ordered = <ApexEntry>[];
    for (final entry in [...review, ...critical, ...open]) {
      if (seen.add(entry.path)) ordered.add(entry);
    }
    return ordered;
  }

  List<ApexEntry> get pulse => [...chats, ...groups].take(10).toList();
}

Future<List<ApexEntry>> loadDirectory(String section) async {
  final raw = await const MethodChannel(
    'apex/session',
  ).invokeMethod<String>('directory', {'section': section});
  final result = jsonDecode(raw ?? '{}') as Map<String, dynamic>;
  final items = result['items'] as List? ?? const [];
  return items
      .whereType<Map>()
      .map((e) => ApexEntry.fromJson(Map<String, dynamic>.from(e), section))
      .toList();
}

Future<ApexWorkspace> loadWorkspace() async {
  final results = await Future.wait([
    loadDirectory('chats'),
    loadDirectory('groups'),
    loadDirectory('issues'),
  ]);
  return ApexWorkspace(
    chats: results[0],
    groups: results[1],
    issues: results[2],
  );
}
