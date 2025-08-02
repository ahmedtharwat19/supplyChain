import 'dart:convert';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:path_provider/path_provider.dart';
import 'package:printing/printing.dart';
import 'package:puresip_purchasing/utils/pdf_exporter.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:puresip_purchasing/widgets/app_scaffold_2.dart';
import 'package:universal_html/html.dart' as html;
import 'package:shared_preferences/shared_preferences.dart';

class PurchaseOrdersPage extends StatefulWidget {
  const PurchaseOrdersPage({super.key});

  @override
  State<PurchaseOrdersPage> createState() => _PurchaseOrdersPageState();
}

class _PurchaseOrdersPageState extends State<PurchaseOrdersPage> {
  String searchQuery = '';
  bool isLoading = true;
  String? userName;
  final List<Map<String, dynamic>> _allOrders = [];
  final List<Map<String, dynamic>> _filteredOrders = [];
  bool _isSearching = false;
  int _userCompaniesCount = 1;
  String _currentSortOption = 'dateDesc';
  final TextEditingController _searchController = TextEditingController();

  bool get isArabic => Localizations.localeOf(context).languageCode == 'ar';

  @override
  void initState() {
    super.initState();
    _initData();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _initData() async {
    await loadUserInfo();
    await _loadUserCompaniesCount();
    await _loadAllOrders();
  }

  Future<void> loadUserInfo() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final email = user.email ?? '';
      final name = user.displayName ?? '';
      setState(() {
        userName = name.isNotEmpty ? name : email.split('@')[0];
      });
    }
  }

  Future<void> _loadUserCompaniesCount() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final prefs = await SharedPreferences.getInstance();
    final cachedCount = prefs.getInt('userCompaniesCount');

    if (cachedCount != null) {
      setState(() => _userCompaniesCount = cachedCount);
      return;
    }

    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();

    final companyIds = (userDoc.data()?['companyIds'] as List?)?.length ?? 1;
    await prefs.setInt('userCompaniesCount', companyIds);
    setState(() => _userCompaniesCount = companyIds);
  }

  Future<String> _getCompanyName(String companyId) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('companies')
          .doc(companyId)
          .get();

      if (isArabic) {
        return doc.data()?['name_ar'] ?? companyId;
      } else {
        return doc.data()?['name_en'] ?? companyId;
      }
    } catch (e) {
      return companyId;
    }
  }

  Future<String> _getSupplierName(String supplierId) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('vendors')
          .doc(supplierId)
          .get();
      return doc.data()?['name'] ?? supplierId;
    } catch (e) {
      return supplierId;
    }
  }

  // Future<Uint8List?> _getCompanyLogo(String companyId) async {
  //   try {
  //     final ref = FirebaseStorage.instance.ref('company_logos/$companyId.png');
  //     return await ref.getData();
  //   } catch (e) {
  //     debugPrint('No logo found for $companyId: $e');
  //     return null;
  //   }
  // }

  Color _getStatusColor(String? status) {
    switch (status?.toLowerCase()) {
      case 'completed':
        return Colors.green;
      case 'pending':
        return Colors.orange;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

/*   Future<void> _loadAllOrders() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (mounted) context.go('/login');
      return;
    }

    if (mounted) setState(() => isLoading = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedOrders = prefs.getString('cachedOrders');
      
      if (cachedOrders != null) {
        final decoded = (json.decode(cachedOrders) as List)
            .map((e) => e as Map<String, dynamic>)
            .toList();
        _allOrders.clear();
        _allOrders.addAll(decoded);
        _filterOrders(searchQuery);
      }

      Query query = FirebaseFirestore.instance
          .collection('purchase_orders')
          .where('userId', isEqualTo: user.uid);

      switch (_currentSortOption) {
        case 'dateDesc': query = query.orderBy('orderDate', descending: true); break;
        case 'dateAsc': query = query.orderBy('orderDate', descending: false); break;
        case 'amountDesc': query = query.orderBy('totalAmountAfterTax', descending: true); break;
        case 'amountAsc': query = query.orderBy('totalAmountAfterTax', descending: false); break;
      }

      final querySnapshot = await query.get();

      if (!mounted) return;

      final orders = querySnapshot.docs;
      final futures = orders.map((doc) async {
        final data = doc.data() as Map<String, dynamic>;
        final companyId = data['companyId'] as String? ?? '';
        final supplierId = data['supplierId'] as String? ?? '';

        final company = await _getCompanyName(companyId);
        final supplier = await _getSupplierName(supplierId);

        return {
          ...data,
          'id': doc.id,
          'companyName': company,
          'supplierName': supplier,
        };
      }).toList();

      _allOrders.clear();
      _allOrders.addAll(await Future.wait<Map<String, dynamic>>(futures));
      
      await prefs.setString('cachedOrders', json.encode(_allOrders));

      _sortOrders();
      _filterOrders(searchQuery);
    } catch (e) {
      debugPrint('Error loading orders: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('error_loading_orders'.tr())),
        );
      }
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }
 */

  Future<void> _loadAllOrders() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (mounted) context.go('/login');
      return;
    }

    if (mounted) setState(() => isLoading = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedOrders = prefs.getString('cachedOrders');

      if (cachedOrders != null) {
        final decoded = (json.decode(cachedOrders) as List)
            .map((e) => e as Map<String, dynamic>)
            .toList();
        _allOrders.clear();
        _allOrders.addAll(decoded);
        _filterOrders(searchQuery);
      }

      Query query = FirebaseFirestore.instance
          .collection('purchase_orders')
          .where('userId', isEqualTo: user.uid);

      switch (_currentSortOption) {
        case 'dateDesc':
          query = query.orderBy('orderDate', descending: true);
          break;
        case 'dateAsc':
          query = query.orderBy('orderDate', descending: false);
          break;
        case 'amountDesc':
          query = query.orderBy('totalAmountAfterTax', descending: true);
          break;
        case 'amountAsc':
          query = query.orderBy('totalAmountAfterTax', descending: false);
          break;
      }

      final querySnapshot = await query.get();

      if (!mounted) return;

      final orders = querySnapshot.docs;
      final futures = orders.map((doc) async {
        final data = doc.data() as Map<String, dynamic>;
        final companyId = data['companyId'] as String? ?? '';
        final supplierId = data['supplierId'] as String? ?? '';

        final company = await _getCompanyName(companyId);
        final supplier = await _getSupplierName(supplierId);

        // تحويل Timestamp إلى milliseconds منذ epoch
        final orderData = {
          ...data,
          'id': doc.id,
          'companyName': company,
          'supplierName': supplier,
        };

        if (data['orderDate'] is Timestamp) {
          orderData['orderDate'] =
              (data['orderDate'] as Timestamp).millisecondsSinceEpoch;
        }

        return orderData;
      }).toList();

      _allOrders.clear();
      _allOrders.addAll(await Future.wait<Map<String, dynamic>>(futures));

      // حفظ في الذاكرة المحلية
      await prefs.setString('cachedOrders', json.encode(_allOrders));

      // تحويل milliseconds back إلى Timestamp عند التحميل
      for (var order in _allOrders) {
        if (order['orderDate'] is int) {
          order['orderDate'] =
              Timestamp.fromMillisecondsSinceEpoch(order['orderDate']);
        }
      }

      _sortOrders();
      _filterOrders(searchQuery);
    } catch (e) {
      debugPrint('Error loading orders: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('error_loading_orders'.tr())),
        );
      }
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  void _sortOrders() {
    _allOrders.sort((a, b) {
      switch (_currentSortOption) {
        case 'dateDesc':
          return (b['orderDate'] as Timestamp)
              .compareTo(a['orderDate'] as Timestamp);
        case 'dateAsc':
          return (a['orderDate'] as Timestamp)
              .compareTo(b['orderDate'] as Timestamp);
        case 'amountDesc':
          return (b['totalAmountAfterTax'] as num)
              .compareTo(a['totalAmountAfterTax'] as num);
        case 'amountAsc':
          return (a['totalAmountAfterTax'] as num)
              .compareTo(b['totalAmountAfterTax'] as num);
        default:
          return 0;
      }
    });
  }

  void _onSearchChanged() {
    setState(() {
      searchQuery = _searchController.text.toLowerCase();
      _filterOrders(searchQuery);
    });
  }

  void _filterOrders(String query) {
    if (query.isEmpty) {
      _filteredOrders.clear();
      _filteredOrders.addAll(_allOrders);
      return;
    }

    _filteredOrders.clear();
    _filteredOrders.addAll(_allOrders.where((order) {
      final poNumber = (order['poNumber'] ?? '').toString().toLowerCase();
      final supplier = (order['supplierName'] ?? '').toString().toLowerCase();
      final company = (order['companyName'] ?? '').toString().toLowerCase();
      final status = (order['status'] ?? '').toString().toLowerCase();

      return poNumber.contains(query) ||
          supplier.contains(query) ||
          company.contains(query) ||
          status.contains(query);
    }));
  }

  void _showSortOptions() {
    showModalBottomSheet(
      context: context,
      builder: (_) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                title: Text('sort_by_date_desc'.tr()),
                onTap: () {
                  Navigator.pop(context);
                  setState(() {
                    _currentSortOption = 'dateDesc';
                    _sortOrders();
                    _filterOrders(searchQuery);
                  });
                },
              ),
              ListTile(
                title: Text('sort_by_date_asc'.tr()),
                onTap: () {
                  Navigator.pop(context);
                  setState(() {
                    _currentSortOption = 'dateAsc';
                    _sortOrders();
                    _filterOrders(searchQuery);
                  });
                },
              ),
              ListTile(
                title: Text('sort_by_amount_desc'.tr()),
                onTap: () {
                  Navigator.pop(context);
                  setState(() {
                    _currentSortOption = 'amountDesc';
                    _sortOrders();
                    _filterOrders(searchQuery);
                  });
                },
              ),
              ListTile(
                title: Text('sort_by_amount_asc'.tr()),
                onTap: () {
                  Navigator.pop(context);
                  setState(() {
                    _currentSortOption = 'amountAsc';
                    _sortOrders();
                    _filterOrders(searchQuery);
                  });
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _editOrder(Map<String, dynamic> order) {
    context.push('/edit-purchase-order/${order['id']}');
  }

/*   Future<void> _exportOrder(Map<String, dynamic> order) async {
    setState(() => _isSearching = true);
    try {
      final companyData = await FirebaseFirestore.instance
          .collection('companies')
          .doc(order['companyId'])
          .get();

      final supplierData = await FirebaseFirestore.instance
          .collection('vendors')
          .doc(order['supplierId'])
          .get();

    // تجهيز عناصر الطلب مع أسماء الأصناف من قاعدة البيانات
    List<dynamic> orderItems = List.from(order['items'] ?? []);
    Map<String, dynamic> itemsDataMap = {}; // تخزين أسماء الأصناف حسب ID

    for (var item in orderItems) {
      final itemId = item['nameId'];
      if (itemId != null) {
        final itemSnapshot = await FirebaseFirestore.instance
            .collection('items')
            .doc(itemId)
            .get();

        final itemData = itemSnapshot.data();
        if (itemData != null) {
          // أضف اسم الصنف حسب اللغة داخل العنصر مباشرة
          item['name_ar'] = itemData['name_ar'];
          item['name_en'] = itemData['name_en'];
          itemsDataMap[itemId] = itemData;
        }
      }
    }

    // تحديث order بعد تعديل العناصر
    order['items'] = orderItems;
      final companyDataMap = companyData.data() ?? {};
      //     final logoBytes = await _getCompanyLogo(companyData.id);
      final base64Logo = companyDataMap['logo_base64'] as String?;

      final pdf = await PdfExporter.generatePurchaseOrderPdf(
        orderId: order['id'],
        orderData: order,
        supplierData: supplierData.data() ?? {},
        companyData: companyData.data() ?? {},
        itemData: itemsDataMap,
        base64Logo: base64Logo,
        isArabic: isArabic,
        //   qrData: order['poNumber'] ?? order['id'],
      );

      final bytes = await pdf.save();

      if (kIsWeb) {
        final blob = html.Blob([bytes], 'application/pdf');
        final url = html.Url.createObjectUrlFromBlob(blob);
        final anchor = html.document.createElement('a') as html.AnchorElement
          ..href = url
          ..download = 'order_${order['poNumber'] ?? order['id']}.pdf'
          ..style.display = 'none';

        html.document.body?.children.add(anchor);
        anchor.click();
        html.document.body?.children.remove(anchor);
        html.Url.revokeObjectUrl(url);
      } else {
        final dir = await getTemporaryDirectory();
        final file =
            File('${dir.path}/order_${order['poNumber'] ?? order['id']}.pdf');
        await file.writeAsBytes(bytes);
        await Printing.sharePdf(
          bytes: bytes,
          filename: 'order_${order['poNumber'] ?? order['id']}.pdf',
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${'export_error'.tr()}: $e'),
            duration: const Duration(seconds: 5),
          ),
        );
      }
      debugPrint('PDF Export Error: $e');
    } finally {
      if (mounted) setState(() => _isSearching = false);
    }
  }

 */

 
 Future<void> _exportOrder(Map<String, dynamic> order) async {
  setState(() => _isSearching = true);
  try {
    final companyData = await FirebaseFirestore.instance
        .collection('companies')
        .doc(order['companyId'])
        .get();

    final supplierData = await FirebaseFirestore.instance
        .collection('vendors')
        .doc(order['supplierId'])
        .get();

    // تجهيز عناصر الطلب مع أسماء الأصناف من قاعدة البيانات
    List<dynamic> orderItems = List.from(order['items'] ?? []);
    Map<String, dynamic> itemsDataMap = {}; // تخزين أسماء الأصناف حسب ID

    for (var item in orderItems) {
      final itemId = item['itemId'];
      if (itemId != null && itemId.isNotEmpty) {
        try {
          final itemSnapshot = await FirebaseFirestore.instance
              .collection('items')
              .doc(itemId) // تم التصحيح هنا لاستخدام itemId مباشرة
              .get();

          if (itemSnapshot.exists) {
            final itemData = itemSnapshot.data();
            // أضف اسم الصنف حسب اللغة داخل العنصر مباشرة
            item['name_ar'] = itemData?['name_ar'] ?? 'غير متوفر';
            item['name_en'] = itemData?['name_en'] ?? 'Not available';
            itemsDataMap[itemId] = itemData;
          } else {
            debugPrint('Item document $itemId does not exist');
            item['name_ar'] = 'صنف غير موجود';
            item['name_en'] = 'Item not found';
          }
        } catch (e) {
          debugPrint('Error fetching item $itemId: $e');
          item['name_ar'] = 'خطأ في جلب البيانات';
          item['name_en'] = 'Error loading data';
        }
      } else {
        item['name_ar'] = 'لا يوجد كود صنف';
        item['name_en'] = 'No item code';
      }
    }

    // تحديث order بعد تعديل العناصر
    order['items'] = orderItems;
    final companyDataMap = companyData.data() ?? {};
    final base64Logo = companyDataMap['logo_base64'] as String?;

    final pdf = await PdfExporter.generatePurchaseOrderPdf(
      orderId: order['id'],
      orderData: order,
      supplierData: supplierData.data() ?? {},
      companyData: companyData.data() ?? {},
      itemData: itemsDataMap,
      base64Logo: base64Logo,
      isArabic: isArabic,
    );

    final bytes = await pdf.save();

    if (kIsWeb) {
      final blob = html.Blob([bytes], 'application/pdf');
      final url = html.Url.createObjectUrlFromBlob(blob);
      final anchor = html.document.createElement('a') as html.AnchorElement
        ..href = url
        ..download = 'order_${order['poNumber'] ?? order['id']}.pdf'
        ..style.display = 'none';

      html.document.body?.children.add(anchor);
      anchor.click();
      html.document.body?.children.remove(anchor);
      html.Url.revokeObjectUrl(url);
    } else {
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/order_${order['poNumber'] ?? order['id']}.pdf');
      await file.writeAsBytes(bytes);
      await Printing.sharePdf(
        bytes: bytes,
        filename: 'order_${order['poNumber'] ?? order['id']}.pdf',
      );
    }
  } catch (e) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${'export_error'.tr()}: $e'),
          duration: const Duration(seconds: 5),
        ),
      );
    }
    debugPrint('PDF Export Error: $e');
  } finally {
    if (mounted) setState(() => _isSearching = false);
  }
}
 
 
  void _confirmDeleteOrder(Map<String, dynamic> order) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('confirm_delete'.tr()),
        content: Text('delete_order_confirm'.tr()),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('cancel'.tr()),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _deleteOrder(order);
            },
            child:
                Text('delete'.tr(), style: const TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteOrder(Map<String, dynamic> order) async {
    try {
      await FirebaseFirestore.instance
          .collection('purchase_orders')
          .doc(order['id'])
          .delete();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('order_deleted'.tr())),
        );
        _loadAllOrders();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('delete_error'.tr())),
        );
      }
    }
  }

  Widget _buildOrderCard(Map<String, dynamic> order) {
    final totalAmount = NumberFormat.currency(
      symbol: '',
      decimalDigits: 2,
    ).format(order['totalAmountAfterTax'] ?? 0);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: _getStatusColor(order['status']).withAlpha(76),
          width: 1.5,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => context.push('/purchase-order-details/${order['id']}'),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    order['poNumber'] ?? 'PO-${order['id']}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: _getStatusColor(order['status']),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      (order['status'] ?? 'pending').toString().toUpperCase(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              if (_userCompaniesCount > 1)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Row(
                    children: [
                      const Icon(Icons.business, size: 16, color: Colors.grey),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          order['companyName'] ?? '',
                          style: TextStyle(color: Colors.grey.shade600),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Row(
                  children: [
                    const Icon(Icons.person, size: 16, color: Colors.grey),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        order['supplierName'] ?? '',
                        style: TextStyle(color: Colors.grey.shade600),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 16, thickness: 1),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.calendar_today,
                          size: 16, color: Colors.grey),
                      const SizedBox(width: 8),
                      Text(
                        DateFormat('yyyy-MM-dd').format(
                          (order['orderDate'] as Timestamp).toDate(),
                        ),
                        style: TextStyle(color: Colors.grey.shade700),
                      ),
                    ],
                  ),
                  Text(
                    '$totalAmount ${'currency'.tr()}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.blue,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  IconButton(
                    icon: const Icon(Icons.edit, size: 20, color: Colors.blue),
                    tooltip: 'edit'.tr(),
                    onPressed: () => _editOrder(order),
                  ),
                  IconButton(
                    icon: const Icon(Icons.picture_as_pdf,
                        size: 20, color: Colors.green),
                    tooltip: 'export_pdf'.tr(),
                    onPressed: () => _exportOrder(order),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete, size: 20, color: Colors.red),
                    tooltip: 'delete'.tr(),
                    onPressed: () => _confirmDeleteOrder(order),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return AppScaffold(
        title: 'purchase_orders'.tr(),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Directionality(
      textDirection: Directionality.of(context),
      child: AppScaffold(
        title: 'purchase_orders'.tr(),
        actions: [
          if (_userCompaniesCount > 1)
            IconButton(
              icon: const Icon(Icons.business),
              tooltip: 'multiple_companies'.tr(),
              onPressed: () {},
            ),
          IconButton(
            icon: const Icon(Icons.sort),
            onPressed: _showSortOptions,
            tooltip: 'sort_options'.tr(),
          ),
        ],
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  labelText: 'search'.tr(),
                  prefixIcon: const Icon(Icons.search),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  hintText: 'search_hint'.tr(),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () => _searchController.clear(),
                        )
                      : null,
                ),
              ),
            ),
            Expanded(
              child: _isSearching
                  ? const Center(child: CircularProgressIndicator())
                  : _filteredOrders.isEmpty
                      ? Center(child: Text('no_match_search'.tr()))
                      : RefreshIndicator(
                          onRefresh: _loadAllOrders,
                          child: ListView.builder(
                            itemCount: _filteredOrders.length,
                            itemBuilder: (ctx, index) {
                              final order = _filteredOrders[index];
                              return _buildOrderCard(order);
                            },
                          ),
                        ),
            ),
          ],
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: () async {
            final result = await context.push('/add-purchase-order');
            if (result == true && mounted) await _loadAllOrders();
          },
          tooltip: 'add_purchase_order'.tr(),
          child: const Icon(Icons.add),
        ),
      ),
    );
  }
}



