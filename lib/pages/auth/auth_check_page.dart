import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../dashboard/dashboard_page.dart';
import 'login_page.dart';
import '../../../utils/user_local_storage.dart'; // تأكد من صحة المسار

class AuthCheckPage extends StatefulWidget {
  const AuthCheckPage({super.key});

  @override
  State<AuthCheckPage> createState() => _AuthCheckPageState();
}

class _AuthCheckPageState extends State<AuthCheckPage> {
  @override
  void initState() {
    super.initState();

    // الاستماع لحالة المصادقة وتخزين أو مسح البيانات حسب الحالة
    FirebaseAuth.instance.authStateChanges().listen((user) async {
      if (user != null) {
        await UserLocalStorage.saveUser(
          userId: user.uid,
          email: user.email ?? '',
          displayName: user.displayName ?? '',
        );
      } else {
        await UserLocalStorage.clearUser();
        await FirebaseAuth.instance.signOut();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Scaffold(
            body: Center(child: Text('Error: ${snapshot.error}')),
          );
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasData && snapshot.data != null) {
          final user = snapshot.data!;
          final userName = user.displayName ?? user.email ?? 'User';
          return DashboardPage(userName: userName);
        }

        return const LoginPage();
      },
    );
  }
}
