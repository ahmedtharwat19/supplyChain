/* import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:printing/printing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../utils/pdf_exporter.dart';
import '../../widgets/app_scaffold.dart';
import 'widgets/filter_bar.dart';
import 'widgets/purchase_order_card.dart';

class PurchaseOrdersPage extends StatefulWidget {
  const PurchaseOrdersPage({super.key});

  @override
  State<PurchaseOrdersPage> createState() => _PurchaseOrdersPageState();
}

class _PurchaseOrdersPageState extends State<PurchaseOrdersPage> {
  String? _userId;

  List<Map<String, dynamic>> allCompanies = [];
  List<String> allSuppliers = [];
  List<String> allItems = [];
  List<Map<String, dynamic>> allFactories = [];

  String? selectedCompanyFilter;
  String? selectedSupplierFilter;
  String? selectedItemFilter;
  List<String> selectedFactories = [];

  DateTime? startDate;
  DateTime? endDate;

  @override
  void initState() {
    super.initState();
    // _loadUserId();
    _loadUserId().then((_) => _verifyUserAccess());
    _loadFilterOptions();
  }

  Future<void> _loadUserId() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString('userId');
    if (userId == null) return;

    final userDoc =
        await FirebaseFirestore.instance.collection('users').doc(userId).get();
    final userCompanyIds =
        (userDoc.data()?['companyIds'] as List?)?.cast<String>() ?? [];

    setState(() {
      _userId = userId;
      // Set the first company as default if none selected
      if (selectedCompanyFilter == null && userCompanyIds.isNotEmpty) {
        selectedCompanyFilter = userCompanyIds.first;
      }
    });

    debugPrint('User $_userId has access to companies: $userCompanyIds'); // هنا
    debugPrint('Trying to access company: $selectedCompanyFilter'); // وهنا
  }

  Future<void> _loadFilterOptions() async {
    if (_userId == null) return;

    final userDoc =
        await FirebaseFirestore.instance.collection('users').doc(_userId).get();
    final userCompanyIds =
        (userDoc.data()?['companyIds'] as List?)?.cast<String>() ?? [];
    debugPrint('User $_userId has access to companies: $userCompanyIds');
    final cs = await FirebaseFirestore.instance
        .collection('companies')
        .where(FieldPath.documentId, whereIn: userCompanyIds)
        .get();
    debugPrint('Available companies count: ${cs.docs.length}');
    final vs = await FirebaseFirestore.instance.collection('vendors').get();
    final ins = await FirebaseFirestore.instance.collectionGroup('items').get();
    final fs = await FirebaseFirestore.instance.collection('factories').get();

    setState(() {
      allCompanies = cs.docs
          .map((d) => {'id': d.id, 'name_ar': d['name_ar'] ?? d.id})
          .toList();
      allSuppliers =
          vs.docs.map((d) => d['name']?.toString() ?? d.id).toSet().toList();
      allItems =
          ins.docs.map((d) => d['name']?.toString() ?? '').toSet().toList();
      allFactories = fs.docs
          .map((d) => {'id': d.id, 'name_ar': d['name_ar'] ?? d.id})
          .toList();
    });
  }

  Future<void> deleteOrder(String companyId, String orderId) async {
    try {
      final ref = FirebaseFirestore.instance
          .collection('companies/$companyId/purchase_orders')
          .doc(orderId);
      final doc = await ref.get();

      if (!mounted) return;

      if (doc.exists && !(doc.data()?['isConfirmed'] ?? false)) {
        await ref.delete();
        if (!mounted) return;
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('orderDeleted'.tr())));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('cannotDeleteConfirmed'.tr())));
      }
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('errorOccurred'.tr())));
    }
  }

  Future<void> _verifyUserAccess() async {
    if (_userId == null) return;

    final userDoc =
        await FirebaseFirestore.instance.collection('users').doc(_userId).get();

    debugPrint('User document exists: ${userDoc.exists}');
    debugPrint('User data: ${userDoc.data()}');

    final companyDoc = await FirebaseFirestore.instance
        .collection('companies')
        .doc(selectedCompanyFilter)
        .get();

    debugPrint('Company document exists: ${companyDoc.exists}');
  }

  void _clearFilters() {
    setState(() {
      selectedCompanyFilter = null;
      selectedSupplierFilter = null;
      selectedItemFilter = null;
      selectedFactories = [];
      startDate = null;
      endDate = null;
    });
  }

  Stream<QuerySnapshot> _purchaseOrdersStream() {
    debugPrint('Stream requested for company: $selectedCompanyFilter');

    if (selectedCompanyFilter != null && selectedCompanyFilter!.isNotEmpty) {
      try {
        final stream = FirebaseFirestore.instance
            .collection('companies')
            .doc(selectedCompanyFilter!)
            .collection('purchase_orders')
            .orderBy('createdAt', descending: true)
            .snapshots();

        // إضافة listener للتحقق من الأخطاء
        stream.listen(
          (querySnapshot) =>
              debugPrint('Got ${querySnapshot.docs.length} orders'),
          onError: (e) => debugPrint('Stream error: $e'),
        );

        return stream;
      } catch (e) {
        debugPrint('Error creating stream: $e');
        return const Stream.empty();
      }
    }
    return const Stream.empty();
  }

  @override
  Widget build(BuildContext context) {
    debugPrint('Current selected company: $selectedCompanyFilter'); // هنا
    return AppScaffold(
      title: 'purchase_orders'.tr(),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push('/add-purchase-order'),
        tooltip: 'addPurchaseOrder'.tr(),
        child: const Icon(Icons.add),
      ),
      body: _userId == null
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                FilterBar(
                  allCompanies: allCompanies,
                  allSuppliers: allSuppliers,
                  allItems: allItems,
                  allFactories: allFactories,
                  selectedCompany: selectedCompanyFilter,
                  selectedSupplier: selectedSupplierFilter,
                  selectedItem: selectedItemFilter,
                  selectedFactories: selectedFactories,
                  startDate: startDate,
                  endDate: endDate,
                  onCompanyChanged: (v) =>
                      setState(() => selectedCompanyFilter = v),
                  onSupplierChanged: (v) =>
                      setState(() => selectedSupplierFilter = v),
                  onItemChanged: (v) => setState(() => selectedItemFilter = v),
                  onFactoriesChanged: (list) =>
                      setState(() => selectedFactories = list),
                  onDateRangePick: (start, end) {
                    setState(() {
                      startDate = start;
                      endDate = end;
                    });
                  },
                  onClearFilters: _clearFilters,
                ),
                if (selectedCompanyFilter == null)
                  Expanded(
                    child: Center(
                      child: Text('select_company_first'.tr(),
                          style: TextStyle(
                              fontSize: 16, color: Colors.blueGrey[700])),
                    ),
                  )
                else
                  Expanded(
                    child: StreamBuilder<QuerySnapshot>(
                      stream: _purchaseOrdersStream(),
                      builder: (ctx, snap) {
                        if (snap.connectionState == ConnectionState.waiting) {
                          return const Center(
                              child: CircularProgressIndicator());
                        }

                        if (snap.hasError) {
                          return Center(child: Text('errorOccurred'.tr()));
                        }

                        final docs = snap.data?.docs ?? [];

                        final filtered = docs.where((doc) {
                          final data = doc.data() as Map<String, dynamic>;
                          final supplier =
                              (data['supplierName'] ?? '').toLowerCase();
                          final itemsText = ((data['items'] ?? []) as List)
                              .map((e) => (e['name'] ?? '').toLowerCase())
                              .join(' ');
                          final factoryIds =
                              (data['factoryIds'] ?? []).cast<String>();
                          final createdAt =
                              (data['createdAt'] as Timestamp?)?.toDate();

                          final matchSupplier =
                              selectedSupplierFilter == null ||
                                  supplier.contains(
                                      selectedSupplierFilter!.toLowerCase());
                          final matchItem = selectedItemFilter == null ||
                              itemsText
                                  .contains(selectedItemFilter!.toLowerCase());
                          final matchFactory = selectedFactories.isEmpty ||
                              selectedFactories
                                  .any((f) => factoryIds.contains(f));
                          final matchDate = startDate == null ||
                              endDate == null ||
                              (createdAt != null &&
                                  !createdAt.isBefore(startDate!) &&
                                  !createdAt.isAfter(
                                      endDate!.add(const Duration(days: 1))));

                          return matchSupplier &&
                              matchItem &&
                              matchFactory &&
                              matchDate;
                        }).toList();

                        if (filtered.isEmpty) {
                          return Center(child: Text('no_orders_found'.tr()));
                        }

                        return ListView.builder(
                          itemCount: filtered.length,
                          itemBuilder: (c, i) {
                            final doc = filtered[i];
                            final data = doc.data() as Map<String, dynamic>;
                            return PurchaseOrderCard(
                              data: data,
                              orderId: doc.id,
                              companyName: allCompanies.firstWhere(
                                  (c) => c['id'] == data['companyId'],
                                  orElse: () => {'name_ar': '---'})['name_ar'],
                              vendorName:
                                  data['supplierName'] ?? data['supplierId'],
                              onEdit: () => context.push(
                                  '/add-purchase-order?companyId=${data['companyId']}&editOrderId=${doc.id}'),
                              onDelete: () =>
                                  deleteOrder(data['companyId'], doc.id),
                              onExport: () async {
                                final compD = await FirebaseFirestore.instance
                                    .collection('companies')
                                    .doc(data['companyId'])
                                    .get();
                                final vendD = await FirebaseFirestore.instance
                                    .collection('vendors')
                                    .doc(data['supplierId'])
                                    .get();
                                final pdf = await generatePurchaseOrderPdf(
                                  orderId: doc.id,
                                  orderData: data,
                                  supplierData: vendD.data() ?? {},
                                  companyData: compD.data() ?? {},
                                );
                                await Printing.layoutPdf(
                                    onLayout: (f) async => pdf.save());
                              },
                            );
                          },
                        );
                      },
                    ),
                  ),
              ],
            ),
    );
  }
}
 */

