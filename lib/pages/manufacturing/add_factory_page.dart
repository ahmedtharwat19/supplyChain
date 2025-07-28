/* import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:puresip_purchasing/widgets/app_scaffold.dart';
import '../../../utils/user_local_storage.dart';

class AddFactoryPage extends StatefulWidget {
  const AddFactoryPage({super.key});

  @override
  State<AddFactoryPage> createState() => _AddFactoryPageState();
}

class _AddFactoryPageState extends State<AddFactoryPage> {
  final _formKey = GlobalKey<FormState>();
  final nameController = TextEditingController();
  final addressController = TextEditingController();
  final phoneController = TextEditingController();

  bool isSubmitting = false;

  Future<void> addFactory() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => isSubmitting = true);

    final user = await UserLocalStorage.getUser();
    final companyId = await UserLocalStorage.getCurrentCompanyId();

    if (!mounted) return; // ⛑️ حماية قبل استخدام context

    if (user == null || companyId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('no_user_or_company'.tr())),
      );
      return;
    }

    await FirebaseFirestore.instance.collection('factories').add({
      'name': nameController.text.trim(),
      'address': addressController.text.trim(),
      'phone': phoneController.text.trim(),
      'company_id': companyId,
      'user_id': user['userId'],
      'createdAt': Timestamp.now(),
    });

    if (!mounted) return;
    setState(() => isSubmitting = false);
    Navigator.pop(context); // العودة بعد الإضافة
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'add_factory'.tr(),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: nameController,
                decoration: InputDecoration(labelText: 'factory_name'.tr()),
                validator: (value) => value!.isEmpty ? 'requierd'.tr() : null,
              ),
              TextFormField(
                controller: addressController,
                decoration: InputDecoration(labelText: 'address'.tr()),
              ),
              TextFormField(
                controller: phoneController,
                decoration: InputDecoration(labelText: 'phone'.tr()),
              ),
              const SizedBox(height: 20),
              isSubmitting
                  ? const CircularProgressIndicator()
                  : ElevatedButton(
                      onPressed: addFactory,
                      child: Text('add_factory'.tr()),
                    ),
            ],
          ),
        ),
      ),
    );
  }
}
 */

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:go_router/go_router.dart';

class AddFactoryPage extends StatefulWidget {
  const AddFactoryPage({super.key});
  @override
  State<AddFactoryPage> createState() => _AddFactoryPageState();
}

class _AddFactoryPageState extends State<AddFactoryPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameArController = TextEditingController();
  final _nameEnController = TextEditingController();
  final _locationController = TextEditingController();
  final _managerController = TextEditingController();
  final _phoneController = TextEditingController();
  bool _isLoading = false;

  @override void dispose() {
    _nameArController.dispose();
    _nameEnController.dispose();
    _locationController.dispose();
    _managerController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _addFactory() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final data = {
      'name_ar': _nameArController.text.trim(),
      'name_en': _nameEnController.text.trim(),
      'location': _locationController.text.trim(),
      'manager_name': _managerController.text.trim(),
      'manager_phone': _phoneController.text.trim(),
      'company_id': user.uid, // أو أي منطق للمفتاح
      'createdAt': FieldValue.serverTimestamp(),
      'user_id': user.uid,
    };

    try {
      final docRef = await FirebaseFirestore.instance
          .collection('factories')
          .add(data);

      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .update({
        'factoryIds': FieldValue.arrayUnion([docRef.id]),
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(tr('factory_added_successfully'))));
      context.pop();
    } catch (e) {
      debugPrint('Error adding factory: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('${tr('error_occurred')}: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(tr('add_factory'))),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              TextFormField(
                controller: _nameArController,
                decoration: InputDecoration(labelText: tr('name_arabic')),
                validator: (v) => v == null || v.isEmpty ? tr('required_field') : null,
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _nameEnController,
                decoration: InputDecoration(labelText: tr('name_english')),
                validator: (v) => v == null || v.isEmpty ? tr('required_field') : null,
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _locationController,
                decoration: InputDecoration(labelText: tr('location')),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _managerController,
                decoration: InputDecoration(labelText: tr('manager_name')),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _phoneController,
                decoration: InputDecoration(labelText: tr('manager_phone')),
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _isLoading ? null : _addFactory,
                child: Text(tr('add')),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
