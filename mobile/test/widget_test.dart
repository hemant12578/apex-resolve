import 'package:app/main.dart';
import 'package:app/workspace_routes.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('home exposes conversations and resolution workflows', (
    tester,
  ) async {
    await tester.pumpWidget(const ApexApp());
    expect(find.text('Messages'), findsOneWidget);
    expect(find.text('Communities'), findsOneWidget);
    expect(find.text('Resolution'), findsOneWidget);
  });
  test(
    'only official workspace conversation URLs can request a native session',
    () {
      const id = '12345678-1234-1234-1234-123456789abc';
      for (final entry
          in {
            '/communities/$id': 'communityId',
            '/issues/$id': 'issueId',
            '/communication?peer=$id': 'peerId',
            '/communication?room=$id': 'issueId',
          }.entries) {
        expect(chatTarget(Uri.parse(workspaceOrigin + entry.key)), {
          entry.value: id,
        });
      }
      for (final url in [
        'https://example.org/issues/$id',
        '$workspaceOrigin/communities/new',
        '$workspaceOrigin/communication?peer=bad',
        'http://apex-resolve-one.vercel.app/issues/$id',
      ]) {
        expect(chatTarget(Uri.parse(url)), isNull);
      }
    },
  );
}
