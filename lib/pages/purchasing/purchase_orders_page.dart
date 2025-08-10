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
import 'package:puresip_purchasing/widgets/app_scaffold.dart';
import 'package:puresip_purchasing/widgets/hover_add_button.dart';
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
  List<Map<String, dynamic>> _userCompanies = [];
  String? _selectedCompanyId;

  //bool get isArabic => Localizations.localeOf(context).languageCode == 'ar';
  late bool _isArabic;

  @override
  void initState() {
    super.initState();
    //_initData();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  bool _isDataLoaded = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (!_isDataLoaded) {
      _isDataLoaded = true;
        setState(() {
   _isArabic = context.locale.languageCode == 'ar';// Localizations.localeOf(context).languageCode == 'ar';
  });
      debugPrint("Current language is Arabic? $_isArabic");
      _initData(); // الدالة التي كانت تُستدعى في initState
    }
  }

  Future<void> _initData() async {
    //   _isArabic = Localizations.localeOf(context).languageCode == 'ar';
    await loadUserInfo();
    await _loadUserCompaniesCount();
    await _loadAllOrders();
    await _loadUserCompanies();
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

  Future<void> _loadUserCompanies() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();
    final List companyIds = doc.data()?['companyIds'] ?? [];

    final futures = companyIds.map((id) async {
      final companyDoc = await FirebaseFirestore.instance
          .collection('companies')
          .doc(id)
          .get();
      return {
        'id': id,
        'name': _isArabic
            ? companyDoc['nameAr'] ?? id
            : companyDoc['nameEn'] ?? id,
      };
    }).toList();

    _userCompanies = await Future.wait(futures);
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
    //debugPrint('User companies count: $_userCompaniesCount');
  }

  Future<String> _getCompanyName(String companyId, bool isArabic) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('companies')
          .doc(companyId)
          .get();

      if (isArabic) {
        return doc.data()?['nameAr'] ?? companyId;
      } else {
        return doc.data()?['nameEn'] ?? companyId;
      }
    } catch (e) {
      return companyId;
    }
  }

  Future<String> _getSupplierName(String supplierId, bool isArabic) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('vendors')
          .doc(supplierId)
          .get();
      if (isArabic) {
        return doc.data()?['nameAr'] ?? supplierId;
      } else {
        return doc.data()?['nameEn'] ?? supplierId;
      }
    } catch (e) {
      return supplierId;
    }
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

        final company = await _getCompanyName(companyId, _isArabic);
        final supplier = await _getSupplierName(supplierId, _isArabic);

          // نحضّر نسخة قابلة للترميز بالكامل
        final cleanedData = Map<String, dynamic>.from(data);

          // تأكد من تحويل كل Timestamps إلى int
        if (cleanedData['orderDate'] is Timestamp) {
          cleanedData['orderDate'] =
              (cleanedData['orderDate'] as Timestamp).millisecondsSinceEpoch;
        }

        // تحويل Timestamp إلى milliseconds منذ epoch
        final orderData = {
          ...cleanedData,
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
    _filteredOrders.clear();
    _filteredOrders.addAll(_allOrders.where((order) {
      final matchesQuery = [
        (order['poNumber'] ?? '').toString().toLowerCase(),
        (order['supplierName'] ?? '').toString().toLowerCase(),
        (order['companyName'] ?? '').toString().toLowerCase(),
        (order['status'] ?? '').toString().toLowerCase(),
      ].any((field) => field.contains(query.toLowerCase()));

      final matchesCompany = _selectedCompanyId == null ||
          order['companyId'] == _selectedCompanyId;

      return matchesQuery && matchesCompany;
    }));
  }

  void _showCompanySelector() {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.all_inclusive),
              title: Text('show_all'.tr()),
              onTap: () {
                Navigator.pop(context);
                setState(() {
                  _selectedCompanyId = null;
                  _filterOrders(searchQuery);
                });
              },
            ),
            ..._userCompanies.map((company) => ListTile(
                  leading: const Icon(Icons.business),
                  title: Text(company['name']),
                  onTap: () {
                    Navigator.pop(context);
                    setState(() {
                      _selectedCompanyId = company['id'];
                      _filterOrders(searchQuery);
                    });
                  },
                )),
          ],
        ),
      ),
    );
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
    context.push('/purchase/${order['id']}');
  }

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

      // تحديث order بعد تعديل العناصر
      //   order['items'] = orderItems;
      final companyDataMap = companyData.data() ?? {};
      final base64Logo = companyDataMap['logoBase64'] as String?;

      final pdf = await PdfExporter.generatePurchaseOrderPdf(
        orderId: order['id'],
        orderData: order,
        supplierData: supplierData.data() ?? {},
        companyData: companyData.data() ?? {},
        itemData: {
          'items': order['items'],
        }, //itemsDataMap,
        base64Logo: base64Logo,
        isArabic: _isArabic,
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
        // onTap: () => context.push('/purchase/${order['id']}'),
        onTap: () => context.push(
          '/purchase/${order['id']}', // أو إذا كان order['id']، فتأكد أنها Map
          extra: order, // هذا تمرير كائن كامل
        ),

        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    order['poNumber'] ?? '${order['id']}',
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
                  if (order['status'] == 'pending')
                    IconButton(
                      icon:
                          const Icon(Icons.edit, size: 20, color: Colors.blue),
                      tooltip: 'edit'.tr(),
                      onPressed: () => _editOrder(order),
                    ),
                  IconButton(
                    icon: const Icon(Icons.picture_as_pdf,
                        size: 20, color: Colors.green),
                    tooltip: 'export_pdf'.tr(),
                    onPressed: () => _exportOrder(order),
                  ),
                  if (order['status'] == 'pending')
                    IconButton(
                      icon:
                          const Icon(Icons.delete, size: 20, color: Colors.red),
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
    debugPrint('User companies count: $_userCompaniesCount');

    return Directionality(
      textDirection: Directionality.of(context),
      child: AppScaffold(
        title: 'purchase_orders'.tr(),
        actions: [
          HoverAddButton(
            onPressed: () async {
              final result = await context.push('/add-purchase-order');
              if (result == true && mounted) await _loadAllOrders();
              _filterOrders(searchQuery);
            },
            tooltip: 'add_purchase_order'.tr(),
            iconColor: Colors.white,
            iconSize: 28,
          ),
        ],
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 8), // const EdgeInsets.all(12),
              child: Row(
                children: [
                  Expanded(
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
                  const SizedBox(width: 8),
                  if (_userCompaniesCount > 1)
                    IconButton(
                      icon: const Icon(Icons.business),
                      tooltip: 'multiple_companies'.tr(),
                      onPressed: _showCompanySelector,
                    ),
                  IconButton(
                    icon: const Icon(Icons.sort),
                    onPressed: _showSortOptions,
                    tooltip: 'sort_options'.tr(),
                  ),
                ],
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
      ),
    );
  }
}


/*         actions: [
              IconButton(
      icon: const Icon(Icons.add),
      tooltip: tr('add_purchase_order'),
      onPressed: () async {
        final result = await context.push('/add-purchase-order');
        if (result == true && mounted) await _loadAllOrders();
        _filterOrders(searchQuery);
      },
    ),
        ], */
/*         actions: [
          if (_userCompaniesCount > 1)
            IconButton(
              icon: const Icon(Icons.business),
              tooltip: 'multiple_companies'.tr(),
              onPressed: _showCompanySelector,
            ),
          IconButton(
            icon: const Icon(Icons.sort),
            onPressed: _showSortOptions,
            tooltip: 'sort_options'.tr(),
          ),
        ], */
       
/*       // تجهيز عناصر الطلب مع أسماء الأصناف من قاعدة البيانات
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
              item['nameAr'] = itemData?['nameAr'] ?? 'غير متوفر';
              item['nameEn'] = itemData?['nameEn'] ?? 'Not available';
              itemsDataMap[itemId] = itemData;
            } else {
              debugPrint('Item document $itemId does not exist');
              item['nameAr'] = 'صنف غير موجود';
              item['nameEn'] = 'Item not found';
            }
          } catch (e) {
            debugPrint('Error fetching item $itemId: $e');
            item['nameAr'] = 'خطأ في جلب البيانات';
            item['nameEn'] = 'Error loading data';
          }
        } else {
          item['nameAr'] = 'لا يوجد كود صنف';
          item['nameEn'] = 'No item code';
        }
      } */
/*         floatingActionButton: FloatingActionButton(
          onPressed: () async {
            final result = await context.push('/add-purchase-order');
            if (result == true && mounted) await _loadAllOrders();
            _filterOrders(searchQuery);
          },
          tooltip: 'add_purchase_order'.tr(),
          child: const Icon(Icons.add),
        ), */