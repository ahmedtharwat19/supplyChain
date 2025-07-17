import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
//import 'package:go_router/go_router.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:puresip_purchasing/pages/dashboard/dashboard_metrics.dart';
import 'package:puresip_purchasing/pages/dashboard/dashboard_tile_widget.dart';

import '../../utils/user_local_storage.dart';
import '../../widgets/app_scaffold.dart';
// import 'dashboard_metrics.dart';
// import 'dashboard_tile_widget.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  int totalCompanies = 0;
  int totalSuppliers = 0;
  int totalOrders = 0;
  double totalAmount = 0.0;
  int totalItems = 0;
  int totalMovements = 0;
  int totalManufacturingOrders = 0;
  int totalFinishedProducts = 0;
  int totalFactories = 0;
  bool isLoading = true;
  String? userName;
  String? userId;

  @override
  void initState() {
    super.initState();
    loadUserAndCachedData();
  }

  Future<void> loadUserAndCachedData() async {
    final user = await UserLocalStorage.getUser();
    if (user == null) return;

    userName = user['displayName'];
    userId = user['userId'];

    final cached = await UserLocalStorage.getDashboardData();
    final extended = await UserLocalStorage.getExtendedStats();
    setState(() {
      totalCompanies = cached['totalCompanies'] ?? 0;
      totalSuppliers = cached['totalSuppliers'] ?? 0;
      totalOrders = cached['totalOrders'] ?? 0;
      totalAmount = cached['totalAmount'] ?? 0.0;
      totalItems = extended['totalItems'] ?? 0;
      totalMovements = extended['totalStockMovements'] ?? 0;
      totalManufacturingOrders = extended['totalManufacturingOrders'] ?? 0;
      totalFinishedProducts = extended['totalFinishedProducts'] ?? 0;
      totalFactories = extended['totalFactories'] ?? 0;
      isLoading = false;
    });

    fetchStats();
  }

  Future<void> fetchStats() async {
    if (userId == null) return;
    setState(() => isLoading = true);

    try {
      final companiesSnapshot = await FirebaseFirestore.instance
          .collection('companies')
          .where('user_id', isEqualTo: userId)
          .get();
      totalCompanies = companiesSnapshot.size;

      List<Future<void>> futures = [];

      int supplierCount = 0;
      int orderCount = 0;
      double amountSum = 0.0;
      int itemCount = 0;
      int movementCount = 0;
      int manufacturingCount = 0;
      int finishedProductCount = 0;
      int factoryCount = 0;

      debugPrint('$userId userId');

      final itemsSnapshot = await FirebaseFirestore.instance
          .collection('items')
          .where('user_id', isEqualTo: userId)
          .get();

      itemCount += itemsSnapshot.size;
      for (var company in companiesSnapshot.docs) {
        final companyId = company.id;

        futures.add(Future(() async {
          try {
            final firestore = FirebaseFirestore.instance;

            final results = await Future.wait([
              firestore
                  .collection('companies/$companyId/purchase_orders')
                  .where('user_id', isEqualTo: userId)
                  .get(),
              firestore
                  .collection('companies/$companyId/stock_movements')
                  .where('user_id', isEqualTo: userId)
                  .get(),
              firestore
                  .collection('companies/$companyId/manufacturing_orders')
                  .where('user_id', isEqualTo: userId)
                  .get(),
              firestore
                  .collection('companies/$companyId/finished_products')
                  .where('user_id', isEqualTo: userId)
                  .get(),
              firestore
                  .collection('companies/$companyId/factories')
                  .where('user_id', isEqualTo: userId)
                  .get(),
            ]);

            final ordersSnap = results[0];
            orderCount += ordersSnap.size;

            for (var doc in ordersSnap.docs) {
              final data = doc.data();
              if (data['totalAmount'] != null) {
                amountSum += (data['totalAmount'] as num).toDouble();
              }
            }

            movementCount += results[1].size;
            manufacturingCount += results[2].size;
            finishedProductCount += results[3].size;
            factoryCount += results[4].size;
          } catch (e) {
            debugPrint('Error fetching company $companyId data: $e');
          }
        }));
      }

      final suppliersSnap = await FirebaseFirestore.instance
          .collection('vendors')
          .where('user_id', isEqualTo: userId)
          .get();
      supplierCount = suppliersSnap.size;

      await Future.wait(futures);

      if (!mounted) return;

      setState(() {
        totalSuppliers = supplierCount;
        totalOrders = orderCount;
        totalAmount = amountSum;
        totalItems = itemCount;
        totalMovements = movementCount;
        totalManufacturingOrders = manufacturingCount;
        totalFinishedProducts = finishedProductCount;
        totalFactories = factoryCount;
        isLoading = false;
      });

      await UserLocalStorage.saveDashboardData(
        totalCompanies: totalCompanies,
        totalSuppliers: supplierCount,
        totalOrders: orderCount,
        totalAmount: amountSum,
      );

      await UserLocalStorage.saveExtendedStats(
        totalFactories: factoryCount,
        totalItems: itemCount,
        totalStockMovements: movementCount,
        totalManufacturingOrders: manufacturingCount,
        totalFinishedProducts: finishedProductCount,
      );
    } catch (e) {
      debugPrint('❌ Error in fetchStats: $e');
      setState(() => isLoading = false);
    }
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
                physics: const AlwaysScrollableScrollPhysics(),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(tr('welcome_back', args: [userName ?? ''])),
                      const SizedBox(height: 12),
                      LayoutBuilder(
                        builder: (context, constraints) {
                          int crossAxisCount = constraints.maxWidth >= 900
                              ? 4
                              : constraints.maxWidth >= 600
                                  ? 3
                                  : 2;
                          return GridView.count(
                            crossAxisCount: crossAxisCount,
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            crossAxisSpacing: 12,
                            mainAxisSpacing: 12,
                            children: _buildDashboardTiles(),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
    );
  }

  List<Widget> _buildDashboardTiles() {
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

    return dashboardMetrics
        .map((metric) => DashboardTileWidget(metric: metric, data: stats))
        .toList();
  }
}