/* import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:path_provider/path_provider.dart';
import 'package:printing/printing.dart';
// import 'dart:io' show Platform;
// import 'dart:html' as html; // فقط على web
import 'package:puresip_purchasing/widgets/app_scaffold.dart';
import 'package:puresip_purchasing/utils/pdf_exporter.dart';
import 'package:share_plus/share_plus.dart';

class PurchaseOrdersPage extends StatefulWidget {
  const PurchaseOrdersPage({super.key});

  @override
  State<PurchaseOrdersPage> createState() => _PurchaseOrdersPageState();
}

class _PurchaseOrdersPageState extends State<PurchaseOrdersPage> {
  String searchQuery = '';
  bool isLoading = true;
  String? userName;
  final List<Map<String, dynamic>> _allOrders = [];
  bool _isSearching = false;
  int _userCompaniesCount = 1;
  bool get isArabic => Localizations.localeOf(context).languageCode == 'ar';

  @override
  void initState() {
    super.initState();
    loadUserInfo();
    _loadUserCompaniesCount();
    _loadAllOrders();
  }

  Future<void> loadUserInfo() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final email = user.email ?? '';
      final name = user.displayName ?? '';
      setState(() {
        userName = name.isNotEmpty ? name : email.split('@')[0];
        debugPrint('User name: $userName');
      });
    }
  }

  Future<void> _loadUserCompaniesCount() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();

    final companyIds = (userDoc.data()?['companyIds'] as List?)?.length ?? 1;
    setState(() => _userCompaniesCount = companyIds);
  }

  Future<void> _loadAllOrders() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (mounted) context.go('/login');
      return;
    }

    if (mounted) setState(() => isLoading = true);

    try {
      final query = FirebaseFirestore.instance
          .collection('purchase_orders')
          .where('userId', isEqualTo: user.uid)
          .orderBy('orderDate', descending: true);

      final querySnapshot = await query.get();

      if (!mounted) return;

      _allOrders.clear();
      for (final doc in querySnapshot.docs) {
        final data = doc.data();
        final companyId = data['companyId'] as String? ?? '';
        final supplierId = data['supplierId'] as String? ?? '';

        final company = await _getCompanyName(companyId);
        final supplier = await _getSupplierName(supplierId);

        _allOrders.add({
          ...data,
          'id': doc.id,
          'companyName': company,
          'supplierName': supplier,
        });
      }

      _allOrders.sort((a, b) {
        final aDate = (a['orderDate'] as Timestamp).toDate();
        final bDate = (b['orderDate'] as Timestamp).toDate();
        return bDate.compareTo(aDate);
      });
    } catch (e) {
      debugPrint('Error loading orders: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('error_loading_orders'.tr())),
        );
      }
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  Future<String> _getCompanyName(String companyId) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('companies')
          .doc(companyId)
          .get();

      if (isArabic) {
        return doc.data()?['name_ar'] ?? companyId;
      } else {
        return doc.data()?['name_en'] ?? companyId;
      }
    } catch (e) {
      return companyId;
    }
  }

  Future<String> _getSupplierName(String supplierId) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('vendors')
          .doc(supplierId)
          .get();
      return doc.data()?['name'] ?? supplierId;
    } catch (e) {
      return supplierId;
    }
  }

  List<Map<String, dynamic>> _filterOrders(String query) {
    if (query.isEmpty) return _allOrders;
    final queryLower = query.toLowerCase();

    return _allOrders.where((order) {
      final poNumber =
          (order['poNumber'] ?? order['id']).toString().toLowerCase();
      final companyName = order['companyName'].toString().toLowerCase();
      final supplierName = order['supplierName'].toString().toLowerCase();
      final status = (order['status'] ?? 'pending').toString().toLowerCase();
      final timestamp = order['orderDate'] as Timestamp?;
      final dateMatch = _isDateMatch(timestamp, queryLower);

      return poNumber.contains(queryLower) ||
          companyName.contains(queryLower) ||
          supplierName.contains(queryLower) ||
          status.contains(queryLower) ||
          dateMatch;
    }).toList();
  }

  bool _isDateMatch(Timestamp? timestamp, String query) {
    if (timestamp == null) return false;

    final date = timestamp.toDate();
    final formats = [
      'yyyy-MM-dd',
      'dd-MM-yyyy',
      'dd/MM/yyyy',
      'yyyy/MM/dd',
      'MM-dd-yyyy',
      'MM/dd/yyyy',
    ];

    if (query.length <= 2 && date.day.toString().contains(query)) return true;
    if (query.length <= 2 && date.month.toString().contains(query)) return true;
    if (query.length == 4 && date.year.toString().contains(query)) return true;

    for (final format in formats) {
      if (DateFormat(format).format(date).toLowerCase().contains(query)) {
        return true;
      }
    }

    return false;
  }

  Color _getStatusColor(String? status) {
    switch (status?.toLowerCase()) {
      case 'completed':
        return Colors.green;
      case 'pending':
        return Colors.orange;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading || _allOrders.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: Text(tr('purchase_orders'))),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final filteredOrders = _filterOrders(searchQuery);

    return AppScaffold(
      title: tr('purchase_orders'),
      userName: userName,
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              decoration: InputDecoration(
                labelText: tr('search'),
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                hintText: tr('search_hint'),
              ),
              onChanged: (v) => setState(() => searchQuery = v.toLowerCase()),
            ),
          ),
          Expanded(
            child: _isSearching
                ? const Center(child: CircularProgressIndicator())
                : filteredOrders.isEmpty
                    ? Center(child: Text(tr('no_match_search')))
                    : ListView.builder(
                        itemCount: filteredOrders.length,
                        itemBuilder: (ctx, index) {
                          final order = filteredOrders[index];
                          final totalAmount =
                              (order['totalAmountAfterTax'] ?? 0.0)
                                  .toStringAsFixed(2);

                          return Card(
                            margin: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 8),
                            elevation: 3,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: BorderSide(
                                color: _getStatusColor(order['status'])
                                    .withAlpha(76),
                                width: 1.5,
                              ),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        order['poNumber'] ??
                                            'PO-${order['id']}',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color:
                                              _getStatusColor(order['status']),
                                          borderRadius:
                                              BorderRadius.circular(12),
                                        ),
                                        child: Text(
                                          (order['status'] ?? 'pending')
                                              .toString()
                                              .toUpperCase(),
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  if (_userCompaniesCount > 1)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 8),
                                      child: Row(
                                        children: [
                                          const Icon(Icons.business,
                                              size: 16, color: Colors.grey),
                                          const SizedBox(width: 8),
                                          Text(
                                            order['companyName'],
                                            style: TextStyle(
                                                color: Colors.grey.shade600),
                                          ),
                                        ],
                                      ),
                                    ),
                                  Padding(
                                    padding: const EdgeInsets.only(top: 4),
                                    child: Row(
                                      children: [
                                        const Icon(Icons.person,
                                            size: 16, color: Colors.grey),
                                        const SizedBox(width: 8),
                                        Text(
                                          order['supplierName'],
                                          style: TextStyle(
                                              color: Colors.grey.shade600),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const Divider(height: 16, thickness: 1),
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Row(
                                        children: [
                                          const Icon(Icons.calendar_today,
                                              size: 16, color: Colors.grey),
                                          const SizedBox(width: 8),
                                          Text(
                                            DateFormat('yyyy-MM-dd').format(
                                                (order['orderDate']
                                                        as Timestamp)
                                                    .toDate()),
                                            style: TextStyle(
                                                color: Colors.grey.shade700),
                                          ),
                                        ],
                                      ),
                                      Text(
                                        '$totalAmount ${tr('currency')}',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: Colors.blue,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    children: [
                                      IconButton(
                                        icon: const Icon(Icons.edit,
                                            size: 20, color: Colors.blue),
                                        onPressed: () => _editOrder(order),
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.picture_as_pdf,
                                            size: 20, color: Colors.green),
                                        onPressed: () => _exportOrder(order),
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.delete,
                                            size: 20, color: Colors.red),
                                        onPressed: () =>
                                            _confirmDeleteOrder(order),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          await context.push('/add-purchase-order');
          if (mounted) await _loadAllOrders();
        },
        tooltip: tr('add_purchase_order'),
        child: const Icon(Icons.add),
      ),
    );
  }

  Future<void> _editOrder(Map<String, dynamic> order) async {
    final result = await context.push('/add-purchase-order', extra: {
      'editMode': true,
      'orderData': order,
      'orderId': order['id'],
    });
    if (result == true && mounted) await _loadAllOrders();
  }

/*   Future<void> _exportOrder(Map<String, dynamic> order) async {
    setState(() => _isSearching = true);
    try {
      final compD = await FirebaseFirestore.instance
          .collection('companies')
          .doc(order['companyId'])
          .get();
      final vendD = await FirebaseFirestore.instance
          .collection('vendors')
          .doc(order['supplierId'])
          .get();

      final pdf = await PdfExporter.generatePurchaseOrderPdf(
        orderId: order['id'],
        orderData: order,
        supplierData: vendD.data() ?? {},
        companyData: compD.data() ?? {},
      );

      await Printing.layoutPdf(onLayout: (format) async => pdf);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('export_error'.tr())),
        );
      }
    } finally {
      if (mounted) setState(() => _isSearching = false);
    }
  }
 */

