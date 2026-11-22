import 'package:app/main.dart';
import 'package:app/workspace_routes.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart';

void main() {
  testWidgets('home exposes conversations and resolution workflows', (
    tester,
  ) async {
    const channel = MethodChannel('apex/session');
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(channel, (_) async => '{"items":[]}');
    addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
    await tester.pumpWidget(const ApexApp(firebase: true));
    await tester.pumpAndSettle();
    expect(find.text('Messages'), findsOneWidget);
    expect(find.text('Communities'), findsOneWidget);
    expect(find.text('Resolution'), findsOneWidget);
  });
  testWidgets(
    'signed out opens native sign-in and account creation is explicit',
    (tester) async {
      const channel = MethodChannel('apex/session');
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(
        channel,
        (_) async => throw PlatformException(code: 'SIGN_IN'),
      );
      addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
      await tester.pumpWidget(const ApexApp(firebase: true));
      await tester.pumpAndSettle();
      expect(find.text('Continue with Google'), findsOneWidget);
      expect(find.text('Messages'), findsNothing);
      await tester.tap(find.text('Create an account'));
      await tester.pumpAndSettle();
      expect(find.text('Create your account'), findsOneWidget);
    },
  );
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
