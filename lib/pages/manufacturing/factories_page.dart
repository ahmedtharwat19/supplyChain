import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';
import 'package:easy_localization/easy_localization.dart';
import '../../widgets/app_scaffold.dart';

class FactoriesPage extends StatefulWidget {
  const FactoriesPage({super.key});

  @override
  State<FactoriesPage> createState() => _FactoriesPageState();
}

class _FactoriesPageState extends State<FactoriesPage> {
  String searchQuery = '';
  List<String> userFactoryIds = [];
  bool isLoading = true;
  String? userName;

  @override
  void initState() {
    super.initState();
    loadUserInfo();
    loadUserFactories();
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

  Future<void> loadUserFactories() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (mounted) context.go('/login');
      return;
    }

    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();
    if (!mounted) return;

    final data = doc.data();
    setState(() {
      userFactoryIds = (data?['factoryIds'] as List?)?.cast<String>() ?? [];
      isLoading = false;
    });
  }

  Future<void> _confirmDeleteFactory(DocumentSnapshot factory) async {
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
        await factory.reference.delete();
        final user = FirebaseAuth.instance.currentUser;
        if (user != null) {
          await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .update({
            'factoryIds': FieldValue.arrayRemove([factory.id]),
          });
        }
        if (mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text(tr('factory_deleted'))));
          await loadUserFactories();
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

  Future<void> _editFactory(DocumentSnapshot factory) async {
    final data = factory.data() as Map<String, dynamic>;
    await context.push('/edit-factory/${factory.id}', extra: data);
    if (mounted) loadUserFactories();
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: tr('factories'),
      userName: userName,
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: TextField(
                    decoration: InputDecoration(
                      labelText: tr('search'),
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8)),
                    ),
                    onChanged: (value) =>
                        setState(() => searchQuery = value.toLowerCase()),
                  ),
                ),
                Expanded(
                  child: userFactoryIds.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(tr('no_factories')),
                              const SizedBox(height: 20),
                              ElevatedButton.icon(
                                onPressed: () => context.push('/add-factory'),
                                icon: const Icon(Icons.add),
                                label: Text(tr('add_factory')),
                              ),
                            ],
                          ),
                        )
                      : StreamBuilder<QuerySnapshot>(
                          stream: FirebaseFirestore.instance
                              .collection('factories')
                              .where('user_id',
                                  isEqualTo:
                                      FirebaseAuth.instance.currentUser?.uid)
                              .snapshots(),
                          builder: (context, snapshot) {
                            if (snapshot.connectionState ==
                                ConnectionState.waiting) {
                              return const Center(
                                  child: CircularProgressIndicator());
                            }

                            if (snapshot.hasError) {
                              return Center(
                                  child: Text(
                                      '${tr('error_occurred')}: ${snapshot.error}'));
                            }

                            final factories = snapshot.data!.docs.where((doc) {
                              final data = doc.data() as Map<String, dynamic>;
                              final name = (data['name'] ?? '')
                                  .toString()
                                  .toLowerCase();
                              return userFactoryIds.contains(doc.id) &&
                                  name.contains(searchQuery);
                            }).toList();

                            if (factories.isEmpty) {
                              return Center(child: Text(tr('no_match_search')));
                            }

                            return ListView.builder(
                              itemCount: factories.length,
                              itemBuilder: (context, index) {
                                final factory = factories[index];
                                final data =
                                    factory.data() as Map<String, dynamic>;

                                Uint8List? imageBytes;
                                try {
                                  if (data['logo_base64'] != null &&
                                      data['logo_base64']
                                          .toString()
                                          .isNotEmpty) {
                                    imageBytes =
                                        base64Decode(data['logo_base64']);
                                  }
                                } catch (_) {}

                                return Card(
                                  margin: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 6),
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10)),
                                  elevation: 2,
                                  child: ListTile(
                                    leading: SizedBox(
                                      width: 60,
                                      height: 60,
                                      child: imageBytes != null
                                          ? ClipRRect(
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                              child: Image.memory(imageBytes,
                                                  fit: BoxFit.contain),
                                            )
                                          : const Icon(Icons.factory, size: 40),
                                    ),
                                    title: Text(data['name'] ?? ''),
                                    subtitle: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        if (data['address'] != null)
                                          Text('📍 ${data['address']}'),
                                        if (data['phone'] != null)
                                          Text('📞 ${data['phone']}'),
                                      ],
                                    ),
                                    trailing: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        IconButton(
                                          icon: const Icon(Icons.edit,
                                              color: Colors.blue),
                                          tooltip: tr('edit'),
                                          onPressed: () =>
                                              _editFactory(factory),
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.delete,
                                              color: Colors.red),
                                          tooltip: tr('delete'),
                                          onPressed: () =>
                                              _confirmDeleteFactory(factory),
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
          await context.push('/add-factory');
          if (mounted) loadUserFactories();
        },
        tooltip: tr('add_factory'),
        child: const Icon(Icons.add),
      ),
    );
  }
}