/*   Future<void> _exportOrder(Map<String, dynamic> order) async {
  setState(() => _isSearching = true);
  try {
    final compD = await FirebaseFirestore.instance
        .collection('companies')
        .doc(order['companyId'])
        .get();
    final vendD = await FirebaseFirestore.instance
        .collection('vendors')
        .doc(order['supplierId'])
        .get();

    final pdf = await generatePurchaseOrderPdf(
      orderId: order['id'],
      orderData: order,
      supplierData: vendD.data() ?? {},
      companyData: compD.data() ?? {},
    );

    // حفظ الملف محلياً ومشاركته
    final bytes = await pdf.save();
    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/order_${order['id']}.pdf');
    await file.writeAsBytes(bytes);
    
    await SharePlus.instance.share(
      files: [XFile(file.path)],
      text: 'invoice_share_message'.tr(),
      subject: 'invoice_subject'.tr(),
    );
  } catch (e) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('export_error'.tr())),
      );
    }
  } finally {
    if (mounted) setState(() => _isSearching = false);
  }
}
   */

/*   Future<void> _exportOrder(Map<String, dynamic> order) async {
    setState(() => _isSearching = true);
    try {
      final compD = await FirebaseFirestore.instance
          .collection('companies')
          .doc(order['companyId'])
          .get();
      final vendD = await FirebaseFirestore.instance
          .collection('vendors')
          .doc(order['supplierId'])
          .get();

      final pdf = await generatePurchaseOrderPdf(
        orderId: order['id'],
        orderData: order,
        supplierData: vendD.data() ?? {},
        companyData: compD.data() ?? {},
      );

      // Save file locally and share
      final bytes = await pdf.save();
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/order_${order['id']}.pdf');
      await file.writeAsBytes(bytes);

      await Share.shareXFiles(
        [XFile(file.path)],
        text: 'invoice_share_message'.tr(),
        subject: 'invoice_subject'.tr(),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('export_error'.tr())),
        );
      }
    } finally {
      if (mounted) setState(() => _isSearching = false);
    }
  }

 */


