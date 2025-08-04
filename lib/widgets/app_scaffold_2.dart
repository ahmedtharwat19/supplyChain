/* //import 'dart:io';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:easy_localization/easy_localization.dart';

class AppScaffold extends StatelessWidget {
  final Widget body;
  final String? userName;
  final String? title;
  final bool isDashboard;
  final FloatingActionButton? floatingActionButton;
  
  final dynamic actions;

  const AppScaffold(required String title, {
    super.key,
    required this.body,
    this.userName,
    this.title,
    this.isDashboard = false,
    this.floatingActionButton,
     this.actions,
    
  });

  // ignore: unused_element
  Future<bool> _confirmExit(BuildContext context) async {
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(tr('exit_confirm_title')),
            content: Text(tr('exit_confirm_message')),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: Text(tr('stay')),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: Text(tr('exit')),
              ),
            ],
          ),
        ) ??
        false;
  }

  Future<void> logout(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    await FirebaseAuth.instance.signOut();
    if (!context.mounted) return;
    context.go('/login');
  }

  @override
  Widget build(BuildContext context) {
    final router = GoRouter.of(context);
    //final currentPath = router.routeInformationProvider.value.uri.toString();
    final currentPath = GoRouter.of(context).routeInformationProvider.value.uri.toString();
    final canGoBack = currentPath != '/dashboard';

    final appBar = AppBar(
      backgroundColor: const Color.fromARGB(255, 69, 200, 218),
      title: Text(title ?? tr('dashboard_title')),
      leading: canGoBack
          ? IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () {
                if (Navigator.of(context).canPop()) {
                  Navigator.of(context).pop();
                } else if (router.canPop()) {
                  context.pop();
                } else {
                  context.go('/dashboard');
                }
              },
            )
          : null,
      actions: [
        if (userName != null)
/*           Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Center(
              child: Text(
                '${tr('hello')}, $userName',
                style: const TextStyle(fontSize: 16, color: Colors.white),
              ),
            ),
          ), */
        PopupMenuButton<Locale>(
          icon: const Icon(Icons.language, color: Colors.white),
          tooltip: tr('change_language'),
          onSelected: (locale) async {
            //if (!mounted) return;
            await context.setLocale(locale);
            (context as Element).markNeedsBuild();
          },
          itemBuilder: (context) => const [
            PopupMenuItem(value: Locale('en'), child: Text('English')),
            PopupMenuItem(value: Locale('ar'), child: Text('العربية')),
          ],
        ),
/*         if (isDashboard)
          IconButton(
            icon: const Icon(Icons.exit_to_app),
            tooltip: tr('exit'),
            onPressed: () async {
              final shouldExit = await _confirmExit(context);
              if (shouldExit) exit(0);
            },
          ), */
      ],
    );

    final drawer = Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          DrawerHeader(
            decoration: const BoxDecoration(color: Color.fromARGB(255, 69, 200, 218)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.person, size: 40, color: Colors.white),
                const SizedBox(height: 8),
                Text(
                  userName != null ? '${tr('hello')}, $userName' : tr('welcome'),
                  style: const TextStyle(fontSize: 18, color: Colors.white),
                ),
              ],
            ),
          ),
          ListTile(
            leading: const Icon(Icons.dashboard),
            title: Text(tr('dashboard_title')),
            onTap: () => context.go('/dashboard'),
          ),
          ListTile(
            leading: const Icon(Icons.business),
            title: Text(tr('manage_companies')),
            onTap: () => context.go('/companies'),
          ),
          ListTile(
            leading: const Icon(Icons.group),
            title: Text(tr('manage_suppliers')),
            onTap: () => context.go('/suppliers'),
          ),
          ListTile(
            leading: const Icon(Icons.category),
            title: Text(tr('manage_items')),
            onTap: () => context.go('/items'),
          ),
          ListTile(
            leading: const Icon(Icons.shopping_cart),
            title: Text(tr('view_purchase_orders')),
            onTap: () => context.go('/purchase-orders'),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.logout),
            title: Text(tr('logout')),
            onTap: () => logout(context),
          ),
        ],
      ),
    );

    return Scaffold(
      appBar: appBar,
      drawer: drawer,
      body: SafeArea(child: body),
      floatingActionButton: floatingActionButton,
    );
  }
}
 */