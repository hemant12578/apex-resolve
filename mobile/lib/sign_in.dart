import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:material_ui/material_ui.dart';

import 'session.dart';
import 'theme.dart';
import 'ui.dart';

class SignIn extends StatefulWidget {
  const SignIn({super.key, this.onSuccess, this.createAccount = false});
  final ValueChanged<String>? onSuccess;
  final bool createAccount;
  @override
  State<SignIn> createState() => _SignInState();
}

class _SignInState extends State<SignIn> {
  static final googleReady = GoogleSignIn.instance.initialize();

  Future<UserCredential> signInWithGoogle(FirebaseAuth auth) async {
    await googleReady;
    final account = await GoogleSignIn.instance.authenticate();
    final token = account.authentication.idToken;
    if (token == null) throw StateError('Google sign-in returned no ID token.');
    return auth.signInWithCredential(
      GoogleAuthProvider.credential(idToken: token),
    );
  }

  final email = TextEditingController();
  final password = TextEditingController();
  final username = TextEditingController();
  final formKey = GlobalKey<FormState>();
  bool busy = false, hidePassword = true, feedbackError = true;
  late bool signup = widget.createAccount;
  String feedback = '';

  @override
  void dispose() {
    email.dispose();
    password.dispose();
    username.dispose();
    super.dispose();
  }

  String? validateUsername(String? value) {
    if (!signup) return null;
    final clean = (value ?? '').trim();
    if (clean.length < 2) return 'Choose a username with at least 2 characters.';
    if (clean.length > 30) return 'Keep your username under 30 characters.';
    if (!RegExp(r'^[A-Za-z0-9][A-Za-z0-9 ._-]*$').hasMatch(clean)) {
      return 'Use letters, numbers, spaces, dots, dashes or underscores.';
    }
    return null;
  }

