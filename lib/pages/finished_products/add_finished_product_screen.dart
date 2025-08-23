import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:puresip_purchasing/models/manufacturing_order_model.dart';
import 'package:puresip_purchasing/pages/manufacturing/services/manufacturing_service.dart';
import 'package:easy_localization/easy_localization.dart';

class AddFinishedProductScreen extends StatefulWidget {
  const AddFinishedProductScreen({super.key});

  @override
  State<AddFinishedProductScreen> createState() => _AddFinishedProductScreenState();
}

class _AddFinishedProductScreenState extends State<AddFinishedProductScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _quantityController = TextEditingController();
  final TextEditingController _shelfLifeController = TextEditingController();

  final List<RawMaterial> _rawMaterials = [];
  final TextEditingController _materialNameController = TextEditingController();
  final TextEditingController _materialQuantityController = TextEditingController();
  final TextEditingController _materialUnitController = TextEditingController();
  final TextEditingController _minStockController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('manufacturing.add_finished_product'.tr()),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              TextFormField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: 'manufacturing.product_name'.tr(),
                  border: const OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'manufacturing.enter_product_name'.tr();
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _quantityController,
                decoration: InputDecoration(
                  labelText: 'manufacturing.quantity_produced'.tr(),
                  border: const OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'manufacturing.enter_quantity'.tr();
                  }
                  if (int.tryParse(value) == null) {
                    return 'manufacturing.enter_valid_number'.tr();
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _shelfLifeController,
                decoration: InputDecoration(
                  labelText: 'manufacturing.shelf_life'.tr(),
                  border: const OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'manufacturing.enter_shelf_life'.tr();
                  }
                  if (int.tryParse(value) == null) {
                    return 'manufacturing.enter_valid_number'.tr();
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),
              Text(
                'manufacturing.raw_materials'.tr(),
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              ..._rawMaterials.map((material) => ListTile(
                title: Text(material.materialName),
                subtitle: Text('${material.quantityRequired} ${material.unit}'),
                trailing: IconButton(
                  icon: const Icon(Icons.delete),
                  onPressed: () => _removeMaterial(material),
                ),
              )),
              const SizedBox(height: 16),
              TextFormField(
                controller: _materialNameController,
                decoration: InputDecoration(
                  labelText: 'manufacturing.material_name'.tr(),
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _materialQuantityController,
                      decoration: InputDecoration(
                        labelText: 'manufacturing.quantity'.tr(),
                        border: const OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextFormField(
                      controller: _materialUnitController,
                      decoration: InputDecoration(
                        labelText: 'manufacturing.unit'.tr(),
                        border: const OutlineInputBorder(),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _minStockController,
                decoration: const InputDecoration(
                  labelText: 'الحد الأدنى للمخزون',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 8),
              ElevatedButton(
                onPressed: _addMaterial,
                child: Text('manufacturing.add_raw_material'.tr()),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _submitForm,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: Text('manufacturing.save_product'.tr()),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _addMaterial() {
    if (_materialNameController.text.isNotEmpty &&
        _materialQuantityController.text.isNotEmpty &&
        _materialUnitController.text.isNotEmpty) {
      setState(() {
        _rawMaterials.add(RawMaterial(
          materialId: DateTime.now().millisecondsSinceEpoch.toString(),
          materialName: _materialNameController.text,
          quantityRequired: double.parse(_materialQuantityController.text),
          unit: _materialUnitController.text,
          minStockLevel: double.parse(_minStockController.text),
        ));
        _materialNameController.clear();
        _materialQuantityController.clear();
        _materialUnitController.clear();
        _minStockController.clear();
      });
    }
  }

  void _removeMaterial(RawMaterial material) {
    setState(() {
      _rawMaterials.remove(material);
    });
  }

  void _submitForm() async {
    if (_formKey.currentState!.validate() && _rawMaterials.isNotEmpty) {
      try {
        final manufacturingService = Provider.of<ManufacturingService>(context, listen: false);
        
        final expiryDate = DateTime.now().add(
          Duration(days: int.parse(_shelfLifeController.text))
        );

        final batchNumber = 'B${DateTime.now().millisecondsSinceEpoch}';

        // إنشاء باركود
        final barcodeUrl = await manufacturingService.generateBarcode(batchNumber);

        final order = ManufacturingOrder(
          id: '',
          batchNumber: batchNumber,
          productId: DateTime.now().millisecondsSinceEpoch.toString(),
          productName: _nameController.text,
          quantity: int.parse(_quantityController.text),
          manufacturingDate: DateTime.now(),
          expiryDate: expiryDate,
          status: ManufacturingStatus.pending,
          isFinished: false,
          rawMaterials: _rawMaterials,
          createdAt: DateTime.now(),
          barcodeUrl: barcodeUrl,
        );

        await manufacturingService.createManufacturingOrder(order);
        if(!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('manufacturing.product_added_success'.tr()))
        );
        Navigator.pop(context);
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${'manufacturing.add_error'.tr()}: $e'))
        );
      }
    }
  }
}