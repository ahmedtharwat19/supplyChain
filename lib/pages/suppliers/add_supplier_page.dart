import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:puresip_purchasing/models/supplier.dart';
import 'package:puresip_purchasing/utils/user_local_storage.dart';

class AddSupplierPage extends StatefulWidget {
  const AddSupplierPage({super.key});

  @override
  State<AddSupplierPage> createState() => _AddSupplierPageState();
}

class _AddSupplierPageState extends State<AddSupplierPage> {
  final _formKey = GlobalKey<FormState>();

  final _nameFocus = FocusNode();
  final _companyFocus = FocusNode();
  final _phoneFocus = FocusNode();
  final _emailFocus = FocusNode();
  final _addressFocus = FocusNode();
  final _notesFocus = FocusNode();

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _companyController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();

  bool _isLoading = false;

  Future<bool> _isSupplierDuplicate(String name) async {
    final userData = await UserLocalStorage.getUser();
    if (userData == null) return false;

    final userId = userData['userId']!;

    final querySnapshot = await FirebaseFirestore.instance
        .collection('vendors')
        .where(Supplier.fieldUserId, isEqualTo: userId)
        .where(Supplier.fieldName, isEqualTo: name)
        .get();

    return querySnapshot.docs.isNotEmpty;
  }

  String? _validateName(String? value) {
    if (value == null || value.trim().isEmpty) {
      return tr('required_field');
    }
    return null;
  }

  String? _validatePhone(String? value) {
    if (value == null || value.trim().isEmpty) return null; // هاتف اختياري
    final phoneRegex = RegExp(r'^\+?\d{7,15}$');
    if (!phoneRegex.hasMatch(value.trim())) {
      return tr('invalid_phone');
    }
    return null;
  }

  String? _validateEmail(String? value) {
    if (value == null || value.trim().isEmpty) return null; // إيميل اختياري
    final emailRegex = RegExp(
      r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$',
    );
    if (!emailRegex.hasMatch(value.trim())) {
      return tr('invalid_email');
    }
    return null;
  }

  Future<void> _addSupplier() async {
    if (!_formKey.currentState!.validate()) return;

    final userData = await UserLocalStorage.getUser();
    if (userData == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr('user_not_logged_in'))),
      );
      return;
    }
    final userId = userData['userId']!;

    final isDuplicate = await _isSupplierDuplicate(_nameController.text.trim());
    if (isDuplicate) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr('supplier_already_exists'))),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final supplier = Supplier(
        name: _nameController.text.trim(),
        company: _companyController.text.trim(),
        phone: _phoneController.text.trim(),
        email: _emailController.text.trim(),
        address: _addressController.text.trim(),
        notes: _notesController.text.trim(),
        userId: userId,
        createdAt: Timestamp.now(),
      );

      await FirebaseFirestore.instance.collection('vendors').add(supplier.toMap());
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr('supplier_added'))),
      );

      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${tr('error_occurred')}: $e')),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _nameFocus.dispose();
    _companyFocus.dispose();
    _phoneFocus.dispose();
    _emailFocus.dispose();
    _addressFocus.dispose();
    _notesFocus.dispose();

    _nameController.dispose();
    _companyController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _addressController.dispose();
    _notesController.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(tr('add_supplier'))),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              TextFormField(
                controller: _nameController,
                focusNode: _nameFocus,
                textInputAction: TextInputAction.next,
                decoration: InputDecoration(labelText: tr('name')),
                validator: _validateName,
                onFieldSubmitted: (_) {
                  FocusScope.of(context).requestFocus(_companyFocus);
                },
              ),
              TextFormField(
                controller: _companyController,
                focusNode: _companyFocus,
                textInputAction: TextInputAction.next,
                decoration: InputDecoration(labelText: tr('company')),
                onFieldSubmitted: (_) {
                  FocusScope.of(context).requestFocus(_phoneFocus);
                },
              ),
              TextFormField(
                controller: _phoneController,
                focusNode: _phoneFocus,
                textInputAction: TextInputAction.next,
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(labelText: tr('phone')),
                validator: _validatePhone,
                onFieldSubmitted: (_) {
                  FocusScope.of(context).requestFocus(_emailFocus);
                },
              ),
              TextFormField(
                controller: _emailController,
                focusNode: _emailFocus,
                textInputAction: TextInputAction.next,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(labelText: tr('email')),
                validator: _validateEmail,
                onFieldSubmitted: (_) {
                  FocusScope.of(context).requestFocus(_addressFocus);
                },
              ),
              TextFormField(
                controller: _addressController,
                focusNode: _addressFocus,
                textInputAction: TextInputAction.next,
                decoration: InputDecoration(labelText: tr('address')),
                onFieldSubmitted: (_) {
                  FocusScope.of(context).requestFocus(_notesFocus);
                },
              ),
              TextFormField(
                controller: _notesController,
                focusNode: _notesFocus,
                textInputAction: TextInputAction.done,
                decoration: InputDecoration(labelText: tr('notes')),
                maxLines: 3,
                onFieldSubmitted: (_) {
                  _addSupplier();
                },
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _isLoading ? null : _addSupplier,
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : Text(tr('add')),
              ),
            ],
          ),
        ),
      ),
    );
  }
}


