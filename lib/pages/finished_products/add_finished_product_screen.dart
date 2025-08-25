import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:puresip_purchasing/models/company.dart';
import 'package:puresip_purchasing/models/factory.dart';
import 'package:puresip_purchasing/models/finished_product.dart';
import 'package:puresip_purchasing/pages/finished_products/services/finished_product_service.dart';
import 'package:puresip_purchasing/services/company_service.dart';
//import 'package:puresip_purchasing/services/factory_service.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AddFinishedProductScreen extends StatefulWidget {
  const AddFinishedProductScreen({super.key});

  @override
  State<AddFinishedProductScreen> createState() => _AddFinishedProductScreenState();
}

class _AddFinishedProductScreenState extends State<AddFinishedProductScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _quantityController = TextEditingController();
  final TextEditingController _unitController = TextEditingController();
  final TextEditingController _shelfLifeController = TextEditingController();

  String? _selectedCompanyId;
  String? _selectedFactoryId;
  final User? _currentUser = FirebaseAuth.instance.currentUser;
  final bool _isArabic = false;
  bool _isLoading = false;
  bool _loadingFactories = false;

  // قائمة المصانع للشركة المحددة
  List<Factory> _factories = [];

  @override
  Widget build(BuildContext context) {
    final companyService = Provider.of<CompanyService>(context);
  //  final factoryService = Provider.of<FactoryService>(context);

    return Scaffold(
      appBar: AppBar(
        title: Text('manufacturing.add_finished_product'.tr()),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Form(
                key: _formKey,
                child: ListView(
                  children: [
                    // اسم المنتج التام
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

                    // الكمية المنتجة
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
                        if (double.tryParse(value) == null) {
                          return 'manufacturing.enter_valid_number'.tr();
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // الوحدة
                    TextFormField(
                      controller: _unitController,
                      decoration: InputDecoration(
                        labelText: 'manufacturing.unit'.tr(),
                        border: const OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'manufacturing.enter_unit'.tr();
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // مدة الصلاحية بالأشهر
                    TextFormField(
                      controller: _shelfLifeController,
                      decoration: InputDecoration(
                        labelText: 'manufacturing.shelf_life_months'.tr(),
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
                    const SizedBox(height: 16),

                    // اختيار الشركة
                    StreamBuilder<List<Company>>(
                      stream: companyService.getUserCompanies(_currentUser!.uid),
                      builder: (context, snapshot) {
                        if (snapshot.hasError) {
                          return Text('manufacturing.error_loading_companies'.tr());
                        }

                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return const CircularProgressIndicator();
                        }

                        if (snapshot.hasData && snapshot.data!.isNotEmpty) {
                          return DropdownButtonFormField<String>(
                            initialValue: _selectedCompanyId,
                            decoration: InputDecoration(
                              labelText: 'company'.tr(),
                              border: const OutlineInputBorder(),
                            ),
                            items: [
                              DropdownMenuItem(
                                value: null,
                                child: Text('select_company'.tr()),
                              ),
                              ...snapshot.data!.map((company) {
                                return DropdownMenuItem(
                                  value: company.id,
                                  child: Text(_isArabic ? company.nameAr : company.nameEn),
                                );
                              }),
                            ],
                            onChanged: (value) async {
                              setState(() {
                                _selectedCompanyId = value;
                                _selectedFactoryId = null;
                                _factories = [];
                                _loadingFactories = true;
                              });

                              // تحميل المصانع عند اختيار الشركة
                              if (value != null) {
                                try {
                                  final factoriesSnapshot = await FirebaseFirestore.instance
                                      .collection('factories')
                                      .where('companyIds', arrayContains: value)
                                      .get();

                                  final factories = factoriesSnapshot.docs
                                      .map((doc) => Factory.fromMap(doc.data(), doc.id))
                                      .toList();

                                  setState(() {
                                    _factories = factories;
                                    _loadingFactories = false;
                                  });
                                } catch (e) {
                                  setState(() {
                                    _loadingFactories = false;
                                  });
                                  if (!context.mounted)return;
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('manufacturing.error_loading_factories'.tr())),
                                  );
                                }
                              } else {
                                setState(() {
                                  _loadingFactories = false;
                                });
                              }
                            },
                            validator: (value) {
                              if (value == null) {
                                return 'select_company'.tr();
                              }
                              return null;
                            },
                          );
                        }
                        return Text('manufacturing.no_companies_available'.tr());
                      },
                    ),
                    const SizedBox(height: 16),

                    // اختيار المصنع (إذا تم اختيار شركة)
                    if (_selectedCompanyId != null)
                      _loadingFactories
                          ? const CircularProgressIndicator()
                          : _factories.isNotEmpty
                              ? DropdownButtonFormField<String>(
                                  initialValue: _selectedFactoryId,
                                  decoration: InputDecoration(
                                    labelText: 'factory'.tr(),
                                    border: const OutlineInputBorder(),
                                  ),
                                  items: [
                                    DropdownMenuItem(
                                      value: null,
                                      child: Text('select_factory'.tr()),
                                    ),
                                    ..._factories.map((factory) {
                                      return DropdownMenuItem(
                                        value: factory.id,
                                        child: Text(_isArabic ? factory.nameAr : factory.nameEn),
                                      );
                                    }),
                                  ],
                                  onChanged: (value) {
                                    setState(() {
                                      _selectedFactoryId = value;
                                    });
                                  },
                                  validator: (value) {
                                    if (value == null) {
                                      return 'select_factory'.tr();
                                    }
                                    return null;
                                  },
                                )
                              : Text('manufacturing.no_factories_available'.tr()),
                    const SizedBox(height: 16),

                    // زر الحفظ
                    ElevatedButton(
                      onPressed: _isLoading ? null : _submitForm,
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

  void _submitForm() async {
    if (_formKey.currentState!.validate()) {
      if (_selectedCompanyId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('select_company'.tr())),
        );
        return;
      }

      if (_selectedFactoryId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('select_factory'.tr())),
        );
        return;
      }

      setState(() {
        _isLoading = true;
      });

      try {
        final finishedProductService = Provider.of<FinishedProductService>(context, listen: false);

        // حساب تاريخ انتهاء الصلاحية بناءً على عدد الأشهر
        final shelfLifeMonths = int.parse(_shelfLifeController.text);
        final expiryDate = DateTime.now().add(Duration(days: shelfLifeMonths * 30));

        final finishedProduct = FinishedProduct(
          id: null,
          name: _nameController.text,
          quantity: double.parse(_quantityController.text),
          unit: _unitController.text,
          manufacturingOrderId: '',
          date: Timestamp.now(),
          companyId: _selectedCompanyId!,
          factoryId: _selectedFactoryId!,
          userId: _currentUser!.uid,
          createdAt: Timestamp.now(),
          batchNumber: '',
          expiryDate: Timestamp.fromDate(expiryDate),
        );

        await finishedProductService.addFinishedProduct(finishedProduct);
        
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('manufacturing.product_added_success'.tr())),
        );

        Navigator.pop(context);
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${'manufacturing.add_error'.tr()}: $e')),
        );
      } finally {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }
    }
  }
}