
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';
import '../../utils/user_local_storage.dart';
import '../../widgets/app_scaffold.dart';

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
      debugPrint('🔍 Fetching companies for userId = $userId');
      final companiesSnapshot = await FirebaseFirestore.instance
          .collection('companies')
          .where('user_id', isEqualTo: userId)
          .get();
      totalCompanies = companiesSnapshot.size;
      debugPrint('✅ Found ${companiesSnapshot.size} companies');

      List<Future<void>> futures = [];

      int supplierCount = 0;
      int orderCount = 0;
      double amountSum = 0.0;
      int itemCount = 0;
      int movementCount = 0;
      int manufacturingCount = 0;
      int finishedProductCount = 0;
      int factoryCount = 0;

      for (var company in companiesSnapshot.docs) {
        final companyId = company.id;
        debugPrint('🔹 Processing company $companyId');

        futures.add(Future(() async {
          final firestore = FirebaseFirestore.instance;

          try {
            final results = await Future.wait([
              firestore
                  .collection('companies/$companyId/purchase_orders')
                  .where('user_id', isEqualTo: userId)
                  .get(),
              firestore
                  .collection('companies/$companyId/items')
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
            debugPrint('🧾 purchase_orders: ${ordersSnap.size}');

            for (var doc in ordersSnap.docs) {
              final data = doc.data();
              if (data['totalAmount'] != null) {
                amountSum += (data['totalAmount'] as num).toDouble();
              }
            }

            itemCount += results[1].size;
            debugPrint('📦 items: ${results[1].size}');
            movementCount += results[2].size;
            debugPrint('🔄 stock_movements: ${results[2].size}');
            manufacturingCount += results[3].size;
            debugPrint('🏭 manufacturing_orders: ${results[3].size}');
            finishedProductCount += results[4].size;
            debugPrint('✅ finished_products: ${results[4].size}');
            factoryCount += results[5].size;
            debugPrint('🏢 factories: ${results[5].size}');
          } catch (e) {
            debugPrint(
                '❌ Error fetching subcollections for company $companyId: $e');
          }
        }));
      }

      final suppliersSnap = await FirebaseFirestore.instance
          .collection('vendors')
          .where('user_id', isEqualTo: userId)
          .get();
      supplierCount = suppliersSnap.size;
      debugPrint('🤝 vendors: $supplierCount');

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

      debugPrint('✅ Dashboard stats loaded successfully');

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
                            children: [
                              _buildDashboardTile(
                                  title: tr('total_companies'),
                                  value: '$totalCompanies',
                                  icon: Icons.business,
                                  color: Colors.blue,
                                  onTap: () => context.go('/companies'),
                                  progress: totalCompanies / 100),
                              _buildDashboardTile(
                                  title: tr('total_suppliers'),
                                  value: '$totalSuppliers',
                                  icon: Icons.group,
                                  color: Colors.orange,
                                  onTap: () => context.go('/suppliers'),
                                  progress: totalSuppliers / 100),
                              _buildDashboardTile(
                                  title: tr('purchase_orders'),
                                  value: '$totalOrders',
                                  icon: Icons.receipt_long,
                                  color: Colors.green,
                                  onTap: () => context.go('/purchase-orders'),
                                  progress: totalOrders / 100),
                              _buildDashboardTile(
                                  title: tr('total_amount'),
                                  value:
                                      '${totalAmount.toStringAsFixed(2)} ${tr('eg_pound')}',
                                  icon: Icons.attach_money,
                                  color: Colors.teal,
                                  onTap: () => context.go('/purchase-orders'),
                                  progress:
                                      (totalAmount / 100000).clamp(0.05, 1)),
                              _buildDashboardTile(
                                  title: tr('total_items'),
                                  value: '$totalItems',
                                  icon: Icons.inventory_2,
                                  color: Colors.purple,
                                  onTap: () => context.go('/items'),
                                  progress: totalItems / 100),
                              _buildDashboardTile(
                                  title: tr('stock_movements'),
                                  value: '$totalMovements',
                                  icon: Icons.swap_horiz,
                                  color: Colors.cyan,
                                  onTap: () => context.go('/stock-movements'),
                                  progress: totalMovements / 100),
                              _buildDashboardTile(
                                  title: tr('manufacturing_orders'),
                                  value: '$totalManufacturingOrders',
                                  icon: Icons.precision_manufacturing,
                                  color: Colors.brown,
                                  onTap: () =>
                                      context.go('/manufacturing-orders'),
                                  progress: totalManufacturingOrders / 100),
                              _buildDashboardTile(
                                  title: tr('finished_products'),
                                  value: '$totalFinishedProducts',
                                  icon: Icons.done_all,
                                  color: Colors.deepOrange,
                                  onTap: () => context.go('/finished-products'),
                                  progress: totalFinishedProducts / 100),
                              _buildDashboardTile(
                                  title: tr('factories'),
                                  value: '$totalFactories',
                                  icon: Icons.factory,
                                  color: Colors.indigo,
                                  onTap: () => context.go('/factories'),
                                  progress: totalFactories / 100),
                            ],
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

  Widget _buildDashboardTile({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
    double progress = 0,
  }) {
    return InkWell(
      onTap: onTap,
      child: Card(
        elevation: 3,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 36, color: color),
              const SizedBox(height: 12),
              Text(
                value,
                style: TextStyle(
                    fontSize: 22, fontWeight: FontWeight.bold, color: color),
              ),
              const SizedBox(height: 4),
              Text(title, style: const TextStyle(fontSize: 16)),
              const SizedBox(height: 8),
              LinearProgressIndicator(
                value: progress.clamp(0.0, 1.0),
                backgroundColor: Colors.grey[200],
                color: color,
                minHeight: 6,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
