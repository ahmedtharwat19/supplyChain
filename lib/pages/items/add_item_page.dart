import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:go_router/go_router.dart';
import 'package:puresip_purchasing/utils/user_local_storage.dart';

//import '../storage/user_local_storage.dart'; // مسار ملف UserLocalStorage حسب مشروعك

class AddItemPage extends StatefulWidget {
  const AddItemPage({super.key});

  @override
  State<AddItemPage> createState() => _AddItemPageState();
}

class _AddItemPageState extends State<AddItemPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _priceController = TextEditingController();
  String _type = 'raw_material'; // القيمة الافتراضية

  bool _isSaving = false;

  @override
  void dispose() {
    _nameController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  Future<void> _saveItem() async {
    if (!_formKey.currentState!.validate()) {
      debugPrint('❌ Form not valid');
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final user = await UserLocalStorage.getUser();
      final userId = user?['userId'];

      debugPrint('👤 Retrieved userId: $userId');

      if (userId == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(tr('please_login_first'))),
          );
        }
        setState(() {
          _isSaving = false;
        });
        return;
      }

      final name = _nameController.text.trim();
      final price = double.tryParse(_priceController.text.trim()) ?? 0.0;

      debugPrint('📝 Saving item: name=$name, price=$price, type=$_type');

      await FirebaseFirestore.instance.collection('items').add({
        'name': name,
        'unitPrice': price,
        'type': _type,
        'createdAt': FieldValue.serverTimestamp(),
        'user_id': userId,
      });

      debugPrint('✅ Item saved successfully');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(tr('item_added_successfully'))),
        );
        context.pop();
      }
    } catch (e) {
      debugPrint('🔥 Error saving item: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${tr('error_occurred')}: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(tr('add_new_item')),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              TextFormField(
                controller: _nameController,
                decoration: InputDecoration(labelText: tr('item_name')),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return tr('please_enter_item_name');
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _priceController,
                decoration: InputDecoration(labelText: tr('unit_price')),
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return tr('please_enter_unit_price');
                  }
                  if (double.tryParse(value.trim()) == null) {
                    return tr('please_enter_valid_number');
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _type,
                decoration: InputDecoration(labelText: tr('item_type')),
                items: [
                  DropdownMenuItem(
                    value: 'raw_material',
                    child: Text(tr('raw_material')),
                  ),
                  DropdownMenuItem(
                    value: 'packaging_material',
                    child: Text(tr('packaging_material')),
                  ),
                ],
                onChanged: (val) {
                  if (val != null) {
                    setState(() {
                      _type = val;
                    });
                  }
                },
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _isSaving ? null : _saveItem,
                child: _isSaving
                    ? const CircularProgressIndicator(color: Colors.white)
                    : Text(tr('add')),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
