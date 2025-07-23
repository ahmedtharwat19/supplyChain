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
  User? _currentUser;

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

    if (_currentUser == null) {
      debugPrint('❌ المستخدم غير مسجل الدخول');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('login_first'.tr())),
      );
      return;
    }

    debugPrint(
        '🟡 بدء عملية إضافة الشركة بواسطة المستخدم: ${_currentUser!.uid}');
    debugPrint('📋 البيانات المُدخلة:');
    debugPrint('- الاسم بالعربية: $nameAr');
    debugPrint('- الاسم بالإنجليزية: $nameEn');
    debugPrint('- العنوان: $address');

    if (nameAr.isEmpty || nameEn.isEmpty || address.isEmpty) {
      debugPrint('❌ الحقول المطلوبة ناقصة');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('requierd_fields'.tr())),
      );
      return;
    }

    if (_base64Logo == null || _base64Logo!.isEmpty) {
      debugPrint('❌ لم يتم اختيار شعار');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('please_select_logo'.tr())),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      // التحقق من تكرار الشركة
      debugPrint('🔍 التحقق من وجود شركة مكررة...');
      final isDuplicate = await _isCompanyDuplicate(nameAr, nameEn);
      if (isDuplicate) {
        debugPrint('⚠️ الشركة مكررة بالفعل');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('⚠️ ${tr('company_already_exists')}')),
          );
        }
        setState(() => _isLoading = false);
        return;
      }

      final firestore = FirebaseFirestore.instance;
      final companyId = firestore.collection('companies').doc().id;
      final companyRef = firestore.collection('companies').doc(companyId);
      final userRef = firestore.collection('users').doc(_currentUser!.uid);

      final companyData = {
        'name_ar': nameAr,
        'name_en': nameEn,
        'address': address,
        'manager_name': managerName,
        'manager_phone': managerPhone,
        'logo_base64': _base64Logo,
        'user_id': _currentUser!.uid,
        'createdAt': Timestamp.now(),
      };

      debugPrint('🛠️ بدء المعاملة لإضافة الشركة وتحديث المستخدم');
      await firestore.runTransaction((transaction) async {
        // إضافة مستند الشركة الجديد
        transaction.set(companyRef, companyData);

        // جلب بيانات المستخدم
        final userSnap = await transaction.get(userRef);

        if (userSnap.exists) {
          // تحديث قائمة الشركات لدى المستخدم
          transaction.update(userRef, {
            'companyIds': FieldValue.arrayUnion([companyId]),
          });
          debugPrint('🔁 تحديث قائمة الشركات لدى المستخدم');
        } else {
          // إنشاء مستند مستخدم جديد مع الشركة
          transaction.set(userRef, {
            'companyIds': [companyId],
            'createdAt': Timestamp.now(),
          });
          debugPrint('🆕 إنشاء مستند مستخدم جديد مع الشركة');
        }
      });

      debugPrint('✅ تمت العملية بنجاح');

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('company_added_successfully'.tr())),
      );

      await Future.delayed(const Duration(seconds: 1));

      final uri = Uri(
        path: '/company-added/$companyId',
        queryParameters: {'nameEn': nameEn},
      );

      debugPrint('🚀 الانتقال إلى: $uri');
      if (mounted) {
        context.go(uri.toString());
      }
    } catch (e, stacktrace) {
      debugPrint('❌ استثناء أثناء إضافة الشركة: $e');
      debugPrint(stacktrace.toString());

      String userMessage = tr('error_while_adding_company');
      if (e.toString().contains('permission-denied')) {
        userMessage = tr('permission_denied_hint');
      } else if (e.toString().contains('network')) {
        userMessage = tr('network_error');
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ $userMessage')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

/* 
  Future<void> _addCompany() async {
    if (_isLoading) return;

    final nameAr = _nameArController.text.trim();
    final nameEn = _nameEnController.text.trim();
    final address = _addressController.text.trim();
    final managerName = _managerNameController.text.trim();
    final managerPhone = _managerPhoneController.text.trim();

    debugPrint('🟡 بدء عملية إضافة الشركة');
    debugPrint('📋 البيانات المُدخلة:');
    debugPrint('- الاسم بالعربية: $nameAr');
    debugPrint('- الاسم بالإنجليزية: $nameEn');
    debugPrint('- العنوان: $address');

    if (_currentUser == null) {
      debugPrint('❌ المستخدم غير مسجل في _addCompany');
      return;
    }
    debugPrint('✅ المستخدم داخل _addCompany: ${_currentUser!.uid}');

    if (nameAr.isEmpty || nameEn.isEmpty || address.isEmpty) {
      debugPrint('❌ حقول مطلوبة ناقصة');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('requierd_fields'.tr())),
      );
      return;
    }

    if (_base64Logo == null || _base64Logo!.isEmpty) {
      debugPrint('❌ لم يتم اختيار شعار');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('please_select_logo'.tr())),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      debugPrint('🔍 التحقق من تكرار الشركة...');
      final isDuplicate = await _isCompanyDuplicate(nameAr, nameEn);
      if (isDuplicate) {
        debugPrint('⚠️ الشركة مكررة');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('⚠️ ${tr('company_already_exists')}')),
          );
        }
        setState(() => _isLoading = false);
        return;
      }

      final currentUser = FirebaseAuth.instance.currentUser;
      debugPrint(
          '📍 currentUser داخل _addCompany: ${currentUser?.uid ?? "null"}');
      if (currentUser == null) {
        debugPrint('❌ المستخدم غير مسجل الدخول');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('login_first'.tr())),
          );
        }
        setState(() => _isLoading = false);
        return;
      }

      final uid = currentUser.uid;
      debugPrint('✅ المستخدم  uid  المسجل: $uid');

      final firestore = FirebaseFirestore.instance;
      final companyId = firestore.collection('companies').doc().id;

      final companyRef = firestore.collection('companies').doc(companyId);
      final userRef = firestore.collection('users').doc(uid);

      final companyData = {
        'name_ar': nameAr,
        'name_en': nameEn,
        'address': address,
        'manager_name': managerName,
        'manager_phone': managerPhone,
        'logo_base64': _base64Logo,
        'user_id': _currentUser!.uid,
        'createdAt': Timestamp.now(),
      };

      debugPrint('🛠️ إعداد البيانات... سيتم بدء المعاملة');
      debugPrint('🆔 معرف الشركة: $companyId');

      await firestore.runTransaction((transaction) async {
        // إضافة الشركة
        transaction.set(companyRef, companyData);
        debugPrint('✅ الشركة تم إدراجها في قاعدة البيانات');

        final userSnap = await transaction.get(userRef);

        if (userSnap.exists) {
          debugPrint('🔁 تحديث مستخدم حالي');
          transaction.update(userRef, {
            'companyIds': FieldValue.arrayUnion([companyId]),
          });
        } else {
          debugPrint('🆕 إنشاء مستخدم جديد وربطه بالشركة');
          transaction.set(userRef, {
            'companyIds': [companyId],
            'createdAt': Timestamp.now(),
          });
        }
      });

      debugPrint('✅ تمت العملية بنجاح');

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('company_added_successfully'.tr())),
      );

      await Future.delayed(const Duration(seconds: 1));

      final uri = Uri(
        path: '/company-added/$companyId',
        queryParameters: {'nameEn': nameEn},
      );

      debugPrint('🚀 الانتقال إلى: $uri');
      if (mounted) {
        context.go(uri.toString());
      }
    } catch (e, stacktrace) {
      debugPrint('❌ استثناء أثناء إضافة الشركة: $e');
      debugPrint(stacktrace.toString());

      if (mounted) {
        String userMessage = tr('error_while_adding_company');

        if (e.toString().contains('permission-denied')) {
          userMessage = tr('permission_denied_hint'); // نضيف ترجمة لهذه لاحقًا
        } else if (e.toString().contains('network')) {
          userMessage = tr('network_error'); // أيضًا نضيف ترجمة لها
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ $userMessage')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
 */
/* 
    Future<void> _addCompany() async {
      if (_isLoading) return;

      final nameAr = _nameArController.text.trim();
      final nameEn = _nameEnController.text.trim();
      final address = _addressController.text.trim();
      final managerName = _managerNameController.text.trim();
      final managerPhone = _managerPhoneController.text.trim();

      debugPrint('🔁 بدء إضافة الشركة...');
      debugPrint(
          '🔍 بيانات الإدخال: nameAr="$nameAr", nameEn="$nameEn", address="$address"');

      if (nameAr.isEmpty || nameEn.isEmpty || address.isEmpty) {
        debugPrint('❌ الحقول المطلوبة ناقصة');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('requierd_fields'.tr())),
        );
        return;
      }

      if (_base64Logo == null || _base64Logo!.isEmpty) {
        debugPrint('❌ الشعار غير محدد');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('please_select_logo'.tr())),
        );
        return;
      }

      setState(() => _isLoading = true);

      try {
        debugPrint('🔍 التحقق من وجود شركة مكررة...');
        final isDuplicate = await _isCompanyDuplicate(nameAr, nameEn);
        if (isDuplicate) {
          if (!mounted) return;
          debugPrint('⚠️ تم العثور على شركة مكررة، يتم الإيقاف');
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('⚠️ ${tr('company_already_exists')}')),
          );
          setState(() => _isLoading = false);
          return;
        }

        final currentUser = FirebaseAuth.instance.currentUser;
        if (currentUser == null) {
          if (!mounted) return;
          debugPrint('❌ المستخدم غير مسجل الدخول');
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('login_first'.tr())),
          );
          setState(() => _isLoading = false);
          return;
        }

        debugPrint('✅ المستخدم الحالي: ${currentUser.uid}');

        final firestore = FirebaseFirestore.instance;
        final companyId = firestore.collection('companies').doc().id;

        final companyRef = firestore.collection('companies').doc(companyId);
        final userRef = firestore.collection('users').doc(currentUser.uid);
        debugPrint('companies $companyId');
        debugPrint('users $currentUser');
        


        final companyData = {
          'name_ar': nameAr,
          'name_en': nameEn,
          'address': address,
          'manager_name': managerName,
          'manager_phone': managerPhone,
          'logo_base64': _base64Logo,
          'user_id': currentUser.uid,
        //  'companyId': companyId,
          'createdAt': Timestamp.now(),
        };

        debugPrint('📦 البيانات جاهزة، جاري التنفيذ داخل المعاملة...');

        await firestore.runTransaction((transaction) async {
          // إنشاء الشركة
          transaction.set(companyRef, companyData);
        //  transaction.set(companyRef, companyData);

          // جلب بيانات المستخدم
          final userSnap = await transaction.get(userRef);

          if (userSnap.exists) {
            debugPrint('🔁 تحديث قائمة الشركات لدى المستخدم');
            transaction.update(userRef, {
              'companyIds': FieldValue.arrayUnion([companyId]),
            });
          } else {
            debugPrint('🆕 إنشاء مستند مستخدم جديد مع الشركة');
            transaction.set(userRef, {
              'companyIds': [companyId],
              'createdAt': Timestamp.now(),
            });
          }
        });

        debugPrint('✅ تم إضافة الشركة وتحديث المستخدم بنجاح.');

        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('company_added_successfully'.tr())),
        );

        await Future.delayed(const Duration(seconds: 1));

        if (!mounted) return;

        final uri = Uri(
          path: '/company-added/$companyId',
          queryParameters: {'nameEn': nameEn},
        );
        debugPrint('🚀 الانتقال إلى صفحة نجاح: $uri');
        context.go(uri.toString());
      } catch (e, stacktrace) {
        debugPrint('❌ خطأ أثناء إضافة الشركة: $e');
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
 */
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
  void initState() {
    super.initState();
    _currentUser = FirebaseAuth.instance.currentUser;
    debugPrint(
        '👤 المستخدم الحالي في initState: ${_currentUser?.uid ?? "null"}');
    final user = FirebaseAuth.instance.currentUser;
    debugPrint('👤 المستخدم الحالي في initState: ${user?.uid ?? "لا يوجد"}');
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
