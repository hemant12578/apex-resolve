import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';

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

  final email = TextEditingController(), password = TextEditingController();
  bool busy = false, hidePassword = true;
  late bool signup = widget.createAccount;
  String feedback = '';
  @override
  void dispose() {
    email.dispose();
    password.dispose();
    super.dispose();
  }

  Future<void> submit({bool reset = false, bool google = false}) async {
    if (busy) return;
    if (!google &&
        (email.text.trim().isEmpty || (!reset && password.text.isEmpty))) {
      setState(
        () =>
            feedback =
                reset
                    ? 'Enter your email address.'
                    : 'Enter your email address and password.',
      );
      return;
    }
    setState(() {
      busy = true;
      feedback = '';
    });
    try {
      final auth = FirebaseAuth.instance;
      if (reset) {
        await auth.sendPasswordResetEmail(email: email.text.trim());
        if (mounted) {
          setState(
            () => feedback = 'Check your inbox for the password reset link.',
          );
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
        await user.sendEmailVerification();
        await auth.signOut();
        if (mounted) {
          setState(() {
            signup = false;
            feedback = 'Verify your email, then sign in.';
          });
        }
        return;
      }
      try {
        final token = await user.getIdToken(true);
        final body = await const MethodChannel(
          'apex/session',
        ).invokeMethod<String>('login', {'idToken': token});
        final result = jsonDecode(body!) as Map;
        if (mounted) {
          final path = result['firstLogin'] == true ? '/welcome' : '/dashboard';
          if (widget.onSuccess != null) {
            widget.onSuccess!(path);
          } else {
            Navigator.pop(context, path);
          }
        }
      } finally {
        await auth.signOut();
      }
    } on GoogleSignInException catch (e) {
      if (mounted && e.code != GoogleSignInExceptionCode.canceled) {
        setState(
          () => feedback = 'Google sign-in failed. Try again or use email.',
        );
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        setState(
          () =>
              feedback = switch (e.code) {
                'invalid-credential' || 'user-not-found' || 'wrong-password' =>
                  google
                      ? 'Google could not verify this account. Please choose your account again.'
                      : 'Check your email and password. New here? Choose Create an account below.',
                'invalid-email' => 'Enter a valid email address.',
                'email-already-in-use' =>
                  'This email already has an account. Choose Sign in.',
                _ => e.message ?? 'Sign-in failed. Please try again.',
              },
        );
      }
    } catch (_) {
      if (mounted) {
        setState(
          () =>
              feedback =
                  'Unable to finish sign-in. Check your connection and try again.',
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final duration =
        MediaQuery.disableAnimationsOf(context)
            ? Duration.zero
            : const Duration(milliseconds: 300);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
              children: [
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: 1),
                  duration: duration,
                  builder:
                      (_, v, child) => Opacity(
                        opacity: v,
                        child: Transform.translate(
                          offset: Offset(0, 12 * (1 - v)),
                          child: child,
                        ),
                      ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: colors.primaryContainer,
                        child: Icon(
                          Icons.forum_rounded,
                          color: colors.onPrimaryContainer,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'Apex Resolve',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 30),
                AnimatedSwitcher(
                  duration: duration,
                  child: Align(
                    key: ValueKey(signup),
                    alignment: Alignment.centerLeft,
                    child: Text(
                      signup ? 'Create your account' : 'Welcome back',
                      style: Theme.of(context).textTheme.headlineLarge
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                const SizedBox(height: 22),
                FilledButton.icon(
                  onPressed: busy ? null : () => submit(google: true),
                  icon: const Icon(Icons.account_circle_outlined),
                  label: const Text('Continue with Google'),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Row(
                    children: [
                      Expanded(child: Divider()),
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 12),
                        child: Text('or use email'),
                      ),
                      Expanded(child: Divider()),
                    ],
                  ),
                ),
                AutofillGroup(
                  child: Column(
                    children: [
                      TextField(
                        controller: email,
                        keyboardType: TextInputType.emailAddress,
                        autofillHints: const [AutofillHints.email],
                        textInputAction: TextInputAction.next,
                        decoration: const InputDecoration(
                          labelText: 'Email address',
                          prefixIcon: Icon(Icons.alternate_email),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: password,
                        obscureText: hidePassword,
                        autofillHints: [
                          signup
                              ? AutofillHints.newPassword
                              : AutofillHints.password,
                        ],
                        onSubmitted: (_) => submit(),
                        decoration: InputDecoration(
                          labelText: 'Password',
                          prefixIcon: const Icon(Icons.lock_outline),
                          suffixIcon: IconButton(
                            tooltip:
                                hidePassword
                                    ? 'Show password'
                                    : 'Hide password',
                            icon: Icon(
                              hidePassword
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined,
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
                if (!signup)
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: busy ? null : () => submit(reset: true),
                      child: const Text('Reset password'),
                    ),
                  ),
                if (signup) const SizedBox(height: 16),
                if (feedback.isNotEmpty)
                  Semantics(
                    liveRegion: true,
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text(feedback),
                    ),
                  ),
                OutlinedButton(
                  onPressed: busy ? null : () => submit(),
                  child: Text(
                    busy
                        ? 'Working…'
                        : signup
                        ? 'Create account'
                        : 'Sign in',
                  ),
                ),
                TextButton(
                  onPressed:
                      busy
                          ? null
                          : () => setState(() {
                            signup = !signup;
                            feedback = '';
                          }),
                  child: Text(
                    signup
                        ? 'Already registered? Sign in'
                        : 'Create an account',
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
