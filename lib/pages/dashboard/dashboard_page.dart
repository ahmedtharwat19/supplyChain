import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:puresip_purchasing/pages/dashboard/dashboard_metrics.dart';
import 'package:puresip_purchasing/pages/dashboard/dashboard_tile_widget.dart';
import 'package:puresip_purchasing/pages/settings_page.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../utils/user_local_storage.dart';
import '../../widgets/app_scaffold.dart';
import 'package:pull_to_refresh/pull_to_refresh.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => DashboardPageState();
}

enum DashboardView { short, long }

class DashboardPageState extends State<DashboardPage> {
  final RefreshController _refreshController =
      RefreshController(initialRefresh: false);
// في _DashboardPageState أضف المتغيرات التالية:
  DashboardView _dashboardView = DashboardView.short;
  Set<String> _selectedCards = {};

  bool isLoading = true;
  double totalAmount = 0.0;
  int totalCompanies = 0;
  int totalFactories = 0;
  int totalFinishedProducts = 0;
  int totalItems = 0;
  int totalManufacturingOrders = 0;
  int totalMovements = 0;
  int totalOrders = 0;
  int totalSuppliers = 0;
  String? userId;
  String? userName;
  List<String> userCompanyIds = [];

  @override
  void initState() {
    super.initState();
    _loadInitialData();
    loadSettings();
  }

  @override
  void dispose() {
    _refreshController.dispose();
    super.dispose();
  }

  Future<void> loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final viewString = prefs.getString(prefDashboardView) ?? 'short';
    final selectedCards = prefs.getStringList(prefSelectedCards) ?? [];

    if (!mounted) return;