Future<void> _exportOrder(Map<String, dynamic> order) async {
  setState(() => _isSearching = true);
  try {
    final compD = await FirebaseFirestore.instance
        .collection('companies')
        .doc(order['companyId'])
        .get();
    final vendD = await FirebaseFirestore.instance
        .collection('vendors')
        .doc(order['supplierId'])
        .get();

    final pdf = await generatePurchaseOrderPdf(
      orderId: order['id'],
      orderData: order,
      supplierData: vendD.data() ?? {},
      companyData: compD.data() ?? {},
    );

    // خيار 1: الطباعة المباشرة (إذا كانت المكتبة متوفرة)
    await Printing.layoutPdf(
      onLayout: (_) => pdf.save(),
    );

    // خيار 2: حفظ ومشاركة الملف (كما هو موجود حالياً)
    final bytes = await pdf.save();
    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/order_${order['id']}.pdf');
    await file.writeAsBytes(bytes);

    await Share.shareXFiles(
      [XFile(file.path)],
      text: 'invoice_share_message'.tr(),
      subject: 'invoice_subject'.tr(),
    );
  } catch (e) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('export_error'.tr(args: [e.toString()]))),
      );
    }
    debugPrint('PDF Export Error: $e');
  } finally {
    if (mounted) setState(() => _isSearching = false);
  }
}


  Future<void> _confirmDeleteOrder(Map<String, dynamic> order) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(tr('confirm_delete_title')),
        content: Text(tr('confirm_delete_message')),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(tr('cancel'))),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child:
                Text(tr('delete'), style: const TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      setState(() => _isSearching = true);
      try {
        await FirebaseFirestore.instance
            .collection('purchase_orders')
            .doc(order['id'])
            .delete();

        await _loadAllOrders();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('delete_error'.tr())),
          );
        }
      } finally {
        if (mounted) setState(() => _isSearching = false);
      }
    }
  }
} */


