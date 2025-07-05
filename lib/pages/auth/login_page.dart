import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../blocs/auth/auth_cubit.dart';
import '../../widgets/auth/login_form.dart';

class LoginPage extends StatelessWidget {
  const LoginPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => AuthCubit(),
      child: Scaffold(
        appBar: AppBar(
          title: Text('login'.tr()),
          actions: [
            PopupMenuButton<Locale>(
              icon: const Icon(Icons.language),
              onSelected: (locale) {
                context.setLocale(locale);
              },
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: const Locale('en'),
                  child: Text('language_en'.tr()),
                ),
                PopupMenuItem(
                  value: const Locale('ar'),
                  child: Text('language_ar'.tr()),
                ),
              ],
            ),
          ],
        ),
        body: const Padding(
          padding: EdgeInsets.all(16.0),
          child: LoginForm(),
        ),
      ),
    );
  }
}
