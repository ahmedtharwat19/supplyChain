import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:puresip_purchasing/services/user_subscription_service.dart';
import 'package:package_info_plus/package_info_plus.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;
  String _appVersion = '';
  late AnimationController _versionController;
  late Animation<Offset> _versionOffset;

  @override
  void initState() {
    super.initState();
    _loadAppVersion(); // ← تحميل رقم الإصدار
    _versionController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _versionOffset = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _versionController, curve: Curves.easeOut),
    );

// شغّل الحركة بعد ظهور الـ splash مباشرة
    _versionController.forward();

    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );

    _fadeAnimation = Tween<double>(begin: 0, end: 1).animate(_fadeController);

    _fadeController.forward();

    // بعد انتهاء التحريك، انتظر ثانية ثم ابدأ التنقل
    _fadeController.addStatusListener((status) async {
      if (status == AnimationStatus.completed) {
        await Future.delayed(const Duration(seconds: 1));
        _startApp(); // ← تابع تحميل التطبيق بعد الانتظار
      }
    });
  }

  Future<void> _loadAppVersion() async {
    final info = await PackageInfo.fromPlatform();
    setState(() {
      _appVersion = 'v${info.version}+${info.buildNumber}';
    });
  }

/*   Future<void> _startApp() async {
  final subscriptionService = UserSubscriptionService();
  final result = await subscriptionService.checkUserSubscription();

  if (!mounted) return;

  if (!result.isValid || result.isExpired) {
    SubscriptionNotifier.showExpiredDialog(context);
    await Future.delayed(const Duration(seconds: 2));
      if (!mounted) return; 
    context.go('/login');
    return;
  }

  SubscriptionNotifier.showWarning(context, result);
  context.go(result.isValid ? '/dashboard' : '/login');
}
   */

