import 'package:cloud_firestore/cloud_firestore.dart';
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
