import 'dart:io';
import 'package:flutter/foundation.dart'
    show kIsWeb, defaultTargetPlatform, TargetPlatform;
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';
import 'package:easy_localization/easy_localization.dart';
import '../../utils/user_local_storage.dart';

class LoginForm extends StatefulWidget {
  const LoginForm({super.key});

  @override
  State<LoginForm> createState() => _LoginFormState();
}

class _LoginFormState extends State<LoginForm> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  final _emailFocusNode = FocusNode();
  final _passwordFocusNode = FocusNode();

  bool _isLoading = false;

  Future<void> _signInWithGoogle() async {
    try {
      final auth = FirebaseAuth.instance;

      if (kIsWeb) {
        await auth.signInWithPopup(GoogleAuthProvider());
      } else {
        final googleProvider = GoogleAuthProvider()
          ..addScope('email')
          ..setCustomParameters({'login_hint': 'user@example.com'});

        await auth.signInWithProvider(googleProvider);
      }

      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        String name = user.displayName ?? '';
        final email = user.email ?? '';

        if (name.isEmpty && email.contains('@')) {
          name = email.split('@')[0];
        }

        await UserLocalStorage.saveUser(
          userId: user.uid,
          email: email,
          displayName: name,
        );

        debugPrint('✅ Google login: $name <$email>');
      }

      if (mounted) context.go('/dashboard');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('google_signin_failed'.tr())),
        );
        debugPrint('Google Sign-In Error: $e');
      }
    }
  }

  Future<void> _loginWithEmailPassword() async {
    if (_formKey.currentState?.validate() ?? false) {
      setState(() => _isLoading = true);
      try {
        final credential = await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
        );

        final user = credential.user;
        if (user != null) {
          String name = user.displayName ?? '';
          final email = user.email ?? '';

          if (name.isEmpty && email.contains('@')) {
            name = email.split('@')[0];
          }

          await UserLocalStorage.saveUser(
            userId: user.uid,
            email: email,
            displayName: name,
          );

          debugPrint('✅ Logged in user: $name <$email>');

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('login_success'.tr())),
            );
            context.go('/dashboard');
          }
        }
      } on FirebaseAuthException catch (e) {
        String message = 'login_error'.tr();
        if (e.code == 'user-not-found') {
          message = 'user_not_found'.tr();
        } else if (e.code == 'wrong-password') {
          message = 'wrong_password'.tr();
        }
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(message)),
          );
        }
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  bool get _shouldShowGoogleButton {
    return kIsWeb ||
        defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS;
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _emailFocusNode.dispose();
    _passwordFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && !kIsWeb) {
          exit(0);
        }
      },
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                TextFormField(
                  controller: _emailController,
                  focusNode: _emailFocusNode,
                  textInputAction: TextInputAction.next,
                  decoration: InputDecoration(labelText: 'email'.tr()),
                  validator: (value) =>
                      value != null && value.contains('@')
                          ? null
                          : 'invalid_email'.tr(),
                  onFieldSubmitted: (_) {
                    FocusScope.of(context).requestFocus(_passwordFocusNode);
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _passwordController,
                  focusNode: _passwordFocusNode,
                  obscureText: true,
                  textInputAction: TextInputAction.done,
                  decoration: InputDecoration(labelText: 'password'.tr()),
                  validator: (value) =>
                      value != null && value.length >= 6
                          ? null
                          : 'short_password'.tr(),
                  onFieldSubmitted: (_) => _loginWithEmailPassword(),
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: _isLoading ? null : _loginWithEmailPassword,
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : Text('login'.tr()),
                ),
                const SizedBox(height: 12),
                if (_shouldShowGoogleButton)
                  ElevatedButton.icon(
                    onPressed: _signInWithGoogle,
                    icon: const Icon(Icons.login),
                    label: Text('login_with_google'.tr()),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.redAccent,
                      foregroundColor: Colors.white,
                    ),
                  ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('no_account'.tr()),
                    TextButton(
                      onPressed: () => context.go('/signup'),
                      child: Text('signup'.tr()),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