/* import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:printing/printing.dart';
import 'package:puresip_purchasing/widgets/app_scaffold.dart';
import 'package:puresip_purchasing/utils/pdf_exporter.dart';

class PurchaseOrdersPage extends StatefulWidget {
  const PurchaseOrdersPage({super.key});

  @override
  State<PurchaseOrdersPage> createState() => _PurchaseOrdersPageState();
}

class _PurchaseOrdersPageState extends State<PurchaseOrdersPage> {
  String searchQuery = '';
  bool isLoading = true;
  String? userName;
  List<String> userOrderIds = [];
  final List<Map<String, dynamic>> _allOrders = [];
  bool _isSearching = false;
  bool get isArabic => Localizations.localeOf(context).languageCode == 'ar';

  /*  @override
  void initState() {
    super.initState();
    loadUserInfo();
    loadUserOrders();
  }
 */
  Future<void> loadUserInfo() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final email = user.email ?? '';
      final name = user.displayName ?? '';
      setState(() {
        userName = name.isNotEmpty ? name : email.split('@')[0];
      });
    }
  }

/*   Future<void> loadUserOrders() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (mounted) context.go('/login');
      return;
    }

    setState(() {
      isLoading = true;
    });

    try {
      final query = await FirebaseFirestore.instance
          .collection('purchase_orders')
          .where('userId', isEqualTo: user.uid)
          //    .orderBy('orderDate', descending: true)
          .get();

      if (!mounted) return;

      userOrderIds = query.docs.map((doc) => doc.id).toList();

      debugPrint('Loaded order IDs for user: $userOrderIds');

      setState(() {
        isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading orders: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('error_loading_orders'.tr())),
        );
        setState(() {
          isLoading = false;
        });
      }
    }
  } */

  Future<void> _loadAllOrders() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (mounted) context.go('/login');
      return;
    }

    if (mounted) setState(() => isLoading = true);

    try {
      final query = FirebaseFirestore.instance
          .collection('purchase_orders')
          .where('userId', isEqualTo: user.uid)
          .orderBy('orderDate', descending: true);

      final querySnapshot = await query.get();

      if (!mounted) return;

      _allOrders.clear();
      for (final doc in querySnapshot.docs) {
        final data = doc.data();
        // تحقق من أن البيانات ليست فارغة
        final companyId = data['companyId'] as String? ?? '';
        final supplierId = data['supplierId'] as String? ?? '';

        final company = await _getCompanyName(companyId);
        final supplier = await _getSupplierName(supplierId);

        _allOrders.add({
          ...data, // استخدام الناشر الآمن للقيم الفارغة
          'id': doc.id,
          'companyName': company,
          'supplierName': supplier,
        });
            }

      // فرز النتائج يدوياً إذا لزم الأمر
      _allOrders.sort((a, b) {
        final aDate =
            (a['orderDate'] as Timestamp?)?.toDate() ?? DateTime.now();
        final bDate =
            (b['orderDate'] as Timestamp?)?.toDate() ?? DateTime.now();
        return bDate.compareTo(aDate);
      });
    } catch (e) {
      debugPrint('Error loading orders: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('error_loading_orders'.tr())),
        );
      }
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

/*    Future<void> _loadAllOrders() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final query = await FirebaseFirestore.instance
          .collection('purchase_orders')
          .where('userId', isEqualTo: user.uid)
          .orderBy('orderDate', descending: true)
          .get();

      _allOrders.clear();
      for (final doc in query.docs) {
        final data = doc.data();// as Map<String, dynamic>;
        final company = await _getCompanyName(data['companyId']);
        final supplier = await _getSupplierName(data['supplierId']);
        
        _allOrders.add({
          ...data,
          'id': doc.id,
          'companyName': company,
          'supplierName': supplier,
        });
      }

      if (mounted) setState(() {});
    } catch (e) {
      debugPrint('Error loading orders: $e');
    }
  }
 */
  /* Future<String> _getCompanyName(String companyId) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('companies')
          .doc(companyId)
          .get();
      return isArabic ? doc.data()?['name_ar'] ?? companyId 
                   : doc.data()?['name_en'] ?? companyId;
    } catch (e) {
      return companyId;
    }
  } */

  Future<String> _getCompanyName(String companyId) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('companies')
          .doc(companyId)
          .get();

      if (isArabic) {
        return doc.data()?['name_ar'] ?? companyId;
      } else {
        return doc.data()?['name_en'] ?? companyId;
      }
    } catch (e) {
      return companyId;
    }
  }

  Future<String> _getSupplierName(String supplierId) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('vendors')
          .doc(supplierId)
          .get();
      return doc.data()?['name'] ?? supplierId;
    } catch (e) {
      return supplierId;
    }
  }

  List<Map<String, dynamic>> _filterOrders(String query) {
    if (query.isEmpty) return _allOrders;
  final queryLower = query.toLowerCase();

    return _allOrders.where((order) {
      final poNumber =
          (order['poNumber'] ?? order['id']).toString().toLowerCase();
      final companyName = order['companyName'].toString().toLowerCase();
      final supplierName = order['supplierName'].toString().toLowerCase();
      // final orderDate = DateFormat('yyyy-MM-dd')
      //     .format((order['orderDate'] as Timestamp).toDate())
      //     .toLowerCase();
      final status = (order['status'] ?? 'pending').toString().toLowerCase();
      final timestamp = order['orderDate'] as Timestamp?;
      final dateMatch = _isDateMatch(timestamp, queryLower);

      return poNumber.contains(query) ||
          companyName.contains(query) ||
          supplierName.contains(query) ||
          //orderDate.contains(query) ||
          status.contains(query) ||
           dateMatch;
    }).toList();
  }
  // دالة مساعدة للبحث المرن بالتاريخ
