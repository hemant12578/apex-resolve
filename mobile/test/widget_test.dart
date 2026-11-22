import 'package:app/apex_ai_screen.dart';
import 'package:app/home.dart';
import 'package:app/main.dart';
import 'package:app/native_chat.dart';
import 'package:app/profile_screen.dart';
import 'package:app/resolution_screens.dart';
import 'package:app/theme.dart';
import 'package:app/user_discovery.dart';
import 'package:app/workspace_management.dart';
import 'package:app/workspace_routes.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

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

  testWidgets('Apex AI screen renders native interface and sends message', (tester) async {
    const channel = MethodChannel('apex/session');
    final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'api') {
        return '{"answer":"This is a real test response from Apex AI."}';
      }
      return '{}';
    });
    addTearDown(() => messenger.setMockMethodCallHandler(channel, null));

    await tester.pumpWidget(const MaterialApp(home: ApexAiScreen()));
    await tester.pumpAndSettle();

    expect(find.text('Apex AI'), findsWidgets);
    expect(find.text('Intelligent Workspace Copilot'), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'How does verification work?');
    await tester.tap(find.byIcon(Icons.arrow_upward_rounded));
    await tester.pumpAndSettle();

    expect(find.text('How does verification work?'), findsOneWidget);
    expect(find.textContaining('This is a real test response from Apex AI'), findsOneWidget);
  });

  testWidgets('User discovery screen displays member search and actions', (tester) async {
    const channel = MethodChannel('apex/session');
    final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'api') {
        return '{"items":[{"id":"11111111-1111-1111-1111-111111111111","displayName":"Alice Smith","handle":"@alice.11111111","contactStatus":"none","incoming":false}],"hasMore":false}';
      }
      return '{}';
    });
    addTearDown(() => messenger.setMockMethodCallHandler(channel, null));

    await tester.pumpWidget(const MaterialApp(home: UserDiscoveryScreen()));
    await tester.pumpAndSettle();

    expect(find.text('Find People'), findsOneWidget);
    expect(find.text('Alice Smith'), findsOneWidget);
    expect(find.text('@alice.11111111'), findsOneWidget);
    expect(find.text('Connect'), findsOneWidget);
  });

  testWidgets('Profile screen displays editable profile attributes', (tester) async {
    const channel = MethodChannel('apex/session');
    final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'api') {
        return '{"user":{"id":"test-user-id","displayName":"Hemant Dev","email":"test@example.com","handle":"@hemant.test","bio":"Mobile Lead","memberships":[]}}';
      }
      return '{}';
    });
    addTearDown(() => messenger.setMockMethodCallHandler(channel, null));

    await tester.pumpWidget(const MaterialApp(home: ProfileScreen()));
    await tester.pumpAndSettle();

    expect(find.text('Edit Profile'), findsOneWidget);
    expect(find.text('Change Profile Photo'), findsOneWidget);
    expect(find.text('Profile Details'), findsOneWidget);
    expect(find.text('Hemant Dev'), findsOneWidget);
  });

  testWidgets('Resolution detail screen renders progress stepper, tasks and evidence', (tester) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    const channel = MethodChannel('apex/session');
    final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'api') {
        return '''
        {
          "issue": {
            "id": "22222222-2222-2222-2222-222222222222",
            "title": "Auth token refresh failing",
            "description": "Observed 401 on token rotation.",
            "status": "IN_PROGRESS",
            "priority": "HIGH",
            "workspace_id": "33333333-3333-3333-3333-333333333333",
            "reporter_id": "user-1",
            "assignee_id": "user-2"
          },
          "tasks": [
            {"id": "t1", "title": "Check cookie parser", "status": "DONE"}
          ],
          "evidence": [
            {"id": "e1", "kind": "note", "description": "Fixed session expiry in token refresh."}
          ],
          "audit": [],
          "reviews": [],
          "people": [
            {"userId": "user-1", "name": "Reporter", "role": "member"},
            {"userId": "user-2", "name": "Resolver", "role": "admin"}
          ],
          "permissions": {
            "role": "admin",
            "team": true,
            "canVerify": true,
            "editable": true,
            "independent": false,
            "isRequestedByMe": false
          }
        }
        ''';
      }
      return '{}';
    });
    addTearDown(() => messenger.setMockMethodCallHandler(channel, null));

    await tester.pumpWidget(const MaterialApp(
      home: ResolutionDetailScreen(issueId: '22222222-2222-2222-2222-222222222222'),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Auth token refresh failing'), findsWidgets);
    expect(find.text('Independent Verification'), findsOneWidget);
    expect(find.text('Tasks (1)'), findsOneWidget);
    expect(find.text('Evidence Vault (1)'), findsOneWidget);
    expect(find.text('Check cookie parser'), findsOneWidget);
    expect(find.text('Request Verification'), findsOneWidget);
  });

  testWidgets('Workspace management screen displays environments and create action', (tester) async {
    const channel = MethodChannel('apex/session');
    final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'api') {
        return '{"items":[{"id":"w1","name":"Core Engineering","description":"Main workspace","role":"admin","isCommunity":false,"isOwner":true}]}';
      }
      return '{}';
    });
    addTearDown(() => messenger.setMockMethodCallHandler(channel, null));

    await tester.pumpWidget(const MaterialApp(home: WorkspaceManagementScreen()));
    await tester.pumpAndSettle();

    expect(find.text('Workspaces & Communities'), findsOneWidget);
    expect(find.text('Core Engineering'), findsOneWidget);
    expect(find.text('Main Workspace'), findsOneWidget);
    expect(find.text('ADMIN'), findsOneWidget);
  });

  testWidgets('Responsive small width (360dp) renders Home without overflow', (tester) async {
    tester.view.physicalSize = const Size(360, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    const channel = MethodChannel('apex/session');
    final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(channel, (call) async => '{"items":[]}');
    addTearDown(() => messenger.setMockMethodCallHandler(channel, null));

    await tester.pumpWidget(MaterialApp(
      theme: ApexTheme.dark,
      home: Home(
        firebase: false,
        theme: ThemeController.global,
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Messages'), findsOneWidget);
    expect(find.text('Communities'), findsOneWidget);
    expect(find.text('Resolution'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Responsive standard width (390dp) renders ResolutionDetailScreen without overflow', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    const channel = MethodChannel('apex/session');
    final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'api') {
        return '''
        {
          "issue": {
            "id": "res-390",
            "title": "Responsive Verification",
            "description": "Checking layout constraints.",
            "status": "IN_PROGRESS",
            "priority": "MEDIUM",
            "workspace_id": "ws-1"
          },
          "tasks": [],
          "evidence": [],
          "audit": [],
          "reviews": [],
          "people": [],
          "permissions": {"role": "member", "team": true, "canVerify": false, "editable": true}
        }
        ''';
      }
      return '{}';
    });
    addTearDown(() => messenger.setMockMethodCallHandler(channel, null));

    await tester.pumpWidget(const MaterialApp(
      home: ResolutionDetailScreen(issueId: 'res-390'),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Responsive Verification'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  test('Starter stickers list is populated and categorised', () {
    expect(starterStickers.length, greaterThanOrEqualTo(20));
    final engineering = starterStickers.where((s) => s.pack == 'Engineering').toList();
    final teamVibes = starterStickers.where((s) => s.pack == 'Team Vibes').toList();
    final status = starterStickers.where((s) => s.pack == 'Status').toList();

    expect(engineering, isNotEmpty);
    expect(teamVibes, isNotEmpty);
    expect(status, isNotEmpty);
    expect(starterStickers.any((s) => s.emoji == '🚀' && s.title == 'Ship It!'), isTrue);
    expect(starterStickers.any((s) => s.emoji == '🛡️' && s.title == 'Verified'), isTrue);
  });
}
