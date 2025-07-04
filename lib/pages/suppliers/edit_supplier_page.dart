import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class EditSupplierPage extends StatefulWidget {
  final String vendorId;
  final String initialName;
  final String initialCompany;

  const EditSupplierPage({
    super.key,
    required this.vendorId,
    required this.initialName,
    required this.initialCompany,
  });

  @override
  State<EditSupplierPage> createState() => _EditSupplierPageState();
}

class _EditSupplierPageState extends State<EditSupplierPage> {
  late TextEditingController _nameController;
  late TextEditingController _companyController;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initialName);
    _companyController = TextEditingController(text: widget.initialCompany);
  }

  Future<void> _updateSupplier() async {
    final name = _nameController.text.trim();
    final company = _companyController.text.trim();

    if (name.isEmpty || company.isEmpty) return;

    setState(() => _isSaving = true);

    try {
      await FirebaseFirestore.instance
          .collection('vendors')
          .doc(widget.vendorId)
          .update({
        'name': name,
        'company': company,
      });

      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('فشل في التعديل: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('تعديل المورد')),
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
                    onPressed: _updateSupplier,
                    child: const Text('تحديث'),
                  ),
          ],
        ),
      ),
    );
  }
}
