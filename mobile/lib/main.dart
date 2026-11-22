import 'dart:io' show Platform;

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import 'data.dart';
import 'home.dart';
import 'local_storage.dart';
import 'session.dart';
import 'sign_in.dart';
import 'theme.dart';
import 'ui.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  bool firebase = false;
  try {
    if (Platform.isIOS) {
      await Firebase.initializeApp(
        options: const FirebaseOptions(
          apiKey: 'AIzaSyDVsh_-eT7ipC9XQci4xkHeLKMMVE_IfMI',
          appId: '1:690636140447:ios:c99f4ef93d493ed02217aa',
          messagingSenderId: '690636140447',
          projectId: 'apex-resolve',
          storageBucket: 'apex-resolve.firebasestorage.app',
        ),
      );
    } else if (Platform.isAndroid) {
      await Firebase.initializeApp(
        options: const FirebaseOptions(
          apiKey: 'AIzaSyDVsh_-eT7ipC9XQci4xkHeLKMMVE_IfMI',
          appId: '1:690636140447:android:c99f4ef93d493ed02217aa',
          messagingSenderId: '690636140447',
          projectId: 'apex-resolve',
          storageBucket: 'apex-resolve.firebasestorage.app',
        ),
      );
    } else {
      await Firebase.initializeApp();
    }
    firebase = true;
  } catch (_) {
    try {
      await Firebase.initializeApp();
      firebase = true;
    } catch (_) {
      /* Workspace email sign-in remains available. */
    }
  }
  runApp(ApexApp(firebase: firebase));
}

class ApexApp extends StatefulWidget {
  const ApexApp({super.key, this.firebase = false});
  final bool firebase;
  @override
  State<ApexApp> createState() => _ApexAppState();
}

class _ApexAppState extends State<ApexApp> {
  final theme = ThemeController();

  @override
  void dispose() {
    theme.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: theme,
    builder:
        (_, _) => MaterialApp(
          title: 'Apex Resolve',
          debugShowCheckedModeBanner: false,
          theme: ApexTheme.light,
          darkTheme: ApexTheme.dark,
          themeMode: theme.mode,
          home: SessionGate(firebase: widget.firebase, theme: theme),
        ),
  );
}

/// Login-first entry point. Signed-out opens the native sign-in screen; an
/// existing workspace session opens the Explorer directly.
class SessionGate extends StatefulWidget {
  const SessionGate({super.key, required this.firebase, required this.theme});
  final bool firebase;
  final ThemeController theme;
  @override
  State<SessionGate> createState() => _SessionGateState();
}

class _SessionGateState extends State<SessionGate> {
  bool? signedIn;
  bool unavailable = false;

  @override
  void initState() {
    super.initState();
    ApexSession.expired.addListener(_expired);
    check();
  }

  @override
  void dispose() {
    ApexSession.expired.removeListener(_expired);
    super.dispose();
  }

  void _expired() {
    if (mounted) setState(() => signedIn = false);
  }

  Future<void> check() async {
    setState(() {
      unavailable = false;
      signedIn = null;
    });

    // 1. Restore local session from phone disk
    await ApexSession.loadFromDisk();
    final hasSession = ApexSession.name.isNotEmpty || ApexSession.email.isNotEmpty;
    final cachedChats = await LocalVault.read('directory_chats');
    if (hasSession || (cachedChats is List && cachedChats.isNotEmpty)) {
      if (mounted) setState(() => signedIn = true);
    }

    // 2. Try online sync in background
    try {
      await loadDirectory('chats');
      if (mounted) setState(() => signedIn = true);
    } on PlatformException catch (e) {
      if (mounted) {
        if (e.code == 'SIGN_IN') {
          ApexSession.clear();
          setState(() {
            signedIn = false;
            unavailable = false;
          });
        } else if (hasSession) {
          setState(() {
            signedIn = true;
            unavailable = false;
          });
        } else {
          setState(() {
            signedIn = false;
            unavailable = false;
          });
        }
      }
    } catch (_) {
      if (mounted) {
        if (hasSession || (cachedChats is List && cachedChats.isNotEmpty)) {
          setState(() {
            signedIn = true;
            unavailable = false;
          });
        } else {
          setState(() {
            signedIn = false;
            unavailable = false;
          });
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = signedIn;
    if (state == null) return const _Splash();
    if (unavailable) {
      return Scaffold(
        body: SafeArea(
          child: Center(
            child: ApexEmpty(
              icon: Icons.cloud_off_outlined,
              title: "Workspace unavailable",
              body: "Check your connection and try again.",
              action: "Retry",
              onAction: check,
            ),
          ),
        ),
      );
    }
    if (!state) {
      return SignIn(
        onSuccess: (_) {
          if (mounted) setState(() => signedIn = true);
        },
      );
    }
    return Home(firebase: widget.firebase, theme: widget.theme);
  }
}

class _Splash extends StatelessWidget {
  const _Splash();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: ApexBackground(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const ApexMark(size: 62),
              const SizedBox(height: 22),
              SizedBox(
                width: 132,
                child: LinearProgressIndicator(
                  borderRadius: BorderRadius.circular(8),
                  minHeight: 3,
                ),
              ),
              const SizedBox(height: 14),
              Text(
                'Opening Apex Resolve…',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
