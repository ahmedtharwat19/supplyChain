import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

import 'firebase_options.dart';
import 'router.dart';

// import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:firebase_auth/firebase_auth.dart';

Future<void> requestNotificationPermission() async {
  final status = await Permission.notification.status;
  if (!status.isGranted) {
    await Permission.notification.request();
  }
}

/* void connectToFirebaseEmulators() {
  // تأكد أنك لا تستخدم المحاكيات عند النشر للإنتاج
  const bool shouldUseEmulator = true;
  if (shouldUseEmulator) {
    FirebaseFirestore.instance.useFirestoreEmulator('localhost', 8080);
    FirebaseAuth.instance.useAuthEmulator('localhost', 9099);
  }
} */

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await EasyLocalization.ensureInitialized();

  try {
    if (Firebase.apps.isEmpty) {
      if (kIsWeb ||
          Platform.isAndroid ||
          Platform.isIOS ||
          Platform.isWindows) {
        await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform,
        );
      } else {
        await Firebase.initializeApp(); // fallback
      }
    }
  } catch (e) {
    debugPrint('⚠️ Firebase already initialized: $e');
  }

  // الاتصال بالمحاكيات
  // connectToFirebaseEmulators();

  // طلب إذن الإشعارات فقط على الأجهزة المحمولة
  if (!kIsWeb) {
    await requestNotificationPermission();
  }

  runApp(
    EasyLocalization(
      supportedLocales: const [Locale('en'), Locale('ar')],
      path: 'assets/lang',
      fallbackLocale: const Locale('ar'),
      child: Builder(
        builder: (context) => const MyApp(),
      ),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      key: ValueKey(context.locale.languageCode),
      title: 'PureSip',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(primarySwatch: Colors.green),
      locale: context.locale,
      supportedLocales: context.supportedLocales,
      localizationsDelegates: context.localizationDelegates,
      routerConfig: appRouter,
    );
  }
}










/* import 'dart:io';
import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'firebase_options.dart';
import 'router.dart';
import 'package:permission_handler/permission_handler.dart';

Future<void> requestNotificationPermission() async {
  final status = await Permission.notification.status;
  if (!status.isGranted) {
    await Permission.notification.request();
  }
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await EasyLocalization.ensureInitialized();

  try {
    if (Firebase.apps.isEmpty) {
      if (kIsWeb ||
          Platform.isAndroid ||
          Platform.isIOS ||
          Platform.isWindows) {
        await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform,
        );
      } else {
        await Firebase.initializeApp(); // fallback
      }
    }
  } catch (e) {
    debugPrint('⚠️ Firebase already initialized: $e');
  }

  // طلب إذن الإشعارات فقط على الأجهزة المحمولة (Android/iOS)
  if (!kIsWeb) {
    await requestNotificationPermission();
  }

  runApp(
    EasyLocalization(
      supportedLocales: const [Locale('en'), Locale('ar')],
      path: 'assets/lang',
      fallbackLocale: const Locale('ar'),
      child: Builder(
        builder: (context) => const MyApp(),
      ),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      key: ValueKey(context.locale.languageCode),
      title: 'PureSip',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(primarySwatch: Colors.green),
      locale: context.locale,
      supportedLocales: context.supportedLocales,
      localizationsDelegates: context.localizationDelegates,
      routerConfig: appRouter,
    );
  }
}
 */