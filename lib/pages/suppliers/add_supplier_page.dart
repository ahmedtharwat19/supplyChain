import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:go_router/go_router.dart';
import '../../models/supplier.dart';
import '../../utils/user_local_storage.dart';

class AddSupplierPage extends StatefulWidget {
  const AddSupplierPage({super.key});

  @override
  State<AddSupplierPage> createState() => _AddSupplierPageState();
}

class _AddSupplierPageState extends State<AddSupplierPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _companyController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _addressController = TextEditingController();
  final _notesController = TextEditingController();

  String? userId;

  @override
  void initState() {
    super.initState();
    _loadUserId();
  }

  Future<void> _loadUserId() async {
    final user = await UserLocalStorage.getUser();
    setState(() {
      userId = user?['userId'];
    });
  }

  Future<void> _saveSupplier() async {
    if (!_formKey.currentState!.validate() || userId == null) return;

    final newSupplier = Supplier(
      name: _nameController.text.trim(),
      company: _companyController.text.trim(),
      phone: _phoneController.text.trim(),
      email: _emailController.text.trim(),
      address: _addressController.text.trim(),
      notes: _notesController.text.trim(),
      userId: userId!,
      createdAt: Timestamp.now(),
    );

    try {
      await FirebaseFirestore.instance
          .collection('vendors')
          .add(newSupplier.toMap());

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(tr('supplier_added'))),
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
      appBar: AppBar(title: Text(tr('add_supplier'))),
      body: userId == null
          ? const Center(child: CircularProgressIndicator())
          : Padding(
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
                    TextFormField(
                      controller: _phoneController,
                      decoration: InputDecoration(labelText: tr('phone')),
                    ),
                    TextFormField(
                      controller: _emailController,
                      decoration: InputDecoration(labelText: tr('email')),
                    ),
                    TextFormField(
                      controller: _addressController,
                      decoration: InputDecoration(labelText: tr('address')),
                    ),
                    TextFormField(
                      controller: _notesController,
                      decoration: InputDecoration(labelText: tr('notes')),
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: _saveSupplier,
                      child: Text(tr('save')),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
