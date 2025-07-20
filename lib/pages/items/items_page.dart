import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';
import 'package:puresip_purchasing/widgets/app_scaffold.dart';
import '../../utils/user_local_storage.dart';
import 'package:easy_localization/easy_localization.dart';

class ItemsPage extends StatefulWidget {
  const ItemsPage({super.key});

  @override
  State<ItemsPage> createState() => _ItemsPageState();
}

class _ItemsPageState extends State<ItemsPage> {
  String? userId;
  bool isLoading = true;

@override
void initState() {
  super.initState();
  debugPrint("🚀 initState: Starting to load user...");
  _loadUser();
}

Future<void> _loadUser() async {
  final user = await UserLocalStorage.getUser();
  debugPrint("👤 Loaded user: $user");

  if (!mounted) return;

  if (user == null) {
    debugPrint("⚠️ No user found in local storage.");
    setState(() {
      isLoading = false;
    });
    return;
  }

  setState(() {
    userId = user['userId'];
    isLoading = false;
  });

  debugPrint("✅ User ID set to: $userId");
}



Future<List<QueryDocumentSnapshot>> _fetchUserItems() async {
  if (userId == null) {
    debugPrint("❌ Cannot fetch items: userId is null");
    return [];
  }

  try {
    debugPrint("📦 Fetching items for user: $userId...");
    final snapshot = await FirebaseFirestore.instance
        .collection('items')
        .where('user_id', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .get();

    debugPrint("📦 Retrieved ${snapshot.docs.length} items for user: $userId");

    for (var doc in snapshot.docs) {
      debugPrint("✅ Item: ${doc.data()}");
    }

    return snapshot.docs;
  } catch (e) {
    debugPrint("❌ Error fetching items: $e");
    return [];
  }
}

Future<List<String>> _getSupplierNames(List<dynamic> supplierIds) async {
  try {
    if (supplierIds.isEmpty) {
      debugPrint("ℹ️ No supplier IDs provided.");
      return [];
    }

    debugPrint("🔍 Fetching supplier names for IDs: $supplierIds");

    final suppliersSnapshot = await FirebaseFirestore.instance
        .collection('vendors')
        .where(FieldPath.documentId, whereIn: supplierIds)
        .get();

    debugPrint("✅ Fetched ${suppliersSnapshot.docs.length} suppliers.");

    return suppliersSnapshot.docs
        .map((doc) => doc.data()['name']?.toString() ?? 'N/A')
        .toList();
  } catch (e) {
    debugPrint("❌ Error fetching supplier names: $e");
    return ['Error loading suppliers'];
  }
}


  String _typeName(String type) {
    return {
          'raw_material': tr('raw_material'),
          'packaging_material': tr('packaging_material'),
        }[type] ??
        type;
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return AppScaffold(
/*       appBar: AppBar(
        title: Text(tr('manage_items')),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () =>
              context.go('/dashboard'), // العودة للصفحة الرئيسية باستخدام GoRouter
        ),
      ), */
      title: tr('manage_items'),
      body: FutureBuilder<List<QueryDocumentSnapshot>>(
        future: _fetchUserItems(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
             debugPrint("⏳ Waiting for items to load...");
            return Center(child: Text(tr('loading_items')));
          }
          if (snapshot.hasError) {

            debugPrint("❌ Error loading items: ${snapshot.error}");

            return Center(
              
                child: Text('${tr('error_occurred')}: ${snapshot.error}'));
          }
          final items = snapshot.data ?? [];
          debugPrint("📋 Final item count in UI: ${items.length}");
          if (items.isEmpty) {
            return Center(child: Text(tr('no_items_found')));
          }

          return ListView.builder(
            itemCount: items.length,
            itemBuilder: (context, index) {
              final doc = items[index];
              final data = doc.data() as Map<String, dynamic>;

              return FutureBuilder<List<String>>(
                future: _getSupplierNames(data['supplierIds'] ?? []),
                builder: (context, suppliersSnapshot) {
                  final supplierNames = suppliersSnapshot.data ?? [];

                  return Card(
                    margin:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    child: ListTile(
                      title: Text(data['name'] ?? tr('unnamed')),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                              '${tr('unit_price')}: ${data['unitPrice']?.toStringAsFixed(2) ?? 'N/A'}'),
                          Text(
                              '${tr('item_type')}: ${_typeName(data['type'] ?? '')}'),
                          if (supplierNames.isNotEmpty)
                            Text(
                                '${tr('suppliers')}: ${supplierNames.join(', ')}'),
                        ],
                      ),
                      trailing: PopupMenuButton<String>(
                        onSelected: (action) => _onItemAction(action, doc),
                        itemBuilder: (ctx) => [
                          PopupMenuItem(value: 'edit', child: Text(tr('edit'))),
                          PopupMenuItem(
                              value: 'delete', child: Text(tr('delete'))),
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
      floatingActionButton: FloatingActionButton(
        onPressed: () =>
            context.push('/items/add'), // فتح صفحة إضافة صنف جديدة (مثال)
        tooltip: tr('add_item'),
        child: const Icon(Icons.add),
      ),
    );
  }

  void _onItemAction(String action, QueryDocumentSnapshot doc) {
    if (action == 'delete') {
      _deleteItem(doc);
    } else {
      context.push(
          '/items/edit/${doc.id}'); // فتح صفحة تعديل الصنف باستخدام GoRouter
    }
  }

  Future<void> _deleteItem(QueryDocumentSnapshot itemDoc) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(tr('confirm_delete')),
        content: Text(tr('delete_item_confirm')),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text(tr('cancel'))),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child:
                Text(tr('delete'), style: const TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await itemDoc.reference.delete();
      if (!mounted) return;
      setState(() {});
    }
  }
}
