/* import 'package:easy_localization/easy_localization.dart';
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

    // تحميل القيم المحفوظة مؤقتًا لعرضها مبدئيًا
    final cached = await UserLocalStorage.getDashboardData();
    setState(() {
      totalCompanies = cached['totalCompanies'] ?? 0;
      totalSuppliers = cached['totalSuppliers'] ?? 0;
      totalOrders = cached['totalOrders'] ?? 0;
      totalAmount = cached['totalAmount'] ?? 0.0;
      isLoading = false;
    });

    // تحميل القيم الحقيقية من Firestore
    fetchStats();
  }

  Future<void> fetchStats() async {
    if (userId == null) return;
    setState(() => isLoading = true);

    final companiesSnapshot = await FirebaseFirestore.instance
        .collection('companies')
        .where('user_id', isEqualTo: userId)
        .get();
    final int companyCount = companiesSnapshot.size;

    int supplierCount = 0;
    int orderCount = 0;
    double amountSum = 0.0;

    for (var company in companiesSnapshot.docs) {
      final companyId = company.id;

      final ordersSnap = await FirebaseFirestore.instance
          .collection('companies/$companyId/purchase_orders')
          .where('user_id', isEqualTo: userId)
          .get();

      orderCount += ordersSnap.size;
      for (var doc in ordersSnap.docs) {
        final data = doc.data();
        if (data['totalAmount'] != null) {
          amountSum += (data['totalAmount'] as num).toDouble();
        }
      }
    }

    final suppliersSnap = await FirebaseFirestore.instance
        .collection('vendors')
        .where('user_id', isEqualTo: userId)
        .get();
    supplierCount = suppliersSnap.size;

    setState(() {
      totalCompanies = companyCount;
      totalSuppliers = supplierCount;
      totalOrders = orderCount;
      totalAmount = amountSum;
      isLoading = false;
    });

    // حفظ الإحصائيات محليًا
    await UserLocalStorage.saveDashboardData(
      totalCompanies: companyCount,
      totalSuppliers: supplierCount,
      totalOrders: orderCount,
      totalAmount: amountSum,
    );
  }

  Widget buildTile({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
    double progress = 0.5,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Card(
        elevation: 3,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color, size: 34),
              const SizedBox(height: 8),
              Text(title,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 15)),
              const SizedBox(height: 6),
              Text(value,
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.w600)),
              const SizedBox(height: 10),
              LinearProgressIndicator(
                value: progress.clamp(0.05, 1.0),
                backgroundColor: Colors.grey[200],
                color: color,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavTile(
      BuildContext context, IconData icon, String title, String route) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      trailing: const Icon(Icons.arrow_forward_ios),
      onTap: () => context.go(route),
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
                physics: const AlwaysScrollableScrollPhysics(),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      LayoutBuilder(builder: (context, constraints) {
                        int crossAxisCount = constraints.maxWidth > 600 ? 4 : 2;
                        return GridView.count(
                          crossAxisCount: crossAxisCount,
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          mainAxisSpacing: 12,
                          crossAxisSpacing: 12,
                          children: [
                            buildTile(
                              title: tr('total_companies'),
                              value: '$totalCompanies',
                              icon: Icons.business,
                              color: Colors.blue,
                              onTap: () => context.go('/companies'),
                              progress: totalCompanies / 100,
                            ),
                            buildTile(
                              title: tr('total_suppliers'),
                              value: '$totalSuppliers',
                              icon: Icons.group,
                              color: Colors.orange,
                              onTap: () => context.go('/suppliers'),
                              progress: totalSuppliers / 100,
                            ),
                            buildTile(
                              title: tr('purchase_orders'),
                              value: '$totalOrders',
                              icon: Icons.receipt_long,
                              color: Colors.green,
                              onTap: () => context.go('/purchase-orders'),
                              progress: totalOrders / 100,
                            ),
                            buildTile(
                              title: tr('total_amount'),
                              value:
                                  '${totalAmount.toStringAsFixed(2)} ${tr('eg_pound')}',
                              icon: Icons.attach_money,
                              color: Colors.teal,
                              onTap: () => context.go('/purchase-orders'),
                              progress: totalAmount / 100000,
                            ),
                          ],
                        );
                      }),
                      const SizedBox(height: 20),
                      const Divider(),
                      _buildNavTile(context, Icons.business,
                          tr('manage_companies'), '/companies'),
                      _buildNavTile(context, Icons.group,
                          tr('manage_suppliers'), '/suppliers'),
                      _buildNavTile(context, Icons.category,
                          tr('manage_items'), '/items'),
                      _buildNavTile(context, Icons.shopping_cart,
                          tr('view_purchase_orders'), '/purchase-orders'),
                    ],
                  ),
                ),
              ),
            ),
    );
  }
}
 */