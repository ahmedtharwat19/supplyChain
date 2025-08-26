// add_composition_screen.dart
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:puresip_purchasing/models/company.dart';
import 'package:puresip_purchasing/models/factory.dart';
import 'package:puresip_purchasing/models/product_composition_model.dart';
import 'package:puresip_purchasing/pages/compositions/services/composition_service.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:puresip_purchasing/models/item.dart';
import 'package:puresip_purchasing/services/firestore_service.dart';
import 'package:puresip_purchasing/utils/user_local_storage.dart';
import '../purchasing/item_selection_dialog.dart';

class AddCompositionScreen extends StatefulWidget {
  final String productId;
//  final String productName; // تم إضافة هذا المتغير

  const AddCompositionScreen({
    super.key,
    required this.productId,
//    required this.productName, // تم إضافة هذا الباراميتر
  });

  @override
  State<AddCompositionScreen> createState() => _AddCompositionScreenState();
}

class _AddCompositionScreenState extends State<AddCompositionScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _batchSizeController = TextEditingController();
  final TextEditingController _shelfLifeController = TextEditingController();
  final TextEditingController _unitController = TextEditingController();
  final FirestoreService _firestoreService = FirestoreService();
  //final _auth = FirebaseAuth.instance;
  String? _selectedCompanyId;
  String? _selectedFactoryId;
  final List<CompositionItem> _rawMaterials = [];
  final List<CompositionItem> _packagingMaterials = [];
  List<Item> _itemsRaws = [];
  List<Item> _itemsPackage = [];
  final List<Item> _items = [];
 // bool _isLoading = false;
  List<Company> _companies = [];
  List<Factory> _factories = [];

  @override
  void initState() {
    super.initState();

    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    debugPrint('⬇️ Start loading initial data...');
   // setState(() => _isLoading = true);

    try {
      final user = await UserLocalStorage.getUser();
      debugPrint('🧑 user from storage: $user');

      if (user == null) {
        debugPrint('❌ User is null, stopping load.');
      //  setState(() => _isLoading = false);
        return;
      }

      final userId = user['userId'] as String;
      final companyIds = (user['companyIds'] as List?)?.cast<String>() ?? [];
      debugPrint('🚀 userId: $userId');
      debugPrint('🚀 companyIds: $companyIds');
      final currentUser = FirebaseAuth.instance.currentUser;
      debugPrint('Current Firebase userId: ${currentUser?.uid}');
      debugPrint('UserId from local storage: $userId');
      if (companyIds.isEmpty) {
        debugPrint('❌ companyIds is empty, stopping load.');
       // setState(() => _isLoading = false);
        return;
      }

      final companies = await _firestoreService.getUserCompanies(companyIds);
      debugPrint('✅ Loaded companies count: ${companies.length}');

      final itemsRaws = await _firestoreService.getUserTypeItems(userId, 'raw_material');
      debugPrint('✅ Loaded items count: ${itemsRaws.length}');
      final itemsPackage = await _firestoreService.getUserTypeItems(userId, 'packaging');
      debugPrint('✅ Loaded items count: ${itemsPackage.length}');



      List<Factory> factories = [];
      if (_selectedCompanyId != null) {
        factories =
            await _firestoreService.getUserFactories(userId, companyIds).first;
        debugPrint('✅ Loaded factories count: ${factories.length}');
      }

      if (!mounted) return;

      setState(() {
        _companies = companies;

        _itemsRaws = itemsRaws;
        _itemsPackage = itemsPackage;
        _factories = factories;

        if (_companies.isNotEmpty &&
            (_selectedCompanyId == null ||
                !_companies.any((c) => c.id == _selectedCompanyId))) {
          _selectedCompanyId = _companies.first.id;
          debugPrint(
              'ℹ️ _selectedCompanyId was reset to first company: $_selectedCompanyId');
        }

        if (_factories.isNotEmpty && _selectedFactoryId == null) {
          _selectedFactoryId = _factories.first.id;
          debugPrint(
              'ℹ️ _selectedFactoryId was set to first factory: $_selectedFactoryId');
        }
      });

      debugPrint('📊 State after loading:');
      debugPrint('  _companies.length: ${_companies.length}');
      debugPrint('  _allItems.length: ${_itemsRaws.length}');
      debugPrint('  _factories.length: ${_factories.length}');
      debugPrint('  _selectedCompanyId: $_selectedCompanyId');
      debugPrint('  _selectedFactoryId: $_selectedFactoryId');
    } catch (e, st) {
      debugPrint('❌ Exception in _loadInitialData: $e');
      debugPrint(st.toString());
      _showErrorSnackbar('error_loading_data'.tr());
    } finally {
    //  if (mounted) setState(() => _isLoading = false);
      debugPrint('⬆️ Finished loading initial data.');
    }
  }

  void _showErrorSnackbar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _showItemSelectionDialog(String itemCategory) async {
    final selected = await showDialog<List<Item>>(
      context: context,
      builder: (_) => ItemSelectionDialog(
        allItems: itemCategory == 'raw_material' ? _itemsRaws : _itemsPackage,
        preSelectedItems: _items.map((i) => i.itemId).toList(),
      ),
    );
    if (selected == null || selected.isEmpty) return;
    setState(() {
      for (var i in selected) {
        if (!_items.any((e) => e.itemId == i.itemId)) {
          _items.add(i);
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // final companyService = Provider.of<CompanyService>(context);
    // final factoryService = Provider.of<FactoryService>(context);

    return Scaffold(
      appBar: AppBar(
        title: Text('add_composition'.tr()),
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: _saveComposition,
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              Text(
                widget.productId, // استخدام widget.productName
                style:
                    const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),

              // ... باقي الحقول بنفس الشكل

              const SizedBox(height: 16),

              // حجم التشغيلة
              TextFormField(
                controller: _batchSizeController,
                decoration: InputDecoration(
                  labelText: 'batch_size'.tr(),
                  border: const OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'enter_batch_size'.tr();
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // الوحدة
              TextFormField(
                controller: _unitController,
                decoration: InputDecoration(
                  labelText: 'unit'.tr(),
                  border: const OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'enter_unit'.tr();
                  }
                  return null;
                },
              ),

              const SizedBox(height: 16),

              // مدة الصلاحية
              TextFormField(
                controller: _shelfLifeController,
                decoration: InputDecoration(
                  labelText: 'shelf_life_months'.tr(),
                  border: const OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'enter_shelf_life'.tr();
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                icon: const Icon(Icons.add),
                label: Text('add_raws'.tr()),
                onPressed: () => _showItemSelectionDialog('raw_material'),
              ),
                            ElevatedButton.icon(
                icon: const Icon(Icons.add),
                label: Text('add_packageing'.tr()),
                onPressed: () => _showItemSelectionDialog('packaging'),
              ),
              _items.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Text(
                        'no_items_added_to_composition'.tr(),
                        style:
                            const TextStyle(fontSize: 16, color: Colors.grey),
                      ),
                    )
                  : ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _items.length,
                      itemBuilder: (context, index) {
                        final item = _items[index];

                        return Card(
                          color: Colors.grey[100],
                          margin: const EdgeInsets.symmetric(vertical: 8),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 2,
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // اسم الصنف
                                Text(
                                  context.locale.languageCode == 'ar'
                                      ? item.nameAr
                                      : item.nameEn,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 18,
                                    color: Colors.black87,
                                  ),
                                ),
                                const SizedBox(height: 12),

                                // الكمية والسعر في صف واحد
                                Row(
                                  children: [
                                    Expanded(
                                      child: TextFormField(
                                        initialValue: item.quantity.toString(),
                                        decoration: InputDecoration(
                                          labelText: 'quantity'.tr(),
                                          border: const OutlineInputBorder(),
                                        ),
                                        keyboardType: TextInputType.number,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                  ],
                                ),
                                const SizedBox(height: 12),

                                const Divider(),
                              ],
                            ),
                          ),
                        );
                      }),

              const SizedBox(height: 16),
              // يمكن إضافة واجهة لإدارة المواد الخام ومواد التعبئة هنا
              // ... (سيتم إضافتها في الخطوة التالية)
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _saveComposition() async {
    if (_formKey.currentState!.validate()) {
   //   setState(() => _isLoading = true);
      try {
        final compositionService =
            Provider.of<CompositionService>(context, listen: false);

        final composition = ProductComposition(
          productId: widget.productId, // استخدام widget.productName
          companyId: _selectedCompanyId!,
          factoryId: _selectedFactoryId!,
          batchSize: double.parse(_batchSizeController.text),
          unit: _unitController.text,
          rawMaterials: _rawMaterials,
          packagingMaterials: _packagingMaterials,
          shelfLife: int.parse(_shelfLifeController.text),
          createdAt: Timestamp.now(),
          userId: '', // سيتم إضافة ID المستخدم الحالي
        );

        await compositionService.saveComposition(composition);

        if (!mounted) return;
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('composition_saved'.tr())),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${'error'.tr()}: $e')),
        );
      }
    }
  }
}
