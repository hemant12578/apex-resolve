import 'package:app/main.dart';
import 'package:app/workspace_routes.dart';
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('home exposes conversations and resolution workflows', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
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
    'signed out opens native sign-in and account creation asks for a username',
    (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
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
      expect(find.text('Username'), findsNothing);
      await tester.ensureVisible(find.text('New to Apex? Create an account'));
      await tester.tap(find.text('New to Apex? Create an account'));
      await tester.pumpAndSettle();
      expect(find.text('Sign up with Google'), findsOneWidget);
      expect(find.text('Username'), findsOneWidget);
      expect(find.text('Email address'), findsOneWidget);
    },
  );
  testWidgets('sign-up rejects a username with symbols', (tester) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
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
    await tester.tap(find.text('New to Apex? Create an account'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, r'bad$name!');
    await tester.enterText(find.byType(TextField).at(1), 'person@example.com');
    await tester.enterText(find.byType(TextField).at(2), 'secret123');
    await tester.ensureVisible(find.text('Create account'));
    await tester.tap(find.text('Create account'));
    await tester.pumpAndSettle();
    expect(
      find.text('Use letters, numbers, spaces, dots, dashes or underscores.'),
      findsOneWidget,
    );
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
