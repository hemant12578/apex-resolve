const workspaceOrigin = 'https://apex-resolve-one.vercel.app';
final _uuid = RegExp(
  r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
  caseSensitive: false,
);

bool isWorkspace(Uri uri) =>
    uri.origin == workspaceOrigin && uri.userInfo.isEmpty;

Map<String, String>? chatTarget(Uri uri) {
  if (uri.scheme != 'https' || !isWorkspace(uri)) return null;
  final parts = uri.pathSegments;
  if (parts.length == 2 && _uuid.hasMatch(parts[1])) {
    if (parts.first == 'communities') return {'communityId': parts[1]};
    if (parts.first == 'issues') return {'issueId': parts[1]};
  }
  if (uri.path == '/communication') {
    for (final (name, field) in [('peer', 'peerId'), ('room', 'issueId')]) {
      final id = uri.queryParameters[name];
      if (id != null && _uuid.hasMatch(id)) return {field: id};
    }
  }
  return null;
}
