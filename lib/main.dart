import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart'; // Ensure Firebase is imported
import 'firebase_options.dart'; // Your Firebase options file
import 'router.dart'; // Your router configuration
//import 'pages/splash_screen.dart'; // Your splash screen

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Firebase
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    debugPrint("Firebase initialized successfully.");
    
  } catch (e) {
    debugPrint("Error initializing Firebase: $e");
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Your App Title',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(primarySwatch: Colors.green),
      routerConfig: appRouter, // Your router configuration
    );
  }
}