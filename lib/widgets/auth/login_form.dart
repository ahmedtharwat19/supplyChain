// باقي importاتك كما هي
import 'package:flutter/foundation.dart'
    show kIsWeb, defaultTargetPlatform, TargetPlatform;
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';
import 'package:easy_localization/easy_localization.dart';
import '../../utils/user_local_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:io';

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
  bool _obscurePassword = true;

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
        if (!user.emailVerified) {
          await user.sendEmailVerification();
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('please_verify_email'.tr())),
            );
          }
          return;
        }

        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();
        final userData = userDoc.data();
        if (userData != null) {
          await UserLocalStorage.setUser(userData);
        }

        if (mounted) context.go('/dashboard');
      }
    } catch (e) {
      if (e is FirebaseAuthException && e.code == 'popup-closed-by-user') return;

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('google_signin_failed'.tr())),
        );
      }
    }
  }

  Future<void> _loginWithEmailPassword() async {
    if (_formKey.currentState?.validate() ?? false) {
      setState(() => _isLoading = true);
      try {
        final credential =
            await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
        );

        final user = credential.user;
        if (user != null) {
          // جلب بيانات المستخدم من Firestore
          final userDoc = await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .get();
          final userData = userDoc.data();

          if (userData != null) {
            await UserLocalStorage.setUser(userData);
          }

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

  Future<bool> onPopInvokedWithResult(bool didPop, dynamic result) async {
    if (!didPop && !kIsWeb) {
      final shouldExit = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('exit_app_title'.tr()),
          content: Text('exit_app_message'.tr()),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text('cancel'.tr()),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text('exit'.tr()),
            ),
          ],
        ),
      );
      if (shouldExit ?? false) exit(0);
      return false;
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      onPopInvokedWithResult: onPopInvokedWithResult,
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
                      value != null && value.contains('@') ? null : 'invalid_email'.tr(),
                  onFieldSubmitted: (_) =>
                      FocusScope.of(context).requestFocus(_passwordFocusNode),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _passwordController,
                  focusNode: _passwordFocusNode,
                  obscureText: _obscurePassword,
                  textInputAction: TextInputAction.done,
                  decoration: InputDecoration(
                    labelText: 'password'.tr(),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword ? Icons.visibility : Icons.visibility_off,
                      ),
                      onPressed: () {
                        setState(() => _obscurePassword = !_obscurePassword);
                      },
                    ),
                  ),
                  validator: (value) =>
                      value != null && value.length >= 6 ? null : 'short_password'.tr(),
                  onFieldSubmitted: (_) => _loginWithEmailPassword(),
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: _isLoading ? null : _loginWithEmailPassword,
                  child: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
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
                    Flexible(child: Text('no_account'.tr())),
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



/* import 'dart:io';
import 'package:flutter/foundation.dart'
    show kIsWeb, defaultTargetPlatform, TargetPlatform;
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';
import 'package:easy_localization/easy_localization.dart';
import '../../utils/user_local_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

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
  bool _obscurePassword = true;

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
        // تحقق من تأكيد البريد الإلكتروني (إن وجد)
        if (!user.emailVerified) {
          await user.sendEmailVerification();
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('please_verify_email'.tr())),
            );
          }
          return;
        }

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

        // إنشاء أو تحديث وثيقة المستخدم في Firestore
        final userDoc =
            FirebaseFirestore.instance.collection('users').doc(user.uid);
        await userDoc.set({
          'userId': user.uid,
          'companyIds': [],
          'supplierIds': [],
          'email': email,
          'createdAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }

      if (mounted) context.go('/dashboard');
    } catch (e) {
      if (e is FirebaseAuthException && e.code == 'popup-closed-by-user') {
        // تجاهل إلغاء المستخدم تسجيل الدخول عبر جوجل
        return;
      }
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
        final credential =
            await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
        );

        final user = credential.user;
        if (user != null) {
     //     bool skipEmailVerification = true; // غيّرها لاحقًا حسب الحاجة
          // تحقق من تأكيد البريد الإلكتروني
/*           if (!user.emailVerified) {
            await user.sendEmailVerification(
              ActionCodeSettings(
                url: 'https://your-app.com/verify', // ← عدلها حسب نطاقك
                handleCodeInApp: true,
                androidPackageName: 'com.example.yourapp',
                androidInstallApp: true,
                androidMinimumVersion: '21',
                iOSBundleId: 'com.example.yourapp',
              ),
            );

            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('please_verify_email'.tr())),
              );
            }
            setState(() => _isLoading = false);
            return;
          } */

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

          final userDoc =
              FirebaseFirestore.instance.collection('users').doc(user.uid);
          await userDoc.set({
            'userId': user.uid,
            'companyIds': [],
            'supplierIds': [],
            'email': email,
            'createdAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));

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

  Future<bool> onPopInvokedWithResult(bool didPop, dynamic result) async {
    // your logic here, for example:
    if (!didPop && !kIsWeb) {
      final shouldExit = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('exit_app_title'.tr()),
          content: Text('exit_app_message'.tr()),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text('cancel'.tr()),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text('exit'.tr()),
            ),
          ],
        ),
      );
      if (shouldExit ?? false) {
        exit(0); // or SystemNavigator.pop();
      }
      return false;
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      onPopInvokedWithResult: onPopInvokedWithResult,
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
                  validator: (value) => value != null && value.contains('@')
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
                  obscureText: _obscurePassword,
                  textInputAction: TextInputAction.done,
                  decoration: InputDecoration(
                    labelText: 'password'.tr(),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword
                            ? Icons.visibility
                            : Icons.visibility_off,
                      ),
                      onPressed: () {
                        setState(() {
                          _obscurePassword = !_obscurePassword;
                        });
                      },
                    ),
                  ),
                  validator: (value) => value != null && value.length >= 6
                      ? null
                      : 'short_password'.tr(),
                  onFieldSubmitted: (_) => _loginWithEmailPassword(),
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: _isLoading ? null : _loginWithEmailPassword,
                  child: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
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
                    Flexible(child: Text('no_account'.tr())),
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
 */

/* import 'dart:io';
import 'package:flutter/foundation.dart'
    show kIsWeb, defaultTargetPlatform, TargetPlatform;
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';
import 'package:easy_localization/easy_localization.dart';
import '../../utils/user_local_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

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
        // إنشاء وثيقة المستخدم إذا لم تكن موجودة
        final userDoc =
            FirebaseFirestore.instance.collection('users').doc(user.uid);
        if (!(await userDoc.get()).exists) {
          await userDoc.set({
            'userId': user.uid,
            'companyIds': [],
            'supplierIds': [], // ✅ أضف هذا السطر
            'email': email,
            'createdAt': FieldValue.serverTimestamp(),
          });
        }
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
        final credential =
            await FirebaseAuth.instance.signInWithEmailAndPassword(
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
// إنشاء وثيقة المستخدم إذا لم تكن موجودة
          final userDoc =
              FirebaseFirestore.instance.collection('users').doc(user.uid);
          if (!(await userDoc.get()).exists) {
            await userDoc.set({
              'userId': user.uid,
              'companyIds': [],
              'supplierIds': [], // ✅ أضف هذا السطر
              'email': email,
              'createdAt': FieldValue.serverTimestamp(),
            });
          }

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
                  validator: (value) => value != null && value.contains('@')
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
                  validator: (value) => value != null && value.length >= 6
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
 */