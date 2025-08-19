import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:puresip_purchasing/widgets/app_scaffold.dart';

class InventoryQueryPage extends StatefulWidget {
  const InventoryQueryPage({super.key});

  @override
  State<InventoryQueryPage> createState() => _InventoryQueryPageState();
}

class _InventoryQueryPageState extends State<InventoryQueryPage> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  bool _isLoading = false;
  final List<Map<String, dynamic>> _inventoryResults = [];

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text;
      });
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _searchInventory(showAll: true);
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _searchInventory({bool showAll = false}) async {
    if (_searchQuery.isEmpty && !showAll) {
      setState(() {
        _inventoryResults.clear();
      });
      return;
    }

    setState(() => _isLoading = true);
    _inventoryResults.clear();

    try {
      /*       final user = FirebaseAuth.instance.currentUser;
          if (user == null) return;

          final userDoc = await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .get();

          final userData = userDoc.data();

          final factoryIds =
              (userData?['factoryIds'] as List?)?.cast<String>() ?? [];

          for (final factoryId in factoryIds) {
            Query query = FirebaseFirestore.instance
                .collection('factories/$factoryId/inventory');

            if (!showAll) {
              query = query
                  .where('productName', isGreaterThanOrEqualTo: _searchQuery)
                  .where('productName', isLessThanOrEqualTo: '$_searchQuery\uf8ff');
            }

            final inventorySnapshot = await query.get();

            for (final doc in inventorySnapshot.docs) {
              final inventoryData = doc.data() as Map<String, dynamic>;
              final productId = doc.id;

              final itemDoc = await FirebaseFirestore.instance
                  .collection('items')
                  .doc(productId)
                  .get();
              final itemData = itemDoc.data();

              final factoryDoc = await FirebaseFirestore.instance
                  .collection('factories')
                  .doc(factoryId)
                  .get();
              final factoryData = factoryDoc.data();

              final companyIds =
                  (factoryData?['companyIds'] as List?)?.cast<String>() ?? [];
              List<String> companyNames = [];

              for (var companyId in companyIds) {
                final companyDoc = await FirebaseFirestore.instance
                    .collection('companies')
                    .doc(companyId)
                    .get();

                final companyData = companyDoc.data();
                if (companyData != null) {
                  if (!mounted) return;
                  final lang = context.locale.languageCode;
                  final companyName = lang == 'ar'
                      ? companyData['nameAr'] ?? companyData['nameEn'] ?? ''
                      : companyData['nameEn'] ?? companyData['nameAr'] ?? '';
                  companyNames.add(companyName);
                }
              }

              if (!mounted) return;
              final lang = context.locale.languageCode;
              final productName = lang == 'ar'
                  ? (itemData?['nameAr'] ?? itemData?['nameEn'])
                  : (itemData?['nameEn'] ?? itemData?['nameAr']);

              final factoryName = lang == 'ar'
                  ? (factoryData?['nameAr'] ?? factoryData?['nameEn'])
                  : (factoryData?['nameEn'] ?? factoryData?['nameAr']);

              _inventoryResults.add({
                'productId': productId,
                'productName': productName,
                'quantity': inventoryData['quantity'] ?? 0,
                'factoryId': factoryId,
                'factoryName': factoryName,
                'companyNames': companyNames,
                'lastUpdated': inventoryData['lastUpdated'],
                'documentId': doc.id,
              });
            }
          } */final user = FirebaseAuth.instance.currentUser;
if (user == null) return;

final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
final userData = userDoc.data();
final userCompanyIds = (userData?['companyIds'] as List?)?.cast<String>() ?? [];
final factoryIds = (userData?['factoryIds'] as List?)?.cast<String>() ?? [];

_inventoryResults.clear();

for (final factoryId in factoryIds) {
  final factoryDoc = await FirebaseFirestore.instance.collection('factories').doc(factoryId).get();
  final factoryData = factoryDoc.data();
  if (factoryData == null) continue;

  final factoryCompanyIds = (factoryData['companyIds'] as List?)?.cast<String>() ?? [];
  if (!factoryCompanyIds.any((id) => userCompanyIds.contains(id))) continue;

  Query query = FirebaseFirestore.instance.collection('factories/$factoryId/inventory');
  if (!showAll) {
    query = query
      .where('productName', isGreaterThanOrEqualTo: _searchQuery)
      .where('productName', isLessThanOrEqualTo: '$_searchQuery\uf8ff');
  }
  final inventorySnapshot = await query.get();

  for (final doc in inventorySnapshot.docs) {
    final inventoryData = doc.data() as Map<String, dynamic>;

    final productId = doc.id;

    final itemDoc = await FirebaseFirestore.instance.collection('items').doc(productId).get();
    final itemData = itemDoc.data();

    if (!mounted) return;
    final lang = context.locale.languageCode;

    final productName = itemData != null
      ? (lang == 'ar' ? (itemData['nameAr'] ?? itemData['nameEn'] ?? 'Unknown Product')
                     : (itemData['nameEn'] ?? itemData['nameAr'] ?? 'Unknown Product'))
      : 'Unknown Product';

    final factoryName = lang == 'ar'
        ? (factoryData['nameAr'] ?? factoryData['nameEn'])
        : (factoryData['nameEn'] ?? factoryData['nameAr']);

    final relevantCompanyNames = <String>[];
    for (final companyId in factoryCompanyIds) {
      if (userCompanyIds.contains(companyId)) {
        final companyDoc = await FirebaseFirestore.instance.collection('companies').doc(companyId).get();
        final companyData = companyDoc.data();
        if (companyData != null) {
          final companyName = lang == 'ar'
              ? (companyData['nameAr'] ?? companyData['nameEn'] ?? '')
              : (companyData['nameEn'] ?? companyData['nameAr'] ?? '');
          if (companyName.isNotEmpty) relevantCompanyNames.add(companyName);
        }
      }
    }

    _inventoryResults.add({
      'productId': productId,
      'productName': productName,
      'quantity': inventoryData['quantity'] ?? 0,
      'factoryId': factoryId,
      'factoryName': factoryName,
      'companyNames': relevantCompanyNames,
      'llastUpdated': inventoryData['lastUpdated'],

    });
  }
}

    } catch (e) {
      debugPrint('Search error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('error_loading_data'.tr())),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Widget _buildResultsList() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_inventoryResults.isEmpty && _searchQuery.isNotEmpty) {
      return Center(child: Text('no_results'.tr()));
    }

    if (_inventoryResults.isEmpty) {
      return Center(child: Text('search_products_hint'.tr()));
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const AlwaysScrollableScrollPhysics(),
      itemCount: _inventoryResults.length,
      itemBuilder: (context, index) {
        final item = _inventoryResults[index];
        return _buildInventoryItem(item);
      },
    );
  }

  Widget _buildInventoryItem(Map<String, dynamic> item) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      child: ListTile(
        title: Text(
          item['productName'] ?? 'Unknown Product',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text('${'quantity'.tr()}: ${item['quantity'] ?? 0}'),
            Text('${'factory'.tr()}: ${item['factoryName']}'),
            if (item['companyNames'] != null &&
                (item['companyNames'] as List).isNotEmpty)
              Text(
                  '${'companies'.tr()}: ${(item['companyNames'] as List).join(", ")}'),
            if (item['lastUpdated'] != null)
              Text(
                  '${'last_updated'.tr()}: ${_formatDate(item['lastUpdated'])}'),
          ],
        ),
        trailing: IconButton(
          icon: const Icon(Icons.history, size: 20),
          onPressed: () =>
              _showStockHistory(item['productId'], item['factoryId']),
        ),
      ),
    );
  }

  String _formatDate(dynamic date) {
    try {
      if (date is Timestamp) {
        return DateFormat('yyyy-MM-dd HH:mm').format(date.toDate());
      }
      return 'Unknown date';
    } catch (e) {
      return 'Invalid date';
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'inventory_query'.tr(),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _searchController,
              decoration: InputDecoration(
                labelText: 'search_products'.tr(),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.search),
                  onPressed: () => _searchInventory(),
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onSubmitted: (value) => _searchInventory(),
            ),
            const SizedBox(height: 20),
            Expanded(child: _buildResultsList()),
          ],
        ),
      ),
    );
  }

  Future<void> _showStockHistory(String productId, String factoryId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('stock_history'.tr()),
        content: FutureBuilder<QuerySnapshot>(
          future: FirebaseFirestore.instance
              .collectionGroup('stock_movements')
              .where('productId', isEqualTo: productId)
              .where('factoryId', isEqualTo: factoryId)
              .orderBy('date', descending: true)
              .get(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const CircularProgressIndicator();
            }

            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
              return Text('no_stock_history'.tr());
            }

            final movements = snapshot.data!.docs;

            return SizedBox(
              width: double.maxFinite,
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: movements.length,
                itemBuilder: (context, index) {
                  final data = movements[index].data() as Map<String, dynamic>;
                  return ListTile(
                    title: Text('${data['type']}: ${data['quantity']}'),
                    subtitle: Text(DateFormat('yyyy-MM-dd HH:mm')
                        .format((data['date'] as Timestamp).toDate())),
                    trailing: Text(data['referenceId'] ?? ''),
                  );
                },
              ),
            );
          },
        ),
      ),
    );
  }
}