import 'package:flutter/material.dart';
import 'package:puresip_purchasing/models/purchase_order.dart';
import 'package:puresip_purchasing/pages/purchasing/add_purchase_order_page.dart';

class PurchaseOrdersScreen extends StatefulWidget {
  const PurchaseOrdersScreen({super.key});

  @override
  State<PurchaseOrdersScreen> createState() => _PurchaseOrdersScreenState();
}

class _PurchaseOrdersScreenState extends State<PurchaseOrdersScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  String? _selectedCompanyId;
  String? _selectedFactoryId;
  String _filterStatus = 'all';
  bool _showOnlyUndelivered = false;
  List<PurchaseOrder> _orders = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    final user = await UserLocalStorage.getUser();
    if (user == null || !mounted) return;

    setState(() {
      _selectedCompanyId = user['companyIds'].isNotEmpty 
          ? user['companyIds'].first 
          : null;
    });

    await _loadOrders();
  }

  Future<void> _loadOrders() async {
    if (_selectedCompanyId == null) {
      setState(() {
        _orders = [];
        _isLoading = false;
      });
      return;
    }

    setState(() => _isLoading = true);

    try {
      Query query = _firestore
          .collection('companies/$_selectedCompanyId/purchase_orders')
          .where('userId', isEqualTo: FirebaseAuth.instance.currentUser?.uid);

      // تطبيق الفلتر حسب المصنع
      if (_selectedFactoryId != null) {
        query = query.where('factoryId', isEqualTo: _selectedFactoryId);
      }

      // تطبيق الفلتر حسب الحالة
      if (_filterStatus != 'all') {
        query = query.where('status', isEqualTo: _filterStatus);
      }

      // تطبيق فلتر التسليم
      if (_showOnlyUndelivered) {
        query = query.where('isDelivered', isEqualTo: false);
      }

      final snapshot = await query
          .orderBy('orderDate', descending: true)
          .get();

      final orders = snapshot.docs
          .map((doc) => PurchaseOrder.fromFirestore(doc))
          .toList();

      if (mounted) {
        setState(() {
          _orders = orders;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load orders: $e')),
        );
      }
    }
  }

  Future<void> _updateDeliveryStatus(String orderId, bool isDelivered) async {
    if (_selectedCompanyId == null) return;

    try {
      await _firestore
          .collection('companies/$_selectedCompanyId/purchase_orders')
          .doc(orderId)
          .update({
            'isDelivered': isDelivered,
            'deliveryDate': isDelivered ? Timestamp.now() : null,
          });

      await _loadOrders();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update status: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<User?>();
    if (user == null) return const Center(child: Text('Please sign in'));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Purchase Orders'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadOrders,
          ),
        ],
      ),
      body: Column(
        children: [
          // فلاتر البحث
          _buildFilters(),
          // قائمة الأوامر
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _orders.isEmpty
                    ? const Center(child: Text('No orders found'))
                    : ListView.builder(
                        itemCount: _orders.length,
                        itemBuilder: (context, index) {
                          final order = _orders[index];
                          return _buildOrderCard(order);
                        },
                      ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _navigateToAddOrder(),
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildFilters() {
    return Card(
      margin: const EdgeInsets.all(8),
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          children: [
            // فلتر الشركة
            FutureBuilder<List<String>>(
              future: UserLocalStorage.getCompanyIds(),
              builder: (context, snapshot) {
                final companies = snapshot.data ?? [];
                return DropdownButtonFormField<String>(
                  value: _selectedCompanyId,
                  items: companies
                      .map((id) => DropdownMenuItem(
                            value: id,
                            child: FutureBuilder<DocumentSnapshot>(
                              future: _firestore.collection('companies').doc(id).get(),
                              builder: (context, snapshot) {
                                final name = snapshot.data?['name'] ?? 'Unknown Company';
                                return Text(name);
                              },
                            ),
                          ))
                      .toList(),
                  onChanged: (value) {
                    setState(() {
                      _selectedCompanyId = value;
                      _selectedFactoryId = null;
                    });
                    _loadOrders();
                  },
                  decoration: const InputDecoration(
                    labelText: 'Company',
                    border: OutlineInputBorder(),
                  ),
                );
              },
            ),
            const SizedBox(height: 8),
            // فلتر المصنع (يظهر فقط إذا تم تحديد شركة)
            if (_selectedCompanyId != null)
              FutureBuilder<List<String>>(
                future: _getFactoryIdsForCompany(_selectedCompanyId!),
                builder: (context, snapshot) {
                  final factories = snapshot.data ?? [];
                  return DropdownButtonFormField<String>(
                    value: _selectedFactoryId,
                    items: [
                      const DropdownMenuItem(
                        value: null,
                        child: Text('All Factories'),
                      ),
                      ...factories.map((id) => DropdownMenuItem(
                            value: id,
                            child: FutureBuilder<DocumentSnapshot>(
                              future: _firestore.collection('factories').doc(id).get(),
                              builder: (context, snapshot) {
                                final name = snapshot.data?['name'] ?? 'Unknown Factory';
                                return Text(name);
                              },
                            ),
                          )),
                    ],
                    onChanged: (value) {
                      setState(() => _selectedFactoryId = value);
                      _loadOrders();
                    },
                    decoration: const InputDecoration(
                      labelText: 'Factory (Optional)',
                      border: OutlineInputBorder(),
                    ),
                  );
                },
              ),
            const SizedBox(height: 8),
            // فلتر الحالة
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _filterStatus,
                    items: [
                      'all',
                      'pending',
                      'approved',
                      'delivered',
                      'cancelled',
                    ].map((status) {
                      return DropdownMenuItem(
                        value: status,
                        child: Text(
                          status == 'all' ? 'All Statuses' : status.capitalize(),
                        ),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() => _filterStatus = value!);
                      _loadOrders();
                    },
                    decoration: const InputDecoration(
                      labelText: 'Status',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // فلتر التسليم
                FilterChip(
                  label: const Text('Undelivered Only'),
                  selected: _showOnlyUndelivered,
                  onSelected: (value) {
                    setState(() => _showOnlyUndelivered = value);
                    _loadOrders();
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOrderCard(PurchaseOrder order) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: ExpansionTile(
        leading: Icon(
          order.isDelivered ? Icons.check_circle : Icons.pending,
          color: order.isDelivered ? Colors.green : Colors.orange,
        ),
        title: Text('Order #${order.id.substring(0, 8)}'),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Supplier: ${order.supplierId}'),
            Text('Date: ${DateFormat('yyyy-MM-dd').format(order.orderDate)}'),
            Text('Total: ${order.totalAmount.toStringAsFixed(2)}'),
            Text('Status: ${order.status.capitalize()}'),
          ],
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // تفاصيل الأصناف
                const Text('Items:', style: TextStyle(fontWeight: FontWeight.bold)),
                ...order.items.map((item) => ListTile(
                      title: Text(item.name),
                      subtitle: Text('${item.quantity} ${item.unit} x ${item.unitPrice}'),
                      trailing: Text(item.totalPrice.toStringAsFixed(2)),
                    )),
                const Divider(),
                // معلومات التسليم
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Delivered: ${order.isDelivered ? 'Yes' : 'No'}',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: order.isDelivered ? Colors.green : Colors.red,
                      ),
                    ),
                    if (order.isDelivered)
                      Text(
                        'on ${DateFormat('yyyy-MM-dd').format(order.deliveryDate!)}',
                        style: const TextStyle(fontSize: 12),
                      ),
                  ],
                ),
                if (order.deliveryNotes?.isNotEmpty ?? false)
                  Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Text('Notes: ${order.deliveryNotes}'),
                  ),
                const SizedBox(height: 8),
                // أزرار التحكم
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (!order.isDelivered)
                      TextButton(
                        onPressed: () => _markAsDelivered(order),
                        child: const Text('Mark as Delivered'),
                      ),
                    if (order.isDelivered)
                      TextButton(
                        onPressed: () => _undoDelivery(order),
                        child: const Text('Undo Delivery'),
                      ),
                    IconButton(
                      icon: const Icon(Icons.edit),
                      onPressed: () => _editOrder(order),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<List<String>> _getFactoryIdsForCompany(String companyId) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return [];

      final snapshot = await _firestore
          .collection('factories')
          .where('companyId', isEqualTo: companyId)
          .where('userId', isEqualTo: user.uid)
          .get();

      return snapshot.docs.map((doc) => doc.id).toList();
    } catch (e) {
      debugPrint('Error fetching factories: $e');
      return [];
    }
  }

  Future<void> _markAsDelivered(PurchaseOrder order) async {
    final notes = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delivery Notes'),
        content: TextField(
          decoration: const InputDecoration(
            hintText: 'Enter any delivery notes...',
          ),
          maxLines: 3,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              final text = (context
                  .findAncestorWidgetOfExactType<TextField>()!
                  .controller!
                  .text);
              Navigator.pop(context, text);
            },
            child: const Text('Confirm'),
          ),
        ],
      ),
    );

    if (_selectedCompanyId == null) return;

    try {
      await _firestore
          .collection('companies/$_selectedCompanyId/purchase_orders')
          .doc(order.id)
          .update({
            'isDelivered': true,
            'deliveryDate': Timestamp.now(),
            'deliveryNotes': notes,
            'status': 'delivered',
          });

      await _loadOrders();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update delivery status: $e')),
      );
    }
  }

  Future<void> _undoDelivery(PurchaseOrder order) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Undo Delivery'),
        content: const Text('Are you sure you want to undo delivery status?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );

    if (confirmed != true || _selectedCompanyId == null) return;

    try {
      await _firestore
          .collection('companies/$_selectedCompanyId/purchase_orders')
          .doc(order.id)
          .update({
            'isDelivered': false,
            'deliveryDate': null,
            'status': 'approved',
          });

      await _loadOrders();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to undo delivery: $e')),
      );
    }
  }

  Future<void> _navigateToAddOrder() async {
    if (_selectedCompanyId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a company first')),
      );
      return;
    }

    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddPurchaseOrderPage(
          companyId: _selectedCompanyId!, selectedCompany: '', orderToEdit: null,
        ),
      ),
    );

    if (result == true) {
      await _loadOrders();
    }
  }

  Future<void> _editOrder(PurchaseOrder order) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddPurchaseOrderPage(
          companyId: _selectedCompanyId!,
          orderToEdit: order,
        ),
      ),
    );

    if (result == true) {
      await _loadOrders();
    }
  }
}