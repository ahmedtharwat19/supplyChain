import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:provider/provider.dart';
import 'package:puresip_purchasing/models/company.dart';
import 'package:puresip_purchasing/models/factory.dart';
import 'package:puresip_purchasing/models/finished_product.dart';
import 'package:puresip_purchasing/models/manufacturing_order_model.dart';
import 'package:puresip_purchasing/pages/manufacturing/services/manufacturing_service.dart';

class AddManufacturingOrderScreen extends StatefulWidget {
  const AddManufacturingOrderScreen({super.key});

  @override
  AddManufacturingOrderScreenState createState() =>
      AddManufacturingOrderScreenState();
}

class AddManufacturingOrderScreenState
    extends State<AddManufacturingOrderScreen> {
  final _runsController = TextEditingController(text: '1');
  List<TextEditingController> _batchControllers = [];
  List<TextEditingController> _quantityControllers = [];
  FinishedProduct? _selectedProduct;
  Company? _selectedCompany;
  Factory? _selectedFactory;
  List<Company> _userCompanies = [];
  List<Factory> _companyFactories = [];
  List<FinishedProduct> _companyProducts = [];
  final _formKey = GlobalKey<FormState>();
  bool _loadingFactories = false;
  bool _loadingProducts = false;

  @override
  void initState() {
    super.initState();
    debugPrint('initState: بدء تهيئة الشاشة');
    _generateRunFields(1);
    _loadUserCompanies();
  }

  void _loadUserCompanies() async {
    debugPrint('_loadUserCompanies: بدء تحميل شركات المستخدم');

    final user = FirebaseAuth.instance.currentUser;
    
    if (user == null) {
      debugPrint('_loadUserCompanies: لا يوجد مستخدم مسجل دخول');
      return;
    }

    try {
      debugPrint('_loadUserCompanies: جلب بيانات المستخدم من Firestore');
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (!userDoc.exists) {
        debugPrint('_loadUserCompanies: مستند المستخدم غير موجود');
        return;
      }

      final companyIds = List<String>.from(userDoc.data()?['companyIds'] ?? []);
      debugPrint('_loadUserCompanies: companyIds = $companyIds');

      if (companyIds.isEmpty) {
        debugPrint('_loadUserCompanies: المستخدم ليس له أي شركات');
        return;
      }

      debugPrint('_loadUserCompanies: جلب بيانات الشركات من Firestore');
      final companiesSnapshot = await FirebaseFirestore.instance
          .collection('companies')
          .where(FieldPath.documentId, whereIn: companyIds)
          .get();

      final companies = companiesSnapshot.docs
          .map((doc) => Company.fromMap(doc.data(), doc.id))
          .toList();

      debugPrint('_loadUserCompanies: تم تحميل ${companies.length} شركة');
      setState(() {
        _userCompanies = companies;
      });
    } catch (e) {
      debugPrint('_loadUserCompanies: خطأ في تحميل الشركات - $e');
    }
  }

  Future<void> _loadCompanyFactories(String companyId) async {
    debugPrint('_loadCompanyFactories: بدء تحميل مصانع الشركة $companyId');
    setState(() {
      _loadingFactories = true;
      _selectedFactory = null;
      _companyFactories = [];
      _selectedProduct = null;
      _companyProducts = [];
    });

    try {
      debugPrint('_loadCompanyFactories: جلب المصانع من Firestore');
      final factoriesSnapshot = await FirebaseFirestore.instance
          .collection('factories')
          .where('companyIds', arrayContains: companyId)
          .get();

      final factories = factoriesSnapshot.docs
          .map((doc) => Factory.fromMap(doc.data(), doc.id))
          .toList();

      debugPrint('_loadCompanyFactories: تم تحميل ${factories.length} مصنع');
      setState(() {
        _companyFactories = factories;
        _loadingFactories = false;
      });
    } catch (e) {
      debugPrint('_loadCompanyFactories: خطأ في تحميل المصانع - $e');
      setState(() {
        _loadingFactories = false;
      });
    }
  }

  Future<void> _loadCompanyProducts() async {
    if (_selectedCompany == null) {
      debugPrint('_loadCompanyProducts: لم يتم اختيار شركة');
      return;
    }

    debugPrint(
        '_loadCompanyProducts: بدء تحميل منتجات الشركة ${_selectedCompany!.id}');
    setState(() {
      _loadingProducts = true;
      _selectedProduct = null;
    });

    try {
      debugPrint('_loadCompanyProducts: جلب المنتجات من Firestore');
      final productsSnapshot = await FirebaseFirestore.instance
          .collection('finished_products')
          .where('companyId', isEqualTo: _selectedCompany!.id)
          .get();

      final products = productsSnapshot.docs
          .map((doc) => FinishedProduct.fromMap(doc.data(), doc.id))
          .toList();

      debugPrint('_loadCompanyProducts: تم تحميل ${products.length} منتج');
      setState(() {
        _companyProducts = products;
        _loadingProducts = false;
      });
    } catch (e) {
      debugPrint('_loadCompanyProducts: خطأ في تحميل المنتجات - $e');
      setState(() {
        _loadingProducts = false;
      });
    }
  }

  void _generateRunFields(int count) {
    debugPrint('_generateRunFields: إنشاء $count حقول للتشغيلات');
    _batchControllers = List.generate(
        count, (i) => TextEditingController(text: 'BATCH_${i + 1}'));
    _quantityControllers =
        List.generate(count, (i) => TextEditingController(text: '1'));
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    debugPrint('build: بناء واجهة المستخدم');
    final manufacturingService =
        Provider.of<ManufacturingService>(context, listen: false);
    final isArabic = context.locale.languageCode == 'ar';

    return Scaffold(
      appBar: AppBar(title: Text('manufacturing.add_order'.tr())),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              // 1. اختيار الشركة (دائماً ظاهر)
              DropdownButtonFormField<Company>(
                initialValue: _selectedCompany,
                decoration: InputDecoration(
                  labelText: 'company.select_company'.tr(),
                  border: const OutlineInputBorder(),
                ),
                items: _userCompanies.map((company) {
                  return DropdownMenuItem(
                    value: company,
                    child: Text(isArabic ? company.nameAr : company.nameEn),
                  );
                }).toList(),
                onChanged: (selectedCompany) {
                  debugPrint(
                      'onChanged Company: تم اختيار شركة ${selectedCompany?.id}');
                  setState(() {
                    _selectedCompany = selectedCompany;
                    _selectedFactory = null;
                    _companyFactories = [];
                    _selectedProduct = null;
                    _companyProducts = [];
                  });
                  if (selectedCompany != null) {
                    _loadCompanyFactories(selectedCompany.id!);
                  }
                },
                validator: (v) => v == null ? 'validation.required'.tr() : null,
              ),
              const SizedBox(height: 16),

              // 2. اختيار المصنع (يظهر فقط بعد اختيار الشركة)
              if (_selectedCompany != null) ...[
                _loadingFactories
                    ? const CircularProgressIndicator()
                    : DropdownButtonFormField<Factory>(
                        initialValue: _selectedFactory,
                        decoration: InputDecoration(
                          labelText: 'factory.select_factory'.tr(),
                          border: const OutlineInputBorder(),
                        ),
                        items: _companyFactories.map((factory) {
                          return DropdownMenuItem(
                            value: factory,
                            child: Text(
                                isArabic ? factory.nameAr : factory.nameEn),
                          );
                        }).toList(),
                        onChanged: (selectedFactory) {
                          debugPrint(
                              'onChanged Factory: تم اختيار مصنع ${selectedFactory?.id}');
                          setState(() {
                            _selectedFactory = selectedFactory;
                            _selectedProduct = null;
                          });
                          if (selectedFactory != null) {
                            _loadCompanyProducts();
                          }
                        },
                        validator: (v) =>
                            v == null ? 'validation.required'.tr() : null,
                      ),
                const SizedBox(height: 16),
              ],

              // 3. اختيار المنتج (يظهر فقط بعد اختيار المصنع)
              if (_selectedFactory != null) ...[
                _loadingProducts
                    ? const CircularProgressIndicator()
                    : DropdownButtonFormField<FinishedProduct>(
                        initialValue: _selectedProduct,
                        decoration: InputDecoration(
                          labelText: 'manufacturing.select_product'.tr(),
                          border: const OutlineInputBorder(),
                        ),
                        items: _companyProducts.map((product) {
                          return DropdownMenuItem(
                            value: product,
                            child: Text(
                                isArabic ? product.nameAr : product.nameEn),
                          );
                        }).toList(),
                        onChanged: (selectedProduct) {
                          debugPrint(
                              'onChanged Product: تم اختيار منتج ${selectedProduct?.id}');
                          setState(() {
                            _selectedProduct = selectedProduct;
                          });
                        },
                        validator: (v) =>
                            v == null ? 'validation.required'.tr() : null,
                      ),
                const SizedBox(height: 16),
              ],

              // 4. باقي الحقول (تظهر فقط بعد اختيار المنتج)
              if (_selectedProduct != null) ...[
                TextFormField(
                  controller: _runsController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'manufacturing.number_of_runs'.tr(),
                    border: const OutlineInputBorder(),
                  ),
                  onChanged: (value) {
                    debugPrint('onChanged Runs: عدد التشغيلات $value');
                    int count = int.tryParse(value) ?? 1;
                    if (count < 1) count = 1;
                    _generateRunFields(count);
                  },
                  validator: (v) {
                    final val = int.tryParse(v ?? '');
                    if (val == null || val < 1) {
                      return 'validation.invalid_number'.tr();
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _batchControllers.length,
                  itemBuilder: (context, index) {
                    return Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _batchControllers[index],
                            decoration: InputDecoration(
                              labelText:
                                  '${'manufacturing.batch_number'.tr()} #${index + 1}',
                              border: const OutlineInputBorder(),
                            ),
                            validator: (v) => v == null || v.isEmpty
                                ? 'validation.required'.tr()
                                : null,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextFormField(
                            controller: _quantityControllers[index],
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              labelText: 'manufacturing.run_quantity'.tr(),
                              border: const OutlineInputBorder(),
                            ),
                            validator: (v) {
                              final val = int.tryParse(v ?? '');
                              if (val == null || val < 1) {
                                return 'validation.invalid_number'.tr();
                              }
                              return null;
                            },
                          ),
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () async {
                    debugPrint('onPressed: بدء إنشاء أمر التصنيع');

                    if (!_formKey.currentState!.validate()) {
                      debugPrint('onPressed: فشل التحقق من صحة النموذج');
                      return;
                    }

                    if (_selectedProduct == null ||
                        _selectedCompany == null ||
                        _selectedFactory == null) {
                      debugPrint(
                          'onPressed: لم يتم اختيار جميع الحقول المطلوبة');
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                            content: Text('validation.select_all_fields'.tr())),
                      );
                      return;
                    }

                    // اجمع الكمية الكلية من التشغيلات
                    int totalQuantity =
                        _quantityControllers.fold(0, (sTotal, ctrl) {
                      return sTotal + (int.tryParse(ctrl.text) ?? 0);
                    });

                    debugPrint('onPressed: الكمية الإجمالية $totalQuantity');

                    final runs =
                        List.generate(_batchControllers.length, (index) {
                      return ManufacturingRun(
                        batchNumber: _batchControllers[index].text,
                        quantity: int.parse(_quantityControllers[index].text),
                        completedAt: null,
                      );
                    });

                    debugPrint('onPressed: إنشاء كائن ManufacturingOrder');
                    final order = ManufacturingOrder(
                      id: '',
                      productId: _selectedProduct!.id!,
                      productName: isArabic
                          ? _selectedProduct!.nameAr
                          : _selectedProduct!.nameEn,
                      totalQuantity: totalQuantity,
                      productUnit: _selectedProduct!.unit,
                      manufacturingDate: DateTime.now(),
                      expiryDate: DateTime.now().add(const Duration(days: 365)),
                      status: ManufacturingStatus.pending,
                      isFinished: false,
                      rawMaterials: [],
                      createdAt: DateTime.now(),
                      runs: runs,
                      companyId: _selectedCompany!.id!,
                      factoryId: _selectedFactory!.id!,
                      packagingMaterials: [],
                    );

                    try {
                      debugPrint('onPressed: استدعاء createManufacturingOrder');
                      await manufacturingService
                          .createManufacturingOrder(order);
                      debugPrint('onPressed: تم إنشاء أمر التصنيع بنجاح');

                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                            content: Text('manufacturing.order_created'.tr())),
                      );
                      Navigator.of(context).pop();
                    } catch (e) {
                      debugPrint(
                          'onPressed: خطأ في createManufacturingOrder - $e');
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Error: ${e.toString()}')),
                      );
                    }
                  },
                  child: Text('manufacturing.create_order'.tr()),
                )
              ],
            ],
          ),
        ),
      ),
    );
  }
}
