import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';

class SignIn extends StatefulWidget {
  const SignIn({super.key});
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
  bool busy = false, signup = false;
  String feedback = '';
  @override
  void dispose() {
    email.dispose();
    password.dispose();
    super.dispose();
  }

  Future<void> submit({bool reset = false, bool google = false}) async {
    if (busy) return;
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
          Navigator.pop(
            context,
            result['firstLogin'] == true ? '/welcome' : '/dashboard',
          );
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
      if (mounted) setState(() => feedback = e.message ?? 'Sign-in failed.');
    } catch (_) {
      if (mounted) {
        setState(
          () =>
              feedback =
                  'Unable to finish sign-in. Retry or open workspace sign-in.',
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(signup ? 'Create account' : 'Sign in')),
    body: SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          AutofillGroup(
            child: Column(
              children: [
                TextField(
                  controller: email,
                  keyboardType: TextInputType.emailAddress,
                  autofillHints: const [AutofillHints.email],
                  decoration: const InputDecoration(labelText: 'Email address'),
                ),
                TextField(
                  controller: password,
                  obscureText: true,
                  autofillHints: [
                    signup ? AutofillHints.newPassword : AutofillHints.password,
                  ],
                  decoration: const InputDecoration(labelText: 'Password'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
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
          OutlinedButton(
            onPressed: busy ? null : () => submit(google: true),
            child: const Text('Continue with Google'),
          ),
          TextButton(
            onPressed: busy ? null : () => submit(reset: true),
            child: const Text('Reset password'),
          ),
          TextButton(
            onPressed: busy ? null : () => setState(() => signup = !signup),
            child: Text(
              signup ? 'Already registered? Sign in' : 'Create an account',
            ),
          ),
          if (feedback.isNotEmpty) Text(feedback),
          TextButton(
            onPressed: busy ? null : () => Navigator.pop(context, '/login'),
            child: const Text('Open workspace sign-in'),
          ),
        ],
      ),
    ),
  );
}
