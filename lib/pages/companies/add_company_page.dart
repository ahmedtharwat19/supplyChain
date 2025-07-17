import 'dart:convert';
import 'dart:io';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:puresip_purchasing/pages/companies/companies_page.dart';
import 'company_added_page.dart';

class AddCompanyPage extends StatefulWidget {
  const AddCompanyPage({super.key});

  @override
  State<AddCompanyPage> createState() => _AddCompanyPageState();
}

class _AddCompanyPageState extends State<AddCompanyPage> {
  final _nameArController = TextEditingController();
  final _nameEnController = TextEditingController();
  final _addressController = TextEditingController();
  final _managerNameController = TextEditingController();
  final _managerPhoneController = TextEditingController();

  File? _logoImage;
  Uint8List? _webImageBytes;
  String? _base64Logo;
  bool _isLoading = false;

  Future<void> _pickLogo() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);

    if (pickedFile != null) {
      if (kIsWeb) {
        _webImageBytes = await pickedFile.readAsBytes();
        _base64Logo = base64Encode(_webImageBytes!);
      } else {
        _logoImage = File(pickedFile.path);
        final bytes = await _logoImage!.readAsBytes();
        _base64Logo = base64Encode(bytes);
      }
      setState(() {});
    }
  }

  Future<void> _addCompany() async {
    if (_isLoading) return; // 🔒 لمنع الضغط المتكرر

    final nameAr = _nameArController.text.trim();
    final nameEn = _nameEnController.text.trim();
    final address = _addressController.text.trim();
    final managerName = _managerNameController.text.trim();
    final managerPhone = _managerPhoneController.text.trim();

    if (nameAr.isEmpty || nameEn.isEmpty || address.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('requierd_fields'.tr())),
      );
      return;
    }

    if (_base64Logo == null || _base64Logo!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('please_select_logo'.tr())),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('login_first'.tr())),
        );
        return;
      }

      final companyData = {
        'name_ar': nameAr,
        'name_en': nameEn,
        'address': address,
        'manager_name': managerName,
        'manager_phone': managerPhone,
        'logo_base64': _base64Logo,
        'user_id': user.uid,
        'createdAt': Timestamp.now(),
      };

      final docRef = await FirebaseFirestore.instance
          .collection('companies')
          .add(companyData);

      final userDocRef =
          FirebaseFirestore.instance.collection('users').doc(user.uid);
      final userDoc = await userDocRef.get();

      if (userDoc.exists) {
        await userDocRef.update({
          'companyIds': FieldValue.arrayUnion([docRef.id]),
        });
      } else {
        await userDocRef.set({
          'companyIds': [docRef.id],
        });
      }

      if (!mounted) return;

      // ✅ عرض رسالة نجاح قبل الانتقال
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('company_added_successfully'.tr())),
      );

      // تأخير بسيط لعرض الرسالة
      await Future.delayed(const Duration(seconds: 1));

      if (!mounted) return;

      // ✅ التنقل إلى صفحة "تمت الإضافة"
/*       Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => CompanyAddedPage(
            nameAr: nameAr,
            docId: docRef.id,
          ),
        ),
      ); */
      if (mounted) {
        //{ context.go('/companies');}

        GoRoute(
          path: '/companies',
          builder: (context, state) => const CompaniesPage(), // أو الصفحة المناسبة
        );
      }
      //context.go('/company-added/${docRef.id}');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${tr('error_while_adding_company')}: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    Uint8List? previewBytes = _webImageBytes ??
        (_base64Logo != null ? base64Decode(_base64Logo!) : null);

    return Scaffold(
      appBar: AppBar(title: Text('add_company'.tr())),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _nameArController,
              decoration:
                  InputDecoration(labelText: 'company_name_arabic'.tr()),
            ),
            TextField(
              controller: _nameEnController,
              decoration:
                  InputDecoration(labelText: 'company_name_english'.tr()),
            ),
            TextField(
              controller: _addressController,
              decoration: InputDecoration(labelText: 'company_address'.tr()),
            ),
            TextField(
              controller: _managerNameController,
              decoration:
                  InputDecoration(labelText: 'company_manager_name'.tr()),
            ),
            TextField(
              controller: _managerPhoneController,
              decoration:
                  InputDecoration(labelText: 'company_manager_phone'.tr()),
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                ElevatedButton.icon(
                  onPressed: _pickLogo,
                  icon: const Icon(Icons.image),
                  label: Text('company_logo'.tr()),
                ),
                const SizedBox(width: 10),
                if (previewBytes != null)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: SizedBox(
                      width: 60,
                      height: 60,
                      child: Image.memory(previewBytes),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 20),
            _isLoading
                ? const CircularProgressIndicator()
                : ElevatedButton.icon(
                    onPressed: _addCompany,
                    icon: const Icon(Icons.add_business),
                    label: Text('add_company'.tr()),
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size.fromHeight(50),
                    ),
                  ),
          ],
        ),
      ),
    );
  }
}
