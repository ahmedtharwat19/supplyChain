/* import 'package:flutter/material.dart';
import '../companies/companies_page.dart';
import '../purchasing/purchase_orders_page.dart';
import '../suppliers/vendors_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _selectedIndex = 0;

  final List<Widget> _pages = [
    const CompaniesPage(),
    const VendorsPage(),
    const PurchaseOrdersPage(),
  ];

  final List<String> _titles = [
    'الشركات',
    'الموردين',
    'أوامر الشراء',
  ];

  void _onSelectPage(int index) {
    setState(() {
      _selectedIndex = index;
      Navigator.pop(context); // لغلق الـ Drawer بعد الاختيار
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_titles[_selectedIndex]),
        backgroundColor: Colors.green[700],
      ),
      drawer: Drawer(
        child: ListView(
          children: [
            const DrawerHeader(
              decoration: BoxDecoration(color: Colors.green),
              child: Text(
                'قائمة التنقل',
                style: TextStyle(color: Colors.white, fontSize: 24),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.business),
              title: const Text('الشركات'),
              onTap: () => _onSelectPage(0),
            ),
            ListTile(
              leading: const Icon(Icons.people),
              title: const Text('الموردين'),
              onTap: () => _onSelectPage(1),
            ),
            ListTile(
              leading: const Icon(Icons.shopping_cart),
              title: const Text('أوامر الشراء'),
              onTap: () => _onSelectPage(2),
            ),
          ],
        ),
      ),
      body: _pages[_selectedIndex],
    );
  }
}
 */