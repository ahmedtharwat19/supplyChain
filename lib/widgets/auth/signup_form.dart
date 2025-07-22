import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';
import 'package:puresip_purchasing/widgets/app_scaffold.dart';

class SignupForm extends StatefulWidget {
  const SignupForm({super.key});

  @override
  State<SignupForm> createState() => _SignupFormState();
}

class _SignupFormState extends State<SignupForm> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _isLoading = false;

//import 'package:firebase_auth/firebase_auth.dart';

  void _signup() async {
    if (_formKey.currentState?.validate() ?? false) {
      setState(() => _isLoading = true);

      try {
        final credential =
            await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
        );
        final user = credential.user;
        if (user != null) {
          await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .set({
            'userId': user.uid,
            'companyIds': [],
            'supplierIds': [], // ✅ أضف هذا السطر // تجهيز مبدئي للحقل
            'email': user.email,
            'createdAt': FieldValue.serverTimestamp(),
          });
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('account_created_successfully'.tr())),
          );
/*           Navigator.pushReplacementNamed(
              context, '/dashboard'); // or use context.go('/dashboard')
          Navigator.pushReplacementNamed(
              context, '/dashboard'); // or use context.go('/dashboard') */
          context.go('/login');
        }
      } on FirebaseAuthException catch (e) {
        String message = 'حدث خطأ أثناء إنشاء الحساب.';
        if (e.code == 'email-already-in-use') {
          message = 'البريد الإلكتروني مستخدم بالفعل.';
        } else if (e.code == 'weak-password') {
          message = 'كلمة المرور ضعيفة جداً.';
        } else if (e.code == 'invalid-email') {
          message = 'البريد الإلكتروني غير صالح.';
        }
        if (mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text(message)));
        }
      } finally {
        if (mounted) {
          setState(() => _isLoading = false);
        }
      }
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'signup'.tr(),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: _emailController,
                decoration: const InputDecoration(labelText: 'Email'),
                validator: (value) => value != null && value.contains('@')
                    ? null
                    : 'Enter a valid email',
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _passwordController,
                decoration: const InputDecoration(labelText: 'Password'),
                obscureText: true,
                validator: (value) => value != null && value.length >= 6
                    ? null
                    : 'Minimum 6 characters required',
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _confirmController,
                decoration:
                    const InputDecoration(labelText: 'Confirm Password'),
                obscureText: true,
                validator: (value) => value == _passwordController.text
                    ? null
                    : 'Passwords do not match',
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _signup,
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text('Signup'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