bool _isDateMatch(Timestamp? timestamp, String query) {
  if (timestamp == null) return false;
  
  final date = timestamp.toDate();
  final formats = [
    'yyyy-MM-dd', // 2023-12-31
    'dd-MM-yyyy', // 31-12-2023
    'dd/MM/yyyy', // 31/12/2023
    'yyyy/MM/dd', // 2023/12/31
    'MM-dd-yyyy', // 12-31-2023
    'MM/dd/yyyy', // 12/31/2023
  ];

  // البحث بأي جزء من التاريخ (يوم، شهر، سنة)
  if (query.length <= 2 && date.day.toString().contains(query)) return true;
  if (query.length <= 2 && date.month.toString().contains(query)) return true;
  if (query.length == 4 && date.year.toString().contains(query)) return true;

  // البحث بالتنسيقات الكاملة
  for (final format in formats) {
    if (DateFormat(format).format(date).toLowerCase().contains(query)) {
      return true;
    }
  }
  
  return false;
}

  @override
  void initState() {
    super.initState();
    loadUserInfo();
    //  loadUserOrders();
    _loadAllOrders();
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading || _allOrders.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: Text(tr('purchase_orders'))),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final filteredOrders = _filterOrders(searchQuery);

    return AppScaffold(
      title: tr('purchase_orders'),
      userName: userName,
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              decoration: InputDecoration(
                labelText: tr('search'),
                prefixIcon: const Icon(Icons.search),
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onChanged: (v) => setState(() => searchQuery = v.toLowerCase()),
            ),
          ),
          Expanded(
            child: _isSearching
                ? const Center(child: CircularProgressIndicator())
                : filteredOrders.isEmpty
                    ? Center(child: Text(tr('no_match_search')))
                    : ListView.builder(
                        itemCount: filteredOrders.length,
                        itemBuilder: (ctx, index) {
                          final order = filteredOrders[index];
                          final totalAmount =
                              (order['totalAmountAfterTax'] ?? 0.0)
                                  .toStringAsFixed(2);

                          return Card(
                            margin: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 6),
                            child: ListTile(
                              title:
                                  Text(order['poNumber'] ?? '${order['id']}'),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                      '${tr('company')}: ${order['companyName']}'),
                                  Text(
                                      '${tr('supplier')}: ${order['supplierName']}'),
                                  Text(
                                      '${tr('date')}: ${DateFormat('yyyy-MM-dd').format((order['orderDate'] as Timestamp).toDate())}'),
                                  Text(
                                      '${tr('total')}: $totalAmount ${tr('currency')}'),
                                  Text(
                                      '${tr('status')}: ${order['status'] ?? 'pending'}'),
                                ],
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.edit,
                                        color: Colors.blue),
                                    onPressed: () => _editOrder(order),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.picture_as_pdf,
                                        color: Colors.green),
                                    onPressed: () => _exportOrder(order),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete,
                                        color: Colors.red),
                                    onPressed: () => _confirmDeleteOrder(order),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          await context.push('/add-purchase-order');
          if (mounted) await _loadAllOrders();
        },
        tooltip: tr('add_purchase_order'),
        child: const Icon(Icons.add),
      ),
    );
  }

  Future<void> _editOrder(Map<String, dynamic> order) async {
    final result = await context.push('/add-purchase-order', extra: {
      'editMode': true,
      'orderData': order,
      'orderId': order['id'],
    });
    if (result == true && mounted) await _loadAllOrders();
  }

  Future<void> _exportOrder(Map<String, dynamic> order) async {
    setState(() => _isSearching = true);
    try {
      final compD = await FirebaseFirestore.instance
          .collection('companies')
          .doc(order['companyId'])
          .get();
      final vendD = await FirebaseFirestore.instance
          .collection('vendors')
          .doc(order['supplierId'])
          .get();

      final pdf = await PdfExporter.generatePurchaseOrderPdf(
        orderId: order['id'],
        orderData: order,
        supplierData: vendD.data() ?? {},
        companyData: compD.data() ?? {},
      );

      await Printing.layoutPdf(onLayout: (format) async => pdf);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('export_error'.tr())),
        );
      }
    } finally {
      if (mounted) setState(() => _isSearching = false);
    }
  }

  Future<void> _confirmDeleteOrder(Map<String, dynamic> order) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(tr('confirm_delete_title')),
        content: Text(tr('confirm_delete_message')),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(tr('cancel'))),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child:
                Text(tr('delete'), style: const TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      setState(() => _isSearching = true);
      try {
        await FirebaseFirestore.instance
            .collection('purchase_orders')
            .doc(order['id'])
            .delete();

        await _loadAllOrders();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('delete_error'.tr())),
          );
        }
      } finally {
        if (mounted) setState(() => _isSearching = false);
      }
    }
  }
}
 */
