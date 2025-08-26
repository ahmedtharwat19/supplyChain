import 'dart:async';
import 'package:collection/collection.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:go_router/go_router.dart';
import 'package:puresip_purchasing/pages/dashboard/dashboard_metrics.dart';
import 'package:puresip_purchasing/pages/dashboard/dashboard_tile_widget.dart';
import 'package:puresip_purchasing/pages/settings_page.dart';
import 'package:puresip_purchasing/services/user_subscription_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../utils/user_local_storage.dart';
import '../../widgets/app_scaffold.dart';
import 'package:pull_to_refresh/pull_to_refresh.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => DashboardPageState();
}

enum DashboardView { short, long }

class DashboardPageState extends State<DashboardPage> {
  StreamSubscription<DocumentSnapshot>? _userSubscription;
  StreamSubscription<QuerySnapshot>? _licenseStatusSubscription;

  // Controllers and State
  final RefreshController _refreshController =
      RefreshController(initialRefresh: false);
  DashboardView _dashboardView = DashboardView.short;
  Set<String> _selectedCards = {};

  // Loading state
  bool isLoading = true;
  bool isSubscriptionExpiringSoon = false;
  bool isSubscriptionExpired = false;
  // Dashboard metrics
  final DashboardStats _stats = DashboardStats.empty();
  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  StreamSubscription? _notificationSubscription;

  // User data
  String? userId;
  String? userName;
  List<String> userCompanyIds = [];

  @override
  void initState() {
    super.initState();
    _initializeData();
    _checkSubscriptionStatus();
    _startListeningToUserChanges();
    _setupFCM();
    _checkInitialNotification();
    _setupLicenseStatusListener(); // ⬅️ أضف هذا هنا أيضًا
  }

  @override
  void dispose() {
    _userSubscription?.cancel();
    _refreshController.dispose();
    _notificationSubscription?.cancel();
    _licenseStatusSubscription?.cancel();
    super.dispose();
  }

