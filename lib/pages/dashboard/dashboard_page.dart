import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../../utils/user_local_storage.dart';
import '../../widgets/app_scaffold.dart'; // مسار app_scaffold.dart الصحيح

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

  @override
  void initState() {
    super.initState();
    loadUserName();
    fetchStats();
  }

  Future<void> loadUserName() async {
    final user = await UserLocalStorage.getUser();
    final email = user?['email'] ?? '';
    String name = user?['displayName'] ?? '';

    if (name.isEmpty && email.contains('@')) {
      name = email.split('@')[0];
    }

    if (!mounted) return;
    setState(() {
      userName = name;
    });
  }

  Future<void> fetchStats() async {
    setState(() => isLoading = true);

    final companiesSnapshot = await FirebaseFirestore.instance.collection('companies').get();
    totalCompanies = companiesSnapshot.size;

    int supplierCount = 0;
    int orderCount = 0;
    double amountSum = 0.0;

    for (var company in companiesSnapshot.docs) {
      final companyId = company.id;

      final ordersSnap = await FirebaseFirestore.instance
          .collection('companies/$companyId/purchase_orders')
          .get();

      orderCount += ordersSnap.size;
      for (var doc in ordersSnap.docs) {
        final data = doc.data();
        if (data['totalAmount'] != null) {
          amountSum += (data['totalAmount'] as num).toDouble();
        }
      }
    }

    final suppliersSnap = await FirebaseFirestore.instance.collection('vendors').get();
    supplierCount = suppliersSnap.size;

    if (!mounted) return;
    setState(() {
      totalSuppliers = supplierCount;
      totalOrders = orderCount;
      totalAmount = amountSum;
      isLoading = false;
    });
  }

  Widget buildTile(String title, String value, IconData icon, Color color) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: Icon(icon, color: color, size: 30),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(
          value,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'PureSip Dashboard',
      userName: userName,
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: fetchStats,
              child: ListView(
                padding: const EdgeInsets.all(12),
                children: [
                  buildTile('Total Companies', '$totalCompanies', Icons.business, Colors.blue),
                  buildTile('Total Suppliers', '$totalSuppliers', Icons.group, Colors.orange),
                  buildTile('Purchase Orders', '$totalOrders', Icons.receipt, Colors.green),
                  buildTile('Total Amount', '${totalAmount.toStringAsFixed(2)} L.E', Icons.attach_money, Colors.teal),
                  const SizedBox(height: 20),
                  const Divider(),
                  ListTile(
                    leading: const Icon(Icons.business),
                    title: const Text('Manage Companies'),
                    trailing: const Icon(Icons.arrow_forward_ios),
                    onTap: () => context.go('/companies'),
                  ),
                  ListTile(
                    leading: const Icon(Icons.group),
                    title: const Text('Manage Suppliers'),
                    trailing: const Icon(Icons.arrow_forward_ios),
                    onTap: () => context.go('/suppliers'),
                  ),
                  ListTile(
                    leading: const Icon(Icons.category),
                    title: const Text('Manage Items'),
                    trailing: const Icon(Icons.arrow_forward_ios),
                    onTap: () => context.go('/items'),
                  ),
                  ListTile(
                    leading: const Icon(Icons.shopping_cart),
                    title: const Text('View Purchase Orders'),
                    trailing: const Icon(Icons.arrow_forward_ios),
                    onTap: () => context.go('/purchase-orders'),
                  ),
                ],
              ),
            ),
    );
  }
}
