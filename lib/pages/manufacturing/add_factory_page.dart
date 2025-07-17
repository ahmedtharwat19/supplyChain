import 'package:easy_localization/easy_localization.dart';
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
