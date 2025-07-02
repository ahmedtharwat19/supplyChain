import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../widgets/company_selector.dart';

class ItemsPage extends StatefulWidget {
  const ItemsPage({super.key});

  @override
  State<ItemsPage> createState() => _ItemsPageState();
}

class _ItemsPageState extends State<ItemsPage> {
  String? selectedCompanyId;
  late String _userId;
  bool _isUserIdLoaded = false;

  final TextEditingController _itemNameController = TextEditingController();
  final TextEditingController _itemUnitPriceController = TextEditingController();
  String _itemType = 'raw_material';
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadUserId();
  }

  Future<void> _loadUserId() async {
    final prefs = await SharedPreferences.getInstance();
    final userIdFromPrefs = prefs.getString('userId');
    if (userIdFromPrefs == null) return;

    setState(() {
      _userId = userIdFromPrefs;
      _isUserIdLoaded = true;
    });
  }

  void _showAddItemDialog([DocumentSnapshot? itemToEdit]) {
    bool isEditing = itemToEdit != null;
    if (isEditing) {
      _itemNameController.text = itemToEdit['name'];
      _itemUnitPriceController.text = itemToEdit['unitPrice'].toString();
      _itemType = itemToEdit['type'];
    } else {
      _itemNameController.clear();
      _itemUnitPriceController.clear();
      _itemType = 'raw_material';
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(isEditing ? 'تعديل صنف' : 'إضافة صنف جديد'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _itemNameController,
              decoration: const InputDecoration(labelText: 'اسم الصنف'),
            ),
            TextField(
              controller: _itemUnitPriceController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'سعر الوحدة الافتراضي'),
            ),
            DropdownButtonFormField<String>(
              value: _itemType,
              decoration: const InputDecoration(labelText: 'طبيعة الصنف'),
              items: const [
                DropdownMenuItem(value: 'raw_material', child: Text('خامة')),
                DropdownMenuItem(value: 'packaging_material', child: Text('مواد تعبئة وتغليف')),
              ],
              onChanged: (value) {
                if (value != null) {
                  setState(() => _itemType = value);
                }
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('إلغاء'),
          ),
          _isLoading
              ? const CircularProgressIndicator()
              : ElevatedButton(
                  onPressed: () => isEditing ? _updateItem(itemToEdit) : _addItem(),
                  child: Text(isEditing ? 'تحديث' : 'إضافة'),
                ),
        ],
      ),
    );
  }

  Future<void> _addItem() async {
    if (selectedCompanyId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يرجى اختيار الشركة أولًا')),
      );
      return;
    }

    final name = _itemNameController.text.trim();
    final unitPrice = double.tryParse(_itemUnitPriceController.text.trim());

    if (name.isEmpty || unitPrice == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يرجى ملء جميع الحقول بشكل صحيح')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      await FirebaseFirestore.instance
          .collection('companies/$selectedCompanyId/items')
          .add({
        'name': name,
        'unitPrice': unitPrice,
        'type': _itemType,
        'createdAt': Timestamp.now(),
      });

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تمت إضافة الصنف بنجاح')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ أثناء الإضافة: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _updateItem(DocumentSnapshot itemToEdit) async {
    final name = _itemNameController.text.trim();
    final unitPrice = double.tryParse(_itemUnitPriceController.text.trim());

    if (name.isEmpty || unitPrice == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يرجى ملء جميع الحقول بشكل صحيح')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      await FirebaseFirestore.instance
          .collection('companies/$selectedCompanyId/items')
          .doc(itemToEdit.id)
          .update({
        'name': name,
        'unitPrice': unitPrice,
        'type': _itemType,
      });

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم تحديث الصنف بنجاح')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ أثناء التحديث: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteItem(String itemId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('تأكيد الحذف'),
        content: const Text('هل أنت متأكد أنك تريد حذف هذا الصنف؟'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('إلغاء')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('حذف', style: TextStyle(color: Colors.red))),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await FirebaseFirestore.instance
            .collection('companies/$selectedCompanyId/items')
            .doc(itemId)
            .delete();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('تم حذف الصنف بنجاح')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('خطأ أثناء الحذف: $e')),
          );
        }
      }
    }
  }

  String _getItemTypeDisplayName(String type) {
    switch (type) {
      case 'raw_material':
        return 'خامة';
      case 'packaging_material':
        return 'مواد تعبئة وتغليف';
      default:
        return type;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_isUserIdLoaded) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('إدارة الأصناف'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: CompanySelector(
              userId: _userId,
              onCompanySelected: (companyId) {
                setState(() => selectedCompanyId = companyId);
              },
            ),
          ),
          if (selectedCompanyId == null)
            const Expanded(
              child: Center(child: Text('يرجى اختيار الشركة لعرض الأصناف')),
            )
          else
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('companies/$selectedCompanyId/items')
                    .orderBy('createdAt', descending: true)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    return Center(child: Text('حدث خطأ: ${snapshot.error}'));
                  }
                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return const Center(child: Text('لا توجد أصناف مسجلة لهذه الشركة.'));
                  }

                  final items = snapshot.data!.docs;
                  return ListView.builder(
                    itemCount: items.length,
                    itemBuilder: (context, index) {
                      final item = items[index];
                      final data = item.data() as Map<String, dynamic>;
                      return Card(
                        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        child: ListTile(
                          title: Text(data['name'] ?? 'Unnamed Item'),
                          subtitle: Text(
                            'السعر: ${data['unitPrice']?.toStringAsFixed(2) ?? 'N/A'} ج.م\n'
                            'النوع: ${_getItemTypeDisplayName(data['type'] ?? 'N/A')}',
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.edit, color: Colors.blue),
                                onPressed: () => _showAddItemDialog(item),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete, color: Colors.red),
                                onPressed: () => _deleteItem(item.id),
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
        onPressed: () => _showAddItemDialog(),
        tooltip: 'إضافة صنف جديد',
        child: const Icon(Icons.add),
      ),
    );
  }
}