  void _setupLicenseStatusListener() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    _licenseStatusSubscription = FirebaseFirestore.instance
        .collection('licenses')
        .where('userId', isEqualTo: user.uid)
        .snapshots()
        .listen((snapshot) {
      if (!mounted) return;
/* 
      final licenseDoc = snapshot.docs.firstWhere(
        (doc) => doc.exists,
        orElse: () => null,
      );

      if (licenseDoc == null) {
        // لا يوجد ترخيص - توجيه المستخدم
        context.go('/license/request');
        return;
      } */

      debugPrint('License docs count: ${snapshot.docs.length}');
      for (var doc in snapshot.docs) {
        debugPrint('License id: ${doc.id}, data: ${doc.data()}');
      }

      final docs = snapshot.docs.where((doc) => doc.exists).toList();
      if (docs.isEmpty) {
        // لا يوجد ترخيص - توجيه المستخدم
        debugPrint('no license found');
        context.go('/license/request');
        return;
      }

      //final licenseDoc = docs.first;
      final now = DateTime.now();
      final licenseDoc = docs.firstWhereOrNull((doc) {
        final isActive = doc.get('isActive') as bool? ?? false;
        final expiry = (doc.get('expiryDate') as Timestamp?)?.toDate();
        final isExpired = expiry != null && expiry.isBefore(now);
        return isActive && !isExpired;
      });

      final isActive = licenseDoc?.get('isActive') as bool? ?? false;
      final expiryTimestamp = licenseDoc?.get('expiryDate') as Timestamp?;
      final expiryDate = expiryTimestamp?.toDate();
      final isExpired =
          expiryDate != null && expiryDate.isBefore(DateTime.now());

      debugPrint('License isActive: $isActive, isExpired: $isExpired');

      if (!isActive || isExpired) {
        // الترخيص ملغي أو منتهي
        debugPrint('License is expired or canceled');
        context.go('/license/request');
      }
    });
  }

  Future<void> _setupFCM() async {
    await _fcm.requestPermission();
    _notificationSubscription = FirebaseMessaging.onMessage.listen((message) {
      _showNotification(message);
    });
  }

  void _checkInitialNotification() async {
    RemoteMessage? initialMessage = await _fcm.getInitialMessage();
    if (initialMessage != null) {
      _handleNotification(initialMessage);
    }
  }

  void _handleNotification(RemoteMessage message) {
    // تأكد من أن الويدجيت ما زال mounted
    if (!mounted) return;

    // معالجة الإشعار حسب نوعه
    if (message.data['type'] == 'license_request') {
      // عرض تفاصيل الإشعار أولاً
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('request_details'.tr()),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('new_license_from'.tr(namedArgs: {
                'email': message.data['userEmail'] ?? 'unknown_user'.tr()
              })),
              const SizedBox(height: 8),
              Text('request_id'.tr(args: [message.data['requestId'] ?? ''])),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context); // إغلاق الـ Dialog
                _navigateToLicenseRequests(); // التنقل لصفحة الطلبات
              },
              child: Text('view_details'.tr()),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('ok'.tr()),
            ),
          ],
        ),
      );
    } else {
      // للإشعارات العامة
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(message.notification?.title ?? 'new_notification'.tr()),
          content:
              Text(message.notification?.body ?? 'new_license_request'.tr()),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('ok'.tr()),
            ),
          ],
        ),
      );
    }
  }

  void _navigateToLicenseRequests() {
    Navigator.pushNamed(context, '/license-requests');
  }

  void _showNotification(RemoteMessage message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(message.notification?.title ?? 'New Notification'),
        content: Text(message.notification?.body ?? 'New license request'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('ok'.tr()),
          ),
        ],
      ),
    );
  }

  Future<void> _initializeData() async {
    await _syncUserData();
    await _reloadUserData(); // ✅ هذا جديد
    await loadSettings();
    await _loadInitialData();
  }

  bool isSameDate(DateTime? a, DateTime? b) {
    if (a == null || b == null) return false;
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  void _startListeningToUserChanges() async {
    final firebaseUser = FirebaseAuth.instance.currentUser;
    if (firebaseUser == null) return;

    _userSubscription = FirebaseFirestore.instance
        .collection('users')
        .doc(firebaseUser.uid)
        .snapshots()
        .listen((snapshot) async {
      debugPrint('🔥 Firestore snapshot received.');

      if (!snapshot.exists) return;
      final data = snapshot.data();
      if (data == null) return;

      final localUser = await UserLocalStorage.getUser();
      bool needUpdate = false;

      final cloudCreatedAt = (data['createdAt'] as Timestamp?)?.toDate();
      final cloudDuration = data['subscriptionDurationInDays'] ?? 30;
      final cloudIsActive = data['isActive'] ?? true;

      final localCreatedAt = localUser?['createdAt'] as DateTime?;
      final localDuration = localUser?['subscriptionDurationInDays'];
      final localIsActive = localUser?['isActive'];

      debugPrint('🔍 Comparing:');
      debugPrint(
          '📦 cloud => createdAt=$cloudCreatedAt, duration=$cloudDuration, isActive=$cloudIsActive');
      debugPrint(
          '📦 local => createdAt=$localCreatedAt, duration=$localDuration, isActive=$localIsActive');

      if (localCreatedAt == null ||
          !localCreatedAt.isAtSameMomentAs(cloudCreatedAt!) ||
          localDuration != cloudDuration ||
          localIsActive != cloudIsActive) {
        needUpdate = true;
      }
      if (localCreatedAt != null && cloudCreatedAt != null) {
        debugPrint(
            '📏 Time diff: ${localCreatedAt.difference(cloudCreatedAt).inMilliseconds} ms');
      }

      if (needUpdate) {
        await UserLocalStorage.saveUser(
          userId: firebaseUser.uid,
          email: firebaseUser.email ?? '',
          displayName: firebaseUser.displayName,
/*           companyIds: (data['companyIds'] as List?)?.cast<String>() ?? [],
          factoryIds: (data['factoryIds'] as List?)?.cast<String>() ?? [],
          supplierIds: (data['supplierIds'] as List?)?.cast<String>() ?? [], */
          companyIds: (data['companyIds'] is List)
              ? (data['companyIds'] as List).cast<String>()
              : [],
          factoryIds: (data['factoryIds'] is List)
              ? (data['factoryIds'] as List).cast<String>()
              : [],
          supplierIds: (data['supplierIds'] is List)
              ? (data['supplierIds'] as List).cast<String>()
              : [],
          createdAt: cloudCreatedAt!,
          subscriptionDurationInDays: cloudDuration,
          isActive: cloudIsActive,
        );

        debugPrint('✅ Local user data updated from Firestore.');

        if (mounted) {
          setState(() {
            userName = firebaseUser.displayName;
            userId = firebaseUser.uid;
            userCompanyIds =
                (data['companyIds'] as List?)?.cast<String>() ?? [];
          });
          _reloadUserData();
        }
      }
    });
  }

  Future<void> _reloadUserData() async {
    final user = await UserLocalStorage.getUser();
    if (user == null || !mounted) return;

    setState(() {
      userName = user['displayName'];
      userId = user['userId'];
      userCompanyIds = (user['companyIds'] as List?)?.cast<String>() ?? [];
      _stats.totalCompanies = userCompanyIds.length;
      final createdAt = user['createdAt'] as DateTime?;
      final subscriptionDuration = user['subscriptionDurationInDays'] as int?;
      final isActive = user['isActive'] as bool?;

      debugPrint(
          '🔁 Local reload: createdAt=$createdAt, duration=$subscriptionDuration, isActive=$isActive');
    });
  }

  Future<void> loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _dashboardView = prefs.getString(prefDashboardView) == 'long'
          ? DashboardView.long
          : DashboardView.short;
      _selectedCards = (prefs.getStringList(prefSelectedCards) ?? []).toSet();
    });
  }

  Future<void> _loadInitialData() async {
    final user = await UserLocalStorage.getUser();
    if (user == null || !mounted) return;

    setState(() {
      userName = user['displayName'];
      userId = user['userId'];
      userCompanyIds = (user['companyIds'] as List?)?.cast<String>() ?? [];
      _stats.totalCompanies = userCompanyIds.length;
    });

    await _loadCachedData();
    await fetchStats();
  }

