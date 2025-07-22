import 'dart:convert';
import 'dart:io';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';

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

  final arabicOnlyFormatter = FilteringTextInputFormatter.allow(
    RegExp(r'[\u0600-\u06FF\s]'),
  );
  final englishOnlyFormatter = FilteringTextInputFormatter.allow(
    RegExp(r'[a-zA-Z\s]'),
  );
  final numbersOnlyFormatter = FilteringTextInputFormatter.digitsOnly;

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
      debugPrint('Logo selected and encoded.');
    } else {
      debugPrint('No logo image selected.');
    }
  }

  Future<bool> _isCompanyDuplicate(String nameAr, String nameEn) async {
    debugPrint('Checking for duplicate company...');
    final querySnapshot =
        await FirebaseFirestore.instance.collection('companies').get();

    final normalizedAr = nameAr.replaceAll(RegExp(r'\s+'), '').toLowerCase();
    final normalizedEn = nameEn.replaceAll(RegExp(r'\s+'), '').toLowerCase();

    for (var doc in querySnapshot.docs) {
      final existingAr = doc['name_ar']
          ?.toString()
          .replaceAll(RegExp(r'\s+'), '')
          .toLowerCase();
      final existingEn = doc['name_en']
          ?.toString()
          .replaceAll(RegExp(r'\s+'), '')
          .toLowerCase();

      if (existingAr == normalizedAr || existingEn == normalizedEn) {
        debugPrint('Duplicate company found: ${doc.id}');
        return true;
      }
    }
    debugPrint('No duplicate company found.');
    return false;
  }

  Future<void> _addCompany() async {
    if (_isLoading) return;

    final nameAr = _nameArController.text.trim();
    final nameEn = _nameEnController.text.trim();
    final address = _addressController.text.trim();
    final managerName = _managerNameController.text.trim();
    final managerPhone = _managerPhoneController.text.trim();

    debugPrint('Starting company add process...');
    debugPrint('Inputs: nameAr="$nameAr", nameEn="$nameEn", address="$address"');

    if (nameAr.isEmpty || nameEn.isEmpty || address.isEmpty) {
      debugPrint('Validation failed: required fields missing.');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('requierd_fields'.tr())),
      );
      return;
    }

    if (_base64Logo == null || _base64Logo!.isEmpty) {
      debugPrint('Validation failed: logo is missing.');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('please_select_logo'.tr())),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      debugPrint('Checking duplicate...');
      final isDuplicate = await _isCompanyDuplicate(nameAr, nameEn);
      if (isDuplicate) {
        if (!mounted) return;
        debugPrint('Duplicate company detected, aborting add.');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('⚠️ ${tr('company_already_exists')}')),
        );
        setState(() => _isLoading = false);
        return;
      }

      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        if (!mounted) return;
        debugPrint('No authenticated user found.');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('login_first'.tr())),
        );
        setState(() => _isLoading = false);
        return;
      }
      debugPrint('Authenticated user: ${user.uid}');

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
      debugPrint('Company data prepared.');

      final docRef = await FirebaseFirestore.instance
          .collection('companies')
          .add(companyData);
      debugPrint('Company added with id: ${docRef.id}');

      final userDocRef =
          FirebaseFirestore.instance.collection('users').doc(user.uid);
      final userDoc = await userDocRef.get();
      debugPrint('Fetched user doc for company update.');

      if (userDoc.exists) {
        debugPrint('User doc exists, updating companyIds array...');
        await userDocRef.update({
          'companyIds': FieldValue.arrayUnion([docRef.id]),
        });
      } else {
        debugPrint('User doc does not exist, creating new with companyIds...');
        await userDocRef.set({
          'companyIds': [docRef.id],
        });
      }

      if (!mounted) return;

      debugPrint('Company added and user updated successfully.');

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('company_added_successfully'.tr())),
      );

      await Future.delayed(const Duration(seconds: 1));

      if (!mounted) return;

      // إعادة تحميل الشبكة (يمكن حذفها إذا لم تكن ضرورية)
      await FirebaseFirestore.instance.disableNetwork();
      await FirebaseFirestore.instance.enableNetwork();

      if (!mounted) return;

      final uri = Uri(
        path: '/company-added/${docRef.id}',
        queryParameters: {'nameEn': nameEn},
      );
      debugPrint('Navigating to company added page: $uri');
      context.go(uri.toString());
    } catch (e, stacktrace) {
      debugPrint('Error while adding company: $e');
      debugPrint(stacktrace.toString());
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
              inputFormatters: [arabicOnlyFormatter],
            ),
            TextField(
              controller: _nameEnController,
              decoration:
                  InputDecoration(labelText: 'company_name_english'.tr()),
              inputFormatters: [englishOnlyFormatter],
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
              inputFormatters: [numbersOnlyFormatter],
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