/* Future<void> _startApp() async {
  try {
    final subscriptionService = UserSubscriptionService();
    final result = await subscriptionService.checkUserSubscription();

    if (!mounted) return;

    debugPrint('''
      Subscription Check Results:
      - isValid: ${result.isValid}
      - isExpired: ${result.isExpired}
      - Days Remaining: ${result.daysRemaining}
    ''');

    if (!result.isValid || result.isExpired) {
      if (!mounted) return;
      await SubscriptionNotifier.showExpiredDialog(context);
      if (!mounted) return;
      context.go('/login');
      return;
    }

    if (result.daysRemaining <= 7) {
      if (!mounted) return;
      await SubscriptionNotifier.showWarning(context, result);
    }

    if (!mounted) return;
    context.go('/dashboard');
  } catch (e) {
    debugPrint('Error in _startApp: $e');
    if (!mounted) return;
    context.go('/login');
  }
}
 */

  Future<void> _startApp() async {
    try {
      final subscriptionService = UserSubscriptionService();
      final result = await subscriptionService.checkUserSubscription();

      if (!mounted) return;

      debugPrint('''
      Subscription Check Results:
      - isValid: ${result.isValid}
      - isExpired: ${result.isExpired}
      - Days Left: ${result.daysLeft}
    ''');

      if (!result.isValid || result.isExpired) {
        if (!mounted) return;
        SubscriptionNotifier.showExpiredDialog(
          context,
          expiryDate: result.expiryDate ?? DateTime.now(),
        );
        await Future.delayed(const Duration(seconds: 2));
        if (!mounted) return;
        context.go('/login');
        return;
      }

      if (result.daysLeft <= 7) {
        if (!mounted) return;
        SubscriptionNotifier.showWarning(
          context,
          daysLeft: result.daysLeft,
        );
      }

      if (!mounted) return;
      context.go('/dashboard');
    } catch (e) {
      debugPrint('Error in _startApp: $e');
      if (!mounted) return;
      context.go('/login');
    }
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _versionController.dispose(); // ✅
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Expanded(
              child: Center(
                child: Image.asset(
                  'assets/images/splash_screen.jpg',
                  width: 200,
                  height: 200,
                  fit: BoxFit.contain,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 24),
              child: Column(
                children: [
                  const Text(
                    'Ahmed Tharwat tech.',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'ALL RIGHTS ARE RESERVED',
                    style: TextStyle(
                      color: Colors.grey,
                      fontWeight: FontWeight.w500,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 4),
                  SlideTransition(
                    position: _versionOffset,
                    child: AnimatedOpacity(
                      opacity: _appVersion.isNotEmpty ? 1.0 : 0.0,
                      duration: const Duration(milliseconds: 500),
                      child: Text(
                        _appVersion,
                        style: const TextStyle(
                          color: Colors.grey,
                          fontWeight: FontWeight.w400,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
/*                   Text(
                    _appVersion,
                    style: const TextStyle(
                      color: Colors.grey,
                      fontWeight: FontWeight.w400,
                      fontSize: 12,
                    ),
                  ), */
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}


/*   void _showExpiredDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        title: Text(tr('membership_expired_title')),
        content: Text(tr('membership_expired_message')),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              context.go('/login');
            },
            child: Text(tr('ok')),
          ),
        ],
      ),
    );
  }
 */
/*   void _showErrorDialog(String message) {
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('error'.tr()),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _startApp(); // إعادة المحاولة
            },
            child: Text('retry'.tr()),
          ),
        ],
      ),
    );
  }
 */
 

/*   Future<void> _startApp() async {
    final connectivityResult = await Connectivity().checkConnectivity();
    debugPrint('📶 Connectivity result: ${connectivityResult.runtimeType}');

    if (connectivityResult.contains(ConnectivityResult.none)) {
      _showErrorDialog('no_internet'.tr());
      return;
    }

    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      debugPrint('❌ ${'user_not_logged_in'.tr()}');
      if (!mounted) return;
      context.go('/login');
      return;
    }

    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      final isActive = userDoc.data()?['isActive'] == true;

      if (!userDoc.exists || !isActive) {
        debugPrint('❗️ Showing inactive account dialog');
        await FirebaseAuth.instance.signOut();

        if (!mounted) return;

        await showDialog(
          context: context,
          barrierDismissible: false,
          builder: (_) => AlertDialog(
            title: Text(tr('membership_expired_title')),
            content: Text(tr('membership_expired_message')),
            actions: [
              TextButton(
                onPressed: () async {
                  Navigator.of(context).pop();
                  if (mounted) context.go('/login');
                },
                child: Text(tr('ok')),
              ),
            ],
          ),
        );

        return; // مهم جدًا حتى لا يكمل الكود للتنقل إلى /dashboard
      }

      // إذا كان المستخدم نشطًا - نحفظ بياناته محليًا
      final localUser = await UserLocalStorage.getUser();
      if (localUser == null) {
        await UserLocalStorage.saveUser(
          userId: user.uid,
          email: user.email ?? '',
          displayName: user.displayName ?? '',
        );
        debugPrint('📦 ${'local_user_saved'.tr()}');
      } else {
        debugPrint('📦 ${'local_user_exists'.tr(args: [
              localUser['displayName'] ?? ''
            ])}');
      }

      if (!mounted) return;
      context.go('/dashboard');
    } catch (e) {
      debugPrint('🔥 Firestore error: $e');

      await FirebaseAuth.instance.signOut();

      if (!mounted) return;
      await showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: Text(tr('error')),
          content: Text(tr('membership_expired_message')),
          actions: [
            TextButton(
              onPressed: () async {
                Navigator.of(context).pop();
                if (mounted) context.go('/login');
              },
              child: Text(tr('ok')),
            ),
          ],
        ),
      );
      return;
    }
  }
 */

/*   Future<void> _startApp() async {
    final connectivityResult = await Connectivity().checkConnectivity();
    debugPrint('📶 Connectivity result: ${connectivityResult.runtimeType}');

    if (connectivityResult.contains(ConnectivityResult.none)) {
      _showErrorDialog('no_internet'.tr());
      return;
    }

    final localUser = await UserLocalStorage.getUser();

    if (localUser == null) {
      debugPrint('🚫 No local user. Redirecting to login.');
      if (!mounted) return;
      context.go('/login');
      return;
    }

    debugPrint('✅ Local user found: ${localUser['email']}');

    try {
      final user = FirebaseAuth.instance.currentUser;

      if (user == null) {
        debugPrint('❌ Firebase user not logged in');
        if (!mounted) return;
        context.go('/login');
        return;
      }

      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      final isActive = userDoc.data()?['isActive'] == true;

      if (!userDoc.exists || !isActive) {
        debugPrint('⛔️ User inactive or document not found');
        await FirebaseAuth.instance.signOut();

        if (!mounted) return;
        await showDialog(
          context: context,
          barrierDismissible: false,
          builder: (_) => AlertDialog(
            title: Text(tr('membership_expired_title')),
            content: Text(tr('membership_expired_message')),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  context.go('/login');
                },
                child: Text(tr('ok')),
              ),
            ],
          ),
        );

        return;
      }

      if (!mounted) return;
      context.go('/dashboard');
    } catch (e) {
      debugPrint('🔥 Firestore error: $e');
      await FirebaseAuth.instance.signOut();

      if (!mounted) return;
      await showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: Text(tr('error')),
          content: Text(tr('membership_expired_message')),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                context.go('/login');
              },
              child: Text(tr('ok')),
            ),
          ],
        ),
      );
    }
  }
 */

/* 
last update 05-08-2025
Future<void> _startApp() async {
  final connectivityResult = await Connectivity().checkConnectivity();
  debugPrint('📶 Connectivity result: ${connectivityResult.runtimeType}');

  if (connectivityResult.contains(ConnectivityResult.none)) {
    _showErrorDialog('no_internet'.tr());
    return;
  }

  final localUser = await UserLocalStorage.getUser();

  if (localUser == null) {
    debugPrint('🚫 No local user. Redirecting to login.');
    if (!mounted) return;
    context.go('/login');
    return;
  }

  debugPrint('✅ Local user found: ${localUser['email']}');

  try {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      debugPrint('❌ Firebase user not logged in');
      if (!mounted) return;
      context.go('/login');
      return;
    }

    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();

    if (!userDoc.exists) {
      debugPrint('⛔️ User document not found');
      await FirebaseAuth.instance.signOut();
      if (!mounted) return;
      context.go('/login');
      return;
    }

    final data = userDoc.data();
    final isActive = data?['isActive'] == true;
    final durationDays = data?['subscriptionDurationInDays'] ?? 30;
    final createdAt = (data?['createdAt'] as Timestamp?)?.toDate();

    if (!isActive || createdAt == null) {
      debugPrint('⛔️ User inactive or missing createdAt');
      await FirebaseAuth.instance.signOut();
      if (!mounted) return;
      _showExpiredDialog();
      return;
    }

    final now = DateTime.now();
    final expiryDate = createdAt.add(Duration(days: durationDays));
    final daysLeft = expiryDate.difference(now).inDays;

    if (now.isAfter(expiryDate)) {
      debugPrint('🔴 Subscription expired on $expiryDate');

      // إلغاء تفعيل الحساب في Firestore
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .update({'isActive': false});

      await FirebaseAuth.instance.signOut();

      if (!mounted) return;
      _showExpiredDialog();
      return;
    }

    // تذكير بقرب انتهاء الاشتراك
    if (daysLeft <= 3) {
      debugPrint('⚠️ Subscription expires in $daysLeft day(s)');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(tr('subscription_expires_soon')),
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }

    // ✅ كل شيء تمام، توجه إلى لوحة التحكم
    if (!mounted) return;
    context.go('/dashboard');
  } catch (e) {
    debugPrint('🔥 Firestore error: $e');
    await FirebaseAuth.instance.signOut();

    if (!mounted) return;
    _showExpiredDialog();
  }
}
 */

 /*  Future<void> _startApp() async {
    final connectivityResult = await Connectivity().checkConnectivity();
    debugPrint('📶 Connectivity result: $connectivityResult');

    final isOffline = connectivityResult.contains(ConnectivityResult.none);

    if (isOffline) {
      // 📴 عرض رسالة بأن الإنترنت غير متاح
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(tr('no_internet_connection')),
            backgroundColor: Colors.orange,
            duration: const Duration(seconds: 4),
          ),
        );
      }

      // 👤 محاولة استخدام بيانات المستخدم من SharedPreferences
      final localUser = await UserLocalStorage.getUser();
      if (localUser == null) {
        debugPrint('🚫 No local user. Redirecting to login.');
        if (mounted) context.go('/login');
        return;
      }

      final createdAtString = localUser['createdAt'] as String?;
      final createdAt =
          createdAtString != null ? DateTime.tryParse(createdAtString) : null;

      final duration = localUser['subscriptionDurationInDays'] as int? ?? 30;

      if (createdAt == null) {
        debugPrint('⚠️ createdAt not found in local user data.');
        if (mounted) context.go('/login');
        return;
      }

      final now = DateTime.now();
      final expiryDate = createdAt.add(Duration(days: duration));

      if (now.isAfter(expiryDate)) {
        debugPrint('🔴 Local subscription expired on $expiryDate');

        if (mounted) {
          await showDialog(
            context: context,
            barrierDismissible: false,
            builder: (_) => AlertDialog(
              title: Text(tr('membership_expired_title')),
              content: Text(tr('membership_expired_message')),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    context.go('/login');
                  },
                  child: Text(tr('ok')),
                ),
              ],
            ),
          );
        }
        return;
      }

      // ✅ الاشتراك ما زال ساريًا
      debugPrint('🟢 Local subscription still valid until $expiryDate');
      if (mounted) context.go('/dashboard');
      return;
    }

    // ✅ إذا كان هناك إنترنت، نتابع التحقق من Firebase (نفس الكود السابق)
    try {
      final user = FirebaseAuth.instance.currentUser;

      if (user == null) {
        debugPrint('❌ Firebase user not logged in');
        if (!mounted) return;
        context.go('/login');
        return;
      }

      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (!userDoc.exists) {
        debugPrint('⛔️ User document not found');
        await FirebaseAuth.instance.signOut();
        if (!mounted) return;
        context.go('/login');
        return;
      }

      final data = userDoc.data();
      final isActive = data?['isActive'] == true;
      final durationDays = data?['subscriptionDurationInDays'] ?? 30;
      final createdAt = (data?['createdAt'] as Timestamp?)?.toDate();

      if (!isActive || createdAt == null) {
        debugPrint('⛔️ User inactive or missing createdAt');
        await FirebaseAuth.instance.signOut();
        if (!mounted) return;
        _showExpiredDialog();
        return;
      }

      final now = DateTime.now();
      final expiryDate = createdAt.add(Duration(days: durationDays));
      final daysLeft = expiryDate.difference(now).inDays;

      if (now.isAfter(expiryDate)) {
        debugPrint('🔴 Subscription expired on $expiryDate');

        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .update({'isActive': false});

        await FirebaseAuth.instance.signOut();

        if (!mounted) return;
        _showExpiredDialog();
        return;
      }

      // ⚠️ إشعار المستخدم باقتراب انتهاء الاشتراك
      if (daysLeft <= 3) {
        debugPrint('⚠️ Subscription expires in $daysLeft day(s)');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                  tr('subscription_expires_soon', args: [daysLeft.toString()])),
              backgroundColor: Colors.orange,
              duration: const Duration(seconds: 4),
            ),
          );
        }
      }

      // ✅ حفظ المستخدم محليًا إن لم يكن موجود
      final localUser = await UserLocalStorage.getUser();
      if (localUser == null) {
        await UserLocalStorage.saveUser(
          userId: user.uid,
          email: user.email ?? '',
          displayName: user.displayName ?? '',
          subscriptionDurationInDays: durationDays,
          createdAt: createdAt,
          companyIds: List<String>.from(data?['companyIds'] ?? []),
          factoryIds: List<String>.from(data?['factoryIds'] ?? []),
          supplierIds: List<String>.from(data?['supplierIds'] ?? []),
          isActive: data?['isActive'] == true,
        );
        debugPrint('📦 Local user saved.');
      }

      if (mounted) context.go('/dashboard');
    } catch (e) {
      debugPrint('🔥 Firestore error: $e');
      await FirebaseAuth.instance.signOut();
      if (!mounted) return;
      _showExpiredDialog();
    }
  }
 */
  

/*   @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );
    _fadeAnimation = Tween<double>(begin: 0, end: 1).animate(_fadeController);
    _fadeController.forward();

    _startApp();
  }
 */


/*   Future<void> _startApp() async {
    //  await Future.delayed(const Duration(seconds: 2));

    final connectivityResult = await Connectivity().checkConnectivity();

    debugPrint('📶 Connectivity result: ${connectivityResult.runtimeType}');
    // المقارنة صحيحة لأن connectivityResult من نوع ConnectivityResult
    if (connectivityResult.contains(ConnectivityResult.none)) {
      _showErrorDialog('no_internet'.tr());
      return;
    }

    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      debugPrint('❌ ${'user_not_logged_in'.tr()}');
      if (!mounted) return;
      context.go('/login');
      return;
    }

      /* 
          final userDoc = await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .get();

          if (!userDoc.exists || userDoc.data()?['isActive'] == false) {
            debugPrint('⛔️ ${'account_inactive'.tr()}');
            debugPrint('❗️ Showing inactive account dialog');

            await FirebaseAuth.instance.signOut();
            _showErrorDialog('account_inactive'.tr());
            await Future.delayed(const Duration(milliseconds: 500));
            await FirebaseAuth.instance.signOut();
            return;
          } */
    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (!userDoc.exists || userDoc.data()?['isActive'] == false) {
        debugPrint('❗️ Showing inactive account dialog');
        await FirebaseAuth.instance.signOut();

        if (!mounted) return;

        await showDialog(
          context: context,
          barrierDismissible: false,
          builder: (_) => AlertDialog(
            title: Text(tr('membership_expired_title')),
            content: Text(tr('membership_expired_message')),
            actions: [
              TextButton(
                onPressed: () async {
                  Navigator.of(context).pop();
                  Future.microtask(() {
                    if (mounted) context.go('/login');
                  });
                 // context.go('/login');
                },
                child: Text(tr('ok')),
              ),
            ],
          ),
        );

        return;
      }
    } catch (e) {
      debugPrint('🔥 Firestore error: $e');

      if (!mounted) return;
      await showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: Text(tr('error')),
          content: Text(tr('membership_expired_message')), // يمكن تخصيص رسالة
          actions: [
            TextButton(
              onPressed: () async {
                Navigator.of(context).pop();
                Future.microtask(() {
                  if (mounted) context.go('/login');
                });
                context.go('/login');
              },
              child: Text(tr('ok')),
            ),
          ],
        ),
      );
      return;
    }

    final localUser = await UserLocalStorage.getUser();
    if (localUser == null) {
      await UserLocalStorage.saveUser(
        userId: user.uid,
        email: user.email ?? '',
        displayName: user.displayName ?? '',
      );
      debugPrint('📦 ${'local_user_saved'.tr()}');
    } else {
      debugPrint('📦 ${'local_user_exists'.tr(args: [
            localUser['displayName'] ?? ''
          ])}');
    }

    if (!mounted) return;
    context.go('/dashboard');
  } */



/* import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';
import 'package:puresip_purchasing/utils/user_local_storage.dart';
//import 'package:puresip_purchasing/services/user_local_storage.dart'; // تأكد من استيراد المسار الصحيح

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    debugPrint('📱 Splash started');

    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );

    _fadeAnimation = Tween<double>(begin: 0, end: 1).animate(_fadeController);
    _fadeController.forward();

    _checkAuthAndNavigate();
  }

  Future<void> _checkAuthAndNavigate() async {
    await Future.delayed(const Duration(seconds: 2)); // لإظهار السبلاتش

    final user = FirebaseAuth.instance.currentUser;

    if (user != null) {
      debugPrint('✅ Firebase user found: ${user.uid}');

      // تحقق إن كانت البيانات المحلية محفوظة
      final localUser = await UserLocalStorage.getUser();

      if (localUser == null) {
        await UserLocalStorage.saveUser(
          userId: user.uid,
          email: user.email ?? '',
          displayName: user.displayName ?? '',
        );
        debugPrint('📦 Local user data saved from Firebase.');
      } else {
        debugPrint('📦 Loaded local user: ${localUser['displayName']}');
      }

      if (!mounted) return;
      context.go('/dashboard');
    } else {
      debugPrint('❌ No Firebase user found, redirecting to login');
      if (!mounted) return;
      context.go('/login');
    }
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Expanded(
              child: Center(
                child: Image.asset(
                  'assets/images/splash_screen.jpg',
                  width: 200,
                  height: 200,
                  fit: BoxFit.contain,
                ),
              ),
            ),
            const Padding(
              padding: EdgeInsets.only(bottom: 24),
              child: Column(
                children: [
                  Text(
                    'Ahmed Tharwat tech.',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'ALL RIGHTS ARE RESERVED',
                    style: TextStyle(
                      color: Colors.grey,
                      fontWeight: FontWeight.w500,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}







/*
import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:puresip_purchasing/services/user_local_storage.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );
    _fadeAnimation = Tween<double>(begin: 0, end: 1).animate(_fadeController);
    _fadeController.forward();

    _handleStartupFlow();
  }

  Future<void> _handleStartupFlow() async {
    await Future.delayed(const Duration(seconds: 2));

    // ✅ التحقق من الاتصال
    final connectivityResult = await Connectivity().checkConnectivity();
    if (connectivityResult == ConnectivityResult.none) {
      _showErrorAndExit('لا يوجد اتصال بالإنترنت');
      return;
    }

    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      debugPrint('❌ No authenticated user.');
      if (!mounted) return;
      context.go('/login');
      return;
    }

    debugPrint('✅ Firebase user found: ${user.uid}');

    // ✅ التحقق من صلاحيات المستخدم (مثال: هل حسابه مفعل؟)
    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();

    if (!userDoc.exists || (userDoc.data()?['isActive'] == false)) {
      debugPrint('⛔️ User is not authorized.');
      await FirebaseAuth.instance.signOut();
      _showErrorAndExit('حسابك غير مفعل، تواصل مع الإدارة.');
      return;
    }

    // ✅ تخزين بيانات المستخدم محليًا إن لم تكن موجودة
    final localUser = await UserLocalStorage.getUser();
    if (localUser == null) {
      await UserLocalStorage.saveUser(
        userId: user.uid,
        email: user.email ?? '',
        displayName: user.displayName ?? '',
      );
      debugPrint('📦 Local user saved.');
    } else {
      debugPrint('📦 Loaded local user: ${localUser['displayName']}');
    }

    if (!mounted) return;
    context.go('/dashboard');
  }

  void _showErrorAndExit(String message) {
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('خطأ'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => exit(0), // يمكنك استبدالها بإعادة المحاولة أو تسجيل الخروج
            child: const Text('إغلاق'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Expanded(
              child: Center(
                child: Image.asset(
                  'assets/images/splash_screen.jpg',
                  width: 200,
                  height: 200,
                  fit: BoxFit.contain,
                ),
              ),
            ),
            const Padding(
              padding: EdgeInsets.only(bottom: 24),
              child: Column(
                children: [
                  Text(
                    'Ahmed Tharwat tech.',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'ALL RIGHTS ARE RESERVED',
                    style: TextStyle(
                      color: Colors.grey,
                      fontWeight: FontWeight.w500,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

*/








/* import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    debugPrint('📱 Splash started on Android');
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );

    _fadeAnimation = Tween<double>(begin: 0, end: 1).animate(_fadeController);
    _fadeController.forward();

    Timer(const Duration(seconds: 3), () {
      _fadeController.stop();
      if (mounted) {
        debugPrint('🚀 Navigating to / from splash');
        context.go('/dashboard'); // انتقل إلى الصفحة الرئيسية بعد السبلاتش
      }
    });
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: FadeTransition(
        opacity: _fadeAnimation, // ← استخدم المتغير فعليًا هنا
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Expanded(
              child: Center(
                child: Image.asset(
                  'assets/images/splash_screen.jpg',
                  width: 200,
                  height: 200,
                  fit: BoxFit.contain,
                ),
              ),
            ),
            const Padding(
              padding: EdgeInsets.only(bottom: 24),
              child: Column(
                children: [
                  Text(
                    'Ahmed Tharwat tech.',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'ALL RIGHTS ARE RESERVED',
                    style: TextStyle(
                      color: Colors.grey,
                      fontWeight: FontWeight.w500,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
 */ */