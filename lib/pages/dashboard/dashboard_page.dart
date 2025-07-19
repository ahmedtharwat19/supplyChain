import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:puresip_purchasing/pages/dashboard/dashboard_metrics.dart';
import 'package:puresip_purchasing/pages/dashboard/dashboard_tile_widget.dart';
import '../../utils/user_local_storage.dart';
import '../../widgets/app_scaffold.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
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

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    final user = await UserLocalStorage.getUser();
    if (user == null || !mounted) return;

    setState(() {
      userName = user['displayName'];
      userId = user['userId'];
    });

    await _loadCachedData();
    await fetchStats();
  }

  Future<void> _loadCachedData() async {
    final cached = await UserLocalStorage.getDashboardData();
    final extended = await UserLocalStorage.getExtendedStats();

    if (!mounted) return;

    setState(() {
      totalCompanies = cached['totalCompanies'] ?? 0;
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
    if (userId == null || !mounted) {
      debugPrint('❌ fetchStats aborted: userId is null or widget not mounted');
      return;
    }

    setState(() => isLoading = true);

    try {
      // Fetch basic data in parallel
      final results = await Future.wait([
        _fetchCollectionCount('companies'),
        _fetchCollectionCount('items'),
        _fetchCollectionCount('vendors'),
      ]);

      if (mounted) {
        setState(() {
          totalCompanies = results[0];
          totalItems = results[1];
          totalSuppliers = results[2];
        });
      }

      // Fetch additional data if companies exist
      if (totalCompanies > 0) {
        await _fetchAdditionalData();
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

  Future<int> _fetchCollectionCount(String collection) async {
    try {
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

  Future<void> _fetchAdditionalData() async {
    try {
      final companiesSnapshot = await FirebaseFirestore.instance
          .collection('companies')
          .where('user_id', isEqualTo: userId)
          .get();

      int orderCount = 0;
      double amountSum = 0.0;
      int movementCount = 0;
      int manufacturingCount = 0;
      int finishedProductCount = 0;
      int factoryCount = 0;

      for (var company in companiesSnapshot.docs) {
        final companyId = company.id;
        
        final results = await Future.wait([
          _getSubCollectionCount('purchase_orders', companyId),
          _getSubCollectionCount('stock_movements', companyId),
          _getSubCollectionCount('manufacturing_orders', companyId),
          _getSubCollectionCount('finished_products', companyId),
          _getSubCollectionCount('factories', companyId),
        ]);

        orderCount += (results[0]['count'] as num).toInt();
        amountSum += (results[0]['amount'] as num).toDouble();
        movementCount += (results[1]['count'] as num).toInt();
        manufacturingCount += (results[2]['count'] as num).toInt();
        finishedProductCount += (results[3]['count'] as num).toInt();
        factoryCount += (results[4]['count'] as num).toInt();
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

  Future<Map<String, dynamic>> _getSubCollectionCount(String collection, String companyId) async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('companies/$companyId/$collection')
          .where('user_id', isEqualTo: userId)
          .get();

      double amount = 0;
      if (collection == 'purchase_orders') {
        amount = snapshot.docs.fold(0, (total, doc) {
          return total + ((doc.data()['totalAmount'] as num?)?.toDouble() ?? 0);
        });
      }

      return {
        'count': snapshot.size,
        'amount': amount,
      };
    } catch (e) {
      debugPrint('❌ Error fetching $collection: $e');
      return {'count': 0, 'amount': 0};
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

  Widget _buildStatsGrid() {
    final stats = {
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

    return GridView.count(
      crossAxisCount: MediaQuery.of(context).size.width > 600 ? 3 : 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 1.5,
      children: dashboardMetrics.map((metric) {
        return DashboardTileWidget(
          metric: metric,
          data: stats,
          highlight: metric.titleKey == 'totalCompanies' && totalCompanies == 0,
        );
      }).toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: tr('dashboard_title'),
      userName: userName,
      isDashboard: true,
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: fetchStats,
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(tr('welcome_back', args: [userName ?? ''])),
                      const SizedBox(height: 20),
                      _buildStatsGrid(),
                      if (totalCompanies == 0 && !isLoading)
                        Padding(
                          padding: const EdgeInsets.only(top: 20),
                          child: Text(
                            tr('no_companies_found'),
                            style: const TextStyle(
                              color: Colors.red,
                              fontSize: 16,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
    );
  }
}