/* 
  Future<void> _confirmDeleteOrder(DocumentSnapshot orderDoc) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(tr('confirm_delete_title')),
        content: Text(tr('confirm_delete_message')),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(tr('cancel'))),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child:
                Text(tr('delete'), style: const TextStyle(color: Colors.red)),
          )
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await orderDoc.reference.delete();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(tr('order_deleted'))),
          );
          await loadUserOrders();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('delete_error'.tr())),
          );
        }
      }
    }
  }

  Future<void> _editOrder(DocumentSnapshot orderDoc) async {
    final data = orderDoc.data() as Map<String, dynamic>;
    await context.push('/add-purchase-order', extra: {
      'editMode': true,
      'orderData': data,
      'orderId': orderDoc.id,
    });
    if (mounted) loadUserOrders();
  }

  Future<void> _exportOrder(DocumentSnapshot orderDoc) async {
    final data = orderDoc.data() as Map<String, dynamic>;
    try {
      final compD = await FirebaseFirestore.instance
          .collection('companies')
          .doc(data['companyId'])
          .get();
      final vendD = await FirebaseFirestore.instance
          .collection('vendors')
          .doc(data['supplierId'])
          .get();

      final pdf = await PdfExporter.generatePurchaseOrderPdf(
        orderId: orderDoc.id,
        orderData: data,
        supplierData: vendD.data() ?? {},
        companyData: compD.data() ?? {},
      );

      await Printing.layoutPdf(onLayout: (format) async => pdf);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('export_error'.tr())),
        );
      }
    }
  }

  Future<Map<String, String>> _getCompanyAndSupplierNames(
      String orderId) async {
    try {
      final orderDoc = await FirebaseFirestore.instance
          .collection('purchase_orders')
          .doc(orderId)
          .get();

      final orderData = orderDoc.data() as Map<String, dynamic>;
      final companyId = orderData['companyId'];
      final supplierId = orderData['supplierId'];

      final companyFuture = FirebaseFirestore.instance
          .collection('companies')
          .doc(companyId)
          .get();

      final supplierFuture = FirebaseFirestore.instance
          .collection('vendors')
          .doc(supplierId)
          .get();

      final results = await Future.wait([companyFuture, supplierFuture]);

      return {
        'companyName': results[0].data()?['name_ar'] ?? 'غير معروف',
        'supplierName': results[1].data()?['name'] ?? 'غير معروف',
      };
    } catch (e) {
      debugPrint('Error fetching names: $e');
      return {
        'companyName': 'غير معروف',
        'supplierName': 'غير معروف',
      };
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Scaffold(
        appBar: AppBar(title: Text(tr('purchase_orders'))),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (userOrderIds.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: Text(tr('purchase_orders'))),
        body: Center(child: Text(tr('no_orders_found'))),
      );
    }

    return AppScaffold(
      title: tr('purchase_orders'),
      userName: userName,
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              decoration: InputDecoration(
                labelText: tr('search'),
                prefixIcon: const Icon(Icons.search),
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onChanged: (v) => setState(() => searchQuery = v.toLowerCase()),
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('purchase_orders')
                  .where(FieldPath.documentId, whereIn: userOrderIds)
                  .orderBy('orderDate', descending: true)
                  .snapshots(),
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snap.hasError) {
                  debugPrint('StreamBuilder error: ${snap.error}');
                  return Center(
                      child: Text('${tr('error_occurred')}: ${snap.error}'));
                }

                final orders = (snap.data?.docs ?? []).where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final poNumber =
                      (data['poNumber'] ?? doc.id).toString().toLowerCase();
                  final orderDate = DateFormat('yyyy-MM-dd')
                      .format((data['orderDate'] as Timestamp).toDate())
                      .toLowerCase();
                  final status =
                      (data['status'] ?? 'pending').toString().toLowerCase();

                  return poNumber.contains(searchQuery) ||
                      orderDate.contains(searchQuery) ||
                      status.contains(searchQuery);
                }).toList();

                if (orders.isEmpty) {
                  return Center(child: Text(tr('no_match_search')));
                }

                return ListView.builder(
                  itemCount: orders.length,
                  itemBuilder: (ctx, index) {
                    final doc = orders[index];
                    final data = doc.data() as Map<String, dynamic>;
                    final totalAmount =
                        (data['totalAmountAfterTax'] ?? 0.0).toStringAsFixed(2);

                    return FutureBuilder<Map<String, String>>(
                      future: _getCompanyAndSupplierNames(doc.id),
                      builder: (context, nameSnapshot) {
                        if (nameSnapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const Center(
                              child: CircularProgressIndicator());
                        }

                        final names = nameSnapshot.data ??
                            {
                              'companyName': 'جاري التحميل...',
                              'supplierName': 'جاري التحميل...'
                            };

                        return Card(
                          margin: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          child: ListTile(
                            title: Text(data['poNumber'] ?? 'PO-${doc.id}'),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                    '${tr('company')}: ${names['companyName']}'),
                                Text(
                                    '${tr('supplier')}: ${names['supplierName']}'),
                                Text(
                                    '${tr('date')}: ${DateFormat('yyyy-MM-dd').format((data['orderDate'] as Timestamp).toDate())}'),
                                Text(
                                    '${tr('total')}: $totalAmount ${tr('currency')}'),
                                Text(
                                    '${tr('status')}: ${data['status'] ?? 'pending'}'),
                              ],
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.edit,
                                      color: Colors.blue),
                                  onPressed: () => _editOrder(doc),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.picture_as_pdf,
                                      color: Colors.green),
                                  onPressed: () => _exportOrder(doc),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete,
                                      color: Colors.red),
                                  onPressed: () => _confirmDeleteOrder(doc),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          await context.push('/add-purchase-order');
          if (mounted) await loadUserOrders();
        },
        tooltip: tr('add_purchase_order'),
        child: const Icon(Icons.add),
      ),
    );
  }
}
 */
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
    _loadUserId().then((_) => _verifyUserAccess());
    _loadFilterOptions();
    //_purchaseOrdersStream(); // تأكد إنها هنا أو في build عبر StreamBuilder
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
      if (selectedCompanyFilter == null && userCompanyIds.isNotEmpty) {
        selectedCompanyFilter = userCompanyIds.first;
      }
    });

    debugPrint('User $_userId has access to companies: $userCompanyIds');
    debugPrint('Trying to access company: $selectedCompanyFilter');
  }

  Future<void> _loadFilterOptions() async {
    if (_userId == null) return;

    final userDoc =
        await FirebaseFirestore.instance.collection('users').doc(_userId).get();
    final userCompanyIds =
        (userDoc.data()?['companyIds'] as List?)?.cast<String>() ?? [];

    final companiesSnap = await FirebaseFirestore.instance
        .collection('companies')
        .where(FieldPath.documentId, whereIn: userCompanyIds)
        .get();

    final vendorsSnap =
        await FirebaseFirestore.instance.collection('vendors').get();
    final itemsSnap =
        await FirebaseFirestore.instance.collectionGroup('items').get();
    final factoriesSnap =
        await FirebaseFirestore.instance.collection('factories').get();
      debugPrint('Loaded companies: $allCompanies');
      debugPrint('Loaded suppliers: $allSuppliers');
      debugPrint('Loaded items: $allItems');
      debugPrint('Loaded factories: $allFactories');
    setState(() {
      allCompanies = companiesSnap.docs
          .map((d) => {'id': d.id, 'name_ar': d['name_ar'] ?? d.id})
          .toList();

      allSuppliers = vendorsSnap.docs
          .map((d) => d['name']?.toString() ?? d.id)
          .toSet()
          .toList();

      allItems = itemsSnap.docs
          .map((d) => d['name_en']?.toString() ?? '')
          .toSet()
          .toList();

      allFactories = factoriesSnap.docs
          .map((d) => {'id': d.id, 'name_ar': d['name_ar'] ?? d.id})
          .toList();

      debugPrint('Loaded companies: $allCompanies');
      debugPrint('Loaded suppliers: $allSuppliers');
      debugPrint('Loaded items: $allItems');
      debugPrint('Loaded factories: $allFactories');
    });
  }

  Future<void> deleteOrder(String orderId) async {
    try {
      final ref =
          FirebaseFirestore.instance.collection('purchase_orders').doc(orderId);
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

/*   Stream<QuerySnapshot> _purchaseOrdersStream() {
    debugPrint('Stream requested for company: $selectedCompanyFilter');

    if (selectedCompanyFilter != null && selectedCompanyFilter!.isNotEmpty) {
      try {
        final stream = FirebaseFirestore.instance
            .collection('purchase_orders')
            .where('companyId', isEqualTo: selectedCompanyFilter!)
            .orderBy('createdAt', descending: true)
            .snapshots();

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
  } */

  Stream<QuerySnapshot> _purchaseOrdersStream() {
    debugPrint(
        'Loading orders for user: $_userId and company: $selectedCompanyFilter');
    if (_userId == null || selectedCompanyFilter == null) {
      return const Stream.empty();
    }
    try {
      final stream = FirebaseFirestore.instance
          .collection('purchase_orders')
          .where('userId', isEqualTo: _userId)
          .orderBy('orderDate', descending: true)
          .snapshots();
      debugPrint('Loading stream for user====> : $stream');
      stream.listen(
        (querySnapshot) =>
            debugPrint('Got ${querySnapshot.docs.length} orders for user'),
        onError: (e) => debugPrint('Stream error: $e'),
      );

      return stream;
    } catch (e) {
      debugPrint('Error creating stream: $e');
      return const Stream.empty();
    }
  }

  @override
  Widget build(BuildContext context) {
    debugPrint('Current selected company: $selectedCompanyFilter');

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
                              onDelete: () => deleteOrder(doc.id),
                              onExport: () async {
                                final compD = await FirebaseFirestore.instance
                                    .collection('companies')
                                    .doc(data['companyId'])
                                    .get();
                                final vendD = await FirebaseFirestore.instance
                                    .collection('vendors')
                                    .doc(data['supplierId'])
                                    .get();
                                final pdf =
                                    await PdfExporter.generatePurchaseOrderPdf(
                                  orderId: doc.id,
                                  orderData: {
                                    ...data,
                                  },
                                  supplierData: vendD.data() ?? {},
                                  companyData: compD.data() ?? {},
                                );
                                await Printing.layoutPdf(
                                    onLayout: (format) async => pdf);
                              },
                              poNumber: data['poNumber'] ?? doc.id,
                              supplierName: data['supplierName'] ?? 'Unknown',
                              isArabic: data['isArabic'] ?? false,
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
 
/* 
import 'package:flutter/material.dart';
import 'package:puresip_purchasing/models/purchase_order.dart';
import 'package:puresip_purchasing/services/purchase_order_service.dart';
import 'package:puresip_purchasing/utils/purchase_order_utils.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:puresip_purchasing/utils/user_local_storage.dart';

class PurchaseOrdersPage extends StatefulWidget {
  const PurchaseOrdersPage({super.key});

  @override
  State<PurchaseOrdersPage> createState() => _PurchaseOrdersPageState();
}

class _PurchaseOrdersPageState extends State<PurchaseOrdersPage> {
  List<Item> _items = [];
  double _taxRate = 14.0;

  final _formKey = GlobalKey<FormState>();

  // Controllers
  final _itemNameController = TextEditingController();
  final _itemQtyController = TextEditingController();
  final _itemUnitController = TextEditingController();
  final _itemPriceController = TextEditingController();

  // بيانات المستخدم
  String? _userId;
  String? _companyId;
  String? _factoryId;

  @override
  void initState() {
    super.initState();
    _loadUserContext();
  }

  Future<void> _loadUserContext() async {
    final user = await UserLocalStorage.getUser();
    _userId = user?['userId'];

    _companyId = await UserLocalStorage.getCurrentCompanyId();
    _factoryId = await UserLocalStorage.getCurrentFactoryId();
    setState(() {});
  }

  void _addItem() {
    final name = _itemNameController.text.trim();
    final qty = double.tryParse(_itemQtyController.text) ?? 0.0;
    final unit = _itemUnitController.text.trim();
    final price = double.tryParse(_itemPriceController.text) ?? 0.0;

    if (name.isEmpty || qty <= 0 || price <= 0 || unit.isEmpty) return;

    final total = qty * price;
    final tax = total * (_taxRate / 100);
    final totalWithTax = total + tax;

    final item = Item(
      itemId: 'item-${DateTime.now().millisecondsSinceEpoch}',
      name: name,
      quantity: qty,
      unit: unit,
      unitPrice: price,
      totalPrice: total,
      taxAmount: tax,
      totalAfterTaxAmount: totalWithTax,
    );

    setState(() {
      _items.add(item);
      _itemNameController.clear();
      _itemQtyController.clear();
      _itemUnitController.clear();
      _itemPriceController.clear();
    });
  }

  void _submit() async {
    if (_items.isEmpty || _userId == null || _companyId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr('missing_required_info'))),
      );
      return;
    }

    final recalculatedItems = PurchaseOrderUtils.recalculateItemsWithTax(
      items: _items,
      taxRate: _taxRate,
    );

    final order = PurchaseOrder(
      id: 'PO-${DateTime.now().millisecondsSinceEpoch}',
      userId: _userId!,
      companyId: _companyId!,
      factoryId: _factoryId,
      supplierId: 'supplier-1', // لاحقًا يمكن جعله قابل للاختيار
      orderDate: DateTime.now(),
      deliveryDate: null,
      status: 'pending',
      items: recalculatedItems,
      totalAmount: PurchaseOrderUtils.calculateTotal(recalculatedItems),
      totalTax: PurchaseOrderUtils.calculateTotalTax(recalculatedItems),
      totalAmountAfterTax:
          PurchaseOrderUtils.calculateTotalAfterTax(recalculatedItems),
      isDelivered: false,
      deliveryNotes: null,
      taxRate: _taxRate,
      finishedProductId: null,
    );

    await PurchaseOrderService.createPurchaseOrder(order);
if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(tr('purchase_order_saved'))),
    );

    setState(() {
      _items = [];
    });
  }

  @override
  Widget build(BuildContext context) {
    final total = PurchaseOrderUtils.calculateTotal(_items);
    final totalTax = PurchaseOrderUtils.calculateTotalTax(_items);
    final totalAfterTax = PurchaseOrderUtils.calculateTotalAfterTax(_items);

    return Scaffold(
      appBar: AppBar(title: Text(tr('create_purchase_order'))),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextFormField(
              initialValue: _taxRate.toString(),
              keyboardType: TextInputType.number,
              decoration: InputDecoration(labelText: tr('tax_rate')),
              onChanged: (val) {
                setState(() {
                  _taxRate = double.tryParse(val) ?? 14.0;
                });
              },
            ),
            const SizedBox(height: 20),
            // ➕ إضافة صنف
            Form(
              key: _formKey,
              child: Column(
                children: [
                  Row(children: [
                    Expanded(
                      child: TextFormField(
                        controller: _itemNameController,
                        decoration: InputDecoration(labelText: tr('item_name')),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextFormField(
                        controller: _itemQtyController,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(labelText: tr('quantity')),
                      ),
                    ),
                  ]),
                  const SizedBox(height: 8),
                  Row(children: [
                    Expanded(
                      child: TextFormField(
                        controller: _itemUnitController,
                        decoration: InputDecoration(labelText: tr('unit')),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextFormField(
                        controller: _itemPriceController,
                        keyboardType: TextInputType.number,
                        decoration:
                            InputDecoration(labelText: tr('unit_price')),
                      ),
                    ),
                  ]),
                  const SizedBox(height: 10),
                  ElevatedButton.icon(
                    onPressed: _addItem,
                    icon: const Icon(Icons.add),
                    label: Text(tr('add_item')),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: ListView.builder(
                itemCount: _items.length,
                itemBuilder: (_, index) {
                  final item = _items[index];
                  return ListTile(
                    title: Text('${item.name} - ${item.quantity} ${item.unit}'),
                    subtitle: Text(
                        '${tr('tax')}: ${item.taxAmount.toStringAsFixed(2)}'),
                    trailing:
                        Text(item.totalAfterTaxAmount.toStringAsFixed(2)),
                  );
                },
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('${tr('total')}: ${total.toStringAsFixed(2)}'),
                Text('${tr('total_tax')}: ${totalTax.toStringAsFixed(2)}'),
                Text(
                    '${tr('total_after_tax')}: ${totalAfterTax.toStringAsFixed(2)}'),
              ],
            ),
            const SizedBox(height: 10),
            ElevatedButton.icon(
              onPressed: _submit,
              icon: const Icon(Icons.save),
              label: Text(tr('save_order')),
              style: ElevatedButton.styleFrom(
                  minimumSize: const Size.fromHeight(50)),
            ),
          ],
        ),
      ),
    );
  }
}
 */