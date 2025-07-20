import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:go_router/go_router.dart';

class EditSupplierPage extends StatefulWidget {
  final String supplierId;
  final String initialName;
  final String initialCompany;

  const EditSupplierPage({
    super.key,
    required this.supplierId,
    required this.initialName,
    required this.initialCompany,
  });

  @override
  State<EditSupplierPage> createState() => _EditSupplierPageState();
}

class _EditSupplierPageState extends State<EditSupplierPage> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _companyController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initialName);
    _companyController = TextEditingController(text: widget.initialCompany);
  }

  Future<void> _updateSupplier() async {
    if (!_formKey.currentState!.validate()) return;

    try {
      await FirebaseFirestore.instance
          .collection('vendors')
          .doc(widget.supplierId)
          .update({
        'name': _nameController.text.trim(),
        'company': _companyController.text.trim(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(tr('supplier_updated'))),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${tr('error_occurred')}: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(tr('edit_supplier'))),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              TextFormField(
                controller: _nameController,
                decoration: InputDecoration(labelText: tr('name')),
                validator: (value) =>
                    value == null || value.isEmpty ? tr('required') : null,
              ),
              TextFormField(
                controller: _companyController,
                decoration: InputDecoration(labelText: tr('company')),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _updateSupplier,
                child: Text(tr('save')),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