/*  Future<void> _checkSubscriptionStatus() async {
  final subscriptionService = UserSubscriptionService();
  final result = await subscriptionService.checkUserSubscription();

  if (!mounted) return;

  setState(() {
    isSubscriptionExpiringSoon = result.isExpiringSoon;
    isSubscriptionExpired = result.isExpired;
    isLoading = false;
  });

  SubscriptionNotifier.showWarning(context, result);
} */
  Future<void> _checkSubscriptionStatus() async {
    final subscriptionService = UserSubscriptionService();
    final result = await subscriptionService.checkUserSubscription();

    if (!mounted) return;

    setState(() {
      isSubscriptionExpiringSoon = result.isExpiringSoon;
      isSubscriptionExpired = result.isExpired;
      isLoading = false;
    });

    // Show warning if subscription is expiring soon
    if (result.isExpiringSoon) {
      SubscriptionNotifier.showWarning(
        context,
        daysLeft: result.daysLeft,
      );
    }

    // Show expired dialog if subscription is expired
    if (result.isExpired && result.expiryDate != null) {
      SubscriptionNotifier.showExpiredDialog(
        context,
        expiryDate: result.expiryDate!,
      );
    }
  }

  Future<void> _loadCachedData() async {
    final cached = await UserLocalStorage.getDashboardData();
    final extended = await UserLocalStorage.getExtendedStats();

    if (!mounted) return;

    setState(() {
      _stats
        ..totalSuppliers = cached['totalSuppliers'] ?? 0
        ..totalOrders = cached['totalOrders'] ?? 0
        ..totalAmount = cached['totalAmount'] ?? 0.0
        ..totalItems = cached['totalItems'] ?? 0
        ..totalMovements = extended['totalStockMovements'] ?? 0
        ..totalManufacturingOrders = extended['totalManufacturingOrders'] ?? 0
        ..totalFinishedProducts = extended['totalFinishedProducts'] ?? 0
        ..totalFactories = extended['totalFactories'] ?? 0;
    });
  }

  Future<void> fetchStats() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || !mounted) return;

    setState(() => isLoading = true);

    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      debugPrint('userDoc : $userDoc');
      final updatedCompanyIds =
          (userDoc.data()?['companyIds'] as List?)?.cast<String>() ?? [];

      // Parallel fetch of basic counts
      final [itemsCount, suppliersCount,finishedProductCount] = await Future.wait([
        _fetchCollectionCount('items'),
        _fetchCollectionCount('vendors'),
        _fetchCollectionCount('finished_products'),
      ]);
      final poStats = await _fetchPoStats();
    //  final fPStates = await _fetchFinishedProducts();
      // Fetch company-specific stats
      int orderCount = 0;
      double amountSum = 0.0;
      int movementCount = 0;
      int manufacturingCount = 0;
     // int finishedProductCount = 0;

      if (updatedCompanyIds.isNotEmpty) {
        final companyResults = await Future.wait(
          updatedCompanyIds.map((companyId) => _getCompanyStats(companyId)),
        );

        for (final result in companyResults) {
          orderCount =
              poStats['count']; // += (result['orders'] as num).toInt();
          amountSum = poStats[
              'totalAmount']; // += (result['amount'] as num).toDouble();
          movementCount += (result['movements'] as num).toInt();
          manufacturingCount += (result['manufacturing'] as num).toInt();
       //   finishedProductCount += fPStates['count']; //(result['finishedProducts'] as num).toInt();
        }
      }

      // Fetch factories count
      final factoryCount = await _fetchFactoriesCount();

      // Create new stats object
      final newStats = DashboardStats(
        totalCompanies: updatedCompanyIds.length,
        totalItems: itemsCount,
        totalSuppliers: suppliersCount,
        totalOrders: orderCount,
        totalAmount: amountSum,
        totalMovements: movementCount,
        totalManufacturingOrders: manufacturingCount,
        totalFinishedProducts: finishedProductCount,
        totalFactories: factoryCount,
      );

      // Update state and storage
      if (mounted) {
        setState(() {
          userCompanyIds = updatedCompanyIds;
          _stats.updateFrom(newStats);
        });
        await _saveToLocalStorage();
      }
    } catch (e) {
      debugPrint('❌ Error in fetchStats: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(tr('error_fetching_data'))),
        );
      }
    } finally {
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  Future<int> _fetchCollectionCount(String collection) async {
    try {
      if (userId == null) return 0;
      final snapshot = await FirebaseFirestore.instance
          .collection(collection)
          .where('userId', isEqualTo: userId)
          .get();
      return snapshot.size;
    } catch (e) {
      debugPrint('❌ Error fetching $collection: $e');
      return 0;
    }
  }

  Future<Map<String, dynamic>> _getCompanyStats(String companyId) async {
    try {
      final results = await Future.wait([
        //      _getSubCollectionCount('purchase_orders', companyId),
        _getSubCollectionCount('stock_movements', companyId),
        _getSubCollectionCount('manufacturing_orders', companyId),
   //     _getSubCollectionCount('finished_products', companyId),
      ]);

      return {
        //     'orders': results[0]['count'],
        //    'amount': results[0]['amount'],
        'movements': results[0]['count'],
        'manufacturing': results[1]['count'],
  //      'finishedProducts': results[2]['count'],
      };
    } catch (e) {
      debugPrint('❌ Error getting stats for company $companyId: $e');
      return {
        //    'orders': 0,
        //     'amount': 0.0,
        'movements': 0,
        'manufacturing': 0,
    //   'finishedProducts': 0,
      };
    }
  }

  Future<Map<String, dynamic>> _getSubCollectionCount(
      String collection, String companyId) async {
    try {
      if (userId == null) return {'count': 0, 'amount': 0.0};

      final snapshot = await FirebaseFirestore.instance
          .collection('companies/$companyId/$collection')
          .where('userId', isEqualTo: userId)
          .get();

      double amount = 0.0;
      if (collection == 'purchase_orders') {
        amount = snapshot.docs.fold(0.0, (total, doc) {
          final val = doc.data()['totalAmount'];
          return total + ((val is num) ? val.toDouble() : 0.0);
        });
      }

      return {'count': snapshot.size, 'amount': amount};
    } catch (e) {
      debugPrint('❌ Error fetching $collection: $e');
      return {'count': 0, 'amount': 0.0};
    }
  }

  // Future<Map<String, dynamic>> _fetchFinishedProducts() async {
  //   try {
  //     if (userId == null) return {'count': 0};

  //     final querySnapshot = await FirebaseFirestore.instance
  //         .collection('finished_products')
  //         .where('userId', isEqualTo: userId)
  //         //.where('status', isEqualTo: 'pending')
  //         .get();

  //     // // حساب القيمة الإجمالية
  //     // double totalAmount = querySnapshot.docs.fold(0.0, (sTotal, doc) {
  //     //   final amount = doc.data()['totalAmountAfterTax'] ?? 0.0;
  //     //   return sTotal + (amount is num ? amount.toDouble() : 0.0);
  //     // });

  //     return {
  //       'count': querySnapshot.size,
  //      // 'totalAmount': totalAmount,
  //     };
  //   } catch (e) {
  //     debugPrint('❌ Error fetching PURCHASE_ORDERS: $e');
  //     return {'count': 0, 'totalAmount': 0.0};
  //   }
  // }



  Future<Map<String, dynamic>> _fetchPoStats() async {
    try {
      if (userId == null) return {'count': 0, 'totalAmount': 0.0};

      final querySnapshot = await FirebaseFirestore.instance
          .collection('purchase_orders')
          .where('userId', isEqualTo: userId)
          .where('status', isEqualTo: 'pending')
          .get();

      // حساب القيمة الإجمالية
      double totalAmount = querySnapshot.docs.fold(0.0, (sTotal, doc) {
        final amount = doc.data()['totalAmountAfterTax'] ?? 0.0;
        return sTotal + (amount is num ? amount.toDouble() : 0.0);
      });

      return {
        'count': querySnapshot.size,
        'totalAmount': totalAmount,
      };
    } catch (e) {
      debugPrint('❌ Error fetching PURCHASE_ORDERS: $e');
      return {'count': 0, 'totalAmount': 0.0};
    }
  }

  Future<int> _fetchFactoriesCount() async {
    try {
      if (userId == null) return 0;

      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();

      final factoryIds =
          (userDoc.data()?['factoryIds'] as List?)?.cast<String>() ?? [];

      if (factoryIds.isEmpty) return 0;

      final factories = await FirebaseFirestore.instance
          .collection('factories')
          .where(FieldPath.documentId, whereIn: factoryIds)
          .get();

      return factories.size;
    } catch (e) {
      debugPrint('❌ Error fetching factories: $e');
      return 0;
    }
  }

  Future<void> _syncUserData() async {
    final firebaseUser = FirebaseAuth.instance.currentUser;
    if (firebaseUser == null) return;

    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(firebaseUser.uid)
        .get();

    if (!userDoc.exists) return;

    final data = userDoc.data();
    if (data == null) return;

    final Timestamp? createdAtTimestamp = data['createdAt'];
    final createdAt = createdAtTimestamp?.toDate();
    final subscriptionDurationInDays = data['subscriptionDurationInDays'] ?? 30;
    final isActive = data['isActive'] ?? true;

    // جلب البيانات المحلية
    final localUser = await UserLocalStorage.getUser();

    bool needUpdateLocal = false;

    if (localUser == null) {
      needUpdateLocal = true;
    } else {
      final localCreatedAt = localUser['createdAt'] as DateTime?;
      final localSubscriptionDuration =
          localUser['subscriptionDurationInDays'] ?? 30;
      final localIsActive = localUser['isActive'] ?? true;

      if (localCreatedAt == null ||
          !isSameDate(localCreatedAt, createdAt) ||
          localSubscriptionDuration != subscriptionDurationInDays ||
          localIsActive != isActive) {
        needUpdateLocal = true;
      }
    }

    if (needUpdateLocal) {
      await UserLocalStorage.saveUser(
        userId: firebaseUser.uid,
        email: firebaseUser.email ?? '',
        displayName: firebaseUser.displayName,
        companyIds: (data['companyIds'] as List?)?.cast<String>() ?? [],
        factoryIds: (data['factoryIds'] as List?)?.cast<String>() ?? [],
        supplierIds: (data['supplierIds'] as List?)?.cast<String>() ?? [],
        createdAt: createdAt,
        subscriptionDurationInDays: subscriptionDurationInDays,
        isActive: isActive,
      );

      // حدث الحالة إذا الواجهة موجودة
      if (mounted) {
        setState(() {
          userName = firebaseUser.displayName;
          userId = firebaseUser.uid;
          userCompanyIds = (data['companyIds'] as List?)?.cast<String>() ?? [];
          // ... حدث بقية المتغيرات حسب الحاجة
        });
      }
    }
  }

  Future<void> _saveToLocalStorage() async {
    await UserLocalStorage.saveDashboardData(
      totalCompanies: _stats.totalCompanies,
      totalSuppliers: _stats.totalSuppliers,
      totalOrders: _stats.totalOrders,
      totalAmount: _stats.totalAmount,
    );

    await UserLocalStorage.saveExtendedStats(
      totalFactories: _stats.totalFactories,
      totalItems: _stats.totalItems,
      totalStockMovements: _stats.totalMovements,
      totalManufacturingOrders: _stats.totalManufacturingOrders,
      totalFinishedProducts: _stats.totalFinishedProducts,
    );
  }

  Future<void> _handleRefresh() async {
    try {
      await _syncUserData();
      await fetchStats();
      _refreshController.refreshCompleted();
    } catch (e) {
      debugPrint('❌ Refresh failed: $e');
      _refreshController.refreshFailed();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(tr('error_fetching_data'))),
        );
      }
    }
  }

  Widget _buildStatsGrid() {
    final statsMap = _stats.toMap();
    // final isWide = MediaQuery.of(context).size.width > 600;

    final filteredMetrics = _selectedCards.isEmpty
        ? dashboardMetrics.where((metric) =>
            metric.defaultMenuType ==
            (_dashboardView == DashboardView.long ? 'long' : 'short'))
        : dashboardMetrics
            .where((metric) => _selectedCards.contains(metric.titleKey));

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 300,
        mainAxisExtent: 135,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 1.6,
      ),
      itemCount: filteredMetrics.length,
      itemBuilder: (context, index) {
        final metric = filteredMetrics.elementAt(index);
        return DashboardTileWidget(
          metric: metric,
          data: statsMap,
          highlight: metric.titleKey == 'totalCompanies',
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: tr('dashboard'),
      userName: userName,
      isSubscriptionExpiringSoon:
          isSubscriptionExpiringSoon, // تمرير الحالة هنا
      isSubscriptionExpired: isSubscriptionExpired,
      isDashboard: true,
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : SmartRefresher(
              controller: _refreshController,
              onRefresh: _handleRefresh,
              enablePullDown: true,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tr('welcome_back', args: [userName ?? '']),
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 12),
                    _buildStatsGrid(),
                  ],
                ),
              ),
            ),
    );
  }
}

