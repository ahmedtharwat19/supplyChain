import 'dart:convert';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../models/company.dart';

class EditCompanyPage extends StatefulWidget {
  final String companyId;

  const EditCompanyPage({
    super.key,
    required this.companyId,
  });

  @override
  State<EditCompanyPage> createState() => _EditCompanyPageState();
}

class _EditCompanyPageState extends State<EditCompanyPage> {
  final _formKey = GlobalKey<FormState>();

  final _nameArController = TextEditingController();
  final _nameEnController = TextEditingController();
  final _addressController = TextEditingController();
  final _managerNameController = TextEditingController();
  final _managerPhoneController = TextEditingController();

  File? _logoImageFile;
  Uint8List? _logoWebBytes;
  String? _logoBase64;

  bool _isLoading = false;
  bool _isDataLoading = true;

  @override
  void initState() {
    super.initState();
    _loadCompanyData();
  }

  Future<void> _loadCompanyData() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('companies')
          .doc(widget.companyId)
          .get();

      if (!doc.exists) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('الشركة غير موجودة')),
          );
          Navigator.pop(context);
        }
        return;
      }

      final data = doc.data()!;
      _nameArController.text = data['name_ar'] ?? '';
      _nameEnController.text = data['name_en'] ?? '';
      _addressController.text = data['address'] ?? '';
      _managerNameController.text = data['manager_name'] ?? '';
      _managerPhoneController.text = data['manager_phone'] ?? '';
      _logoBase64 = data['logo_base64'];

      if (_logoBase64 != null) {
        if (kIsWeb) {
          _logoWebBytes = base64Decode(_logoBase64!);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ في تحميل بيانات الشركة: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isDataLoading = false;
        });
      }
    }
  }

  Future<void> _pickLogo() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);

    if (pickedFile != null) {
      if (kIsWeb) {
        _logoWebBytes = await pickedFile.readAsBytes();
        _logoBase64 = base64Encode(_logoWebBytes!);
      } else {
        _logoImageFile = File(pickedFile.path);
        final bytes = await _logoImageFile!.readAsBytes();
        _logoBase64 = base64Encode(bytes);
      }
      setState(() {});
    }
  }

  Future<void> _updateCompany() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('يجب تسجيل الدخول أولاً')),
        );
        return;
      }

      final updatedCompany = Company(
        nameAr: _nameArController.text.trim(),
        nameEn: _nameEnController.text.trim(),
        address: _addressController.text.trim(),
        managerName: _managerNameController.text.trim(),
        managerPhone: _managerPhoneController.text.trim(),
        logoBase64: _logoBase64,
        userId: user.uid,
        createdAt: Timestamp.now(),
      );

      await FirebaseFirestore.instance
          .collection('companies')
          .doc(widget.companyId)
          .update(updatedCompany.toMap());

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم تحديث بيانات الشركة بنجاح')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('حدث خطأ أثناء التحديث: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _nameArController.dispose();
    _nameEnController.dispose();
    _addressController.dispose();
    _managerNameController.dispose();
    _managerPhoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Uint8List? previewBytes =
        _logoWebBytes ?? (_logoBase64 != null ? base64Decode(_logoBase64!) : null);

    return Scaffold(
      appBar: AppBar(title: const Text('تعديل بيانات الشركة')),
      body: _isDataLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    TextFormField(
                      controller: _nameArController,
                      decoration: const InputDecoration(labelText: 'اسم الشركة (عربي)'),
                      validator: (val) =>
                          val == null || val.isEmpty ? 'يرجى إدخال اسم الشركة بالعربي' : null,
                    ),
                    TextFormField(
                      controller: _nameEnController,
                      decoration: const InputDecoration(labelText: 'Company Name (English)'),
                      validator: (val) =>
                          val == null || val.isEmpty ? 'Please enter the company name in English' : null,
                    ),
                    TextFormField(
                      controller: _addressController,
                      decoration: const InputDecoration(labelText: 'عنوان الشركة'),
                      validator: (val) =>
                          val == null || val.isEmpty ? 'يرجى إدخال عنوان الشركة' : null,
                    ),
                    TextFormField(
                      controller: _managerNameController,
                      decoration: const InputDecoration(labelText: 'اسم المسؤول'),
                    ),
                    TextFormField(
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
                            onPressed: _updateCompany,
                            icon: const Icon(Icons.save),
                            label: const Text('تحديث البيانات'),
                            style: ElevatedButton.styleFrom(
                              minimumSize: const Size.fromHeight(50),
                            ),
                          ),
                  ],
                ),
              ),
            ),
    );
  }
}