  Future<void> submit({bool reset = false, bool google = false}) async {
    if (busy) return;
    final chosen = username.text.trim();
    if (signup && !google && validateUsername(chosen) != null) {
      setState(() {
        feedbackError = true;
        feedback = validateUsername(chosen)!;
      });
      return;
    }
    if (!google &&
        (email.text.trim().isEmpty || (!reset && password.text.isEmpty))) {
      setState(() {
        feedbackError = true;
        feedback =
            reset
                ? 'Enter your email address.'
                : 'Enter your email address and password.';
      });
      return;
    }
    if (!reset && !google && signup && password.text.length < 6) {
      setState(() {
        feedbackError = true;
        feedback = 'Use a password with at least 6 characters.';
      });
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() {
      busy = true;
      feedback = '';
    });
    try {
      final auth = FirebaseAuth.instance;
      if (reset) {
        await auth.sendPasswordResetEmail(email: email.text.trim());
        if (mounted) {
          setState(() {
            feedbackError = false;
            feedback = 'Check your inbox for the password reset link.';
          });
        }
        return;
      }
      final credentials =
          google
              ? await signInWithGoogle(auth)
              : signup
              ? await auth.createUserWithEmailAndPassword(
                email: email.text.trim(),
                password: password.text,
              )
              : await auth.signInWithEmailAndPassword(
                email: email.text.trim(),
                password: password.text,
              );
      final user = credentials.user!;
      if (!user.emailVerified) {
        if (signup && chosen.isNotEmpty) {
          await user.updateDisplayName(chosen);
        }
        await user.sendEmailVerification();
        await auth.signOut();
        if (mounted) {
          setState(() {
            signup = false;
            feedbackError = false;
            feedback =
                'Account created. Verify ${user.email ?? 'your email'}, then sign in.';
          });
        }
        return;
      }
      final name =
          chosen.isNotEmpty
              ? chosen
              : (user.displayName ?? '').trim();
      if (name.isNotEmpty && name != user.displayName) {
        await user.updateDisplayName(name);
      }
      try {
        final token = await user.getIdToken(true);
        final body = await const MethodChannel('apex/session').invokeMethod<
          String
        >('login', {'idToken': token, 'displayName': name});
        final result = jsonDecode(body!) as Map;
        ApexSession.remember(displayName: name, address: user.email);
        if (!mounted) return;
        final path = result['firstLogin'] == true ? '/welcome' : '/dashboard';
        if (widget.onSuccess != null) {
          widget.onSuccess!(path);
        } else {
          Navigator.pop(context, path);
        }
      } finally {
        await auth.signOut();
      }
    } on GoogleSignInException catch (e) {
      if (mounted && e.code != GoogleSignInExceptionCode.canceled) {
        setState(() {
          feedbackError = true;
          feedback = 'Google sign-in failed. Try again or use email.';
        });
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        setState(() {
          feedbackError = true;
          feedback = switch (e.code) {
            'invalid-credential' ||
            'user-not-found' ||
            'wrong-password' =>
              google
                  ? 'Google could not verify this account. Choose your account again.'
                  : 'Check your email and password. New here? Create an account below.',
            'invalid-email' => 'Enter a valid email address.',
            'weak-password' => 'Use a stronger password (6+ characters).',
            'email-already-in-use' =>
              'This email already has an account. Choose Sign in.',
            'too-many-requests' =>
              'Too many attempts. Wait a moment and try again.',
            _ => e.message ?? 'Sign-in failed. Please try again.',
          };
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          feedbackError = true;
          feedback =
              'Unable to finish sign-in. Check your connection and try again.';
        });
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  void toggleMode() {
    setState(() {
      signup = !signup;
      feedback = '';
      feedbackError = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    final duration =
        MediaQuery.disableAnimationsOf(context)
            ? Duration.zero
            : const Duration(milliseconds: 260);
    return Scaffold(
      body: ApexBackground(
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(22, 20, 22, 30),
                children: [
                  TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: 1),
                    duration: duration,
                    curve: Curves.easeOut,
                    builder:
                        (_, v, child) => Opacity(
                          opacity: v,
                          child: Transform.translate(
                            offset: Offset(0, 14 * (1 - v)),
                            child: child,
                          ),
                        ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const ApexMark(size: 40),
                            const SizedBox(width: 11),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Apex Resolve',
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: -.4,
                                  ),
                                ),
                                Text(
                                  'Conversation → verified fix',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: muted,
                                    fontSize: 10.5,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 26),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 9,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: ApexColors.coral.withValues(alpha: .12),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: ApexColors.coral.withValues(alpha: .3),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.bolt_rounded,
                                size: 12,
                                color: ApexColors.coral,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                signup ? 'CREATE YOUR SPACE' : 'WELCOME BACK',
                                style: TextStyle(
                                  color: ApexColors.coral,
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: .9,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        AnimatedSwitcher(
                          duration: duration,
                          child: Text(
                            signup
                                ? 'Start resolving,\nnot just chatting.'
                                : 'Pick up where\nyou left off.',
                            key: ValueKey(signup),
                            style: theme.textTheme.headlineLarge?.copyWith(
                              fontSize: 34,
                              height: 1.06,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          signup
                              ? 'One account for conversations, evidence and independent review.'
                              : 'Your alerts, chats and resolution rooms are waiting.',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: muted,
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 22),
                  ApexCard(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        OutlinedButton.icon(
                          onPressed: busy ? null : () => submit(google: true),
                          icon: const Icon(Icons.g_mobiledata_rounded, size: 26),
                          label: Text(
                            signup ? 'Sign up with Google' : 'Continue with Google',
                          ),
                        ),
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 14),
                          child: Row(
                            children: [
                              Expanded(child: Divider()),
                              Padding(
                                padding: EdgeInsets.symmetric(horizontal: 10),
                                child: Text(
                                  'or use email',
                                  style: TextStyle(fontSize: 11),
                                ),
                              ),
                              Expanded(child: Divider()),
                            ],
                          ),
                        ),
                        Form(
                          key: formKey,
                          child: AutofillGroup(
                            child: Column(
                              children: [
                                if (signup) ...[
                                  TextFormField(
                                    controller: username,
                                    enabled: !busy,
                                    textInputAction: TextInputAction.next,
                                    maxLength: 30,
                                    autofillHints: const [
                                      AutofillHints.newUsername,
                                    ],
                                    validator: validateUsername,
                                    decoration: const InputDecoration(
                                      labelText: 'Username',
                                      hintText: 'How teammates see you',
                                      prefixIcon: Icon(
                                        Icons.alternate_email_rounded,
                                      ),
                                      counterText: '',
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                ],
                                TextField(
                                  controller: email,
                                  enabled: !busy,
                                  keyboardType: TextInputType.emailAddress,
                                  autofillHints: const [AutofillHints.email],
                                  textInputAction: TextInputAction.next,
                                  decoration: const InputDecoration(
                                    labelText: 'Email address',
                                    prefixIcon: Icon(Icons.mail_outline_rounded),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                TextField(
                                  controller: password,
                                  enabled: !busy,
                                  obscureText: hidePassword,
                                  autofillHints: [
                                    signup
                                        ? AutofillHints.newPassword
                                        : AutofillHints.password,
                                  ],
                                  onSubmitted: (_) => submit(),
                                  decoration: InputDecoration(
                                    labelText: 'Password',
                                    prefixIcon: const Icon(
                                      Icons.lock_outline_rounded,
                                    ),
                                    suffixIcon: IconButton(
                                      tooltip:
                                          hidePassword
                                              ? 'Show password'
                                              : 'Hide password',
                                      icon: Icon(
                                        hidePassword
                                            ? Icons.visibility_outlined
                                            : Icons.visibility_off_outlined,
                                        size: 20,
                                      ),
                                      onPressed:
                                          () => setState(
                                            () => hidePassword = !hidePassword,
                                          ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        if (!signup)
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton(
                              onPressed: busy ? null : () => submit(reset: true),
                              child: const Text(
                                'Reset password',
                                style: TextStyle(fontSize: 12),
                              ),
                            ),
                          ),
                        if (feedback.isNotEmpty)
                          Semantics(
                            liveRegion: true,
                            child: Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 9,
                              ),
                              decoration: BoxDecoration(
                                color: (feedbackError
                                        ? ApexColors.danger
                                        : ApexColors.green)
                                    .withValues(alpha: .1),
                                borderRadius: BorderRadius.circular(11),
                                border: Border.all(
                                  color: (feedbackError
                                          ? ApexColors.danger
                                          : ApexColors.green)
                                      .withValues(alpha: .35),
                                ),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Icon(
                                    feedbackError
                                        ? Icons.error_outline_rounded
                                        : Icons.check_circle_outline_rounded,
                                    size: 16,
                                    color:
                                        feedbackError
                                            ? ApexColors.danger
                                            : ApexColors.green,
                                  ),
                                  const SizedBox(width: 7),
                                  Expanded(
                                    child: Text(
                                      feedback,
                                      style: theme.textTheme.bodySmall?.copyWith(
                                        color:
                                            feedbackError
                                                ? ApexColors.danger
                                                : ApexColors.green,
                                        height: 1.4,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        FilledButton(
                          onPressed: busy ? null : () => submit(),
                          child: Text(
                            busy
                                ? 'Working…'
                                : signup
                                ? 'Create account'
                                : 'Sign in',
                          ),
                        ),
                        const SizedBox(height: 6),
                        TextButton(
                          onPressed: busy ? null : toggleMode,
                          child: Text(
                            signup
                                ? 'Already registered? Sign in'
                                : 'New to Apex? Create an account',
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.shield_outlined,
                        size: 13,
                        color: ApexColors.muted,
                      ),
                      const SizedBox(width: 5),
                      Flexible(
                        child: Text(
                          'Independent review · Evidence-first resolution',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: muted,
                            fontSize: 10,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
