import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:puresip_purchasing/services/license_service.dart';

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
  final _displayNameController = TextEditingController();
  final _phoneController = TextEditingController();

  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirm = true;

  void _signup() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _isLoading = true);

    try {
      final credential =
          await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      final user = credential.user;
      if (user != null) {
        await user.sendEmailVerification();

        final displayName = _displayNameController.text.trim().isEmpty
            ? _emailController.text.trim().split('@')[0]
            : _displayNameController.text.trim();

        final phone = _phoneController.text.trim();

        await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
          'userId': user.uid,
          'email': user.email,
          'displayName': displayName,
          'phoneNumber': phone,
          'companyIds': [],
          'supplierIds': [],
          'factoriesIds': [],
          'isActive': true,
          'subscriptionDurationInDays': 30,
          'createdAt': FieldValue.serverTimestamp(),
        });

        final licenseService = LicenseService();
        await licenseService.initialize();

        final licenseKey = await licenseService.createLicense(
          userId: user.uid,
          durationMonths: 1,
          maxDevices: 1,
          requestId: 'demo_${DateTime.now().millisecondsSinceEpoch}',
        );

// تسجيل الجهاز الحالي تلقائيًا
        await licenseService.registerCurrentDevice(licenseKey);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('account_created_successfully'.tr())),
          );
          context.go('/login');
        }
      }
    } on FirebaseAuthException catch (e) {
      String message = 'signup_error'.tr();
      if (e.code == 'email-already-in-use') {
        message = 'email_already_in_use'.tr();
      } else if (e.code == 'weak-password') {
        message = 'weak_password'.tr();
      } else if (e.code == 'invalid-email') {
        message = 'invalid_email'.tr();
      }

      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(message)));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    _displayNameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: _emailController,
                decoration: InputDecoration(labelText: 'email'.tr()),
                keyboardType: TextInputType.emailAddress,
                autofillHints: const [AutofillHints.email],
                textInputAction: TextInputAction.next,
                validator: (value) => value != null && value.contains('@')
                    ? null
                    : 'invalid_email'.tr(),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _displayNameController,
                decoration: InputDecoration(labelText: 'display_name'.tr()),
                textInputAction: TextInputAction.next,
                validator: (value) =>
                    value == null || value.trim().isEmpty ? null : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _phoneController,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                ],
                decoration: InputDecoration(labelText: 'phone_number'.tr()),
                keyboardType: TextInputType.phone,
                autofillHints: const [AutofillHints.telephoneNumber],
                textInputAction: TextInputAction.next,
                validator: (value) => value != null && value.trim().length >= 6
                    ? null
                    : 'invalid_phone'.tr(),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _passwordController,
                decoration: InputDecoration(
                  labelText: 'password'.tr(),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePassword
                          ? Icons.visibility
                          : Icons.visibility_off,
                    ),
                    onPressed: () =>
                        setState(() => _obscurePassword = !_obscurePassword),
                  ),
                ),
                obscureText: _obscurePassword,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.newPassword],
                validator: (value) => value != null && value.length >= 6
                    ? null
                    : 'short_password'.tr(),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _confirmController,
                decoration: InputDecoration(
                  labelText: 'confirm_password'.tr(),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscureConfirm ? Icons.visibility : Icons.visibility_off,
                    ),
                    onPressed: () =>
                        setState(() => _obscureConfirm = !_obscureConfirm),
                  ),
                ),
                obscureText: _obscureConfirm,
                textInputAction: TextInputAction.done,
                validator: (value) => value == _passwordController.text
                    ? null
                    : 'passwords_do_not_match'.tr(),
                onFieldSubmitted: (_) => _signup(),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _signup,
                  child: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text('signup'.tr()),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}


