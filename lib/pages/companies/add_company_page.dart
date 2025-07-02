// lib/pages/add_company_page.dart

import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'company_added_page.dart';
//import '../../../../models/company.dart';


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
    final nameAr = _nameArController.text.trim();
    final nameEn = _nameEnController.text.trim();
    final address = _addressController.text.trim();
    final managerName = _managerNameController.text.trim();
    final managerPhone = _managerPhoneController.text.trim();

    if (nameAr.isEmpty || nameEn.isEmpty || address.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يرجى ملء جميع الحقول المطلوبة')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('يجب تسجيل الدخول أولاً')),
        );
        return;
      }

      final docRef = await FirebaseFirestore.instance.collection('companies').add({
        'name_ar': nameAr,
        'name_en': nameEn,
        'address': address,
        'manager_name': managerName,
        'manager_phone': managerPhone,
        'logo_base64': _base64Logo,
        'user_id': user.uid,
        'createdAt': Timestamp.now(),
      });

      // ربط الشركة بالمستخدم الحالي
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'companyIds': FieldValue.arrayUnion([docRef.id]),
      }, SetOptions(merge: true));

      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => CompanyAddedPage(nameAr: nameAr, docId: docRef.id),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('حدث خطأ أثناء الإضافة: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    Uint8List? previewBytes =
        _webImageBytes ?? (_base64Logo != null ? base64Decode(_base64Logo!) : null);

    return Scaffold(
      appBar: AppBar(title: const Text('إضافة شركة')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _nameArController,
              decoration: const InputDecoration(labelText: 'اسم الشركة (عربي)'),
            ),
            TextField(
              controller: _nameEnController,
              decoration: const InputDecoration(labelText: 'Company Name (English)'),
            ),
            TextField(
              controller: _addressController,
              decoration: const InputDecoration(labelText: 'عنوان الشركة'),
            ),
            TextField(
              controller: _managerNameController,
              decoration: const InputDecoration(labelText: 'اسم المسؤول'),
            ),
            TextField(
              controller: _managerPhoneController,
              decoration: const InputDecoration(labelText: 'رقم هاتف المسؤول'),
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                ElevatedButton.icon(
                  onPressed: _pickLogo,
                  icon: const Icon(Icons.image),
                  label: const Text('اختيار لوجو'),
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
                    label: const Text('إضافة الشركة'),
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