class DashboardStats {
  int totalCompanies;
  int totalSuppliers;
  int totalOrders;
  double totalAmount;
  int totalItems;
  int totalMovements;
  int totalManufacturingOrders;
  int totalFinishedProducts;
  int totalFactories;

  DashboardStats({
    required this.totalCompanies,
    required this.totalSuppliers,
    required this.totalOrders,
    required this.totalAmount,
    required this.totalItems,
    required this.totalMovements,
    required this.totalManufacturingOrders,
    required this.totalFinishedProducts,
    required this.totalFactories,
  });

  factory DashboardStats.empty() => DashboardStats(
        totalCompanies: 0,
        totalSuppliers: 0,
        totalOrders: 0,
        totalAmount: 0.0,
        totalItems: 0,
        totalMovements: 0,
        totalManufacturingOrders: 0,
        totalFinishedProducts: 0,
        totalFactories: 0,
      );

  void updateFrom(DashboardStats other) {
    totalCompanies = other.totalCompanies;
    totalSuppliers = other.totalSuppliers;
    totalOrders = other.totalOrders;
    totalAmount = other.totalAmount;
    totalItems = other.totalItems;
    totalMovements = other.totalMovements;
    totalManufacturingOrders = other.totalManufacturingOrders;
    totalFinishedProducts = other.totalFinishedProducts;
    totalFactories = other.totalFactories;
  }

  Map<String, dynamic> toMap() {
    return {
      'totalCompanies': totalCompanies,
      'totalSuppliers': totalSuppliers,
      'totalOrders': totalOrders,
      'totalAmount': totalAmount,
      'totalItems': totalItems,
      'totalStockMovements': totalMovements,
      'totalManufacturingOrders': totalManufacturingOrders,
      'totalFinishedProducts': totalFinishedProducts,
      'totalFactories': totalFactories,
    };
  }
}