/* import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:go_router/go_router.dart';

class AddSupplierPage extends StatefulWidget {
  const AddSupplierPage({super.key});

  @override
  State<AddSupplierPage> createState() => _AddSupplierPageState();
}

class _AddSupplierPageState extends State<AddSupplierPage> {
  final _nameController = TextEditingController();
  final _companyController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _addressController = TextEditingController();
  final _notesController = TextEditingController();

  bool _isLoading = false;
  User? _currentUser;

  @override
  void initState() {
    super.initState();
    _currentUser = FirebaseAuth.instance.currentUser;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _companyController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _addressController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<bool> _checkUserActive() async {
    final userId = _currentUser?.uid;
    if (userId == null) return false;

    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();

      if (!userDoc.exists) return false;
      final isActive = userDoc.data()?['is_active'] ?? false;
      return isActive == true;
    } catch (e) {
      debugPrint('Error checking user active status: $e');
      return false;
    }
  }

  // التحقق من تكرار المورد بناءً على الاسم ضمن الموردين المرتبطين بالمستخدم
  Future<bool> _isSupplierDuplicate(String name) async {
    final userId = _currentUser?.uid;
    if (userId == null) return false;

    final userDoc =
        await FirebaseFirestore.instance.collection('users').doc(userId).get();
    final supplierIds = List<String>.from(userDoc.data()?['supplierIds'] ?? []);

    if (supplierIds.isEmpty) return false;

    final snapshot = await FirebaseFirestore.instance
        .collection('vendors')
        .where(FieldPath.documentId, whereIn: supplierIds)
        .get();

    final normalizedName = name.trim().toLowerCase();

    for (var doc in snapshot.docs) {
      final existingName = (doc['name'] ?? '').toString().trim().toLowerCase();
      if (existingName == normalizedName) {
        return true;
      }
    }

    return false;
  }

  bool _validateInputs() {
    if (_nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr('required'))),
      );
      return false;
    }

    // يمكنك إضافة المزيد من التحقق على الحقول الأخرى إذا أردت

    if (_emailController.text.isNotEmpty &&
        !_emailController.text.contains('@')) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr('invalid_email'))),
      );
      return false;
    }

    return true;
  }

  Future<void> _addSupplier() async {
    if (!_validateInputs()) return;

    final userId = _currentUser?.uid;
    if (userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr('user_not_logged_in'))),
      );
      return;
    }

    final isActive = await _checkUserActive();
    if (!isActive) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr('user_not_active'))),
      );
      return;
    }

    final name = _nameController.text.trim();
    final isDuplicate = await _isSupplierDuplicate(name);
    if (isDuplicate) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr('supplier_already_exists'))),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final supplierData = {
        'name': name,
        'company': _companyController.text.trim(),
        'phone': _phoneController.text.trim(),
        'email': _emailController.text.trim(),
        'address': _addressController.text.trim(),
        'notes': _notesController.text.trim(),
        'user_id': userId,
        'createdAt': FieldValue.serverTimestamp(),
      };

      final docRef = await FirebaseFirestore.instance
          .collection('vendors')
          .add(supplierData);

      final userDocRef =
          FirebaseFirestore.instance.collection('users').doc(userId);
      await userDocRef.update({
        'supplierIds': FieldValue.arrayUnion([docRef.id]),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(tr('supplier_added'))),
        );
        context.pop();
      }
    } catch (e) {
      debugPrint('Error adding supplier: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${tr('error_occurred')}: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(tr('add_supplier'))),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16),
              child: ListView(
                children: [
                  TextField(
                    controller: _nameController,
                    decoration: InputDecoration(labelText: tr('name')),
                    textInputAction: TextInputAction.next,
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _companyController,
                    decoration: InputDecoration(labelText: tr('company')),
                    textInputAction: TextInputAction.next,
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _phoneController,
                    decoration: InputDecoration(labelText: tr('phone')),
                    keyboardType: TextInputType.phone,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    textInputAction: TextInputAction.next,
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _emailController,
                    decoration: InputDecoration(labelText: tr('email')),
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _addressController,
                    decoration: InputDecoration(labelText: tr('address')),
                    textInputAction: TextInputAction.next,
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _notesController,
                    decoration: InputDecoration(labelText: tr('notes')),
                    textInputAction: TextInputAction.next,
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: _addSupplier,
                    child: Text(tr('save')),
                  ),
                ],
              ),
            ),
    );
  }
}
 */