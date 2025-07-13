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
  bool isLoading = true;
  String? userName;
  String? userId;

  @override
  void initState() {
    super.initState();
    loadUser();
  }

  Future<void> loadUser() async {
    final user = await UserLocalStorage.getUser();
    final email = user?['email'] ?? '';
    String name = user?['displayName'] ?? '';
    final uid = user?['userId'];

    if (name.isEmpty && email.contains('@')) {
      name = email.split('@')[0];
    }

    if (!mounted) return;
    setState(() {
      userName = name;
      userId = uid;
      debugPrint('User loaded: $name, $uid,$email');
    });

    fetchStats();
  }

  Future<void> fetchStats() async {
    if (userId == null) return;
    setState(() => isLoading = true);
    debugPrint('Fetching stats...');

    final companiesSnapshot = await FirebaseFirestore.instance
        .collection('companies')
        .where('user_id', isEqualTo: userId)
        .get();
    totalCompanies = companiesSnapshot.size;

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

    if (!mounted) return;
    setState(() {
      totalSuppliers = supplierCount;
      totalOrders = orderCount;
      totalAmount = amountSum;
      isLoading = false;
    });
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
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color, size: 36),
              const SizedBox(height: 10),
              Text(
                title,
                style:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 6),
              Text(
                value,
                style: const TextStyle(
                    fontSize: 18, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 12),
              LinearProgressIndicator(
                value: progress,
                backgroundColor: Colors.grey.shade200,
                color: color,
              ),
            ],
          ),
        ),
      ),
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
                  child:  Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        GridView.count(
                          crossAxisCount: 2,
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
                              icon: Icons.receipt,
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
                              progress: totalAmount > 0
                                  ? (totalAmount / 100000)
                                  : 0.05,
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        const Divider(),
                        _buildNavTile(context, Icons.business,
                            'manage_companies'.tr(), '/companies'),
                        _buildNavTile(context, Icons.group,
                            'manage_suppliers'.tr(), '/suppliers'),
                        _buildNavTile(context, Icons.category,
                            'manage_items'.tr(), '/items'),
                        _buildNavTile(context, Icons.shopping_cart,
                            'view_purchase_orders'.tr(), '/purchase-orders'),
                      ],
                    ),
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
}
