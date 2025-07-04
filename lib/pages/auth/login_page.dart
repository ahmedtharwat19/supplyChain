import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';
//import 'package:shared_preferences/shared_preferences.dart';
import '../../../utils/user_local_storage.dart'; // تأكد من المسار الصحيح للملف
 // تأكد من المسار الصحيح للملف

import 'signup_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final emailFocus = FocusNode();
  final passwordFocus = FocusNode();

  String error = '';
  bool isLoading = false;

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    emailFocus.dispose();
    passwordFocus.dispose();
    super.dispose();
  }

  Future<void> login() async {
    setState(() {
      isLoading = true;
      error = '';
    });

    try {
      final credential = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: emailController.text.trim(),
        password: passwordController.text,
      );

      final user = credential.user;

      // حفظ بيانات المستخدم محليًا
      if (user != null) {
        final email = user.email ?? '';
        final userName = email.split('@').first;

        await UserLocalStorage.saveUser(
          userId: user.uid,
          email: email,
          displayName: userName,
        );
      }

      if (!mounted) return;

      // الانتقال إلى صفحة Dashboard عبر GoRouter
      context.go('/');
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      setState(() {
        error = e.message ?? 'فشل تسجيل الدخول.';
      });
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('تسجيل الدخول')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: emailController,
              focusNode: emailFocus,
              autofocus: true,
              decoration: const InputDecoration(labelText: 'البريد الإلكتروني'),
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              onSubmitted: (_) =>
                  FocusScope.of(context).requestFocus(passwordFocus),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: passwordController,
              focusNode: passwordFocus,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'كلمة المرور'),
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => login(),
            ),
            const SizedBox(height: 20),
            if (error.isNotEmpty)
              Text(error, style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 10),
            isLoading
                ? const Center(child: CircularProgressIndicator())
                : ElevatedButton(
                    onPressed: login,
                    child: const Text('تسجيل الدخول'),
                  ),
            const SizedBox(height: 10),
            TextButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const SignupPage()),
                );
              },
              child: const Text("ليس لديك حساب؟ سجل الآن"),
            ),
          ],
        ),
      ),
    );
  }
}
