import 'dart:convert';
import 'package:flutter/services.dart';

class ApexApiClient {
  const ApexApiClient._();

  static const _channel = MethodChannel('apex/session');

  /// Perform an authenticated request through the native cookie session bridge.
  static Future<dynamic> request({
    required String path,
    String method = 'GET',
    Map<String, dynamic>? data,
  }) async {
    final raw = await _channel.invokeMethod<String>('api', {
      'path': path,
      'method': method,
      if (data != null) 'data': data,
    });
    if (raw == null || raw.isEmpty) return null;
    return jsonDecode(raw);
  }

  /// Get directory entries (chats, groups, issues, knowledge)
  static Future<Map<String, dynamic>> directory(String section) async {
    final raw = await _channel.invokeMethod<String>('directory', {'section': section});
    return jsonDecode(raw ?? '{}') as Map<String, dynamic>;
  }

  /// Obtain a real-time Nexconn chat session for direct peer, group community, or issue room
  static Future<Map<String, dynamic>> chatSession({
    String? peerId,
    String? communityId,
    String? issueId,
  }) async {
    final target = <String, String>{};
    if (peerId != null) target['peerId'] = peerId;
    if (communityId != null) target['communityId'] = communityId;
    if (issueId != null) target['issueId'] = issueId;

    final raw = await _channel.invokeMethod<String>('chat', target);
    return jsonDecode(raw ?? '{}') as Map<String, dynamic>;
  }

  /// Ask Apex AI assistant using the OpenRouter backend
  static Future<Map<String, dynamic>> askApex(List<Map<String, String>> messages) async {
    final res = await request(
      path: '/api/mobile/ai',
      method: 'POST',
      data: {'messages': messages},
    );
    return (res as Map?)?.cast<String, dynamic>() ?? {};
  }

  /// Search user directory with handle matching and contact status
  static Future<Map<String, dynamic>> searchUsers(String query, {int page = 1}) async {
    final q = Uri.encodeComponent(query.trim());
    final res = await request(path: '/api/mobile/users?q=$q&page=$page');
    return (res as Map?)?.cast<String, dynamic>() ?? {};
  }

  /// Perform a contact action: 'request', 'accept', 'decline', or 'pin'
  static Future<Map<String, dynamic>> contactAction({
    required String peer,
    required String operation,
    String? pin,
  }) async {
    final res = await request(
      path: '/api/mobile/contacts',
      method: 'POST',
      data: {
        'peer': peer,
        'operation': operation,
        if (pin != null) 'pin': pin,
      },
    );
    return (res as Map?)?.cast<String, dynamic>() ?? {};
  }

  /// Get full issue details including tasks, evidence, audit timeline, and permissions
  static Future<Map<String, dynamic>> getIssue(String issueId) async {
    final res = await request(path: '/api/mobile/issues?id=$issueId');
    return (res as Map?)?.cast<String, dynamic>() ?? {};
  }

  /// Transition issue status (start, request, approve, reject, withdraw, reopen)
  static Future<Map<String, dynamic>> transitionIssue({
    required String issueId,
    required String action,
    String? notes,
    List<String>? tags,
    String? reviewRequest,
  }) async {
    final res = await request(
      path: '/api/mobile/issues',
      method: 'POST',
      data: {
        'op': 'transition',
        'issueId': issueId,
        'action': action,
        if (notes != null) 'notes': notes,
        if (tags != null) 'tags': tags,
        if (reviewRequest != null) 'reviewRequest': reviewRequest,
      },
    );
    return (res as Map?)?.cast<String, dynamic>() ?? {};
  }

  /// Save or update a task item on an issue
  static Future<Map<String, dynamic>> saveTask({
    required String issueId,
    required String title,
    String? description,
    String status = 'TODO',
    String? assigneeId,
    String? taskId,
  }) async {
    final res = await request(
      path: '/api/mobile/issues',
      method: 'POST',
      data: {
        'op': 'task',
        'issueId': issueId,
        'title': title,
        if (description != null) 'description': description,
        'status': status,
        if (assigneeId != null) 'assigneeId': assigneeId,
        if (taskId != null) 'id': taskId,
      },
    );
    return (res as Map?)?.cast<String, dynamic>() ?? {};
  }