    setState(() {
      _dashboardView =
          viewString == 'long' ? DashboardView.long : DashboardView.short;
      _selectedCards = selectedCards.toSet();
    });
  }

  Future<void> _loadInitialData() async {
    final user = await UserLocalStorage.getUser();
    if (user == null || !mounted) return;
    debugPrint('local user from dashboard $user');
    setState(() {
      userName = user['displayName'];
      userId = user['userId'];
      userCompanyIds = (user['companyIds'] as List?)?.cast<String>() ?? [];
      totalCompanies =
          userCompanyIds.length; // Set early for better UI responsiveness
    });

    await _loadCachedData();
    await fetchStats();
  }

  Future<void> _loadCachedData() async {
    final cached = await UserLocalStorage.getDashboardData();
    final extended = await UserLocalStorage.getExtendedStats();

    if (!mounted) return;

    setState(() {
      // We keep totalCompanies from userCompanyIds length for consistency
      totalSuppliers = cached['totalSuppliers'] ?? 0;
      totalOrders = cached['totalOrders'] ?? 0;
      totalAmount = cached['totalAmount'] ?? 0.0;
      totalItems = cached['totalItems'] ?? 0;
      totalMovements = extended['totalStockMovements'] ?? 0;
      totalManufacturingOrders = extended['totalManufacturingOrders'] ?? 0;
      totalFinishedProducts = extended['totalFinishedProducts'] ?? 0;
      totalFactories = extended['totalFactories'] ?? 0;
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

      final updatedCompanyIds =
          (userDoc.data()?['companyIds'] as List?)?.cast<String>() ?? [];

      // Using Future.wait to parallel fetch counts
      final results = await Future.wait([
        _fetchCollectionCount('items'),
        _fetchCollectionCount('vendors'),
      ]);

      if (!mounted) return;

      setState(() {
        userCompanyIds = updatedCompanyIds;
        totalCompanies = updatedCompanyIds.length;
        totalItems = results[0];
        totalSuppliers = results[1];
      });

      if (updatedCompanyIds.isNotEmpty) {
        await _fetchAdditionalData(updatedCompanyIds);
      }

      await _saveToLocalStorage();
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

  // Fetch collection count using Firestore count() aggregation if available,
  // fallback to current method if not supported (Firestore recent feature).
  Future<int> _fetchCollectionCount(String collection) async {
    try {
      if (userId == null) return 0;
      // You can replace below with count() aggregation when available:
      final snapshot = await FirebaseFirestore.instance
          .collection(collection)
          .where('user_id', isEqualTo: userId)
          .get();
      return snapshot.size;
    } catch (e) {
      debugPrint('❌ Error fetching $collection: $e');
      return 0;
    }
  }

  Future<void> _fetchAdditionalData(List<String> companyIds) async {
    try {
      int orderCount = 0;
      double amountSum = 0.0;
      int movementCount = 0;
      int manufacturingCount = 0;
      int finishedProductCount = 0;
      int factoryCount = 0;

      final results = await Future.wait(
        companyIds.map((companyId) => _getCompanyStats(companyId)),
      );

      for (final result in results) {
        orderCount += (result['orders'] as num).toInt();
        amountSum += (result['amount'] as num).toDouble();
        movementCount += (result['movements'] as num).toInt();
        manufacturingCount += (result['manufacturing'] as num).toInt();
        finishedProductCount += (result['finishedProducts'] as num).toInt();
        factoryCount += (result['factories'] as num).toInt();
      }

      if (mounted) {
        setState(() {
          totalOrders = orderCount;
          totalAmount = amountSum;
          totalMovements = movementCount;
          totalManufacturingOrders = manufacturingCount;
          totalFinishedProducts = finishedProductCount;
          totalFactories = factoryCount;
        });
      }
    } catch (e) {
      debugPrint('❌ Error in _fetchAdditionalData: $e');
    }
  }

  Future<Map<String, dynamic>> _getCompanyStats(String companyId) async {
    try {
      final results = await Future.wait([
        _getSubCollectionCount('purchase_orders', companyId),
        _getSubCollectionCount('stock_movements', companyId),
        _getSubCollectionCount('manufacturing_orders', companyId),
        _getSubCollectionCount('finished_products', companyId),
        _getSubCollectionCount('factories', companyId),
      ]);

      return {
        'orders': results[0]['count'],
        'amount': results[0]['amount'],
        'movements': results[1]['count'],
        'manufacturing': results[2]['count'],
        'finishedProducts': results[3]['count'],
        'factories': results[4]['count'],
      };
    } catch (e) {
      debugPrint('❌ Error getting stats for company $companyId: $e');
      return {
        'orders': 0,
        'amount': 0.0,
        'movements': 0,
        'manufacturing': 0,
        'finishedProducts': 0,
        'factories': 0,
      };
    }
  }

  Future<Map<String, dynamic>> _getSubCollectionCount(
      String collection, String companyId) async {
    try {
      if (userId == null) return {'count': 0, 'amount': 0.0};

      final snapshot = await FirebaseFirestore.instance
          .collection('companies/$companyId/$collection')
          .where('user_id', isEqualTo: userId)
          .get();

      double amount = 0.0;
      if (collection == 'purchase_orders') {
        amount = snapshot.docs.fold(0.0, (total, doc) {
          final val = doc.data()['totalAmount'];
          return total + ((val is num) ? val.toDouble() : 0.0);
        });
      }

      return {
        'count': snapshot.size,
        'amount': amount,
      };
    } catch (e) {
      debugPrint('❌ Error fetching $collection: $e');
      return {'count': 0, 'amount': 0.0};
    }
  }

  Future<void> _saveToLocalStorage() async {
    await UserLocalStorage.saveDashboardData(
      totalCompanies: totalCompanies,
      totalSuppliers: totalSuppliers,
      totalOrders: totalOrders,
      totalAmount: totalAmount,
    );

    await UserLocalStorage.saveExtendedStats(
      totalFactories: totalFactories,
      totalItems: totalItems,
      totalStockMovements: totalMovements,
      totalManufacturingOrders: totalManufacturingOrders,
      totalFinishedProducts: totalFinishedProducts,
    );
  }

  Future<void> _handleRefresh() async {
    try {
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
    final stats = {
      'totalCompanies': userCompanyIds.length,
      'totalSuppliers': totalSuppliers,
      'totalOrders': totalOrders,
      'totalAmount': totalAmount,
      'totalItems': totalItems,
      'totalStockMovements': totalMovements,
      'totalManufacturingOrders': totalManufacturingOrders,
      'totalFinishedProducts': totalFinishedProducts,
      'totalFactories': totalFactories,
    };

    final isWide = MediaQuery.of(context).size.width > 600;

    // إذا لم يحدد المستخدم أي بطاقة، عرض الكل
    final filteredMetrics = _selectedCards.isEmpty
        ? dashboardMetrics
        : dashboardMetrics
            .where((metric) => _selectedCards.contains(metric.titleKey))
            .toList();
    // ✅ تغيير عرض الشبكة حسب نوع العرض
    int crossAxisCount;
    double aspectRatio;

    if (_dashboardView == DashboardView.short) {
      crossAxisCount = isWide ? 3 : 2;
      aspectRatio = isWide ? 1.8 : 1.4;
    } else {
      crossAxisCount = isWide ? 2 : 1;
      aspectRatio = isWide ? 2.5 : 2;
    }

return GridView.builder(
  shrinkWrap: true,
  physics: const NeverScrollableScrollPhysics(),
  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
    maxCrossAxisExtent: 300, // أقصى عرض لكل بطاقة
    mainAxisExtent: 135, // 👈 مهم جداً لضبط الارتفاع
    mainAxisSpacing: 12,
    crossAxisSpacing: 12,
    childAspectRatio: 1.6,
  ),
  itemCount: filteredMetrics.length,
  itemBuilder: (context, index) {
    final metric = filteredMetrics[index];
    return DashboardTileWidget(
      metric: metric,
      data: stats,
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
