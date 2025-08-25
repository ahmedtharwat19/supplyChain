// add_composition_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:puresip_purchasing/models/product_composition_model.dart';
import 'package:puresip_purchasing/pages/finished_products/services/composition_service.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

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

  String? _selectedCompanyId;
  String? _selectedFactoryId;
  final List<CompositionItem> _rawMaterials = [];
  final List<CompositionItem> _packagingMaterials = [];

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
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
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
      try {
        final compositionService = Provider.of<CompositionService>(context, listen: false);

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