import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';
import '../../models/supplier.dart';
import '../../utils/user_local_storage.dart';
import '../../widgets/app_scaffold.dart';

class SuppliersPage extends StatefulWidget {
  const SuppliersPage({super.key});

  @override
  State<SuppliersPage> createState() => _SuppliersPageState();
}

class _SuppliersPageState extends State<SuppliersPage> {
  String searchQuery = '';
  String? userId;
  String? userName;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final user = await UserLocalStorage.getUser();
    if (user == null) {
      if (mounted) context.go('/login');
      return;
    }

    setState(() {
      userId = user['userId'];
      userName = user['displayName'];
      isLoading = false;
    });
  }

  Future<void> _confirmDelete(DocumentSnapshot doc) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(tr('confirm_delete_title')),
        content: Text(tr('confirm_delete_message')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(tr('cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(tr('delete'), style: const TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await doc.reference.delete();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(tr('supplier_deleted'))),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('${tr('delete_error')}: $e')),
          );
        }
      }
    }
  }

  Future<void> _editSupplier(Supplier supplier) async {
    await context.push('/edit-vendor/${supplier.id}', extra: {
      'name_ar': supplier.nameAr,
      'name_en': supplier.nameEn,
    });
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: tr('supplier_list'),
      userName: userName,
      body: isLoading || userId == null
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: TextField(
                    decoration: InputDecoration(
                      labelText: tr('search'),
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onChanged: (value) => setState(() => searchQuery = value.toLowerCase()),
                  ),
                ),
                Expanded(
                  child: StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('vendors')
                        .where(Supplier.fieldUserId, isEqualTo: userId)
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      if (snapshot.hasError) {
                        return Center(child: Text('${tr('error_occurred')}: ${snapshot.error}'));
                      }

                      final suppliers = snapshot.data!.docs
                          .map((doc) => Supplier.fromMap(doc.data() as Map<String, dynamic>, doc.id))
                          .where((supplier) => supplier.nameAr.toLowerCase().contains(searchQuery))
                          .toList();

                      if (suppliers.isEmpty) {
                        return Center(child: Text(tr('no_match_search')));
                      }

                      return ListView.builder(
                        itemCount: suppliers.length,
                        itemBuilder: (context, index) {
                          final supplier = suppliers[index];

                          return Card(
                            margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            elevation: 2,
                            child: ListTile(
                              leading: const Icon(Icons.person, size: 40),
                              title: Text(supplier.nameAr),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (supplier.nameEn.isNotEmpty)
                                    Text('🏢 ${supplier.nameEn}'),
                                  if (supplier.phone.isNotEmpty)
                                    Text('📞 ${supplier.phone}'),
                                ],
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.edit, color: Colors.blue),
                                    tooltip: tr('edit'),
                                    onPressed: () => _editSupplier(supplier),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete, color: Colors.red),
                                    tooltip: tr('delete'),
                                    onPressed: () => _confirmDelete(
                                      snapshot.data!.docs[index],
                                    ),
                                  ),
                                ],
                              ),
                            ),
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
          await context.push('/add-supplier');
        },
        tooltip: tr('add_supplier'),
        child: const Icon(Icons.add),
      ),
    );
  }
}
