import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AddSupplierPage extends StatefulWidget {
  const AddSupplierPage({super.key});

  @override
  State<AddSupplierPage> createState() => _AddSupplierPageState();
}

class _AddSupplierPageState extends State<AddSupplierPage> {
  final _nameController = TextEditingController();
  final _companyController = TextEditingController();
  bool _isSaving = false;

  Future<void> _saveSupplier() async {
    final name = _nameController.text.trim();
    final company = _companyController.text.trim();

    if (name.isEmpty || company.isEmpty) return;

    setState(() => _isSaving = true);

    try {
      await FirebaseFirestore.instance.collection('vendors').add({
        'name': name,
        'company': company,
        'timestamp': FieldValue.serverTimestamp(),
      });

      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('فشل في الإضافة: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('إضافة مورد جديد')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: 'اسم المورد'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _companyController,
              decoration: const InputDecoration(labelText: 'اسم الشركة'),
            ),
            const SizedBox(height: 20),
            _isSaving
                ? const CircularProgressIndicator()
                : ElevatedButton(
                    onPressed: _saveSupplier,
                    child: const Text('حفظ'),
                  ),
          ],
        ),
      ),
    );
  }
}