/* import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';

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
  bool _obscurePassword = true;
  bool _obscureConfirm = true;

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
          await user.sendEmailVerification();
          String displayName = user.email!.split('@')[0];
          await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .set({
/*             'userId': user.uid,
            'companyIds': [],
            'supplierIds': [],
            'email': user.email,
            'createdAt': FieldValue.serverTimestamp(), */
            'userId': user.uid,
            'email': user.email,
            'displayName': displayName,
            'companyIds': [],
            'supplierIds': [],
            'factoriesIds': [],
            'isActive': true,
            'createdAt': FieldValue.serverTimestamp(),
          });

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('account_created_successfully'.tr())),
            );
            context.go('/login');
          }
        }
      } on FirebaseAuthException catch (e) {
        String message = 'signup_error'.tr();
        if (e.code == 'email-already-in-use') {
          message = 'email_already_in_use'.tr();
        } else if (e.code == 'weak-password') {
          message = 'weak_password'.tr();
        } else if (e.code == 'invalid-email') {
          message = 'invalid_email'.tr();
        }
        if (mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text(message)));
        }
      } finally {
        if (mounted) setState(() => _isLoading = false);
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
  return SafeArea(
    child: SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Form(
        key: _formKey,
        child: Column(
          children: [
            TextFormField(
              controller: _emailController,
              decoration: InputDecoration(labelText: 'email'.tr()),
              keyboardType: TextInputType.emailAddress,
              autofillHints: const [AutofillHints.email],
              textInputAction: TextInputAction.next,
              validator: (value) =>
                  value != null && value.contains('@') ? null : 'invalid_email'.tr(),
            ),
            const SizedBox(height: 16),
            TextFormField(
              decoration: InputDecoration(labelText: 'display_name'.tr()),
              textInputAction: TextInputAction.next,
              onChanged: (value) {
                // يمكن تخزينه في متغير داخلي أو إضافته كـ TextEditingController
              },
              validator: (value) =>
                  value != null && value.trim().isNotEmpty ? null : 'required'.tr(),
            ),
            const SizedBox(height: 16),
            TextFormField(
              decoration: InputDecoration(labelText: 'phone_number'.tr()),
              keyboardType: TextInputType.phone,
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.telephoneNumber],
              onChanged: (value) {
                // يمكن تخزينه في متغير داخلي أيضًا
              },
              validator: (value) =>
                  value != null && value.trim().length >= 6 ? null : 'invalid_phone'.tr(),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _passwordController,
              decoration: InputDecoration(
                labelText: 'password'.tr(),
                suffixIcon: IconButton(
                  icon: Icon(_obscurePassword ? Icons.visibility : Icons.visibility_off),
                  onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                ),
              ),
              obscureText: _obscurePassword,
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.newPassword],
              validator: (value) =>
                  value != null && value.length >= 6 ? null : 'short_password'.tr(),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _confirmController,
              decoration: InputDecoration(
                labelText: 'confirm_password'.tr(),
                suffixIcon: IconButton(
                  icon: Icon(_obscureConfirm ? Icons.visibility : Icons.visibility_off),
                  onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm),
                ),
              ),
              obscureText: _obscureConfirm,
              textInputAction: TextInputAction.done,
              validator: (value) =>
                  value == _passwordController.text ? null : 'passwords_do_not_match'.tr(),
              onFieldSubmitted: (_) => _signup(),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _signup,
                child: _isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text('signup'.tr()),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

}
 */

/* //import 'dart:io';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
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
  bool _obscurePassword = true;
  bool _obscureConfirm = true;

  void _signup() async {
    if (_formKey.currentState?.validate() ?? false) {
      setState(() => _isLoading = true);

      try {
        final credential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
        );
        final user = credential.user;
        if (user != null) {
          // إرسال بريد التحقق من الحساب
          await user.sendEmailVerification();

          // إعداد وثيقة المستخدم في Firestore
          await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
            'userId': user.uid,
            'companyIds': [],
            'supplierIds': [],
            'email': user.email,
            'createdAt': FieldValue.serverTimestamp(),
          });

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('account_created_successfully'.tr())),
            );
            context.go('/login');
          }
        }
      } on FirebaseAuthException catch (e) {
        String message = 'signup_error'.tr();
        if (e.code == 'email-already-in-use') {
          message = 'email_already_in_use'.tr();
        } else if (e.code == 'weak-password') {
          message = 'weak_password'.tr();
        } else if (e.code == 'invalid-email') {
          message = 'invalid_email'.tr();
        }
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
        }
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  Future<bool> onPopInvokedWithResult(bool didPop, dynamic result) async {
    if (!didPop && !kIsWeb) {
      // عند الضغط على زر الرجوع، نرجع إلى صفحة تسجيل الدخول
      context.go('/login');
      return false; // منع الإغلاق التلقائي للصفحة الحالية (بمعنى: نحن قمنا بالتنقل يدوياً)
    }
    return true;
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
    return PopScope(
      onPopInvokedWithResult: onPopInvokedWithResult,
      child: AppScaffold(
        title: 'signup'.tr(),
        body: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                TextFormField(
                  controller: _emailController,
                  decoration: InputDecoration(labelText: 'email'.tr()),
                  keyboardType: TextInputType.emailAddress,
                  validator: (value) =>
                      value != null && value.contains('@') ? null : 'invalid_email'.tr(),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _passwordController,
                  decoration: InputDecoration(
                    labelText: 'password'.tr(),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword ? Icons.visibility : Icons.visibility_off,
                      ),
                      onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                    ),
                  ),
                  obscureText: _obscurePassword,
                  validator: (value) => value != null && value.length >= 6
                      ? null
                      : 'short_password'.tr(),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _confirmController,
                  decoration: InputDecoration(
                    labelText: 'confirm_password'.tr(),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscureConfirm ? Icons.visibility : Icons.visibility_off,
                      ),
                      onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm),
                    ),
                  ),
                  obscureText: _obscureConfirm,
                  validator: (value) =>
                      value == _passwordController.text ? null : 'passwords_do_not_match'.tr(),
                ),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _signup,
                    child: _isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Text('signup'.tr()),
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
 */

/* import 'package:easy_localization/easy_localization.dart';
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
  bool _obscurePassword = true;
  bool _obscureConfirm = true;

  void _signup() async {
    if (_formKey.currentState?.validate() ?? false) {
      setState(() => _isLoading = true);

      try {
        final credential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
        );
        final user = credential.user;
        if (user != null) {
          // إرسال بريد التحقق من الحساب
          await user.sendEmailVerification();

          // إعداد وثيقة المستخدم في Firestore
          await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
            'userId': user.uid,
            'companyIds': [],
            'supplierIds': [],
            'email': user.email,
            'createdAt': FieldValue.serverTimestamp(),
          });

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('account_created_successfully'.tr())),
            );
            context.go('/login');
          }
        }
      } on FirebaseAuthException catch (e) {
        String message = 'signup_error'.tr();
        if (e.code == 'email-already-in-use') {
          message = 'email_already_in_use'.tr();
        } else if (e.code == 'weak-password') {
          message = 'weak_password'.tr();
        } else if (e.code == 'invalid-email') {
          message = 'invalid_email'.tr();
        }
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
        }
      } finally {
        if (mounted) setState(() => _isLoading = false);
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
                decoration: InputDecoration(labelText: 'email'.tr()),
                keyboardType: TextInputType.emailAddress,
                validator: (value) =>
                    value != null && value.contains('@') ? null : 'invalid_email'.tr(),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _passwordController,
                decoration: InputDecoration(
                  labelText: 'password'.tr(),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePassword ? Icons.visibility : Icons.visibility_off,
                    ),
                    onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                  ),
                ),
                obscureText: _obscurePassword,
                validator: (value) => value != null && value.length >= 6
                    ? null
                    : 'short_password'.tr(),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _confirmController,
                decoration: InputDecoration(
                  labelText: 'confirm_password'.tr(),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscureConfirm ? Icons.visibility : Icons.visibility_off,
                    ),
                    onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm),
                  ),
                ),
                obscureText: _obscureConfirm,
                validator: (value) =>
                    value == _passwordController.text ? null : 'passwords_do_not_match'.tr(),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _signup,
                  child: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text('signup'.tr()),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
} */




/* import 'package:easy_localization/easy_localization.dart';
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
 */