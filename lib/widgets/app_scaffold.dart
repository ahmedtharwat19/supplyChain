import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:easy_localization/easy_localization.dart';

class AppScaffold extends StatelessWidget {
  final Widget body;
  final String? userName;
  final String? title;

  const AppScaffold({
    super.key,
    required this.body,
    this.userName,
    this.title,
  });

  Future<void> logout(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    await FirebaseAuth.instance.signOut();

    if (!context.mounted) return;
    context.go('/login');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF45E94D),
        title: Text(title ?? 'PureSip Dashboard'),
        actions: [
          // اللغة
          PopupMenuButton<Locale>(
            icon: const Icon(Icons.language, color: Colors.white),
            tooltip: 'change_language'.tr(),
            onSelected: (locale) => context.setLocale(locale),
            itemBuilder: (context) => [
              PopupMenuItem(
                value: const Locale('en'),
                child: const Text('English'),
              ),
              PopupMenuItem(
                value: const Locale('ar'),
                child: const Text('العربية'),
              ),
            ],
          ),
          // اسم المستخدم
          if (kIsWeb && userName != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Center(
                child: Text(
                  '${'hello'.tr()}, $userName',
                  style: const TextStyle(fontSize: 16, color: Colors.white),
                ),
              ),
            ),
          // زر تسجيل الخروج
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'logout'.tr(),
            onPressed: () => logout(context),
          ),
        ],
      ),
      body: body,
    );
  }
}