  /// Delete a task item
  static Future<Map<String, dynamic>> deleteTask({
    required String issueId,
    required String taskId,
  }) async {
    final res = await request(
      path: '/api/mobile/issues',
      method: 'POST',
      data: {
        'op': 'deleteTask',
        'issueId': issueId,
        'id': taskId,
      },
    );
    return (res as Map?)?.cast<String, dynamic>() ?? {};
  }

  /// Attach evidence to an issue (note, url, or file)
  static Future<Map<String, dynamic>> addEvidence({
    required String issueId,
    required String kind,
    required String description,
    String? value,
    String? fileBase64,
    String? fileName,
    String? fileType,
  }) async {
    final res = await request(
      path: '/api/mobile/issues',
      method: 'POST',
      data: {
        'op': 'evidence',
        'issueId': issueId,
        'kind': kind,
        'description': description,
        if (value != null) 'value': value,
        if (fileBase64 != null) 'fileBase64': fileBase64,
        if (fileName != null) 'fileName': fileName,
        if (fileType != null) 'fileType': fileType,
      },
    );
    return (res as Map?)?.cast<String, dynamic>() ?? {};
  }

  /// Create a new issue in a workspace
  static Future<Map<String, dynamic>> fileIssue({
    required String workspaceId,
    required String title,
    required String description,
    String priority = 'MEDIUM',
    String? assigneeId,
    List<String>? affected,
    String? source,
  }) async {
    final res = await request(
      path: '/api/mobile/issues',
      method: 'POST',
      data: {
        'op': 'issue',
        'workspaceId': workspaceId,
        'title': title,
        'description': description + (source != null ? '\n\nSource message: $source' : ''),
        'priority': priority,
        if (assigneeId != null) 'assigneeId': assigneeId,
        if (affected != null) 'affected': affected,
      },
    );
    return (res as Map?)?.cast<String, dynamic>() ?? {};
  }

  /// Get profile info
  static Future<Map<String, dynamic>> getProfile() async {
    final res = await request(path: '/api/mobile/profile');
    return (res as Map?)?.cast<String, dynamic>() ?? {};
  }

  /// Update user profile
  static Future<Map<String, dynamic>> updateProfile({
    String? displayName,
    String? bio,
    String? avatarBase64,
  }) async {
    final res = await request(
      path: '/api/mobile/profile',
      method: 'POST',
      data: {
        if (displayName != null) 'displayName': displayName,
        if (bio != null) 'bio': bio,
        if (avatarBase64 != null) 'avatarBase64': avatarBase64,
      },
    );
    return (res as Map?)?.cast<String, dynamic>() ?? {};
  }

  /// List user's workspaces and communities
  static Future<Map<String, dynamic>> getWorkspaces() async {
    final res = await request(path: '/api/mobile/workspaces');
    return (res as Map?)?.cast<String, dynamic>() ?? {};
  }

  /// Get details of a single workspace
  static Future<Map<String, dynamic>> getWorkspaceDetails(String workspaceId) async {
    final res = await request(path: '/api/mobile/workspaces?id=$workspaceId');
    return (res as Map?)?.cast<String, dynamic>() ?? {};
  }

  /// Update workspace name or description
  static Future<Map<String, dynamic>> updateWorkspace({
    required String workspaceId,
    required String name,
    required String description,
  }) async {
    final res = await request(
      path: '/api/mobile/workspaces',
      method: 'POST',
      data: {
        'op': 'update',
        'workspaceId': workspaceId,
        'name': name,
        'description': description,
      },
    );
    return (res as Map?)?.cast<String, dynamic>() ?? {};
  }

  /// Create a new community or workspace
  static Future<Map<String, dynamic>> createWorkspace({
    required String name,
    required String description,
    bool isCommunity = false,
  }) async {
    final res = await request(
      path: '/api/mobile/workspaces',
      method: 'POST',
      data: {
        'op': isCommunity ? 'community' : 'create',
        'name': name,
        'description': description,
      },
    );
    return (res as Map?)?.cast<String, dynamic>() ?? {};
  }

  /// Upload a media file or document attachment
  static Future<Map<String, dynamic>> uploadAttachment({
    required String fileName,
    required String fileType,
    required String fileBase64,
  }) async {
    final res = await request(
      path: '/api/mobile/attachments',
      method: 'POST',
      data: {
        'fileName': fileName,
        'fileType': fileType,
        'fileBase64': fileBase64,
      },
    );
    return (res as Map?)?.cast<String, dynamic>() ?? {};
  }
}
