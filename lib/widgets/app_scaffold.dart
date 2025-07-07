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
        title: Builder(
          builder: (context) => Text(title ?? tr('dashboard_title')),
        ),
        actions: [
          Builder(
            builder: (context) => PopupMenuButton<Locale>(
              icon: const Icon(Icons.language, color: Colors.white),
              tooltip: tr('change_language'),
              onSelected: (locale) async {
                await context.setLocale(locale);
                // إعادة بناء الواجهة
                (context as Element).markNeedsBuild();
              },
              itemBuilder: (context) => const [
                PopupMenuItem(
                  value: Locale('en'),
                  child: Text('English'),
                ),
                PopupMenuItem(
                  value: Locale('ar'),
                  child: Text('العربية'),
                ),
              ],
            ),
          ),
          if (kIsWeb && userName != null)
            Builder(
              builder: (context) => Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Center(
                  child: Text(
                    '${tr('hello')}, $userName',
                    style: const TextStyle(fontSize: 16, color: Colors.white),
                  ),
                ),
              ),
            ),
          Builder(
            builder: (context) => IconButton(
              icon: const Icon(Icons.logout),
              tooltip: tr('logout'),
              onPressed: () => logout(context),
            ),
          ),
        ],
      ),
      body: body,
    );
  }
}
